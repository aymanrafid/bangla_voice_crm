import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/offline_report_queue_service.dart';
import 'alerts_screen.dart';
import 'command_center_screen.dart';
import 'company_management_screen.dart';
import 'dashboard_screen.dart';
import 'live_monitor_screen.dart';
import 'meetings_screen.dart';
import 'offline_queue_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'survey_report_screen.dart';
import 'text_input_screen.dart';
import 'user_management_screen.dart';
import 'voice_input_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  final _offlineQueue = OfflineReportQueueService();
  int _selectedIndex = 0;
  int _pendingUploads = 0;

  static const _screens = [
    VoiceInputScreen(),
    DashboardScreen(),
    MeetingsScreen(adminMode: true),
    LiveMonitorScreen(),
    SurveyReportScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadPendingUploads();
  }

  Future<void> _logout() async {
    await context.read<AuthService>().logout();
  }

  Future<void> _loadPendingUploads() async {
    final count = await _offlineQueue.getPendingCount();
    if (!mounted) {
      return;
    }
    setState(() => _pendingUploads = count);
  }

  Future<void> _openQueueScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OfflineQueueScreen()),
    );
    await _loadPendingUploads();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final companyLabel = user?.companyName.isNotEmpty == true
        ? user!.companyName
        : 'Local Demo Company';

    return Scaffold(
      appBar: AppBar(
        title: Text('${user?.role ?? 'Admin'} · ${user?.fullName ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          IconButton(
            icon: _buildQueueBadgeIcon(),
            onPressed: _openQueueScreen,
            tooltip: 'Pending uploads',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.fullName ?? ''),
              accountEmail: Text(
                '${user?.username ?? ''}\n$companyLabel',
              ),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  (user?.fullName.isNotEmpty == true
                          ? user!.fullName.characters.first
                          : 'A')
                      .toUpperCase(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Text Input'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TextInputScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Command Center'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CommandCenterScreen()),
              ),
            ),
            if (user?.isSuperAdmin ?? false)
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Company Management'),
                subtitle: const Text('Provision company workspaces'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CompanyManagementScreen(),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('Users & Roles'),
              subtitle: Text(companyLabel),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Offline Upload Queue'),
              trailing: _pendingUploads > 0 ? _buildCountChip() : null,
              onTap: _openQueueScreen,
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('All Reports'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportsScreen(adminMode: true),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic_none),
            selectedIcon: Icon(Icons.mic),
            label: 'Voice',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Meetings',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_searching_outlined),
            selectedIcon: Icon(Icons.location_searching),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_turned_in_outlined),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Survey',
          ),
        ],
      ),
    );
  }

  Widget _buildQueueBadgeIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.cloud_upload_outlined),
        if (_pendingUploads > 0)
          Positioned(
            right: -6,
            top: -6,
            child: _buildCountChip(compact: true),
          ),
      ],
    );
  }

  Widget _buildCountChip({bool compact = false}) {
    final label = _pendingUploads > 99 ? '99+' : '$_pendingUploads';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: BoxConstraints(minWidth: compact ? 18 : 28),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
