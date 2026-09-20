# QA_TEST_EXECUTION — Kết quả chạy sau khi sửa lỗi nền tảng (2026-09-20)

Máy A = CPH2203 `NJR8W86LKRVW7DHQ`, máy B = CPH2239 `WCE65565HMDYOB59`, cùng tài khoản m@m.com / shop M.
Build: debug APK từ working tree (commit sau `385b814c`), cài `adb install -r` cả 2 máy 08:37 và 09:00.
Mạng: tắt/bật bằng `svc wifi|data`. SQLite kéo bằng `run-as … cat` kèm `-wal`. Cloud xác minh gián tiếp qua SQLite máy B (không truy vấn Firestore production trực tiếp).

| Test ID | Precondition | Action | Expected | Actual | Kết quả | Evidence (SQLite / log / máy / mạng / giờ) |
|---|---|---|---|---|---|---|
| RG-01 (BUG-01) | A online session, wifi+data OFF | Bán CAPLIGHTNING 120k TIỀN MẶT, khách vãng lai | Lưu local-first ngay, không lỗi, kho −1, intent tạo | Sheet "Đã ghi nhận — chờ đồng bộ" sau <1 s | **PASS** | A 08:39:34 log `📴 _processSale: không có mạng → lưu local-first`; SQLite `sales sale_1789868373836… isSynced=0`, `products id69 qty 19 isSynced=0`, 1 intent |
| RG-01b | tiếp RG-01 | Kill app → bật mạng → mở app | Đẩy đúng 1 sale + 1 product, không trùng | `✅ Synced 1 sales`, `✅ Synced 1 products`; sale isSynced=1, qty 19 | **PASS** | A 08:40:18–19; B nhận sale (s_B=1) và qty 19 |
| RG-02 (BUG-02) | A online, mạng OFF | Tạo đơn sửa KH mới 0901000002 / SAMSUNG A54 / 400k | Lưu ngay, không treo, có hàng đợi | Về danh sách sau ~1 s; log `📴 … bỏ qua write customers`, `No network, skipping sync` | **PASS** | A 08:43:48; `repairs id70 isSynced=0`, `customers QA KH2 isSynced=0`, `sync_queue repair pending` |
| RG-02b | tiếp RG-02 | Bật mạng | Đơn + KH lên cloud, B nhận | repair isSynced=1, customer `customer_1789868627996…` isSynced=1; B: r_B=1, c_B=1 | **PASS** | A 08:44, B 08:47 |
| RG-03 (BUG-04) | A online, mạng OFF | Nhập kho mới QA-CAP x5 30k/60k TIỀN MẶT → LƯU VÀO HÀNG CHỜ | Lưu local ngay (không "Đang lưu…" treo) | "Lưu thành công" sau <2 s; `✅ createEntry (local): id=se_1789869077969_diamym` | **PASS** | A 08:51 |
| RG-03b | tiếp, vẫn OFF | Mở "Hàng chờ" → Sửa (thêm NCC NCCTEST01) → Nhập kho (double-tap Xác nhận) | Danh sách hiện phiếu local; xác nhận đường offline; 1 lần | List "1" → sau xác nhận "0"; `repair_parts QA-CAP qty 5 isSynced=0`, `import_orders imp_1789869221161… isSynced=0`, `expenses 150000 CHI isSynced=0` | **PASS** | A 08:53–08:54 |
| RG-03c | tiếp | Bật mạng | Đẩy phiếu + bảng local; B nhận | `☁️ Đã đẩy 1 phiếu nhập kho lưu tạm`, `Synced 1 expenses`, `Synced 1 repair parts`, `Committed 1 import_orders`; A isSynced=1 cả 3; B: QA-CAP qty 5, expense 150k, import_order có | **PASS** | A/B 08:55 |
| RG-04 (BUG-05) | B mở foreground (không resume), A online | A thu nợ TÉTCARDQC 50k TIỀN MẶT | B nhận debt/paidAmount + debt_payments + intent ≤30 s | B: paidAmount 150000, dp=2, pi=2 sau 25 s; log B `📡 SyncSignal: nhận debts,…,payment_intents` → `[SYNC][FETCH] collection=debts … manual_refresh` | **PASS** | B 08:49; `mResumedActivity` = app (không resume) |
| RG-04b | tiếp RG-03c | — | B nhận repair_parts/expenses/import_orders khi A sync | `📡 SyncSignal: nhận stock_entries…`, `… repair_parts, import_orders …`; dữ liệu về (xem RG-03c) | **PASS** | B 08:55 |
| RG-05 (BUG-06) | ngay sau RG-04 trên A | Mở tab Tài chính → Tiền (không đổi kỳ) | Tiền vào gồm 50k vừa thu | "1,89 Tr / Tiền vào, 6 giao dịch" = SQL Σ intents COMPLETED hôm nay 1.890.000 | **PASS** | A 08:50 |
| RG-06 (BUG-09) | như trên | So tab Tiền vs Chốt quỹ | Cùng cách trình bày | Tab Tiền: vào 1,89 / ra 0,12 / còn 1,77; Chốt quỹ: Thu 1,89 / Tiền mặt 1,77 | **PASS** | A 08:50–08:51 |
| RG-07 (BUG-08) | sau thu nợ 08:49 | Quan sát snackbar | Tự đóng ≤6 s | 08:50 `BẬT TB` = 0 node trên màn (trước sửa: còn sau >10 phút) | **PASS** | A uiautomator |
| RG-08 (BUG-03) | A | Tạo đơn sửa SĐT "ABC" + model | Chặn, không lưu | log `Validation failed - phone invalid`; `repairs WHERE model='TÉTMODEL'` = 0 | **PASS** | A 08:58 |
| RG-09 (BUG-07) | A, đơn 70 | Thêm MANHINH95 từ Kho phụ tùng | Snapshot có `partFirestoreId` + `source` | `partsUsedDetailed=[…{"name":"MANHINH95","partFirestoreId":"DSfC0cbMseCMyMNjbrEv","source":"repair_parts",…}]`, repair_parts 4→3 | **PASS** | A 09:01 (APK 09:00) |
| RG-09b | FFI | 2 dòng `repair_parts` trùng tên, hoàn kho theo `partFirestoreId=B` x2 | Dòng B +2, dòng A không đổi, isSynced=0; snapshot cũ rơi về tên | đúng | **PASS** | `test/restore_part_by_detail_test.dart` |
| RG-09c | 2 máy | B xoá linh kiện của đơn 70 → hoàn đúng dòng | — | chưa chạy UI | **BLOCKED** (thời gian) — logic đã có test FFI RG-09b |
| RG-10 (D-03) | code + rules | Xác nhận phiếu nhập không còn ghi `supplier_debts`/`financial_activities` | không doc mồ côi | code đã bỏ 2 write; RG-03c xác nhận qua đường offline; xác nhận cloud-transaction chưa chạy lại máy | **PASS (static) / BLOCKED (device, transaction cloud)** |
| RG-11 | unit | `flutter test` toàn bộ | 0 FAIL | 719 PASS, 1 skipped, 0 FAIL | **PASS** | `test/cloud_write_policy_test.dart` (4), `full_audit_db_schema_test` (7), `restore_part_by_detail_test` (1), finance scenario cập nhật gross |
| RG-12 | emulator | rules cross-shop | deny đúng | 17/17 (không đổi rules) | **PASS** | `tools/firestore_rules_test/cross_shop_test.js` (chạy 19/09 01:31) |
| RG-13 | A | Double-tap Xác nhận thu nợ / xác nhận nhập kho | 1 phiếu | 1 phiếu (RG-04, RG-03b) | **PASS** | |
| RG-14 | A | Timeout (mạng có nhưng chập chờn) | ≤12 s rồi local-first | chưa mô phỏng được (không có công cụ throttle) | **BLOCKED** | unit test timeout 200 ms PASS |
| RG-15 | A | Permission denied | báo lỗi, không queue vô hạn | không có tài khoản staff bị chặn để thử | **BLOCKED** | rules test deny PASS; `CloudWritePolicy` rethrow permission-denied (unit) |
| RG-16 | A | Offline → Online → Offline liên tiếp (RG-01→RG-02→RG-03 xen kẽ bật/tắt) | không trùng, không mất | 3 chu kỳ, 0 trùng (đếm sales/repairs/import_orders theo firestoreId) | **PASS** | |

Tổng đợt regression: 16 mục · **PASS 12** · **BLOCKED 4** (RG-09c, RG-10 device, RG-14, RG-15) · FAIL 0.
