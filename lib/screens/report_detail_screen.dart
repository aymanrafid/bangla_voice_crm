import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/field_report.dart';
import '../models/report_image.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/report_remote_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final FieldReport report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _db = DatabaseService();
  final _remote = ReportRemoteService();
  final _commentController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  List<ReportImage> _images = [];
  bool _loading = true;
  String _status = 'Contacted';

  @override
  void initState() {
    super.initState();
    _commentController.text = widget.report.adminComment;
    _status = widget.report.suggestedLeadStatus.isEmpty
        ? 'Contacted'
        : widget.report.suggestedLeadStatus;
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.report.id != null) {
      final images = await _db.getReportImages(widget.report.id!);
      if (!mounted) {
        return;
      }
      setState(() {
        _images = images;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _playAudio() async {
    if (widget.report.voiceAudioPath.isEmpty) {
      return;
    }
    if (widget.report.voiceAudioPath.startsWith('http')) {
      await _audioPlayer.play(UrlSource(widget.report.voiceAudioPath));
      return;
    }
    await _audioPlayer.play(DeviceFileSource(widget.report.voiceAudioPath));
  }

  Future<void> _saveReview() async {
    final auth = context.read<AuthService>();
    if (auth.isRemoteMode && widget.report.externalId.isNotEmpty) {
      await _remote.saveAdminReview(
        externalId: widget.report.externalId,
        adminComment: _commentController.text.trim(),
        suggestedLeadStatus: _status,
      );
    } else {
      await _db.updateReportAdminReview(
        reportId: widget.report.id!,
        adminComment: _commentController.text.trim(),
        suggestedLeadStatus: _status,
      );
      await _db.updateLeadStatus(widget.report.leadDbId, _status);
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report review updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<AuthService>().currentUser?.isAdmin ?? false;
    final remoteImageUrls = widget.report.imagePaths
        .where((path) => path.startsWith('http'))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(widget.report.leadId)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text(widget.report.outcome),
                    subtitle: Text(
                      '${widget.report.employeeName}\n${widget.report.submittedAt.replaceFirst('T', ' ')}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ),
                if (widget.report.voiceTranscript.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        widget.report.voiceTranscript,
                        style: const TextStyle(height: 1.6),
                      ),
                    ),
                  ),
                if (widget.report.textNotes.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(widget.report.textNotes),
                    ),
                  ),
                if (widget.report.voiceAudioPath.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: _playAudio,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Voice Note'),
                  ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _images
                        .map(
                          (img) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(img.filePath),
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (remoteImageUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: remoteImageUrls
                        .map(
                          (url) => ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              url,
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 110,
                                height: 110,
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Admin Comment',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    items: const [
                      DropdownMenuItem(value: 'New', child: Text('New')),
                      DropdownMenuItem(
                        value: 'Contacted',
                        child: Text('Contacted'),
                      ),
                      DropdownMenuItem(
                        value: 'Converted',
                        child: Text('Converted'),
                      ),
                      DropdownMenuItem(value: 'Closed', child: Text('Closed')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _status = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Lead Status Suggestion',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _saveReview,
                    child: const Text('Save Admin Review'),
                  ),
                ],
              ],
            ),
    );
  }
}
