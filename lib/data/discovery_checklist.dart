import 'package:flutter/material.dart';

/// Một nhiệm vụ trong thẻ "Khám phá Ứng Dụng" ở Trang chủ — giúp người dùng mới
/// đi qua hết các tính năng chính.
class DiscoveryTask {
  final String id;
  final String title;

  /// 1 dòng: làm xong sẽ biết / được gì.
  final String hint;
  final IconData icon;

  /// id mục trong `AppKnowledgeBase` để mở hướng dẫn.
  final String kbEntryId;

  /// Nếu có → bấm sẽ chuyển tab dưới (AiNavBridge tabId), thay vì mở hướng dẫn.
  final String? tabId;

  /// Vai trò thấy nhiệm vụ này.
  final List<String> audience;

  const DiscoveryTask({
    required this.id,
    required this.title,
    required this.hint,
    required this.icon,
    required this.kbEntryId,
    this.tabId,
    this.audience = const ['all'],
  });
}

/// Danh sách nhiệm vụ khám phá. Giữ ngắn (~15) và theo thứ tự "nên làm trước".
const List<DiscoveryTask> kDiscoveryTasks = [
  DiscoveryTask(
    id: 'create-repair',
    title: 'Tạo đơn sửa đầu tiên',
    hint: 'Tiếp nhận một máy khách mang đến sửa.',
    icon: Icons.build_circle_outlined,
    kbEntryId: 'repair-create',
    tabId: 'repairs',
  ),
  DiscoveryTask(
    id: 'repair-status',
    title: 'Cập nhật trạng thái & giao máy',
    hint: 'Đổi trạng thái và bàn giao máy có thu tiền.',
    icon: Icons.assignment_turned_in_outlined,
    kbEntryId: 'repair-status',
  ),
  DiscoveryTask(
    id: 'record-cost',
    title: 'Ghi giá vốn cho một đơn sửa',
    hint: 'Nhập tiền linh kiện để tính lãi đúng.',
    icon: Icons.payments_outlined,
    kbEntryId: 'repair-cost',
    audience: ['owner', 'manager', 'technician'],
  ),
  DiscoveryTask(
    id: 'create-sale',
    title: 'Lập một đơn bán hàng',
    hint: 'Bán điện thoại / phụ kiện và in phiếu.',
    icon: Icons.point_of_sale_outlined,
    kbEntryId: 'sale-create',
    tabId: 'sales',
  ),
  DiscoveryTask(
    id: 'payment-methods',
    title: 'Thử các hình thức thanh toán',
    hint: 'Tiền mặt, chuyển khoản, công nợ, trả góp NH.',
    icon: Icons.account_balance_wallet_outlined,
    kbEntryId: 'sale-payment-methods',
  ),
  DiscoveryTask(
    id: 'stock-in',
    title: 'Nhập hàng vào kho',
    hint: 'Thêm hàng mới, ghi giá vốn / công nợ NCC.',
    icon: Icons.add_box_outlined,
    kbEntryId: 'stock-in-cash',
    tabId: 'inventory',
    audience: ['owner', 'manager', 'technician'],
  ),
  DiscoveryTask(
    id: 'inventory-check',
    title: 'Kiểm kho một lần',
    hint: 'Đối chiếu tồn trên app với hàng thực tế.',
    icon: Icons.fact_check_outlined,
    kbEntryId: 'inventory-check',
  ),
  DiscoveryTask(
    id: 'debt-collect',
    title: 'Thu / trả một khoản công nợ',
    hint: 'Ghi nhận tiền vào/ra theo khoản nợ.',
    icon: Icons.request_quote_outlined,
    kbEntryId: 'debt-collect',
    audience: ['owner', 'manager', 'cashier'],
  ),
  DiscoveryTask(
    id: 'cash-closing',
    title: 'Chốt quỹ cuối ngày',
    hint: 'Đếm tiền thực tế, phát hiện thừa/thiếu.',
    icon: Icons.lock_clock_outlined,
    kbEntryId: 'cash-closing',
    audience: ['owner', 'manager', 'cashier'],
  ),
  DiscoveryTask(
    id: 'daily-report',
    title: 'Xem báo cáo ngày',
    hint: 'Doanh thu / lãi (dồn tích) và tiền vào/ra (dòng tiền).',
    icon: Icons.assessment_outlined,
    kbEntryId: 'finance-daily-report',
    audience: ['owner', 'manager'],
  ),
  DiscoveryTask(
    id: 'money-reconcile',
    title: 'Đối soát tiền về',
    hint: 'Nhập số tiền → tìm đơn trả góp / công nợ khớp → ghi nhận.',
    icon: Icons.fact_check_outlined,
    kbEntryId: 'money-reconcile',
    audience: ['owner', 'manager', 'cashier'],
  ),
  DiscoveryTask(
    id: 'price-book',
    title: 'Xem & chốt Bảng giá',
    hint: 'Giá đề xuất theo lịch sử; ghim giá niêm yết để tự điền vào đơn.',
    icon: Icons.sell_outlined,
    kbEntryId: 'price-book',
    audience: ['owner', 'manager'],
  ),
  DiscoveryTask(
    id: 'bank-transfer-qr',
    title: 'Thu tiền bằng mã QR ngân hàng',
    hint: 'Chọn "Chuyển khoản" khi thu tiền → hiện QR đúng số tiền cho khách quét.',
    icon: Icons.qr_code_2_outlined,
    kbEntryId: 'bank-transfer-qr',
  ),
  DiscoveryTask(
    id: 'bank-notification',
    title: 'Bật đọc thông báo ngân hàng',
    hint: 'App tự nhận diện tiền vào/ra để gợi ý đối soát (Android).',
    icon: Icons.notifications_active_outlined,
    kbEntryId: 'bank-notification',
    audience: ['owner', 'manager'],
  ),
  DiscoveryTask(
    id: 'expense',
    title: 'Ghi một khoản chi phí',
    hint: 'Mặt bằng, điện nước, ăn uống…',
    icon: Icons.receipt_long_outlined,
    kbEntryId: 'expense',
    audience: ['owner', 'manager'],
  ),
  DiscoveryTask(
    id: 'customers',
    title: 'Mở hồ sơ một khách hàng',
    hint: 'Lịch sử sửa / mua và công nợ của khách.',
    icon: Icons.people_alt_outlined,
    kbEntryId: 'customers',
  ),
  DiscoveryTask(
    id: 'permissions',
    title: 'Phân quyền cho nhân viên',
    hint: 'Gán vai trò, bật/tắt quyền chi tiết.',
    icon: Icons.admin_panel_settings_outlined,
    kbEntryId: 'roles-permissions',
    audience: ['owner', 'manager'],
  ),
  DiscoveryTask(
    id: 'ai-assistant',
    title: 'Hỏi AI Trợ Lý một câu',
    hint: 'Hỏi số liệu hoặc cách dùng bất kỳ tính năng nào.',
    icon: Icons.smart_toy_outlined,
    kbEntryId: 'ai-assistant',
  ),
  DiscoveryTask(
    id: 'backup',
    title: 'Sao lưu dữ liệu',
    hint: 'An toàn trước khi đổi máy hoặc có sự cố.',
    icon: Icons.cloud_upload_outlined,
    kbEntryId: 'backup-restore',
    audience: ['owner'],
  ),
];
