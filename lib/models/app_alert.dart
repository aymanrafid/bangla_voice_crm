class AppAlert {
  final int? id;
  final String title;
  final String body;
  final String targetRole;
  final int? targetUserId;
  final String relatedType;
  final int? relatedId;
  final String createdAt;
  final String readAt;

  const AppAlert({
    this.id,
    required this.title,
    required this.body,
    required this.targetRole,
    required this.targetUserId,
    required this.relatedType,
    required this.relatedId,
    required this.createdAt,
    required this.readAt,
  });

  bool get isRead => readAt.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'targetRole': targetRole,
      'targetUserId': targetUserId,
      'relatedType': relatedType,
      'relatedId': relatedId,
      'createdAt': createdAt,
      'readAt': readAt,
    };
  }

  factory AppAlert.fromMap(Map<String, dynamic> map) {
    return AppAlert(
      id: map['id'] as int?,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      targetRole: map['targetRole'] ?? 'Admin',
      targetUserId: map['targetUserId'] as int?,
      relatedType: map['relatedType'] ?? '',
      relatedId: map['relatedId'] as int?,
      createdAt: map['createdAt'] ?? '',
      readAt: map['readAt'] ?? '',
    );
  }
}
