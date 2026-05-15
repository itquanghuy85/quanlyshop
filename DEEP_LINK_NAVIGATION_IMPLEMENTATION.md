# Deep Link Navigation Implementation

## Mục tiêu
- Chuẩn hóa điều hướng CRM-style khi bấm vào khách hàng/sản phẩm ở các màn hình chi tiết.
- Ưu tiên tra cứu theo thứ tự khóa rõ ràng và fallback an toàn, không làm crash UI.

## Các file đã tạo
- `lib/widgets/deep_link_navigator.dart`
- `lib/widgets/clickable_customer_header.dart`
- `lib/widgets/clickable_customer_chip.dart`
- `lib/widgets/clickable_product_chip.dart`
- `lib/widgets/clickable_product_list.dart`
- `lib/views/inventory_detail_view.dart`

## Các file đã cập nhật
- `lib/views/sale_detail_view.dart`
- `lib/views/repair_detail_view.dart`
- `lib/views/customer_profile_view.dart`

## Quy tắc lookup đã áp dụng
### Customer
1. `customerId` (local id hoặc firestoreId)
2. `phoneNumber` (chuẩn hóa chữ số)
3. `normalizedName` (bỏ dấu + lowercase)

### Product
1. `productId` (local id hoặc firestoreId)
2. `imei`
3. `serial`
4. `sku`
5. fallback theo tên sản phẩm

## Hành vi UX
- Toàn bộ thành phần clickable đều có:
  - `InkWell` ripple.
  - `MouseRegion` pointer.
  - Tooltip tiếng Việt.
- Nếu không tìm thấy dữ liệu:
  - Hiển thị SnackBar `Không tìm thấy hồ sơ khách hàng` hoặc `Không tìm thấy sản phẩm`.
  - Không throw exception ra UI.

## Màn hình đã gắn deep-link
- Sale detail:
  - Header khách hàng mở hồ sơ khách hàng.
  - Danh sách sản phẩm từ `itemSnapshotsJson` (fallback `productNames/productImeis`) mở chi tiết sản phẩm theo từng item độc lập.
- Repair detail:
  - Header khách hàng mở hồ sơ khách hàng.
  - Chip thiết bị/máy sửa mở chi tiết sản phẩm.
- Customer profile:
  - Lịch sử giao dịch có chip mở nhanh chi tiết sản phẩm theo mô tả lịch sử.
- Inventory detail:
  - Tạo mới màn hình đích để điều hướng thống nhất cho deep-link sản phẩm.

## Ghi chú triển khai
- Event hook analytics đang để dạng `debugPrint` (`deeplink_event=...`) để không ảnh hưởng luồng runtime hiện tại.
- Không thay đổi interface các service cũ, chỉ mở rộng hành vi ở lớp widget/view.
