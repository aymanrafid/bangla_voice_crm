import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/field_report.dart';
import '../models/field_visit.dart';
import '../models/report_image.dart';
import '../services/alert_service.dart';
import '../services/asr_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/offline_report_queue_service.dart';
import '../services/report_remote_service.dart';
import '../theme.dart';

class FieldReportSubmissionScreen extends StatefulWidget {
  final int meetingId;
  final FieldVisit visit;
  final int leadDbId;
  final String leadId;

  const FieldReportSubmissionScreen({
    super.key,
    required this.meetingId,
    required this.visit,
    required this.leadDbId,
    required this.leadId,
  });

  @override
  State<FieldReportSubmissionScreen> createState() =>
      _FieldReportSubmissionScreenState();
}

class _FieldReportSubmissionScreenState
    extends State<FieldReportSubmissionScreen> {
  static const _channel = MethodChannel('bangla_crm/recorder');
  final _db = DatabaseService();
  final _remote = ReportRemoteService();
  final _offlineQueue = OfflineReportQueueService();
  final _picker = ImagePicker();
  final _textController = TextEditingController();

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _saving = false;
  String _outcome = 'Follow-up';
  String _transcript = '';
  String _voicePath = '';
  String _error = '';
  String _progressText = '';
  String? _recordingPath;
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;
  final List<String> _imagePaths = [];

  @override
  void dispose() {
    _textController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _error = 'Microphone permission denied.';
        });
        return;
      }
      final dir = await getTemporaryDirectory();
      _recordingPath = path.join(
        dir.path,
        'field_report_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _channel.invokeMethod('startRecording', {'path': _recordingPath});
      _recordTimer?.cancel();
      _recordDuration = Duration.zero;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordDuration += const Duration(seconds: 1));
      });
      setState(() {
        _isRecording = true;
        _transcript = '';
        _voicePath = '';
        _error = '';
        _progressText = '';
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _error = 'Recording could not start: $exc';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordTimer?.cancel();
      await _channel.invokeMethod('stopRecording');
      if (!mounted) return;
      setState(() => _isRecording = false);
      final recordedPath = _recordingPath;
      if (recordedPath == null) return;
      // Guard against transcribing a file the recorder never produced, which is
      // how a stale recording gets attached to a new report.
      final file = File(recordedPath);
      if (!await file.exists() || await file.length() < 1024) {
        if (!mounted) return;
        setState(() {
          _recordingPath = null;
          _voicePath = '';
          _transcript = '';
          _error = 'No audio was captured. Please record again and speak for '
              'at least 2 seconds.';
        });
        return;
      }
      await _transcribeVoice(recordedPath);
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isProcessing = false;
        _error = 'Recording could not stop properly: $exc';
      });
    }
  }

  Future<void> _transcribeVoice(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _progressText = 'Preparing voice report...';
      _error = '';
    });
    final result = await AsrService.transcribe(
      audioPath,
      onProgress: (status) {
        if (!mounted) return;
        setState(() {
          final chunkPart = status.chunkCount > 0
              ? ' (${status.completedChunks}/${status.chunkCount})'
              : '';
          _progressText = '${status.stage.isEmpty ? status.status : status.stage}${chunkPart} - ${status.progress}%';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _isProcessing = false;
      _voicePath = audioPath;
      _progressText = '';
      if (result.error != null && result.error!.isNotEmpty) {
        _error = result.error!;
      } else {
        _transcript = result.text;
      }
    });
  }

  void _resetVoiceNote() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isProcessing = false;
      _recordDuration = Duration.zero;
      _recordingPath = null;
      _transcript = '';
      _voicePath = '';
      _error = '';
      _progressText = '';
    });
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;
    setState(() {
      _imagePaths
        ..clear()
        ..addAll(result.paths.whereType<String>());
    });
  }

  Future<void> _captureImage() async {
    final image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    setState(() => _imagePaths.add(image.path));
  }

  Future<void> _save() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = '';
    });

    final localUser = await _db.upsertUserByIdentity(
      AppUser(
        externalId: user.externalId,
        username: user.username,
        passwordHash: user.passwordHash,
        role: user.role,
        fullName: user.fullName,
        isActive: user.isActive,
        createdAt: user.createdAt,
      ),
    );

    final report = FieldReport(
      externalId: '${widget.leadId}_${DateTime.now().millisecondsSinceEpoch}',
      meetingId: widget.meetingId,
      visitId: widget.visit.id!,
      leadDbId: widget.leadDbId,
      leadId: widget.leadId,
      employeeId: localUser.id ?? 0,
      employeeExternalId: user.externalId,
      imagePaths: List<String>.from(_imagePaths),
      employeeName: localUser.fullName,
      outcome: _outcome,
      voiceAudioPath: _voicePath,
      voiceTranscript: _transcript,
      textNotes: _textController.text.trim(),
      submittedAt: DateTime.now().toIso8601String(),
      adminComment: '',
      suggestedLeadStatus: _mapOutcomeToStatus(_outcome),
    );

    final auth = context.read<AuthService>();
    var feedbackMessage = 'Report submitted successfully.';

    try {
      if (auth.isRemoteMode && await _remote.isConfigured()) {
        await _remote.submitReport(
          report: report,
          employeeExternalId: user.externalId,
          imagePaths: _imagePaths,
        );
        await _offlineQueue.retryPendingUploads(
          employeeExternalId: user.externalId,
        );
      } else {
        final reportId = await _db.createFieldReport(report);
        if (_imagePaths.isNotEmpty) {
          await _db.addReportImages(
            _imagePaths
                .map((imagePath) =>
                    ReportImage(reportId: reportId, filePath: imagePath))
                .toList(),
          );
        }
        await AlertService.createRoleAlert(
          title: 'Field Report Submitted',
          body: '${localUser.fullName} submitted a report for ${widget.leadId}',
          targetRole: 'Admin',
          relatedType: 'report',
          relatedId: reportId,
        );
      }
    } catch (exc) {
      if (auth.isRemoteMode) {
        await _offlineQueue.enqueueReportUpload(
          report: report,
          employeeExternalId: user.externalId,
          imagePaths: _imagePaths,
          lastError: exc.toString().replaceFirst('Exception: ', ''),
        );
        feedbackMessage =
            'Network/server issue: report queued locally and will retry automatically.';
      } else {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = exc.toString().replaceFirst('Exception: ', '');
        });
        return;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(feedbackMessage)),
    );
    Navigator.pop(context, true);
  }

  String _mapOutcomeToStatus(String outcome) {
    switch (outcome) {
      case 'Interested':
        return 'Contacted';
      case 'Deal Closed':
        return 'Converted';
      case 'Not Interested':
        return 'Closed';
      default:
        return 'Contacted';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Field Report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _outcome,
            items: const [
              DropdownMenuItem(value: 'Interested', child: Text('Interested')),
              DropdownMenuItem(
                  value: 'Not Interested', child: Text('Not Interested')),
              DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
              DropdownMenuItem(
                  value: 'Deal Closed', child: Text('Deal Closed')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _outcome = value);
            },
            decoration: const InputDecoration(labelText: 'Meeting Outcome'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isProcessing
                        ? null
                        : (_isRecording ? _stopRecording : _startRecording),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor:
                          _isRecording ? AppTheme.error : AppTheme.primary,
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isRecording
                        ? 'Recording... ${_recordDuration.inSeconds}s'
                        : _isProcessing
                            ? 'Transcribing voice note...'
                            : 'Record Bangla voice note',
                  ),
                  if (_progressText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _progressText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (_transcript.isNotEmpty || _voicePath.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _isRecording || _isProcessing
                          ? null
                          : _resetVoiceNote,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset voice note'),
                    ),
                  ],
                  if (_transcript.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _transcript,
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Optional text notes',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery Photos'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _captureImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
          if (_imagePaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _imagePaths
                  .map(
                    (img) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(img),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: AppTheme.error)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Submit Report'),
          ),
        ],
      ),
    );
  }
}