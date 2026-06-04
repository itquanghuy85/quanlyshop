# HANDOVER - HULUCA Shop Manager

Trạng thái hiện tại dự án, tasks đã hoàn thành, tasks pending, known issues, next steps.

---

## ⚡ Trạng thái hiện tại

**Version:** 1.x (develop) → 2.0 planning  
**Last Updated:** 2026-06-05  
**Build Status:** ✅ Debug build passing (`flutter build apk --debug`)  
**Analyze Status:** ✅ 0 compile error trên các file vừa sửa; còn lint/info hiện hữu của dự án  
**Database Version:** SQLite v17  
**Branch:** master  
**Active Initiative:** ✅ Hardening startup sync theo quyền + AI/domain audit

---

## 🎯 Phase hiện tại

**Phase đang thực hiện:** Chưa bắt đầu (chuẩn bị khởi động Phase 01)  
**Tài liệu đã khởi tạo:** Toàn bộ `docs/` structure  
**Tiến độ:** 0 / 8 phases hoàn thành

---

## ✅ Vừa hoàn thành (2026-06-05)

1. **Fix sync bug nghiêm trọng: expense/debt không lên Firestore khi nhập giá vốn (2026-06-05)**
   - `missing_info_products_view._editCost()` + `inventory_view._showInlineCostEdit()`:
     - Thêm `enqueueDebt()` cho CÔNG NỢ path — trước đó `isSynced=0` nhưng không bao giờ enqueue.
     - Thêm `enqueueExpense()` cho TIỀN MẶT/CK path — cùng vấn đề.
     - Thêm `createdAt` vào expense record cho nhất quán với schema.
   - `inventory_view._showInlineCostEdit()`:
     - Sửa `costCtrl` memory leak: `dispose()` ngay sau sheet đóng.
     - Chuyển validation giá vốn > 0 vào modal button (trước `Navigator.pop`).
     - Đổi "Bỏ qua" → "Hủy".
   - Commit: `29ffae55` (master).

## ✅ Vừa hoàn thành (2026-06-04)

1. **Audit & sửa toàn diện màn Thiếu vốn / NCC (2026-06-04)**
  - `lib/views/missing_info_products_view.dart` + `lib/data/db_helper.dart`:
    - Sửa memory leak: `costCtrl.dispose()` sau mỗi lần đóng popup.
    - Thêm `mounted` guard sau `await getCurrentShopId()`.
    - Fix count Tab "Đã bán": thêm `soldOnly` param vào `getProductsCount`, filter đúng `quantity ≤ 0`.
    - Đổi popup Nhập giá vốn sang light theme (`Colors.grey.shade50`) — nhất quán với fields trắng.
    - Thêm `StreamSubscription _productEventSub` lắng nghe EventBus (`financial_changed`, `products_changed`) → màn tự refresh khi nhập vốn từ màn khác.
    - `_buildCard` skip card rỗng (không badge, không action) khi cả 2 feature `allowPendingCost` và `enableSupplier` đều tắt.
  - Validation: analyze = 0 error, build thành công.

1. **Sửa độ rõ AppBar + popup Nhập giá vốn ở màn Thiếu vốn / NCC (2026-06-04)**
  - `missing_info_products_view.dart`:
    - Tăng độ rõ phần chữ AppBar bằng `titleWidget` riêng (font đậm hơn, dễ đọc hơn trên nền gradient).
    - Chuẩn hóa màu chữ TabBar (`Còn hàng`, `Đã bán`) để trạng thái chọn/không chọn rõ ràng.
    - Sửa popup `Nhập giá vốn`: đổi màu chữ/label/icon của dropdown và chọn NCC sang tông tối trên nền trắng để không còn hiện tượng chữ trùng nền.
  - Validation:
    - `flutter analyze lib/views/missing_info_products_view.dart`: không có issue.
    - `flutter build apk --debug`: thành công.

1. **Chuẩn hóa nhập liệu: "iPhone" là thương hiệu, không phải tên (2026-06-04)**
  - `quick_input_codes_view.dart`:
    - Khi lưu mã nhập nhanh loại điện thoại, tự suy luận và chuẩn hóa brand từ chuỗi tên (ví dụ `IPHONE ...`).
    - Nếu model trống, tự tách phần sau brand vào model.
  - `smart_stock_in_view.dart` + `fast_stock_in_view.dart`:
    - Fallback suy luận brand từ dữ liệu cũ (`name + model`) khi field brand chưa có.
  - Kết quả:
    - Nhập `IPHONE` sẽ đi đúng vào trường thương hiệu trong các luồng mã nhập nhanh và nhập kho.
  - Validation:
    - `flutter analyze` các file liên quan: không có compile error mới.
    - `flutter build apk --debug`: thành công.

1. **Fix toggle "Cho phép nhập giá vốn sau" báo bật nhưng UI không đổi (2026-06-04)**
  - `home_view.dart`:
    - Thêm guard `_isSavingPendingCost` để chặn double-tap khi đang lưu.
    - Giữ `_pendingCostOverride` qua vòng save/reload để tránh bị dữ liệu stale ghi đè ngược về OFF.
    - Merge settings từ `_loadShopSettings()` theo override pending và chỉ clear override khi backend đã phản ánh đúng.
  - `db_helper.dart` + `category_service.dart`:
    - Xác nhận nguyên nhân gốc trên DB cũ: thiếu cột `shop_settings.allowPendingCost`.
    - Thêm migration phòng thủ để tự thêm cột khi mở DB và trước khi CategoryService đọc/ghi settings local.
    - `saveShopSettings` chỉ trả thành công khi local DB ghi thành công.
  - `settings_view.dart` + `home_view.dart`:
    - Không còn báo thành công giả: bắt buộc check kết quả save + read-back xác nhận giá trị.
    - Nếu chưa có shop hiện tại hoặc bị chặn quyền/App Check, hiển thị lỗi rõ ràng và rollback UI.
  - Kết quả:
    - Công tắc đổi trạng thái ổn định theo thao tác người dùng, không còn hiện tượng chỉ báo snackbar mà switch không đổi.
  - Validation:
    - `flutter analyze lib/views/home_view.dart`: không có compile error mới (còn info/lint pre-existing).
    - `flutter build apk --debug`: thành công.

1. **Fix vòng lặp sync `permission_denied:storage_locations -> refresh scope -> permission_denied` (2026-06-03)**
  - `sync_service.dart`:
    - Sửa baseline chữ ký quyền người dùng: không còn set từ permissions đã chuẩn hóa ở đầu `initRealTimeSync`; lấy snapshot đầu tiên từ `users/{uid}` làm baseline để tránh false-positive "permissions changed".
    - Bổ sung cooldown `20s` cho reinit theo access-change để chặn vòng lặp reinit dồn dập.
    - Gắn `storage_locations` vào gate quyền kho (`allowViewInventory`) để không subscribe/poll collection trái quyền.
  - Kết quả:
    - Chặn chuỗi lặp gây tiêu hao quota App Check khi user không có quyền đọc `storage_locations`.
    - Không thay đổi hành vi của các collection hợp lệ đang có quyền.
  - Validation:
    - `flutter analyze lib/services/sync_service.dart`: không có compile error mới (còn info/lint pre-existing).
    - `flutter build apk --debug`: thành công.

1. **AI hiểu ngôn ngữ người dùng: mở rộng cụm kho/tồn kho tự nhiên (2026-06-03)**
  - `ai_command_router.dart`:
    - Thêm các cụm người dùng hay nói như `kho linh kiện`, `kho phụ kiện`, `tồn kho hiện tại`, `hàng tồn hiện tại`, `còn bao nhiêu trong kho` vào stock check.
  - `natural_order_parser_service.dart`:
    - Parser đơn tự nhiên cũng nhận thêm các biến thể tồn kho này để route đúng intent ngay từ lớp ngôn ngữ.
  - Validation:
    - `flutter analyze lib/services/ai_command_router.dart lib/services/natural_order_parser_service.dart`: sạch.
    - `flutter build apk --debug`: thành công.

1. **Permission-gated sync: tự reinit khi quyền/shop-lock thay đổi (2026-06-03)**
  - `sync_service.dart`:
    - Thêm chữ ký quyền người dùng và chữ ký khóa cấp shop để phát hiện scope truy cập đổi trong lúc app đang mở.
    - Khi `users/{uid}` hoặc `shops/{shopId}` đổi các field ảnh hưởng quyền, sync sẽ tự khởi tạo lại để chỉ tải collection được phép.
    - Giữ nguyên lọc collection hiện có ở startup/download, nên collection không được phép vẫn không bị subscribe/download.
  - Validation:
    - `flutter analyze lib/services/sync_service.dart`: không phát sinh lỗi compile mới.

---

## ✅ Vừa hoàn thành (2026-05-29)

1. **AI kho hàng: tách đúng mặt hàng / sản phẩm tồn + chặn lặp phản hồi (2026-06-03)**
  - `db_helper.dart`:
    - Thêm `getInventoryBreakdownSummary()` để trả về breakdown theo loại hàng với 3 chỉ số: `mặt hàng`, `sản phẩm tồn`, `giá vốn`.
  - `ai_chat_service.dart`:
    - Đổi các câu trả lời kho sang format đúng nghĩa nghiệp vụ.
    - Tách riêng `Kho điện thoại`, `Kho phụ kiện`, `Kho linh kiện`, `Tồn kho hiện tại`.
  - `functions/index.js`:
    - Siết prompt Cloud AI để không lặp lại section và phân biệt rõ `mặt hàng` với `sản phẩm tồn`.
    - Thêm lọc khử trùng lặp paragraph ở output trước khi trả về app.
  - Validation:
    - `flutter analyze lib/data/db_helper.dart lib/services/ai_chat_service.dart`: không có lỗi compile.
    - `flutter build apk --debug`: thành công.

1. **Fix 3 vấn đề vận hành thực tế: đơn sửa, backup, reset dữ liệu (2026-05-29)**
  - `repair_detail_view.dart`:
    - Chặn ghi chi phí lặp khi sửa giá vốn nhiều lần trên cùng đơn.
    - Khi đã ghi sổ quỹ trước đó, lần sửa sau chỉ ghi phần chênh lệch (`delta`) thay vì ghi lại full giá vốn.
  - `backup_restore_view.dart` + `backup_service.dart`:
    - Thêm nút **xóa từng file backup SQLite cục bộ**.
    - Mở rộng mapping xóa dữ liệu SQLite cho nhóm **Kho/Tài chính** để xóa sâu hơn các bảng liên quan.
    - Thêm tùy chọn **xóa luôn dữ liệu Cloud theo nhóm** để tránh dữ liệu sync ngược sau khi đã xóa local.
  - Validation:
    - `flutter analyze` 3 file thay đổi: không có compile error mới.
    - `flutter build apk --debug`: thành công.

1. **Backup: Xóa dữ liệu chọn lọc + Dọn backup cũ (2026-05-29)**
  - `BackupService.deleteSelectedData()`: xóa table SQLite theo danh sách collection, trả về số bản ghi xóa
  - `BackupService.cleanOldLocalBackups(keepDays)`: dọn file backup cục bộ cũ hơn N ngày
  - Tab SQLite tab: section "Xóa dữ liệu chọn lọc" (preset kho phụ kiện, linh kiện, tùy chọn tự do) + section "Dọn backup cũ" (30/60/90/180 ngày)
  - Files: `backup_service.dart`, `backup_restore_view.dart`

2. **AI Assistant — 8 UX Improvements (2026-05-29)**
  - #3 Auto-fill đơn từ chat: "tạo đơn sửa iPhone 15 cho Minh" → mở `AiOrderInputSheet` với text pre-filled
  - #5 Context chips xanh sau mỗi answer (followUpChips per intent)
  - #4 Daily briefing lần mở đầu trong ngày: hiển thị pending repairs, nợ phải thu/trả
  - #6 Lưu/khôi phục lịch sử chat (SharedPreferences, max 20 messages)
  - #2 followUpChips trên 12+ intent khác nhau
  - #8 Mở rộng voice command vocabulary (+40 keywords)
  - #7 Dashboard tab "Phản hồi xấu": xem từng query bị dislike
  - Files: `ai_chat_service.dart`, `ai_chat_overlay.dart`, `ai_command_router.dart`, `ai_usage_logger.dart`, `ai_usage_dashboard_view.dart`

2. **Sprint 4B: Flutter Analyze Warning Cleanup (2026-05-29)**
  - Xóa 130+ unused elements, fields, imports, dead code qua ~20 file.
  - Kết quả: 132 warnings → 1 (giữ `_eventBusSub2` StreamSubscription intentionally).
  - Files chính: `home_view`, `inventory_view`, `sale_detail_view`, `sale_list_view`, `repair_detail_view`, `settings_view`, `staff_list_view`, `work_schedule_settings_view`, `unified_sync_button`.

2. **Phân quyền Chat & Cloud AI (2026-05-29)**
  - Thêm 4 quyền mới: `allowSendChat`, `allowPinChat`, `allowDeleteOtherChat`, `allowCloudAI` vào `UserService`.
  - `advanced_chat_view`: load quyền và áp dụng rate-limit 30 tin/phút.
  - `ai_chat_overlay`: kiểm tra `allowCloudAI` trước khi gọi Cloud AI.

2. **AI Usage Logger + Dashboard (2026-05-29)**
  - Tạo `lib/services/ai_usage_logger.dart`: ghi log mọi AI interaction lên Firestore.
  - Tạo `lib/views/ai_usage_dashboard_view.dart`: màn hình thống kê cho Owner.

3. **Prompt Injection Guard (2026-05-29)**
  - `ai_chat_service.dart`: thêm `_sanitize()` làm sạch question/history trước khi gửi LLM.

4. **Fix compile error `_pinVerified` (2026-05-29)**
  - `shop_selector_view.dart`: xóa tham chiếu biến không tồn tại.

5. **Việt hóa UI Super Admin Console (2026-05-29)**
  - Đổi nhãn tiếng Anh còn sót sang tiếng Việt.

6. **Dọn dead code Sync (2026-05-29)**
  - Xóa `_scheduleResubscribe()` không dùng trong `sync_service.dart`.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Fix lỗi sao lưu/khôi phục Cloud + thêm xóa backup DB (2026-05-26)**
  - Thêm khả năng xóa từng bản backup SQLite trên Cloud trực tiếp trong màn hình Sao lưu/Khôi phục.
  - Cải thiện thông báo lỗi cloud thân thiện theo mã lỗi Firebase Storage phổ biến.
  - Vá `storage.rules` cho đường dẫn `db_backups/{shopId}/{allPaths=**}` để backup/restore/xóa cloud hoạt động đúng theo tenant.
  - Đã deploy Storage Rules mới thành công lên Firebase project `huyaka-1809`.

2. **Validation đợt cloud backup fix (2026-05-26)**
  - `flutter analyze` cho `backup_service.dart` và `backup_restore_view.dart`: không phát sinh compile error mới.
  - `firebase deploy --only storage`: thành công.

1. **Hardening restore cross-shop đầy đủ domain (2026-05-26)**
  - Mở rộng selective restore cho các miền dữ liệu còn thiếu khi khôi phục toàn bộ: đơn sửa, kho linh kiện, kho máy xác, kho vị trí, yêu cầu đóng tiền, đối tác sửa chữa, lịch sử đối tác, nhập kho.
  - Khi restore sang shop mới (remap shopId), dữ liệu local được reset trạng thái sync (`isSynced=0`) và bỏ `firestoreId` để đồng bộ lại đúng shop đích.

2. **Cập nhật báo cáo đồng bộ theo domain (2026-05-26)**
  - Mở rộng phạm vi Sync Health và Domain Sync Report cho `salvage_phones`, `storage_locations`, `payment_requests`, `payment_intents`, `repair_partners`, `partner_repair_history`.
  - Mục tiêu: giảm tình trạng báo lệch/mất coverage sau khi restore shop mới.

3. **Khóa loại hình kinh doanh chỉ còn điện tử (2026-05-26)**
  - `register_view`: chỉ còn lựa chọn điện tử.
  - `business_type_wizard`: chỉ cho chọn điện tử; `availableTypes` còn `electronics`.
  - `shop_switcher_widget` (tạo chi nhánh): bỏ dropdown ngành, cố định điện tử.

4. **Validation của đợt cập nhật mới**
  - Đã lên kế hoạch chạy `flutter analyze` cho các file thay đổi và `flutter build apk --debug` ngay sau patch.

1. **Follow-up fix UI Sao lưu/Khôi phục (2026-05-26)**
  - Fix tương phản chữ/tab với AppBar trong `backup_restore_view` để tránh trùng màu.
  - Bổ sung danh sách backup SQLite cục bộ để người dùng nhìn thấy file đã lưu.
  - Bổ sung thao tác chia sẻ/khôi phục trực tiếp từ danh sách backup cục bộ.
  - Làm rõ flow lưu file .db -> xem danh sách -> chia sẻ/khôi phục.
  - Đổi thư mục backup cục bộ sang `quanlyshop/sqlite_backups` để dễ nhận diện trên máy.
  - Thêm preset trong luồng xóa chọn lọc để giữ lại dữ liệu cốt lõi: sửa chữa, khách hàng, chấm công, cài đặt lương, lịch làm việc.
  - Thêm lựa chọn khi restore SQLite: giữ nguyên shop gốc hoặc chuyển dữ liệu vào shop hiện tại bằng remap `shopId`.
  - Thêm restore SQLite chọn lọc từng mục dữ liệu cho cả file cục bộ và backup cloud.

2. **Fix runtime lỗi Kho sau restore**
  - Bổ sung đảm bảo `products.shopId` tồn tại sau restore DB cũ để chặn lỗi:
    - `DatabaseException(no such column: shopId ...)`
  - Thêm check phòng thủ trong `DBHelper.onOpen` cho cột `shopId` của bảng `products`.

3. **Cải tiến UI chi tiết đơn bán**
  - Redesign item sản phẩm sang phong cách sáng, gọn, sạch, chuyên nghiệp khi đơn có nhiều sản phẩm.

2. **Validation follow-up**
  - `flutter analyze` cho `backup_service.dart` và `backup_restore_view.dart`: không có compile error mới.
  - `flutter build apk --debug`: thành công.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Hoàn thiện backup/restore offline + online (2026-05-26)**
  - Đã bật khôi phục SQLite từ Cloud (Firebase Storage) theo từng bản backup `.db`.
  - Firestore giữ cơ chế khôi phục chọn lọc theo từng mục (collection) và bổ sung hướng dẫn rõ hơn trong UI.
  - Luồng xác nhận khôi phục và thông báo sau khôi phục SQLite đã đầy đủ.

2. **Thiết kế lại thao tác trang Cài đặt bằng nút `...` trên AppBar (2026-05-26)**
  - Thêm menu nhanh đi tới:
    - Sao lưu & Khôi phục
    - Hướng dẫn sử dụng
    - Trung tâm trợ giúp
  - Giảm thao tác cuộn sâu và gom các action quan trọng lên đầu.

3. **Cập nhật hướng dẫn sử dụng backup/restore (2026-05-26)**
  - Cập nhật user guide mô tả rõ 2 chế độ:
    - Offline: SQLite file `.db`
    - Online: Firestore backup/restore theo từng mục

4. **Validation kỹ thuật cho đợt này**
  - `flutter analyze` (4 file thay đổi chính): không có compile error mới do task.
  - `flutter build apk --debug`: thành công.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Triển khai Hardening P0 cho AI cloud functions (2026-05-25)**
  - `functions/index.js`:
    - Áp dụng phân loại intent cho `chatAssistant` và chỉ gửi context tối thiểu theo intent.
    - Mask PII trong question/history trước khi gửi lên model.
    - Giảm lịch sử hội thoại gửi AI từ 10 xuống 6 turns.
    - Bỏ hoàn toàn log thô prompt/answer; thay bằng telemetry an toàn (requestId, len, latency, intent).
    - Bỏ log text/raw result ở `createRepairOrderAI` và `parseOrderAI`.
  - Mục tiêu đạt được: giảm rủi ro lộ dữ liệu qua context/log và giảm token không cần thiết.

2. **Validation kỹ thuật cho hardening P0 (2026-05-25)**
  - `node --check functions/index.js`: pass.
  - `flutter analyze`: chạy xong, còn `1525` warning/info legacy toàn repo.
  - `flutter build apk --debug`: thành công.

---

## ✅ Vừa hoàn thành (2026-05-25)

1. **Hoàn tất Industry Vocabulary Engine (2026-05-25)**
  - Tạo đủ 5 output theo yêu cầu tại `DOCS/vocabulary/`:
    - `vocabulary.json`
    - `alias_mapping.json`
    - `typo_mapping.json`
    - `phonetic_mapping.json`
    - `intent_mapping.json`
  - Chuẩn hóa theo pipeline normalize -> typo -> alias -> intent.
  - Bổ sung coverage cho thiết bị, lỗi sửa chữa, kho, tài chính, và intent điều hướng.

2. **Audit rủi ro đọc dữ liệu và rủi ro token AI (2026-05-25)**
  - Tạo `DOCS/AI_SECURITY_RISK_AUDIT.md`.
  - Kết luận chính:
    - API key DeepSeek đang an toàn ở server-side secret.
    - Rủi ro còn lại chủ yếu nằm ở data minimization/context over-sharing và logging prompt/answer.
  - Đưa ra kế hoạch hardening theo P0/P1/P2.

3. **Validation kỹ thuật cho đợt cập nhật tài liệu (2026-05-25)**
  - `flutter analyze`: chạy xong, còn warning/info legacy (không có compile error mới do task này).
  - `flutter build apk --debug`: thành công.
  - JSON syntax check cho 5 file vocabulary: OK.

---

## ✅ Vừa hoàn thành (2026-05-22)

1. **Nhập nhanh đơn sửa/đơn bán bằng câu lệnh tự nhiên (2026-05-23)**
  - Thêm parser `natural_order_parser_service.dart` để nhận diện câu lệnh tạo đơn sửa và đơn bán.
  - `create_repair_order_view`: thêm nút nhập nhanh trên AppBar, parse và tự điền model/lỗi/khách/SĐT/giá; mặc định `0đ` khi thiếu giá.
  - `create_sale_view`: thêm nút nhập nhanh trên AppBar, parse sản phẩm/IMEI/khách/SĐT/phương thức thanh toán; tự map trả góp FE.
  - Luồng lưu đơn, sync, transaction kho/công nợ/thanh toán vẫn dùng nguyên pipeline hiện tại (không ghi tắt bypass service).

2. **Validation kỹ thuật cho thay đổi mới**
  - Đã chạy `flutter analyze` cho 3 file thay đổi chính.
  - Không có lỗi compile mới; còn warning/info legacy ở các file màn hình lớn.

3. **Hotfix trắng màn hình đơn sửa mới (2026-05-23)**
  - Thêm cơ chế fallback render trong `create_repair_order_view.dart`.
  - Nếu build UI chính phát sinh exception, màn hình tự chuyển sang form dự phòng để vẫn thao tác tạo đơn.
  - Có log debug chi tiết để truy dấu nguyên nhân runtime thay vì hiển thị màn hình trống.
  - Root-cause fix: ràng buộc width hữu hạn cho nút `Lưu & In` ở bottom action bar để loại bỏ lỗi `BoxConstraints forces an infinite width`.

---

## ✅ Vừa hoàn thành (2026-05-22)

1. **Audit toàn diện UX/UI ứng dụng ở cấp sản phẩm thương mại**
  - Tạo đầy đủ thư mục `DOCS/UX_AUDIT/` với `7` tài liệu: score report, problem list, improvement plan, design-system debt, workflow optimization, loading/async UX, modernization roadmap.
  - Audit dựa trên đọc trực tiếp các màn hình trọng yếu như `home_view`, `create_repair_order_view`, `repair_detail_view`, `inventory_view`, `debt_view`, `finance_v2_view`, nhóm settings và widgets sync/loading.
  - Bổ sung số đo repo-level để lượng hóa UX debt: AppBar trực tiếp, spinner trực tiếp, dialog, bottom sheet.

2. **Cập nhật chỉ mục tài liệu**
  - `docs/DOCUMENTATION_INDEX.md` bổ sung nhóm tài liệu `DOCS/UX_AUDIT`.

---

## ✅ Vừa hoàn thành (2026-05-22)

1. **Tạo hệ thống tài liệu BLUEPRINT toàn app (DNA Rebuild)**
  - Tạo đầy đủ thư mục `DOCS/BLUEPRINT/` với các tài liệu lõi kiến trúc/nghiệp vụ/design/service/offline/rebuild.
  - Sinh `112` tài liệu màn hình trong `DOCS/BLUEPRINT/screens/` (bao phủ toàn bộ `lib/views`).
  - Tạo graph: dependency graph, screen relationship graph, service relationship graph.
  - Tạo `README_FINAL.md` tổng kết độ hoàn thiện, rủi ro, khả năng rebuild.
  - Tạo `TODO_GAPS.md` để theo dõi các điểm cần xác minh runtime/thực địa.

2. **Cập nhật chỉ mục tài liệu**
  - `docs/DOCUMENTATION_INDEX.md` bổ sung nhóm tài liệu BLUEPRINT.

---

## ✅ Vừa hoàn thành (2026-05-21)

1. **Tối ưu DB reads Excel export** — commit `c86c152e`
   - `loadSnapshot()`: 17 queries song song (parallel futures)
   - `_exportDetailedReport`: 14 → 9 reads (−36%)
   - `_exportReport`: 31 → 28 reads + parallel pre-fetch
   - N+1 fix trong `exportImportOrders`: 51 → 2 reads (với 50 đơn)

2. **Khởi tạo toàn bộ cấu trúc docs/ cho dự án Flavor Split**
   - `PROJECT_OVERVIEW.md`, `ROADMAP_ONLINE_OFFLINE.md`, `PROGRESS_TRACKER.md`
   - `DECISIONS.md` (ADR-001 đến ADR-005)
   - `RISKS_AND_ISSUES.md`, `TEST_RESULTS.md`
   - `docs/phases/PHASE_01` đến `PHASE_08`

3. **Enrich activity feed** — commit `2200ad95`
   - Bán hàng hiện tên sản phẩm + người bán
   - Thu/trả nợ hiện tên khách/NCC
   - Trả NCC hiện tên thực thay vì raw ID

4. **Fix Finance V2 3-checkpoint reconciliation** — commit `e6584072`
   - REPAIR_PARTNER type nhất quán ở 3 điểm kiểm tra
   - Thu khác không còn bị thổi phồng bởi thu nợ KH

---

## 🔴 Lỗi còn tồn tại

| Lỗi | File | Mức độ |
|-----|------|--------|
| `withOpacity` deprecated (pre-existing) | Nhiều file UI | Thấp |
| Kho location chưa test đầy đủ offline | salvage_phone_view | Trung bình |

---

## 📋 Ưu tiên tiếp theo

1. **Chuyển audit UX/UI thành execution spec**
  - Chốt AppBar strategy, loading states, sync feedback language, card taxonomy, settings IA.

2. **Ưu tiên redesign kiến trúc trải nghiệm**
  - `home_view.dart`
  - `debt_view.dart`
  - `inventory_view.dart`
  - `shop_settings_view.dart`

3. **Nếu quay lại roadmap flavor split**
  - Bắt đầu Phase 01 — Flavors Setup
  - Tạo `FlavorConfig`, `AppFlavor`
  - Cấu hình `android/app/build.gradle`
  - Tạo `main_online.dart` + `main_offline.dart`

---

## 🔧 Lệnh build/test quan trọng

```bash
# Analyze
flutter analyze

# Run (current — single flavor)
flutter run

# Build release (current)
flutter build apk --release

# Sau khi hoàn thành Phase 01:
flutter run --flavor online -t lib/main_online.dart
flutter run --flavor offline -t lib/main_offline.dart
flutter build apk --flavor online -t lib/main_online.dart --release
flutter build apk --flavor offline -t lib/main_offline.dart --release
```

---

## 📁 Tài liệu quan trọng

| File | Đọc khi nào |
|------|------------|
| `docs/ROADMAP_ONLINE_OFFLINE.md` | Hiểu lộ trình |
| `docs/PROGRESS_TRACKER.md` | Xem tiến độ hiện tại |
| `docs/ARCHITECTURE.md` | Hiểu kiến trúc mục tiêu |
| `docs/DECISIONS.md` | Hiểu lý do quyết định |
| `docs/phases/PHASE_01_FLAVORS.md` | Bắt đầu từ Phase 01 |
| `CLAUDE.md` | Rules và conventions |

---

## 📝 Ghi chú cho AI / lập trình viên tiếp theo

1. **Không sửa FirestoreService trực tiếp** trong Phase 02 — chỉ thêm interface wrapper
2. **Không xóa Firebase code** — guard bằng `FlavorConfig.isOnline`
3. **Online flavor phải không regression** — test toàn bộ trước mỗi phase
4. **SQLite schema không thay đổi** — cả 2 flavor dùng chung `DBHelper`
5. **Mỗi phase hoàn thành** → cập nhật `PROGRESS_TRACKER.md` + `CHANGELOG.md` + file phase tương ứng

---

## 📦 Recent commits

```
c86c152e perf(excel): reduce DB reads on Excel export — eliminate duplicates & N+1
2200ad95 feat(home): enrich "Hoạt động hôm nay" activity feed with contextual details
e6584072 fix(finance): sync REPAIR_PARTNER type across all 3 debt-balance checkpoints
```


---

## Completed Tasks (Recent)

- [x] **Fix Công Nợ Đối Tác Bị Mất Sau Refresh (2026-05-20)**
  - `debt_summary_service.dart`: Phát hiện orphan partner (deleted/inactive) vẫn có nợ còn lại; thêm `missingPartner: true` flag; log debugPrint
  - `db_helper.dart`: Thêm `getAllRepairPartnersRaw()` — trả toàn bộ hàng kể cả deleted
  - `debt_view.dart`: Card hiển thị icon cảnh báo đỏ nếu `missingPartner`; navigation dùng `partnerId` đúng + fallback tìm theo tên; snackbar giải thích rõ

- [x] **Tab Linh Kiện: Nút + AppBar, Auto-Open Từ Đơn Sửa, Fix Dialog iOS (2026-05-20)**
  - `parts_inventory_view.dart`: Xóa FAB "Thêm linh kiện"; thêm `ValueNotifier<int> addTrigger` param cho `PartsInventoryViewContent`
  - `inventory_view.dart`: AppBar tự đổi sang nút `+` khi tab LINH_KIEN; truyền `_partsAddTrigger` xuống; thêm `triggerPartsAdd` param
  - `repair_detail_view.dart`: `_navigateToPartsInventory` truyền `triggerPartsAdd: true` → dialog thêm LK tự mở
  - Fix iOS: `_showEditPartDialog` + `_showAddPartDialog` bọc content bằng `SizedBox(width: double.maxFinite)`

- [x] **Fix Popup Trắng iOS — Vị Trí Kho & Sửa Sản Phẩm (2026-05-20)**
  - `storage_location_view.dart`: `_LocationFormDialog` width 340→`double.maxFinite`; `_confirmDelete` dùng builder ctx thay vì outer context
  - `widgets/storage_location_selector.dart`: `showModalBottomSheet` thêm `useRootNavigator: true` — fix cả inventory's `_editProduct` vẫn trắng do nested modal

- [x] **Fix Sai Lệch Số Liệu Nhật Ký Tài Chính (2026-05-20)**
  - `finance_v2_view.dart`: Round giá vốn về 1000đ; load đối tác SC vào nhật ký; fix type 'OWE' cho CN NCC đầu kỳ
  - `finance_v2_reconciliation.dart`: EXPENSE cost dùng `lineCostTotal` thay `cashOut+transferOut`

- [x] **Fix Popup Trắng Khi Sửa Sản Phẩm Trong Kho (2026-05-20)**
  - `inventory_view.dart` (`_editProduct`): Bọc `SingleChildScrollView` bằng `SizedBox(width: double.maxFinite)` — fix layout constraint khiến content không hiển thị trong release mode

- [x] **Ảnh Sản Phẩm & Vị Trí Kho Trong Nhập Hàng; Location Repair; Badge Lỗi (2026-05-19)**
  - `smart_stock_in_view.dart` + `fast_stock_in_view.dart`: Thêm `ImagePickerWidget` (chụp/chọn ảnh sản phẩm khi nhập kho)
  - `stock_entry_service.dart`: Sau confirmEntry thành công → upload ảnh background qua `ProductImageService.uploadProductImage()`
  - `create_repair_order_view.dart`: Thêm `StorageLocationSelector` để ghi nhận vị trí cất máy lúc tiếp nhận
  - `repair_detail_view.dart`: Card vị trí cất máy editable, thay đổi ghi audit log before/after
  - `parts_inventory_view.dart`: Audit log `PART_INFO_UPDATE` bổ sung `oldLocationCode` / `newLocationCode`
  - `order_list_view.dart`: Badge lỗi thiết bị font 14→11, ellipsis tránh chiếm quá nhiều diện tích

- [x] **UI Fixes: Lỗi Thiết Bị, Vị Trí Lưu Kho, AppBar Inventory (2026-05-19)**
  - `repair_detail_view.dart`: Issue badge xuống body (Card đỏ), AppBar sạch
  - `home_view.dart`: Shortcut "Vị trí lưu kho" trong tab Kho
  - `storage_location_view.dart`: Fix list rỗng (virtual locations từ products), stats case-insensitive, FAB tròn
  - `inventory_view.dart`: Gộp 3 icon ít dùng vào PopupMenu "⋮" → tránh nút + đè nút back

- [x] **Fix Offline: Dừng Loading Vô Hạn Khi Mất Mạng (2026-05-19)**
  - `stock_entry_service.dart`: timeout + cache fallback cho confirmEntry/cancelEntry
  - Spinner dừng, hiển thị thông báo tiếng Việt khi offline

- [x] **Refactor NCC & Đối Tác Sửa Chữa — Light Premium CRM (2026-05-19)**
  - Xóa popup `...` khỏi tất cả card; toàn bộ card tappable → mở detail view
  - `supplier_list_view.dart`: compact card (avatar 48px, badge + quick-pay), không còn `PopupMenuButton`
  - `supplier_detail_view.dart`: AppBar actions Edit + Delete (password auth trước khi xóa)
  - `repair_partner_detail_view.dart`: AppBar actions Edit + Delete
  - Logic xóa NCC chuyển từ list view → detail view; `_confirmDeleteSupplier` + `_showPasswordDialog` đã xóa khỏi list view

- [x] **Product Image & Storage Location System (2026-05-19)**
  - `StorageLocation` model + DB table `storage_locations` (schema v98)
  - `StorageLocationView` — màn hình CRUD quản lý vị trí kho
  - `StorageLocationSelector` widget — bottom sheet chọn vị trí
  - `LocationBadge` widget — hiển thị badge vị trí
  - `ImagePickerWidget` — chọn ảnh camera/thư viện, nén tự động <300KB
  - `ProductImageService` — upload background lên Firebase Storage
  - Tích hợp: thumbnail + chip vị trí trong card sản phẩm kho
  - Tích hợp: chọn vị trí cất máy khi đánh dấu sửa XONG
  - Tích hợp: chip vị trí trong danh sách đơn sửa chữa
  - Nút điều hướng đến StorageLocationView từ AppBar kho

- [x] **Tắt Thông Báo Bảo Hành + Cải Thiện UI 5 Màn Hình (2026-05-19)**
  - Tắt push notification bảo hành: `_enableWarrantyPushNotifications = false` trong `WarrantyReminderService`
  - Fix overflow stats bar linh kiện: `FittedBox(fit: BoxFit.scaleDown)`
  - Redesign dialog tạo nhân viên: gradient header, icons, section labels
  - Cải thiện product detail bottom sheet: price cards trực quan
  - Cải thiện edit product dialog: gradient header thay text đơn giản
  - Cải thiện `_card` widget sale detail: shadow, accent border, loại bỏ Colors.pink

- [x] **Reconciliation Patch v7 — TOTAL_DEBT_SUPPLIER dứt điểm (2026-05-17)**
  - Root cause xác nhận từ ADB device log: `debt_payments` có bản ghi corrupt (60M cho nợ 100k, 7M cho nợ 100k).
  - Giải pháp: tách biệt cash flow (dùng `debt_payments.amount`) và debt balance (dùng `debts.paidAmount`).
  - Main loop `debtSupplierChange=0`, Category B dùng full `paidAmount`, `_loadOpeningDebtBalances` đơn giản hóa.
  - Kết quả: debtSupplierClosing = 33,190,500 = payableTotal → **TOTAL_DEBT_SUPPLIER PASS** ✓

- [x] **Reconciliation Patch v5 — TOTAL_DEBT_SUPPLIER dứt điểm** (2026-05-16)
  - Root cause: payments link tới deleted debts (`deleted=1`) vẫn bị tính vào `debtSupplierChange` do LEFT JOIN không phân biệt deleted.
  - Fix: thêm `linkedDebtDeleted` column; chỉ set `debtSupplierChange` khi `linkedDebtIsActive` (debt còn tồn tại và không bị xóa).
  - Expected: TOTAL_DEBT_SUPPLIER PASS — closing = 12,020,500 + 21,170,000 = 33,190,500 ✓

- [x] **Reconciliation Patch v4 + sửa nền popup xuất file** (2026-05-16)
  - Audit 2 file mới người dùng gửi xác nhận:
    - `TOTAL_OUT` PASS
    - `NET` PASS
    - còn `TOTAL_DEBT_SUPPLIER` FAIL
  - Sửa reconciliation:
    - `db_helper.dart`: query debt payments trả thêm `linkedDebtType`
    - `finance_v2_view.dart`: `DEBT_PAY` chỉ trừ `debtSupplierChange` khi linked debt là loại NCC thật sự
  - Sửa UI popup xuất file thành công:
    - `finance_v2_excel_export.dart`: đổi block thông tin file từ nền xanh đậm sang nền xanh nhạt, tăng tương phản chữ/icon để không còn mảng xanh đặc.

- [x] **Reconciliation Patch v2 theo bộ Excel 16/05/2026** (2026-05-16)
  - Tái hiện chính xác FAIL từ file `nhat_ky_chi_tiet_16052026_16052026.xlsx`:
    - `TOTAL_OUT` lệch +200,000
    - `NET` lệch -200,000
    - `TOTAL_DEBT_SUPPLIER` lệch -66,800,000
  - Root cause 1: dedup import theo amount trong `finance_v2_data_service.dart` gây skip nhầm khoản nhập trùng số tiền.
  - Root cause 2: `DEBT_PAY` không linked vào bảng `debts` vẫn trừ `debtSupplierChange`, làm flow công nợ NCC âm giả.
  - Đã sửa:
    - dedup import theo canonical reference key.
    - SQL debt payments trả thêm `linkedDebtId`.
    - audit log chỉ ghi `debtSupplierChange` cho `DEBT_PAY` khi có `linkedDebtId`.
  - Validation: `flutter build apk --debug` thành công; analyze không có error mới.

- [x] **Reconciliation Patch v3: opening debt supplier âm giả** (2026-05-16)
  - Audit bộ Excel tải lại xác nhận:
    - `TOTAL_OUT` đã PASS
    - `NET` đã PASS
    - còn duy nhất `TOTAL_DEBT_SUPPLIER` FAIL
  - Sửa `_loadOpeningDebtBalances()` trong `finance_v2_view.dart`:
    - skip debt `totalAmount <= 0`
    - skip debt `openingRemaining <= 0`
  - Mục tiêu: loại ảnh hưởng các debt record âm/không hợp lệ khỏi opening balance công nợ NCC.
- [x] **Reconciliation Fix TOTAL_OUT + TOTAL_DEBT_SUPPLIER** (2026-05-16)
  - Audit tiếp theo sau 4 bug fixes trước: phát hiện 2 lỗi còn lại trong RECONCILIATION sheet
  - LỖI 1: TOTAL_OUT lệch 200K (log > report) — data service thiếu query `supplier_import_history`
    - Sửa `finance_v2_data_service.dart`: thêm import_history processing với dedup theo amount
  - LỖI 2: TOTAL_DEBT_SUPPLIER lệch 50.38M (log < report) — 2 nguyên nhân:
    - (a) `_loadOpeningDebtBalances()` dùng pre-period payments (debt_payments table) → lệch với snap.payableTotal (dùng stored paidAmount) khi có sync lag
      - Sửa `finance_v2_view.dart`: đổi sang `paidBeforeStart = storedPaid - inPeriodPaid` — algebraically nhất quán với snap.payableTotal
    - (b) Reconciliation engine cộng IMPORT debtSupplierChange (CÔNG NỢ imports qua purchase_orders) vào flow → không có trong snap.payableTotal (chỉ track debts table)
      - Sửa `finance_v2_reconciliation.dart`: skip debtSupplierChange cho IMPORT action
  - Git commit `c9822f44` — build debug thành công

- [x] **Financial Reconciliation Audit — 4 Bugs Fixed** (2026-05-16)
  - Audit 6 file Excel ngày 16/05/2026, xác định 4 nguyên nhân chênh lệch số liệu
  - BUG 1: KẾT HỢP sales dùng `finalPrice` thay vì `cashAmount + transferAmount` → thiếu 5M TOTAL_IN
    - Sửa `finance_v2_data_service.dart` (current + previous sales loops) + `daily_financial_analysis_service.dart`
    - recognizedCost denominator = actualPaid cho KẾT HỢP (ratio = 1, 100% vốn)
  - BUG 2: bao_cao_ngay "CHI — Nhập hàng" luôn 0 vì filter `type=IMPORT` không bao giờ match
    - Sửa `finance_v2_view.dart`: derive `importOut = totalOut - debtRepayOut - operatingExpenseOut`
  - BUG 3: Section 3 danh sách đơn bán hiển thị `finalPrice` thay vì `cashAmount+transferAmount` cho KẾT HỢP
  - BUG 4: so_quy duplicate partner payments (ĐỐI TÁC SỬA CHỮA + Trả đối tác SC = 2×)
    - Track `partnerExpenseAmounts`; skip `_repairPartnerPayments` nếu đã có entry trùng từ `_expenses`
  - Git commit `2b2f3966` — build debug thành công

- [x] **Fix Finance Tab Crash + Audit Financial Display** (2026-05-16)
   - Sửa `getSalesByDateRange()` crash `no such column: createdAt` — xóa `COALESCE(soldAt, createdAt)` dùng `soldAt` trực tiếp
   - Sửa Home `_loadStats` catch block không reset về 0 khi lỗi — giữ số liệu cũ
   - Audit xác nhận: Home và Finance tab dùng cùng `FinanceV2DataService.loadSnapshot()` → nhất quán
   - Công thức tài chính đúng: cash-basis, CÔNG NỢ = 0, trả góp chỉ tính phần đã thu, trả hàng trừ net

- [x] **Fix lỗi tab Nhật ký tài chính bị trống theo ảnh người dùng** (2026-05-16)
   - Triển khai fallback timeline trong `finance_v2_view.dart`: nếu `transactions + financial_activity_log` rỗng theo kỳ lọc thì lấy dữ liệu từ `audit_logs` liên quan tài chính.
   - Áp dụng lọc action tài chính: sale/repair/expense/debt/payment/purchase/import/cash_closing.
   - Mapping action kỹ thuật sang nhãn tiếng Việt để dễ đọc trên UI Nhật ký.
   - Thêm banner thông báo nguồn dữ liệu fallback để người dùng biết trạng thái hiển thị.
   - Validation: `flutter analyze` không có lỗi mới trong file sửa; `flutter build apk --debug` thành công.

- [x] **Financial Audit Home vs Finance + Consistency Fix** (2026-05-16)
   - Audit theo phản hồi xuất Excel rỗng ở tab Giao dịch/Công nợ/Nhật ký
   - Xác định và sửa lỗi query `getSalesByDateRange()` chưa lọc shopId (nguy cơ kéo số liệu chéo shop)
   - Bổ sung filter dữ liệu sales theo `shopId` + `deleted` + `COALESCE(soldAt, createdAt)`
   - Sửa Home không giữ số tài chính cũ khi `_loadStats` lỗi (reset về 0 trong catch)
   - Build/debug thành công sau khi vá

- [x] **Fix hiển thị mục 2 trên OPPO (NCC/Đối tác topbar)** (2026-05-16)
   - Xác định root cause: luồng OPPO đang dùng `supplier_list_view.dart`, không phải `partner_management_view.dart`
   - Chuyển tìm kiếm và bộ lọc lên AppBar cho cả 2 tab trong `supplier_list_view.dart`
   - Đồng bộ menu lọc theo tab:
      - NCC: Còn nợ, Đã tất toán, Quá hạn, Giao dịch gần đây
      - Đối tác: Hoạt động, Ngừng HĐ, Còn nợ, Theo tên
   - Loại bỏ cụm search/filter trong body để tránh trùng thao tác
   - Validation: `flutter build apk --debug` thành công

- [x] **Topbar Actions for Customer, Partner/NCC, and Inventory** (2026-05-16)
   - customer_profile_view: đưa Lưu/Xóa lên AppBar, đổi bộ lọc lịch sử sang dropdown topbar
   - customer_profile_view: xóa ô Email, thu gọn Địa chỉ/Ghi chú 1 dòng, giảm 1/2 chiều cao khung ảnh đại diện
   - partner_management_view: thêm tìm kiếm (icon kính lúp) và dropdown lọc trên topbar cho cả 2 tab NCC/đối tác
   - partner_management_view: thêm các chế độ lọc theo tab (còn nợ/tất toán/quá hạn/giao dịch gần đây và hoạt động/ngừng HĐ/theo tên)
   - inventory_view: chuyển tìm kiếm + toggle hiển thị hàng hết lên topbar, ẩn block “Tải cuộn 20 mục/lần”
   - Validation: build debug thành công; analyze còn warnings/info pre-existing ở inventory/partner

- [x] **Partner Navigation + Font Sync + Parts Financial Fix** (2026-05-16)
  - partner_management_view: onTap NCC/đối tác → RepairPartnerDetailView / SupplierDetailView
  - sale_detail_view: sửa lỗi PKX/NO_IMEI truyền sai vào IMEI lookup → "không tìm thấy sản phẩm"
  - deep_link_navigator: fallback strip quantity suffix (x2) khi tìm sản phẩm theo tên
  - Font size đồng bộ: parts_inventory_view, partner_management_view, create_repair_order_view dùng AppTextStyles
  - parts_inventory_view: gradient nhất quán [1A237E → 2962FF] với 2 tab còn lại
  - repair_detail_view: fix 2 bug tài chính — parts cash dùng sai PaymentIntentType + _showCostFundRecordingPopup thiếu FinancialActivity log

- [x] **Compact Listview + KiotViet Credentials UI + Clickable Navigation** (2026-05-16)
  - Khôi phục giao diện về `3185ff9f` sau khi revert broken color commit
  - Tái tích hợp: clickable customer header (phiếu sửa/đơn bán), clickable product (đơn bán), order navigation (hồ sơ KH)
  - KiotViet: nhập Client ID/Secret trực tiếp trong app (SharedPreferences), không cần dart-define
  - Compact listview: search box 42px, dense tiles, borderRadius 12 trên order_list, customer, inventory
  - Thêm Backup & KiotViet tiles trong Cài đặt cửa hàng

- [x] **Restore Legacy Color Palette** (2026-05-15)
  - Truy vết palette gốc từ commit `3d6b3109` bằng `git show`
  - Khôi phục primary `#4D8EE9` (soft blue, mềm mại hơn iOS/Zalo blue)
  - AppBar gradient: #0068FF → #0084FF (Zalo Blue gốc)
  - Grey scale: Material Design grey (gốc, không Tailwind)
  - finance_v2_theme.dart: khôi phục navy original
  - Toàn bộ ứng dụng tự kế thừa qua shared tokens

- [x] **Documentation Process Setup** (2026-05-15)
  - Tạo CLAUDE.md, documentation index
  - Setup quy trình tài liệu hóa bắt buộc
  - Tạo templates cho all documentation files

---

## Pending Tasks

### High Priority
- [ ] **Review & Update DOCS/FULL_DOCUMENTATION.md**
  - Đảm bảo đầy đủ tất cả services, models, views
  - Thêm chi tiết schema database
  - Thêm API documentation (Firestore, Firebase)

- [ ] **Complete docs/KNOWN_ISSUES.md**
  - Danh sách tất cả known issues
  - Workarounds nếu có
  - Priority levels

- [ ] **Complete docs/TODO.md**
  - Danh sách tasks pending
  - Priority, assignee, due dates
  - Link đến relevant code/docs

- [ ] **Complete docs/ROADMAP.md**
  - Milestones
  - Features planned
  - Timeline

### Medium Priority
- [ ] **Verify All Specialized Reports**
  - PERMISSION_AUDIT_REPORT.md
  - FINANCE_V2_MIGRATION.md
  - KIOTVIET_INTEGRATION_REPORT.md
  - IMAGE_UPLOAD_AUDIT_REPORT.md
  - UI_STANDARDIZATION_REPORT.md

- [ ] **Consolidate Legacy Documentation**
  - Clean up legacy files
  - Archive old reports
  - Link từ legacy files tới mới

### Low Priority
- [ ] **Create Automated Documentation Update Tool**
  - Script kiểm tra file changes
  - Auto-update CHANGELOG
  - Auto-validate documentation

---

## Known Issues

### Build & Compilation
1. **Android NDK Version Mismatch**
   - Issue: integration_test requires NDK 28.2.13676358
   - Status: ⚠ Pending fix in build.gradle.kts
   - Workaround: Add `ndkVersion = "28.2.13676358"` to android/app/build.gradle.kts

2. **Impeller Opt-out Deprecated**
   - Issue: Warning từ Flutter về Impeller opt-out
   - Status: ⚠ Pending removal
   - Workaround: Remove `io.flutter.embedding.android.EnableImpeller=false` từ AndroidManifest.xml

### Runtime
3. **Image Decoder Failures**
   - Issue: Some images fail to decode ("unimplemented")
   - Status: ⚠ Device-specific (Android 12+)
   - Workaround: Validate image format trước upload

4. **FCM Token Save**
   - Issue: "Cannot save FCM token: no authenticated user"
   - Status: ℹ Expected (happens at login screen)
   - Workaround: None needed, automatic retry after auth

### Known Limitations
5. **Geolocation**
   - Status: Active (connected)
   - Note: Requires permission từ user

---

## Recommended Next Steps

### Immediate (This Sprint)
1. **Complete Pending Documentation**
   - Finish KNOWN_ISSUES.md
   - Finish TODO.md
   - Finish ROADMAP.md

2. **Consolidate Full Documentation**
   - Review DOCS/FULL_DOCUMENTATION.md
   - Add missing details
   - Update all links

3. **Fix Build Issues**
   - Update Android NDK version
   - Remove Impeller opt-out

### Short-term (Next Sprint)
4. **Verify All Services**
   - Run comprehensive tests
   - Validate all Firestore operations
   - Check sync reliability

5. **UI/UX Review**
   - Check design consistency
   - Verify all screens
   - Test on multiple devices

### Long-term (Roadmap)
6. **Performance Optimization**
   - Analyze app startup time
   - Optimize Firestore queries
   - Reduce app bundle size

7. **Feature Expansion**
   - Multi-language support
   - Advanced reporting
   - Mobile payment integration

---

## System Architecture (Quick Reference)

```
┌─────────────────────┐
│  Views (UI)         │
├─────────────────────┤
│  Services           │
│  (Firestore, Auth)  │
├─────────────────────┤
│  Models & Database  │
│  (SQLite, Firestore)│
├─────────────────────┤
│  External APIs      │
│  (Firebase, etc.)   │
└─────────────────────┘
```

---

## Key Files to Know

| File | Purpose | Status |
|------|---------|--------|
| `lib/main.dart` | Entry point | ✓ Stable |
| `lib/services/firestore_service.dart` | Firestore CRUD | ✓ Stable |
| `lib/services/user_service.dart` | Auth & roles | ✓ Stable |
| `lib/services/sync_service.dart` | Real-time sync | ✓ Active |
| `lib/data/db_helper.dart` | SQLite | ✓ v17 |
| `.github/copilot-instructions.md` | AI guidelines | ✓ Updated |
| `CLAUDE.md` | Developer guide | ✓ Updated |
| `docs/DOCUMENTATION_INDEX.md` | Doc index | ✓ Updated |

---

## Documentation Files Status

| File | Status | Last Updated |
|------|--------|--------------|
| CLAUDE.md | ✓ Created | 2026-05-15 |
| .github/copilot-instructions.md | ⚠ Partial | 2026-05-15 |
| docs/DOCUMENTATION_INDEX.md | ✓ Created | 2026-05-15 |
| docs/CHANGELOG.md | ✓ Created | 2026-05-15 |
| docs/HANDOVER.md | ✓ Created (this file) | 2026-05-15 |
| docs/KNOWN_ISSUES.md | ⏳ Pending | - |
| docs/TODO.md | ⏳ Pending | - |
| docs/ROADMAP.md | ⏳ Pending | - |
| docs/ARCHITECTURE.md | ⏳ Pending | - |
| docs/DESIGN_SYSTEM.md | ⏳ Pending | - |
| docs/DESIGN_TOKENS_REFERENCE.md | ⏳ Pending | - |
| docs/UI_GUIDELINES.md | ⏳ Pending | - |
| docs/CODING_STANDARDS.md | ⏳ Pending | - |
| docs/IMPLEMENTATION_REPORT.md | ⏳ Pending | - |
| docs/PAYMENT_AUDIT.md | ⏳ Pending | - |
| DOCS/FULL_DOCUMENTATION.md | ⚠ Needs review | - |

---

## Quick Stats

- **Total Source Files:** 150+ (lib/)
- **Total Views:** 10+
- **Total Services:** 8+
- **Total Models:** 15+
- **Database Tables:** 8+
- **Firebase Collections:** 10+
- **External Integrations:** 4+ (Firebase, KiotViet, etc.)

---

## Communication

- **Documentation Owner:** GitHub Copilot
- **Last Updated:** 2026-05-16
- **Next Review:** Before next major task
- **Questions?** Check CLAUDE.md or docs/DOCUMENTATION_INDEX.md

---

**Note:** Tài liệu này được cập nhật tự động sau mỗi task. Nếu thông tin không chính xác, vui lòng báo cáo.
