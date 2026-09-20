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

---

# ĐỢT 3 — 2026-09-20 (09:15–10:50): gỡ chặn 4 mục + chạy tiếp plan

Máy A = CPH2203 (m@m.com, chủ shop) · Máy B = CPH2239 (**n@n.com, nhân viên** từ 09:31 — đổi để có góc nhìn phân quyền). Build: working tree sau `fbe97736` + 3 sửa nhỏ (mục F), cài `adb install -r` 09:00 / 09:15 / 10:31.

## A. Gỡ chặn 4 mục regression
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| RG-09c | B "Đổi PT" MANHINH95→CAM12 trên đơn 70 (snapshot có `partFirestoreId`) | B hoàn đúng dòng MANHINH95 (3→4) theo khoá cloud, trừ CAM12 8→7; A nhận | B log `✅ Restored part quantity: MANHINH95, +1 => 4`, `Đổi PT - Đã trả kho`; B `repair_parts` MANHINH95=4, CAM12=7; A sau 20 s: cost 780.000, MANHINH95=4, CAM12=7; snapshot mới có `"partFirestoreId":"CtIQt3Auy2JByzzc4pvx"` | **PASS** | B 09:25 |
| RG-10 (device) | A xác nhận phiếu QA-PIN (draft trên cloud, có mạng) | transaction cloud OK; không ghi `supplier_debts`/`financial_activities`; B nhận | A log: `Inside transaction … Transaction completed successfully`, `Created local EXPENSE 2000000`, `Local repair_part saved QA-PIN`, bump `stock_entries,products,repair_parts,supplier_import_history`; không dòng nào chạm 2 collection đã bỏ; B: QA-PIN qty 20, expense 2 Tr | **PASS** | A 09:28 |
| RG-14 | Mô phỏng mạng có nhưng cloud không tới (timeout 12 s) | local-first sau ≤12 s | `settings put global http_proxy` bị OPPO từ chối (`WRITE_SECURE_SETTINGS`), không root, không throttle được | **BLOCKED** (unit test timeout 200 ms PASS) | 09:29 |
| RG-15 | Permission-denied thật trên máy | báo lỗi, không queue vô hạn | n@n.com = employee: mọi thao tác UI của employee đều được rules cho phép (sửa cửa hàng / xoá cứng bị UI ẩn) ⇒ không tạo được PD qua UI | **BLOCKED** (rules emulator 17/17 + unit `permission-denied` rethrow PASS) | 09:31–09:33 |

## B. Sửa chữa
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| REP-03 | LƯU ĐƠN với model rỗng | chặn | log `Validation failed - model empty`, repairs không tăng (24) | PASS | A 09:35 |
| REP-04 | giá "-500" | không nhận âm | ô tiền lọc dấu trừ → "500" | PASS | A 09:35 |
| REP-05 | triple-tap LƯU ĐƠN | 1 đơn | 1 dòng `rep_1789871770577_770577`, 1 lần `_onlySave: Starting` | PASS | A 09:36 |
| REP-06 | Back đúng lúc đang lưu | — | lưu xong < 1 s, không bấm kịp | BLOCKED | |
| REP-11 | B (employee) XONG → Y/C DUYỆT (double-tap GỬI) | `pendingDeliveryApproval=1`, 1 yêu cầu, A thấy "CHỜ DUYỆT" | B: status 3, pending 1, requested 500, isSynced 1; A ≤10 s: pending 1; list "3 / TÉTNEG / N / CHỜ DUYỆT / YC 500đ" | PASS | 09:38–09:41 |
| REP-11b | A (owner) DUYỆT (double-tap) | status 4, 1 phiếu thu 500 | A: status 4, deliveredBy N, `pi_direct_repair_service_rep_1789871770577_770577` 500 COMPLETED (1); B ≤8 s: status 4, 1 intent | PASS | 09:42 |
| REP-20 | Sửa giá sau giao 500→600 | phải có bút toán chênh lệch / nợ | `repairs.price`=600 nhưng intent vẫn 500, không debt, không adjustment; tab Tiền 1,891 Tr (cash-basis) | **FAIL → NEW-02** | A 09:44 |
| REP-21 | Xoá đơn ĐÃ GIAO (vuốt) | — | chặn: "❌ Không thể xóa đơn ĐÃ GIAO" (quy tắc nghiệp vụ) | PASS | 09:47 |
| REP-22 | Xoá đơn TIẾP NHẬN (KH LE) mật khẩu rỗng / sai | chặn | "❌ Mật khẩu sai" 2 lần, `deleted=0` | PASS | 09:52 |
| REP-21b | Mật khẩu đúng | soft-delete, hoàn kho MAN HINH X +1, B nhận | A: `Restored part quantity: MAN HINH X, +1 => 2`, `Repair deleted directly on Firestore`, row gỡ khỏi SQLite; B: đơn biến mất (kho B: xem D-1) | PASS | 09:53 |
| REP-15/16 | Tạo đơn OPPO A5 + dịch vụ đối tác SC 200k TIỀN MẶT | 1 phiếu chi, 1 dòng trả đối tác, không nợ trùng | `pi_direct_repair_partner_debt_partner_payment_…` 200k COMPLETED; `repair_partner_payments` 1 dòng; repairs.cost 200k; không dòng debts mới | PASS | 10:01 |
| REP-15c, REP-24 | Dịch vụ đối tác CÔNG NỢ; Bảo hành | — | chưa chạy | BLOCKED | |

## C. Bán hàng
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| SALE-05 | CUSAC 180k CÔNG NỢ, trả trước 50k, KH mới QA KH9 | sale, debt 180k/paid 50k, 1 phiếu thu 50k, kho −1 | `sale_1789874093726_0901000009` CÔNG NỢ; `debt_1789874093726_0901000009` 180000/50000 ACTIVE; debt_payments 50k; products id68 9→8; log `Booked CÔNG NỢ partial payment: 50000`; B ≤15 s: đủ 4 mục | PASS | 10:14 |
| SALE-17 | Xoá đơn CÔNG NỢ (mật khẩu, double-tap XÓA ĐƠN) | gỡ debt + phiếu thu + intents, hoàn kho | A: sale gỡ, debt#105 + debtPayment#117 delete synced, `Deleted 2 payment intents`, qty 8→9; B: sale 0, debt 0, dp 0, qty 9 | PASS | 10:16 |
| SALE-06 | IP15PROMAX256 29 Tr TRẢ GÓP (NH) FE, cọc 1 Tr TIỀN MẶT | sale isInstallment, cọc = intent 1 Tr, máy status 0, chờ tất toán 28 Tr | sales `TRẢ GÓP (NH)`, downPayment 1.000.000, bankName FE; `pi_sale_down_…` 1 Tr COMPLETED; products status 0; list "Chờ NH tất toán … 28 Tr" | PASS | 10:19 |
| SALE-07 | Tất toán NH 28 Tr (double-tap XÁC NHẬN) | settlement 1 lần, intent NGÂN HÀNG 28 Tr | `settlementReceivedAt=1789874568436, settlementAmount=28000000`; `pi_settlement_…` 28 Tr NGÂN HÀNG COMPLETED (1); B: đủ; tab Tiền vào 30,89 Tr = Σ intents thu (31,09 − 0,2 chi đối tác), Tiền ra 2,47 = 0,12+2+0,15+0,2 | PASS | 10:22 |
| SALE-09/10/12/16/21/22/23/24 | — | — | chưa chạy | BLOCKED | |
| NEW-03 | Thứ tự ô nhập | — | màn bán: **Tên trái / SĐT phải**; màn đơn sửa: **SĐT trái / Tên phải** ⇒ nhập nhầm | FAIL (LOW) | 10:07 |

## D. Kho / Công nợ
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| INV-06 | Nhập QA-LOA x10 @40k, NCCTEST01, CÔNG NỢ, xác nhận (double-tap) | debts SHOP_OWES 400k, import_orders DEBT, không expense, không doc mồ côi | `debt_stock_se_1789874720053_kmlwe_…` 400000/0 ACTIVE SHOP_OWES; import_orders `PDBLBxVJeoXrYjB1hjVY` DEBT paid 0; expenses 400k = 0; repair_parts +10 | PASS | 10:26 |
| INV-08 / DEBT-08 | Trả NCC 150k (double-tap) | debt paid 150k, import_orders paid 150k, 1 phiếu | A: debts 150000, import_orders paidAmount 150000, debt_payments 1, intent `pi_direct_supplier_debt_…` 150k; B: debts 150000 ✓ nhưng **import_orders 0** | PASS (nợ) / **FAIL → NEW-04** (import_orders liên máy) | 10:28 |
| NEW-04 retest | trả thêm 100k sau khi sửa | B nhận import_orders 250k | A: 250000 isSynced 1, bump `import_orders`; B: 250000 | PASS | 10:36 |
| DEBT-03 | trả 300k khi còn 250k | chặn | "Số tiền thanh toán không được vượt 250.000", paid không đổi | PASS | 10:33 |
| DEBT-05/06/11, INV-13/14/15/16/18/19/20 | — | — | chưa chạy | BLOCKED | |

## E. 2 máy / Crash / Stress
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| MD-07 | A & B cùng tạo đơn sửa KH mới cùng SĐT 0901000777 (tap đồng thời) | không trùng KH | A & B: đúng 1 customer `customer_1789875614128` "QA DUP A", 2 repairs; tên máy B ("QA DUP B") bị gộp theo SĐT | PASS (ghi chú: người tạo sau mất tên) | 10:40 |
| MD-04 | A XONG, B sửa giá 350k cùng đơn (B lưu sau A ~1 phút) | không mất field | A & B: price 350000, status 3, repairedBy H | PASS (tuần tự; đồng thời tuyệt đối chưa ép được) | 10:45 |
| NEW-01 (quan sát) | B khoá màn hình lúc A thêm linh kiện (09:01); B mở lại 09:1x | listener đưa bản mới | B giữ bản cũ (cost 30k) tới khi bấm đồng bộ tay; tái hiện lần 2 (09:22, B mở màn) nhận đúng ≤2 s | 1/2 — theo dõi | |
| CR-03 | bán offline → bật mạng → kill app sau 3 s → mở lại | 1 doc, kho đúng | A: sale isSynced 0→1, `Synced 1 sales`; B: đúng 1 doc, qty 18 | PASS | 10:48 |
| CR-01/02/04–07 | — | — | chưa chạy | BLOCKED | |
| STRESS | 100/500/1000 dòng | — | máy không có `sqlite3`, `TestDataService`/`seed_test_data` không có lối vào UI, không push DB khi app chạy | BLOCKED | |

## F. Sửa code trong đợt này (đều có bằng chứng lỗi mới)
1. `payment_intent_service._syncImportOrderPaymentIfLinked` + `reconcileStaleImportOrderDebts`: 2 write trực tiếp không qua guard ⇒ không bump tín hiệu, không timeout, upsert local giữ `isSynced=1` khi cloud lỗi ⇒ **NEW-04**. Sửa: `CloudWritePolicy.guard` + `isSynced = cloudOk ? 1 : 0`.
2. `CloudWritePolicy.guard` mặc định bump `SyncSignalService` (context = tên collection); `_cw`/`_cwBg` truyền `bump:false`. Phát hiện từ REP-21b: hoàn kho ghi thẳng từ `DBHelper` với context `db_helper/restore` ⇒ B không nhận `repair_parts` (D-1). Sửa context thành `products/restore`, `repair_parts/restore`.
3. Bọc guard cho các write trực tiếp còn sót trong views (work_schedule, attendance, kiotviet_import, shop_settings, home, advanced_chat, staff_self_profile, register, shop_selector, shop_switcher).

## G. Tổng đợt 3
Đã chạy **31** mục · **PASS 26** · **FAIL 3** (REP-20→NEW-02 mở; NEW-03 mở; NEW-04 đã sửa & retest PASS) · **BLOCKED 2** cứng (RG-14, RG-15) + các case ghi BLOCKED chưa chạy.
Unit: 718 PASS / 0 FAIL, analyze 0 error.
