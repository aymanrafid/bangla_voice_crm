import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/field_visit.dart';
import '../models/meeting.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/field_tracking_service.dart';
import 'field_report_submission_screen.dart';
import 'report_detail_screen.dart';

class MeetingDetailScreen extends StatefulWidget {
  final Meeting meeting;
  final bool adminMode;
  const MeetingDetailScreen({
    super.key,
    required this.meeting,
    required this.adminMode,
  });

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  final _db = DatabaseService();
  FieldVisit? _activeVisit;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _activeVisit = await _db.getActiveVisitForMeeting(widget.meeting.id!);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<AppUser> _ensureLocalUser(AppUser user) {
    return _db.upsertUserByIdentity(
      AppUser(
        externalId: user.externalId,
        username: user.username,
        passwordHash: user.passwordHash,
        role: user.role,
        fullName: user.fullName,
        isActive: user.isActive,
        createdAt: user.createdAt,
      ),
    );
  }

  Future<Position> _requirePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Location service is turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required for check-in.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _checkIn() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      final localUser = await _ensureLocalUser(user);
      final pos = await _requirePosition();
      final visit = FieldVisit(
        meetingId: widget.meeting.id!,
        leadDbId: widget.meeting.leadDbId,
        leadId: widget.meeting.leadId,
        employeeId: localUser.id ?? 0,
        employeeName: localUser.fullName,
        checkInAt: DateTime.now().toIso8601String(),
        checkInLat: pos.latitude,
        checkInLng: pos.longitude,
        checkOutAt: '',
        checkOutLat: null,
        checkOutLng: null,
        durationMinutes: 0,
        status: 'Checked In',
      );
      final visitId = await _db.createFieldVisit(visit);
      await _db.updateMeetingStatus(widget.meeting.id!, 'Checked In');
      await FieldTrackingService().start(
        FieldVisit(
          id: visitId,
          meetingId: visit.meetingId,
          leadDbId: visit.leadDbId,
          leadId: visit.leadId,
          employeeId: visit.employeeId,
          employeeName: visit.employeeName,
          checkInAt: visit.checkInAt,
          checkInLat: visit.checkInLat,
          checkInLng: visit.checkInLng,
          checkOutAt: visit.checkOutAt,
          checkOutLat: visit.checkOutLat,
          checkOutLng: visit.checkOutLng,
          durationMinutes: visit.durationMinutes,
          status: visit.status,
        ),
      );
      await AlertService.createRoleAlert(
        title: 'Employee Check-In',
        body: '${localUser.fullName} checked in for ${widget.meeting.clientName}',
        targetRole: 'Admin',
        relatedType: 'visit',
        relatedId: visitId,
      );
      await _load();
    } catch (exc) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-in failed: $exc')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _checkOut() async {
    final visit = _activeVisit;
    if (visit == null || _busy) return;
    setState(() => _busy = true);
    try {
      final pos = await _requirePosition();
      final start = DateTime.parse(visit.checkInAt);
      final minutes = DateTime.now().difference(start).inMinutes;
      await _db.updateFieldVisitCheckout(
        visitId: visit.id!,
        checkOutAt: DateTime.now().toIso8601String(),
        checkOutLat: pos.latitude,
        checkOutLng: pos.longitude,
        durationMinutes: minutes,
      );
      await _db.updateMeetingStatus(widget.meeting.id!, 'Checked Out');
      await FieldTrackingService().stop();
      await AlertService.createRoleAlert(
        title: 'Employee Check-Out',
        body:
            '${visit.employeeName} checked out from ${widget.meeting.clientName}',
        targetRole: 'Admin',
        relatedType: 'visit',
        relatedId: visit.id,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FieldReportSubmissionScreen(
            meetingId: widget.meeting.id!,
            visit: FieldVisit(
              id: visit.id,
              meetingId: visit.meetingId,
              leadDbId: visit.leadDbId,
              leadId: visit.leadId,
              employeeId: visit.employeeId,
              employeeName: visit.employeeName,
              checkInAt: visit.checkInAt,
              checkInLat: visit.checkInLat,
              checkInLng: visit.checkInLng,
              checkOutAt: DateTime.now().toIso8601String(),
              checkOutLat: pos.latitude,
              checkOutLng: pos.longitude,
              durationMinutes: minutes,
              status: 'Checked Out',
            ),
            leadDbId: widget.meeting.leadDbId,
            leadId: widget.meeting.leadId,
          ),
        ),
      );
      await _load();
    } catch (exc) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Check-out failed: $exc')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openReport() async {
    final reports = await _db.getReports();
    final matching = reports
        .where((report) => report.meetingId == widget.meeting.id)
        .toList();
    if (matching.isEmpty || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(report: matching.first),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.meeting.clientName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(widget.meeting.clientName),
              subtitle: Text(
                '${widget.meeting.location}\n${widget.meeting.scheduledAt.replaceFirst('T', ' ')}\nAssigned: ${widget.meeting.employeeName}',
                style: const TextStyle(height: 1.5),
              ),
            ),
          ),
          if (widget.meeting.notes.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.meeting.notes),
              ),
            ),
          if (_activeVisit != null)
            Card(
              child: ListTile(
                title: const Text('Active Visit'),
                subtitle: Text(
                  'Check-in: ${_activeVisit!.checkInAt.replaceFirst('T', ' ')}',
                ),
              ),
            ),
          if (!widget.adminMode) ...[
            const SizedBox(height: 12),
            if (_activeVisit == null)
              ElevatedButton.icon(
                onPressed: _busy ? null : _checkIn,
                icon: const Icon(Icons.login),
                label: Text(_busy ? 'Please wait...' : 'Check In'),
              )
            else
              ElevatedButton.icon(
                onPressed: _busy ? null : _checkOut,
                icon: const Icon(Icons.logout),
                label: Text(
                  _busy ? 'Please wait...' : 'Check Out & Submit Report',
                ),
              ),
          ],
          if (widget.adminMode) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openReport,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Open Report'),
            ),
          ],
        ],
      ),
    );
  }
}