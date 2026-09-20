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

---

# ĐỢT 4 — 2026-09-20 (12:50–13:30): NEW-02 + chạy tiếp plan (DỪNG ở NEW-05 HIGH)

Máy A = CPH2203 m@m.com (chủ) · B = CPH2239 n@n.com (nhân viên). Build working tree (commit sau `9f50fe02`), cài 12:58 / 13:15.

## A. NEW-02 — sửa giá đơn sửa ĐÃ GIAO (Phần A)
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| NEW-02-U1 | unit: đơn status 3 | không tạo nợ | null, không debts | PASS | `test/repair_price_adjustment_test.dart` |
| NEW-02-U2 | unit: giao TIỀN MẶT 500 → 600 → 700 → (khách trả 50) → 500 → 550 → 400 | tăng: 1 nợ khách 100 rồi 200 (không trùng); về 500 sau khi trả 50: nợ khách PAID + shop nợ khách 50; 550: đóng; 400: shop nợ 150 (mở lại cùng bản ghi) | đúng, `COUNT(debts WHERE linkedId)`=1 mỗi loại | PASS | unit |
| NEW-02-U3 | unit: giao CÔNG NỢ 500 đã trả 200 → 600 → 150 → 500 | 600: nợ giao = 600 ACTIVE; 150: nợ giao = 200 (=đã trả) PAID + shop nợ 50; 500: về ACTIVE 500, shop-nợ đóng | đúng | PASS | unit |
| NEW-02-D1 | A: đơn TÉTNEG (đã giao, thu 500) giá 600→700 | nợ khách `debt_adj_cust_…` 200 ACTIVE, sync, B nhận | log `💱 RepairPriceAdjust … price=700 collected=500 outstanding=200`, `Successfully synced debt#107`; SQLite A: CUSTOMER_OWES 200/0 ACTIVE isSynced 1; snackbar "Khách còn phải trả thêm 200 — đã ghi vào Công nợ" | PASS | A 13:05 |
| NEW-02-D2 | 700 → 500 (về giá cũ) | đóng nợ (xoá mềm), không trùng | `outstanding=0`; debt total 0 PAID deleted=1; queue delete synced | PASS | A 13:07 |
| NEW-02-D3 | 500 → 400 | shop nợ khách `debt_adj_shop_…` 100 ACTIVE | `outstanding=-100`; SHOP_OWES 100 ACTIVE; B sau khi mở app: chỉ còn SHOP_OWES 100 (cust đã xoá); màn Công nợ → Phải trả hiện "1 khoản / 100" | PASS | A 13:09, B 13:12 |
| NEW-02-F | tài chính | thu nợ chênh lệch của đơn TIỀN MẶT tính là doanh thu sửa (không phải "thu khác") | `finance_v2_data_service._linkedRevenueOf` nhận `linkedDebtLinkedType=REPAIR_PRICE_ADJUST`; scenario/comprehensive tests PASS | PASS (unit) | |

## B. Chạy tiếp plan
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| REP-15c | Tạo đơn NOKIA X + dịch vụ đối tác SC 300k **CÔNG NỢ** | 1 nợ SHOP_OWES đối tác, không phiếu chi, không trùng | `debt_partner_debt_rep_1789885188261_…_svc_…_300000` SC 300000/0 ACTIVE SHOP_OWES; intents mới = 0; log `Partner debt recorded` + `Created doc with existing ID` | PASS | A 13:19 |
| REP-24 | Màn Bảo hành | workflow BH | chỉ là danh sách theo dõi (sửa/bán có BH) → mở chi tiết đơn gốc; không có luồng "đơn BH 0đ" riêng (= tạo đơn thường giá 0, đã phủ bởi REP-01/05) | PASS-partial | A 13:20 |
| SALE-09 (online) | CAPLIGHTNING tồn 18, số lượng 120, TIỀN MẶT | chặn | UI cho nhập 120 (14,4 Tr) nhưng transaction cloud chặn `OUT_OF_STOCK:CAPLIGHTNING (còn: 18, cần: 120)`; kho 18, 0 sale | PASS (server) / LOW: UI không chặn trước | A 13:23 |
| SALE-09 (offline) | cùng đơn, mạng OFF | chặn theo tồn local | **Lưu local-first, `Deducted CAPLIGHTNING quantity by 120` ⇒ `products.quantity = -102`, sale 14,4 Tr tạo, isSynced 0→1 khi có mạng (đẩy số âm lên cloud)** | **FAIL → NEW-05 HIGH** | A 13:24; đã xoá đơn để hoàn kho 18 (13:27) |

**DỪNG theo constraint (HIGH mới) — các case còn lại (SALE-16/22/23, INV-13/14/15/16/18/20, DEBT-05/06/11, MD-10, CR-01/02/04–07) chưa chạy, chờ quyết định.**

## C. Tổng đợt 4
Đã chạy **11** mục (7 NEW-02 + 4 plan) · **PASS 10** · **FAIL 1** (NEW-05) · BLOCKED 0 (còn lại chưa chạy do dừng).
Unit 721 PASS / 0 FAIL (thêm `repair_price_adjustment_test` 3), analyze 0 error.

---

# ĐỢT 5 — 2026-09-20 (13:40–14:50): NEW-05 + chạy nốt plan (DỪNG ở NEW-08 HIGH)

Máy A = CPH2203 m@m.com (chủ) · B = CPH2239 n@n.com (nhân viên). Build working tree: `9955ade7` (cài 13:55) và bản có NEW-06 (cài 14:33).

## A. NEW-05 — bán local-first không kiểm tồn (Phần A)
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| NEW-05-U1 | unit `deductProductQuantity` trừ 120 khi tồn 18 | tồn = 0, không âm | 0 | PASS | `test/sale_stock_guard_test.dart` |
| NEW-05-U2 | unit `SaleStockGuard.shortages` (2 dòng cùng SP 10+10 khi tồn 18; điện thoại IMEI status≠1) | báo "CAPLIGHTNING (còn: 18, cần: 20)"; ĐT đã bán maxSellable = 0 | đúng | PASS | unit |
| NEW-05-D1 | A **mất mạng**, Tạo đơn bán → CAPLIGHTNING (tồn 18) → gõ số lượng 120 | ô số lượng kẹp về 18 + cảnh báo | snackbar "⚠️ CAPLIGHTNING: chỉ còn 18 trong kho", ô = 18; nút "+" không tăng quá 18 | PASS | A 13:57 |
| NEW-05-D2 | (cùng phiên mất mạng) bán đúng 18 (toàn bộ tồn) TIỀN MẶT | lưu local, tồn = 0, không âm | "Đã ghi nhận — chờ đồng bộ"; `products.quantity=0,status=0`; sale 2.160.000 isSynced 0; có mạng → sync; xoá đơn test → tồn về 18/status 1 (A & B) | PASS | A 13:58–14:01 |
| NEW-05-D3 | hàng rào lưu (`_checkLocalStock`) khi tồn đổi giữa lúc chọn và lúc lưu | báo "Không đủ hàng! … (còn N, cần M)" và không lưu | không tái hiện được qua UI (ô số lượng đã kẹp) — phủ bằng NEW-05-U2 | PASS (unit) | |

## B. Chạy nốt plan
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| SALE-16 | A xoá đơn tiền mặt CAPLIGHTNING 120k (08:39) | đơn xoá mềm, hoàn kho, phiếu thu xoá, B nhận | A: sale deleted=1, kho +1, intent deleted; B nhận sau bump `sales,products,payment_intents` | PASS | A/B 14:05 |
| SALE-22 | Xem trước biên nhận + QR chuyển khoản | hiển thị đúng số tiền/STK | biên nhận + QR hiện đúng; **in vật lý BLOCKED** (không máy in) | PASS / BLOCKED (in) | A 14:08 |
| INV-13 | A sửa giá bán SP (→110k) | B nhận | B `products.price=110000` sau signal | PASS | 14:10 |
| INV-14 | A xoá SP có tồn (CAP SAC Y, tồn 7) | xoá mềm, lịch sử bán giữ, B ẩn SP | `deleted=1`, sales cũ vẫn tra được; B ẩn | PASS | 14:12 |
| INV-15 | Kiểm kho (đối chiếu tồn thực tế) rồi lưu | phiếu kiểm kho lưu + sync | lưu local `inventory_checks` id 8 **`firestoreId NULL`, `isSynced 0`**, không có bảng nào đẩy lên cloud ⇒ B không thấy | **FAIL → L-08 LOW** | A 14:15 |
| INV-16 | A tạo vị trí kho QA-KE1 | B nhận | `loc_1789889057749_QA-KE1` isSynced 1, bump `storage_locations`, B có QA-KE1 | PASS | 14:23 |
| INV-18 | Đơn đặt hàng NCC (PurchaseOrderListView) | vào từ menu Kho | **không có lối vào từ menu Kho**; chỉ tới được qua Nhắc việc (`reminders_view.dart:490`) | **FAIL → D-07 LOW** (điều hướng) | 14:24 |
| INV-20 | Chủ shop tắt quyền xem giá vốn của n@n.com | có công tắc GIÁ VỐN trong Nhân viên → sửa → phân quyền | sheet "PHÂN QUYỀN NỘI DUNG" (`staff_list_view`) có 11 công tắc, **không có GIÁ VỐN**; `_canViewCostPrice` được lưu nhưng không có widget; màn có công tắc (`staff_permissions_view`) mồ côi | **FAIL → NEW-07 MEDIUM** | A 14:27 |
| NEW-06 (mới) | Hàng đợi `sync_queue` có mục delete `sales/sale_…` mà doc chưa từng lên cloud (đơn offline đã xoá trước khi sync) | không kẹt "Lỗi đồng bộ" | trước: `permission-denied` retry mãi, badge đỏ; sau sửa `_handleDelete` bỏ qua permission-denied: log `⏭️ Delete sales/…: permission-denied (doc chưa có trên cloud), bỏ qua`, queue rỗng, header "Đã đồng bộ" | **FIXED** | A 14:36 |
| DEBT-05 | Thu gộp 2 khoản TÉTCONGNO (30k còn + 200k) nhập 100k TIỀN MẶT | phân bổ cũ→mới: 30k đóng khoản 1, 70k vào khoản 2; 2 phiếu thu; B nhận | preview đúng; A: debt78 PAID 50/50, debt79 70/200; 2 `payment_intents` CUSTOMER_DEBT_COLLECT 30k/70k, 2 `debt_payments` (`debtFirestoreId` đúng); B (đang ngủ) vẫn nhận cả 3 bảng | PASS | A/B 14:38 |
| DEBT-06 | Miễn nợ 100đ (`debt_adj_shop_…TÉTNEG`) qua Công cụ điều chỉnh dữ liệu (lý do, tóm tắt, mật khẩu) | nợ xoá mềm, audit, đẩy cloud, B ẩn nợ | A: `deleted=1, isSynced=0`, audit `RECONCILE_WRITE_OFF_DEBT`; **không đẩy cloud** (không bump, không enqueue); sau resume A `syncAllToCloud` "Synced 2 debts" nhưng là 78/79 — nợ 108 **vẫn isSynced=0** vì `getAllDebts()` lọc `deleted=0`; B sau 3 phút vẫn ACTIVE | **FAIL → NEW-08 HIGH** | A 14:43–14:47, B 14:47 |
| DEBT-11, MD-10, CR-01→07, SALE-23 | | | **chưa chạy — dừng theo constraint (HIGH mới)** | — | |

## C. Quan sát thêm (LOW)
- `sync_service.dart` ~3590 (đẩy debts sau thanh toán): ghi cloud nhưng **không đánh dấu isSynced=1** ⇒ mỗi lần thanh toán đẩy lại toàn bộ nợ chưa đánh dấu (log "Synced 2 debts" 2 lần) tới khi `syncAllToCloud` chạy. Không sai dữ liệu, chỉ thừa write → L-09.

## D. Tổng đợt 5
Đã chạy **16** mục · **PASS 11** · **FAIL 4** (INV-15 L-08, INV-18 D-07, INV-20 NEW-07, DEBT-06 NEW-08) · BLOCKED 1 (in vật lý) · NEW-06 FIXED. Còn 10 case chưa chạy.

---

# ĐỢT 6 — 2026-09-20 (15:00–18:30): NEW-08 + chạy nốt plan (HOÀN TẤT)

Máy A = CPH2203 m@m.com (chủ) · B = CPH2239 n@n.com (nhân viên). Build working tree cài 15:09 (NEW-08) và 18:19 (NEW-10).

## A. NEW-08 — miễn nợ không lên cloud (Phần A)
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| NEW-08-U1 | unit `writeOffDebt` | xoá mềm local + 1 mục `sync_queue` delete đúng firestoreId | `deleted=1,isSynced=0`, note "Miễn nợ: …", queue 1 mục `delete` | PASS | `test/debt_write_off_sync_test.dart` |
| NEW-08-U2 | unit `getUnsyncedDeletedDebts` | chỉ row deleted=1 & isSynced=0 & có firestoreId | đúng (loại row đã sync, row còn sống, row không firestoreId) | PASS | unit |
| NEW-08-D1 | A mở app bản mới, bấm đồng bộ (dọn khoản kẹt #108 đã miễn ở đợt 5) | `syncAllToCloud` đẩy `deleted:true`, B ẩn nợ | log `Synced 1 debts to cloud` + `bump debts`; echo cloud xoá row local A; B poll 1 doc → không còn nợ | PASS | A/B 15:11 |
| NEW-08-D2 | A miễn nợ mới (SC 300k, lý do QA-NEW08, tóm tắt, mật khẩu) | enqueue → cloud → B ẩn trong vài giây | `Enqueued debt#109 (delete)` → `Successfully synced` → `bump debts` 15:14:25; B `SyncSignal: nhận debts` 15:14:26, `Polled debts: 1 docs`, row biến mất | PASS | A/B 15:14 |

## B. Chạy nốt plan
| Test ID | Action | Expected | Actual | Kết quả | Evidence |
|---|---|---|---|---|---|
| DEBT-11 | Xoá/sửa phiếu thu nợ | có cho phép? | Sheet "Lịch sử trả nợ" chỉ xem, không có xoá/sửa (không long-press, không nút); chỉ Công cụ điều chỉnh → TÀI CHÍNH xoá phiếu **mồ côi**. Muốn sửa phải xoá nợ/đơn ⇒ N/A theo thiết kế | PASS (N/A) | A 15:17 |
| MD-10 | A nhập thêm OP LUNG Y +3 (NHẬP THÊM, TIỀN MẶT) | B nhận tồn mới, 1 phiếu chi | A 18→21, `confirmEntry … Created local EXPENSE 150000`; B 21 sau ~15 s. Ghi chú: SP "Chưa NCC" (CAPLIGHTNING) bị chặn nhập nhanh "không tìm thấy NCC" — đúng thiết kế nhưng snackbar biến mất nhanh | PASS | A/B 15:22 |
| CR-01a | Tap HOÀN TẤT rồi kill ngay (0–0,9 s, trước transaction cloud) | không có gì được ghi | 30 đơn, tồn 21, queue 0, cloud không có; mở lại sạch | PASS | 15:25 / 15:27 |
| CR-01b | kill **giữa** `executeSaleTransaction` (2,2 s) | cloud commit hoặc không; mở lại nhất quán | cloud ĐÃ commit (sale + tồn 22); mở lại A kéo về sale #31 + tồn 22, B có sale. **Nhưng phiếu thu `SALE_PAYMENT` 200k không được tạo** (tạo ở bước sau transaction, đã bị kill) ⇒ tab Tiền thiếu 200k; B tồn vẫn 23 tới lần poll sau (bump products cũng bị kill) | **FAIL → NEW-09 MEDIUM** | A 15:29, B 15:30 |
| CR-02 | NHẬP THÊM +2, kill 0,4 s sau xác nhận | không trùng, phục hồi được | kill sau `createEntry` (draft lên cloud) trước `confirmEntry`: tồn không đổi, Kho hiện "1 Xác nhận nhập vào kho"; xác nhận tay → 23 (A & B), 1 phiếu chi 100k, không trùng | PASS | 15:31–15:33 |
| CR-03 | kill giữa syncAll → item `processing` kẹt? | tự retry | static: `syncAll` lấy `status IN ('pending','processing')` (`sync_orchestrator.dart:616`) ⇒ item processing được chạy lại | PASS (static) | |
| CR-04 | Back khi dialog "Bán offline" | không lưu, nút mở lại | dialog chỉ hiện khi SP chưa có firestoreId (không tái hiện được trên dữ liệu hiện tại); static: `showDialog` trả null ⇒ `_isSaving=false`, return | PASS (static) | `create_sale_view.dart:1454–1483` |
| CR-05 | wifi → 4G giữa listener | re-attach | **BLOCKED** — cả 2 máy không SIM (`gsm.sim.state=ABSENT`); wifi tắt/bật đã phủ ở RG-01b/03c | BLOCKED | |
| CR-06 | B khoá màn hình 2,5 h (15:33→18:06); A sửa giá OP LUNG Y 200k→210k lúc 15:34 | B mở lại nhận đúng, không trùng | B: price 210000, qty 22; 31 sales = 31 distinct; 1 lượt refresh 20 bảng | PASS | B 18:07 |
| CR-07 | A background 2,5 h (15:35→18:08); B tạo đơn sửa QACR7 lúc 18:07 | A resume kéo về, không trùng | A: 29 repairs = 29 distinct (có QACR7), 31 sales distinct, payment_intents 173 không đổi, queue 0 | PASS | A 18:08 |
| SALE-23 | A chốt quỹ ngày 20/09 (TM 220.400 / NH 105.767.000) rồi tạo đơn bán | chặn | `cash_closings` isLocked=1 synced; `_processSale: canEdit = false` ⇒ không lưu (31 đơn giữ nguyên, tồn 22) | PASS | A 18:12–18:14 |
| SALE-23b | B có nhận chốt quỹ không? | B có row 20/09 ⇒ cũng bị chặn | **B không có row** sau >5 phút: 3 write `cash_closings` trong `cash_closing_view` ghi thẳng Firestore, không qua CloudWritePolicy (không timeout, không bump) | **FAIL → NEW-10 MEDIUM, ĐÃ SỬA** | B 18:16 |
| NEW-10-D | Sau sửa: A "Sửa chốt quỹ" 220.400→221.400 (lý do QA) | bump `cash_closings`, B nhận | A `bump cash_closings`; B `refreshCollectionNow(cash_closings)` → `Polled 1 docs` → row 20/09 isLocked=1 cashEnd 221400 | PASS | A/B 18:26 |

## C. Tổng đợt 6
Đã chạy **17** mục · **PASS 14** (3 static/N-A) · **FAIL 2** (CR-01b NEW-09 mở, SALE-23b NEW-10 đã sửa) · BLOCKED 1 (CR-05). Unit 725 PASS, analyze 0 error.
Dữ liệu test để lại trên shop M: ngày 20/09 đã chốt quỹ (dùng "Sửa chốt quỹ" nếu cần bán tiếp), nợ SC 300k và nợ điều chỉnh TÉTNEG đã miễn, đơn sửa QACR7 (B tạo), sale #31 OP LUNG Y 200k không có phiếu thu (NEW-09).
