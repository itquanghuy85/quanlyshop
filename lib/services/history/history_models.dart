/// Model & hằng số dùng chung cho tầng History/Event Service.
///
/// PHA 0 — chỉ đọc: đây là hình dạng dữ liệu trung lập mà `HistoryService`
/// trả ra cho mọi consumer, để UI/service gọi nó không cần biết dữ liệu nằm
/// ở bảng nào (`financial_activity_log`, `audit_logs`, `sync_audit_log`,
/// `adjustment_entries`...). Sau này đổi nguồn dữ liệu phía dưới (vd. Finance
/// History chuyển sang live-query) thì hình dạng `HistoryEntry` không cần đổi.
///
/// `metadata` cố tình giữ NGUYÊN row gốc (Map thô từ DB, hoặc object gốc như
/// `SyncAuditEvent`) — để các nơi đang định dạng hiển thị theo kiểu riêng của
/// từng domain (vd. các hàm `_financialTitle`/`_auditTitle` trong
/// `recent_activity_service.dart`) tiếp tục đọc đúng field như trước, không
/// mất thông tin nào trong quá trình chuyển đổi.
library;

class HistoryCategory {
  HistoryCategory._();

  /// Sự kiện tài chính (tiền thu/chi) — nguồn hiện tại: `financial_activity_log`.
  static const String finance = 'finance';

  /// Hành vi người dùng/hệ thống (ai đổi gì) — nguồn hiện tại: `audit_logs`.
  static const String audit = 'audit';

  /// Kết quả đồng bộ — nguồn hiện tại: `sync_audit_log`.
  static const String sync = 'sync';

  /// Bút toán điều chỉnh sau chốt quỹ — nguồn hiện tại: `adjustment_entries`
  /// (LƯU Ý: bảng này hiện không có luồng ghi nào gọi tới, xem ghi chú trong
  /// `AdjustmentService` — giữ nguyên hiện trạng, không xử lý ở PHA 0).
  static const String adjustment = 'adjustment';
}

class HistoryEntry {
  /// Id ổn định của dòng — ưu tiên `firestoreId`, có tiền tố theo category để
  /// không đụng nhau khi gộp nhiều nguồn (giữ đúng quy ước id đã dùng trong
  /// `recent_activity_service.dart` trước khi có lớp này).
  final String id;

  /// Một trong các hằng số `HistoryCategory.*`.
  final String category;

  /// Loại sự kiện trong phạm vi category đó — vd. `activityType` (finance),
  /// `action` (audit), `operation` (sync), `adjustmentType` (adjustment).
  final String type;

  /// Tiêu đề thô lấy từ nguồn gốc (CHƯA nhân văn hoá) — nhiều nguồn không có
  /// field này (audit/sync), consumer tự định dạng tiêu đề hiển thị dựa vào
  /// `metadata` như trước giờ vẫn làm.
  final String? title;

  final String? description;

  /// Số tiền, chỉ có ý nghĩa với category `finance`/`adjustment`.
  final int? amount;

  /// `IN`/`OUT`/`DEBT`... chỉ có ý nghĩa với category `finance`.
  final String? direction;

  /// Trạng thái rời rạc (vd. `success`/`retry`/`failed` của sync).
  final String? status;

  /// Loại + id của đối tượng nghiệp vụ gốc mà sự kiện này nói tới (để mở màn
  /// chi tiết) — vd. `sale`/`repair`/`debt` + firestoreId tương ứng.
  final String? entityType;
  final String? entityId;

  final String? userId;

  final int createdAt;

  /// Row/object gốc CHƯA qua biến đổi — xem giải thích ở đầu file.
  final Map<String, dynamic> metadata;

  const HistoryEntry({
    required this.id,
    required this.category,
    required this.type,
    this.title,
    this.description,
    this.amount,
    this.direction,
    this.status,
    this.entityType,
    this.entityId,
    this.userId,
    required this.createdAt,
    this.metadata = const {},
  });
}
