# Customer/Product Navigation Test Report

## Phạm vi test
- `lib/widgets/deep_link_navigator.dart`
- `lib/widgets/clickable_customer_header.dart`
- `lib/widgets/clickable_customer_chip.dart`
- `lib/widgets/clickable_product_chip.dart`
- `lib/widgets/clickable_product_list.dart`
- `lib/views/sale_detail_view.dart`
- `lib/views/repair_detail_view.dart`
- `lib/views/customer_profile_view.dart`
- `lib/views/inventory_detail_view.dart`

## Kịch bản đã kiểm tra logic
1. Customer lookup theo `customerId`.
2. Customer lookup fallback theo số điện thoại chuẩn hóa.
3. Customer lookup fallback theo tên bỏ dấu.
4. Product lookup theo `productId` (local/firestore).
5. Product lookup theo `imei`/`serial`.
6. Product lookup theo `sku`.
7. Product lookup fallback theo tên.
8. Khi lookup thất bại hiển thị SnackBar tiếng Việt, không crash.
9. Sale multi-products parse từ `itemSnapshotsJson` và fallback từ chuỗi cũ.

## Kết quả static validation
- Đã cập nhật mã theo tiêu chí deep-link và xử lý lỗi mềm.
- Cần chạy `flutter analyze` tại môi trường hiện tại để xác nhận không còn cảnh báo/lỗi liên quan import hoặc nullability sau khi merge.

## Kiểm thử thiết bị Android thực tế
- Trạng thái: Chưa thể xác nhận tự động trong phiên này.
- Cần kiểm tra thủ công trên thiết bị Android thật các luồng sau:
  - Bấm khách hàng từ sale detail mở đúng hồ sơ.
  - Bấm từng sản phẩm trong sale detail mở đúng item.
  - Bấm khách hàng từ repair detail mở đúng hồ sơ.
  - Bấm chip máy/sản phẩm từ repair detail mở đúng chi tiết sản phẩm.
  - Bấm chip sản phẩm trong customer profile mở đúng sản phẩm.
  - Trường hợp không tìm thấy phải hiện SnackBar, không văng app.

## Đề xuất xác nhận cuối
- Chạy task `flutter run (validate UI changes)` và test tay tuần tự các case trên trước khi phát hành.
