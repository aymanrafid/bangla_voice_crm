import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/field_visit.dart';
import '../models/gps_log.dart';
import '../models/tracking_event.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/tracking_remote_service.dart';
import '../theme.dart';

class LiveMonitorScreen extends StatefulWidget {
  const LiveMonitorScreen({super.key});

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final _db = DatabaseService();
  final _remote = TrackingRemoteService();
  bool _loading = true;
  bool _deleting = false;
  List<FieldVisit> _visits = [];
  final Map<int, List<GpsLog>> _visitLogs = {};
  List<TrackingEvent> _remoteEvents = [];
  Map<String, String> _userNames = {};
  Set<String> _employeeIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    if (auth.isRemoteMode && await _remote.isConfigured()) {
      final users = await auth.getUsers();
      final employees = users.where((AppUser u) => u.isEmployee).toList();
      _employeeIds = employees.map((user) => user.externalId).toSet();
      _userNames = {for (final AppUser u in employees) u.externalId: u.fullName};
      final remoteEvents = await _remote.getEvents();
      _remoteEvents = remoteEvents
          .where((event) => _employeeIds.contains(event.employeeExternalId))
          .toList();
      _visits = [];
      _visitLogs.clear();
    } else {
      final visits = await _db.getMonitoringVisits();
      final logsByVisit = <int, List<GpsLog>>{};
      for (final visit in visits) {
        if (visit.id == null) continue;
        logsByVisit[visit.id!] = await _db.getGpsLogsForVisit(visit.id!);
      }
      _visits = visits;
      _visitLogs
        ..clear()
        ..addAll(logsByVisit);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _deleteRemoteHistory(
    String employeeExternalId,
    String leadExternalId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Tracking History?'),
        content: Text('Delete saved monitoring history for $leadExternalId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _remote.deleteHistory(
        employeeExternalId: employeeExternalId,
        leadExternalId: leadExternalId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking history deleted')),
      );
      await _load();
    } catch (exc) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $exc')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<void> _deleteLocalVisit(FieldVisit visit) async {
    if (visit.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Tracking History?'),
        content: Text('Delete saved monitoring history for ${visit.leadId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await _db.deleteMonitoringVisit(visit.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracking history deleted')),
      );
      await _load();
    } catch (exc) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $exc')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final remoteMode = auth.isRemoteMode;
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Monitoring')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : remoteMode
              ? _buildRemoteBody()
              : _buildLocalBody(),
    );
  }

  Widget _buildRemoteBody() {
    if (_remoteEvents.isEmpty) {
      return Center(
        child: Text(
          'No employee tracking history yet.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    final grouped = <String, List<TrackingEvent>>{};
    for (final event in _remoteEvents) {
      final key = '${event.employeeExternalId}_${event.leadExternalId}';
      grouped.putIfAbsent(key, () => []).add(event);
    }

    final activeEntries = <MapEntry<String, List<TrackingEvent>>>[];
    final historyEntries = <MapEntry<String, List<TrackingEvent>>>[];
    for (final entry in grouped.entries) {
      final events = [...entry.value]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (events.isNotEmpty && events.last.eventType == 'check_out') {
        historyEntries.add(MapEntry(entry.key, events));
      } else {
        activeEntries.add(MapEntry(entry.key, events));
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(activeEntries.length, historyEntries.length),
          const SizedBox(height: 16),
          _sectionTitle('Active Employees'),
          const SizedBox(height: 10),
          if (activeEntries.isEmpty)
            _emptyCard('No active employee tracking session right now.')
          else
            ...activeEntries.map((entry) => _remoteVisitCard(entry.value, canDelete: false)),
          const SizedBox(height: 16),
          _sectionTitle('Saved Monitoring History'),
          const SizedBox(height: 10),
          if (historyEntries.isEmpty)
            _emptyCard('Completed employee tracking stays here until admin deletes it.')
          else
            ...historyEntries.map((entry) => _remoteVisitCard(entry.value, canDelete: true)),
        ],
      ),
    );
  }

  Widget _remoteVisitCard(List<TrackingEvent> events, {required bool canDelete}) {
    final first = events.first;
    final last = events.last;
    final points = events
        .map((event) => LatLng(event.latitude, event.longitude))
        .toList();
    final center = points.last;
    final employeeName =
        _userNames[first.employeeExternalId] ?? first.employeeExternalId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    employeeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: _deleting
                        ? null
                        : () => _deleteRemoteHistory(
                              first.employeeExternalId,
                              first.leadExternalId,
                            ),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete tracking history',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Lead: ${first.leadExternalId}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoPill('Events', '${events.length}'),
                _infoPill('First', first.eventType),
                _infoPill('Latest', last.eventType),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 240,
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.bangla_voice_crm',
                    ),
                    if (points.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 4,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: points.first,
                          width: 42,
                          height: 42,
                          child: const Icon(Icons.flag_circle,
                              color: AppTheme.success, size: 32),
                        ),
                        Marker(
                          point: points.last,
                          width: 42,
                          height: 42,
                          child: const Icon(Icons.person_pin_circle,
                              color: AppTheme.primary, size: 34),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalBody() {
    final activeVisits =
        _visits.where((visit) => visit.status == 'Checked In').toList();
    final completedVisits =
        _visits.where((visit) => visit.status != 'Checked In').toList();

    if (_visits.isEmpty) {
      return Center(
        child: Text(
          'No monitoring history yet.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(activeVisits.length, completedVisits.length),
          const SizedBox(height: 16),
          _sectionTitle('Active Employees'),
          const SizedBox(height: 10),
          if (activeVisits.isEmpty)
            _emptyCard('No active field session right now.')
          else
            ...activeVisits.map((visit) => _visitCard(visit, canDelete: false)),
          const SizedBox(height: 16),
          _sectionTitle('Saved Monitoring History'),
          const SizedBox(height: 10),
          if (completedVisits.isEmpty)
            _emptyCard('Completed visits stay here until admin deletes them.')
          else
            ...completedVisits.map((visit) => _visitCard(visit, canDelete: true)),
        ],
      ),
    );
  }

  Widget _summaryCard(int activeCount, int historyCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryStat('Active', '$activeCount')),
          const SizedBox(width: 12),
          Expanded(child: _summaryStat('Saved History', '$historyCount')),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _visitCard(FieldVisit visit, {required bool canDelete}) {
    final logs =
        visit.id == null ? <GpsLog>[] : (_visitLogs[visit.id!] ?? <GpsLog>[]);
    final latest = logs.isEmpty ? null : logs.last;
    final center = latest != null
        ? LatLng(latest.latitude, latest.longitude)
        : LatLng(visit.checkInLat, visit.checkInLng);
    final points = <LatLng>[
      LatLng(visit.checkInLat, visit.checkInLng),
      ...logs.map((log) => LatLng(log.latitude, log.longitude)),
      if (visit.checkOutLat != null && visit.checkOutLng != null)
        LatLng(visit.checkOutLat!, visit.checkOutLng!),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.employeeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (canDelete)
                  IconButton(
                    onPressed: _deleting ? null : () => _deleteLocalVisit(visit),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete tracking history',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Lead: ${visit.leadId}'),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 220,
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 15),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bangla_voice_crm',
                    ),
                    if (points.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: points,
                            strokeWidth: 4,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: points.first,
                          width: 42,
                          height: 42,
                          child: const Icon(Icons.flag_circle,
                              color: AppTheme.success, size: 32),
                        ),
                        Marker(
                          point: points.last,
                          width: 42,
                          height: 42,
                          child: const Icon(Icons.person_pin_circle,
                              color: AppTheme.primary, size: 34),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}