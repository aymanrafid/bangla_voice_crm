import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStream;
  static Position? _currentPosition;

  // Active destination tracking
  static String? _destinationAddress;
  static double? _destLat;
  static double? _destLng;
  static String? _destLeadId;
  static String? _destLeadName;
  static Function(String leadId, String leadName)? onArrival;

  static const double arrivalRadiusMeters = 100.0;

  /// Request location permissions
  static Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  /// Get current position
  static Future<Position?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  /// Get coordinates from address string
  static Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      List<Location> locations =
          await locationFromAddress('$address, Bangladesh');
      if (locations.isNotEmpty) {
        return {
          'lat': locations.first.latitude,
          'lng': locations.first.longitude
        };
      }
    } catch (e) {
      // Try without Bangladesh
      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          return {
            'lat': locations.first.latitude,
            'lng': locations.first.longitude
          };
        }
      } catch (_) {}
    }
    return null;
  }

  /// Start tracking toward a destination
  static Future<bool> startTracking({
    required String leadId,
    required String leadName,
    required String address,
    required double lat,
    required double lng,
    required Function(String leadId, String leadName) onArrivalCallback,
  }) async {
    final granted = await requestPermission();
    if (!granted) return false;

    _destLeadId = leadId;
    _destLeadName = leadName;
    _destinationAddress = address;
    _destLat = lat;
    _destLng = lng;
    onArrival = onArrivalCallback;

    await _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      _currentPosition = position;
      _checkArrival(position);
    });

    return true;
  }

  /// Stop tracking
  static Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _destLat = null;
    _destLng = null;
    _destLeadId = null;
    _destLeadName = null;
    _destinationAddress = null;
  }

  /// Check if arrived at destination
  static void _checkArrival(Position position) {
    if (_destLat == null || _destLng == null) return;

    final distance = _calculateDistance(
      position.latitude,
      position.longitude,
      _destLat!,
      _destLng!,
    );

    if (distance <= arrivalRadiusMeters) {
      final leadId = _destLeadId!;
      final leadName = _destLeadName!;
      stopTracking();
      onArrival?.call(leadId, leadName);
    }
  }

  /// Calculate distance between two coordinates in meters (Haversine formula)
  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  /// Get distance to current destination
  static Future<double?> getDistanceToDestination() async {
    if (_destLat == null || _destLng == null) return null;
    final pos = await getCurrentPosition();
    if (pos == null) return null;
    return _calculateDistance(
        pos.latitude, pos.longitude, _destLat!, _destLng!);
  }

  static bool get isTracking => _positionStream != null;
  static String? get trackingLeadName => _destLeadName;
  static String? get trackingAddress => _destinationAddress;
}
