import '../models/field_report.dart';
import 'crm_api_client.dart';
import 'media_upload_service.dart';

class ReportRemoteService {
  final CrmApiClient _client = CrmApiClient();
  final MediaUploadService _media = MediaUploadService();

  Future<bool> isConfigured() => _client.isConfigured();

  Future<FieldReport> submitReport({
    required FieldReport report,
    required String employeeExternalId,
    List<String> imagePaths = const [],
  }) async {
    final reportExternalId = report.externalId.isEmpty
        ? '${report.leadId}_${report.submittedAt}'
        : report.externalId;

    var voiceAudioUrl = report.voiceAudioPath;
    if (voiceAudioUrl.isNotEmpty &&
        !voiceAudioUrl.startsWith('http') &&
        await _media.isConfigured()) {
      voiceAudioUrl = await _media.uploadFile(
        filePath: voiceAudioUrl,
        category: 'audio',
        relatedType: 'field_report',
        relatedExternalId: reportExternalId,
      );
    }

    final uploadedImages = <String>[];
    for (final imagePath in imagePaths) {
      if (imagePath.isEmpty) {
        continue;
      }
      if (await _media.isConfigured()) {
        uploadedImages.add(
          await _media.uploadFile(
            filePath: imagePath,
            category: 'images',
            relatedType: 'field_report',
            relatedExternalId: reportExternalId,
          ),
        );
      }
    }

    final data = await _client.post('/reports', {
      'external_id': reportExternalId,
      'employee_external_id': employeeExternalId,
      'lead_external_id': report.leadId,
      'outcome': report.outcome,
      'voice_audio_url': voiceAudioUrl,
      'voice_transcript': report.voiceTranscript,
      'text_notes': report.textNotes,
      'admin_comment': report.adminComment,
      'suggested_lead_status': report.suggestedLeadStatus,
      'version': 1,
    });
    return _fromApi(data as Map<String, dynamic>,
        fallbackImageUrls: uploadedImages);
  }

  Future<List<FieldReport>> getReports({
    String? employeeExternalId,
    Map<String, String> userNames = const {},
  }) async {
    final data = await _client.get(
      '/reports',
      query: employeeExternalId == null || employeeExternalId.isEmpty
          ? null
          : {'employee_external_id': employeeExternalId},
    );
    return (data as List<dynamic>)
        .map((item) =>
            _fromApi(item as Map<String, dynamic>, userNames: userNames))
        .toList();
  }

  Future<void> saveAdminReview({
    required String externalId,
    required String adminComment,
    required String suggestedLeadStatus,
  }) async {
    await _client.put('/reports/$externalId/review', {
      'admin_comment': adminComment,
      'suggested_lead_status': suggestedLeadStatus,
    });
  }

  FieldReport _fromApi(
    Map<String, dynamic> map, {
    Map<String, String> userNames = const {},
    List<String> fallbackImageUrls = const [],
  }) {
    final employeeExternalId = map['employee_external_id']?.toString() ?? '';
    final imageUrls = _extractImageUrls(map, fallbackImageUrls);
    return FieldReport(
      externalId: map['external_id']?.toString() ?? '',
      meetingId: 0,
      visitId: 0,
      leadDbId: 0,
      leadId: map['lead_external_id']?.toString() ?? '',
      employeeId: 0,
      employeeExternalId: employeeExternalId,
      employeeName: userNames[employeeExternalId] ?? employeeExternalId,
      outcome: map['outcome'] ?? '',
      voiceAudioPath: map['voice_audio_url'] ?? '',
      voiceTranscript: map['voice_transcript'] ?? '',
      textNotes: _extractNotes(map['text_notes']?.toString() ?? ''),
      imagePaths: imageUrls,
      submittedAt: (map['created_at'] ?? '').toString(),
      adminComment: map['admin_comment'] ?? '',
      suggestedLeadStatus: map['suggested_lead_status'] ?? '',
    );
  }

  List<String> _extractImageUrls(
    Map<String, dynamic> map,
    List<String> fallbackImageUrls,
  ) {
    final apiValue = map['image_urls'];
    if (apiValue is List) {
      return apiValue
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (fallbackImageUrls.isNotEmpty) {
      return fallbackImageUrls;
    }
    return _splitNotesAndImages(map['text_notes']?.toString() ?? '').imageUrls;
  }

  String _extractNotes(String rawNotes) {
    return _splitNotesAndImages(rawNotes).notes;
  }

  _ParsedReportNotes _splitNotesAndImages(String rawNotes) {
    const marker = 'Uploaded Images:';
    final markerIndex = rawNotes.indexOf(marker);
    if (markerIndex < 0) {
      return _ParsedReportNotes(rawNotes.trim(), const []);
    }

    final noteText = rawNotes.substring(0, markerIndex).trim();
    final imageBlock = rawNotes.substring(markerIndex + marker.length).trim();
    final imageUrls = imageBlock
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.startsWith('http'))
        .toList();
    return _ParsedReportNotes(noteText, imageUrls);
  }
}

class _ParsedReportNotes {
  final String notes;
  final List<String> imageUrls;

  const _ParsedReportNotes(this.notes, this.imageUrls);
}
