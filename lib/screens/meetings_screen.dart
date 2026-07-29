import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meeting.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'meeting_detail_screen.dart';

class MeetingsScreen extends StatefulWidget {
  final bool adminMode;
  const MeetingsScreen({super.key, required this.adminMode});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<Meeting> _meetings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthService>().currentUser;
    setState(() => _loading = true);
    final meetings = await _db.getMeetings(
      employeeId: widget.adminMode ? null : user?.id,
    );
    if (!mounted) return;
    setState(() {
      _meetings = meetings;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.adminMode ? 'All Meetings' : 'My Meetings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _meetings.isEmpty
              ? Center(
                  child: Text(
                    widget.adminMode
                        ? 'No meetings have been scheduled yet.'
                        : 'You do not have any upcoming meetings.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _meetings.length,
                    itemBuilder: (_, index) {
                      final meeting = _meetings[index];
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetingDetailScreen(
                                meeting: meeting,
                                adminMode: widget.adminMode,
                              ),
                            ),
                          ).then((_) => _load()),
                          title: Text(meeting.clientName),
                          subtitle: Text(
                            '${meeting.location}\n${meeting.scheduledAt.replaceFirst('T', ' ')}\n${meeting.employeeName}',
                            style: const TextStyle(height: 1.5),
                          ),
                          trailing: Chip(label: Text(meeting.status)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
