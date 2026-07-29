import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/lead.dart';
import '../services/barikoi_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class NavigationScreen extends StatefulWidget {
  final Lead lead;

  const NavigationScreen({super.key, required this.lead});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final _db = DatabaseService();
  final _mapController = MapController();

  late Lead _lead;
  bool _isTracking = false;
  bool _isLoading = false;
  double? _distanceMeters;
  Position? _currentPosition;
  double? _destLat;
  double? _destLng;
  String _currentPlaceLabel = '';
  String _destinationLabel = '';
  String _geocodeSource = '';
  String _statusMsg = '';
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _destLat = _lead.latitude;
    _destLng = _lead.longitude;
    if (_lead.address.isNotEmpty || _lead.location.isNotEmpty) {
      _destinationLabel =
          _lead.address.isNotEmpty ? _lead.address : _lead.location;
    }
    _getCurrentLocation();
  }

  @override
  void dispose() {
    if (_isTracking) {
      LocationService.stopTracking();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;

    if (pos != null) {
      await _resolveCurrentPlace(pos);
    }

    setState(() {
      _currentPosition = pos;
      _isLoading = false;
    });
    _syncMapCamera();
  }

  Future<void> _resolveCurrentPlace(Position position) async {
    final place = await BarikoiService.reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (!mounted || place == null) return;
    setState(() {
      _currentPlaceLabel = place.displayLabel;
    });
  }

  Future<void> _geocodeAndStart() async {
    final address = _lead.address.isNotEmpty ? _lead.address : _lead.location;

    if (address.isEmpty) {
      setState(() => _errorMsg =
          'No address found for this lead.\nPlease add an address in the lead details first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMsg = '';
      _statusMsg = 'Finding location for: $address...';
    });

    double? latitude;
    double? longitude;

    if (_lead.latitude != null && _lead.longitude != null) {
      latitude = _lead.latitude;
      longitude = _lead.longitude;
      _destinationLabel = address;
      _geocodeSource = 'Saved coordinates';
    } else {
      final barikoiPlace = await BarikoiService.geocodeAddress(address);
      if (barikoiPlace != null) {
        latitude = barikoiPlace.latitude;
        longitude = barikoiPlace.longitude;
        _destinationLabel = barikoiPlace.displayLabel;
        _geocodeSource = barikoiPlace.source;
      } else {
        final fallback = await LocationService.geocodeAddress(address);
        if (fallback != null) {
          latitude = fallback['lat'];
          longitude = fallback['lng'];
          _destinationLabel = address;
          _geocodeSource = 'Device geocoding fallback';
        }
      }
    }

    if (latitude == null || longitude == null) {
      setState(() {
        _isLoading = false;
        _errorMsg =
            'Could not find coordinates for "$address".\nTry a more specific address.';
        _statusMsg = '';
      });
      return;
    }

    _destLat = latitude;
    _destLng = longitude;

    if (_lead.id != null) {
      final startedAt = DateTime.now().toString().substring(0, 19);
      await _db.updateLeadSurveyLocation(
        id: _lead.id!,
        latitude: _destLat!,
        longitude: _destLng!,
      );
      await _db.updateSurveyStatus(
        id: _lead.id!,
        surveyStatus: 'In Progress',
        surveyStartedAt: startedAt,
      );
      _lead = _lead.copyWith(
        latitude: _destLat,
        longitude: _destLng,
        surveyStatus: 'In Progress',
        surveyStartedAt: startedAt,
      );
    }

    final started = await LocationService.startTracking(
      leadId: _lead.leadId,
      leadName: _lead.name,
      address: address,
      lat: _destLat!,
      lng: _destLng!,
      onArrivalCallback: _onArrived,
    );

    if (!mounted) return;

    if (started) {
      _startDistanceUpdates();
      setState(() {
        _isTracking = true;
        _isLoading = false;
        _statusMsg =
            'Navigating to: ${_destinationLabel.isNotEmpty ? _destinationLabel : address}';
      });
      _syncMapCamera();
    } else {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Location permission denied. Please allow location access.';
      });
    }
  }

  void _startDistanceUpdates() {
    Future.doWhile(() async {
      if (!_isTracking || !mounted) return false;

      final pos = await LocationService.getCurrentPosition();
      double? distance;
      if (pos != null && _destLat != null && _destLng != null) {
        distance = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          _destLat!,
          _destLng!,
        );
      }

      if (!mounted) return false;

      setState(() {
        _currentPosition = pos;
        _distanceMeters = distance;
      });
      _syncMapCamera();

      await Future.delayed(const Duration(seconds: 5));
      return _isTracking && mounted;
    });
  }

  Future<void> _onArrived(String leadId, String leadName) async {
    if (!mounted) return;

    final arrivedAt = DateTime.now().toString().substring(0, 19);
    final distance = _distanceMeters ?? 0;

    if (_lead.id != null) {
      await _db.updateSurveyStatus(
        id: _lead.id!,
        surveyStatus: 'Completed',
        surveyArrivedAt: arrivedAt,
        surveyDistanceMeters: distance,
        surveyNote: 'Auto verified by GPS arrival radius.',
      );
      _lead = _lead.copyWith(
        surveyStatus: 'Completed',
        surveyArrivedAt: arrivedAt,
        surveyDistanceMeters: distance,
        surveyNote: 'Auto verified by GPS arrival radius.',
      );
    }

    await NotificationService.showSurveyArrival(
      leadId: _lead.leadId,
      leadName: _lead.name,
      address: _lead.address.isNotEmpty ? _lead.address : _lead.location,
    );

    if (!mounted) return;

    setState(() {
      _isTracking = false;
      _statusMsg = 'Arrived';
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Survey location reached'),
        content: Text(
          'You are now near ${_lead.name.isNotEmpty ? _lead.name : "the customer"}\'s location.\n\nThis survey visit has been marked completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
            child: const Text('Back to Lead'),
          ),
        ],
      ),
    );
  }

  void _stopTracking() {
    LocationService.stopTracking();
    setState(() {
      _isTracking = false;
      _distanceMeters = null;
      _statusMsg = '';
    });
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  List<LatLng> _linePoints() {
    if (_currentPosition == null || _destLat == null || _destLng == null) {
      return const [];
    }
    return [
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      LatLng(_destLat!, _destLng!),
    ];
  }

  void _syncMapCamera() {
    final current = _currentPosition == null
        ? null
        : LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    final destination = _destLat == null || _destLng == null
        ? null
        : LatLng(_destLat!, _destLng!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (current != null && destination != null) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: [current, destination],
            padding: const EdgeInsets.all(48),
          ),
        );
      } else if (current != null) {
        _mapController.move(current, 15);
      } else if (destination != null) {
        _mapController.move(destination, 15);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final linePoints = _linePoints();
    final mapCenter = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_destLat != null && _destLng != null)
            ? LatLng(_destLat!, _destLng!)
            : const LatLng(23.8103, 90.4125);

    return Scaffold(
      appBar: AppBar(
        title: Text(_lead.leadId),
        actions: [
          if (_isTracking)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _stopTracking,
              tooltip: 'Stop navigation',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.place_outlined, color: AppTheme.accent),
                        SizedBox(width: 8),
                        Text(
                          'Navigate to Customer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                        'Name', _lead.name.isNotEmpty ? _lead.name : 'Unknown'),
                    const SizedBox(height: 6),
                    _infoRow('Address',
                        _lead.address.isNotEmpty ? _lead.address : '-'),
                    const SizedBox(height: 6),
                    _infoRow('Area',
                        _lead.location.isNotEmpty ? _lead.location : '-'),
                    const SizedBox(height: 6),
                    _infoRow(
                        'Phone', _lead.phone.isNotEmpty ? _lead.phone : '-'),
                    const SizedBox(height: 6),
                    _infoRow('Survey', _lead.surveyStatus),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: 280,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bangla_voice_crm',
                    ),
                    if (linePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: linePoints,
                            strokeWidth: 5,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 56,
                            height: 56,
                            child: _mapPin(
                              icon: Icons.my_location,
                              color: AppTheme.primary,
                              label: 'You',
                            ),
                          ),
                        if (_destLat != null && _destLng != null)
                          Marker(
                            point: LatLng(_destLat!, _destLng!),
                            width: 64,
                            height: 64,
                            child: _mapPin(
                              icon: Icons.location_on,
                              color: AppTheme.error,
                              label: 'Lead',
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.map_outlined, color: AppTheme.accent),
                        SizedBox(width: 8),
                        Text(
                          'Barikoi Location Intelligence',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      'Current place',
                      _currentPlaceLabel.isNotEmpty
                          ? _currentPlaceLabel
                          : 'Waiting for current position',
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      'Destination',
                      _destinationLabel.isNotEmpty
                          ? _destinationLabel
                          : (_lead.address.isNotEmpty
                              ? _lead.address
                              : _lead.location),
                    ),
                    const SizedBox(height: 6),
                    _infoRow(
                      'Geo source',
                      _geocodeSource.isNotEmpty
                          ? _geocodeSource
                          : 'Not resolved yet',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isTracking) ...[
              Card(
                color: AppTheme.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.navigation,
                          color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        _distanceMeters != null
                            ? _formatDistance(_distanceMeters!)
                            : 'Calculating...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'away from destination',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      if (_distanceMeters != null)
                        Text(
                          _distanceMeters! <= 100
                              ? 'Almost there'
                              : 'On the way',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_distanceMeters != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _distanceMeters! <= 100
                                  ? 'Arrived'
                                  : '${_distanceMeters!.round()}m remaining',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _distanceMeters! <= 0
                                ? 1.0
                                : (1 - (_distanceMeters! / 5000))
                                    .clamp(0.0, 1.0),
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _distanceMeters! <= 100
                                  ? AppTheme.success
                                  : AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Navigating to',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            _destinationLabel.isNotEmpty
                                ? _destinationLabel
                                : _statusMsg,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _stopTracking,
                icon: const Icon(Icons.stop, color: Colors.red),
                label: const Text(
                  'Stop Navigation',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
            if (_errorMsg.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!_isTracking) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _geocodeAndStart,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.navigation, size: 22),
                label: Text(
                  _isLoading ? 'Finding location...' : 'Start Navigation',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. Tap Start Navigation',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                    Text(
                      '2. Barikoi resolves the survey destination when possible',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                    Text(
                      '3. The app tracks your GPS location and shows it on the map',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                    Text(
                      '4. When you arrive within 100m, the survey is auto-completed',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            if (_currentPosition != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Your location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _mapPin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }
}
