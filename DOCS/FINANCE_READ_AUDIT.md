# FINANCE_READ_AUDIT — Kiểm toán đọc Firestore module Tài chính

**Ngày:** 2026-09-18  
**Phạm vi:** `lib/finance_v2/*`, `lib/views/cash_closing_view.dart`, các service tài chính liên quan.  
**Mục tiêu:** UI Tài chính đọc SQLite/memory là chính; Firestore chỉ để sync.

---

## 1. TRƯỚC refactor

| # | File · Function | Collection | Operation | Reads ước tính / lần | Trigger | Cache | Local alternative |
|---|---|---|---|---|---|---|---|
| 1 | `finance_v2_data_service.loadSnapshot()` | — (SQLite) | ~22 query SQLite song song | 0 Firestore | `_load()` của FinanceV2View: initState, MỌI event `*_changed` / `financialChanged` / `syncComplete`, quay về từ màn con | **Không** | Đã là local |
| 2 | `cash_closing_view._loadAllDataFromFirestore()` | `repairs`, `expenses`, `debt_payments`, `supplier_payments`, `repair_partner_payments`, `debts`, `sales_returns`, `sales` ×2, `supplier_import_history`, `cash_closings` | `get()` ×11 (bound `updatedAt ≥ đầu kỳ` / `soldAt` / `date`) | Shop thật: **50–400 doc/lần** (kỳ 1 ngày); shop nhiều ngày chưa chốt quỹ: hàng trăm–nghìn | **Mỗi `initState` của CashClosingView** = mỗi lần vào Tài chính rồi vuốt tới tab Chốt quỹ | **Không** (đọc lại mỗi mount) | SQLite đã có đủ (SyncService sync real-time các bảng này) |
| 3 | `cash_closing_view._loadHistoryClosings()` | `cash_closings` | `get()` limit 365 | **≤365 doc/lần** | `initState` + mỗi event `cash_closings_changed` + pull-to-refresh | Không | `db.getAllCashClosings()` (đã sync real-time) |
| 4 | `cash_closing_view` (dòng ~2306, 4021, 4483) | `cash_closings` | `set/update` khi chốt / sửa chốt / đặt số dư đầu kỳ | write | Hành động người dùng | — | Bắt buộc (ghi cloud) |
| 5 | `finance_v2_daily_report_view._loadAttendanceSummary()` | `users`, `shift_swap_requests` | `get()` ×2 | ~5–15 doc | Mở màn Báo cáo ngày (drill-down) | Không | `users` có thể lấy từ local staff cache — chưa đổi (ngoài phạm vi, chi phí nhỏ) |
| 6 | `CashBalanceCacheService` | `shops/{id}/meta` | `set` | write | Sau khi tải Chốt quỹ (đồng bộ mốc "Còn lại") | — | Bắt buộc (cho thông báo) |

**Listener realtime trong module Tài chính:** 0 `snapshots()` trực tiếp. Cả `FinanceV2View` lẫn `CashClosingView` chỉ nghe `EventBus` (do `SyncService` phát sau khi ghi SQLite). ✅ Không duplicate listener.

**N+1:** không có — `loadSnapshot` tra tên/ảnh/SĐT khách, NCC, đối tác bằng 3 map dựng một lần từ 3 query bảng (`getCustomers/getSuppliers/getRepairPartners`).

---

## 2. SAU refactor

| # | File · Function | Collection | Operation | Reads / lần | Caller |
|---|---|---|---|---|---|
| 1 | `loadSnapshot()` | SQLite | ~22 query, **đi qua `FinanceV2Cache`** | 0 Firestore; SQLite chỉ khi cache miss/bẩn | `_load()` (debounce 300ms, gộp yêu cầu trùng, không xếp hàng nhiều lần) |
| 2 | `_loadAllDataFromFirestore()` | như trên | `get()` ×11 | **0 nếu đã quét `shopId|ngày` trong 10 phút** (`_cloudSweepTtl`); pull-to-refresh ép quét | `_loadAllData({forceCloud})` |
| 3 | `_loadHistoryClosings()` | `cash_closings` | **local trước**; Firestore chỉ khi local trống hoặc pull-to-refresh | 0 (bình thường) | `_refreshHistory({forceCloud})` |
| 4–6 | không đổi | | | | |

---

## 3. `get()` đã loại bỏ / gate

- `_loadAllDataFromFirestore()` — từ *mỗi lần mount* → *tối đa 1 lần / 10 phút / (shop, ngày)*; ước tính giảm **80–95 %** read của tab Chốt quỹ trong một phiên dùng bình thường (vào-ra Tài chính nhiều lần).
- `_loadHistoryClosings()` — từ *mỗi mount + mỗi event* → *chỉ khi local trống / kéo làm mới*: **−365 read/lần mở**.

## 4. Listener đã loại bỏ

- Không có listener nào phải bỏ (module vốn không dùng `snapshots()`); giữ nguyên mô hình `SyncService → SQLite → EventBus`.

## 5. Query chuyển sang SQLite

- Lịch sử chốt quỹ (`cash_closings`) → `db.getAllCashClosings()`.
- `debts` cho snapshot: `getDebtsForFinanceSnapshot()` (toàn bảng) → `getOutstandingDebtsForFinanceSnapshot()` (lọc `total − paid > 0` ngay ở SQL; tập kết quả giống hệt vì hai vòng lặp trong `loadSnapshot` vốn `continue` khi `remaining <= 0`).

## 6. Dữ liệu được cache (`FinanceV2Cache`, key = `shopId|start|end|prevStart|prevEnd`)

- Toàn bộ `FinanceV2Snapshot` (summary tiền, lãi, nợ, danh sách giao dịch, bucket theo ngày/tháng). TTL 60 s là lưới an toàn; **nguồn invalidate chính là sự kiện nghiệp vụ** (`FinanceV2Cache.sectionsForEvent`):
  - Ghi thu / chi / bán / sửa / nhập kho → bẩn `cash + profit + transactions`, **không** bẩn `debt`.
  - Thu/trả nợ → bẩn `cash + debt + transactions`, **không** bẩn `profit`.
  - Sửa nợ → chỉ `debt`.
  - `financial_changed` / `SYNC_COMPLETE` / đổi shop → toàn bộ (đổi shop `clear()` hẳn).
- Tab đang mở không thuộc mảng bị bẩn thì **giữ nguyên số đang hiện**, chuyển sang tab bị ảnh hưởng mới tải lại.
- Đổi bộ lọc Tất cả/Thu/Chi/Khác/🔍, đổi bên Phải thu/Phải trả, lật trang: **thuần lọc list trong bộ nhớ**, 0 query.

## 7. Trường hợp vẫn bắt buộc đọc Firestore

- Lần đầu mở Chốt quỹ cho một (shop, ngày) trong 10 phút — đối chiếu chéo thiết bị trước khi chốt (giữ vì đây là nghiệp vụ tiền thật; có thể hạ TTL/bỏ hẳn sau khi đo thêm).
- Kéo-để-làm-mới ở tab Chốt quỹ / Lịch sử chốt.
- Ghi chốt quỹ / sửa chốt / số dư đầu kỳ (write).
- Báo cáo ngày: `users` + `shift_swap_requests` (chấm công, nhỏ, chỉ khi mở màn).

## 8. Nguy cơ N+1 (đã rà)

- `_debtGroupRow`: dùng `FinanceV2DebtItem.avatarUrl/phone` đã gắn sẵn ✅.
- `_txRow`: dùng `customerName/itemName/paymentMethod` trong `FinanceV2Txn` ✅; chi tiết (`getRepairByFirestoreId`, `getSaleByFirestoreId`) chỉ khi **bấm mở** một giao dịch.
- `_showDebtGroupDetail` → `getDebtPayments(debtId)` chỉ khi bấm "Lịch sử trả".

## 9. Nguy cơ duplicate listener (đã rà)

- `FinanceV2View._eventSub` và `CashClosingView._eventBusSub`: mỗi State đúng 1 subscription, huỷ trong `dispose()`. Hai State cùng nghe EventBus là cố ý (Chốt quỹ tự quản dữ liệu riêng); cả hai đều debounce (300/500 ms) và cùng đọc SQLite, không đọc cloud khi nhận event (trừ `_refreshHistory` trước đây — đã chuyển local).
- Trang con Thu/Chi/Lịch sử đẩy từ tab Chốt quỹ dùng lại State cha (`_pushEmbeddedPage` + `_rebuildTick`), **không** tạo `CashClosingView` mới ⇒ không nhân đôi subscription/quét cloud.

---

## Kịch bản test (PHẦN 15)

| Test | Kỳ vọng sau refactor | Cách kiểm |
|---|---|---|
| T1 mở app → Tài chính → Tiền | 0 read Firestore (chỉ SQLite) | Log `FirestoreAuditModule` / Firebase RW stats |
| T2 Tiền → Lãi → Nợ → Chốt quỹ → Tiền | Tiền/Lãi/Nợ: 0 query (cache hit, log `FinanceV2Cache.hits`); Chốt quỹ: quét cloud 1 lần (lần đầu), lần sau trong 10 phút: 0 |
| T3 Tất cả → Thu → Chi → Khác → Tất cả | 0 query (lọc bộ nhớ) |
| T4/T5 Ghi thu / Ghi chi | EventBus `expenses_changed` → bẩn cash/profit/tx → `_load()` đọc SQLite; tab Nợ giữ nguyên |
| T6 Thanh toán nợ | bẩn cash/debt/tx; **profit không đổi** |
| T7 Chốt quỹ | ghi local + cloud như cũ; `cash_closings_changed` → lịch sử đọc local |
| T8 Thoát Tài chính rồi vào lại (< 60 s) | cache hit, không chạy 22 query |
| T9 Offline | mọi tab đọc SQLite; Chốt quỹ: quét cloud timeout 10 s rơi về local (như cũ) |

**Trạng thái nghiệm thu máy thật:** T1–T8 đã chạy 2026-09-18 (Oppo CPH2203 shop M) — xem `DOCS/CHANGELOG.md` `[2026-09-18b]` (read) và `[2026-09-18c]` (số liệu mọi hình thức thanh toán, 2 máy). T9 offline chưa chạy.
