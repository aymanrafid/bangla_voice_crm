class ReportImage {
  final int? id;
  final int reportId;
  final String filePath;

  const ReportImage({
    this.id,
    required this.reportId,
    required this.filePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'filePath': filePath,
    };
  }

  factory ReportImage.fromMap(Map<String, dynamic> map) {
    return ReportImage(
      id: map['id'] as int?,
      reportId: map['reportId'] ?? 0,
      filePath: map['filePath'] ?? '',
    );
  }
}
