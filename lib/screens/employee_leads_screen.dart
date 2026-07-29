import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/lead_remote_service.dart';
import 'lead_detail_screen.dart';
import 'meeting_form_screen.dart';

class EmployeeLeadsScreen extends StatefulWidget {
  const EmployeeLeadsScreen({super.key});

  @override
  State<EmployeeLeadsScreen> createState() => _EmployeeLeadsScreenState();
}

class _EmployeeLeadsScreenState extends State<EmployeeLeadsScreen> {
  final _db = DatabaseService();
  final _remote = LeadRemoteService();
  bool _loading = true;
  List<Lead> _leads = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    List<Lead> leads;
    if (context.read<AuthService>().isRemoteMode &&
        await _remote.isConfigured()) {
      leads = await _remote.getLeads(
        assignedUserExternalId: user.externalId,
      );
    } else {
      leads = await _db.getLeadsForEmployee(user.id!);
    }
    if (!mounted) return;
    setState(() {
      _leads = leads;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_leads.isEmpty) {
      return Center(
        child: Text(
          'No assigned leads yet.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leads.length,
        itemBuilder: (_, index) {
          final lead = _leads[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.name.isEmpty ? lead.leadId : lead.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(lead.phone.isEmpty ? '-' : lead.phone),
                  const SizedBox(height: 4),
                  Text(lead.address.isEmpty ? lead.location : lead.address),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LeadDetailScreen(lead: lead),
                            ),
                          ).then((_) => _load()),
                          child: const Text('View Lead'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MeetingFormScreen(lead: lead),
                            ),
                          ).then((_) => _load()),
                          child: const Text('Schedule Meeting'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
