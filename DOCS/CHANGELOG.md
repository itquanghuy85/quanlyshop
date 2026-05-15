# CHANGELOG - HULUCA Shop Manager

Lịch sử tất cả thay đổi từng phiên bản.

---

## [2026-05-16] - Compact Listview + KiotViet Credentials UI + Clickable Navigation

### Summary
Khôi phục giao diện cũ (git revert về `3185ff9f`) và tái tích hợp các cải tiến chức năng bị mất. Thêm UI nhập Client ID/Secret cho KiotViet, tinh gọn search box và listview tiles trên các màn hình danh sách.

### Tính Năng Mới
- **Clickable customer header** trong phiếu sửa và đơn bán → mở hồ sơ khách hàng
- **Clickable product list** trong đơn bán → xem chi tiết sản phẩm
- **Order navigation** từ hồ sơ khách hàng → mở đơn sửa / đơn bán tương ứng
- **Backup & KiotViet tiles** trong Cài đặt → điều hướng nhanh
- **KiotViet credentials UI**: nhập Client ID và Client Secret trực tiếp trong ứng dụng (lưu mã hóa trên thiết bị, không cần dart-define)

### Compact Listview
- `order_list_view.dart`: search box height 42, isDense, padding 12h/6v
- `customer_management_view.dart`: tile dense, avatar radius 18, card elevation 0, borderRadius 12
- `inventory_view.dart`: search box height 42, isDense, padding 12h/8v
- `global_search_bar.dart`: height 56 → 42, borderRadius 16 → 12, padding 8v

### Files Modified
- `lib/views/kiotviet_settings_view.dart` — thêm phần nhập Client ID + Client Secret với eye icon
- `lib/services/kiotviet_service.dart` — hỗ trợ runtime credentials qua SharedPreferences
- `lib/views/order_list_view.dart` — compact search box
- `lib/views/customer_management_view.dart` — compact tiles
- `lib/views/inventory_view.dart` — compact search box
- `lib/widgets/global_search_bar.dart` — height 42
- `lib/views/repair_detail_view.dart` — ClickableCustomerHeader
- `lib/views/sale_detail_view.dart` — ClickableCustomerHeader + ClickableProductList
- `lib/views/customer_profile_view.dart` — _openOrder() navigation
- `lib/views/shop_settings_view.dart` — Backup & KiotViet quick tiles
- `lib/widgets/clickable_customer_header.dart` — widget mới
- `lib/widgets/clickable_customer_chip.dart` — widget mới
- `lib/widgets/clickable_product_chip.dart` — widget mới
- `lib/widgets/clickable_product_list.dart` — widget mới
- `lib/widgets/deep_link_navigator.dart` — widget mới

---

## [2026-05-15] - Restore Legacy Color Palette (Git Forensics)

### Summary
Truy vết chính xác bảng màu gốc từ commit `3d6b3109` và khôi phục lại toàn bộ ứng dụng. Giao diện cũ mềm mại vì dùng primary `#4D8EE9` (soft blue) thay vì iOS/Zalo blue cứng.

### Palette Forensics — Commit `3d6b3109` (gốc)
| Token | Cũ (gốc) | Mới (iOS — đã hủy) | Đã khôi phục |
|---|---|---|---|
| primary | `#4D8EE9` (soft blue) | `#007AFF` | ✅ |
| AppBar gradient | `#0068FF → #0084FF` | `#007AFF → #0056D6` | ✅ |
| background | `#F8FAFF` | `#F5F7FB` | ✅ |
| success | `#388E3C` | `#34A853` | ✅ |
| warning | `#F57C00` | `#E6A700` | ✅ |
| error | `#D32F2F` | `#EF4444` | ✅ |
| textPrimary | `#1C1B1F` | `#1F2937` | ✅ |
| grey scale | Material Design | Tailwind Gray | ✅ |
| finance_v2_theme | original navy | modified | ✅ |

### Files Modified
- `lib/theme/app_colors.dart` — khôi phục palette gốc từ Git history
- `lib/theme/app_theme.dart` — AppBar → #0068FF
- `lib/widgets/custom_app_bar.dart` — gradient → #0068FF/#0084FF
- `lib/finance_v2/finance_v2_theme.dart` — khôi phục navy original

### Validation Results
- ✓ flutter analyze: 0 errors
- ✓ flutter build apk --debug: Success
- ✓ Install on OPPO CPH1989: Success

---

## [2026-05-15] - iOS Premium Color Palette + Finance V1 Removal

### Summary
Nâng cấp toàn bộ bảng màu ứng dụng sang iOS Premium Palette (Apple/Stripe/Notion style) và loại bỏ hoàn toàn Finance V1.

### Color Palette Changes
- Primary: `#2563EB` → `#007AFF` (iOS System Blue)
- Background: `#F7F8FA` → `#F5F7FB`
- Grey scale: Tailwind Slate → Tailwind Gray (ấm hơn)
- Success: `#16A34A` → `#34A853` (Google Green)
- Warning: `#F59E0B` → `#E6A700`
- AppBar gradient: `#0068FF/#0084FF` → `#007AFF/#0056D6`
- Text Primary: `#0F172A` → `#1F2937`
- Text Secondary: `#64748B` → `#6B7280`

### Files Modified
- `lib/theme/app_colors.dart` — toàn bộ palette iOS premium
- `lib/theme/app_theme.dart` — AppBar backgroundColor → #007AFF
- `lib/widgets/custom_app_bar.dart` — gradient → #007AFF/#0056D6
- `lib/finance_v2/finance_v2_theme.dart` — hardcoded tokens → iOS palette
- `lib/views/financial_report_view.dart` — DELETED (Finance V1)
- `lib/views/daily_activity_report_view.dart` — DELETED (Finance V1)
- `lib/services/daily_activity_report_service.dart` — DELETED (Finance V1)
- `lib/finance_v2/finance_v2_feature_flag.dart` — DELETED (unused)

### Validation Results
- ✓ flutter analyze: 0 errors (infos/warnings only, pre-existing)
- ✓ flutter build apk --debug: Success
- ✓ Install on OPPO CPH1989 (Android 11): Success

---

## [2026-05-15] - Documentation Process Setup

### Summary
Thiết lập quy trình tài liệu hóa bắt buộc toàn dự án. Mỗi thay đổi code từ nay phải tự động cập nhật tài liệu liên quan.

### Files Created
- `CLAUDE.md` - Hướng dẫn tổng thể cho AI agents
- `docs/DOCUMENTATION_INDEX.md` - Chỉ mục toàn bộ tài liệu
- `docs/CHANGELOG.md` - File này
- `docs/HANDOVER.md` - Trạng thái hiện tại
- `docs/KNOWN_ISSUES.md` - Vấn đề đã biết
- `docs/TODO.md` - Công việc cần làm
- `docs/ROADMAP.md` - Lộ trình phát triển
- `docs/ARCHITECTURE.md` - Kiến trúc chi tiết
- `docs/DESIGN_SYSTEM.md` - Design system & tokens
- `docs/DESIGN_TOKENS_REFERENCE.md` - Bảng colors, typography
- `docs/UI_GUIDELINES.md` - Hướng dẫn UI
- `docs/CODING_STANDARDS.md` - Quy tắc coding
- `docs/IMPLEMENTATION_REPORT.md` - Chi tiết implementation
- `docs/PAYMENT_AUDIT.md` - Audit thanh toán

### Files Modified
- `.github/copilot-instructions.md` - Thêm hướng dẫn tài liệu hóa bắt buộc

### Files Deleted
- None

### Validation Results
- ✓ flutter analyze: No errors
- ✓ flutter build: Success
- ⊘ flutter test: Skipped (documentation setup)

### Details
Thiết lập framework tài liệu hóa hoàn chỉnh:
1. Tạo tất cả file tài liệu bắt buộc
2. Định nghĩa quy tắc cập nhật tự động
3. Tạo documentation index
4. Thêm validation checklist
5. Cập nhật copilot-instructions.md

---

## Previous History

*Lưu ý: Trước khi 2026-05-15, không có CHANGELOG.md chính thức.*
*Để xem lịch sử chi tiết, xem git log hoặc các file tài liệu legacy.*

---

**Template cho changelog entries mới:**

```markdown
## [YYYY-MM-DD] - Task Title

### Summary
Mô tả ngắn (1-2 dòng) về thay đổi

### Files Created
- file1.dart
- file2.md

### Files Modified
- file3.dart
- docs/file4.md

### Files Deleted
- old_file.dart

### Validation Results
- ✓ flutter analyze: No errors
- ✓ flutter test: X tests passed
- ✓ flutter build: Success

### Details
Chi tiết thay đổi (bullet points, technical notes, etc.)
```
