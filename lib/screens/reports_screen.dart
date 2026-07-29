import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/field_report.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/report_remote_service.dart';
import 'report_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  final bool adminMode;
  const ReportsScreen({super.key, required this.adminMode});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _db = DatabaseService();
  final _remote = ReportRemoteService();
  bool _loading = true;
  List<FieldReport> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    setState(() => _loading = true);
    if (auth.isRemoteMode && await _remote.isConfigured()) {
      final directory = <String, String>{};
      if (widget.adminMode) {
        final users = await auth.getUsers();
        directory.addEntries(
          users.map((AppUser u) => MapEntry(u.externalId, u.fullName)),
        );
      } else if (user != null && user.externalId.isNotEmpty) {
        directory[user.externalId] = user.fullName;
      }
      _reports = await _remote.getReports(
        employeeExternalId: widget.adminMode ? null : user?.externalId,
        userNames: directory,
      );
    } else {
      _reports =
          await _db.getReports(employeeId: widget.adminMode ? null : user?.id);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text(widget.adminMode ? 'All Reports' : 'My Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Text(
                    'No field reports yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    itemBuilder: (_, index) {
                      final report = _reports[index];
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ReportDetailScreen(report: report)),
                          ).then((_) => _load()),
                          title: Text(report.leadId),
                          subtitle: Text(
                            '${report.employeeName} - ${report.outcome}\n${report.submittedAt.replaceFirst('T', ' ')}',
                            style: const TextStyle(height: 1.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
