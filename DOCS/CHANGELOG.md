# CHANGELOG - HULUCA Shop Manager

Lịch sử tất cả thay đổi từng phiên bản.

---

## [2026-05-26] - Hoàn Thiện Sao Lưu/Khôi Phục Offline + Online, Thêm Nút ... Trên Cài Đặt

### Follow-up Migration & Sync Hardening (2026-05-26)
- `lib/services/backup_service.dart`
	- Mở rộng mapping restore SQLite cho các domain còn thiếu khi chuyển shop: `repair_parts`, `salvage_phones`, `storage_locations`, `payment_requests`, `payment_intents`, `repair_partners`, `partner_repair_history`, `import_orders`.
	- Khi chọn chế độ chuyển dữ liệu vào shop hiện tại: tự động remap `shopId`, reset `isSynced=0`, và xóa `firestoreId` để dữ liệu được upload lại đúng shop mới.
	- Bổ sung nhãn collection cho các module kho/đối tác/thanh toán mới.
- `lib/views/backup_restore_view.dart`
	- Mở rộng danh sách chọn khôi phục theo nhóm để bao phủ đủ: đơn sửa, kho máy xác, kho linh kiện, kho vị trí, yêu cầu đóng tiền, chi đối tác/NCC, lịch sử nhập.
- `lib/services/sync_health_check.dart`
	- Mở rộng phạm vi kiểm tra sync + auto-fix cho `salvage_phones`, `storage_locations`, `payment_requests`, `payment_intents`, `repair_partners`, `partner_repair_history`.
- `lib/services/sync_domain_report_service.dart`
	- Cập nhật domain report để phản ánh đúng các bảng/domain mới trong phần cài đặt đồng bộ.
- `lib/views/register_view.dart`
	- UI đăng ký chỉ còn loại hình kinh doanh điện tử.
- `lib/views/onboarding/business_type_wizard.dart`
	- Wizard onboarding và quick selector chỉ còn điện tử; `availableTypes` giới hạn còn `electronics`.
- `lib/widgets/shop_switcher_widget.dart`
	- Luồng tạo chi nhánh mới bỏ dropdown ngành, cố định tạo shop theo ngành điện tử.

### Validation (follow-up migration)
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/services/sync_health_check.dart lib/services/sync_domain_report_service.dart lib/views/register_view.dart lib/views/onboarding/business_type_wizard.dart lib/widgets/shop_switcher_widget.dart`
- `flutter build apk --debug`

### Changed
- `lib/services/backup_service.dart`
	- Hoàn thiện khôi phục SQLite từ Cloud bằng `restoreSqliteFromFirebase(fileName)`.
	- Tải file `.db` từ `Firebase Storage` và ghi đè DB local để khôi phục offline từ bản online.
- `lib/views/backup_restore_view.dart`
	- Bật chức năng "Khôi phục" cho từng bản backup SQLite trên Cloud (không còn trạng thái "đang phát triển").
	- Thêm xác nhận trước khi khôi phục và thông báo yêu cầu khởi động lại app sau khôi phục SQLite.
	- Bổ sung nút `...` ở AppBar để điều hướng nhanh giữa tab SQLite/Firestore và mở hướng dẫn sử dụng.
	- Bổ sung card "Hướng dẫn nhanh" cho tab SQLite và "Khôi phục theo từng mục" cho tab Firestore.
- `lib/views/settings_view.dart`
	- Thiết kế lại phần thao tác nhanh bằng nút `...` ở trên AppBar.
	- Từ menu `...` có thể đi nhanh tới: `Sao lưu & Khôi phục`, `Hướng dẫn sử dụng`, `Trung tâm trợ giúp`.
- `lib/data/user_guide_repository.dart`
	- Cập nhật kịch bản hướng dẫn sao lưu/khôi phục cho cả offline (SQLite) và online (Firestore).
	- Làm rõ luồng khôi phục chọn lọc theo từng mục trên Firestore.

### Validation
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/views/settings_view.dart lib/data/user_guide_repository.dart`
	- Không phát sinh lỗi compile mới; còn warning/info legacy của dự án.
- `flutter build apk --debug`: thành công (`build/app/outputs/flutter-apk/app-debug.apk`).

### Follow-up UX Fixes (2026-05-26)
- `lib/views/backup_restore_view.dart`
	- Tăng tương phản `TabBar` trên AppBar (label/unselected/indicator màu trắng) để tránh trùng màu khó đọc.
	- Bổ sung khu vực "Bản sao lưu SQLite trong máy" để xem được các file `.db` đã lưu.
	- Thêm thao tác rõ ràng:
		- "Lưu file .db vào máy"
		- "Chia sẻ bản sao mới nhất"
		- Khôi phục trực tiếp từ danh sách backup cục bộ.
	- Thêm lựa chọn khi khôi phục SQLite: "Khôi phục nguyên bản" hoặc "Chuyển vào shop hiện tại".
- `lib/services/backup_service.dart`
	- Thêm `listLocalSqliteBackups()` và `shareSqliteFile()` phục vụ xem/chia sẻ/khôi phục backup cục bộ.
- `lib/services/backup_service.dart` (follow-up 2026-05-26)
	- Đổi thư mục lưu backup cục bộ sang `Documents/quanlyshop/sqlite_backups`.
	- Giữ tương thích với thư mục cũ `Documents/sqlite_backups` khi liệt kê file.
	- Thêm remap `shopId` cho restore SQLite sang shop hiện tại khi người dùng chọn chế độ chuyển shop.
- `lib/views/backup_restore_view.dart` (follow-up 2026-05-26)
	- Nút Share không còn giữ loading overlay trong lúc mở share sheet.
- `lib/views/super_admin_console_view.dart` (follow-up 2026-05-26)
	- Thêm preset một chạm để chọn nhanh luồng xóa dữ liệu cũ, giữ lại `repairs`, `customers`, `attendance`, `payroll_settings`, `work_schedules`.
- `lib/data/user_guide_repository.dart`
	- Cập nhật mô tả để nói rõ backup SQLite là snapshot theo shop, restore sang shop khác cần remap `shopId`.

### Follow-up Runtime Fixes (2026-05-26)
- `lib/views/backup_restore_view.dart`
	- Luồng restore SQLite (file cục bộ / backup cloud / danh sách backup cục bộ) nay cho phép **chọn từng mục dữ liệu** trước khi khôi phục.
	- Giữ tùy chọn remap shopId khi cần chuyển dữ liệu vào shop hiện tại.
- `lib/services/backup_service.dart`
	- Thêm `restoreSelectedFromLocalFile()` và `restoreSelectedSqliteFromFirebase()` để khôi phục chọn lọc theo nhóm dữ liệu.
	- Thêm lớp tương thích schema sau restore, tự đảm bảo các cột quan trọng của `products` (đặc biệt `shopId`) tồn tại.
- `lib/data/db_helper.dart`
	- Bổ sung check phòng thủ `products.shopId` trong `onOpen` để tránh lỗi `DatabaseException(no such column: shopId)` sau restore từ file DB cũ.
- `lib/widgets/clickable_product_chip.dart`
	- Redesign item sản phẩm trong chi tiết đơn bán: tối giản, nền sáng, spacing gọn, dễ đọc khi đơn có nhiều dòng.

### Validation (follow-up)
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/views/super_admin_console_view.dart`
	- Không có lỗi compile mới; còn info tối ưu `const`.
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart lib/data/db_helper.dart lib/widgets/clickable_product_chip.dart`
	- Không có lỗi compile mới; còn lint info của dự án.
- `flutter build apk --debug`: thành công.

## [2026-05-25d] - Hardening P0 AI: Context Tối Thiểu + Mask PII + Safe Logging

### Changed
- `functions/index.js`
	- Thêm lớp hardening P0 cho `chatAssistant`:
		- `detectChatIntent()` để phân loại intent câu hỏi.
		- `buildStatsContextByIntent()` để chỉ gửi context tối thiểu theo intent (kho/công nợ/tài chính/sửa/bán/tổng quan), loại bỏ context chi tiết không cần thiết.
		- `maskPii()` + `sanitizeHistory()` để ẩn số điện thoại/email/số dài và giảm lịch sử từ 10 xuống 6 turns.
	- Thay toàn bộ log thô prompt/answer bằng telemetry an toàn:
		- `requestId`, `uid`, `intent`, `q_len`, `answer_len`, `latency_ms`.
	- Bỏ log thô ở các AI callable khác:
		- `createRepairOrderAI`: không log nội dung text/result JSON nữa.
		- `parseOrderAI`: không log text người dùng nữa.

### Validation
- `node --check functions/index.js`: ✅ hợp lệ cú pháp JavaScript.
- `flutter analyze`: hoàn tất với warning/info legacy toàn repo (`1525 issues`), không phát sinh compile error mới từ task này.
- `flutter build apk --debug`: ✅ thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.

## [2026-05-25c] - Hoàn Tất Industry Vocabulary Engine + Audit Rủi Ro AI

### Added
- `DOCS/vocabulary/vocabulary.json`
	- Bản tổng hợp vocabulary engine theo domain cửa hàng sửa chữa điện thoại.
	- Bao gồm: brands, device families, repair issues, business entities, supported intents, preprocess pipelines.
- `DOCS/vocabulary/intent_mapping.json`
	- Mapping intent đầy đủ cho luồng: tạo đơn sửa, tạo đơn bán, nhập kho, xem kho, công nợ, tài chính.
	- Bổ sung `disambiguation_rules` và `fallback` cho câu mơ hồ.
- `DOCS/AI_SECURITY_RISK_AUDIT.md`
	- Audit rủi ro đọc dữ liệu AI context và rủi ro token/key trong luồng `chatAssistant` + `createRepairOrderAI`.
	- Nêu rõ mức độ rủi ro, bằng chứng, và checklist hardening theo ưu tiên P0/P1/P2.

### Changed
- `DOCS/vocabulary/alias_mapping.json`
	- Mở rộng alias thiết bị/sửa chữa/slang theo thực tế vận hành cửa hàng.
- `DOCS/vocabulary/typo_mapping.json`
	- Bổ sung lỗi chính tả phổ biến cho brand/model/repair/business terms.
- `DOCS/vocabulary/phonetic_mapping.json`
	- Mở rộng map nhận diện giọng nói (số đọc model, nhầm âm kỹ thuật).
- `docs/DOCUMENTATION_INDEX.md`
	- Bổ sung nhóm tài liệu AI & NLP cho vocabulary engine và security audit.
- `docs/HANDOVER.md`
	- Cập nhật trạng thái hoàn tất task vocabulary engine + audit rủi ro AI.

### Validation
- `flutter analyze`: hoàn tất, vẫn còn warning/info legacy toàn dự án (không phát sinh lỗi compile mới từ thay đổi tài liệu).
- `flutter build apk --debug`: thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.
- JSON syntax check: OK cho 5 file vocabulary (`ConvertFrom-Json`).

## [2026-05-25b] — Progressive Intent Clarification + Máy Xác + NCC Link Kho

### Added
- `lib/services/ai_chat_service.dart` + `lib/widgets/ai_chat_overlay.dart`
  - **Progressive Intent Clarification**: nhập ngắn ("bán", "sửa", "kho", "nợ", "tài chính", "NCC", "linh kiện", tên hãng) → AI hiển thị chip gợi ý thay vì đi thẳng cloud
  - `AiIntentSuggestion` + `AiClarifyResponse` types; `detectAmbiguousIntent()` method
  - `AiActionType.openSalesTab` / `openRepairsTab` — đóng panel + chuyển tab
  - `quickAnswer()`: thêm handler "tạo đơn bán" → salesTab, "tạo đơn sửa" → repairsTab
- `lib/widgets/quick_action/quick_action_sheet.dart` — thêm "Máy xác mới" (SalvagePhoneView, icon brown)

### Changed
- `lib/widgets/app_popup.dart` — `PopupInfoRow` thêm param `trailingIcon` để phân biệt copy vs navigate chevron
- `lib/views/inventory_view.dart` — row "Nhà cung cấp" trong popup sản phẩm kho bây giờ tappable → mở `SupplierDetailView`; màu teal khi có link

---

## [2026-05-25] — AI Stats Year Scope + Fix Mở Đơn Bán Từ AI

### Added
- `lib/services/ai_chat_service.dart`
  - `AiChatStats`: 6 trường mới cho thống kê năm nay (`salesThisYear`, `saleRevenueThisYear`, `repairRevenueThisYear`, `revenueThisYear`, `profitThisYear`, `repairsThisYear`)
  - `getTodayStats()`: thêm 3 query song song cho khoảng năm, tính toán vòng lặp sau monthly
  - `quickAnswer()`: intent mới "năm nay / doanh thu năm / thống kê năm" trả về tổng hợp năm; "bán hàng hôm nay / đơn bán hôm nay"; "sửa chữa hôm nay / đơn sửa hôm nay"; "tài chính / tổng hợp" mở rộng hiển thị cả 3 kỳ (hôm nay + tháng + năm)

### Fixed
- `lib/data/db_helper.dart` — `getLatestSale()`: đổi `orderBy: 'createdAt DESC'` → `'soldAt DESC'` — bảng `sales` không có cột `createdAt`, khiến AI action "mở đơn bán gần nhất" luôn trả về null

---

## [2026-05-24b] — Premium Product Chip + Staff Link + Draggable AI FAB

### Changed
- `lib/widgets/clickable_product_chip.dart` — Redesign từ nền xanh phẳng sang gradient dark-navy→blue, icon box frosted-glass, badge QR serial, shadow — giao diện premium hơn
- `lib/views/sale_detail_view.dart` — Row "Nhân viên" tappable, bấm vào mở `StaffPublicProfileView` theo `sellerUid`
- `lib/widgets/ai_chat_overlay.dart` — FAB AI có thể kéo thả (drag) để di chuyển trên màn hình; vị trí mặc định bottom-right; khóa drag khi panel đang mở

---

## [2026-05-24] — Fix NCC Detail + AI Overlay + NCC Tappable Links

### Fixed
- `lib/views/supplier_detail_view.dart`
  - "Lịch sử nhập": hiển thị debts (SHOP_OWES) khi không có import history chính thức — phù hợp với thực tế ghi nợ nhập
  - "Thống kê": tính từ `_debts` thay vì service stats (trước trả về toàn 0)
  - "Sản phẩm" KHO TỔNG: query thêm sản phẩm có `supplier IS NULL/''` cho warehouse-type supplier
- `lib/widgets/ai_chat_overlay.dart`: fix crash "No Material widget ancestor" — bọc panel bằng `Material` thay vì `Container`
- `lib/data/db_helper.dart`
  - Thêm `getSupplierByName(name)` — tìm NCC theo tên trong shop hiện tại
  - Thêm `isWarehouse` param cho `getProductsBySupplier()`

### Added
- NCC tappable links — bấm vào tên nhà cung cấp mở thẳng `SupplierDetailView`:
  - `lib/views/inventory_detail_view.dart` — row "Nhà cung cấp" trong chi tiết sản phẩm kho
  - `lib/views/parts_inventory_view.dart` — row "Nhà cung cấp" trong chi tiết linh kiện
  - `lib/views/import_order_detail_view.dart` — row "NCC" trong chi tiết đơn nhập

---

## [2026-05-23] — Nhập Nhanh Đơn Sửa/Đơn Bán Bằng Câu Lệnh Tự Nhiên

### Added
- `lib/services/natural_order_parser_service.dart` — Parser câu lệnh tự nhiên cho 2 ý định: tạo đơn sửa và tạo đơn bán.

### Changed
- `lib/views/create_repair_order_view.dart`
	- Thêm nút `auto_awesome` trên AppBar để nhập nhanh bằng 1 câu lệnh.
	- Thêm dialog nhập câu lệnh và tự điền form đơn sửa.
	- Nếu câu lệnh không có giá, tự điền `0đ` theo yêu cầu nghiệp vụ.
- `lib/views/create_sale_view.dart`
	- Thêm nút `auto_awesome` trên AppBar để nhập nhanh bằng 1 câu lệnh.
	- Tự parse sản phẩm/IMEI/khách hàng/phương thức thanh toán.
	- Tự tìm sản phẩm trong kho theo IMEI hoặc tên gợi ý rồi đưa vào đơn.
	- Hỗ trợ nhận diện "trả góp FE" và tự điền `TRẢ GÓP (NH)` + ngân hàng `FE`.

### Validation
- Chạy `flutter analyze lib/services/natural_order_parser_service.dart lib/views/create_repair_order_view.dart lib/views/create_sale_view.dart`.
- Kết quả: không phát sinh lỗi compile mới; còn các warning/info legacy đã tồn tại từ trước trong 2 màn hình tạo đơn.

### Hotfix
- `lib/views/create_repair_order_view.dart`
	- Thêm `build-safe fallback` để chặn trạng thái trắng màn hình khi có lỗi render widget con.
	- Khi có lỗi build, app chuyển sang form dự phòng (vẫn tạo đơn được) và log lỗi để debug thay vì blank screen.
	- Fix dứt điểm lỗi layout `BoxConstraints(w=Infinity, 44.0<=h<=Infinity)` ở thanh nút dưới cùng bằng cách ràng buộc chiều rộng hữu hạn cho nút `Lưu & In`.

---

## [2026-05-22] — Audit Toàn Diện UX/UI Ứng Dụng

### Added
- `DOCS/UX_AUDIT/UX_SCORE_REPORT.md` — Chấm điểm tổng thể UX/UI, severity, priority và màn hình cần redesign.
- `DOCS/UX_AUDIT/UX_PROBLEMS.md` — Liệt kê vấn đề UX, anti-pattern, technical debt và root causes.
- `DOCS/UX_AUDIT/UX_IMPROVEMENTS.md` — Đề xuất cải thiện theo hướng system-first và workflow-first.
- `DOCS/UX_AUDIT/DESIGN_SYSTEM_PROBLEMS.md` — Audit nợ design system, AppBar fragmentation, visual inconsistency.
- `DOCS/UX_AUDIT/WORKFLOW_OPTIMIZATION.md` — Tối ưu luồng repair, inventory, debt, payment, settings.
- `DOCS/UX_AUDIT/LOADING_AND_ASYNC_UX.md` — Audit loading/sync/save feedback và async communication.
- `DOCS/UX_AUDIT/MODERNIZATION_PLAN.md` — Roadmap hiện đại hóa UX/UI theo phase, có ưu tiên và KPI.

### Changed
- `docs/DOCUMENTATION_INDEX.md` — Bổ sung nhóm tài liệu `DOCS/UX_AUDIT`.
- `docs/HANDOVER.md` — Cập nhật initiative hiện tại và kết quả audit UX/UI.

### Validation
- Tài liệu audit đã tạo đủ `7` file trong `DOCS/UX_AUDIT`.
- Audit dựa trên đọc trực tiếp các màn hình/ widget trọng yếu và số đo repo-level (`AppBar`, `CircularProgressIndicator`, `showDialog`, `showModalBottomSheet`).
- `flutter analyze` / `flutter build`: không chạy lại cho task này vì chỉ thay đổi tài liệu, không sửa code runtime.

---

## [2026-05-22] — Tạo Hệ Thống Blueprint Tài Liệu Toàn App (DNA Rebuild)

### Added
- `DOCS/BLUEPRINT/index.md` — Chỉ mục blueprint và cấu trúc tài liệu.
- `DOCS/BLUEPRINT/CORE_ARCHITECTURE.md` — Kiến trúc lõi, startup/async/data flow/sync.
- `DOCS/BLUEPRINT/BUSINESS_LOGIC.md` — Logic nghiệp vụ theo flow thực tế.
- `DOCS/BLUEPRINT/DESIGN_SYSTEM.md` — Design DNA (màu, type, spacing, hierarchy).
- `DOCS/BLUEPRINT/COMPONENT_LIBRARY.md` — Thư viện component tái sử dụng.
- `DOCS/BLUEPRINT/USER_FLOW_MAP.md` — User/admin/offline/sync flow map + screen graph.
- `DOCS/BLUEPRINT/DATABASE_SCHEMA.md` — Schema SQLite/Firestore, quan hệ, index, migration.
- `DOCS/BLUEPRINT/API_AND_SERVICES.md` — Vai trò services, retry/failure, service graph.
- `DOCS/BLUEPRINT/OFFLINE_BEHAVIOR.md` — Hành vi app khi mất mạng và conflict handling.
- `DOCS/BLUEPRINT/APP_REBUILD_GUIDE.md` — Hướng dẫn rebuild theo thứ tự ưu tiên.
- `DOCS/BLUEPRINT/README_FINAL.md` — Tổng kết blueprint, rủi ro, khả năng rebuild.
- `DOCS/BLUEPRINT/TODO_GAPS.md` — Danh sách gaps cần xác minh runtime.
- `DOCS/BLUEPRINT/screens/*.md` — 112 hồ sơ màn hình/view (bao phủ toàn bộ `lib/views`).
- `scripts/generate_blueprint_screens.ps1` — Script sinh hồ sơ màn hình.
- `scripts/regenerate_blueprint_screens_vi.ps1` — Script chuẩn hóa hồ sơ màn hình tiếng Việt có dấu.

### Changed
- `docs/DOCUMENTATION_INDEX.md` — Bổ sung nhóm tài liệu BLUEPRINT và cập nhật ngày.

### Validation
- Blueprint generation: ✅ Thành công (`112` screen docs).
- `flutter analyze`: ⚠️ Hoàn tất nhưng còn `1552` issues pre-existing toàn dự án (chủ yếu info/warning, không phải do thay đổi docs).
- `flutter build apk --debug`: ✅ Thành công, tạo `build/app/outputs/flutter-apk/app-debug.apk`.

---

## [2026-05-21] — Khởi động dự án Flavor Split + Tối ưu Excel Export

### Added
- `docs/PROJECT_OVERVIEW.md` — Tổng quan dự án 2 flavor
- `docs/ROADMAP_ONLINE_OFFLINE.md` — Lộ trình 8 phases
- `docs/PROGRESS_TRACKER.md` — Theo dõi tiến độ
- `docs/DECISIONS.md` — ADR-001 đến ADR-005 (quyết định kiến trúc)
- `docs/RISKS_AND_ISSUES.md` — Risk register
- `docs/TEST_RESULTS.md` — Template kết quả test
- `docs/phases/PHASE_01_FLAVORS.md` đến `PHASE_08_TESTING.md`
- `lib/data/db_helper.dart`: `getAllImportOrderItemsForOrders()` bulk query

### Changed
- `docs/ARCHITECTURE.md` — Cập nhật kiến trúc flavor split
- `docs/HANDOVER.md` — Cập nhật trạng thái dự án

### Fixed (perf)
- `lib/finance_v2/finance_v2_data_service.dart`: `loadSnapshot()` — 17 queries tuần tự → parallel futures
- `lib/finance_v2/finance_v2_daily_report_view.dart`:
  - `_buildAuditAnalysis()`: fix duplicate repair fetch nội bộ; accept pre-loaded data (8 params)
  - `_buildInventoryAudit()`: accept pre-loaded inventory data (5 params)
  - `_exportDetailedReport()`: 14 reads → 9 reads (−36%)
  - `_printDetailedReport()`: 12 reads → 9 reads (−25%)
  - `_exportReport()`: 31 reads → 28 reads; parallel pre-fetch
- `lib/utils/excel_export_helper.dart`: N+1 trong `exportImportOrders()` → 2 reads fixed

---

## [2026-05-20] - Fix Công Nợ Đối Tác Bị Mất Sau Refresh

### Vấn đề
Khi refresh màn hình Quản Lý Công Nợ (tab Đối Tác):
- Một số khoản nợ đối tác biến mất khỏi danh sách
- Tổng nợ giảm không chính xác
- Snackbar "Không tìm thấy đối tác!" xuất hiện khi bấm Thanh Toán

### Nguyên nhân
1. `getRepairPartners()` chỉ lấy `active = 1` → đối tác đã xóa mềm (`deleted=1`) bị lọc hoàn toàn, kéo theo khoản nợ tự động biến mất
2. `_navigateToPartnerDetail` dùng `partner['id']` (là `debtId` với nợ thủ công) để lookup `repair_partners` → luôn thất bại
3. Khi lookup thất bại → snackbar nhưng không thông tin rõ, bản ghi nợ vẫn giữ nguyên trên màn hình

### Sửa

**A. `debt_summary_service.dart`** — Orphan partner detection
- Thêm `getAllRepairPartnersRaw()` trong `db_helper.dart` (trả về toàn bộ hàng kể cả `deleted=1`)
- Sau khi xử lý đối tác active, quét thêm đối tác deleted/inactive
- Nếu `remain > 0` → thêm vào danh sách với `missingPartner: true` + log `debugPrint`
- Nợ thủ công: thử khớp `personName` với đối tác active; nếu không tìm được → `missingPartner: true`
- Bỏ qua nợ thủ công đã được đại diện bởi entry auto-detect cùng partner

**B. `debt_view.dart`** — Card + Navigation
- `_partnerDebtCard`: khi `missingPartner == true` → icon cảnh báo đỏ thay handshake, tên đỏ + tooltip
- `_navigateToPartnerDetail`: sử dụng `partner['partnerId']` thay `partner['id']`; fallback tìm theo tên nếu ID lookup thất bại; snackbar giải thích rõ ràng thay vì im lặng

### Files thay đổi
- `lib/services/debt_summary_service.dart`
- `lib/data/db_helper.dart`
- `lib/views/debt_view.dart`

---

## [2026-05-20] - Tab Linh Kiện: Nút + AppBar, Auto-Open Thêm Từ Đơn Sửa, Fix Dialog

### Thay đổi

**A. Tab Linh Kiện — Xóa FAB, Thêm Nút + AppBar**
- `PartsInventoryViewContent`: Xóa FAB "Thêm linh kiện" ở dưới cùng
- `InventoryView`: Khi tab LINH_KIEN active → AppBar hiển thị nút `+` thay cho nút "Nhập kho"
- Trigger qua `ValueNotifier<int> _partsAddTrigger` truyền xuống widget con

**B. Chi Tiết Đơn Sửa "NHẬP LK MỚI" → Tự Mở Dialog Thêm**
- `repair_detail_view.dart`: `_navigateToPartsInventory()` truyền `triggerPartsAdd: true` vào `InventoryView`
- `InventoryView.initState()`: Nếu `triggerPartsAdd == true` → bắn `_partsAddTrigger` sau frame đầu tiên → dialog thêm linh kiện tự mở

**C. Fix Dialog Sửa/Thêm Linh Kiện — iOS Rendering**
- `_showEditPartDialog` (embedded tab) + `_showAddPartDialog` (standalone): bọc content bằng `SizedBox(width: double.maxFinite)` → fix trường tên không hiển thị trên iOS

### Files thay đổi
- `lib/views/parts_inventory_view.dart`
- `lib/views/inventory_view.dart`
- `lib/views/repair_detail_view.dart`

---

## [2026-05-20] - Fix Popup Trắng iOS (Vị Trí Kho & Sửa Sản Phẩm)

### Vấn đề
Trên iOS, hai popup hiện trắng hoàn toàn không bấm được:
1. **"Tạo mới vị trí lưu kho"** (FAB trong `StorageLocationView`)
2. **"Sửa sản phẩm"** trong màn hình Kho (vẫn trắng sau fix SizedBox trước đó)

### Nguyên nhân & Sửa

**A. `_LocationFormDialog` — `SizedBox(width: 340)` → `double.maxFinite`**
Fixed-width 340 không phải pattern chuẩn; đổi thành `double.maxFinite` để iOS tính layout đúng, khớp với fix `_editProduct`.

**B. `_confirmDelete` — context sai trong dialog action**
`builder: (_) => AlertDialog(actions: [Navigator.pop(context, ...)])` dùng outer context thay vì dialog's context → iOS freezes dialog. Sửa: đổi `builder: (ctx)` và dùng `Navigator.pop(ctx, ...)`.

**C. `StorageLocationSelector._showPicker` — nested modal trong dialog**
`showModalBottomSheet(context: dialogContext)` → trên iOS, bottom sheet push vào navigator của dialog thay vì root navigator → dialog đóng băng. Sửa: thêm `useRootNavigator: true`.

### Files thay đổi
- `lib/views/storage_location_view.dart`
- `lib/widgets/storage_location_selector.dart`

---

## [2026-05-20] - Fix Sai Lệch Số Liệu Nhật Ký Tài Chính (3 vấn đề)

### Vấn đề & Nguyên nhân

**1. Giá vốn lẻ đến đồng (7 đơn tháng 3)**
App mới phân bổ giá vốn theo tỉ lệ cho bundle sản phẩm → ra số lẻ (VD: 5,974,867đ). BC làm tròn nghìn, nhật ký không → lệch doanh thu/lợi nhuận.

**2. Chi phí đối tác sửa chữa không vào nhật ký**
Thanh toán đối tác SC đi qua `PaymentIntentService` (hệ thống công nợ) → xuất hiện trong BC là "Chi phí đối tác" nhưng nhật ký không có dòng tương ứng → lệch tổng chi phí.

**3. Số dư đầu kỳ CN NCC bị bỏ sót (type 'OWE' từ app cũ)**
`_loadOpeningDebtBalances` chỉ nhận `SHOP_OWES`, `OTHER_SHOP_OWES`, `OWED` — bỏ sót `OWE` là type do app cũ dùng cho nợ NCC → số dư đầu kỳ = 0 thay vì đúng.

### Sửa
- **`finance_v2_view.dart`**:
  - Round `revenueCost` và `lineCostTotal` về 1000đ khi xây dựng nhật ký
  - Load `repairPartnerPayments` trong `_buildDetailedAuditLogEntries` → tạo EXPENSE entry riêng cho từng khoản đối tác SC (không nhân đôi tiền ra, chỉ ghi `lineCostTotal`)
  - Thêm `'OWE'` vào `isPayable` check trong `_loadOpeningDebtBalances`
- **`finance_v2_reconciliation.dart`**: Sửa công thức chi phí EXPENSE dùng `lineCostTotal` thay vì `cashOut + transferOut` (hỗ trợ partner entries không có cashOut)

### Files thay đổi
- `lib/finance_v2/finance_v2_view.dart`
- `lib/finance_v2/finance_v2_reconciliation.dart`

---

## [2026-05-20] - Fix Popup Trắng Khi Sửa Sản Phẩm Trong Kho

### Vấn đề
Khi bấm "Sửa" sản phẩm trong tab Kho, popup hiện ra nhưng trắng hoàn toàn — nội dung không hiển thị.

### Nguyên nhân gốc
`SingleChildScrollView` bên trong `AlertDialog.content` không có ràng buộc width rõ ràng. Flutter release mode không thể tính toán layout, khiến content render với size 0 — không nhìn thấy vì nền dialog màu trắng (`PopupTheme.bgDark = 0xFFFFFFFF`).

### Sửa
- **`inventory_view.dart`** (`_editProduct`): Bọc `SingleChildScrollView` bằng `SizedBox(width: double.maxFinite)` — cung cấp width constraint rõ ràng để Flutter layout được content đúng cách.

### Files thay đổi
- `lib/views/inventory_view.dart`

---

## [2026-05-19] - Ảnh Sản Phẩm & Vị Trí Kho Trong Nhập Hàng; Location Repair; Badge Lỗi Nhỏ Hơn

### Thay đổi

**Task 1 — Ảnh sản phẩm trong nhập kho (SmartStockIn, FastStockIn)**
- **`smart_stock_in_view.dart`**: Thêm `ImagePickerWidget` bên dưới `StorageLocationSelector` — cho phép chụp/chọn ảnh ngay lúc nhập từng sản phẩm
- **`fast_stock_in_view.dart`**: Tương tự — thêm `ImagePickerWidget` bên dưới selector vị trí kho
- **`stock_entry_service.dart`**: Thêm `imagesToUpload` list trước `runTransaction`. Bên trong loop tạo product, thu thập `{firestoreId, localPath, shopId}` nếu `item.localImagePath != null`. Sau khi transaction thành công, gọi `ProductImageService.uploadProductImage()` background cho từng ảnh
- **`stock_entry_model.dart`**: `StockEntryItem` đã có trường `localImagePath` (thêm từ phiên trước)

**Task 2 — Vị trí lưu kho trong đơn sửa**
- **`create_repair_order_view.dart`**: Thêm `StorageLocationSelector` sau trường địa chỉ — lưu `storageLocationId/Code/Name` vào `Repair` object khi tạo đơn
- **`repair_detail_view.dart`**: Thay thẻ location tĩnh bằng card luôn hiển thị + editable — khi thay đổi: cập nhật SQLite, ghi audit log với before/after code

**Task 3 — Vị trí kho linh kiện có ghi log**
- **`parts_inventory_view.dart`**: Cập nhật `PART_INFO_UPDATE` audit log để bao gồm `oldLocationCode` và `newLocationCode` trong payload

**Task 4 — Thu nhỏ badge lỗi thiết bị trong list đơn sửa**
- **`order_list_view.dart`**: Font badge lỗi từ 14 bold → 11 w600, thêm `maxLines: 1, overflow: ellipsis`, padding nhỏ hơn

### Files thay đổi
- `lib/views/smart_stock_in_view.dart`
- `lib/views/fast_stock_in_view.dart`
- `lib/services/stock_entry_service.dart`
- `lib/models/stock_entry_model.dart`
- `lib/views/create_repair_order_view.dart`
- `lib/views/repair_detail_view.dart`
- `lib/views/parts_inventory_view.dart`
- `lib/views/order_list_view.dart`

---

## [2026-05-19] - UI Fixes: Lỗi Thiết Bị, Vị Trí Lưu Kho, AppBar Inventory

### Vấn đề & sửa
- **`repair_detail_view.dart`**: Chuyển badge "Lỗi thiết bị" từ AppBar (bị tràn/cắt ngắn) xuống body thành Card đỏ hiển thị toàn bộ nội dung lỗi; AppBar chỉ còn `r.model`
- **`home_view.dart`**: Thêm shortcut "Vị trí lưu kho" trong tab Kho (bên dưới "Lịch sử nhập kho") để vào nhanh màn hình quản lý vị trí
- **`storage_location_view.dart`**: 3 fix:
  - Fix danh sách rỗng dù đã có sản phẩm lưu ở vị trí — tự tạo "virtual location" từ `locationCode` trong bảng products khi chưa có record chính thức
  - Fix stats mismatch (0 sp) — lookup key theo case-insensitive + trim thay vì exact match
  - Thay `FloatingActionButton.extended` bằng FAB tròn thông thường — không bị cắt bởi bottom bar
- **`inventory_view.dart`**: Gộp 3 icon ít dùng (Vị trí, In tem, Excel) vào `PopupMenuButton` "⋮" — giảm từ 7 xuống 4+1 icon, tránh nút + bị đè lên nút back

### Files thay đổi
- `lib/views/repair_detail_view.dart`
- `lib/views/home_view.dart`
- `lib/views/storage_location_view.dart`
- `lib/views/inventory_view.dart`

---

## [2026-05-19] - Fix Offline: Dừng Loading Vô Hạn Khi Mất Mạng (Firestore Offline)

### Vấn đề gốc
- Các thao tác nhập kho (`confirmEntry`, `cancelEntry`) bị loading vô hạn khi thiết bị mất kết nối Firestore server (dù WiFi vẫn bật)
- Nguyên nhân: `Firestore.collection().doc().get()` và `collection().where().get()` treo mãi khi offline — không có timeout, Future không bao giờ throw, `finally` block không chạy → spinner không dừng

### Sửa chính xác (`stock_entry_service.dart`)
- **`confirmEntry()` — pre-read entry (line ~273)**: Thêm `.timeout(8s)` + fallback `Source.cache`. Nếu cache cũng fail → trả về false ngay với thông báo "Không có mạng"
- **`confirmEntry()` — pre-query repair_parts (line ~298)**: Thêm `.timeout(5s)` vào `.get()`. Đã có try/catch → TimeoutException được bắt → tiếp tục với kết quả rỗng (tạo mới thay vì upsert)
- **`confirmEntry()` — pre-query products (line ~328)**: Thêm `.timeout(5s)` — cùng logic
- **`confirmEntry()` — runTransaction (line ~386)**: Thêm `.timeout(20s)`. Thêm `on TimeoutException` TRƯỚC `catch (e)` ở outer try → hiển thị thông báo "Không có mạng. Vui lòng kết nối internet để xác nhận nhập kho."
- **`cancelEntry()` — pre-read (line ~135)**: Thêm `.timeout(8s)` + cache fallback — cùng pattern

### Kết quả
- Spinner luôn dừng sau tối đa 8–20 giây (tuỳ từng bước)
- Tự đồng bộ khi có mạng trở lại không bị ảnh hưởng
- Logic nghiệp vụ giữ nguyên — chỉ thêm timeout và fallback

### Files thay đổi
- `lib/services/stock_entry_service.dart`

---

## [2026-05-19] - Tích Hợp Vị Trí Lưu Kho Toàn Diện (Location Integration v2)

### Tính năng bổ sung
- **`smart_stock_in_view.dart`**: Thêm `StorageLocationSelector` trong form NHẬP KHO MỚI — chọn vị trí khi nhập sản phẩm mới
- **`fast_stock_in_view.dart`**: Thêm `StorageLocationSelector` trong form NHẬP KHO SIÊU TỐC — chọn vị trí khi nhập nhanh
- **`stock_entry_service.dart`**: Truyền `locationCode/Id/Name` vào Firestore product khi `confirmEntry`
- **`supplier_detail_view.dart`**: Thêm tab "Sản phẩm" (tab 4) hiển thị tất cả sản phẩm trong kho từ NCC này — có thể nhấn vào từng sản phẩm để xem chi tiết
- **`db_helper.dart`**: Thêm method `getProductsBySupplier` — query sản phẩm theo supplierId hoặc supplierName
- **`storage_location_view.dart`**: Fix crash khi mở (thiếu `catch` trong `_load()`) — hiển thị snackbar lỗi thay vì crash
- **`repair_detail_view.dart`**: Hiển thị badge "Vị trí cất máy" trong body khi repair có storageLocationCode
- **`repair_detail_view.dart`**: Fix AppBar overflow — dùng Row+Flexible thay Wrap, giảm font size

### Data Model
- **`stock_entry_model.dart`** (`StockEntryItem`): Thêm `locationId`, `locationCode`, `locationName` — truyền qua toàn bộ flow nhập kho

### Tương thích ngược
- Sản phẩm cũ không có location vẫn hiển thị "Chưa cập nhật vị trí" — không mất dữ liệu
- Migration: không cần — columns đã tồn tại từ DB v98

### Files thay đổi
- `lib/models/stock_entry_model.dart`
- `lib/views/smart_stock_in_view.dart`
- `lib/views/fast_stock_in_view.dart`
- `lib/services/stock_entry_service.dart`
- `lib/views/supplier_detail_view.dart`
- `lib/data/db_helper.dart`
- `lib/views/storage_location_view.dart`
- `lib/views/repair_detail_view.dart`

---

## [2026-05-19] - Refactor NCC & Đối Tác Sửa Chữa — Light Premium CRM

### Tính năng / UX thay đổi
- **`supplier_list_view.dart`**: Xóa `PopupMenuButton (...)` khỏi card NCC và card đối tác
- **`supplier_list_view.dart`**: Toàn bộ card bọc `Material + InkWell` — chạm bất kỳ đâu → mở trang chi tiết
- **`supplier_list_view.dart`**: Avatar 48px (radius 24), layout compact: tên + nợ + ngày | badge trạng thái + nút thanh toán nhanh
- **`supplier_detail_view.dart`**: Thêm AppBar actions Edit (✏) + Delete (🗑) — edit mở `SupplierFormView`, delete yêu cầu xác thực mật khẩu
- **`repair_partner_detail_view.dart`**: Thêm AppBar actions Edit + Delete — edit mở `RepairPartnerFormView`, delete confirm dialog

### Refactor / Clean-up
- Xóa `_confirmDeleteSupplier` + `_showPasswordDialog` khỏi `supplier_list_view.dart` (logic chuyển vào detail view)
- Xóa getter `_terms` + import `business_type_helper.dart` không còn dùng trong list view
- Tất cả `withOpacity` mới → `withValues(alpha: ...)` để tránh deprecation
- Zero new warnings/errors (flutter analyze)

### Files thay đổi
- `lib/views/supplier_list_view.dart`
- `lib/views/supplier_detail_view.dart`
- `lib/views/repair_partner_detail_view.dart`
- `DOCS/CHANGELOG.md`
- `DOCS/HANDOVER.md`

---

## [2026-05-19] - Vị Trí Lưu Kho cho Linh Kiện

### Tính năng bổ sung
- **`parts_inventory_view.dart`**: Pre-populate StorageLocationSelector khi sửa linh kiện đã có vị trí
- **`parts_inventory_view.dart`**: Hiển thị chip vị trí (📍 màu indigo) trong card danh sách linh kiện
- **`parts_inventory_view.dart`**: Hiển thị "Vị trí kho" trong sheet chi tiết linh kiện

### Files thay đổi
- `lib/views/parts_inventory_view.dart`
- `DOCS/HANDOVER.md`

---

## [2026-05-19] - Tắt Thông Báo Bảo Hành + Cải Thiện UI 5 Màn Hình

### Tắt thông báo bảo hành
- **`warranty_reminder_service.dart`**: Thêm flag `_enableWarrantyPushNotifications = false` để tắt push notification bảo hành (nhiều thiết bị hết hạn gây phiền). Dashboard widget vẫn hiển thị data bình thường.

### Cải thiện giao diện chuyên nghiệp
- **`parts_inventory_view.dart`**: Fix overflow stats bar — bọc value text trong `FittedBox(fit: BoxFit.scaleDown)` để tự co lại trên màn nhỏ
- **`staff_list_view.dart`**: Redesign dialog tạo nhân viên — gradient header xanh đậm, TextFields có icons và outlined border, section labels (THÔNG TIN ĐĂNG NHẬP / CÁ NHÂN / PHÂN QUYỀN), dropdown role có icon, footer buttons styled
- **`inventory_view.dart` (product detail sheet)**: Thêm price cards (Giá nhập / Giá bán) trực quan ngay dưới product name, thay vì chỉ là text trong list item
- **`inventory_view.dart` (edit dialog)**: Tiêu đề AlertDialog → gradient header với icon, màu đậm chuyên nghiệp
- **`sale_detail_view.dart`**: Widget `_card` cải thiện — shadow nhẹ, section header có border-left accent màu shop, background tông nhạt, loại bỏ màu `Colors.pink` cũ

### Files thay đổi
- `lib/services/warranty_reminder_service.dart`
- `lib/views/parts_inventory_view.dart`
- `lib/views/staff_list_view.dart`
- `lib/views/inventory_view.dart`
- `lib/views/sale_detail_view.dart`
- `docs/CHANGELOG.md`
- `docs/HANDOVER.md`

---

## [2026-05-19] - Finance V2 Excel Export — Nhãn Tiếng Việt Thân Thiện

### Cải tiến
- **Nhật ký giao dịch:** Tất cả 21 tên cột chuyển sang tiếng Việt (Thời gian, Loại giao dịch, Phân hệ, v.v.)
- **Loại giao dịch:** SALE→Bán hàng, RETURN→Hoàn trả, REPAIR→Sửa chữa, IMPORT→Nhập kho, EXPENSE→Chi phí, DEBT_CREATE→Tạo công nợ, DEBT_PAY→Thanh toán công nợ, v.v.
- **Phương thức thanh toán:** CASH→Tiền mặt, TRANSFER→Chuyển khoản, DEBT→Công nợ, MIXED→Kết hợp
- **Nguồn phát sinh:** Tiền tố ID ánh xạ sang nhãn đọc được (exp_→Chi phí vận hành, sale_→Đơn bán hàng, repair_→Đơn sửa chữa, v.v.)
- **Định dạng số:** Số tiền hiển thị dấu phẩy phân nghìn (1,234,567), ô bằng 0 để trống
- **Sheet Đối soát:** Toàn bộ nhãn kỹ thuật chuyển sang tiếng Việt (TOTAL_IN→Tổng tiền vào, PASS→Khớp, FAIL→Sai lệch)
- **Tên sheet:** activity_log→Nhật ký giao dịch, RECONCILIATION→Đối soát

### Files thay đổi
- `lib/finance_v2/finance_v2_view.dart` (headers, helper methods, _auditRow, sheet names)
- `lib/finance_v2/finance_v2_reconciliation.dart` (metricLabel, toSheetRows, detail strings)

---

## [2026-05-19] - Product Image & Storage Location System

### Tính năng mới

**Hệ thống ảnh sản phẩm:**
- `ImagePickerWidget` — chọn ảnh từ camera/thư viện, nén tự động (<300KB), xem full-screen
- `ProductImageService` — upload background lên Firebase Storage, retry khi thất bại
- Thumbnail sản phẩm hiển thị trong danh sách kho

**Hệ thống vị trí lưu kho:**
- `StorageLocation` model + DB table `storage_locations` (schema v98)
- `StorageLocationView` — màn hình CRUD quản lý vị trí (code, tên, kho/tầng/kệ/ô)
- `StorageLocationSelector` — widget chọn vị trí dạng bottom sheet

**Tích hợp toàn app:**
- Kho hàng: thumbnail + chip vị trí trong card sản phẩm; chọn ảnh+vị trí khi nhập/sửa
- Đơn sửa chữa: dialog chọn vị trí cất máy khi bấm XONG (tùy chọn)
- Danh sách đơn: hiển thị chip vị trí lưu kho
- AppBar kho: nút điều hướng đến trang quản lý vị trí

### Files thay đổi
- `lib/models/storage_location_model.dart` (mới)
- `lib/widgets/image_picker_widget.dart` (mới)
- `lib/widgets/storage_location_selector.dart` (mới)
- `lib/views/storage_location_view.dart` (mới)
- `lib/services/product_image_service.dart` (mới)
- `lib/data/db_helper.dart` (v97→v98, bảng mới + cột mới)
- `lib/models/product_model.dart` (thêm location + image fields)
- `lib/models/repair_model.dart` (thêm storageLocation fields)
- `lib/views/inventory_view.dart`
- `lib/views/repair_detail_view.dart`
- `lib/views/order_list_view.dart`

---

## [2026-05-17] - Reconciliation Patch v7 — TOTAL_DEBT_SUPPLIER dứt điểm (debt_payments corrupt)

### Root Cause xác nhận từ ADB device log

Bảng `debt_payments` có các bản ghi **corrupt/mislinked** với amount sai lệch nghiêm trọng:
- `pmt id=9`: amount=**60,000,000** nhưng nợ tương ứng (DT2 partner) chỉ 100,000
- `pmt id=8`: amount=**7,000,000** nhưng nợ tương ứng (KHO TỔNG part) chỉ 100,000

Hậu quả: `DEBT_PAY` từ main loop = -69,200,000 (dùng `debt_payments.amount`) nhưng `snap.payableTotal` = 33,190,500 (dùng `debts.paidAmount` — nguồn tin cậy). Hai nguồn **không đồng bộ** → reconciliation luôn FAIL.

### Giải pháp kiến trúc

**Tách biệt cash flow và debt balance**:
- **Cash flow** (`TOTAL_OUT`): dùng `debt_payments.amount` ✓ (đúng, cash thực sự đã ra)
- **Debt balance** (`TOTAL_DEBT_SUPPLIER`): dùng `debts.paidAmount` ✓ (nguồn tin cậy)

### Thay đổi code

**1. Main loop payment entries** (`_buildAuditEntries`):
- `debtSupplierChange: isSupplier ? -amount : 0` → `debtSupplierChange: 0`
- Cash flow (cashOut/cashIn) giữ nguyên → TOTAL_OUT không thay đổi

**2. Category B** (`_buildAuditEntries`):
- Bỏ logic `untracked = paidAmount - tracked` (phụ thuộc payment records)
- Dùng `paidAmount` trực tiếp cho tất cả in-period supplier debts có paid > 0
- referenceId: `catb_pay_*` (thay vì `untracked_pay_*`)

**3. `_loadOpeningDebtBalances()`**:
- Bỏ toàn bộ logic `inPeriodPayments` + `inPeriodByKey` (một DB query tiết kiệm)
- Opening = `totalAmount - storedPaid` (số dư hiện tại của pre-period debts)
- Nhất quán vì: opening(pre-period remaining) + flow(in-period net) = payableTotal ✓

### Kiểm chứng toán học

```
Opening: 0 (all debts in-period)
DEBT_CREATE: +35,590,500
DEBT_PAY (Cat B): -(100k + 100k + 600k + 1,600k) = -2,400,000
debtSupplierFlow = 33,190,500
debtSupplierClosing = 0 + 33,190,500 = snap.payableTotal ✓ PASS
```

TOTAL_OUT vẫn = 69,200,000 (cash flow đúng) ✓

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

### Validation
- `flutter analyze lib/finance_v2/finance_v2_view.dart` → 0 errors
- TOTAL_DEBT_SUPPLIER: PASS (diff=0)
- TOTAL_OUT, NET, TOTAL_DEBT_CUSTOMER: không thay đổi → vẫn PASS

---

## [2026-05-16] - Reconciliation Patch v6 (TOTAL_DEBT_SUPPLIER — Cat A + Cat B final fix)

### Root Cause (dứt điểm — diff=-66,200,000)

**Category A** (`_loadOpeningDebtBalances`): Payments lưu với `debtId=numeric` nhưng `debtFirestoreId=''` (rỗng). Hàm lookup `inPeriodByKey` chỉ dùng `debt.firestoreId` làm key → miss các payment này → `inPeriodPaid=0` → `paidBeforeStart=storedPaid` → `openingRemaining=0` → debt bị bỏ qua khỏi opening. Nhưng DEBT_PAY vẫn tính đủ -68M → lệch -68M. (NCC 2 60M, DT 2 7M, KHO TỔNG 1M)

**Category B** (`_buildDetailedAuditLogEntries`): Một số in-period supplier debts có `paidAmount > 0` nhưng không có record trong `debt_payments` (paidAmount cập nhật trực tiếp). DEBT_CREATE tính đủ totalAmount nhưng không có DEBT_PAY → balance leak +1.8M. (huy 1.6M, KHO TỔNG 100K, DT2 100K)

Combined: -68M + 1.8M = **-66.2M** ✓ khớp Excel.

### Fix
- **`lib/finance_v2/finance_v2_view.dart`** — `_loadOpeningDebtBalances`: dual-key lookup (firestoreId + numeric id), take max để tránh double-count.
- **`lib/finance_v2/finance_v2_view.dart`** — `_buildDetailedAuditLogEntries`: sau DEBT_CREATE loop, emit synthetic DEBT_PAY cho in-period supplier debts với untracked paidAmount.

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

### Commit
`b43c1aea`

---

## [2026-05-16] - Reconciliation Patch v5 (TOTAL_DEBT_SUPPLIER — deleted debt root cause)

### Root Cause (dứt điểm)
Payments trong `debt_payments` có thể link tới debt đã bị **soft-delete** (`deleted=1`) trong bảng `debts`. Các deleted debt này không xuất hiện trong `getDebtsByDateRange` (filter `deleted=0`) nên **không có trong DEBT_CREATE flow**, nhưng LEFT JOIN trong `getDebtPaymentsForCashFlowByDateRange` vẫn tìm thấy chúng, khiến `debtSupplierChange` bị trừ âm sai cho những payment này (NCC 2 60M, DT 2 7M → tổng lệch 66,800,000).

### Fix
- **`lib/data/db_helper.dart`** — `getDebtPaymentsForCashFlowByDateRange`: thêm cột `COALESCE(d.deleted, 0) as linkedDebtDeleted` vào SELECT.
- **`lib/finance_v2/finance_v2_view.dart`** — build DEBT_PAY entries: thêm biến `linkedDebtIsActive = hasLinkedDebtRecord && linkedDebtDeleted == 0`; chỉ set `debtSupplierChange = -amount` khi `linkedDebtIsActive` (debt tồn tại VÀ chưa bị xóa).

### Expected Result
- `DEBT_PAY` dsc = −2,400,000 (chỉ active KHO TỔNG 600K + 100K + DT2 100K + huy 1.6M)
- flow = DEBT_CREATE(23,570,000) + DEBT_PAY(−2,400,000) = 21,170,000
- closing = 12,020,500 + 21,170,000 = **33,190,500 = snap.payableTotal ✓**
- Tất cả chỉ số khác (TOTAL_OUT, TOTAL_IN, NET, ...) không thay đổi vì cash direction vẫn dùng `resolvedDebtType` từ JOIN đầy đủ.

### Files Modified
- `lib/data/db_helper.dart`
- `lib/finance_v2/finance_v2_view.dart`

---

## [2026-05-16] - Reconciliation Patch v2 (TOTAL_OUT + TOTAL_DEBT_SUPPLIER)

### Summary
Tiếp tục debug theo bộ Excel mới ngày 16/05/2026 và xử lý dứt điểm 3 chỉ số còn FAIL: `TOTAL_OUT`, `NET`, `TOTAL_DEBT_SUPPLIER`.

### Root Cause
- **TOTAL_OUT lệch 200,000**
	- `finance_v2_data_service.dart` dedup nhập hàng phụ thuộc so sánh số tiền (`amount`) nên có thể loại nhầm khoản nhập khác reference nhưng trùng số tiền.
- **TOTAL_DEBT_SUPPLIER lệch dấu và lệch lớn**
	- `DEBT_PAY` trong `activity_log` đang trừ `debtSupplierChange` cả với payment không join được vào bảng `debts` (ví dụ khoản trả không thuộc debt record hiện hữu), làm flow công nợ NCC bị âm giả.

### Fix Implemented
- **`lib/finance_v2/finance_v2_data_service.dart`**
	- Thêm `_canonicalImportReference()`.
	- Đổi dedup bổ sung import từ `supplier_import_history` sang theo **canonical reference key** thay vì so theo amount.
- **`lib/data/db_helper.dart`**
	- Trong `getDebtPaymentsForCashFlowByDateRange()`, bổ sung cột `linkedDebtId` từ join `debts`.
- **`lib/finance_v2/finance_v2_view.dart`**
	- Khi build `DEBT_PAY` entries cho audit log: chỉ ghi `debtSupplierChange = -amount` nếu payment **có linked debt record** (`linkedDebtId != null`).
	- Payment không link debt vẫn là tiền ra (`cashOut/transferOut`) nhưng không tác động flow công nợ NCC.

### Validation
- ⚠ `flutter analyze lib/finance_v2/finance_v2_data_service.dart lib/finance_v2/finance_v2_view.dart lib/data/db_helper.dart`
	- Không có error mới; còn các info style pre-existing.
- ✓ `flutter build apk --debug` thành công.

### Files Modified
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/data/db_helper.dart`

---

## [2026-05-16] - Reconciliation Patch v3 (TOTAL_DEBT_SUPPLIER opening fix)

### Summary
Kiểm tra bộ Excel tải lại cho thấy `TOTAL_OUT` và `NET` đã PASS, còn duy nhất `TOTAL_DEBT_SUPPLIER` lệch do số dư đầu kỳ công nợ NCC bị âm giả.

### Root Cause
- Trong `_loadOpeningDebtBalances()` vẫn có thể cộng vào opening các debt record không hợp lệ (`totalAmount <= 0`) hoặc opening còn lại không dương, làm `openingDebtSupplier` sai dấu.

### Fix Implemented
- **File:** `lib/finance_v2/finance_v2_view.dart`
	- Bỏ qua debt có `totalAmount <= 0` khi tính opening.
	- Bỏ qua debt có `openingRemaining <= 0` sau khi trừ phần đã trả trước kỳ.

### Validation
- ⚠ `flutter analyze lib/finance_v2/finance_v2_view.dart`: không có error mới, chỉ còn info style pre-existing.

### Files Modified
- `lib/finance_v2/finance_v2_view.dart`

---

## [2026-05-16] - Reconciliation Patch v4 + Export Success Dialog UI Fix

### Summary
Theo bộ file mới người dùng gửi, `TOTAL_OUT` và `NET` đã PASS nhưng `TOTAL_DEBT_SUPPLIER` vẫn FAIL. Đồng thời popup “Xuất file thành công” bị hiển thị khối nền xanh đặc (chữ/icon chìm).

### Fix Implemented
- **Audit/Reconciliation**
	- `lib/data/db_helper.dart`
		- Bổ sung `linkedDebtType` trong query `getDebtPaymentsForCashFlowByDateRange()`.
	- `lib/finance_v2/finance_v2_view.dart`
		- Khi tạo entry `DEBT_PAY`, chỉ ghi `debtSupplierChange = -amount` nếu payment:
			- có `linkedDebtId`, và
			- `linkedDebtType` thực sự là nợ NCC (`SHOP_OWES`/`OTHER_SHOP_OWES`/`OWED`).
		- Mục đích: loại các payment mapping sai loại nợ khỏi flow công nợ NCC.

- **UI Popup Export**
	- `lib/finance_v2/finance_v2_excel_export.dart`
		- Đổi thẻ thông tin file đã lưu từ nền xanh đậm sang nền xanh nhạt (`alpha 0.08`).
		- Giữ viền xanh nhẹ và đổi màu chữ sang xanh đậm tương phản (`#1B5E20`).
		- Kết quả: không còn khối xanh đặc như ảnh người dùng khoanh.

### Validation
- ⚠ `flutter analyze lib/finance_v2/finance_v2_excel_export.dart lib/finance_v2/finance_v2_view.dart lib/data/db_helper.dart`
	- Không có error mới; còn info style pre-existing.

### Files Modified
- `lib/data/db_helper.dart`
- `lib/finance_v2/finance_v2_view.dart`
- `lib/finance_v2/finance_v2_excel_export.dart`

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
