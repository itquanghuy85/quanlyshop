# Design System Audit

## Tổng quan
Đợt audit này tập trung vào việc loại bỏ phân mảnh style và chuẩn hóa token theo một nguồn duy nhất.

## Phát hiện chính
1. Trùng hệ quy chiếu UI giữa:
- `lib/theme/app_theme.dart`
- `lib/theme/app_text_styles.dart`
- `lib/utils/ui_constants.dart`
- `lib/widgets/custom_app_bar.dart`
- `lib/widgets/app_ui_helpers.dart`

2. Hard-code phổ biến:
- Màu HEX trực tiếp trong view
- `EdgeInsets` số rời rạc (6/10/14/18...)
- `TextStyle` inline với size/weight khác nhau

3. Thành phần có phong cách lệch nhau:
- Card / Dialog / ListTile ở nhiều màn hình dùng style cục bộ
- Icon size và icon-text spacing chưa thống nhất

## Hành động đã thực hiện
1. Tạo token mới:
- `lib/theme/app_typography.dart`
- `lib/theme/app_spacing.dart`
- `lib/theme/design_tokens.dart`

2. Chuẩn hóa nền theme:
- cập nhật `lib/theme/app_theme.dart`
- cập nhật `lib/theme/app_button_styles.dart`
- bổ sung semantic text token trong `lib/theme/app_colors.dart`

3. Refactor màn hình và component chính:
- Home: `lib/views/home_view.dart`
- Customer: `lib/views/customer_profile_view.dart`
- Product/Inventory: `lib/views/inventory_view.dart`, `lib/views/inventory_detail_view.dart`
- Repair: `lib/views/repair_detail_view.dart`
- Sales: `lib/views/sale_detail_view.dart`
- Settings: `lib/views/shop_settings_view.dart`
- Shared components: `lib/widgets/section_card.dart`, các clickable widgets deep-link

## Khoảng trống còn lại (phase tiếp theo)
- `lib/utils/ui_constants.dart` vẫn tồn tại song song để tương thích cũ
- Một số module chuyên biệt (`finance_v2`) còn token riêng, chưa hợp nhất hoàn toàn
- Cần quét toàn bộ view để loại bỏ triệt để hard-code còn sót

## Kết luận audit
- Đã có Design System trung tâm và áp dụng thực tế lên các luồng màn hình trọng điểm.
- Đã giảm đáng kể style hard-code ở vùng truy cập cao.
- Cần thêm 1 vòng cleanup toàn repo để đạt mức “100% tokenized UI”.
