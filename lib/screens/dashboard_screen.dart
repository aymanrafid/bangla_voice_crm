import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/lead_remote_service.dart';
import '../theme.dart';
import '../widgets/field_card.dart';
import 'lead_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _db = DatabaseService();
  final _remote = LeadRemoteService();
  final _searchCtrl = TextEditingController();

  List<Lead> _leads = [];
  List<Lead> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';
  String _priorityFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeads() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    List<Lead> leads;
    if (auth.isRemoteMode && await _remote.isConfigured()) {
      leads = await _remote.getLeads();
    } else {
      leads = await _db.getAllLeads();
    }
    if (!mounted) return;
    setState(() {
      _leads = leads;
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    setState(() {
      _filtered = _leads.where((lead) {
        final matchesSearch = query.isEmpty ||
            lead.name.toLowerCase().contains(query) ||
            lead.phone.contains(query) ||
            lead.location.toLowerCase().contains(query) ||
            lead.productInterest.toLowerCase().contains(query) ||
            lead.leadId.toLowerCase().contains(query) ||
            lead.intent.toLowerCase().contains(query) ||
            lead.aiSummary.toLowerCase().contains(query);
        final matchesPriority =
            _priorityFilter == 'All' || lead.priority == _priorityFilter;
        return matchesSearch && matchesPriority;
      }).toList();
    });
  }

  Future<void> _exportCsv() async {
    if (_leads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leads to export')),
      );
      return;
    }

    final exportPath = await ExportService.exportToCsv(_leads);
    if (mounted && exportPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV export ready!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatsHeader(),
        _buildSearchBar(),
        _buildPriorityFilters(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadLeads,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _buildLeadCard(_filtered[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    final total = _leads.length;
    final hotLeads = _leads.where((lead) => lead.priority == 'High').length;
    final supportCount =
        _leads.where((lead) => lead.leadType.contains('Support')).length;
    final avgScore = _leads.isEmpty
        ? 0
        : (_leads.map((lead) => lead.leadScore).reduce((a, b) => a + b) /
                _leads.length)
            .round();
    final frustrated =
        _leads.where((lead) => lead.sentiment == 'Frustrated').length;

    return Container(
      width: double.infinity,
      color: AppTheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _statTile('Total', '$total'),
              const SizedBox(width: 12),
              _statTile('Hot', '$hotLeads'),
              const SizedBox(width: 12),
              _statTile('Support', '$supportCount'),
              const Spacer(),
              _statTile('AI Score', '$avgScore'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _signalCard(
                  title: 'Frustrated Customers',
                  value: '$frustrated',
                  subtitle: 'Need careful follow-up',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _signalCard(
                  title: 'Priority Queue',
                  value: '$hotLeads',
                  subtitle: 'High-priority leads',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _signalCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (value) {
                _searchQuery = value;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search leads, intent, summary...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _applyFilters();
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadLeads,
            icon: const Icon(Icons.refresh),
            color: AppTheme.primary,
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _exportCsv,
            icon: const Icon(Icons.download),
            color: AppTheme.accent,
            tooltip: 'Export CSV',
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityFilters() {
    const filters = ['All', 'High', 'Medium', 'Normal'];
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) {
          return ChoiceChip(
            label: Text(filter),
            selected: _priorityFilter == filter,
            onSelected: (_) {
              _priorityFilter = filter;
              _applyFilters();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLeadCard(Lead lead) {
    final scoreColor = lead.leadScore >= 75
        ? AppTheme.success
        : lead.leadScore >= 55
            ? AppTheme.warning
            : AppTheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
        ).then((_) => _loadLeads()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LeadTypeBadge(leadType: lead.leadType),
                        PriorityBadge(priority: lead.priority),
                        SentimentBadge(sentiment: lead.sentiment),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Score ${lead.leadScore}',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                lead.name.isEmpty ? lead.leadId : lead.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(lead.phone.isEmpty ? '-' : lead.phone),
              if (lead.location.isNotEmpty || lead.address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(lead.address.isNotEmpty ? lead.address : lead.location),
              ],
              const SizedBox(height: 8),
              Text(
                lead.aiSummary.isEmpty ? lead.nextAction : lead.aiSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No leads found.',
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}
