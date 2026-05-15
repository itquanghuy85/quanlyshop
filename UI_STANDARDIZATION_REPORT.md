# UI Standardization Report

## Phạm vi triển khai
- Thiết lập token cho Typography, Spacing, Core Design.
- Chuẩn hóa ThemeData để button/card/dialog/input/chip dùng chuẩn chung.
- Refactor các màn hình chính theo ưu tiên lưu lượng sử dụng.

## Kết quả theo mục tiêu

### 1. Typography System
- Hoàn thành tạo `AppTypography` với các cấp Display/Headline/Title/Body/Label/Caption.
- Theme đã dùng textTheme từ token.

### 2. Spacing System
- Hoàn thành tạo `AppSpacing` với scale xs/sm/md/lg/xl/xxl.
- Áp dụng vào các màn hình đã refactor và component dùng chung.

### 3. Color System
- Duy trì `AppColors` làm nguồn semantic colors.
- Bổ sung alias `textPrimary`, `textSecondary`.

### 4. Component Standards
- Chuẩn hóa qua Theme + refactor `SectionCard` và các deep-link widgets.
- Buttons/Card/Dialog/Input/Chip dùng chung style hơn trước.

### 5. Iconography
- Tạo chuẩn icon size và gap tại `DesignTokens`.
- Áp dụng lên quick actions/headers/chips đã refactor.

### 6. Responsive Rules
- Giữ nền responsive hiện hữu (`ResponsiveCenter`, `ResponsiveScaffold`, `showAppBottomSheet`).
- Tăng tính nhất quán spacing trên mobile/tablet trong các màn hình đã sửa.

### 7. Accessibility
- Bổ sung token touch target tối thiểu 44.
- Áp dụng vào button style nhỏ và một số ListTile/action.

### 8. Refactor Existing Screens
- Đã áp dụng cho nhóm chính theo yêu cầu: Home/Customer/Product-Inventory/Repair/Sales/Settings.

## Chỉ số hoàn thành hiện tại
- Design tokens: Hoàn thành.
- Theme integration: Hoàn thành.
- Main screens refactor: Hoàn thành mức trọng điểm.
- Full-repo hard-code cleanup: Chưa hoàn thành tuyệt đối.

## Khuyến nghị bước tiếp
1. Quét toàn bộ `lib/views` thay thế số hard-code còn lại bằng `AppSpacing` và `AppTypography`.
2. Hợp nhất `ui_constants.dart` và token riêng của `finance_v2` vào hệ token mới.
3. Thêm lint rule nội bộ để chặn hard-coded color/spacing/font trong code mới.
