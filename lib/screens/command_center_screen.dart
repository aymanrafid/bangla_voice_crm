import 'package:flutter/material.dart';

import '../models/lead.dart';
import '../services/database_service.dart';
import '../theme.dart';
import '../widgets/field_card.dart';
import 'lead_detail_screen.dart';

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  final _db = DatabaseService();

  bool _loading = true;
  List<Lead> _leads = [];

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  Future<void> _loadLeads() async {
    setState(() => _loading = true);
    final leads = await _db.getAllLeads();
    if (!mounted) return;
    setState(() {
      _leads = leads;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final highPriority =
        _leads.where((lead) => lead.priority == 'High').toList();
    final frustrated = _leads
        .where((lead) =>
            lead.sentiment == 'Frustrated' || lead.sentiment == 'Negative')
        .toList();
    final conversionReady = _leads
        .where((lead) => lead.leadType == 'Sales Lead' && lead.leadScore >= 75)
        .toList();
    final intentCounts = _countBy(_leads, (lead) => lead.intent);
    final sentimentCounts = _countBy(_leads, (lead) => lead.sentiment);

    return Scaffold(
      appBar: AppBar(title: const Text('Command Center')),
      body: RefreshIndicator(
        onRefresh: _loadLeads,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _heroSummary(
              total: _leads.length,
              highPriority: highPriority.length,
              frustrated: frustrated.length,
              conversionReady: conversionReady.length,
            ),
            const SizedBox(height: 16),
            _sectionTitle('Live Queues'),
            const SizedBox(height: 10),
            _queueCard(
              title: 'High Priority Leads',
              subtitle: 'Needs same-day follow-up',
              leads: highPriority,
              emptyMessage: 'No high-priority leads right now.',
            ),
            const SizedBox(height: 12),
            _queueCard(
              title: 'Customer Risk Queue',
              subtitle: 'Negative or frustrated sentiment',
              leads: frustrated,
              emptyMessage: 'No risky customer conversations detected.',
            ),
            const SizedBox(height: 12),
            _queueCard(
              title: 'Conversion Ready',
              subtitle: 'High-score sales leads',
              leads: conversionReady,
              emptyMessage: 'No conversion-ready leads yet.',
            ),
            const SizedBox(height: 16),
            _sectionTitle('AI Breakdown'),
            const SizedBox(height: 10),
            _breakdownCard(
              title: 'Intent Mix',
              counts: intentCounts,
              emptyMessage: 'Create some leads to see intent analytics.',
            ),
            const SizedBox(height: 12),
            _breakdownCard(
              title: 'Sentiment Mix',
              counts: sentimentCounts,
              emptyMessage: 'Create some leads to see sentiment analytics.',
            ),
            const SizedBox(height: 16),
            _sectionTitle('Recommended Actions'),
            const SizedBox(height: 10),
            _actionsCard(_leads),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _heroSummary({
    required int total,
    required int highPriority,
    required int frustrated,
    required int conversionReady,
  }) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Command Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Monitor hot leads, customer risk, and next actions from one place.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _heroStat('Leads', '$total')),
              const SizedBox(width: 10),
              Expanded(child: _heroStat('Hot Queue', '$highPriority')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _heroStat('Customer Risk', '$frustrated')),
              const SizedBox(width: 10),
              Expanded(
                  child: _heroStat('Ready to Convert', '$conversionReady')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
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

  Widget _queueCard({
    required String title,
    required String subtitle,
    required List<Lead> leads,
    required String emptyMessage,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (leads.isEmpty)
              Text(
                emptyMessage,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            else
              ...leads.take(3).map(_leadRow),
          ],
        ),
      ),
    );
  }

  Widget _leadRow(Lead lead) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
      ).then((_) => _loadLeads()),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lead.name.isEmpty
                        ? lead.leadId
                        : '${lead.name} (${lead.leadId})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lead.nextAction.isNotEmpty
                        ? lead.nextAction
                        : lead.aiSummary,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PriorityBadge(priority: lead.priority),
          ],
        ),
      ),
    );
  }

  Widget _breakdownCard({
    required String title,
    required Map<String, int> counts,
    required String emptyMessage,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            if (counts.isEmpty)
              Text(
                emptyMessage,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            else
              ...counts.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade800),
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
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

  Widget _actionsCard(List<Lead> leads) {
    final recommended =
        leads.where((lead) => lead.nextAction.isNotEmpty).take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Action Suggestions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            if (recommended.isEmpty)
              Text(
                'No action suggestions yet. Save a few enriched leads to populate this area.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            else
              ...recommended.map(
                (lead) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FieldCard(
                    icon: '->',
                    label: lead.name.isEmpty ? lead.leadId : lead.name,
                    value: lead.nextAction,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, int> _countBy(List<Lead> leads, String Function(Lead) picker) {
    final counts = <String, int>{};
    for (final lead in leads) {
      final key = picker(lead).trim();
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entry in entries) entry.key: entry.value};
  }
}
