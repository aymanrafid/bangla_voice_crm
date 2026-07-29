import 'package:flutter_test/flutter_test.dart';
import 'package:bangla_voice_crm/models/lead.dart';

void main() {
  test('Lead model keeps survey fields', () {
    final lead = Lead(
      leadId: 'LEAD-0001',
      dateTime: '2026-05-05 10:00:00',
      leadType: 'Sales Lead',
      name: 'Test Lead',
      phone: '01712345678',
      address: 'Mirpur, Dhaka',
      location: 'Dhaka',
      productInterest: 'Real Estate - Flat',
      transcript: 'Test transcript',
      confidence: 90,
      latitude: 23.8,
      longitude: 90.4,
      surveyStatus: 'Completed',
      surveyArrivedAt: '2026-05-05 11:00:00',
      surveyDistanceMeters: 42,
    );

    final restored = Lead.fromMap(lead.toMap());

    expect(restored.surveyStatus, 'Completed');
    expect(restored.latitude, 23.8);
    expect(restored.longitude, 90.4);
    expect(restored.surveyDistanceMeters, 42);
  });
}
