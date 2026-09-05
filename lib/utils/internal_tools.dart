import 'package:flutter/foundation.dart' show kDebugMode;

/// Ai được THẤY các công cụ chẩn đoán nội bộ (vd "Giám sát Firestore Read").
///
/// ⚠️ CHỈ ĐIỀU KHIỂN HIỂN THỊ, KHÔNG PHẢI CƠ CHẾ BẢO MẬT.
/// Quyền đọc/ghi thật vẫn do Firebase custom claims + `firestore.rules` quyết
/// (CLAUDE.md mục III.1). Danh sách email dưới đây bị sửa cũng không giúp đọc
/// thêm được bất kỳ dữ liệu nào — nó chỉ bật/tắt một mục menu.
///
/// Vì vậy KHÔNG được dùng lớp này để gác tính năng có tác động dữ liệu.
class InternalTools {
  InternalTools._();

  /// Email nội bộ được xem công cụ chẩn đoán trên bản phát hành.
  /// Ghi thường (lowercase) — [visibleFor] tự chuẩn hoá email đầu vào.
  static const Set<String> allowedEmails = {'huy@huluca.com'};

  /// [isDebugBuild] tách ra làm tham số để test được cả nhánh release.
  static bool visibleFor({
    required String? email,
    required bool isSuperAdmin,
    bool isDebugBuild = kDebugMode,
  }) {
    if (isDebugBuild || isSuperAdmin) return true;
    final normalized = (email ?? '').trim().toLowerCase();
    return normalized.isNotEmpty && allowedEmails.contains(normalized);
  }
}
