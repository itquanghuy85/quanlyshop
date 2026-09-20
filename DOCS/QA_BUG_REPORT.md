# QA_BUG_REPORT — trạng thái sau đợt sửa nền tảng 2026-09-20

Chi tiết phát hiện gốc: `docs/FULL_TEST_REPORT_2026-09-19.md` §2. Root cause & phương án: `docs/QA_OFFLINE_SYNC_AUDIT.md` §3. Evidence sau sửa: `docs/QA_TEST_EXECUTION.md`.

| BUG | Sev | Trạng thái | Root cause | File/function đã sửa | Evidence |
|---|---|---|---|---|---|
| BUG-01 mất mạng không bán được | HIGH | **FIXED** | chỉ fallback khi PD; không gate mạng | `create_sale_view._processSale` (cloudReachable + `isOfflineError`), `firestore_service.executeSaleTransaction` (`_cw`) | RG-01/01b |
| BUG-02 tạo đơn sửa treo | HIGH | **FIXED** | `FirestoreService` 67 write không timeout | `cloud_write_policy.dart` (mới), `firestore_service._cw` (60 write), `customer_service` (qua FirestoreService), `repair_detail_view._pushRepairStatusToCloud` (gate), `getRepairDoc` timeout 8 s | RG-02/02b |
| BUG-04 nhập kho treo | HIGH | **FIXED** | `stock_entries` cloud-first, nhánh local chỉ phiên offline | `stock_entry_service` (`_cloudUnavailable`, `pushPendingLocalEntries`, create/update/cancel/get/list/confirm), `import_order_service`, `sync_orchestrator` (network restored), `sync_service.syncAllToCloud` (push) | RG-03/03b/03c |
| W2 ẩn: `syncAllToCloud` kẹt sau mất mạng | HIGH | **FIXED** | 30 `batch.commit` không timeout, `_isSyncingAllToCloud` kẹt | `sync_service._cwBg` + precheck mạng | RG-01b/03c (sync chạy lại sau mất mạng) |
| BUG-05 máy 2 không nhận tồn/nợ | MEDIUM | **FIXED** | không có cơ chế báo đổi cho 28 bảng | `sync_signal_service.dart` (mới), bump tại `firestore_service._cw`, `sync_orchestrator._processSyncItem`, `sync_service._cwBg` (chỉ batch có dữ liệu), `stock_entry_service`, `sales_return_service`; listen trong `sync_service.initRealTimeSync`, stop trong `cancelAllSubscriptions` | RG-04/04b |
| BUG-06 Tài chính thiếu phiếu thu | MEDIUM | **FIXED** | không emit tại nguồn; cache không map `payment_intents_changed` | `payment_intent_service.executePayment` (+`payment_intents_changed`, `debt_payments_changed`, `expenses_changed`), `finance_v2_cache.sectionsForEvent` | RG-05 |
| BUG-07 snapshot linh kiện không id cloud | MEDIUM | **FIXED** | writer chỉ ghi id cho `products`; unified list thiếu firestoreId của `repair_parts` | `part_used_detail_model` (+`partFirestoreId`, `source`), `repair_detail_view` (writer + `_partDetailByName` + 2 chỗ hoàn kho), `order_list_view._restorePartsToInventory`, `db_helper.getAllPartsUnified` (+firestoreId), `db_helper.restorePartQuantityByDetail` (+refactor `_restoreRepairPartRow`, `_restoreProductQuantityById`) | RG-09/09b; RG-09c BLOCKED |
| BUG-08 snackbar treo | MEDIUM | **FIXED** (termination path) | timer SnackBar không chạy khi route đổi | `notification_service._showInAppNotification` (+FCM snackbar): `clearSnackBars` + `Timer` đóng | RG-07 (1 lần quan sát) |
| BUG-09 hoàn tiền lệch 2 màn | MEDIUM | **FIXED** (trình bày gross) | FinanceV2 net vs Sổ quỹ gross; không thiếu ledger (sales_returns là sổ) | `finance_v2_data_service` (`refundOut`, `saleRevenueNet/saleCogsNet`), test scenario cập nhật | RG-06 |
| BUG-03 SĐT không validate | MEDIUM | **FIXED** | `_saveOrderProcess` không gọi validatePhone | `create_repair_order_view._saveOrderProcess` | RG-08 |
| D-03 orphan `supplier_debts`/`financial_activities` | MEDIUM | **FIXED** (không ghi nữa) | 2 write cloud-only trùng với ledger local | `stock_entry_service.confirmEntry` transaction | RG-10 static; device transaction BLOCKED |
| BUG-10 status ACTIVE/UNPAID | LOW | OPEN | 2 tên cùng nghĩa | — (cần migration dữ liệu + rà mọi truy vấn) | |
| L-01 payment_intents không trong onCreate | LOW | **FIXED** | tạo lười | `db_helper.onCreate` + `_ensurePaymentIntentsSchema` | DB-01 PASS |
| L-02 cash_closings.firestoreId không UNIQUE | LOW | OPEN | — | | |
| L-03 NULL shopId lọt getAllDebts | LOW | OPEN | | | |
| L-04 header Kho đếm sai / CUSAC trùng | LOW | OPEN | | | |
| L-05 đăng xuất rơi về offline không PIN | LOW | OPEN (thiết kế) | | | |
| L-06 thiếu storage.rules | LOW | OPEN | | | |
| D-01/02/04/05/06 code chết | INFO | OPEN | | | |

**Rủi ro còn lại:** (1) `SyncSignalService` ghi 1 doc `meta/sync_signal` mỗi lượt ghi cloud (gộp 1,5 s) — tăng ~1 write/lượt; (2) timeout 12 s với mạng có nhưng chập chờn chưa đo máy thật; (3) phiếu nhập trên đám mây khi mất mạng bị từ chối xác nhận (thông báo rõ) thay vì làm offline; (4) BUG-08 sửa bằng termination path, chưa xác định 100% nguyên nhân gốc trong Flutter.

## Lỗi mới phát hiện đợt 3 (2026-09-20 09:15–10:50)

| BUG | Sev | Trạng thái | Mô tả | Root cause | File | Evidence |
|---|---|---|---|---|---|---|
| NEW-02 | **MEDIUM** | OPEN — chờ quyết định | Sửa giá đơn sửa SAU KHI ĐÃ GIAO (500→600) không tạo bút toán chênh lệch (thu thêm / nợ / adjustment); phiếu thu vẫn 500, tab Tiền/Lãi cash-basis 500 ⇒ 100đ "khách còn thiếu" không xuất hiện ở đâu | dialog TÀI CHÍNH ĐƠN SỬA chỉ `upsertRepair(price)`; không gọi `PaymentIntentService`/`createDebtRecord`/`HistoryService` khi status=4 | `lib/views/repair_detail_view.dart` (dialog "Sửa" tài chính) | REP-20 09:44: `repairs.price=600`, `payment_intents` 500, `adjustment_entries` 0 |
| NEW-04 | MEDIUM | **FIXED** | Trả nợ NCC theo phiếu: máy B không nhận `import_orders.paidAmount` (0 vs 150k); mất mạng thì cloud không bao giờ nhận | write trực tiếp không guard/bump; upsert local `isSynced=1` bất kể cloud | `payment_intent_service.dart` `_syncImportOrderPaymentIfLinked`, `reconcileStaleImportOrderDebts` | INV-08 10:28 → retest 10:36 B=250k |
| D-1 | LOW | **FIXED** | Hoàn kho từ `DBHelper` (xoá đơn/đổi PT) không bump tín hiệu ⇒ B không nhận `repair_parts` tới khi resume | context `db_helper/restore` không phải tên collection | `db_helper.dart` 4 write; `cloud_write_policy.guard` tự bump | REP-21b 09:53 |
| NEW-03 | LOW | OPEN | Thứ tự ô Tên/SĐT ngược nhau giữa tạo đơn bán (Tên trái) và tạo đơn sửa (SĐT trái) ⇒ nhập nhầm, validate báo "SĐT 9–12 số" khó hiểu | UX | `create_sale_view.dart:2262`, `create_repair_order_view.dart` | 10:07 |
| NEW-01 | LOW | OPEN (quan sát 1/2) | B khoá màn hình lúc A cập nhật đơn; B mở lại thì listener realtime đưa bản cũ, chỉ đúng sau bấm đồng bộ tay | chưa rõ (cache Firestore + listener cửa sổ) | `sync_service.dart` `_liveWindowCollections` | 09:1x; tái hiện 09:22 không lặp |
| L-07 | LOW | OPEN (thiết kế) | Đăng xuất chủ shop trên máy nối bằng "Tải dữ liệu tài khoản về máy" ⇒ SQLite bị xoá (máy A nối bằng claim thì giữ) | `ownsShop` chỉ set ở luồng claim offline | `session_logout_service.dart` | 09:30 B |

Không phát hiện lỗi CRITICAL/HIGH mới. NEW-02 (MEDIUM, tài chính) dừng lại chờ quyết định theo yêu cầu.

## Đợt 4 (2026-09-20 12:50–13:30)

| BUG | Sev | Trạng thái | Mô tả | Root cause | File | Evidence |
|---|---|---|---|---|---|---|
| NEW-02 | MEDIUM | **FIXED** | Sửa giá đơn sửa đã giao ⇒ nợ chênh lệch 2 chiều, idempotent | — | `lib/services/repair_price_adjustment_service.dart` (mới), `repair_detail_view._editFinancials`, `finance_v2_data_service._linkedRevenueOf`, `db_helper` join `linkedDebtLinkedType` | đợt 4 A/B |
| **NEW-05** | **HIGH** | **OPEN — DỪNG CHỜ QUYẾT ĐỊNH** | Bán hàng khi mất mạng (đường local-first — cả phiên online mất mạng lẫn phiên offline) **không kiểm tồn**: bán 120 khi tồn 18 ⇒ `products.quantity = -102`, đơn 14,4 Tr được tạo, khi có mạng số âm được đẩy lên cloud và các máy khác. Trước fix BUG-01, đường này chỉ đi khi `permission-denied`/SP chưa có firestoreId; nay mọi lần mất mạng đều đi ⇒ mức độ phơi nhiễm tăng | `create_sale_view._processSale` nhánh `isLocalOnly` gọi `db.deductProductQuantity(p.id!, quantity)` thẳng, không so `quantity` với tồn local; UI ô số lượng cũng không giới hạn theo tồn | `lib/views/create_sale_view.dart` (~dòng 1540–1560 nhánh `isLocalOnly`), `db_helper.deductProductQuantity` | A 13:24: log `Deducted CAPLIGHTNING quantity by 120`, SQLite qty −102 |

**Đề xuất sửa NEW-05 (chờ duyệt):** (1) trước khi lưu local-first, kiểm `quantity ≤ tồn local` cho từng SP (điện thoại IMEI: `status == 1`), thiếu thì báo "Không đủ hàng (còn N)" và không lưu — cùng thông điệp với nhánh OUT_OF_STOCK online; (2) `deductProductQuantity` không cho âm (clamp 0 + log) như lưới an toàn; (3) ô số lượng giới hạn theo tồn (LOW, UX). Cần quyết định vì (1) thay đổi hành vi phiên offline (trước đây cho bán vượt tồn).

## Đợt 5 (2026-09-20 13:40–14:50)

| BUG | Sev | Trạng thái | Mô tả | Root cause | File | Evidence |
|---|---|---|---|---|---|---|
| NEW-05 | HIGH | **FIXED** (`9955ade7`) | Bán local-first không kiểm tồn ⇒ tồn âm | — | `lib/services/sale_stock_guard.dart` (mới), `create_sale_view` (kiểm tồn trước khi lưu local + kẹp ô số lượng), `db_helper.deductProductQuantity` (clamp ≥ 0) | đợt 5 A |
| NEW-06 | MEDIUM | **FIXED** | Mục `sync_queue` xoá doc chưa từng lên cloud (đơn tạo offline rồi xoá trước khi sync) ⇒ `permission-denied` retry mãi, header "Lỗi đồng bộ" kẹt vĩnh viễn | rules từ chối delete doc không tồn tại; `_handleDelete` coi là lỗi tạm | `sync_orchestrator._handleDelete` (permission-denied ⇒ bỏ qua, log) | A 14:36 |
| **NEW-08** | **HIGH** | **OPEN — DỪNG CHỜ QUYẾT ĐỊNH** | **Miễn nợ** (Công cụ điều chỉnh dữ liệu → CÔNG NỢ) chỉ xoá mềm SQLite, **không bao giờ lên cloud**: không enqueue/bump, và `syncAllToCloud` dùng `getAllDebts()` (lọc `deleted=0`) nên bỏ qua vĩnh viễn. Hệ quả: máy khác vẫn thấy nợ ACTIVE; khi máy khác thu/sửa khoản đó hoặc quét trọn 24h, `_upsert` (không có rào `isSynced=0`) ghi đè local ⇒ **nợ đã miễn sống lại** trên chính máy đã miễn | `DataReconciliationService.writeOffDebt` → `DBHelper.softDeleteDebt` (chỉ local) — các thao tác khác trong cùng service đều `SyncOrchestrator().enqueue(...)`; `sync_service.syncAllToCloud` debts bỏ qua row deleted | `lib/services/data_reconciliation_service.dart:~466`, `lib/services/sync_service.dart:~4967` | A 14:43 `debts#108 deleted=1 isSynced=0`; resume 14:45 "Synced 2 debts" = 78/79; B 14:47 vẫn ACTIVE |
| NEW-07 | MEDIUM | OPEN | Chủ shop **không có UI** để bật/tắt quyền xem giá vốn (`allowViewCostPrice`) cho từng nhân viên: sheet phân quyền của `staff_list_view` thiếu công tắc GIÁ VỐN (biến `_canViewCostPrice` được đọc/lưu nhưng không có widget); màn `staff_permissions_view` có công tắc nhưng mồ côi; knowledge base chỉ đường "Nhân viên → chọn nhân viên → Phân quyền" | widget bị bỏ khi gộp sheet | `lib/views/staff_list_view.dart` (~1169/1215/1883), `lib/views/staff_permissions_view.dart` | A 14:27 |
| L-08 | LOW | OPEN | Phiếu kiểm kho (`inventory_checks`) chỉ lưu local, `firestoreId NULL`, không có đường đẩy cloud | chưa có sync cho bảng | `inventory_check_view`, `sync_service` | A 14:15 |
| D-07 | LOW | OPEN | `PurchaseOrderListView` (đơn đặt hàng NCC) không có lối vào từ menu Kho, chỉ qua Nhắc việc | điều hướng | `reminders_view.dart:490` | 14:24 |
| L-09 | LOW | OPEN | Đẩy debts sau thanh toán (`sync_service` ~3590) không đánh dấu `isSynced=1` ⇒ ghi lại cloud mỗi lần thanh toán cho tới khi `syncAllToCloud` chạy (thừa write, không sai dữ liệu) | thiếu mark | `lib/services/sync_service.dart:~3590` | log "Synced 2 debts" ×2 14:38 |

**Đề xuất sửa NEW-08 (chờ duyệt):** (1) `writeOffDebt` enqueue `SyncOrchestrator` operation update/delete (`deleted:true`) như các thao tác khác trong `DataReconciliationService` — đi qua CloudWritePolicy + SyncSignal sẵn có; (2) `syncAllToCloud` phần debts lấy cả row `deleted=1 AND isSynced=0` (đẩy `deleted:true` lên cloud) để quét lại các khoản đã miễn trước đây; (3) (tuỳ chọn, rộng hơn) rào `_upsert` không ghi đè row local `isSynced=0` — ảnh hưởng mọi bảng, cần cân nhắc riêng. Không cần sửa dữ liệu: nợ 108 test sẽ được đẩy sau khi sửa (2).

## Đợt 6 (2026-09-20 15:00–18:30)

| BUG | Sev | Trạng thái | Mô tả | Root cause | File | Evidence |
|---|---|---|---|---|---|---|
| NEW-08 | HIGH | **FIXED** (`568c1214`) | Miễn nợ / xoá mềm nợ không lên cloud | — | `data_reconciliation_service.writeOffDebt` (+ nợ kèm khi xoá đơn sửa) enqueue `SyncOrchestrator` delete; `sync_service.syncAllToCloud` lấy thêm `DBHelper.getUnsyncedDeletedDebts()` (deleted=1 & isSynced=0 & có firestoreId), `deleted` ép bool | đợt 6 A; `test/debt_write_off_sync_test.dart` |
| NEW-10 | MEDIUM | **FIXED** (`36575a41`) | Chốt quỹ / số dư đầu kỳ / sửa chốt quỹ ghi thẳng Firestore không qua CloudWritePolicy ⇒ không timeout (treo khi mất mạng), không báo máy khác ⇒ máy B không biết ngày đã chốt, vẫn bán được tới lần poll sau | 3 write trực tiếp trong view | `lib/views/cash_closing_view.dart` (3 site → `CloudWritePolicy.guard(context: 'cash_closings')`) | SALE-23b / NEW-10-D |
| NEW-09 | MEDIUM | OPEN | App bị kill **trong lúc** `executeSaleTransaction` đang chờ cloud: transaction đã commit (đơn + tồn) nhưng các bước sau (phiếu thu `SALE_PAYMENT`, bump `products`, ghi SQLite) mất ⇒ đơn có, tồn trừ, **không có phiếu thu ⇒ tab Tiền thiếu tiền**; máy khác chậm tồn tới lần poll. Cửa sổ ~1 s, cần OS kill đúng lúc | phiếu thu tạo ở client sau transaction, không nằm trong transaction; không có bước đối chiếu "đơn không có phiếu thu" khi mở lại | `create_sale_view._processSale` (sau `executeSaleTransaction`), `firestore_service.executeSaleTransaction` | CR-01b: `sale_1789893142913` 200k, `payment_intents` 0 |
| D-08 | MEDIUM | OPEN | Còn **7 write Firestore trực tiếp ở tầng view** chưa qua CloudWritePolicy (cùng gốc NEW-10): `repair_detail_view.dart:2625,2723` (qty linh kiện sau sửa PT), `sale_list_view.dart:2180` & `order_list_view.dart:1232` (sửa tên/SĐT), `sale_detail_view.dart:1682` (hoàn tồn), `parts_inventory_view.dart:1877` (nhập PT), `expense_view.dart:541` (xoá chi); + 3 ở `super_admin_console_view`, 1 `printer_settings_view`, 1 `shop_switcher_widget` (cấu hình, ít rủi ro). Hệ quả: treo khi mất mạng (không timeout), máy khác không được báo (products/repair_parts/expenses không có listener) | ghi thẳng `FirebaseFirestore.instance…update/set` trong view | các file trên | grep 18:17 — chưa có bằng chứng máy thật từng site, chưa sửa (ngoài phạm vi duyệt) |

**Đề xuất NEW-09:** đưa việc tạo phiếu thu vào **cùng transaction** cloud (ghi doc `payment_intents` trong `executeSaleTransaction`) hoặc thêm bước tự đối chiếu khi mở app: đơn bán TIỀN MẶT/CK không có `payment_intents` ⇒ tạo bù. Cần quyết định vì đụng `executeSaleTransaction` (đường tiền chính).
**Đề xuất D-08:** bọc 7 site nghiệp vụ bằng `CloudWritePolicy.guard(context: '<collection>')` như NEW-10 (mỗi site đã có try/catch, local đã ghi trước). ~30 phút, cần test lại 2 máy từng luồng.
