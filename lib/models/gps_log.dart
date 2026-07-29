class GpsLog {
  final int? id;
  final int visitId;
  final int meetingId;
  final int employeeId;
  final String employeeName;
  final String recordedAt;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double distanceFromCheckIn;
  final bool isGeofenceAlert;

  const GpsLog({
    this.id,
    required this.visitId,
    required this.meetingId,
    required this.employeeId,
    required this.employeeName,
    required this.recordedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.distanceFromCheckIn,
    required this.isGeofenceAlert,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'visitId': visitId,
      'meetingId': meetingId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'recordedAt': recordedAt,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'distanceFromCheckIn': distanceFromCheckIn,
      'isGeofenceAlert': isGeofenceAlert ? 1 : 0,
    };
  }

  factory GpsLog.fromMap(Map<String, dynamic> map) {
    return GpsLog(
      id: map['id'] as int?,
      visitId: map['visitId'] ?? 0,
      meetingId: map['meetingId'] ?? 0,
      employeeId: map['employeeId'] ?? 0,
      employeeName: map['employeeName'] ?? '',
      recordedAt: map['recordedAt'] ?? '',
      latitude: _toDouble(map['latitude']) ?? 0,
      longitude: _toDouble(map['longitude']) ?? 0,
      accuracy: _toDouble(map['accuracy']) ?? 0,
      distanceFromCheckIn: _toDouble(map['distanceFromCheckIn']) ?? 0,
      isGeofenceAlert: (map['isGeofenceAlert'] ?? 0) == 1,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
