import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/lead.dart';
import '../models/meeting.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class MeetingFormScreen extends StatefulWidget {
  final Lead lead;
  const MeetingFormScreen({super.key, required this.lead});

  @override
  State<MeetingFormScreen> createState() => _MeetingFormScreenState();
}

class _MeetingFormScreenState extends State<MeetingFormScreen> {
  final _db = DatabaseService();
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime? _meetingDateTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _locationController.text = widget.lead.address.isNotEmpty
        ? widget.lead.address
        : widget.lead.location;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _meetingDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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

  Future<void> _save() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null || _meetingDateTime == null) {
      return;
    }
    setState(() => _saving = true);

    try {
      final localUser = await _ensureLocalUser(user);

      var localLeadId = widget.lead.id;
      if (localLeadId == null) {
        final existingLead = await _db.getLeadByLeadId(widget.lead.leadId);
        if (existingLead != null) {
          localLeadId = existingLead.id;
        } else {
          localLeadId = await _db.insertLead(
            widget.lead.copyWith(
              dateTime: widget.lead.dateTime.isEmpty
                  ? DateTime.now().toIso8601String()
                  : widget.lead.dateTime,
              assignedEmployeeId: localUser.id,
              assignedEmployeeName: localUser.fullName,
            ),
          );
        }
      }

      final meeting = Meeting(
        leadDbId: localLeadId ?? 0,
        leadId: widget.lead.leadId,
        clientName:
            widget.lead.name.isEmpty ? widget.lead.leadId : widget.lead.name,
        location: _locationController.text.trim(),
        scheduledAt: _meetingDateTime!.toIso8601String(),
        notes: _notesController.text.trim(),
        employeeId: localUser.id ?? 0,
        employeeName: localUser.fullName,
        status: 'Scheduled',
        createdAt: DateTime.now().toIso8601String(),
        adminNotifiedAt: DateTime.now().toIso8601String(),
      );
      final id = await _db.createMeeting(meeting);
      try {
        await AlertService.createRoleAlert(
          title: 'New Meeting Scheduled',
          body:
              '${localUser.fullName} scheduled a meeting with ${meeting.clientName} at ${meeting.location}',
          targetRole: 'Admin',
          relatedType: 'meeting',
          relatedId: id,
        );
      } catch (_) {
        // Keep meeting creation successful even if notifications fail.
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting scheduled successfully')),
      );
      Navigator.pop(context, true);
    } catch (exc) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Meeting save failed: $exc')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule Meeting')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            enabled: false,
            decoration: InputDecoration(
              labelText: 'Client',
              hintText: widget.lead.name.isEmpty
                  ? widget.lead.leadId
                  : widget.lead.name,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _meetingDateTime == null
                  ? 'Select date & time'
                  : _meetingDateTime!.toString().substring(0, 16),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save Meeting'),
          ),
        ],
      ),
    );
  }
}