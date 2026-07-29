class Meeting {
  final int? id;
  final int leadDbId;
  final String leadId;
  final String clientName;
  final String location;
  final String scheduledAt;
  final String notes;
  final int employeeId;
  final String employeeName;
  final String status;
  final String createdAt;
  final String adminNotifiedAt;

  const Meeting({
    this.id,
    required this.leadDbId,
    required this.leadId,
    required this.clientName,
    required this.location,
    required this.scheduledAt,
    required this.notes,
    required this.employeeId,
    required this.employeeName,
    required this.status,
    required this.createdAt,
    required this.adminNotifiedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leadDbId': leadDbId,
      'leadId': leadId,
      'clientName': clientName,
      'location': location,
      'scheduledAt': scheduledAt,
      'notes': notes,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'status': status,
      'createdAt': createdAt,
      'adminNotifiedAt': adminNotifiedAt,
    };
  }

  factory Meeting.fromMap(Map<String, dynamic> map) {
    return Meeting(
      id: map['id'] as int?,
      leadDbId: map['leadDbId'] ?? 0,
      leadId: map['leadId'] ?? '',
      clientName: map['clientName'] ?? '',
      location: map['location'] ?? '',
      scheduledAt: map['scheduledAt'] ?? '',
      notes: map['notes'] ?? '',
      employeeId: map['employeeId'] ?? 0,
      employeeName: map['employeeName'] ?? '',
      status: map['status'] ?? 'Scheduled',
      createdAt: map['createdAt'] ?? '',
      adminNotifiedAt: map['adminNotifiedAt'] ?? '',
    );
  }
}
