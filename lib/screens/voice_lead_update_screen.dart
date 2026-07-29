import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../services/asr_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/lead_remote_service.dart';
import '../services/lead_voice_update_service.dart';
import '../theme.dart';

class VoiceLeadUpdateScreen extends StatefulWidget {
  final Lead lead;

  const VoiceLeadUpdateScreen({super.key, required this.lead});

  @override
  State<VoiceLeadUpdateScreen> createState() => _VoiceLeadUpdateScreenState();
}

class _VoiceLeadUpdateScreenState extends State<VoiceLeadUpdateScreen> {
  static const _channel = MethodChannel('bangla_crm/recorder');

  final _db = DatabaseService();
  final _remote = LeadRemoteService();
  final _actorController = TextEditingController(text: 'Admin');

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _recordingPath;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  String _transcript = '';
  String _errorMsg = '';
  String _processingMessage = '';
  int _processingProgress = 0;
  int _processingChunkCount = 0;
  int _processingCompletedChunks = 0;
  VoiceLeadUpdateProposal? _proposal;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _actorController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _errorMsg =
            'Microphone permission denied. Please allow it in settings.';
      });
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      _recordingPath = path.join(
        dir.path,
        'lead_update_${DateTime.now().millisecondsSinceEpoch}.m4a',
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
        _errorMsg = '';
        _proposal = null;
        _transcript = '';
      });
    } catch (e) {
      setState(() => _errorMsg = 'Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    try {
      await _channel.invokeMethod('stopRecording');
      setState(() => _isRecording = false);
      if (_recordingPath != null) {
        await _processAudio(_recordingPath!);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMsg = 'Could not stop recording: $e';
      });
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      await _processAudio(result.files.single.path!);
    }
  }

  void _resetState() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isProcessing = false;
      _recordingPath = null;
      _recordDuration = Duration.zero;
      _transcript = '';
      _errorMsg = '';
      _processingMessage = '';
      _processingProgress = 0;
      _processingChunkCount = 0;
      _processingCompletedChunks = 0;
      _proposal = null;
    });
  }

  Future<void> _processAudio(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _errorMsg = '';
      _proposal = null;
      _transcript = '';
      _processingMessage = 'Uploading audio to ASR server...';
      _processingProgress = 2;
      _processingChunkCount = 0;
      _processingCompletedChunks = 0;
    });

    final asrResult = await AsrService.transcribe(
      audioPath,
      onProgress: (status) {
        if (!mounted) return;
        setState(() {
          _processingProgress = status.progress.clamp(0, 100);
          _processingMessage = status.message.isNotEmpty
              ? status.message
              : _fallbackProgressMessage(status);
          _processingChunkCount = status.chunkCount;
          _processingCompletedChunks = status.completedChunks;
        });
      },
    );
    if (!mounted) return;

    if (asrResult.error != null && asrResult.error!.isNotEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMsg = asrResult.error!;
      });
      return;
    }

    final transcript = asrResult.text.trim();
    if (transcript.isEmpty) {
      setState(() {
        _isProcessing = false;
        _errorMsg = 'No clear voice command was detected.';
      });
      return;
    }

    final proposal = LeadVoiceUpdateService.parseVoiceUpdate(
      currentLead: widget.lead,
      transcript: transcript,
    );

    setState(() {
      _isProcessing = false;
      _transcript = transcript;
      _proposal = proposal;
      if (!proposal.hasChanges && proposal.warnings.isNotEmpty) {
        _errorMsg = proposal.warnings.join('\n');
      }
    });
  }

  String _fallbackProgressMessage(AsrJobStatus status) {
    switch (status.stage) {
      case 'loading_model':
        return 'Preparing ASR model...';
      case 'preprocessing':
        return 'Reducing noise and trimming silence...';
      case 'segmenting':
        return 'Splitting long audio into chunks...';
      case 'transcribing':
        return 'Transcribing audio chunks...';
      case 'completed':
        return 'Transcription complete.';
      case 'failed':
        return 'Transcription failed.';
      default:
        return 'Processing...';
    }
  }

  Future<void> _saveUpdates() async {
    if (_proposal == null || !_proposal!.hasChanges || _isSaving) return;

    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isSaving = true;
      _errorMsg = '';
    });

    try {
      late final Lead updatedLead;
      if (auth.isRemoteMode && await _remote.isConfigured()) {
        final remoteLead = _proposal!
            .applyTo(widget.lead)
            .copyWith(transcript: _transcript, version: widget.lead.version);
        updatedLead = await _remote.updateLead(remoteLead);
      } else {
        updatedLead = await _db.updateLeadWithChanges(
          lead: widget.lead,
          changes: _proposal!.changes,
          changedBy: _actorController.text.trim().isEmpty
              ? 'Local User'
              : _actorController.text.trim(),
          sourceTranscript: _transcript,
        );
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Voice update saved successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop(updatedLead);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Update could not be saved: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final proposedLead = _proposal?.applyTo(widget.lead);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Update')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 12),
            _buildRecorderCard(),
            const SizedBox(height: 12),
            _buildActorCard(),
            if (_errorMsg.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildErrorCard(_errorMsg),
            ],
            if (_transcript.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildTranscriptCard(),
            ],
            if (_proposal != null) ...[
              const SizedBox(height: 12),
              _buildDiffCard(proposedLead),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed:
                  _proposal != null && _proposal!.hasChanges && !_isSaving
                      ? _saveUpdates
                      : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_as_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Save Voice Update'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to speak updates',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Examples:\n'
              '• Phone number will be 01712345678\n'
              '• Address will be Gulshan 2, Dhaka\n'
              '• Set status to Closed\n'
              '• Name will be Rahim',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Only the fields you mention will be changed.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecorderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _isProcessing
                  ? null
                  : (_isRecording ? _stopRecording : _startRecording),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? AppTheme.error
                      : _isProcessing
                          ? AppTheme.warning
                          : AppTheme.primary,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isRecording
                  ? 'Recording ${_formatDuration(_recordDuration)}'
                  : _isProcessing
                      ? _processingMessage
                      : 'Tap to record an update',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_processingProgress <= 0 || _processingProgress >= 100)
                    ? null
                    : _processingProgress / 100,
              ),
              const SizedBox(height: 8),
              Text(
                _processingChunkCount > 0
                    ? '$_processingProgress% • chunk $_processingCompletedChunks of $_processingChunkCount'
                    : '$_processingProgress%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!_isRecording && !_isProcessing)
                        ? _pickAudioFile
                        : null,
                    icon: const Icon(Icons.audio_file_outlined),
                    label: const Text('Upload Audio File'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.outlined(
                  onPressed:
                      (!_isRecording && !_isProcessing) ? _resetState : null,
                  icon: const Icon(Icons.restart_alt),
                  tooltip: 'Reset',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _actorController,
          decoration: const InputDecoration(
            labelText: 'Updated by',
            hintText: 'Admin / Manager / Employee',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transcript',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _transcript,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffCard(Lead? proposedLead) {
    final proposal = _proposal!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected changes',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (proposal.changes.isEmpty)
              Text(
                'No structured update was detected from this transcript.',
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
              ...proposal.changes.map(
                (change) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        change.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Before: ${change.oldValue.isEmpty ? 'Empty' : change.oldValue}',
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'After: ${change.newValue}',
                        style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (proposal.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...proposal.warnings.map(_buildWarningText),
            ],
            if (proposedLead != null && proposal.changes.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Preview: ${proposedLead.name.isEmpty ? proposedLead.leadId : proposedLead.name}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                '${proposedLead.phone} • ${proposedLead.status}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningText(String warning) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.error,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
