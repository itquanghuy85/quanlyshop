# LEGACY UI CLEANUP REPORT

**Ngày cập nhật:** 15/05/2026

## Phạm vi xử lý trong đợt này
- Quét lại toàn bộ `lib/views` và `lib/widgets` để tìm style inline còn sót.
- Chuẩn hóa theo Design System: `AppTextStyles`, `AppSpacing`, `Theme.of(context).colorScheme`.
- Ưu tiên các khu vực có mật độ style inline cao: Dialog, Form, List item, Dashboard card, Bottom sheet.

## File đã chuẩn hóa trong phiên này
- `lib/views/about_developer_view.dart`
- `lib/widgets/app_ui_helpers.dart`
- `lib/views/label_designer_view.dart`
- `lib/views/printer_settings_view.dart`
- `lib/views/bank_installment_report_view.dart`
- `lib/views/audit_log_view.dart`
- `lib/views/adjustment_history_view.dart`
- `lib/views/category_management_view.dart`

## Kết quả kỹ thuật
- Đã sửa và ổn định lại `label_designer_view.dart` sau khi phát sinh lỗi cú pháp trong lúc refactor.
- Chạy `flutter analyze` trên toàn bộ file đã chỉnh sửa: **không còn ERROR**.
- Các issue còn lại chủ yếu là warning/info deprecation (`withOpacity`, `surfaceVariant`) và các màn hình legacy chưa chạm tới trong phiên này.

## Kiểm tra Android thực tế
- Đã chạy kiểm tra thiết bị bằng `flutter devices`.
- Kết quả: **chưa có thiết bị Android kết nối** (chỉ có Windows và Chrome), nên chưa thể xác nhận chạy thực tế Android cho bản build mới.

## Danh sách legacy còn ưu tiên cao
- `lib/views/bank_installment_report_view.dart` (còn một số style inline nhỏ)
- `lib/views/attendance_management_view.dart`
- `lib/views/advanced_chat_view.dart`
- `lib/views/adjustment_history_view.dart` (còn một phần nhỏ)
- `lib/views/cash_closing_view.dart`

## Ghi chú an toàn release
- Tất cả thay đổi trong phiên này đều tập trung UI layer, không đổi luồng nghiệp vụ và không đổi schema dữ liệu.
- Đã xác thực compile/analyze không có lỗi mức `error` trong các file đã chỉnh sửa.
