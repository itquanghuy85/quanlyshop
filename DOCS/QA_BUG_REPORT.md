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
