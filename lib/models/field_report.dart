class FieldReport {
  final int? id;
  final String externalId;
  final int meetingId;
  final int visitId;
  final int leadDbId;
  final String leadId;
  final int employeeId;
  final String employeeExternalId;
  final String employeeName;
  final String outcome;
  final String voiceAudioPath;
  final String voiceTranscript;
  final String textNotes;
  final List<String> imagePaths;
  final String submittedAt;
  final String adminComment;
  final String suggestedLeadStatus;

  const FieldReport({
    this.id,
    this.externalId = '',
    required this.meetingId,
    required this.visitId,
    required this.leadDbId,
    required this.leadId,
    required this.employeeId,
    this.employeeExternalId = '',
    required this.employeeName,
    required this.outcome,
    required this.voiceAudioPath,
    required this.voiceTranscript,
    required this.textNotes,
    this.imagePaths = const [],
    required this.submittedAt,
    required this.adminComment,
    required this.suggestedLeadStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meetingId': meetingId,
      'visitId': visitId,
      'leadDbId': leadDbId,
      'leadId': leadId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'outcome': outcome,
      'voiceAudioPath': voiceAudioPath,
      'voiceTranscript': voiceTranscript,
      'textNotes': textNotes,
      'submittedAt': submittedAt,
      'adminComment': adminComment,
      'suggestedLeadStatus': suggestedLeadStatus,
    };
  }

  factory FieldReport.fromMap(Map<String, dynamic> map) {
    return FieldReport(
      id: map['id'] as int?,
      meetingId: map['meetingId'] ?? 0,
      visitId: map['visitId'] ?? 0,
      leadDbId: map['leadDbId'] ?? 0,
      leadId: map['leadId'] ?? '',
      employeeId: map['employeeId'] ?? 0,
      employeeName: map['employeeName'] ?? '',
      outcome: map['outcome'] ?? '',
      voiceAudioPath: map['voiceAudioPath'] ?? '',
      voiceTranscript: map['voiceTranscript'] ?? '',
      textNotes: map['textNotes'] ?? '',
      imagePaths: const [],
      submittedAt: map['submittedAt'] ?? '',
      adminComment: map['adminComment'] ?? '',
      suggestedLeadStatus: map['suggestedLeadStatus'] ?? '',
    );
  }
}
