import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/offline_report_queue_service.dart';
import 'employee_leads_screen.dart';
import 'meetings_screen.dart';
import 'offline_queue_screen.dart';
import 'reports_screen.dart';

class EmployeeShellScreen extends StatefulWidget {
  const EmployeeShellScreen({super.key});

  @override
  State<EmployeeShellScreen> createState() => _EmployeeShellScreenState();
}

class _EmployeeShellScreenState extends State<EmployeeShellScreen> {
  final _offlineQueue = OfflineReportQueueService();
  int _selectedIndex = 0;
  int _pendingUploads = 0;

  static const _screens = [
    EmployeeLeadsScreen(),
    MeetingsScreen(adminMode: false),
    ReportsScreen(adminMode: false),
    _EmployeeUploadsTab(),
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
    final employeeExternalId =
        context.read<AuthService>().currentUser?.externalId;
    final count = await _offlineQueue.getPendingCount(
      employeeExternalId: employeeExternalId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _pendingUploads = count);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text('Employee - ' + (user?.fullName ?? '')),
        actions: [
          IconButton(
            icon: _buildQueueBadgeIcon(),
            onPressed: () => setState(() => _selectedIndex = 3),
            tooltip: 'Pending uploads',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_ind_outlined),
            selectedIcon: Icon(Icons.assignment_ind),
            label: 'Assigned Leads',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available),
            label: 'Meetings',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_upload_outlined),
            selectedIcon: Icon(Icons.cloud_upload),
            label: 'Uploads',
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                _pendingUploads > 99 ? '99+' : '$_pendingUploads',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmployeeUploadsTab extends StatelessWidget {
  const _EmployeeUploadsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Uploads',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'If report upload fails because of network or server delay, it will stay here and retry again.',
                style: TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        const Expanded(child: OfflineQueueScreen()),
      ],
    );
  }
}