import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';

import '../models/field_visit.dart';
import '../models/gps_log.dart';
import 'alert_service.dart';
import 'api_config_service.dart';
import 'database_service.dart';
import 'tracking_remote_service.dart';

class FieldTrackingService {
  static final FieldTrackingService _instance =
      FieldTrackingService._internal();
  factory FieldTrackingService() => _instance;
  FieldTrackingService._internal();

  final DatabaseService _db = DatabaseService();
  final ApiConfigService _config = ApiConfigService();
  final TrackingRemoteService _remote = TrackingRemoteService();
  Timer? _timer;
  FieldVisit? _activeVisit;
  double _checkInLat = 0;
  double _checkInLng = 0;

  static const double geofenceAlertMeters = 250;

  FieldVisit? get activeVisit => _activeVisit;
  bool get isTracking => _timer != null;

  Future<void> start(FieldVisit visit) async {
    _activeVisit = visit;
    _checkInLat = visit.checkInLat;
    _checkInLng = visit.checkInLng;
    await _recordPing('check_in');
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _recordPing('location_ping');
    });
  }

  Future<void> stop() async {
    await _recordPing('check_out');
    _timer?.cancel();
    _timer = null;
    _activeVisit = null;
  }

  Future<void> _recordPing(String eventType) async {
    final visit = _activeVisit;
    if (visit == null) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final distance = Geolocator.distanceBetween(
        _checkInLat,
        _checkInLng,
        pos.latitude,
        pos.longitude,
      );
      final isGeofenceAlert = distance > geofenceAlertMeters;
      final previousLog = visit.id == null
          ? null
          : await _db.getLatestGpsLogForVisit(visit.id!);

      await _db.addGpsLog(
        GpsLog(
          visitId: visit.id ?? 0,
          meetingId: visit.meetingId,
          employeeId: visit.employeeId,
          employeeName: visit.employeeName,
          recordedAt: DateTime.now().toIso8601String(),
          latitude: pos.latitude,
          longitude: pos.longitude,
          accuracy: pos.accuracy,
          distanceFromCheckIn: distance,
          isGeofenceAlert: isGeofenceAlert,
        ),
      );

      final baseUrl = await _config.getCrmApiBaseUrl();
      final token = await _config.getAccessToken();
      final sessionJson = await _config.getSessionUserJson();
      if (baseUrl.isNotEmpty && token.isNotEmpty && sessionJson.isNotEmpty) {
        final session = jsonDecode(sessionJson) as Map<String, dynamic>;
        final employeeExternalId = session['externalId']?.toString() ?? '';
        final role = session['role']?.toString() ?? '';
        if (role == 'Employee' &&
            employeeExternalId.isNotEmpty &&
            await _remote.isConfigured()) {
          await _remote.createEvent(
            externalId:
                '${visit.leadId}_${DateTime.now().millisecondsSinceEpoch}_$eventType',
            employeeExternalId: employeeExternalId,
            leadExternalId: visit.leadId,
            eventType: eventType,
            latitude: pos.latitude,
            longitude: pos.longitude,
            accuracy: pos.accuracy,
            notes:
                '${visit.employeeName}|${distance.round()}|${isGeofenceAlert ? 'alert' : 'ok'}',
          );
        }
      }

      if (isGeofenceAlert &&
          (previousLog == null || !previousLog.isGeofenceAlert)) {
        await AlertService.createRoleAlert(
          title: 'Geofence Alert',
          body:
              '${visit.employeeName} moved ${distance.round()}m away from check-in for ${visit.leadId}',
          targetRole: 'Admin',
          relatedType: 'gps',
          relatedId: visit.id,
        );
      }
    } catch (_) {}
  }
}