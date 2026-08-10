import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/lead.dart';
import '../models/meeting.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme.dart';

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

    Meeting? scheduled;
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

      scheduled = meeting;
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

    if (scheduled == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting scheduled successfully')),
    );
    // The meeting is already saved; notifying is optional and never blocks it.
    await _promptNotifyClient(scheduled);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _promptNotifyClient(Meeting meeting) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifyClientSheet(
        meeting: meeting,
        clientPhone: widget.lead.phone,
      ),
    );
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

enum _MessageLanguage { bangla, english }

/// Offers the employee an optional confirmation message to send the client
/// after a meeting is scheduled, in Bangla or English.
class _NotifyClientSheet extends StatefulWidget {
  final Meeting meeting;
  final String clientPhone;

  const _NotifyClientSheet({required this.meeting, required this.clientPhone});

  @override
  State<_NotifyClientSheet> createState() => _NotifyClientSheetState();
}

class _NotifyClientSheetState extends State<_NotifyClientSheet> {
  _MessageLanguage _language = _MessageLanguage.bangla;
  bool _sending = false;

  /// Digits only, keeping a leading '+' so international numbers survive.
  String get _dialablePhone {
    final raw = widget.clientPhone.trim();
    final cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.startsWith('+')) {
      return '+${cleaned.substring(1).replaceAll('+', '')}';
    }
    return cleaned.replaceAll('+', '');
  }

  bool get _hasPhone => _dialablePhone.isNotEmpty;

  String get _message {
    final when = DateTime.tryParse(widget.meeting.scheduledAt);
    // Explicitly unlocalised: Bangla date symbols would need
    // initializeDateFormatting, and this format is unambiguous either way.
    final date =
        when == null ? '' : DateFormat('EEE, dd MMM yyyy').format(when);
    final time = when == null ? '' : DateFormat('hh:mm a').format(when);
    final location = widget.meeting.location.trim();
    final notes = widget.meeting.notes.trim();

    if (_language == _MessageLanguage.bangla) {
      final buffer = StringBuffer()
        ..writeln('প্রিয় ${widget.meeting.clientName},')
        ..writeln()
        ..writeln(
          '${widget.meeting.employeeName} এর সাথে আপনার মিটিং নিশ্চিত করা হয়েছে।',
        )
        ..writeln('তারিখ: $date')
        ..writeln('সময়: $time');
      if (location.isNotEmpty) buffer.writeln('স্থান: $location');
      if (notes.isNotEmpty) {
        buffer
          ..writeln()
          ..writeln('বিশেষ দ্রষ্টব্য: $notes');
      }
      buffer
        ..writeln()
        ..write('ধন্যবাদ।');
      return buffer.toString();
    }

    final buffer = StringBuffer()
      ..writeln('Dear ${widget.meeting.clientName},')
      ..writeln()
      ..writeln(
        'Your meeting with ${widget.meeting.employeeName} is confirmed.',
      )
      ..writeln('Date: $date')
      ..writeln('Time: $time');
    if (location.isNotEmpty) buffer.writeln('Location: $location');
    if (notes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Note: $notes');
    }
    buffer
      ..writeln()
      ..write('Thank you.');
    return buffer.toString();
  }

  void _report(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendSms() async {
    if (!_hasPhone) return;
    setState(() => _sending = true);
    try {
      // iOS expects '&body=' after the number; Android expects '?body='.
      final separator = Platform.isIOS ? '&' : '?';
      final uri = Uri.parse(
        'sms:$_dialablePhone${separator}body=${Uri.encodeComponent(_message)}',
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _report('Could not open the SMS app. Try Share instead.');
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (exc) {
      _report('Could not open the SMS app: $exc');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sending = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _message,
          subject: 'Meeting confirmation',
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (exc) {
      _report('Could not open the share sheet: $exc');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.campaign_outlined,
                        color: AppTheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notify ${widget.meeting.clientName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _hasPhone
                      ? 'Sending to $_dialablePhone'
                      : 'This lead has no phone number — use Share instead.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _hasPhone ? Colors.grey.shade700 : AppTheme.warning,
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedButton<_MessageLanguage>(
                  segments: const [
                    ButtonSegment(
                      value: _MessageLanguage.bangla,
                      label: Text('বাংলা'),
                    ),
                    ButtonSegment(
                      value: _MessageLanguage.english,
                      label: Text('English'),
                    ),
                  ],
                  selected: {_language},
                  onSelectionChanged: (selection) =>
                      setState(() => _language = selection.first),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _message,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: (_sending || !_hasPhone) ? null : _sendSms,
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Send SMS'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _sending ? null : _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share (WhatsApp / other)'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed:
                      _sending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Skip for now'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}