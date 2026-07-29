import '../models/app_alert.dart';
import 'database_service.dart';
import 'notification_service.dart';

class AlertService {
  static final DatabaseService _db = DatabaseService();

  static Future<void> createRoleAlert({
    required String title,
    required String body,
    required String targetRole,
    int? targetUserId,
    required String relatedType,
    int? relatedId,
  }) async {
    await _db.createAlert(
      AppAlert(
        title: title,
        body: body,
        targetRole: targetRole,
        targetUserId: targetUserId,
        relatedType: relatedType,
        relatedId: relatedId,
        createdAt: DateTime.now().toIso8601String(),
        readAt: '',
      ),
    );
    try {
      await NotificationService.showSimpleNotification(
        title: title,
        body: body,
      );
    } catch (_) {
      // Alerts should still be stored even if a local notification fails.
    }
  }
}
