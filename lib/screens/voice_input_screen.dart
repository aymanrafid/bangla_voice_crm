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
import '../services/crm_extractor.dart';
import '../services/database_service.dart';
import '../services/lead_intelligence_service.dart';
import '../services/lead_remote_service.dart';
import '../theme.dart';
import 'lead_detail_screen.dart';

class VoiceInputScreen extends StatefulWidget {
  const VoiceInputScreen({super.key});

  @override
  State<VoiceInputScreen> createState() => _VoiceInputScreenState();
}

class _VoiceInputScreenState extends State<VoiceInputScreen> {
  static const _channel = MethodChannel('bangla_crm/recorder');
  final DatabaseService _db = DatabaseService();
  final LeadRemoteService _remote = LeadRemoteService();

  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  String? _recordingPath;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  String _errorMsg = '';
  String _processingMessage = '';
  int _processingProgress = 0;
  int _processingChunkCount = 0;
  int _processingCompletedChunks = 0;
  CrmFields? _extractedFields;
  LeadIntelligence? _intelligence;
  int _confidence = 0;

  final _transcriptCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _productCtrl = TextEditingController();
  String _leadType = 'Auto Detect';

  @override
  void dispose() {
    _recordTimer?.cancel();
    _transcriptCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _locationCtrl.dispose();
    _productCtrl.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() {
        _errorMsg = 'Microphone permission denied.';
      });
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordingPath = path.join(
      dir.path,
      'rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await _channel.invokeMethod('startRecording', {'path': _recordingPath});
    _recordDuration = Duration.zero;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
    setState(() {
      _isRecording = true;
      _errorMsg = '';
    });
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    await _channel.invokeMethod('stopRecording');
    setState(() => _isRecording = false);
    if (_recordingPath != null) {
      await _processAudio(_recordingPath!);
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      await _processAudio(result.files.single.path!);
    }
  }

  void _resetForm() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isProcessing = false;
      _recordingPath = null;
      _recordDuration = Duration.zero;
      _errorMsg = '';
      _processingMessage = '';
      _processingProgress = 0;
      _processingChunkCount = 0;
      _processingCompletedChunks = 0;
      _extractedFields = null;
      _intelligence = null;
      _confidence = 0;
      _leadType = 'Auto Detect';
    });
    _transcriptCtrl.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _locationCtrl.clear();
    _productCtrl.clear();
  }

  Future<void> _processAudio(String audioPath) async {
    _transcriptCtrl.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _locationCtrl.clear();
    _productCtrl.clear();
    setState(() {
      _isProcessing = true;
      _errorMsg = '';
      _recordingPath = audioPath;
      _processingMessage = 'Uploading audio to ASR server...';
      _processingProgress = 2;
      _processingChunkCount = 0;
      _processingCompletedChunks = 0;
      _extractedFields = null;
      _intelligence = null;
      _confidence = 0;
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
        _errorMsg = asrResult.error!;
        _isProcessing = false;
      });
      return;
    }
    _transcriptCtrl.text = asrResult.text;
    _extractFromTranscript();
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

  void _extractFromTranscript() {
    final transcript = _transcriptCtrl.text.trim();
    if (transcript.isEmpty) {
      setState(() {
        _errorMsg = 'Transcript is empty.';
        _isProcessing = false;
      });
      return;
    }

    final fields = CrmExtractor.extract(
      transcript,
      leadType: _leadType == 'Auto Detect' ? 'auto' : _leadType,
    );
    if (_nameCtrl.text.trim().isNotEmpty) {
      fields.name = _nameCtrl.text.trim();
    }
    if (_phoneCtrl.text.trim().isNotEmpty) {
      fields.phone = _phoneCtrl.text.trim();
    }
    if (_addressCtrl.text.trim().isNotEmpty) {
      fields.address = _addressCtrl.text.trim();
    }
    if (_locationCtrl.text.trim().isNotEmpty) {
      fields.location = _locationCtrl.text.trim();
    }
    if (_productCtrl.text.trim().isNotEmpty) {
      fields.productInterest = _productCtrl.text.trim();
    }

    final confidence = CrmExtractor.computeConfidence(fields);
    final intelligence = LeadIntelligenceService.analyze(
      transcript: transcript,
      fields: fields,
      confidence: confidence,
    );

    setState(() {
      _extractedFields = fields;
      _intelligence = intelligence;
      _confidence = confidence;
      _nameCtrl.text = fields.name;
      _phoneCtrl.text = fields.phone;
      _addressCtrl.text = fields.address;
      _locationCtrl.text = fields.location;
      _productCtrl.text = fields.productInterest;
      _isProcessing = false;
      _errorMsg = '';
      _processingMessage = 'Transcript ready.';
      _processingProgress = 100;
    });
  }

  Future<void> _saveLead() async {
    if (_isSaving) return;
    _extractFromTranscript();
    if (_extractedFields == null) return;
    final auth = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    try {
      final leadId = await _db.generateLeadId();
      final lead = Lead(
        leadId: leadId,
        dateTime: DateTime.now().toString().substring(0, 19),
        leadType: _extractedFields!.leadType,
        name: _extractedFields!.name,
        phone: _extractedFields!.phone,
        address: _extractedFields!.address,
        location: _extractedFields!.location,
        productInterest: _extractedFields!.productInterest,
        transcript: _transcriptCtrl.text.trim(),
        confidence: _confidence,
      );
      final enrichedLead = LeadIntelligenceService.enrichLead(
        lead: lead,
        fields: _extractedFields!,
      );
      final savedLead = auth.isRemoteMode && await _remote.isConfigured()
          ? await _remote.createLead(enrichedLead)
          : enrichedLead.copyWith(id: await _db.insertLead(enrichedLead));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('${savedLead.leadId} saved successfully')),
      );
      await navigator.push(
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: savedLead)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Text(
              'Speak the customer name, phone, location, and product interest clearly. Long audio is processed in background chunks so you can wait for progress, edit the transcript, and save only when it looks right.',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isProcessing
                        ? null
                        : (_isRecording ? _stopRecording : _startRecording),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          _isRecording ? AppTheme.error : AppTheme.primary,
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isRecording
                        ? 'Recording ${_recordDuration.inSeconds}s'
                        : _isProcessing
                            ? _processingMessage
                            : 'Tap to record',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (_processingProgress <= 0 ||
                              _processingProgress >= 100)
                          ? null
                          : _processingProgress / 100,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _processingChunkCount > 0
                          ? '$_processingProgress% • chunk $_processingCompletedChunks of $_processingChunkCount'
                          : '$_processingProgress%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : _pickAudioFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Audio File'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.outlined(
                        onPressed:
                            (_isProcessing || _isRecording) ? null : _resetForm,
                        icon: const Icon(Icons.restart_alt),
                        tooltip: 'Reset form',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _leadType,
            items: const [
              DropdownMenuItem(
                  value: 'Auto Detect', child: Text('Auto Detect')),
              DropdownMenuItem(value: 'Sales Lead', child: Text('Sales Lead')),
              DropdownMenuItem(
                value: 'Customer Support',
                child: Text('Customer Support'),
              ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _leadType = value);
            },
            decoration: const InputDecoration(labelText: 'Lead Type'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transcriptCtrl,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Transcript'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _extractFromTranscript,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Extract Again'),
          ),
          const SizedBox(height: 12),
          _field(_nameCtrl, 'Name'),
          const SizedBox(height: 10),
          _field(_phoneCtrl, 'Phone'),
          const SizedBox(height: 10),
          _field(_addressCtrl, 'Address'),
          const SizedBox(height: 10),
          _field(_locationCtrl, 'Location'),
          const SizedBox(height: 10),
          _field(_productCtrl, 'Product / Service'),
          if (_extractedFields != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Confidence: $_confidence%'),
                    if (_intelligence != null) ...[
                      const SizedBox(height: 8),
                      Text('Intent: ${_intelligence!.intent}'),
                      Text('Priority: ${_intelligence!.priority}'),
                      Text('Summary: ${_intelligence!.aiSummary}'),
                    ],
                  ],
                ),
              ),
            ),
          ],
          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_errorMsg, style: const TextStyle(color: AppTheme.error)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveLead,
            child: Text(_isSaving ? 'Saving...' : 'Save Lead'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }
}
