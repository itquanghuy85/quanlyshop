# QA_OFFLINE_SYNC_AUDIT — Write path & chính sách offline chung (2026-09-20)

## 1. Bảng WRITE PATH (đọc từ code, trước khi sửa)

Ký hiệu: TO = timeout · Q = hàng đợi (`sync_queue` / quét `isSynced=0`) · IDEM = idempotent · PD = permission-denied.

| # | Write path | Module | Collection | Local table | ONLINE | OFFLINE (phiên online, mất mạng) | TO | Retry | IDEM | Q | UI state | Error handling |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| W1 | `SyncOrchestrator._handleCreate/_handleUpdate/_handleDelete` | Sync | 12 loại entity | tất cả | set(merge) docId cố định | `_syncAllOnce` kiểm `Connectivity` → `noNetwork`, giữ item | 25s `_withCloudWriteTimeout` | backoff 2s→5ph, max 3, PD = failed vĩnh viễn | ✓ docId cố định | ✓ | badge sync | phân loại PD vs khác ✓ |
| W2 | `SyncService.syncAllToCloud` (30 `batch.commit`) | Sync | 25 bảng | quét `isSynced=0` | batch set(merge) | **KHÔNG kiểm mạng; commit treo ⇒ `_isSyncingAllToCloud=true` mãi ⇒ mọi lượt sau bị skip tới khi restart** | ✗ | cooldown | ✓ | ✓(quét) | — | try/catch chung |
| W3 | `FirestoreService.*` 39 write (addCustomer, addRepair, upsertRepairPatch…, sendChat, addSupplier…) | Nhiều | 25 | tuỳ hàm | set/update/add | **treo vô hạn** (SDK persistence chờ ack) | ✗ | ✗ | set docId ✓ / `.add` ✗ | gián tiếp (isSynced=0) | caller await ⇒ **treo UI** | try/catch → null/false (không phân loại) |
| W4 | `FirestoreService.executeSaleTransaction` | Bán | sales, products, debts | sales, products, debts | runTransaction atomic | fail nhanh `unavailable` → `create_sale_view` chỉ fallback khi PD ⇒ **báo lỗi, mất đơn** | ✗ | ✗ | ✓ docId | ✗ (đường local-only có: `isSynced=false`) | `_isSaving` ✓ | thiếu nhánh unavailable/timeout |
| W5 | `StockEntryService.createEntry/updateEntry/confirmEntry` | Kho | stock_entries, products, repair_parts, supplier_import_history, financial_activities, supplier_debts | (không có bảng `stock_entries`), products, repair_parts, import_orders, expenses, debts, financial_activity_log | `.add` + runTransaction | **treo** (`.add` chờ ack); nhánh local chỉ khi `AppSession.isOffline` | ✗ | ✗ | `.add` auto-id ✗ | `OfflineStockEntryStore` chỉ phiên offline | `_isSaving` (smart_stock_in) | try/catch → `_showError` |
| W6 | `CustomerService.addCustomer/updateCustomer` | KH | customers | customers | insert local → W3 | treo (W3) | ✗ | ✗ | docId `customer_<ts>` ✓ | quét isSynced=0 ✓ | caller (tạo đơn sửa) treo | — |
| W7 | `SalesReturnService.processReturn` → `_reduceDebt` | Bán | sales_returns, sales_return_items, debts(update trực tiếp) | sales_returns, items, products, debts | set + `debts.update` | treo ở `debts.update` | ✗ | ✗ | ✓ | ✓ | `_activeReturnLocks` ✓ | — |
| W8 | `PaymentIntentService.executePaymentDirect` | Tiền | (qua W1/W2) | payment_intents, debt_payments, debts, expenses, import_orders | local commit → enqueue | ✓ local-first | n/a | W1 | ✓ idempotencyKey | ✓ | caller | ✓ |
| W9 | `RepairPartnerService`, `SupplierService`, `AuditService`, `FinancialActivityService` | Phụ | repair_partners, suppliers, audit_logs, financial_activity_log | cùng tên | local + W3 | treo (W3) | ✗ | ✗ | ✓ | quét | — | — |
| W10 | `ChatService`, `NotificationService`, `PaymentRequestService`, `ShiftSwap`, `AttendanceApproval` | Phụ | chats, notifications, payment_requests, attendance/* | — | trực tiếp | treo nếu await | ✗ | ✗ | mixed | ✗ | — | — |

Kết luận Phase 1: hạ tầng hàng đợi (W1) ĐÃ đúng chính sách (timeout, phân loại PD, backoff, idempotent). Lỗi nền tảng là **W2–W7 đi vòng qua hàng đợi bằng write trực tiếp không timeout, không gate mạng**, và nhánh local chỉ tồn tại cho `AppSession.isOffline` chứ không cho "phiên online mất mạng".

## 2. Chính sách offline chung (Phase 2) — `CloudWritePolicy`

File: `lib/services/cloud_write_policy.dart` (một nơi duy nhất).

1. **Gate mạng trước khi bắt đầu write trực tiếp**: `Connectivity.checkConnectivity()==none` ⇒ ném `CloudOfflineException` NGAY (0 ms), KHÔNG khởi động write (tránh SDK persistence ghi lại sau ⇒ trùng với hàng đợi).
2. **Mọi write trực tiếp có timeout**: tương tác 12 s (`interactive`), nền 25 s (`background`, = SyncOrchestrator). Lý do 12 s: ack Firestore online thường < 2 s; 3G chậm < 8 s; người dùng chờ tối đa 12 s rồi được trả lời "đã lưu trên máy".
3. **Phân loại lỗi**: `unavailable` / `deadline-exceeded` / `network-request-failed` / `TimeoutException` / `SocketException` ⇒ **OFFLINE** (local commit + queue + UI trạng thái offline). `permission-denied` / `invalid-argument` / `failed-precondition` / `not-found` ⇒ **PERMANENT** (báo lỗi, không queue vô hạn; hàng đợi đánh dấu failed như W1 đã làm).
4. Write trực tiếp trong nghiệp vụ phải dùng **docId cố định** (`set(merge)`) để retry/replay idempotent; `.add()` auto-id chỉ cho dữ liệu không nghiệp vụ (chat/notification).
5. Local SQLite commit TRƯỚC cloud ở mọi nghiệp vụ hỗ trợ offline; `isSynced=1` CHỈ sau khi cloud xác nhận (giữ nguyên quy tắc hiện có).
6. Hàng đợi: `sync_queue` (entityType, entityId, firestoreId, operation, data, createdAt, retryCount, lastError, status) + quét `isSynced=0` của `syncAllToCloud` — đã có, không tạo cơ chế mới. `stock_entries` dùng `OfflineStockEntryStore` (prefs JSON, id `se_…` cố định) làm hàng đợi cho CẢ 2 chế độ phiên, đẩy lên bằng `StockEntryService.pushPendingLocalEntries()` khi có mạng.
7. Tín hiệu liên máy: `SyncSignalService` — 1 doc `shops/{shopId}/meta/sync_signal`, người ghi bump `{tables:{col:ts}, by:deviceId}` sau mỗi lần ghi cloud thành công; máy khác nghe 1 listener duy nhất và gọi `SyncService.refreshCollectionNow(col)` (truy vấn con trỏ tăng dần, chỉ doc đổi). Không thêm listener theo bảng, không poll.

## 3. Root cause & phương án từng nhóm (Phase 11 — nêu trước khi sửa)

### Nhóm A — BUG-01/02/04 (+ W2 ẩn)
- **Root cause**: W3/W4/W5 không gate mạng, không timeout; nhánh local chỉ theo `AppSession.isOffline`; `create_sale_view` chỉ fallback khi PD.
- **File/function**: `firestore_service.dart` (39 write), `sync_service.dart` (`syncAllToCloud` 30 commit), `stock_entry_service.dart` (`createEntry/updateEntry/deleteEntry/getEntry/getPendingEntries/confirmEntry`), `create_sale_view._processSale`, `sales_return_service._reduceDebt`.
- **Impact**: treo UI vô hạn, mất đơn bán khi mất mạng, `syncAllToCloud` chết lặng sau 1 lần mất mạng giữa chừng.
- **Phương án**: bọc mọi write trực tiếp bằng `CloudWritePolicy.guard` (gate + timeout + phân loại); `create_sale_view`: mất mạng ⇒ đi thẳng local-first (bỏ `refreshMyClaims`), lỗi OFFLINE ⇒ local-first tự động (không hỏi); `StockEntryService`: chọn kho local khi `isOffline || !online`, hợp nhất danh sách chờ, `confirmEntry` cho phiếu local dùng `_confirmEntryOffline`, phiếu cloud khi mất mạng ⇒ báo rõ (không treo), `pushPendingLocalEntries` khi có mạng (từ `syncAllToCloud` + orchestrator network-restored); `createEntry` dùng docId cố định.
- **Risk regression**: hàm FirestoreService trả null/false nhanh hơn khi mất mạng — caller đã xử lý null (giữ isSynced=0). `.timeout` trên `runTransaction`: SDK có thể vẫn hoàn tất sau timeout (hiếm, do gate mạng chặn trước) ⇒ docId cố định nên trùng vô hại.

### Nhóm B — BUG-05 (liên máy)
- **Root cause**: chỉ `repairs`,`sales` có listener; 28 bảng còn lại chỉ refresh khi resume/manual (`refreshCloudCollections` callers); không có cơ chế báo "có thay đổi".
- **Phương án**: `SyncSignalService` (mục 2.7). Bump tại 3 phễu ghi cloud: `SyncOrchestrator._processSyncItem` thành công, `SyncService.syncAllToCloud` sau mỗi batch, `FirestoreService._cw` (write trực tiếp) + `executeSaleTransaction` + `StockEntryService.confirmEntry`. Debounce 1,5 s; bỏ qua tín hiệu của chính máy mình.
- **Read impact**: +1 write/bump (gộp), +1 read/bump trên mỗi máy khác + 1 truy vấn con trỏ/bảng đổi. So với hiện tại (resume = ~30 truy vấn) là rẻ hơn và nhanh hơn.

### Nhóm C — BUG-06 (invalidation tài chính)
- **Root cause**: `PaymentIntentService.executePayment` không phát sự kiện; caller chỉ emit `debts_changed`; `FinanceV2Cache.sectionsForEvent('payment_intents_changed')` = ∅.
- **Phương án**: `executePayment` thành công ⇒ emit `payment_intents_changed` + (`debt_payments_changed` nếu ghi phiếu nợ) + (`expenses_changed` nếu ghi chi) — tại nguồn; `FinanceV2Cache`: `payment_intents_changed` → {cash, transactions, debt}. Mọi màn đang nghe các event này (cash_closing, home, finance) tự cập nhật.

### Nhóm D — BUG-07 (snapshot linh kiện)
- **Root cause**: `repair_detail_view:2540` chỉ ghi id khi `source=='products'`; `PartUsedDetail` không có khoá cho `repair_parts`.
- **Phương án**: thêm `partFirestoreId` + `source` vào `PartUsedDetail` (JSON schemaless trong `repairs.partsUsedDetailed`, không đụng rules/migration; đơn cũ không có field ⇒ fallback tên như cũ). Hoàn kho ưu tiên khoá cloud: `DBHelper.restorePartQuantityByDetail`.

### Nhóm E — BUG-09 (hoàn tiền)
- **Root cause**: thiết kế "trả hàng không tạo bút toán riêng" (`sales_return_service.dart:181`), `sales_returns` là sổ hoàn tiền; FinanceV2 **trừ vào Tiền vào** (net) còn Sổ quỹ **cộng vào Chi** (gross) ⇒ 2 màn khác nhau. Không thiếu ledger; thiếu **nhất quán trình bày** và bộ lọc "Thu" đang bật giấu dòng REFUND.
- **Phương án**: trong `FinanceV2DataService`: tách `saleCashIn` (gross) cho dòng tiền và `saleIn` (net) cho lãi; hoàn tiền vào `refundOut` cộng `totalOut` ⇒ Tiền vào 1,72 / Tiền ra 0,12 / Còn lại 1,6 = Sổ quỹ. Không sửa số ở UI, không tạo intent (tránh đếm 2 lần với engine).
- **Risk**: `finance_full_scenario_test`/`comprehensive_financial_test` có thể assert net ⇒ chạy lại và đọc kỳ vọng.

### Nhóm F — D-03 (orphan cloud)
- **Root cause**: `StockEntryService` confirm-transaction ghi `financial_activities` + `supplier_debts` (không bảng local, không ai đọc) song song với `_writeLocalFinancialRecords` (debts + financial_activity_log ⇒ sync). 
- **Phương án**: bỏ 2 write mồ côi khỏi transaction; giữ rules cũ (không xoá collection). Idempotency confirm: đã có `status=='draft'` check trong transaction.

### Nhóm G — BUG-08 (snackbar)
- **Root cause (dự kiến, Flutter #93999)**: SnackBar qua `messengerKey` gốc; route đổi trong lúc animation vào ⇒ không tới `completed` ⇒ timer không chạy.
- **Phương án**: `_showInAppNotification` — `clearSnackBars()` trước khi show + `Timer(duration+1s)` gọi `hideCurrentSnackBar` (termination path bắt buộc), áp dụng cho helper global.

### Nhóm H — BUG-03
- **Phương án**: `create_repair_order_view._saveOrderProcess`: nếu SĐT không rỗng ⇒ `UserService.validatePhone` (9–12 số sau làm sạch), báo lỗi và dừng; khách vãng lai không SĐT vẫn cho phép; không đụng dữ liệu cũ.
