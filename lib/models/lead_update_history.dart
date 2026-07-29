class LeadUpdateHistory {
  final int? id;
  final int leadDbId;
  final String leadId;
  final String fieldKey;
  final String fieldLabel;
  final String oldValue;
  final String newValue;
  final String changedAt;
  final String changedBy;
  final String sourceType;
  final String sourceTranscript;

  const LeadUpdateHistory({
    this.id,
    required this.leadDbId,
    required this.leadId,
    required this.fieldKey,
    required this.fieldLabel,
    required this.oldValue,
    required this.newValue,
    required this.changedAt,
    required this.changedBy,
    required this.sourceType,
    required this.sourceTranscript,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadDbId': leadDbId,
      'leadId': leadId,
      'fieldKey': fieldKey,
      'fieldLabel': fieldLabel,
      'oldValue': oldValue,
      'newValue': newValue,
      'changedAt': changedAt,
      'changedBy': changedBy,
      'sourceType': sourceType,
      'sourceTranscript': sourceTranscript,
    };
  }

  factory LeadUpdateHistory.fromMap(Map<String, dynamic> map) {
    return LeadUpdateHistory(
      id: map['id'] as int?,
      leadDbId: map['leadDbId'] ?? 0,
      leadId: map['leadId'] ?? '',
      fieldKey: map['fieldKey'] ?? '',
      fieldLabel: map['fieldLabel'] ?? '',
      oldValue: map['oldValue'] ?? '',
      newValue: map['newValue'] ?? '',
      changedAt: map['changedAt'] ?? '',
      changedBy: map['changedBy'] ?? '',
      sourceType: map['sourceType'] ?? 'voice_update',
      sourceTranscript: map['sourceTranscript'] ?? '',
    );
  }
}
