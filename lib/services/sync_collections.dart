/// Danh sách collection được đồng bộ Local ⇄ Cloud — **NGUỒN SỰ THẬT DUY NHẤT**.
///
/// ## Vì sao phải gom về một chỗ
/// Trước 06/09/2026 danh sách này bị chép tay ở nhiều nơi và **lệch nhau**:
/// `sync_health_check.dart` chép 3 lần cùng một danh sách 17 bảng, trong khi
/// realtime listener của `SyncService` theo dõi 27 bảng. Hậu quả đo được trên
/// shop thật: máy chủ shop thiếu **2.965 phiếu nhập + 2.011 dòng nhật ký tài
/// chính**, nhưng Trung tâm đồng bộ vẫn báo *"1 bản ghi chưa khớp"* — vì các
/// bảng đó **không nằm trong danh sách kiểm tra**. Nhìn màn hình đó thì không
/// đời nào phát hiện ra.
///
/// ## Quy tắc thêm bảng mới
/// Thêm vào đây là đủ — kiểm tra sức khoẻ, sửa tự động và báo cáo theo nghiệp
/// vụ đều đọc từ danh sách này. Điều kiện để một tên được vào danh sách:
/// 1. có bảng SQLite cùng tên trong `db_helper.dart`;
/// 2. có cột `shopId` và `firestoreId` để đối chiếu được với cloud;
/// 3. thực sự được đẩy/tải giữa local và Firestore.
///
/// Quyền xem vẫn lọc riêng qua `SyncService.filterCollectionsForCurrentUser`,
/// nên để tên ở đây KHÔNG có nghĩa mọi vai trò đều tải được.
class SyncCollections {
  SyncCollections._();

  /// Toàn bộ collection đối chiếu được giữa local và cloud.
  static const List<String> all = [
    // ── Sửa chữa ──
    'repairs',
    'repair_parts',
    'repair_partners',
    'repair_partner_payments',
    'partner_repair_history',
    'salvage_phones',
    // ── Bán hàng ──
    'sales',
    'sales_returns',
    'sales_return_items',
    // ── Kho & nhập hàng ──
    'products',
    'product_categories',
    'import_orders',
    'import_order_items',
    'purchase_orders',
    'supplier_import_history',
    'price_catalog_items',
    'storage_locations',
    'quick_input_codes',
    // ── Đối tác ──
    'customers',
    'suppliers',
    'supplier_payments',
    // ── Tiền ──
    'expenses',
    'debts',
    'debt_payments',
    'payment_intents',
    'payment_requests',
    'cash_closings',
    'financial_activity_log',
    // ── Nhân sự & hệ thống ──
    'attendance',
    'work_schedules',
    'audit_logs',
  ];

  /// Các bảng từng có trong danh sách kiểm tra cũ (17 bảng) — giữ lại để đối
  /// chiếu khi cần biết bảng nào MỚI được đưa vào diện kiểm tra.
  static const List<String> legacyChecked = [
    'repairs',
    'repair_parts',
    'repair_partners',
    'partner_repair_history',
    'sales',
    'salvage_phones',
    'products',
    'storage_locations',
    'expenses',
    'debts',
    'debt_payments',
    'payment_intents',
    'payment_requests',
    'attendance',
    'customers',
    'suppliers',
    'quick_input_codes',
  ];

  /// Bảng mới được đưa vào diện kiểm tra so với danh sách cũ.
  static List<String> get newlyChecked =>
      all.where((c) => !legacyChecked.contains(c)).toList();
}
