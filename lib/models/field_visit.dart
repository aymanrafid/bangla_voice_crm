class FieldVisit {
  final int? id;
  final int meetingId;
  final int leadDbId;
  final String leadId;
  final int employeeId;
  final String employeeName;
  final String checkInAt;
  final double checkInLat;
  final double checkInLng;
  final String checkOutAt;
  final double? checkOutLat;
  final double? checkOutLng;
  final int durationMinutes;
  final String status;

  const FieldVisit({
    this.id,
    required this.meetingId,
    required this.leadDbId,
    required this.leadId,
    required this.employeeId,
    required this.employeeName,
    required this.checkInAt,
    required this.checkInLat,
    required this.checkInLng,
    required this.checkOutAt,
    required this.checkOutLat,
    required this.checkOutLng,
    required this.durationMinutes,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meetingId': meetingId,
      'leadDbId': leadDbId,
      'leadId': leadId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'checkInAt': checkInAt,
      'checkInLat': checkInLat,
      'checkInLng': checkInLng,
      'checkOutAt': checkOutAt,
      'checkOutLat': checkOutLat,
      'checkOutLng': checkOutLng,
      'durationMinutes': durationMinutes,
      'status': status,
    };
  }

  factory FieldVisit.fromMap(Map<String, dynamic> map) {
    return FieldVisit(
      id: map['id'] as int?,
      meetingId: map['meetingId'] ?? 0,
      leadDbId: map['leadDbId'] ?? 0,
      leadId: map['leadId'] ?? '',
      employeeId: map['employeeId'] ?? 0,
      employeeName: map['employeeName'] ?? '',
      checkInAt: map['checkInAt'] ?? '',
      checkInLat: _toDouble(map['checkInLat']) ?? 0,
      checkInLng: _toDouble(map['checkInLng']) ?? 0,
      checkOutAt: map['checkOutAt'] ?? '',
      checkOutLat: _toDouble(map['checkOutLat']),
      checkOutLng: _toDouble(map['checkOutLng']),
      durationMinutes: map['durationMinutes'] ?? 0,
      status: map['status'] ?? 'Checked In',
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
