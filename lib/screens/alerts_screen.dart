import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_alert.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _db = DatabaseService();
  bool _loading = true;
  List<AppAlert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    final alerts = await _db.getAlerts(role: user.role, userId: user.id);
    if (!mounted) return;
    setState(() {
      _alerts = alerts;
      _loading = false;
    });
  }

  Future<void> _markRead(AppAlert alert) async {
    if (!alert.isRead) {
      await _db.markAlertRead(alert.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _alerts.isEmpty
          ? Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _alerts.length,
                itemBuilder: (_, index) {
                  final alert = _alerts[index];
                  return Card(
                    color: alert.isRead
                        ? Colors.white
                        : AppTheme.primary.withValues(alpha: 0.05),
                    child: ListTile(
                      onTap: () => _markRead(alert),
                      title: Text(alert.title),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${alert.body}\n${alert.createdAt.replaceFirst('T', ' ')}',
                          style: const TextStyle(height: 1.5),
                        ),
                      ),
                      trailing: alert.isRead
                          ? const Icon(Icons.done_all, color: AppTheme.success)
                          : const Icon(Icons.mark_email_unread_outlined),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
