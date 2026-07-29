import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/queued_report_upload.dart';
import '../services/auth_service.dart';
import '../services/offline_report_queue_service.dart';
import '../theme.dart';

class OfflineQueueScreen extends StatefulWidget {
  const OfflineQueueScreen({super.key});

  @override
  State<OfflineQueueScreen> createState() => _OfflineQueueScreenState();
}

class _OfflineQueueScreenState extends State<OfflineQueueScreen> {
  final _queueService = OfflineReportQueueService();
  Timer? _autoRefreshTimer;

  List<QueuedReportUpload> _items = [];
  QueueSyncSnapshot _snapshot = const QueueSyncSnapshot(
    pendingCount: 0,
    lastRetryAt: '',
    state: QueueSyncState.idle,
    message: '',
  );
  bool _loading = true;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _loading || _retrying) {
        return;
      }
      unawaited(_loadQueue(silent: true));
    });
  }

  Future<void> _loadQueue({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }

    final auth = context.read<AuthService>();
    final employeeExternalId =
        auth.currentUser?.isAdmin == true ? null : auth.currentUser?.externalId;
    final items = await _queueService.getPendingUploads(
      employeeExternalId: employeeExternalId,
    );
    final snapshot = await _queueService.getSyncSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _snapshot = snapshot;
      _loading = false;
    });
  }

  Future<void> _retryNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthService>();
    final employeeExternalId =
        auth.currentUser?.isAdmin == true ? null : auth.currentUser?.externalId;
    setState(() => _retrying = true);
    final result = await _queueService.retryPendingUploads(
      employeeExternalId: employeeExternalId,
    );
    if (!mounted) {
      return;
    }
    await _loadQueue(silent: true);
    if (!mounted) {
      return;
    }
    setState(() => _retrying = false);
    final message = result.busy
        ? 'Retry is already running.'
        : result.attempted == 0
            ? 'No queued reports to retry.'
            : 'Retried ${result.attempted}: ${result.succeeded} sent, ${result.failed} still pending.';
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final title =
        user?.isAdmin == true ? 'Offline Upload Queue' : 'My Pending Uploads';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _retrying ? null : _retryNow,
            icon: _retrying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Retry now',
          ),
          IconButton(
            onPressed: () => _loadQueue(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadQueue,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 12),
                  if (_items.isEmpty)
                    _buildEmptyState()
                  else
                    ..._buildQueueList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final config = _statusVisual(_snapshot.state);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: config.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(config.icon, color: config.foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config.title,
                  style: TextStyle(
                    color: config.foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${_snapshot.pendingCount} pending',
                style: TextStyle(
                  color: config.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _snapshot.message.isEmpty
                ? 'The queue is waiting for the next retry cycle.'
                : _snapshot.message,
            style: TextStyle(color: Colors.grey.shade800, height: 1.4),
          ),
          const SizedBox(height: 6),
          Text(
            _snapshot.lastRetryAt.isEmpty
                ? 'Last retry: not yet attempted'
                : 'Last retry: ${_snapshot.lastRetryAt.replaceFirst('T', ' ')}',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Auto-refresh every 6 seconds while this screen is open.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildQueueList() {
    return _items.map(_buildQueueCard).toList(growable: false);
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_done_outlined, size: 40, color: AppTheme.success),
            SizedBox(height: 12),
            Text(
              'No pending offline report uploads.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(QueuedReportUpload item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.externalId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Retry ${item.retryCount}',
                    style: const TextStyle(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Queued at ${item.queuedAt.replaceFirst('T', ' ')}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              'Employee: ${item.employeeExternalId}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (item.lastError.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.lastError,
                  style: const TextStyle(color: AppTheme.error),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusVisual _statusVisual(QueueSyncState state) {
    switch (state) {
      case QueueSyncState.waiting:
        return _StatusVisual(
          title: 'Waiting to Sync',
          icon: Icons.wifi_off_outlined,
          foreground: AppTheme.warning,
          background: AppTheme.warning.withValues(alpha: 0.10),
          border: AppTheme.warning.withValues(alpha: 0.35),
        );
      case QueueSyncState.healthy:
        return _StatusVisual(
          title: 'Sync Healthy',
          icon: Icons.cloud_done_outlined,
          foreground: AppTheme.success,
          background: AppTheme.success.withValues(alpha: 0.10),
          border: AppTheme.success.withValues(alpha: 0.35),
        );
      case QueueSyncState.degraded:
        return _StatusVisual(
          title: 'Retry Needed',
          icon: Icons.error_outline,
          foreground: AppTheme.error,
          background: AppTheme.error.withValues(alpha: 0.08),
          border: AppTheme.error.withValues(alpha: 0.25),
        );
      case QueueSyncState.idle:
        return _StatusVisual(
          title: 'Queue Idle',
          icon: Icons.schedule_outlined,
          foreground: AppTheme.primary,
          background: AppTheme.primary.withValues(alpha: 0.08),
          border: AppTheme.primary.withValues(alpha: 0.20),
        );
    }
  }
}

class _StatusVisual {
  final String title;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;

  const _StatusVisual({
    required this.title,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });
}
