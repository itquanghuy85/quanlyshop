import 'package:flutter/widgets.dart';

/// Huỷ [ChangeNotifier] (thường là `TextEditingController`) SAU KHI route
/// dialog / bottom sheet đã chạy xong hiệu ứng đóng.
///
/// Bẫy: `await showDialog(...)` / `await showModalBottomSheet(...)` trả về
/// ngay khi route bắt đầu pop, trong khi cây widget của dialog còn sống thêm
/// ~300 ms để chạy animation đóng. Nếu màn phía sau `setState` trong lúc đó
/// (ví dụ EventBus `debts_changed` làm danh sách công nợ rebuild), dialog
/// được rebuild lại và `TextFormField` gọi `controller.addListener` trên
/// controller đã dispose → debug: "A TextEditingController was used after
/// being disposed" → kéo theo "Duplicate GlobalKeys" → release: màn đỏ
/// `_dependents.isEmpty` (framework.dart:6268). Tái hiện thật 2026-09-12 ở
/// Công nợ → Thu nợ (khoản trả đủ làm nhóm biến mất) bằng `flutter attach`.
///
/// Cách đúng nhất là cho State của dialog sở hữu controller; hàm này là
/// hàng rào rẻ cho các dialog dựng inline bằng `StatefulBuilder`.
void disposeAfterTransition(
  ChangeNotifier notifier, {
  Duration delay = const Duration(milliseconds: 800),
}) {
  Future<void>.delayed(delay, () {
    try {
      notifier.dispose();
    } catch (_) {
      // Đã dispose ở nơi khác — bỏ qua.
    }
  });
}
