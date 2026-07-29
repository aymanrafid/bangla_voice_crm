class QueuedReportUpload {
  final int? id;
  final String externalId;
  final String employeeExternalId;
  final String reportJson;
  final String imagePathsJson;
  final String queuedAt;
  final int retryCount;
  final String lastError;

  const QueuedReportUpload({
    this.id,
    required this.externalId,
    required this.employeeExternalId,
    required this.reportJson,
    required this.imagePathsJson,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastError = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'externalId': externalId,
      'employeeExternalId': employeeExternalId,
      'reportJson': reportJson,
      'imagePathsJson': imagePathsJson,
      'queuedAt': queuedAt,
      'retryCount': retryCount,
      'lastError': lastError,
    };
  }

  factory QueuedReportUpload.fromMap(Map<String, dynamic> map) {
    return QueuedReportUpload(
      id: map['id'] as int?,
      externalId: map['externalId']?.toString() ?? '',
      employeeExternalId: map['employeeExternalId']?.toString() ?? '',
      reportJson: map['reportJson']?.toString() ?? '{}',
      imagePathsJson: map['imagePathsJson']?.toString() ?? '[]',
      queuedAt: map['queuedAt']?.toString() ?? '',
      retryCount: map['retryCount'] ?? 0,
      lastError: map['lastError']?.toString() ?? '',
    );
  }
}
