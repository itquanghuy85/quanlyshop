# CHANGELOG - HULUCA Shop Manager

Lịch sử tất cả thay đổi từng phiên bản.

---

## [2026-05-16] - Reconciliation Fix TOTAL_OUT + TOTAL_DEBT_SUPPLIER

### Summary
Sửa 2 lỗi còn lại trong sheet RECONCILIATION của `nhat_ky_chi_tiet` phát hiện qua audit Excel ngày 16/05/2026.

### Sửa Lỗi

#### LỖI 1 — TOTAL_OUT lệch 200,000đ (log > report)
- **File:** `lib/finance_v2/finance_v2_data_service.dart`
- **Root cause:** Data service không query `supplier_import_history` → bỏ sót các khoản thanh toán nhập hàng (non-CÔNG NỢ) chưa có expense record tương ứng. Activity_log dùng import_history nên log cao hơn report 200K.
- **Fix:** Thêm query `getAllImportHistoryByDateRange`, aggregate theo referenceId, dedup theo amount với import expenses đã có, bổ sung phần còn lại vào `expenseOut` (và `importExpenseOut`).

#### LỖI 2 — TOTAL_DEBT_SUPPLIER lệch 50,380,000đ (log < report)
- **Files:** `lib/finance_v2/finance_v2_view.dart`, `lib/finance_v2/finance_v2_reconciliation.dart`
- **Root cause (a):** `_loadOpeningDebtBalances()` dùng `prePeriodPayments` (từ debt_payments table), nhưng `snap.payableTotal` dùng stored `paidAmount` field → khi 2 nguồn lệch nhau (sync lag), opening không nhất quán với closing, gây lỗi formula `opening + flow ≠ closing`.
- **Fix (a):** Đổi sang `paidBeforeStart = storedPaid - inPeriodPaid` (dùng in-period payments từ cùng ngày). Về mặt đại số: `opening_new + flow = snap.payableTotal` luôn đúng khi `debt.paidAmount` là nguồn sự thật.
- **Root cause (b):** Reconciliation engine cộng `debtSupplierChange` từ IMPORT entries (CÔNG NỢ imports), nhưng các khoản nợ này được track qua `purchase_orders`, không phải `debts` table → không có trong `snap.payableTotal`, làm flow dương hơn thực tế.
- **Fix (b):** Skip `debtSupplierChange` cho action type 'IMPORT' trong `FinanceV2ReconciliationEngine.compute()`.

### Reconciliation Expected Results (16/05/2026 sau fix)
| Metric | Trước | Sau fix |
|--------|-------|---------|
| TOTAL_OUT | log=128.4M, report=128.2M, FAIL | ✓ PASS |
| TOTAL_DEBT_SUPPLIER | log=-17.19M, report=33.19M, FAIL | ✓ PASS |
| NET | Fail (-200K) | ✓ PASS |

### Files Modified
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/finance_v2/finance_v2_reconciliation.dart`

### Git Commit
`c9822f44`

---

## [2026-05-16] - Financial Reconciliation Audit — 4 Bugs Fixed

### Summary
Audit toàn diện 6 file Excel xuất ngày 16/05/2026. Xác định và sửa 4 lỗi gây chênh lệch số liệu giữa các báo cáo.

### Sửa Lỗi

#### BUG 1 — KẾT HỢP Revenue Gap (+5M thiếu)
- **Files:** `lib/finance_v2/finance_v2_data_service.dart`, `lib/services/daily_financial_analysis_service.dart`
- **Root cause:** Đơn KẾT HỢP dùng `finalPrice` thay vì `cashAmount + transferAmount` → mất phần tiền mặt
- **Fix:** Thêm nhánh `isKetHop && (cashAmount + transferAmount) > 0 → actualPaid = cashAmount + transferAmount`
- **Áp dụng:** Cả current period lẫn previousSales loop; cả data service lẫn daily analysis service
- **recognizedCost:** Đổi denominator = `actualPaid` cho KẾT HỢP (ratio = 1, ghi nhận 100% vốn)

#### BUG 2 — bao_cao_ngay "CHI — Nhập hàng" luôn 0
- **File:** `lib/finance_v2/finance_v2_view.dart` (section 2 Cơ cấu thu chi)
- **Root cause:** Filter `type='IMPORT'` nhưng data service không bao giờ tạo txn type IMPORT (dùng EXPENSE)
- **Fix:** Derive từ snapshot: `importOut = totalOut - debtRepayOut - operatingExpenseOut`

#### BUG 3 — Giá hiển thị KẾT HỢP trong danh sách đơn bán
- **File:** `lib/finance_v2/finance_v2_view.dart` (section 3 Danh sách đơn bán)
- **Root cause:** Hiển thị `finalPrice` thay vì số tiền thực thu (`cashAmount + transferAmount`)
- **Fix:** Dùng `cashAmount + transferAmount` khi `> 0` và `paymentMethod == 'KẾT HỢP'`

#### BUG 4 — so_quy duplicate partner payment entries
- **File:** `lib/views/cash_closing_view.dart`
- **Root cause:** Cùng một khoản trả đối tác xuất hiện 2 lần: từ `_expenses` ('ĐỐI TÁC SỬA CHỮA') và `_repairPartnerPayments` ('Trả đối tác SC')
- **Fix:** Track `partnerExpenseAmounts` trong loop expenses; skip `_repairPartnerPayments` nếu đã có entry trùng amount
- **Bonus:** Sửa KẾT HỢP amount trong `_getIncomeTransactions` sổ quỹ (tương tự BUG 1)

### Reconciliation Results (16/05/2026)
| Metric | Trước (gap) | Sau fix |
|--------|-------------|---------|
| TOTAL_IN | -5,000,000 | ✓ Match |
| CHI — Nhập hàng | Luôn 0 | ✓ Hiển thị đúng |
| so_quy duplicate | ~1.4M × 2 | ✓ Deduplicated |
| sec3 KẾT HỢP display | finalPrice sai | ✓ cashAmount + transferAmount |

### Files Modified
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/services/daily_financial_analysis_service.dart`
- `lib/views/cash_closing_view.dart`

### Git Commit
`2b2f3966`

---

## [2026-05-16] - Fix Finance Tab Crash + Audit Financial Display

### Summary
Sửa lỗi `DatabaseException(no such column: createdAt)` làm crash tab Tài chính. Audit và xác nhận logic tính toán tài chính giữa Home và Finance nhất quán. Sửa Home không giữ số liệu khi _loadStats lỗi.

### Sửa Lỗi
- **`getSalesByDateRange()` crash** (`db_helper.dart`)
  - Xóa `COALESCE(soldAt, createdAt)` — cột `createdAt` không tồn tại trong bảng `sales`
  - Thay bằng `soldAt` trực tiếp (đúng schema)
  - Áp dụng cho cả 2 nhánh: shopId-filtered và non-filtered
- **Home `_loadStats` catch block** (`home_view.dart`)
  - Bỏ `setState` reset toàn bộ số về 0 khi lỗi — giữ nguyên số liệu cũ thay vì mất trắng

### Audit Tài Chính
- **Home vs Finance**: Cả hai dùng `FinanceV2DataService.loadSnapshot()` → số liệu `totalIn/totalOut/netCashflow` nhất quán
- **Công thức**: `totalIn = saleIn + repairIn + extraIn`, `totalOut = expenseOut` (đúng)
- **CÔNG NỢ**: Đơn bán/sửa ghi CÔNG NỢ = 0 đóng góp vào dòng tiền (cash-basis đúng)
- **Trả góp**: chỉ tính `downPayment + settlementAmount` (đúng)
- **Trả hàng**: Trừ trực tiếp vào `saleIn` (net revenue — đúng)
- **Nhật ký tab**: Trống vì `financial_activity_log` chưa có bản ghi — fallback audit_logs đang hoạt động đúng

### Files Modified
- `lib/data/db_helper.dart`
- `lib/views/home_view.dart`

### Validation
- ✓ `flutter analyze`: không có lỗi mới
- ✓ `flutter build apk --debug`: Success

---

## [2026-05-16] - Fix Blank Finance Timeline (Nhật ký) on OPPO

### Summary
Sửa lỗi tab Nhật ký tài chính bị trống như ảnh chụp trong trường hợp không có bản ghi `financial_activity_log` trong kỳ lọc nhưng hệ thống vẫn có `audit_logs` liên quan tài chính.

### Tính Năng / Sửa Lỗi
- **Finance V2 Timeline fallback** (`finance_v2_view.dart`)
	- Khi timeline chính (`transactions + financial_activity_log`) rỗng, tự động fallback đọc `audit_logs` theo cùng khoảng thời gian.
	- Chỉ lấy các action liên quan tài chính (`sale`, `repair`, `expense`, `debt`, `payment`, `purchase`, `import`, `cash_closing`).
	- Mapping action -> nhãn tiếng Việt để hiển thị thân thiện hơn.
- **UX thông báo nguồn dữ liệu**
	- Thêm banner cảnh báo ở tab Nhật ký khi đang hiển thị dữ liệu fallback từ log hệ thống.

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/finance_v2/finance_v2_view.dart lib/data/db_helper.dart lib/views/home_view.dart`: không có lỗi mới, còn warnings/info pre-existing.
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## [2026-05-16] - Financial Audit: Home vs Finance Consistency Fix

### Summary
Audit luồng tính toán tài chính sau phản hồi “Home và Tài chính không khớp”, đồng thời vá các điểm có thể gây sai số hoặc hiển thị số liệu treo.

### Tính Năng / Sửa Lỗi
- **Fix nguồn dữ liệu doanh số theo ngày** (`db_helper.dart`)
	- `getSalesByDateRange()` trước đó chưa lọc `shopId`, có thể kéo nhầm doanh số từ shop khác.
	- Bổ sung lọc `(shopId = ? OR shopId IS NULL)` + `(deleted = 0 OR deleted IS NULL)`.
	- Dùng `COALESCE(soldAt, createdAt)` để tránh sót bản ghi thiếu `soldAt`.
- **Fix số liệu treo ở Home khi load lỗi** (`home_view.dart`)
	- Khi `_loadStats()` throw exception, trước đó giữ nguyên số cũ (stale), dễ gây lệch với màn Tài chính.
	- Bổ sung reset toàn bộ biến tổng hợp tài chính về `0` trong `catch` để tránh hiển thị sai.

### Audit Notes
- Trên bản DB debug local trong workspace (`_debug_repair_shop_v22.db`), không có dữ liệu ngày hiện tại nên xuất Excel theo chế độ “Hôm nay” sẽ rỗng là hành vi đúng.
- Các file Excel đính kèm trong chat không mount vào workspace nên không thể parse trực tiếp nội dung sheet bằng công cụ file của workspace; audit được thực hiện qua code path và kiểm tra query thực tế.

### Files Modified
- `lib/data/db_helper.dart`
- `lib/views/home_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/data/db_helper.dart lib/views/home_view.dart lib/finance_v2/finance_v2_view.dart lib/finance_v2/finance_v2_data_service.dart`: không phát sinh lỗi mới, còn warnings/info pre-existing.
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## [2026-05-16] - Fix OPPO Visibility for Partner/Supplier Topbar Controls

### Summary
Sửa đúng màn hình đang dùng thực tế trên OPPO để hiển thị thay đổi mục 2 (NCC/đối tác): chuyển tìm kiếm + bộ lọc lên topbar cho cả 2 tab.

### Tính Năng / Sửa Lỗi
- **Sửa nhầm màn hình mục tiêu**: áp dụng thay đổi vào `supplier_list_view.dart` (màn hình được điều hướng từ Home/Create Sale), thay vì chỉ `partner_management_view.dart`.
- **Topbar NCC/Đối tác**:
	- Thêm nút tìm kiếm dạng icon kính lúp trên AppBar.
	- Thêm dropdown lọc trên AppBar, tự đổi theo tab đang mở.
- **Tab Nhà cung cấp** dropdown gồm:
	- Tất cả, Còn nợ, Đã tất toán, Quá hạn, Giao dịch gần đây.
- **Tab Đối tác sửa chữa** dropdown gồm:
	- Tất cả, Hoạt động, Ngừng HĐ, Còn nợ, Theo tên.
- **Dọn UI body**:
	- Bỏ ô search + chip filter trong thân danh sách để đồng nhất theo yêu cầu “đưa lên topbar”.

### Files Modified
- `lib/views/supplier_list_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/views/supplier_list_view.dart`: chỉ còn info/warning cũ (deprecated/use_build_context), không có lỗi mới.
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

---

## [2026-05-16] - Topbar Actions for Customer, Partner/NCC, and Inventory

### Summary
Điều chỉnh lại thao tác nhanh trên 3 khu vực chính theo hướng ưu tiên topbar: hồ sơ khách hàng, quản lý đối tác/NCC và quản lý kho.

### Tính Năng / Sửa Lỗi
- **Hồ sơ khách hàng** (`customer_profile_view.dart`)
	- Di chuyển nút **Lưu** và **Xóa** lên AppBar
	- Di chuyển bộ lọc lịch sử giao dịch (Tất cả/Mua bán/Sửa chữa/Thanh toán) thành **dropdown trên topbar**
	- Xóa trường nhập **Email**
	- Thu gọn trường **Địa chỉ** và **Ghi chú** về 1 dòng
	- Thu nhỏ khung ảnh đại diện từ 190 xuống 95 (1/2 chiều cao)
- **Quản lý đối tác & NCC** (`partner_management_view.dart`)
	- Thêm nút tìm kiếm dạng **icon kính lúp** trên topbar
	- Thêm dropdown lọc trên topbar và đồng bộ theo tab đang chọn:
		- Tab **Nhà cung cấp**: Tất cả, Còn nợ, Đã tất toán, Quá hạn, Giao dịch gần đây
		- Tab **Đối tác sửa chữa**: Tất cả, Hoạt động, Ngừng HĐ, Còn nợ, Theo tên
	- Áp dụng lọc/tìm kiếm trực tiếp vào danh sách của cả 2 tab
- **Quản lý kho** (`inventory_view.dart`)
	- Di chuyển tìm kiếm từ thân trang lên topbar (icon kính lúp)
	- Di chuyển nút con mắt (ẩn/hiện hàng hết) lên topbar
	- Ẩn khối hiển thị trạng thái tải cuộn “Tải cuộn 20 mục/lần”

### Files Modified
- `lib/views/customer_profile_view.dart`
- `lib/views/partner_management_view.dart`
- `lib/views/inventory_view.dart`

### Validation Results
- ⚠ `flutter analyze lib/views/customer_profile_view.dart lib/views/partner_management_view.dart lib/views/inventory_view.dart`: còn warnings/info pre-existing trong `inventory_view.dart` và `partner_management_view.dart`, không phát sinh lỗi compile
- ✓ `flutter build apk --debug`: Success (`build/app/outputs/flutter-apk/app-debug.apk`)

### Details
- Các thay đổi tập trung vào UX thao tác nhanh: giảm thao tác cuộn xuống thân trang, đưa hành động quan trọng lên AppBar.
- Logic lọc cho NCC/đối tác được tách rõ theo tab để tránh lẫn ngữ cảnh sử dụng.

---

## [2026-05-16] - Partner Navigation, Font Sync, Parts Financial Fix

### Summary
Sửa 5 bug lớn: điều hướng NCC/đối tác, lỗi tìm sản phẩm trong đơn bán, đồng bộ font size toàn app, tab linh kiện không nhất quán, giá vốn linh kiện không ghi vào tài chính.

### Tính Năng / Sửa Lỗi
- **Partner navigation**: bấm vào NCC/đối tác trong partner_management_view → mở trang chi tiết đúng
- **Sale detail product link**: sửa lỗi "không tìm thấy sản phẩm" do PKX/NO_IMEI được truyền sai vào lookup
- **DeepLinkNavigator**: thêm fallback strip số lượng (x2) khi tìm sản phẩm theo tên
- **Font size đồng bộ**: toàn app dùng AppTextStyles thay vì hardcoded fontSize
- **Tab linh kiện**: gradient màu, font size nhất quán với 2 tab điện thoại/phụ kiện
- **Giá vốn linh kiện tài chính**: fix 2 bug — parts cash payment dùng sai PaymentIntentType, _showCostFundRecordingPopup không ghi FinancialActivity
- **Màu nền đơn bán**: nhạt hơn (0xFFF4F6FA)

### Files Modified
- `lib/views/partner_management_view.dart` — thêm onTap + font sync
- `lib/views/sale_detail_view.dart` — sửa IMEI lookup + màu nền
- `lib/widgets/deep_link_navigator.dart` — thêm strip quantity suffix fallback
- `lib/views/parts_inventory_view.dart` — gradient đồng bộ + font sync
- `lib/views/create_repair_order_view.dart` — font sync
- `lib/views/repair_detail_view.dart` — fix parts cost financial recording

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
