# UI Guidelines

## Mục tiêu
Thiết lập trải nghiệm giao diện thống nhất, dễ mở rộng, giảm style hard-code rời rạc.

## 1. Typography
Sử dụng token từ `AppTypography`.

- Display: `displayLarge`
- Headline: `headlineLarge`, `headlineMedium`, `headlineSmall`
- Title: `titleLarge`, `titleMedium`, `titleSmall`
- Body: `bodyLarge`, `bodyMedium`, `bodySmall`
- Label: `labelLarge`, `labelMedium`, `labelSmall`
- Caption: `caption`

Quy ước:
- Font family mặc định: Roboto
- Không set `fontSize` rải rác nếu có thể dùng token
- Trường hợp đặc biệt phải comment lý do

## 2. Spacing
Sử dụng token từ `AppSpacing`.

- xs = 4
- sm = 8
- md = 12
- lg = 16
- xl = 24
- xxl = 32

Quy ước:
- Dùng `AppSpacing.p*`, `AppSpacing.ph*`, `AppSpacing.pv*`, `AppSpacing.gap*` thay cho số trực tiếp
- Dialog/card/form phải ưu tiên spacing scale này

## 3. Color
Sử dụng `AppColors` làm nguồn màu duy nhất.

Màu semantic:
- primary
- secondary
- surface
- background
- error
- success
- warning
- info
- textPrimary
- textSecondary

Quy ước:
- Không dùng hex inline nếu đã có token tương ứng
- Các badge/trạng thái phải đi qua semantic color

## 4. Component Standards
- Buttons: theo `AppButtonStyles` + minimum touch target 44
- Cards: dùng `CardTheme` hoặc `SectionCard`
- Dialogs: ưu tiên `AlertDialog` + spacing token + typography token
- Input fields: theo `InputDecorationTheme`
- Chips/Badges: icon + text gap theo `DesignTokens.iconTextGap`
- Empty/Loading states: dùng icon size chuẩn + body/caption token

## 5. Iconography
- Icon size chuẩn: `DesignTokens.iconSm|iconMd|iconLg`
- Gap icon-text: `DesignTokens.iconTextGap`
- Màu icon theo semantic (`AppColors.*`)

## 6. Responsive
- Mobile-first
- Tablet/Web dùng `ResponsiveCenter`, `ResponsiveScaffold`, `showAppBottomSheet`
- Tránh fixed width cứng khi có helper responsive

## 7. Accessibility
- Touch target tối thiểu: `DesignTokens.touchTargetMin` (=44)
- Ưu tiên màu có tương phản tốt
- Không khóa textScaleFactor trừ khi có yêu cầu nghiệp vụ

## 8. Quy trình áp dụng
1. Thêm token vào `lib/theme/`
2. Refactor component dùng chung trước
3. Refactor màn hình chính theo luồng truy cập nhiều
4. Chạy `flutter analyze`
5. Soát lại hard-code màu/spacing/font
