import 'package:flutter/material.dart';
import '../models/lead.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../theme.dart';
import 'lead_detail_screen.dart';

class SurveyReportScreen extends StatefulWidget {
  const SurveyReportScreen({super.key});

  @override
  State<SurveyReportScreen> createState() => _SurveyReportScreenState();
}

class _SurveyReportScreenState extends State<SurveyReportScreen> {
  final _db = DatabaseService();
  List<Lead> _leads = [];
  String _filter = 'All';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final leads = await _db.getSurveyLeads();
    setState(() {
      _leads = leads;
      _loading = false;
    });
  }

  List<Lead> get _filtered {
    if (_filter == 'All') return _leads;
    return _leads.where((lead) => lead.surveyStatus == _filter).toList();
  }

  Future<void> _export() async {
    if (_leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No survey data to export')),
      );
      return;
    }

    final path = await ExportService.exportSurveyReport(_leads);
    if (mounted && path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Survey report export ready')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed =
        _leads.where((lead) => lead.surveyStatus == 'Completed').length;
    final inProgress =
        _leads.where((lead) => lead.surveyStatus == 'In Progress').length;
    final pending =
        _leads.where((lead) => lead.surveyStatus == 'Not Started').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(
            total: _leads.length,
            completed: completed,
            inProgress: inProgress,
            pending: pending,
          ),
          const SizedBox(height: 12),
          _filterRow(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Survey Visits',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: _export,
                icon: const Icon(Icons.download),
                color: AppTheme.accent,
                tooltip: 'Export survey report',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filtered.isEmpty)
            _emptyState()
          else
            ..._filtered.map(_surveyCard),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required int total,
    required int completed,
    required int inProgress,
    required int pending,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Survey Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Track field visits, GPS arrivals, and pending surveys.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat('Total', '$total')),
              const SizedBox(width: 8),
              Expanded(child: _stat('Done', '$completed')),
              const SizedBox(width: 8),
              Expanded(child: _stat('Active', '$inProgress')),
              const SizedBox(width: 8),
              Expanded(child: _stat('Pending', '$pending')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    const filters = ['All', 'Not Started', 'In Progress', 'Completed'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filters.map((filter) {
        return ChoiceChip(
          label: Text(filter),
          selected: _filter == filter,
          onSelected: (_) => setState(() => _filter = filter),
        );
      }).toList(),
    );
  }

  Widget _surveyCard(Lead lead) {
    final address = lead.address.isNotEmpty ? lead.address : lead.location;
    final distance = lead.surveyDistanceMeters == null
        ? ''
        : '${lead.surveyDistanceMeters!.round()} m';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
        ).then((_) => _load()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lead.name.isEmpty
                          ? lead.leadId
                          : '${lead.name} (${lead.leadId})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  _statusChip(lead.surveyStatus),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address.isEmpty ? 'No address available' : address,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _tinyMetric('Started', lead.surveyStartedAt),
                  _tinyMetric('Arrived', lead.surveyArrivedAt),
                  _tinyMetric('Distance', distance),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tinyMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: ${value.isEmpty ? '-' : value}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = AppTheme.success;
        break;
      case 'in progress':
        color = AppTheme.warning;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No survey visits for this filter',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            'Open a lead with an address and start survey tracking.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
