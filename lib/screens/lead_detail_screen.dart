import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/lead.dart';
import '../models/lead_update_history.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/lead_remote_service.dart';
import '../theme.dart';
import '../widgets/field_card.dart';
import 'meeting_form_screen.dart';
import 'voice_lead_update_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late Lead _lead;
  final _db = DatabaseService();
  final _remote = LeadRemoteService();
  late Future<List<LeadUpdateHistory>> _historyFuture;
  List<AppUser> _employees = [];

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _historyFuture = _loadHistory();
    final currentUser = context.read<AuthService>().currentUser;
    if (currentUser?.isAdmin ?? false) {
      _loadEmployees();
    }
  }

  Future<List<LeadUpdateHistory>> _loadHistory() async {
    if (_lead.id == null) return [];
    return _db.getLeadUpdateHistory(_lead.id!);
  }

  Future<void> _loadEmployees() async {
    try {
      final auth = context.read<AuthService>();
      final users = await auth.getUsers();
      if (!mounted) return;
      setState(() {
        _employees =
            users.where((user) => user.isEmployee || user.isManager).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _employees = []);
    }
  }

  Future<void> _openVoiceUpdate() async {
    final updatedLead = await Navigator.push<Lead>(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceLeadUpdateScreen(lead: _lead),
      ),
    );

    if (updatedLead != null && mounted) {
      setState(() {
        _lead = updatedLead;
        _historyFuture = _loadHistory();
      });
    }
  }

  Future<void> _assignLead(AppUser employee) async {
    final auth = context.read<AuthService>();
    if (auth.isRemoteMode && await _remote.isConfigured()) {
      _lead = await _remote.assignLead(_lead, employee);
    } else {
      if (_lead.id == null || employee.id == null) return;
      await _db.assignLeadToEmployee(
        leadId: _lead.id!,
        employeeId: employee.id!,
        employeeName: employee.fullName,
      );
      _lead = _lead.copyWith(
        assignedEmployeeId: employee.id,
        assignedEmployeeName: employee.fullName,
      );
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Assigned to ${employee.fullName}')),
    );
  }

  Future<void> _updateStatus(String status) async {
    final auth = context.read<AuthService>();
    if (auth.isRemoteMode && await _remote.isConfigured()) {
      _lead = await _remote.updateStatus(_lead, status);
    } else {
      if (_lead.id == null) return;
      await _db.updateLeadStatus(_lead.id!, status);
      _lead = _lead.copyWith(status: status);
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to $status')),
    );
  }

  Future<void> _deleteLead() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Lead?'),
        content: Text('Delete ${_lead.leadId}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final auth = context.read<AuthService>();
    if (auth.isRemoteMode && await _remote.isConfigured()) {
      await _remote.deleteLead(_lead.leadId);
    } else if (_lead.id != null) {
      await _db.deleteLead(_lead.id!);
    }
    if (mounted) Navigator.pop(context);
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUser = auth.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;
    final isAssignedEmployee = currentUser != null &&
        ((currentUser.id != null &&
                _lead.assignedEmployeeId == currentUser.id) ||
            (currentUser.externalId.isNotEmpty &&
                _lead.assignedEmployeeExternalId == currentUser.externalId));
    final showLocalHistory = isAdmin && !auth.isRemoteMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_lead.leadId),
        actions: [
          if (isAdmin)
            IconButton(
              onPressed: _deleteLead,
              icon: const Icon(Icons.delete_outline),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LeadTypeBadge(leadType: _lead.leadType),
                        Text(
                          _lead.dateTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConfidenceBar(confidence: _lead.confidence),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PriorityBadge(priority: _lead.priority),
                        SentimentBadge(sentiment: _lead.sentiment),
                        _metricPill('Intent', _lead.intent),
                        _metricPill('AI Score', '${_lead.leadScore}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isAdmin) _buildAssignmentCard(),
            if (isAdmin) const SizedBox(height: 12),
            if (isAdmin)
              ElevatedButton.icon(
                onPressed: _openVoiceUpdate,
                icon: const Icon(Icons.mic_external_on_outlined, size: 20),
                label: const Text(
                  'Voice Update',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (isAdmin) const SizedBox(height: 12),
            if (isAssignedEmployee)
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingFormScreen(lead: _lead),
                  ),
                ),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Schedule Meeting'),
              ),
            if (isAssignedEmployee) const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Intelligence',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    FieldCard(
                        icon: 'AI', label: 'Summary', value: _lead.aiSummary),
                    const SizedBox(height: 8),
                    FieldCard(
                      icon: '->',
                      label: 'Recommended Next Action',
                      value: _lead.nextAction,
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
                    const Text(
                      'CRM Fields',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _copyableField('N', 'Name', _lead.name),
                    const SizedBox(height: 8),
                    _copyableField('P', 'Phone', _lead.phone),
                    const SizedBox(height: 8),
                    _copyableField('A', 'Address', _lead.address),
                    const SizedBox(height: 8),
                    _copyableField('L', 'Location', _lead.location),
                    const SizedBox(height: 8),
                    _copyableField('I', 'Product / Service Interest',
                        _lead.productInterest),
                    const SizedBox(height: 8),
                    FieldCard(
                      icon: 'AS',
                      label: 'Assigned Employee',
                      value: _lead.assignedEmployeeName,
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
                    const Text(
                      'Status',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['New', 'Contacted', 'Converted', 'Closed']
                          .map(
                            (status) => ChoiceChip(
                              label: Text(status,
                                  style: const TextStyle(fontSize: 13)),
                              selected: _lead.status == status,
                              onSelected: (_) => _updateStatus(status),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            if (showLocalHistory) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<List<LeadUpdateHistory>>(
                    future: _historyFuture,
                    builder: (context, snapshot) {
                      final history = snapshot.data ?? [];
                      if (history.isEmpty) {
                        return const Text('No voice update history yet.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update History',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          ...history.take(5).map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    '${item.fieldLabel}: ${item.oldValue} -> ${item.newValue}',
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ),
                              ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
            if (_lead.transcript.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Transcript',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () => _copyToClipboard(_lead.transcript),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _lead.transcript,
                          style: const TextStyle(fontSize: 14, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lead Assignment',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _lead.assignedEmployeeExternalId.isNotEmpty
                  ? _lead.assignedEmployeeExternalId
                  : null,
              items: _employees
                  .map(
                    (employee) => DropdownMenuItem<String>(
                      value: employee.externalId.isNotEmpty
                          ? employee.externalId
                          : employee.id?.toString() ?? '',
                      child: Text(employee.fullName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final employee = _employees.firstWhere(
                  (e) =>
                      (e.externalId.isNotEmpty
                          ? e.externalId
                          : e.id?.toString()) ==
                      value,
                );
                _assignLead(employee);
              },
              decoration:
                  const InputDecoration(labelText: 'Assign to employee'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyableField(String icon, String label, String value) {
    return GestureDetector(
      onLongPress: value.isEmpty ? null : () => _copyToClipboard(value),
      child: FieldCard(icon: icon, label: label, value: value),
    );
  }

  Widget _metricPill(String label, String value) {
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
