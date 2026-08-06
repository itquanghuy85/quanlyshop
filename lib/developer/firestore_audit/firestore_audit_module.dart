import 'package:flutter/foundation.dart' show debugPrint;
import 'models/audit_event.dart';
import 'services/firestore_audit_service.dart';

export 'services/firestore_audit_service.dart';
export 'models/audit_event.dart';
export 'models/audit_stats.dart';
export 'dashboard/firestore_audit_dashboard.dart';

/// Entry point của Firestore Audit Monitor.
///
/// Khởi tạo trong main.dart:
/// ```dart
/// await FirestoreAuditModule.init();
/// ```
///
/// Module hoàn toàn độc lập — có thể xóa folder `developer/firestore_audit/`
/// mà project vẫn compile và chạy bình thường.
///
/// KILL SWITCH: Khi isEnabled = false, service làm KHÔNG CÓ GÌ cả.
class FirestoreAuditModule {
  FirestoreAuditModule._();

  /// Khởi tạo module. Gọi trong main.dart trước runApp().
  /// Không tốn resource nếu kill switch đang OFF.
  static Future<void> init() async {
    // Kill switch (isEnabled=false mặc định) đảm bảo không tốn resource khi OFF.
    try {
      await FirestoreAuditService.instance.init();
      if (FirestoreAuditService.instance.isEnabled) {
        debugPrint('[FirestoreAudit] 🟢 Monitor ACTIVE');
      } else {
        debugPrint('[FirestoreAudit] ⚫ Monitor standby (OFF)');
      }
    } catch (e) {
      debugPrint('[FirestoreAudit] init error: $e');
    }
  }

  /// Ghi nhận một Firestore read từ bất kỳ đâu.
  /// Safe to call even if module is disabled.
  static void logRead({
    required String collection,
    required AuditOperation operation,
    required String callerService,
    required String callerMethod,
    String? callerScreen,
    int documentCount = 0,
    int? estimatedReads,
    int executionTimeMs = 0,
    bool isActiveListener = false,
    String? queryInfo,
  }) {
    FirestoreAuditService.instance.logRead(
      collection: collection,
      operation: operation,
      callerService: callerService,
      callerMethod: callerMethod,
      callerScreen: callerScreen,
      documentCount: documentCount,
      estimatedReads: estimatedReads,
      executionTimeMs: executionTimeMs,
      isActiveListener: isActiveListener,
      queryInfo: queryInfo,
    );
  }
}
