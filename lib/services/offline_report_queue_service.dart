import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/field_report.dart';
import '../models/queued_report_upload.dart';
import 'report_remote_service.dart';

class OfflineReportQueueService {
  static const _storageKey = 'queued_report_uploads_v1';
  static const _lastRetryAtKey = 'queued_report_uploads_last_retry_at';
  static const _lastStatusKey = 'queued_report_uploads_last_status';
  static const _lastMessageKey = 'queued_report_uploads_last_message';
  static bool _retryInProgress = false;

  final ReportRemoteService _remote = ReportRemoteService();

  Future<void> enqueueReportUpload({
    required FieldReport report,
    required String employeeExternalId,
    required List<String> imagePaths,
    required String lastError,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _readQueue(prefs);
    queue.removeWhere((item) => item.externalId == report.externalId);
    queue.add(
      QueuedReportUpload(
        externalId: report.externalId,
        employeeExternalId: employeeExternalId,
        reportJson: jsonEncode(_serializeReport(report)),
        imagePathsJson: jsonEncode(imagePaths),
        queuedAt: DateTime.now().toIso8601String(),
        retryCount: 0,
        lastError: lastError,
      ),
    );
    await _writeQueue(prefs, queue);
    await _saveSyncStatus(
      prefs,
      status: QueueSyncState.waiting,
      message: 'Waiting for network or server recovery.',
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  Future<int> getPendingCount({String? employeeExternalId}) async {
    final queue =
        await getPendingUploads(employeeExternalId: employeeExternalId);
    return queue.length;
  }

  Future<List<QueuedReportUpload>> getPendingUploads({
    String? employeeExternalId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _readQueue(prefs);
    if (employeeExternalId == null || employeeExternalId.isEmpty) {
      return queue;
    }
    return queue
        .where((item) => item.employeeExternalId == employeeExternalId)
        .toList();
  }

  Future<QueueSyncSnapshot> getSyncSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await _readQueue(prefs);
    final statusValue =
        prefs.getString(_lastStatusKey) ?? QueueSyncState.idle.name;
    final timestamp = prefs.getString(_lastRetryAtKey) ?? '';
    final message = prefs.getString(_lastMessageKey) ?? '';

    return QueueSyncSnapshot(
      pendingCount: queue.length,
      lastRetryAt: timestamp,
      state: QueueSyncState.values.firstWhere(
        (value) => value.name == statusValue,
        orElse: () => QueueSyncState.idle,
      ),
      message: message,
    );
  }

  Future<QueueRetryResult> retryPendingUploads({
    String? employeeExternalId,
  }) async {
    if (_retryInProgress) {
      return const QueueRetryResult(
        attempted: 0,
        succeeded: 0,
        failed: 0,
        busy: true,
      );
    }
    _retryInProgress = true;
    final prefs = await SharedPreferences.getInstance();
    final startedAt = DateTime.now().toIso8601String();
    try {
      if (!await _remote.isConfigured()) {
        await _saveSyncStatus(
          prefs,
          status: QueueSyncState.waiting,
          message: 'Remote CRM is not configured yet.',
          timestamp: startedAt,
        );
        return const QueueRetryResult(
          attempted: 0,
          succeeded: 0,
          failed: 0,
        );
      }
      final queue = await _readQueue(prefs);
      if (queue.isEmpty) {
        await _saveSyncStatus(
          prefs,
          status: QueueSyncState.healthy,
          message: 'No pending uploads. Everything is synced.',
          timestamp: startedAt,
        );
        return const QueueRetryResult(
          attempted: 0,
          succeeded: 0,
          failed: 0,
        );
      }

      final updatedQueue = <QueuedReportUpload>[];
      var attempted = 0;
      var succeeded = 0;
      var failed = 0;

      for (final queued in queue) {
        if (employeeExternalId != null &&
            employeeExternalId.isNotEmpty &&
            queued.employeeExternalId != employeeExternalId) {
          updatedQueue.add(queued);
          continue;
        }

        attempted += 1;
        final report = _deserializeReport(
          jsonDecode(queued.reportJson) as Map<String, dynamic>,
        );
        final imagePaths = (jsonDecode(queued.imagePathsJson) as List<dynamic>)
            .map((item) => item.toString())
            .toList();
        try {
          await _remote.submitReport(
            report: report,
            employeeExternalId: queued.employeeExternalId,
            imagePaths: imagePaths,
          );
          succeeded += 1;
        } catch (exc) {
          failed += 1;
          updatedQueue.add(
            QueuedReportUpload(
              id: queued.id,
              externalId: queued.externalId,
              employeeExternalId: queued.employeeExternalId,
              reportJson: queued.reportJson,
              imagePathsJson: queued.imagePathsJson,
              queuedAt: queued.queuedAt,
              retryCount: queued.retryCount + 1,
              lastError: exc.toString().replaceFirst('Exception: ', ''),
            ),
          );
        }
      }

      await _writeQueue(prefs, updatedQueue);
      await _saveSyncStatus(
        prefs,
        status: failed > 0 ? QueueSyncState.degraded : QueueSyncState.healthy,
        message: attempted == 0
            ? 'No matching queued uploads were retried.'
            : 'Retried $attempted upload(s): $succeeded sent, $failed pending.',
        timestamp: startedAt,
      );
      return QueueRetryResult(
        attempted: attempted,
        succeeded: succeeded,
        failed: failed,
      );
    } finally {
      _retryInProgress = false;
    }
  }

  Future<List<QueuedReportUpload>> _readQueue(SharedPreferences prefs) async {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => QueuedReportUpload.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeQueue(
    SharedPreferences prefs,
    List<QueuedReportUpload> queue,
  ) async {
    await prefs.setString(
      _storageKey,
      jsonEncode(queue.map((item) => item.toMap()).toList()),
    );
  }

  Future<void> _saveSyncStatus(
    SharedPreferences prefs, {
    required QueueSyncState status,
    required String message,
    required String timestamp,
  }) async {
    await prefs.setString(_lastStatusKey, status.name);
    await prefs.setString(_lastMessageKey, message);
    await prefs.setString(_lastRetryAtKey, timestamp);
  }

  Map<String, dynamic> _serializeReport(FieldReport report) {
    return {
      'externalId': report.externalId,
      'meetingId': report.meetingId,
      'visitId': report.visitId,
      'leadDbId': report.leadDbId,
      'leadId': report.leadId,
      'employeeId': report.employeeId,
      'employeeExternalId': report.employeeExternalId,
      'employeeName': report.employeeName,
      'outcome': report.outcome,
      'voiceAudioPath': report.voiceAudioPath,
      'voiceTranscript': report.voiceTranscript,
      'textNotes': report.textNotes,
      'imagePaths': report.imagePaths,
      'submittedAt': report.submittedAt,
      'adminComment': report.adminComment,
      'suggestedLeadStatus': report.suggestedLeadStatus,
    };
  }

  FieldReport _deserializeReport(Map<String, dynamic> map) {
    return FieldReport(
      externalId: map['externalId']?.toString() ?? '',
      meetingId: map['meetingId'] ?? 0,
      visitId: map['visitId'] ?? 0,
      leadDbId: map['leadDbId'] ?? 0,
      leadId: map['leadId']?.toString() ?? '',
      employeeId: map['employeeId'] ?? 0,
      employeeExternalId: map['employeeExternalId']?.toString() ?? '',
      employeeName: map['employeeName']?.toString() ?? '',
      outcome: map['outcome']?.toString() ?? '',
      voiceAudioPath: map['voiceAudioPath']?.toString() ?? '',
      voiceTranscript: map['voiceTranscript']?.toString() ?? '',
      textNotes: map['textNotes']?.toString() ?? '',
      imagePaths: (map['imagePaths'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      submittedAt: map['submittedAt']?.toString() ?? '',
      adminComment: map['adminComment']?.toString() ?? '',
      suggestedLeadStatus: map['suggestedLeadStatus']?.toString() ?? '',
    );
  }
}

class QueueRetryResult {
  final int attempted;
  final int succeeded;
  final int failed;
  final bool busy;

  const QueueRetryResult({
    required this.attempted,
    required this.succeeded,
    required this.failed,
    this.busy = false,
  });
}

class QueueSyncSnapshot {
  final int pendingCount;
  final String lastRetryAt;
  final QueueSyncState state;
  final String message;

  const QueueSyncSnapshot({
    required this.pendingCount,
    required this.lastRetryAt,
    required this.state,
    required this.message,
  });
}

enum QueueSyncState { idle, waiting, healthy, degraded }
