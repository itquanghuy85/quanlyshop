# FULL TEST REPORT — HULUCA Shop Manager (2026-09-19 → 20)

Kèm theo: `docs/FULL_TEST_PLAN_2026-09-19.md` (Feature Map + Test Plan). Không sửa code app trong đợt này.

## 0. Môi trường
| | |
|---|---|
| Build | debug APK từ HEAD `3490b3ad` (build 2026-09-19 22:30), versionName 3.7.0 |
| Máy A | OPPO CPH2203 (`NJR8W86LKRVW7DHQ`) — m@m.com, shop M (`geqXPHQJ3nT6XkMbeh6JswTdGbr2`) |
| Máy B | OPPO CPH2239 (`WCE65565HMDYOB59`) — m@m.com, cùng shop M |
| Emulator rules | Firestore emulator 127.0.0.1:8089, `tools/firestore_rules_test/cross_shop_test.js` |
| Tự động | `flutter analyze`, `flutter test` (79 file), `test/full_audit_db_schema_test.dart` (FFI, mới) |
| Điều khiển | adb + uiautomator (không nhờ người dùng thao tác) |

## 1. Số liệu tổng
| Mục | Số |
|---|---|
| Module thực tế | **17** |
| Màn hình (file có `Scaffold`) | **127** (136 file view; 13 view + 1 dialog mồ côi — không điều hướng tới) |
| Workflow xuyên module | **10** (WF-01…10) |
| SQLite table | 45 distinct (41 trong `onCreate` + `payment_intents` tạo lười + 3 bảng tạm) |
| Firestore collection dùng trong code | 57; rules 60 block; Cloud Functions 21 |
| Test case trong plan | **~185** (AUTH 10, REP 30, SALE 24, INV 21, DEBT 11, FIN 11, PERM 11, MD 10, READ 9, CR 7, DB 7, + tự động 706) |
| Đã thực thi có bằng chứng | **58** (34 máy thật/2 máy, 17 rules emulator, 7 DB FFI) + 706 unit test |
| PASS | 45 + 706 unit |
| FAIL | **10** (→ 10 bug bên dưới) |
| BLOCKED / chưa chạy | ~127 test case còn lại (xem §5) |
| Severity | CRITICAL 0 · HIGH 3 · MEDIUM 7 · LOW 4 (+ 6 finding code chết/kiến trúc) |

Baseline tự động: `flutter analyze` 0 error / 0 warning / 1860 info; `flutter test` **706 PASS, 1 skipped, 0 FAIL**.

## 2. BUG LIST (theo mức nguy hiểm)

### BUG-01 — HIGH — Đã đăng nhập + mất mạng ⇒ KHÔNG BÁN ĐƯỢC HÀNG
- MODULE/SCREEN: Bán hàng / `create_sale_view._processSale` · SERVICE `FirestoreService.executeSaleTransaction`, `ClaimsService.refreshMyClaims` · TABLE `sales`,`products` · COLLECTION `sales`,`products`
- CONDITION: phiên online (có Firebase user), wifi+data tắt.
- STEPS: Bán hàng → chọn CAPLIGHTNING → Khách vãng lai → TIỀN MẶT → HOÀN TẤT.
- EXPECTED: lưu local-first (`isSynced=0`, vào `sync_queue`), đẩy lên khi có mạng — như tinh thần offline-first của app.
- ACTUAL: logcat `❌ Sale transaction failed: [cloud_firestore/unavailable]` → snackbar lỗi, **0 sale, kho không đổi**. Fallback "bán offline" chỉ kích hoạt khi `errorMsg.contains('permission-denied') || needRelogin` (`create_sale_view.dart:1437-1470`); `unavailable` rơi vào nhánh `else` báo lỗi.
- DATA/FINANCIAL IMPACT: mất giao dịch khi mất mạng (nhân viên phải ghi tay). SYNC: không.
- REPRO 1/1 · OFFLINE: có · MULTI-DEVICE: n/a
- ROOT CAUSE: thiếu nhánh `unavailable`/`deadline-exceeded` trong xử lý lỗi transaction; không kiểm `ConnectivityService` trước.

### BUG-02 — HIGH — Tạo đơn sửa khi mất mạng TREO vô hạn "Đang đồng bộ dữ liệu lên server…"
- SCREEN `create_repair_order_view` (dòng 850 `customerService.addCustomer`) · SERVICE `CustomerService.addCustomer` → `FirestoreService.addCustomer` (`docRef.set` **không timeout**) · TABLE `repairs`,`customers`,`sync_queue`
- STEPS: mất mạng → nhập KH mới + máy + lỗi + giá → LƯU ĐƠN.
- ACTUAL: `repairs` id 69 ghi local `isSynced=0` nhưng **`sync_queue` = 0 dòng** (chưa tới `enqueue`), UI treo >3 phút; chỉ hoàn tất sau khi bật mạng lại (01:17:30). Kill app lúc này ⇒ đơn không có mục queue (được vớt nhờ `syncAllToCloud` quét `isSynced=0` — chưa xác nhận cho mọi bảng).
- ROOT CAUSE: `FirestoreService` có **67 lệnh `set/add/update`, 0 lệnh `.timeout(`**; Firestore SDK bật persistence ⇒ Future không resolve khi offline. Cùng họ: BUG-04.
- REPRO 1/1 · FINANCIAL: nếu có cọc thì tiền chưa ghi.

### BUG-03 — MEDIUM — Lưu đơn sửa không validate SĐT; SĐT chữ được ghi vào `customers.phone`
- SCREEN `create_repair_order_view` · Bằng chứng: `customers` id 84 `name='0901000001', phone='QA KH1'`; `repairs` 69 `phone='QA KH1'`. `UserService.validatePhone` chỉ được gọi ở `_addCustomerQuick` (dòng 674), không ở `_saveOrderProcess`.
- IMPACT: danh bạ bẩn, tra cứu theo SĐT hỏng, gộp khách sai.

### BUG-04 — HIGH — Nhập kho "LƯU VÀO HÀNG CHỜ" treo "Đang lưu…" khi mất mạng; nút LƯU TẠM vẫn bấm được
- SERVICE `StockEntryService.createEntry` (cloud-first, `stock_entries` không có bảng SQLite ở phiên online) · COLLECTION `stock_entries`
- ACTUAL: treo 92 giây cho tới khi bật mạng (`✅` lúc 01:21:53); trong lúc treo `LƯU TẠM` vẫn enabled ⇒ nguy cơ phiếu trùng.
- ROOT CAUSE: như BUG-02; nhánh `OfflineStockEntryStore` chỉ dùng khi `AppSession.isOffline`, không dùng khi online-mất-mạng.

### BUG-05 — MEDIUM — Máy khác KHÔNG nhận tồn kho / công nợ / phiếu thu khi app mở liên tục
- SERVICE `SyncService` · chỉ `repairs`,`sales` có listener (`_liveWindowCollections`); 28 bảng còn lại **không có timer poll** — chỉ refresh khi `app_resumed` / bấm đồng bộ / vào vài màn (`refreshCloudCollections` callers).
- EVIDENCE: B mở màn hình chính 7 phút: `sales` về ngay (01:23:41) nhưng `products.quantity` 20 (A=19), `payment_intents` thiếu, `debts.paidAmount` 0 (A=100.000), `repair_parts` 5 (A=4). Background→resume: về đủ trong 20s.
- IMPACT: nhân viên máy 2 thấy tồn/nợ cũ; bán trùng bị chặn nhờ transaction cloud nhưng UI gây nhầm. Comment code gọi là "nhịp poll 120s" nhưng thực tế là cooldown.

### BUG-06 — MEDIUM — Tab Tài chính → Tiền hiện thiếu phiếu thu nợ vừa ghi (cache không invalidate)
- FILE `finance_v2_cache.dart:138` (`debts_changed` → chỉ `FinanceSection.debt`); `debt_payment_sheet.dart:275`, `customer_debt_payment_service.dart:230` chỉ emit `debts_changed`; `debt_payments_changed` chỉ emit ở `firestore_service.dart:740` (đường cloud).
- EVIDENCE: thu 100.000 lúc 01:26 → mở Tài chính 01:31: "Tiền vào 120.000, 1 giao dịch"; đổi kỳ 7 ngày→Hôm nay: "220.000, 2 giao dịch".

### BUG-07 — MEDIUM — Snapshot linh kiện từ `repair_parts` không ghi id cloud
- FILE `repair_detail_view.dart:2540` — `productId/productFirestoreId` chỉ set khi `source=='products'`; linh kiện từ kho phụ tùng chỉ còn `name`. EVIDENCE: `repairs.partsUsedDetailed = [{"name":"MANHINH95","productId":null,"cost":1500000,"qty":1}]` trên cả A và B.
- IMPACT: đổi/xoá linh kiện, hoàn kho, thống kê theo tên ⇒ sai khi trùng tên (vi phạm CLAUDE.md §12 cho `repair_parts`).

### BUG-08 — MEDIUM — Snackbar thông báo tài chính (duration 5s) treo >10 phút, che nút thao tác đáy màn hình
- FILE `notification_service.dart:1310-1365` (`_showInAppNotification`, `SnackBarBehavior.floating`, `duration: 5s`).
- EVIDENCE: banner "THANH TOÁN THÀNH CÔNG 01:23" còn lúc 01:35; banner "THU TIỀN SỬA MÁY 01:37" còn lúc 01:43 trên mọi màn (chi tiết đơn, trả hàng), che nút "Phụ tùng/Kho LK" và "Xác nhận trả hàng"; tap vào banner không đóng. REPRO 2/2.
- ROOT CAUSE DỰ KIẾN: messenger gốc (`messengerKey`) + route đổi khiến timer không chạy / snackbar được show lại; cần `hideCurrentSnackBar` khi push route hoặc dùng overlay có auto-dismiss riêng.

### BUG-09 — MEDIUM — Hoàn tiền trả hàng không tạo phiếu chi / ledger; các màn tài chính không thống nhất
- SERVICE `SalesReturnService.processReturn` · TABLE `sales_returns` (+kho đúng), **0 dòng** `payment_intents`/`expenses`/`financial_activity_log` cho 120.000 hoàn TIỀN MẶT.
- EVIDENCE: sau trả hàng — tab Tiền: "Tiền vào 1,6 Tr / Tiền ra 0 / 3 giao dịch" nhưng danh sách vẫn có dòng "+120.000 CAPLIGHTNING"; Chốt quỹ: "Thu trong ngày 1,72 Tr", "Tiền mặt 1,6 Tr". Không màn nào có dòng "Hoàn tiền −120.000".
- IMPACT: sổ quỹ không truy vết được tiền hoàn; số tổng đúng nhờ trừ ngầm.

### BUG-10 — LOW — Trạng thái nợ dùng 2 tên cho cùng nghĩa (`ACTIVE` / `UNPAID`)
- EVIDENCE shop M: CUSTOMER_OWES ACTIVE 4 + UNPAID 2; thu 1 phần → `ACTIVE` đổi thành `UNPAID` (`updateDebtPaid`). UI cộng đúng cả 2, nhưng truy vấn/báo cáo nào lọc `status='ACTIVE'` sẽ thiếu.

### Finding LOW khác
- L-01 `payment_intents` không nằm trong `onCreate` v111 (tạo lười `_ensurePaymentIntentsSchema`); `SyncHealthCheck`/`DataReconciliationService` raw-query bảng này có thể lỗi "no such table" trên máy cài mới trước lần ghi đầu.
- L-02 `cash_closings.firestoreId` không UNIQUE (các bảng sync khác có) ⇒ upsert phụ thuộc code.
- L-03 `getAllDebts` dùng `shopId = ? OR shopId IS NULL` ⇒ dòng `shopId NULL` hiện ở mọi shop trên cùng máy (FFI DB-06 tái hiện).
- L-04 Kho: header "QUẢN LÝ KHO / 28 điện thoại" nhưng tab "Tất cả 13 · Điện thoại 6 · Phụ kiện 7"; 2 SP cùng tên `CUSAC` (id 68 cloud, id 86 `product_1789704973657__25` client) — nghi trùng do claim/offline.
- L-05 Sau ĐĂNG XUẤT, app tự rơi về "Chế độ Offline" với TOÀN BỘ dữ liệu shop, "Mật khẩu bảo vệ: Chưa đặt" ⇒ ai cầm máy đều xem/sửa được (thiết kế `ownsShop`, nhưng nên cảnh báo/ép PIN).
- L-06 Không có `storage.rules` dù `firebase.json` khai `"storage": {"rules": "storage.rules"}` ⇒ `firebase deploy` sẽ lỗi / Storage dùng rule mặc định console.

### Finding kiến trúc / code chết (không phải bug runtime)
- D-01 13 view mồ côi: `payroll_view` (knowledge base ghi "Nhân viên → Bảng lương" nhưng không tới được — **AI trợ lý chỉ sai**), `staff_permissions_view`, `partner_management_view`, `pending_payments_list_view`, `quick_input_library_view`, `quick_input_management_view`, `repair_receipt_view`, `invoice_template_view`, `financial_activity_log_view`, `my_profile_view`, `ai_usage_dashboard_view`, `super_admin_view`, `expansion_modules_hub_view`; dialog `hr/add_custom_adjustment_dialog`.
- D-02 6 service mồ côi: `supplier_payment_service` (ghi root `supplier_payments` **không có shopId path** — nếu được gọi lại sẽ lệch), `repair_stock_service`, `thermal_printer_service`, `sync_control`, `logging_service`, `test_data_service`; `lib/data/db_migration_service.dart` dead.
- D-03 `StockEntryService` confirm-transaction ghi `financial_activities` + `supplier_debts` (cloud-only, không bảng SQLite, không ai đọc) song song với `financial_activity_log` + `debts` ⇒ mỗi phiếu nhập CÔNG NỢ tạo 1 doc nợ mồ côi trên cloud (tốn write/read, gây nhầm khi audit).
- D-04 Bảng `product_variants` vẫn được tạo (tính năng đã gỡ 2026-09-11); rules còn `product_variants`, `supplier_debts`, `financial_activities`.
- D-05 30 file view/widget gọi `FirebaseFirestore.instance` trực tiếp (vi phạm Service-First; `super_admin_console_view` 10 chỗ, `shop_settings_view` 6, `cash_closing_view` 5, `work_schedule_settings_view` 5).
- D-06 Migration `onUpgrade` thiếu khối `oldV < 38` (37→39) — vô hại vì các khối dùng `IF NOT EXISTS`/try-catch; schema máy thật (đã migrate nhiều đời) **khớp 100%** với `onCreate` (diff 0 cột, chỉ dư 2 bảng lười `firebase_read_stats`, `sync_audit_log`).

## 3. KẾT QUẢ THEO NHÓM

### 3.1 DB (FFI + máy thật) — 7 case
| ID | Kết quả |
|---|---|
| DB-01 version 111, đủ bảng | PASS (thiếu `payment_intents` trong onCreate → L-01) |
| DB-02 shopId/isSynced/firestoreId UNIQUE | PASS có ghi chú (L-02; `work_schedules` khoá `userId`) |
| DB-03 foreign_keys | pragma ON nhưng **0 bảng khai FK** (quan hệ chỉ bằng code) |
| DB-04 insert trùng | `debts` UNIQUE chặn ✓; `payment_intents.intentId` chặn ✓ |
| DB-05 sync_queue schema | PASS (`status`,`retryCount`,`lastError`) |
| DB-06 NULL shopId | FAIL nhẹ (L-03) |
| DB-07 defaults | `products.quantity=1,status=1`; `repairs.status` không default (dựa `_normalizeRepairStatus`) |
| Migration drift máy thật vs fresh | PASS (0 khác biệt) |
| Toàn vẹn dữ liệu shop M (trước test) | 0 nợ trùng linkedId, 0 intent trùng, 0 `paidAmount ≠ Σdebt_payments`, 0 qty âm |

### 3.2 Bán hàng — 8 case chạy
TC-SALE-01 PASS (sale, kho 20→19, intent 120k, cloud transaction) · SALE-08 double-tap PASS (1 sale) · SALE-11 **FAIL BUG-01** · SALE-18 trả hàng: kho hoàn ✓, 1 phiếu dù double-tap ✓, tiền **FAIL BUG-09** · SALE-24 (staff không quyền) chưa chạy máy, rules PASS.

### 3.3 Sửa chữa — 7 case
REP-01/07 tạo (mất mạng) **FAIL BUG-02**, lưu local ✓, lên cloud sau khi có mạng ✓ · REP-03 validate **FAIL BUG-03** · REP-10 1→3→4 PASS (`repairedBy`, `finishedAt` giữ) · REP-12 thêm linh kiện: `repair_parts` 5→4 ✓, cost 1,5 Tr ✓, snapshot **FAIL BUG-07** · REP-18 giao thu TIỀN MẶT: 1 intent `pi_direct_repair_service_…` dù double-tap ✓ · REP-26 A→B đơn sửa về ≤30s PASS.

### 3.4 Công nợ — 3 case
DEBT-01 thu 100k: `debts.paidAmount` ✓, `debt_payments` 1 ✓, intent ✓, `financial_activity_log` ✓ · DEBT-04 triple-tap → 1 phiếu ✓ (idempotency `<fid>_<ts>` + UI guard) · DEBT-10 tổng UI 17,56 Tr = SQL (ACTIVE+UNPAID) ✓.

### 3.5 Tài chính — 5 case
FIN-01 tab Tiền sau 3 giao dịch = 1,72 Tr = SQL Σ intents ✓ (sau BUG-06 refresh) · FIN-02 Lãi: DT 1,72 Tr = bán 120k + sửa 1,6 Tr (1,5 Tr giao + 100k thu nợ theo "phương án A"), vốn 1,583 Tr = 50k + 1,5 Tr + 33.333 pro-rata ⇒ đúng công thức đã chốt · FIN-04 Chốt quỹ Tiền mặt 1,6 Tr sau hoàn ✓ nhưng "Thu 1,72" (BUG-09) · FIN-06 unit tests PASS · FIN-10 chưa chạy.

### 3.6 Kho — 2 case
INV-09 **FAIL BUG-04** · INV-17 phiếu chờ lưu được sau khi có mạng ✓.

### 3.7 Phân quyền / Rules (emulator) — 17 case
PERM-03a..e đọc/query chéo shop: **deny** ✓ · PERM-04 create shopId B deny ✓ · PERM-05 đổi shopId / sửa product shop B deny ✓ · PERM-06 user không `allowViewSales` tạo sale deny ✓, xoá sale deny ✓, tạo repair allow ✓ · PERM-08 `shop_chats` deny (không rule) ✓ · PERM-12/13/14 status 5, giá âm deny ✓ · PERM-15/16 FAIL test (payload thiếu field bắt buộc `type`/`supplierId`) — rules yêu cầu `isEmployee()` ⇒ role `technician`/`user` **không thể** xác nhận phiếu nhập (transaction chạm `financial_activities`).

### 3.8 Multi-device — 4 case
MD-01 A tạo đơn sửa → B ✓ (~30s) · MD-01b A bán → B nhận `sales` ngay ✓ nhưng `products`/`payment_intents` **FAIL BUG-05** · MD-02 A thêm linh kiện/đổi status → B nhận `repairs` ✓, `repair_parts` không (BUG-05) · MD-04..10 chưa chạy.

### 3.9 Firestore Read Audit (đọc code + log)
- Mở app: listener `repairs`,`sales` cửa sổ 3 ngày (`[SYNC][FETCH] count=2 limit=20`), quét 30 bảng con trỏ; `payment_intents` sweep trọn (B: 25→158 doc) — 1 lần/24h.
- Danh sách/chi tiết đơn: SQLite only ✓ (0 read).
- Bán hàng: 1 callable `refreshMyClaims` + N `transaction.get` + N write mỗi đơn — `refreshMyClaims` **mỗi lần bán** là dư (claims hiếm đổi).
- Listener chat `snapshots()` thật; `other_apps_view`, `super_admin_console_view` snapshots trực tiếp.
- Không thấy listener trùng trong phiên test (subs khởi tạo 1 lần, `initSignature`).

## 4. TOP 10 LỖI NGUY HIỂM NHẤT
1. BUG-01 mất mạng không bán được (HIGH)
2. BUG-02 tạo đơn sửa treo vô hạn khi mất mạng (HIGH)
3. BUG-04 nhập kho treo khi mất mạng + nút LƯU TẠM còn mở (HIGH)
4. BUG-09 hoàn tiền trả hàng không có ledger (MEDIUM, tài chính)
5. BUG-05 máy 2 không thấy tồn kho/nợ khi app mở liên tục (MEDIUM, đa thiết bị)
6. BUG-06 Tài chính hiện thiếu phiếu thu (MEDIUM, sai số hiển thị)
7. BUG-07 snapshot linh kiện không có id cloud (MEDIUM, sai kho khi trùng tên)
8. BUG-08 snackbar treo che nút (MEDIUM, chặn thao tác)
9. BUG-03 SĐT không validate (MEDIUM, dữ liệu bẩn)
10. D-03 mỗi phiếu nhập CÔNG NỢ tạo doc `supplier_debts` mồ côi trên cloud (MEDIUM, dữ liệu rác/nhầm)

Root cause chung của #1–#3: **`FirestoreService`/`StockEntryService` không có timeout và không có nhánh offline khi phiên online mất mạng** — một fix chung (`.timeout` + rơi về hàng đợi) giải quyết cả 3.

## 5. PHẦN CHƯA TEST & LÝ DO
| Nhóm | Lý do |
|---|---|
| Kill app đúng lúc lưu/sync (TC-CR-01..07) | cần hook thời điểm; chỉ quan sát gián tiếp (BUG-02: repair `isSynced=0` không có queue) |
| Offline session (TC-SALE-13/14/15, INV-10/11, REP-08) | 2 máy đã chuyển sang phiên online để test đa thiết bị; nhóm này đã nghiệm thu B1/B2 ngày 19/09 (theo HANDOVER) |
| Trả góp NH, tất toán, đối soát tiền về (SALE-06/07, FIN-08) | chưa chạy máy; unit `installment_*` PASS |
| Nhập kho CÔNG NỢ / trả NCC (INV-06/07/08, DEBT-08) | chưa chạy máy; đã xác minh code ghi `debts` + `supplier_debts` song song (D-03) |
| Xoá đơn bán/sửa, đổi KTV, dịch vụ đối tác, bảo hành, xác máy | chưa chạy (ưu tiên nhóm tiền/offline) |
| Phân quyền UI theo role staff (PERM-01/02/11) | không có mật khẩu n@n.com; chỉ test rules server |
| Stress 100/500/1000 | chưa sinh dữ liệu (shop M ~30 dòng/bảng) |
| HR/Chấm công/Lương, Chat, AI, KiotViet, Backup, In ấn, Expansion | chỉ đọc code; không có thiết bị in/KiotViet |
| Firestore production (đếm doc thật) | client bị chặn truy vấn trực tiếp (theo HANDOVER); dùng SQLite máy B làm proxy cloud |

**Không tuyên bố "FULL TEST PASS".** 58 case có bằng chứng; phần còn lại BLOCKED/chưa chạy như bảng trên.

## 6. Dữ liệu test đã tạo trong shop M (để dọn nếu cần)
`repairs` rep_1789841723869_QA KH1 (đã giao, 1,5 Tr) · `customers` customer_1789841723998 (SĐT sai "QA KH1") · `sales` sale_1789842217606_KHÁCH VÃNG LAI (đã trả hàng sr_1789843452488824) · `debt_payments` 100k cho debt_1789750969342_1046796477 · `repair_parts` MANHINH95 5→4 · phiếu nhập chờ QA-PIN x20 (draft) · `stock_entries` draft trên cloud.
