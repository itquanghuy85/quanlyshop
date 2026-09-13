import '../../data/db_helper.dart';
import '../adjustment_service.dart';
import '../financial_activity_service.dart';
import '../sync_audit_service.dart';
import '../user_service.dart';
import 'history_models.dart';

/// Facade tập trung cho mọi truy vấn lịch sử/log/event trong app.
///
/// PHA 0 (READ FACADE): lớp này CHƯA đổi bất kỳ nguồn dữ liệu nào — mỗi hàm
/// bên dưới chỉ gọi lại đúng service/bảng đang dùng hôm nay
/// (`DBHelper.getFinancialActivities`, `DBHelper.getAuditLogs`,
/// `SyncAuditService.getRecentEvents`, `AdjustmentService.getAdjustmentHistory`)
/// rồi bọc kết quả vào `HistoryEntry` — hình dạng dữ liệu trung lập không lộ
/// tên bảng ra ngoài. Mục tiêu: consumer (vd. `RecentActivityService`) chỉ
/// cần biết gọi `HistoryService`, không cần tự biết dữ liệu nằm ở
/// `financial_activity_log` hay `audit_logs`.
///
/// KHÔNG đụng tới: `financial_activity_log_view.dart`, `audit_log_view.dart`,
/// `adjustment_history_view.dart` — các màn này migrate sang gọi facade ở
/// PHA 1, không phải PHA 0.
///
/// KHÔNG có hàm ghi (write) nào ở đây — việc tập trung điểm ghi
/// (`recordCorrection`...) là PHA 2, cố tình chưa làm trong PHA 0.
class HistoryService {
  static final DBHelper _db = DBHelper();

  // ─────────────────────────── FINANCE HISTORY ───────────────────────────

  /// Sự kiện tài chính — hiện đọc thẳng `financial_activity_log` qua
  /// `DBHelper.getFinancialActivities` (KHÔNG đổi truy vấn). Tham số giữ
  /// nguyên tên/ý nghĩa như hàm gốc để mọi tham số truyền xuyên suốt.
  static Future<List<HistoryEntry>> getFinanceHistory({
    int? startDate,
    int? endDate,
    String? activityType,
    String? direction,
    String? searchQuery,
    int limit = 100,
    int offset = 0,
    String? shopId,
  }) async {
    final rows = await _db.getFinancialActivities(
      startDate: startDate,
      endDate: endDate,
      activityType: activityType,
      direction: direction,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
      shopId: shopId,
    );
    return _dedupePartsCostMirror(rows.map(_fromFinancialRow).toList());
  }

  /// Nhánh nhập nhiều linh kiện giữa chừng đơn sửa (`repair_detail_view.dart`
  /// nhánh TIỀN MẶT/CHUYỂN KHOẢN) ghi 2 dòng cho CÙNG 1 khoản tiền: `PARTS_COST`
  /// (mô tả rõ) và `OTHER_EXPENSE` mirror do `PaymentIntentService` tự sinh
  /// (referenceType `parts_payment`) — cùng `referenceId`/amount. Đây CHỈ là
  /// trùng ở tầng hiển thị lịch sử: `Chốt quỹ`/`Finance V2` không dùng
  /// `financial_activity_log` cho các số liệu này (đọc thẳng bảng nghiệp vụ,
  /// đã xác nhận qua audit) nên KHÔNG bị đếm 2 lần vào tiền/lãi — chỉ có
  /// "Nhật ký tài chính"/"Hoạt động gần đây" hiện thừa 1 dòng. An toàn để lọc
  /// ở tầng đọc vì không đụng dữ liệu/ghi sổ, chỉ bớt 1 dòng hiển thị trùng.
  static List<HistoryEntry> _dedupePartsCostMirror(List<HistoryEntry> entries) {
    final partsCostKeys = entries
        .where((e) => e.type == 'PARTS_COST')
        .map((e) => '${e.entityId}|${e.amount}')
        .toSet();
    if (partsCostKeys.isEmpty) return entries;
    return entries.where((e) {
      final isMirror = e.type == 'OTHER_EXPENSE' &&
          e.metadata['referenceType'] == 'parts_payment';
      if (!isMirror) return true;
      return !partsCostKeys.contains('${e.entityId}|${e.amount}');
    }).toList();
  }

  // ──────────────────────────── AUDIT HISTORY ────────────────────────────

  /// Nhật ký hệ thống ("ai làm gì") — hiện đọc thẳng `audit_logs` qua
  /// `DBHelper.getAuditLogs` (KHÔNG đổi truy vấn).
  static Future<List<HistoryEntry>> getAuditHistory({
    int limit = 100,
    int offset = 0,
    String? shopId,
    String? searchQuery,
  }) async {
    final rows = await _db.getAuditLogs(
      limit: limit,
      offset: offset,
      shopId: shopId,
      searchQuery: searchQuery,
    );
    return rows.map(_fromAuditRow).toList();
  }

  // ───────────────────────────── SYNC HISTORY ─────────────────────────────

  /// Kết quả đồng bộ từng bản ghi — hiện đọc thẳng `sync_audit_log` qua
  /// `SyncAuditService.getRecentEvents` (KHÔNG đổi truy vấn).
  static Future<List<HistoryEntry>> getSyncHistory({int limit = 120}) async {
    final events = await SyncAuditService.getRecentEvents(limit: limit);
    return events.map(_fromSyncEvent).toList();
  }

  // ─────────────────────────── ADJUSTMENT HISTORY ─────────────────────────

  /// Bút toán điều chỉnh — hiện đọc thẳng `adjustment_entries` qua
  /// `AdjustmentService.getAdjustmentHistory` (KHÔNG đổi truy vấn).
  ///
  /// LƯU Ý (đã xác nhận qua audit): không có luồng ghi nào trong app gọi tới
  /// `AdjustmentService.adjustPartCost/adjustPayment/paySupplierDebt`, nên
  /// bảng `adjustment_entries` hiện luôn rỗng trên production. Hàm này vẫn
  /// được khai báo đúng như thiết kế đích (Phần 2 của kế hoạch tái cấu trúc)
  /// để sau này nếu bảng có dữ liệu, consumer không cần đổi cách gọi — nhưng
  /// PHA 0 không sửa/không kích hoạt lại phần ghi.
  static Future<List<HistoryEntry>> getAdjustmentHistory({
    String? entityType,
    String? entityId,
    int? limit,
  }) async {
    final rows = await AdjustmentService.getAdjustmentHistory(
      entityType: entityType,
      entityId: entityId,
      limit: limit,
    );
    return rows.map(_fromAdjustmentRow).toList();
  }

  // ────────────────────────── RECORD CORRECTION ───────────────────────────

  /// PHA 2 — điểm ghi TẬP TRUNG cho bút toán bù trừ/điều chỉnh (correction)
  /// bắt buộc phải lưu lịch sử vì không dựng lại được từ bảng nghiệp vụ gốc
  /// (giá/vốn đơn sửa đã bị ghi đè, đơn đã bị xoá cứng...). Bọc lại ĐÚNG
  /// `FinancialActivityService.logCustomActivity` — cùng tham số, cùng hành
  /// vi (kể cả `EventBus().emitFinancialChanged()` bên trong) — chỉ đổi NƠI
  /// gọi từ rải rác trong UI (`repair_detail_view.dart`) về 1 chỗ, để UI
  /// không tự quyết định cách ghi correction nữa.
  ///
  /// KHÔNG dùng hàm này cho giao dịch nghiệp vụ bình thường (bán/sửa/chi phí
  /// còn nguyên bảng gốc) — chỉ dùng khi bản thân sự kiện là một correction.
  static Future<void> recordCorrection({
    required String activityType,
    required int amount,
    required String direction,
    required String paymentMethod,
    required String title,
    String? description,
    String? customerName,
    String? phone,
    String? productInfo,
    String? referenceType,
    String? referenceId,
    int? createdAt,
    String? createdBy,
  }) {
    return FinancialActivityService.logCustomActivity(
      activityType: activityType,
      amount: amount,
      direction: direction,
      paymentMethod: paymentMethod,
      title: title,
      description: description,
      customerName: customerName,
      phone: phone,
      productInfo: productInfo,
      referenceType: referenceType,
      referenceId: referenceId,
      createdAt: createdAt,
      createdBy: createdBy,
    );
  }

  // ─────────────────────────── RECENT ACTIVITY ────────────────────────────

  /// Gộp finance + sync + audit theo thời gian — thay cho việc
  /// `recent_activity_service.dart` trước đây tự gọi rời rạc 3 nguồn rồi tự
  /// gộp. Logic ngưỡng thời gian/giới hạn/lọc shopId dưới đây được CHUYỂN
  /// NGUYÊN VẸN từ `RecentActivityService.load()` — không đổi ngưỡng, không
  /// đổi limit mặc định của từng nguồn (180 cho finance, 120 cho sync, mặc
  /// định của `getAuditLogs` cho audit), không đổi thứ tự lọc, để kết quả
  /// hiển thị ở màn "Hoạt động gần đây" giữ nguyên như trước khi có lớp này.
  static Future<List<HistoryEntry>> getRecentActivity({
    String sourceFilter = 'all',
    Duration window = const Duration(hours: 24),
    int limit = 300,
  }) async {
    final threshold = DateTime.now().subtract(window).millisecondsSinceEpoch;
    final shopId = await UserService.getCurrentShopId();
    final entries = <HistoryEntry>[];

    if (sourceFilter == 'all' || sourceFilter == HistoryCategory.finance) {
      entries.addAll(
        await getFinanceHistory(startDate: threshold, limit: 180),
      );
    }

    if (sourceFilter == 'all' || sourceFilter == HistoryCategory.sync) {
      final syncEntries = await getSyncHistory(limit: 200);
      entries.addAll(syncEntries.where((e) => e.createdAt >= threshold));
    }

    if (sourceFilter == 'all' || sourceFilter == HistoryCategory.audit) {
      // `getAuditLogs()` không nhận tham số ngày — lọc ngưỡng + shopId thủ
      // công sau khi lấy về, giống hệt code gốc (đề phòng shopId cache lệch
      // so với shopId hiện tại đã resolve async ở trên).
      final auditEntries = await getAuditHistory();
      entries.addAll(
        auditEntries.where((e) {
          if (e.createdAt < threshold) return false;
          final rowShopId = e.metadata['shopId']?.toString();
          if (shopId != null &&
              shopId.isNotEmpty &&
              rowShopId != null &&
              rowShopId != shopId) {
            return false;
          }
          return true;
        }),
      );
    }

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries.length > limit ? entries.take(limit).toList() : entries;
  }

  // ────────────────────────────── MAPPERS ─────────────────────────────────

  static HistoryEntry _fromFinancialRow(Map<String, dynamic> row) {
    return HistoryEntry(
      id:
          row['firestoreId']?.toString() ??
          'financial_${row['id']?.toString() ?? row['createdAt']?.toString() ?? ''}',
      category: HistoryCategory.finance,
      type: row['activityType']?.toString() ?? '',
      title: row['title']?.toString(),
      description: row['description']?.toString(),
      amount: _toNullableInt(row['amount']),
      direction: row['direction']?.toString(),
      entityType: row['referenceType']?.toString(),
      entityId: row['referenceId']?.toString(),
      userId: row['createdBy']?.toString(),
      createdAt: _toInt(row['createdAt']),
      metadata: row,
    );
  }

  static HistoryEntry _fromAuditRow(Map<String, dynamic> row) {
    return HistoryEntry(
      id:
          row['firestoreId']?.toString() ??
          'audit_${row['id']?.toString() ?? row['createdAt']?.toString() ?? ''}',
      category: HistoryCategory.audit,
      type: row['action']?.toString() ?? '',
      description: row['description']?.toString(),
      entityType: (row['targetType'] ?? row['entityType'])?.toString(),
      entityId: (row['targetId'] ?? row['entityId'])?.toString(),
      userId: row['userId']?.toString(),
      createdAt: _toInt(row['createdAt']),
      metadata: row,
    );
  }

  static HistoryEntry _fromSyncEvent(SyncAuditEvent event) {
    return HistoryEntry(
      id: 'sync_${event.id}',
      category: HistoryCategory.sync,
      type: event.operation,
      status: event.outcome,
      entityType: event.entityType,
      entityId: event.entityId.toString(),
      createdAt: event.createdAt.millisecondsSinceEpoch,
      metadata: {'event': event},
    );
  }

  static HistoryEntry _fromAdjustmentRow(Map<String, dynamic> row) {
    return HistoryEntry(
      id:
          row['firestoreId']?.toString() ??
          'adjustment_${row['id']?.toString() ?? row['createdAt']?.toString() ?? ''}',
      category: HistoryCategory.adjustment,
      type: row['adjustmentType']?.toString() ?? '',
      description: row['description']?.toString(),
      amount: _toNullableInt(row['costDelta']),
      entityType: row['originalEntityType']?.toString(),
      entityId: row['originalEntityId']?.toString(),
      userId: row['createdBy']?.toString(),
      createdAt: _toInt(row['adjustmentDate'] ?? row['createdAt']),
      metadata: row,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  static int? _toNullableInt(dynamic value) {
    final v = _toInt(value);
    if (v == 0) return null;
    return v;
  }
}
