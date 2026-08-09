import '../models/tracking_event.dart';
import 'crm_api_client.dart';

class TrackingRemoteService {
  final CrmApiClient _client = CrmApiClient();

  Future<bool> isConfigured() => _client.isConfigured();

  Future<void> createEvent({
    required String externalId,
    required String employeeExternalId,
    required String leadExternalId,
    required String eventType,
    required double latitude,
    required double longitude,
    required double accuracy,
    String notes = '',
  }) async {
    await _client.post('/field-tracking', {
      'external_id': externalId,
      'employee_external_id': employeeExternalId,
      'lead_external_id': leadExternalId,
      'event_type': eventType,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'accuracy': accuracy.toString(),
      'notes': notes,
      'proof_image_url': '',
      'version': 1,
    });
  }

  Future<List<TrackingEvent>> getEvents({
    String? employeeExternalId,
  }) async {
    final data = await _client.get(
      '/field-tracking',
      query: employeeExternalId == null || employeeExternalId.isEmpty
          ? null
          : {'employee_external_id': employeeExternalId},
    );
    return (data as List<dynamic>)
        .map((item) => _fromApi(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteHistory({
    required String employeeExternalId,
    required String leadExternalId,
  }) async {
    await _client.delete(
      '/field-tracking/history/$employeeExternalId/$leadExternalId',
    );
  }

  TrackingEvent _fromApi(Map<String, dynamic> map) {
    return TrackingEvent(
      externalId: map['external_id']?.toString() ?? '',
      employeeExternalId: map['employee_external_id']?.toString() ?? '',
      leadExternalId: map['lead_external_id']?.toString() ?? '',
      eventType: map['event_type'] ?? '',
      latitude: double.tryParse(map['latitude']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(map['longitude']?.toString() ?? '') ?? 0,
      accuracy: double.tryParse(map['accuracy']?.toString() ?? '') ?? 0,
      notes: map['notes'] ?? '',
      createdAt: (map['created_at'] ?? '').toString(),
    );
  }
}
