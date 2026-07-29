class TrackingEvent {
  final String externalId;
  final String employeeExternalId;
  final String leadExternalId;
  final String eventType;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String notes;
  final String createdAt;

  const TrackingEvent({
    required this.externalId,
    required this.employeeExternalId,
    required this.leadExternalId,
    required this.eventType,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.notes,
    required this.createdAt,
  });
}
