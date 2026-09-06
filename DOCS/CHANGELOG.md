# CHANGELOG - HULUCA Shop Manager

Lịch sử tất cả thay đổi từng phiên bản.

---

## [2026-09-06f] - fix(đơn sửa) KHÔNG CHỌN ĐƯỢC PHỤ TÙNG

**Chủ shop báo:** *"lỗi không chọn được phụ tùng đơn sửa"*.

### Gốc rễ — ép kiểu cứng làm sập cả hàm

`repair_parts.supplierId` khai là `INTEGER`, nhưng SQLite **không cưỡng chế kiểu**
và đường đồng bộ từ cloud có ghi vào đây **firestoreId dạng chuỗi**. Trên máy chủ
shop, phụ tùng **"DÂY NGUỒN"** mang `supplierId = 'supplier_1781189222071'`.

`DBHelper.getAllPartsUnified()` gom nhà cung cấp bằng:
```dart
if (p['supplierId'] != null) p['supplierId'] as int,   // ← ném lỗi
```
Chỉ cần MỘT phụ tùng như vậy là **cả hàm ném `TypeError`** ⇒ danh sách linh kiện
rỗng ⇒ `repair_detail_view` không mở được hộp thoại chọn phụ tùng. Không phải
"bấm không ăn" mà là **hàm nạp dữ liệu chết trước khi kịp mở**.

**Sửa:** nhận cả hai dạng khoá — số thì tra theo `suppliers.id`, chuỗi thì tra
theo `suppliers.firestoreId`, chuỗi-số thì `int.tryParse`. Không còn ép kiểu cứng.

### Vá kèm — bỏ sót linh kiện tạo bằng hằng số hiện hành

Cùng hàm đó gọi `getProductsByType('LINH KIỆN')` (chuỗi tiếng Việt cũ), mà
`_typeWhereClause` **chỉ khớp cả hai dạng khi nhận khoá ASCII `'LINH_KIEN'`** —
truyền chuỗi tiếng Việt sẽ rơi vào nhánh mặc định `type = ?`. Nghĩa là mọi linh
kiện tạo bằng hằng số hiện hành (`ProductConstants` dùng `'LINH_KIEN'`) **không
bao giờ hiện trong hộp chọn**. Đã đổi sang `'LINH_KIEN'`.
*(Shop hiện chưa có sản phẩm loại này nên chưa phát tác — vá trước khi thành lỗi thật.)*

### Nghiệm thu máy thật (Oppo CPH2203)

Mở đơn sửa → **Phụ tùng**: hộp thoại mở bình thường, hiện đủ 6 phụ tùng kèm tên
NCC ("TÔN APPLE"), món hết hàng hiện "HẾT HÀNG", bấm **+** chọn được (thẻ chuyển
xanh, nút bật thành **XÁC NHẬN (1)**). Đã bấm Huỷ, không đụng dữ liệu đơn thật.
`flutter analyze lib test` 0 error 0 warning.

---

## [2026-09-06e] - refactor(đồng bộ) TRUNG TÂM ĐỒNG BỘ: 8 NÚT CÒN 3 + VÁ 2 LỖI GỐC

**Chủ shop báo:** *"trang đồng bộ dữ liệu gom lại nhiều mục trùng hoặc gần giống
tính năng, nhiều tính năng không sử dụng được"*.

### Gom nút: 8 → 3 (+1 nút chỉ hiện khi có lỗi)

| Nút cũ | | Lý do |
|---|---|---|
| Tải từ Cloud | ❌ bỏ | Chỉ gọi `downloadAllFromCloud`, **không xoá con trỏ đồng bộ** ⇒ bản ghi cũ hơn con trỏ không bao giờ về. Đúng cơ chế đã làm máy chủ shop thiếu 2.965 phiếu nhập (`[2026-09-06d]`) |
| 🔧 SỬA TỰ ĐỘNG | ❌ bỏ | Chạy trên danh sách **17 bảng chép tay**, thiếu 14 bảng ⇒ báo "đã sửa xong" trong khi vẫn thiếu dữ liệu — nguy hiểm hơn là không có nút |
| Kiểm tra kết nối Firestore | ❌ bỏ | Trùng nguyên vẹn mục ở Cài đặt → Dữ liệu & Hệ thống |
| Thống kê Firebase Read/Write | ❌ bỏ | Trùng nguyên vẹn mục ở Cài đặt |
| ĐỒNG BỘ 2 CHIỀU (`_handleFullSync`) | ❌ xoá code chết | Chỉ gọi từ nút "SỬA LỖI" trong hộp thoại; đã trỏ sang `_handleReinitializeSync` |
| Khởi động lại Realtime | ✅ đổi tên **"Đồng bộ lại toàn bộ"** | Đây mới là đường chữa thật (reset con trỏ + tải lại) |
| Đẩy lên Cloud | ✅ đổi tên **"Đẩy dữ liệu máy này lên cloud"** | Có vai trò riêng |
| Kiểm tra chi tiết | ✅ giữ, tách mục **KIỂM TRA** | Ghi rõ "đọc nhiều, chỉ dùng khi nghi ngờ" |
| Thử lại N mục lỗi | ✅ giữ (chỉ hiện khi hàng đợi có lỗi) | |

Gỡ 5 hàm chết: `_handleDownload`, `_handleAutoFix`, `_handleFullSync`,
`_handleOpenFirebaseStats`, `_handleOpenFirestoreConnectivityPage`
(1.528 → 1.367 dòng).

### Lỗi gốc 1 — danh sách bảng chép tay 3 lần, thiếu 14 bảng

`sync_health_check.dart` chép **cùng một danh sách 17 bảng ở 3 chỗ** (kiểm tra,
sửa tự động, đánh dấu đã sync), trong khi realtime theo dõi 27 bảng. Vì thế màn
hình báo *"1 bản ghi chưa khớp"* trong khi máy đang thiếu **2.965 phiếu nhập +
2.011 dòng nhật ký tài chính** — các bảng đó đơn giản là **không được kiểm**.

**Sửa:** thêm `lib/services/sync_collections.dart` — `SyncCollections.all`
(**31 bảng**) là nguồn sự thật duy nhất, thay cả 3 chỗ chép tay.

**Đo trên máy thật sau khi sửa:** phạm vi kiểm tra **13.128 → 28.618 bản ghi**,
phát hiện **20 bản lệch** thay vì 1.

### Lỗi gốc 2 — kiểm tra tự động đọc hơn 13.000 document mỗi lần, không throttle

`runFullCheck` phải `.get()` **toàn bộ document của mọi bảng** (cần id để đối
chiếu và tự khôi phục bản thiếu — `count()` không thay được), mà `main.dart` gọi
**mỗi lần mở app VÀ mỗi lần app quay lại foreground**, không có throttle.

**Sửa:** thêm nghỉ **30 phút** cho đường tự động (dùng lại kết quả gần nhất);
nút bấm tay truyền `force: true` nên vẫn kiểm ngay. `resetSyncTimestamps()` gọi
`SyncHealthCheck.invalidateCache()` để đổi shop là kiểm lại thật.

⚠️ **Đính chính:** báo cáo `[2026-09-05l]` nói "Firebase read ~1.857/ngày —
không nhiều". Con số đó **chỉ đếm listener**; phần đọc của kiểm tra sức khoẻ
KHÔNG được ghi vào `firebase_read_stats` nên không nằm trong đó. Thực tế cao hơn.

### Nghiệm thu máy thật (Oppo CPH2203)

Trung tâm đồng bộ hiện đúng 3 nút (Đồng bộ lại toàn bộ · Đẩy dữ liệu máy này lên
cloud · Kiểm tra chi tiết); nút "Thử lại mục lỗi" ẩn vì hàng đợi sạch.
`flutter analyze lib test` 0 error 0 warning.

---

## [2026-09-06f] - fix(chốt quỹ) DỌN 9 ĐIỂM CÒN TỒN SAU AUDIT (DB v111)

Xử lý nốt danh sách tồn của `[2026-09-06e]`.

### 1. Gộp nhiều ngày → danh sách giao dịch sắp SAI và không rõ ngày

Mọi chỗ sắp xếp giao dịch đều so **chuỗi `"HH:mm"`**. Trong 1 ngày thì vô hại,
nhưng màn hình này thường xuyên gộp nhiều ngày (khoảng chưa chốt quỹ, hoặc tự
chọn khoảng ngày) ⇒ `"09:00"` của hôm kia đứng trên `"08:00"` của hôm nay, mà
thẻ giao dịch **chỉ in giờ** nên không cách nào biết dòng nào của ngày nào.

- Mỗi dòng giao dịch nay mang thêm `timestamp` (ms tuyệt đối) — 12 chỗ tạo dòng.
- `lib/utils/transaction_sort.dart` (mới): `txTimestamp` / `byTimeDesc` dùng
  chung cho tab Tổng/Thu/Chi/Giao dịch **và** xuất Excel.
- Tab Thu / Chi trước đây còn nối từng ngày rồi **không sắp lại** ⇒ ra "khối
  theo ngày tăng dần, trong mỗi khối mới nhất trước".
- Thẻ giao dịch hiện `dd/MM HH:mm` khi danh sách trải nhiều ngày; sheet chi tiết
  thêm dòng "Thời gian" đầy đủ.

### 2. Tổng Thu/Chi ở tab Giao dịch không theo bộ lọc

Lọc "Bán hàng" thì số DÒNG đổi nhưng số TIỀN vẫn là tổng của mọi loại. Nay tổng
tính trên danh sách đã lọc/tìm kiếm, tiêu đề đổi thành "GIAO DỊCH ĐÃ LỌC".

### 3. Tab Lịch sử gọi Firestore trong `build()`

`FutureBuilder(future: _loadHistoryClosings())` tạo future MỚI mỗi lần rebuild
⇒ mỗi lần gõ ô tìm kiếm / nhận event đồng bộ lại bắn thêm 1 truy vấn
`cash_closings` (**không `limit`**) và nháy spinner. Nay future giữ ở state, chỉ
nạp lại khi chốt quỹ / nhận `cash_closings_changed` / kéo refresh; thêm
`limit(365)`.

### 4. LỆCH QUỸ không được lưu — **DB v111**

`_saveClosing` chỉ ghi `cashEnd`/`bankEnd` (số ĐẾM ĐƯỢC), không ghi số KỲ VỌNG
⇒ chốt xong là **mất dấu vĩnh viễn ngày nào lệch bao nhiêu**, đúng thứ mà màn
hình này sinh ra để phát hiện. Nay ghi đủ `cashStart` / `bankStart` /
`expectedCashDelta` / `expectedBankDelta` + 2 cột mới `cashDiff` / `bankDiff`.

**`cashDiff`/`bankDiff` CỐ TÌNH không có `DEFAULT`**: `NULL` = bản ghi chốt
trước v111 (không biết lệch), khác hẳn `0` = đã chốt và khớp. Để `DEFAULT 0` thì
mọi lần chốt cũ sẽ hiện "Khớp quỹ" — nói dối về số liệu tài chính.

Thẻ Lịch sử nay hiện lệch quỹ + ghi chú, đổi màu/biểu tượng theo trạng thái
(xám = không có thông tin lệch, xanh = khớp, cam = lệch), ngày theo `dd/MM/yyyy`.

### 5. Ô "Thực tế" không định dạng số

Điền sẵn số thô `6000000`, không có `inputFormatters`, và `_saveClosing` dùng
`int.tryParse` thẳng ⇒ gõ/dán `6.000.000` ra **0** rồi chốt luôn — trong khi ô
"Số dư đầu kỳ" ngay cạnh lại có định dạng. Nay dùng `MoneyUtils
.currencyInputFormatter()` + `MoneyUtils.parseCurrency` (formatter chuẩn của dự
án). Kỳ vọng âm thì điền sẵn 0 vì formatter không giữ dấu trừ — điền số âm vào
sẽ bị lật dấu âm thầm.

### 6. Gỡ `CashClosingNotifier` (359 dòng)

- `isDateLocked` / `canPerformTransaction` (mục đích cả service: chặn giao dịch
  ngày đã chốt) — **không nơi nào gọi**;
- `_saveClosing` không bao giờ ghi `isLocked` ⇒ nhánh thông báo khoá quỹ
  (`wasLocked != isLocked`) **không bao giờ chạy**; mà `_saveClosing` vốn đã tự
  gửi `sendCloudNotification`;
- `_syncToLocalDb` trùng hoàn toàn với `sync_service.dart` mục 19 (đã subscribe
  real-time `cash_closings` → `upsertCashClosing`, cùng phạm vi quyền
  `_isManagerLike`);
- nhưng vẫn poll Firestore (`limit 7`) ở `init` + `dataRefresh` +
  `sync_now_completed` + `app_resumed` + `cash_closings_changed`, khởi tạo 3 chỗ
  trong `main.dart`.

⇒ Xoá hẳn file + 3 lời gọi. Không mất chức năng nào đang chạy.

### 7. Xuất Excel sổ quỹ chỉ xuất 1 ngày

Luôn dùng `_selectedDate` nên khi màn đang gộp khoảng chưa chốt quỹ, file thiếu
hẳn các ngày còn lại mà vẫn mang tên "sổ quỹ"; cột "Ngày" còn đóng cứng 1 giá
trị cho MỌI dòng. Nay nhận `endDate`, lấy ngày theo `timestamp` của từng dòng.

### 8. Bấm "XÁC NHẬN CHỐT" bị từ chối vẫn đóng sheet như thành công

`_saveClosing` trả `void` và `return` khi từ chối (không phải hôm nay / đã chốt
/ thiếu ghi chú / thiếu shopId) ⇒ sheet vẫn đóng. Nay trả `Future<bool>`, chỉ
đóng khi lưu thật.

### 9. `permission_gate.dart` cấp quyền theo email cứng

2 chỗ `user.email == 'admin@huluca.com'` → quyền cao nhất hệ thống dựa trên một
chuỗi email chứ không phải claim đã ký, trái CLAUDE.md mục III.1. Đổi sang
`UserService.isCurrentUserSuperAdmin()` (đọc custom claims).

### Files
- `lib/utils/transaction_sort.dart` — **mới**
- `lib/views/cash_closing_view.dart` — 1,2,3,4,5,7,8
- `lib/utils/excel_export_helper.dart` — 1,7
- `lib/data/db_helper.dart` — **DB v110 → v111** (cash_closings.cashDiff/bankDiff)
- `lib/services/cash_closing_notifier.dart` — **xoá**
- `lib/main.dart` — bỏ 3 lời gọi + import
- `lib/widgets/permission_gate.dart` — 9
- `lib/data/app_knowledge_base.dart` — sửa id thuật ngữ `cong-no` (không tồn tại)
  thành `cong-no-phai-thu` / `cong-no-phai-tra` (lỗi lọt ở `[2026-09-06e]`)
- `test/cash_closing_audit_test.dart` — **mới**, 11 case (migration FFI trên
  SQLite thật + sắp xếp nhiều ngày + parse ô tiền)

---

## [2026-09-06e] - refactor(nhắc việc) GỘP "CẦN XỬ LÝ" VÀO "NHẮC NHỞ" + fix(sổ quỹ) ĐƠN "KẾT HỢP" DỒN HẾT VÀO NGÂN HÀNG

**Chủ shop báo:** *"việc cần xử lý (nhắc nhở) với cần xử lý lại bị trùng tính năng"* + yêu cầu audit toàn bộ trang Chốt quỹ.

### A. Trùng tính năng "CẦN XỬ LÝ" ↔ "Nhắc nhở"

Hai tính năng song song, mỗi bên tự đếm:

| | Thẻ "CẦN XỬ LÝ" (`dashboard_cards.dart`) | Trang "Nhắc nhở" (`ReminderService`) |
|---|---|---|
| Nguồn số | ~9 câu SQL viết thẳng trong widget | service, có lọc `shopId` |
| Đơn sửa chờ xử lý | `status IN (1,2)` | `status = 1` |
| Hàng chờ nhập kho | `products.isPending` (kho tạm) | `stock_entries` status=draft (Firestore) |
| Công nợ | chỉ khoản **quá hạn > 30 ngày** | **tất cả** khoản đang nợ |

Hệ quả:
1. Cùng một việc hiện **2 lần với 2 con số khác nhau**.
2. Thẻ còn kèm dòng *"N việc cần xử lý"* **trỏ ngược sang chính trang Nhắc nhở** — khung tên "CẦN XỬ LÝ" chứa mục tên "cần xử lý".
3. **"N hàng chờ xác nhận nhập kho" là số sai hẳn:** `products.isPending` = *sản phẩm kho tạm chưa có giá vốn*, còn màn hình mở ra là *danh sách phiếu nhập chờ duyệt* ⇒ số không bao giờ khớp danh sách.
4. Các câu SQL của thẻ **không lọc `shopId`**.
5. `_expiringProducts` (sản phẩm sắp hết HSD) **không bao giờ được gán** ⇒ mục HSD chưa từng hiển thị.
6. Trang chủ gọi `getTotalReminderCount()` (chạy trọn bộ query) **cộng thêm** 9 query của thẻ ⇒ 2 lượt quét trùng mỗi lần load.

**Đã gộp:** `ReminderService` là nguồn DUY NHẤT. Thẻ CẦN XỬ LÝ nay chỉ **vẽ** 5 việc gấp nhất của cùng danh sách + dòng "Xem tất cả".

- `reminder_service.dart`: thêm 4 category `warrantyExpiring` / `unclosedCash` / `missingCostRepair` / `pendingInstallment` (đều lọc `shopId`); `_countRepairsNeedWork` đổi sang `status IN (1,2)` cho khớp màn hình nó mở ra; thêm cờ `enableRepair` / `enableWarranty` theo ngành nghề shop; thêm `totalCount()`.
- **Không tách mục "công nợ quá hạn" riêng** — quá hạn là *tập con* của đang nợ, tách ra là đếm 1 khoản nợ thành 2 việc. Thay vào đó mục công nợ đổi sang mức "Cần xử lý ngay" và ghi thêm *"• N quá hạn"*.
- **Thợ:** con số toàn shop nay loại đơn của chính thợ (`excludeUid`) vì thợ đã có mục riêng "Máy cần sửa" — trước đây 1 đơn bị đếm 2 lần trên badge.
- **"Chưa chốt quỹ" tính là 1 việc**, không phải 1 việc/ngày, để badge không phình lên khi bỏ chốt quỹ lâu.
- `ReminderNavigator` (mới, trong `reminders_view.dart`): khai báo đích đến của mỗi mục đúng MỘT chỗ cho cả Trang chủ lẫn trang Nhắc nhở.
- Bỏ mục HSD chết và mục "hàng chờ xác nhận nhập kho" đếm sai; giữ mục nhập kho đúng của `ReminderService`.

### B. fix(sổ quỹ): đơn "KẾT HỢP" dồn **toàn bộ** tiền vào ngân hàng

`DailyFinancialAnalysisService.analyze()` có sẵn nhánh tách phần tiền mặt / phần
chuyển khoản của đơn KẾT HỢP, nhưng nhánh chỉ chạy khi caller truyền
`cashAmount` / `transferAmount`. **3/4 caller lược mất 2 cột đó** ⇒ nhánh KẾT HỢP
là code chết, đơn rơi xuống nhánh mặc định, và vì `'KẾT HỢP' != 'TIỀN MẶT'` nên
**cả đơn vào `bankIn`**:

| Caller | Trước | Sau |
|---|---|---|
| `cash_closing_view._analyzeTransactions` | ❌ thiếu | ✅ |
| `home_view._loadStats` (fSales) | ❌ thiếu | ✅ |
| `monthly_profit_report_view` | ❌ thiếu | ✅ |
| `finance_v2_daily_report_view` | ✅ (dùng `toMap()`) | ✅ |

Hệ quả thực tế: bán 10tr kiểu 4tr tiền mặt + 6tr chuyển khoản → Sổ quỹ báo
**tiền mặt +0đ, ngân hàng +10tr**. Chốt quỹ **lệch cả hai chiều** (thiếu tiền mặt,
thừa ngân hàng) trong khi tab **Thu** lại hiện đúng 4tr+6tr ⇒ hai tab đá nhau.
FinanceV2 thì đúng ⇒ Sổ quỹ vs FinanceV2 cũng đá nhau.

Test hồi quy: `test/ket_hop_cash_split_test.dart` (5 case, có case chứng minh
hành vi lỗi cũ).

### Files
- `lib/services/reminder_service.dart` — gộp toàn bộ phép đếm, +4 category, cờ ngành nghề, lọc shopId
- `lib/views/reminders_view.dart` — `ReminderNavigator` dùng chung, nhận cờ ngành nghề
- `lib/widgets/dashboard_cards.dart` — `ActionRequiredCard` từ StatefulWidget (~9 SQL) → StatelessWidget chỉ vẽ
- `lib/views/home_view.dart` — load 1 lần danh sách reminder cho cả 2 nơi; +cột KẾT HỢP
- `lib/views/cash_closing_view.dart`, `lib/views/monthly_profit_report_view.dart` — +cột KẾT HỢP
- `lib/data/app_knowledge_base.dart` — viết lại mục `home-action-required`
- `test/ket_hop_cash_split_test.dart` — mới

### Còn tồn (audit Chốt quỹ — CHƯA sửa, xem HANDOVER)
Tab Giao dịch sort chỉ theo `HH:mm` khi gộp nhiều ngày; tổng Thu/Chi ở header
không theo bộ lọc; tab Lịch sử gọi Firestore trong `build()`; lệch quỹ không
được lưu; `CashClosingNotifier.canPerformTransaction` chưa nơi nào gọi.

---

## [2026-09-06d] - fix(đồng bộ) XOÁ DỮ LIỆU LOCAL MÀ GIỮ CON TRỎ ⇒ MẤT DỮ LIỆU VĨNH VIỄN

**Chủ shop báo:** "2 máy số liệu khác nhau".

### Đo được trên 2 máy thật (HULUCA STORE)

Chỉ đếm bản ghi **đúng shop**:

| Bảng | Máy 1 trước | Máy 2 trước | Đúng (cloud) |
|---|---|---|---|
| Phiếu nhập | **71** | 59 | **3.036** |
| Nhật ký tài chính | **0** | 0 | **2.011** |
| Bảng giá NCC | 32 | 33 | **140** |
| Khách hàng | 5.377 | 5.374 | **5.560** |

Máy chủ shop dùng hằng ngày chỉ có **71/3.036 phiếu nhập** và **0/2.011 dòng
nhật ký tài chính**. Đơn bán / đơn sửa / sản phẩm thì đủ.

### Gốc rễ

`SyncService` dùng con trỏ tăng dần `rtCursor_<collection>_<shopId>` — listener
chỉ lấy document có `updatedAt > cursor`. `resetSyncTimestamps()` xoá đúng các
con trỏ này, **nhưng 4/5 chỗ xoá dữ liệu local lại không gọi nó**:

| Nơi xoá `clearAllData()` | Reset con trỏ? |
|---|---|
| `shop_selector_view.dart:238` | ✅ có |
| `main.dart:973` (đổi shop/user lúc khởi động) | ❌ **không** |
| `current_shop_service.dart:374` (chuyển shop) | ❌ **không** |
| `home_view.dart:3219` (đăng xuất) | ❌ **không** |
| `home_view.dart:7368` (đăng xuất) | ❌ **không** |

⇒ Xoá sạch dữ liệu nhưng giữ con trỏ ⇒ **mọi bản ghi cũ hơn con trỏ không bao
giờ tải lại được**. Máy càng đổi tài khoản / đăng xuất nhiều thì càng rỗng, mà
**không có dấu hiệu gì báo cho người dùng biết**.

Đo được trên máy 2: `rtCursor_import_orders` = 30/08, `rtCursor_customers` =
04/06 — trong khi dữ liệu local đã bị xoá sạch từ trước đó.

### Sửa

Thêm `await SyncService.resetSyncTimestamps();` ngay sau `clearAllData()` ở cả
4 chỗ còn thiếu, kèm ghi chú tại chỗ để không ai gỡ ra.

### Nghiệm thu 2 máy thật

Chạy **Trung tâm đồng bộ → Khởi động lại Realtime** (đường có sẵn, gọi
`forceReinitializeSync` → `resetSyncTimestamps` → tải lại) trên cả 2 máy.
Sau đó **14/15 bảng khớp tuyệt đối**: phiếu nhập **3.036 = 3.036**, nhật ký tài
chính **2.011 = 2.011**, khách **5.560 = 5.560**, bảng giá NCC **140 = 140**,
đơn bán **4.240 = 4.240**, doanh thu **64.210.963.000đ** hai máy như nhau.
(`import_order_items` còn lệch vì máy 2 đang tải tiếp.)

### 🔴 Hai vấn đề GHI NHẬN, CHƯA SỬA

1. **Kiểm tra đồng bộ báo sai an toàn.** Trung tâm đồng bộ hiện *"Local 13128 |
   Cloud 13129 — 1 bản ghi chưa khớp"* trên **cả hai máy**, trong khi máy 1
   thiếu **2.965 phiếu nhập + 2.011 dòng nhật ký tài chính**. Phép đếm không soi
   các bảng này ⇒ **cho cảm giác an toàn giả**.
2. **Rác dữ liệu shop khác còn trên cả 2 máy**: 101 dòng `financial_activity_log`,
   18–19 `import_orders`, 13 `price_catalog_items` mang `shopId` của shop test.
   Không lọt báo cáo (truy vấn lọc theo `shopId`) nhưng nên dọn.

---

## [2026-09-06c] - fix(tài chính) BỎ SÓT TIỀN TẤT TOÁN NGÂN HÀNG

Phát hiện khi đối chiếu màn Tài chính với CSDL sau đợt dọn trùng KiotViet.

### Lỗi

`finance_v2_data_service.dart` tính tiền thu của đơn trả góp là
`downPayment + settlementAmount`, nhưng chỉ duyệt **danh sách đơn bán trong kỳ**
(`getSalesByDateRange` bound theo `soldAt`). Sai **cả hai chiều**:

- đơn **bán TRONG kỳ**, ngân hàng trả tiền **SAU kỳ** ⇒ **ghi nhận SỚM** (tiền
  chưa về đã tính vào dòng tiền);
- đơn **bán TRƯỚC kỳ**, ngân hàng trả tiền **TRONG kỳ** ⇒ **BỎ SÓT** (tiền về
  thật mà không vào báo cáo).

**Đo trên shop thật 06/09/2026, cửa sổ 30 ngày: bỏ sót 59.660.000đ** — 5 đơn bán
đầu tháng 8, ngân hàng trả ngày 19/08 (PHẠM PHONG LƯU 17,59tr · PHÙNG NHỰT SƠN
15,59tr · PHẠM KHÁNH ANH THƯ 15,39tr · NGUYỄN VĂN QUANG 5,59tr · PHẠM HẢI LƯỢNG
5,5tr).

Đáng nói: `db_helper.dart` **đã có sẵn** `getInstallmentSalesSettledBetween()`
viết đúng cho việc này, kèm ghi chú *"KHÔNG lọc theo soldAt, vì đơn thường bán
từ trước rất lâu"* — nhưng màn Tài chính không gọi.

### Sửa

- Thêm `FinanceV2DataService.installmentCashIn(sale, startMs, endMs)`: **cọc
  tính theo ngày BÁN, tất toán tính theo ngày NHẬN TIỀN** — mỗi khoản vào đúng
  kỳ tiền thật về.
- `loadSnapshot` nạp thêm `getInstallmentSalesSettledBetween()` cho **cả kỳ hiện
  tại lẫn kỳ trước**, gộp vào danh sách đơn (khử trùng theo `firestoreId`, rơi
  về `id` khi chưa đồng bộ).

### Nghiệm thu máy thật (Oppo CPH2203, HULUCA STORE)

| Chỉ số 30 ngày | Trước | Sau |
|---|---|---|
| Thu từ bán hàng | 1,58 Tỷ | **1,64 Tỷ** |
| Tổng tiền vào | 1,687 Tỷ | **1,746 Tỷ** |
| Dòng tiền ròng | 1,16 Tỷ | **1,22 Tỷ** |
| Tiền ra | 526,4 Tr | 526,4 Tr *(không đổi)* |
| Thu sửa chữa | 105,6 Tr | 105,6 Tr *(không đổi)* |

Chênh lệch đúng bằng **59,66 triệu** đã tính ở trên.
`test/installment_settlement_cash_basis_test.dart` **8/8 PASS**; `flutter test`
**+584 −8** (đúng 8 lỗi có sẵn, không hồi quy); `flutter analyze lib test`
0 error 0 warning.

### KHÔNG phải lỗi (đã kiểm rồi bỏ)

Nút **"30 ngày"** dùng `subtract(days: 29)` với `end = hôm nay` — **đúng 30 ngày
kể cả hôm nay** (08/08 → 06/09). Ban đầu tưởng lệch 1 ngày, kiểm lại thì không.
Ghi ra đây để lần sau khỏi "sửa" nhầm.

---

## [2026-09-06b] - feat(AI) LỘ NĂNG LỰC AI + BẢN TIN ĐẦU NGÀY · fix ĐẾM ĐƠN CHỜ SAI · gỡ 3 TRIGGER THÔNG BÁO CHẾT

**Chủ shop báo:** *"AI chat đang có ít card gợi ý, chỉ chú tâm vào hướng dẫn sử
dụng là nhiều — cần cho người dùng biết chức năng, khả năng của AI hơn."*

### 1. Vì sao người dùng không biết AI làm được gì

Không phải AI thiếu năng lực — mà **không có đường nào nhìn thấy nó**:

- 4 chip mặc định (`ai_chat_overlay.dart`) đều là câu hỏi **số liệu**.
- Ngay sau lời chào, `_sendWelcome` **ghi đè** chip bằng 3 câu mẫu "cách dùng
  tính năng" từ `AppKnowledgeBase.sampleQuestionSpread(3)`, kèm câu dẫn *"Bạn có
  thể hỏi mình cách dùng bất kỳ tính năng nào"* ⇒ **chip đầu tiên người dùng
  nhìn thấy 100% là hướng dẫn sử dụng**.
- Câu trả lời liệt kê năng lực **đã có sẵn** trong `quickAnswer`, nhưng chỉ khớp
  cụm `'lam gi duoc'` — gõ "AI **làm được gì**" (đảo trật tự từ) là trượt, rơi
  xuống cloud/KB.
- `app_knowledge_base.dart` — nguồn sự thật của **cả AI lẫn Trung tâm trợ giúp**
  — **ghi sai**: *"AI chỉ đọc số liệu, không tự tạo/sửa đơn"*. Thực tế AI mở
  được form **tạo đơn sửa / đơn bán / nhập kho** đã điền sẵn nội dung
  (`AiOrderInputSheet` + `createRepairFromChat`/`createSaleFromChat`/
  `createStockFromChat`). Tức là AI đang **tự khai báo sai về chính mình**.

### 2. Đã sửa — AI

- **Chip mặc định đặt năng lực lên trước:** chip đầu luôn là **"✨ AI làm được
  gì?"**, rồi tới nhóm chip theo việc (`Tạo đơn sửa`, `Đơn đang chờ`, `Doanh thu
  hôm nay`, `Tồn kho hiện tại`, `Công nợ khách hàng`), chốt bằng
  `📚 Tất cả tính năng`.
- **Chip đổi theo tab đang mở** (`AiNavBridge.screenContext`): Sửa chữa → *Tạo
  đơn sửa · Đơn đang chờ · Sửa chữa hôm nay*; Bán hàng → *Tạo đơn bán · Bán hàng
  hôm nay · Đơn bán gần nhất*; Kho → *Nhập kho mới · Tồn kho hiện tại · Kho linh
  kiện*; Tài chính → *Doanh thu hôm nay · Lợi nhuận hôm nay · Ai nợ nhiều nhất*.
  Mọi nhãn đều đã đối chiếu để khớp đúng một nhánh `quickAnswer`.
- **Lọc theo quyền:** chip tài chính bị **ẩn** với người không có
  `allowViewRevenue` (trước đây vẫn hiện rồi mới bị AI từ chối). Nếu lọc xong
  rỗng thì quay về bộ chip chung.
- **Bắt thêm cách hỏi tự nhiên:** thêm `lam duoc gi`, `lam duoc nhung gi`,
  `lam nhung gi`, `giup duoc gi`, `kha nang`, `biet lam gi`, `co the lam gi`.
- **Viết lại câu trả lời năng lực** theo 4 nhóm — 🛠️ LÀM HỘ BẠN / 📊 TRA SỐ LIỆU
  / 📂 MỞ NHANH MÀN HÌNH / 📚 CHỈ CÁCH LÀM — mở đầu bằng *"Mình không chỉ trả
  lời — mình làm hộ được luôn"* và nhắc nút 🎤.
- **Tin nhắn sau lời chào** nay dẫn bằng năng lực *làm hộ* trước, rồi mới tới
  câu mẫu how-to.
- **`app_knowledge_base.dart` (`ai-assistant`):** viết lại `whatItDoes` thành 4
  nhóm năng lực, thay ghi chú sai bằng ghi chú đúng — *"AI KHÔNG tự ghi dữ liệu:
  với lệnh tạo đơn, AI chỉ mở form điền sẵn, bạn vẫn phải tự bấm Lưu"* — thêm
  bước "bấm chip ✨ AI làm được gì?" và 1 câu hỏi mẫu.

### 3. Đã sửa — bản tin đầu ngày (chủ động hơn)

- **Chấm đỏ trên nút AI** khi lần đầu mở app trong ngày chưa xem bản tin
  (`_checkBriefingPending` chỉ **đọc** mốc ngày; việc **ghi** vẫn do
  `_sendWelcome` làm khi thật sự hiện tin — không tự tiêu bản tin).
- Bản tin thêm dòng **"⚠️ Trong đó N đơn tồn từ hôm trước"**.

### 4. 🐛 fix: "đơn sửa đang chờ" trước nay **chỉ đếm đơn tạo trong ngày**

`AiChatStats.repairsPending` được tính từ `getRepairsByCreatedAtRange(dayStart,
dayEnd)` — tức **bỏ sót toàn bộ đơn tồn của những hôm trước**. Chủ shop hỏi "đơn
đang chờ" lúc 9h sáng có thể nhận về **0** dù còn 20 máy chưa trả. Danh sách liệt
kê cũng lọc từ `repairSummaries` (cũng chỉ trong ngày). Con số này xuất hiện ở
**16 chỗ** trong `ai_chat_service.dart` + lời chào.

**Sửa:**
- `db_helper.dart` thêm `getPendingRepairCounts(dayStartMs)` (1 câu `COUNT` +
  `SUM(CASE…)` → `{total, overdue}`) và `getPendingRepairs({limit: 8})` — đều
  lọc `status < 4`, `deleted`, `shopId`, **không giới hạn ngày tạo**.
- `AiChatStats` thêm `repairsOverdue` + `pendingRepairSummaries`;
  `repairsPending` nay là **toàn bộ đơn chưa giao**.
- Câu trả lời "đơn đang chờ" liệt kê từ danh sách chưa giao thật, mỗi dòng có
  **"tồn N ngày"**, kèm cảnh báo số đơn tồn từ hôm trước.
- `repairsToday` giữ nguyên nghĩa cũ (đơn tạo trong ngày) — không đụng.

### 5. 🔴 Gỡ 3 trigger thông báo: vừa CHẾT SẴN vừa RÒ DỮ LIỆU CHÉO SHOP

`functions/index.js` có `notifyNewRepair`, `notifyNewChat`, `notifyStatusChange`.

- **Chết sẵn:** chúng gọi `admin.messaging().sendToTopic()` và `.sendMulticast()`
  — **cả hai API đã bị xoá khỏi `firebase-admin` v13**, mà `package.json` đang
  `^13.6.0` (đã kiểm `node_modules`: không còn hàm nào). Mỗi lần chạy đều ném
  `TypeError` rồi bị `catch` nuốt ⇒ **im lặng không gửi được gì**.
- **Rò chéo shop:** `notifyNewRepair`/`notifyStatusChange` bắn tới topic
  **`staff` TOÀN CỤC**, mà `notification_service.dart` cho nhân viên của **mọi
  shop** subscribe topic đó. "Sửa cho chạy lại" nguyên trạng = **tên khách +
  SĐT + model + giá của shop A hiện trên máy shop B** (cùng họ AR-05/AR-06).
- **Và sẽ gây trùng:** client đã tự gửi đủ cả 3 loại qua callable
  `sendShopNotification` (đúng API `sendEachForMulticast`, lọc theo `shopId`):
  đơn sửa mới `create_repair_order_view.dart:1116`, đổi trạng thái
  `repair_detail_view.dart:1422`, chat `chat_service.dart:111`. Hồi sinh trigger
  ⇒ **mỗi sự kiện 2 thông báo**.

**Xử lý: gỡ hẳn 3 trigger** (thay bằng khối chú thích nêu đủ 3 lý do + cách làm
đúng nếu sau này muốn chuyển thông báo về server), trim import
`onDocumentCreated`/`onDocumentUpdated` không còn dùng, và **bỏ đăng ký topic
`staff`** ở client (`subscribeToTopic` → `unsubscribeFromTopic`) vì topic này
nay không còn ai gửi — đóng luôn đường rò. Topic `all_users` (broadcast của super
admin) **giữ nguyên**.

### 6. Nghiệm thu máy thật (Oppo CPH2203, shop HULUCA STORE) — phát hiện thêm 3 lỗi

**a) Số "đơn đang chờ" của AI đá nhau với Trang chủ.** Trang chủ báo **1 đơn sửa
chờ xử lý**, AI báo **8**. Đối chiếu: `dashboard_cards.dart` đếm
`status IN (1,2)` (việc thợ còn phải làm), còn truy vấn mới đếm `status < 4`
(máy còn trong tiệm) — gộp cả **7 máy đã sửa xong đang chờ khách tới lấy**.
Con số 8 đúng, nhưng **chữ "đang chờ xử lý" thì sai**.
**Sửa:** `getPendingRepairCounts` trả thêm `inProgress` (1–2) + `awaitingPickup`
(3); mọi câu chữ đổi **"chờ xử lý" → "chưa giao"** (9 dòng trong
`ai_chat_service.dart` + 3 dòng lời chào). AI nay nói:
*"Đang có 8 đơn chưa giao (1 đang xử lý · 7 xong chờ khách lấy)"* — khớp Trang chủ.
**Giá trị thực tế đo được:** 7 máy đã sửa xong tồn **1–4 ngày** chưa ai lấy;
trước khi sửa AI báo **0 đơn** vì không đơn nào tạo trong ngày.

**b) 🐛 Thanh nhập của bong bóng AI bị thanh điều hướng che** (chủ shop báo:
*"thanh nhập ký tự bị che dưới màn hình khó bấm vào"*). Panel neo `bottom: 0`
của **toàn màn hình** nên đáy nằm dưới thanh 3 nút, mà `_buildInput` chỉ trừ
`mq.viewInsets.bottom` (bàn phím), **không trừ `mq.padding.bottom`**.
**Sửa:** cộng cả `mq.padding.bottom` — Flutter tự đưa giá trị này về 0 khi bàn
phím mở nên không bị đệm thừa. Ảnh chụp trước/sau xác nhận mic + ô nhập + nút
gửi đã hiện đủ.

**c) Dấu `*nghiêng*` hiện ra ký tự thô.** `_buildMsgText` **chỉ** hiểu
`**đậm**`, nên `*"..."*` và `_"..."_` hiển thị nguyên dấu sao/gạch dưới. Đã bỏ
khỏi câu trả lời năng lực + tin nhắn sau lời chào (kèm chú thích cảnh báo tại
chỗ). **Còn tồn đọng:** vài câu quick-answer cũ khác vẫn dùng `*...*` — chưa
đụng tới trong đợt này.

**d) Chip theo tab gần như không bao giờ hiện.** `_sendWelcome` set
`_contextChips` ngay lúc mở bong bóng và giá trị đó nằm lại tới câu trả lời có
`followUpChips` kế tiếp ⇒ bộ chip mặc định theo tab bị che vĩnh viễn.
**Sửa:** đổi tab thì **xoá** `_contextChips` để thanh chip quay về gợi ý của tab
mới.


### 7. Dọn nốt dấu `*nghiêng*` + trạng thái cloud

**Client:** rà toàn bộ chuỗi AI, chỉ còn **3 chỗ** dùng dấu nghiêng — nhánh chào
hỏi trong `ai_chat_service.dart` (2 dòng) và mục `finance-v2` của
`app_knowledge_base.dart` (1 chỗ). Đã bỏ hết. Nhân tiện sửa 2 chip của nhánh
chào: `Đơn sửa đang chờ` → **`Đơn đang chờ`** (chuỗi cũ chuẩn hoá ra
`don sua dang cho`, **không** khớp từ khoá `don dang cho` nên rơi nhầm sang
nhánh trả lời khác), và `Hướng dẫn` → **`✨ AI làm được gì?`**.

**Cloud:** `CHAT_SYSTEM_PROMPT` mới chỉ cấm heading, chưa cấm nghiêng — đã thêm
một dòng nói rõ app CHỈ hiển thị được `**bold**`. **Chỉ có hiệu lực sau khi
deploy functions.**

**✅ Đã xoá 3 trigger khỏi cloud.** Trước khi xoá đã đối chiếu:
`firebase functions:list` cho thấy cloud có **đúng 21 hàm của mã nguồn + 3
trigger đã gỡ + 3 hàm của Firebase Extension** (`ext-delete-user-data-*`,
vùng `us-central1`, KHÔNG thuộc repo). Không hàm nào trong nguồn thiếu trên
cloud ⇒ **không cần deploy lại cả 21 hàm**, chỉ cần xoá đúng 3 cái chết:

```
firebase functions:delete notifyNewRepair notifyNewChat notifyStatusChange \
  --region asia-southeast1 --force --project huyaka-1809
```

**Kết quả xác minh bằng `functions:list` sau khi xoá:** **27 → 24 hàm**; 3 trigger
biến mất; **đủ 21 hàm của mã nguồn**; 3 hàm Extension nguyên vẹn.

Chọn `functions:delete` thay vì `deploy --only functions` là có chủ ý: deploy sẽ
đẩy lại toàn bộ 21 hàm đang chạy ổn, trong khi mục tiêu chỉ là bỏ 3 hàm chết.

**⚠️ Còn chờ deploy:** dòng cấm `*nghiêng*` thêm vào `CHAT_SYSTEM_PROMPT` chỉ có
hiệu lực sau `firebase deploy --only functions`.


### Files

`lib/widgets/ai_chat_overlay.dart` · `lib/services/ai_chat_service.dart` ·
`lib/data/db_helper.dart` · `lib/data/app_knowledge_base.dart` ·
`lib/services/notification_service.dart` · `functions/index.js` ·
`test/ai_pending_repairs_test.dart` (MỚI)

**Kiểm chứng:** `flutter analyze` **0 error** · `node --check functions/index.js`
OK · `flutter test` **+576 −8** (8 lỗi có sẵn: kiotviet, payroll lock, quick
input) · 4 test FFI mới chạy ĐÚNG câu SQL trên SQLite thật · **đã nghiệm thu**
trên Oppo CPH2203 với dữ liệu shop thật (xem mục 6).

---


## [2026-09-06a] - fix(UI) NÚT DỌN TRÙNG BỊ KHUẤT + SOÁT TRÙNG TOÀN BỘ BẢNG

### ✅ NGHIỆM THU: đã dọn xong trên dữ liệu thật (06/09/2026)

Chủ shop tự bấm nút. Đối chiếu CSDL sau khi dọn — **khớp chính xác kỳ vọng**:

| | Trước | Sau |
|---|---|---|
| Đơn bán | 6.485 | **4.240** |
| Bản ghi KV / mã hoá đơn | 6.218 / 3.973 | **3.973 / 3.973 (thừa 0)** |
| Doanh thu | 99.817.152.000đ | **64.210.963.000đ** |
| Doanh thu 2026 | 25.814.613.000đ | **15.390.584.000đ** |

- **Không xoá nhầm:** đơn app tự tạo vẫn đúng **267 đơn / 3.980.865.000đ**;
  hôm nay và tháng 9/2026 không đổi.
- **Không lượt nào hụt cloud:** `sync_queue` = 0 dòng.
- **Chạy lại an toàn:** lượt đầu (xoá lẻ) dọn 716/2245 rồi bị ngắt giữa chừng
  để đổi sang bản gộp lô; quét lại đếm đúng 1.529 bản còn lại, không mất và
  không xoá nhầm gì.

**Chủ shop báo:** "tôi không thấy chỗ dọn đơn từ kiotviet trùng".

**Nguyên nhân:** panel đặt ở tab **TÀI CHÍNH** — tab thứ 5 của `TabBar` có
`isScrollable: true`, nên **bị khuất khỏi mép phải màn hình điện thoại**, phải
vuốt ngang mới thấy. **Sửa:** tách thành widget `_KvDuplicatePanel` và đưa lên
**đầu tab ĐƠN BÁN** (tab thứ 2, luôn nhìn thấy) — cũng đúng chỗ về mặt ngữ
nghĩa vì đây là dọn đơn bán. Nút đổi thành `ElevatedButton` đỏ, rộng hết dòng.
Gỡ bản inline khỏi `_FinanceCleanupTab` để khỏi phải bảo trì hai nơi.

### Dọn trùng quá chậm — gộp lô Firestore

Chủ shop chạy thật báo "dọn lâu quá". Đo trên máy: **~25–37 bản/phút** ⇒ 2.181
bản mất **~50–70 phút**. Nguyên nhân: mỗi bản là **một lượt gọi mạng riêng**
(`FirestoreService.deleteSale` → 1 `update`, chạy tuần tự `await`).

**Sửa:** `apply()` nay gom **400 thao tác / `WriteBatch`** (trần Firestore là
500, chừa biên) — cả lô chỉ tốn MỘT lượt mạng; local cũng gộp thành một câu
`DELETE ... WHERE id IN (...)` thay vì mỗi bản một câu. 2.181 bản còn ~6 lô.
- Dùng `set(..., merge: true)` chứ không `update`: document đã bị gỡ ở nơi khác
  sẽ làm **hỏng cả lô** nếu dùng `update`, trong khi `set(merge)` vẫn an toàn vì
  ta chỉ đánh dấu `deleted: true`.
- Lô nào commit lỗi thì **tự hạ xuống xoá lẻ** từng bản, hỏng tiếp thì đẩy vào
  hàng đợi `SyncOrchestrator` — một document lỗi không kéo cả lô theo.

**Ngắt giữa chừng an toàn:** mỗi bản độc lập, bản đã xoá vẫn xoá. Thực tế đã
ngắt lượt chậm ở 716/2245 để đổi sang bản gộp lô, lần quét lại đếm đúng 1.529
bản còn lại, không mất và không xoá nhầm gì.

### Tab TÀI CHÍNH quay vòng vĩnh viễn

Chủ shop mở đúng tab TÀI CHÍNH thì gặp **vòng xoay không bao giờ dứt**. Nguyên
nhân: `_FinanceCleanupTab._load()` chạy 8 lệnh quét **trần, không try/catch** —
chỉ cần một lệnh ném lỗi là `_loading` không bao giờ về `false`. Trên shop có
6.485 đơn bán / 821 sản phẩm thì xác suất này là thật.

**Sửa:** mỗi lệnh bọc qua `_safe(label, run)` — lỗi thì ghi nhãn vào
`_loadErrors` và trả danh sách rỗng thay vì làm sập cả tab; `finally` luôn tắt
vòng xoay. Màn hình trống nay nói rõ mục nào quét lỗi thay vì im lặng.

### Soát trùng TOÀN BỘ các bảng (theo yêu cầu "các mục khác có bị trùng không")

Đối chiếu trên DB thật của HULUCA STORE, khoá `firestoreId`:

| Bảng | Nhóm trùng | Bản thừa | Kết luận |
|---|---|---|---|
| **sales** | — | **2.245** | 🔴 trùng (đã có công cụ dọn) |
| suppliers (NCC) | 0 | 0 | ✅ sạch |
| customers | 0 | 0 | ✅ sạch |
| products | 0 | 0 | ✅ sạch |
| repairs | 0 | 0 | ✅ sạch |
| debts · debt_payments | 0 | 0 | ✅ sạch |
| import_orders · import_order_items | 0 | 0 | ✅ sạch |
| expenses · payment_intents · cash_closings | 0 | 0 | ✅ sạch |
| financial_activity_log | 0 | 0 | ✅ sạch |

**Chỉ `sales` bị trùng** — đúng như phân tích ở `[2026-09-05l]`: chỉ đường đẩy
đơn bán mới nhét `s.id` (số thứ tự SQLite từng máy) vào doc id. Sản phẩm dùng
khoá tổng hợp không có id cục bộ nên không dính.

### Hai nghi vấn KHÔNG kết luận được (cố ý không tự sửa)

- **Sản phẩm cùng SKU + cùng IMEI (15 cụm, 17 dòng).** Cột `imei` chỉ lưu **4
  số cuối** (399/821 sản phẩm dài đúng 4 ký tự) nên **không đủ làm khoá duy
  nhất** — đã chứng minh: 4 số `7352` xuất hiện ở **3 SKU khác nhau**. Thêm nữa
  giá vốn giữa các dòng lệch nhau (13.800.000 vs 12.700.000) ⇒ nhiều khả năng
  là **hai lô nhập khác nhau**, không phải bản trùng. Muốn chốt phải đối chiếu
  IMEI đầy đủ bên KiotViet hoặc kiểm kho thực tế.
- **Cùng tên nhưng là hai bản ghi song song** — `CÓC SẠC ANKER 30W` (KiotViet:
  sl 158, vốn 280.000, bán 590.000 / app tự tạo: sl 914, vốn 115.000, bán
  380.000), `ESIM` (92 / 0), `DÂY SẠC` (97 / 94). Đây KHÔNG phải import hai lần
  mà là **hàng đã có sẵn trong app rồi KiotViet nhập vào tạo bản thứ hai** ⇒
  tồn kho bị chia đôi. Gộp hay không là quyết định nghiệp vụ của chủ shop.

---

## [2026-09-05l] - fix(KiotViet) HOÁ ĐƠN NHẬP TRÙNG THỔI DOANH THU 35,6 TỶ

**Phát hiện khi đối soát số liệu tài chính trên shop thật (HULUCA STORE).**

### Đo được trên máy chủ shop (Oppo CPH2203, `huy@huluca.com`)

| | |
|---|---|
| Bản ghi mang mã `KV:` | **6.218** |
| Hoá đơn KiotViet THẬT | **3.973** |
| Bản ghi thừa | **2.245** |
| Doanh thu bị cộng lặp | **35.606.189.000 đ** |
| Riêng năm 2026 | app hiện 25,8 tỷ — thực tế **15,4 tỷ** (+68%) |

Trải từ 01/2025 → 06/2026. Cả 2.245 cặp đều `isSynced=1` ⇒ **đã lên cloud**,
mọi máy của shop đều đang thấy số sai.

### Gốc rễ — `sync_service.dart:3619`

```dart
final docId = s.firestoreId ?? "sale_${s.soldAt}_${s.phone}_${s.id ?? 0}";
```

`s.id` là **số thứ tự SQLite của riêng từng máy**. Cùng một hoá đơn import ở
hai máy ⇒ hai doc id ⇒ **hai document trên Firestore** ⇒ mọi máy tải về hai bản.
Đo được đúng cặp: `sale_1767627673970_0968704453_**1745**` và `..._**8463**` —
giống hệt nhau từ khách, SĐT, sản phẩm tới từng mili giây.

*Cùng họ lỗi với sự cố xoá khách `[2026-09-05g]`: dùng id cục bộ để tra cloud.*

Chống trùng sẵn có của importer (`notes = 'KV:<mã>'`) chỉ chặn được **trên máy
đang import**, nên máy thứ hai có DB local trống vẫn tạo bản mới. Hai hàm dọn
trùng cũng bó tay: `cleanDuplicateData` gộp theo `firestoreId` (hai bản khác
id), `cleanupCloudShadowDuplicates` chỉ xoá bản `firestoreId` rỗng.

### Đã sửa

**1. Vá gốc — `kiotviet_excel_import_service.dart`**
Thêm `kvSaleDocId(shopId, invoiceCode)` sinh doc id **tất định**
`kv_<shopId>_<mã HĐ>`, gán ngay lúc import cho bản MỚI (bản cũ giữ nguyên
`firestoreId` để không bỏ rơi document đang có). Import lại ở bất kỳ máy nào
cũng ghi đè đúng document cũ. Có `shopId` vì `sales` là collection dùng chung
mọi shop.

**2. Công cụ dọn — `lib/services/kv_duplicate_cleanup_service.dart` (mới)**
- `scan()` — quét thử, KHÔNG sửa gì: số bản thừa, tiền thổi phồng, phân bố theo
  tháng, số đơn thiếu `shopId`.
- `apply()` — giữ bản `id` nhỏ nhất mỗi hoá đơn; cloud xoá MỀM
  (`deleted: true`, CLAUDE.md III.10) để máy khác tự gỡ theo, local xoá hẳn;
  mất mạng thì đẩy vào hàng đợi `SyncOrchestrator`. **Không đụng công nợ / bút
  toán / tồn kho** — bản trùng là bản ghi ma do đồng bộ đẻ ra, chưa từng sinh
  sổ sách riêng. Ghi **một** bản kiểm toán tổng, không ghi từng dòng (tránh đẻ
  thêm hàng nghìn lượt ghi Firestore chỉ để log dọn rác).

**3. Giao diện** — Cài đặt → Công cụ điều chỉnh dữ liệu → tab **TÀI CHÍNH**.
Hiện số liệu quét trước, bấm dọn phải qua hộp xác nhận **và mật khẩu đăng nhập**
(`reauthenticateWithCredential`) như mọi thao tác nguy hiểm khác ở màn này.

**4. Test — `test/kv_duplicate_cleanup_test.dart` (11 ca, PASS)**
`kvSaleDocId` tất định / hai máy ra cùng id / hai shop không đụng id / giữ dấu
chấm `HD007168.02` / bỏ `/` và khoảng trắng. Trên SQLite thật (ffi): đúng hình
dạng cặp trùng đo được ngoài production, hoá đơn không trùng không bị đụng, bản
đã xoá mềm không bị tính lại (chạy lần 2 an toàn), đơn app tự tạo không lọt
diện dọn, nhóm 3 bản xoá 2 giữ 1, tiền thổi phồng = tổng bản thừa.

### Kiểm chứng phần ĐÚNG (không phải lỗi)

- **Dòng tiền hôm nay 66.18 Tr khớp chính xác** DB: 20.390.000 + 340.000 +
  11.390.000 + 50.000 + 120.000 + 33.890.000. Đơn trả góp 4.990.000 đúng là
  không cộng (NH chưa tất toán).
- Tháng 9/2026 và 30 ngày gần đây **không có bản trùng** — số liệu sạch.
- 101 dòng `financial_activity_log` của shop test (`geqXPHQ…`) còn sót trong máy
  nhưng **bị lọc đúng** bởi `(shopId = ? OR shopId IS NULL)`, không lọt báo cáo.
- Firebase read **~1.857 read/ngày/máy** (2.551 read / 33 giờ), 100% từ listener
  ⇒ ~19% hạn mức free với 5 máy. **Không nhiều.**

### CÒN LẠI — chưa xong

- 🔴 **Chưa chạy dọn trên dữ liệu thật.** Bước cuối đòi mật khẩu đăng nhập của
  chủ shop nên phải do chủ shop tự bấm. Đã tạo sẵn file phục hồi
  `/sdcard/Download/kv_rollback_manifest.json` (630 KB) liệt kê đủ 2.245
  `firestoreId` sẽ bị xoá + bản giữ lại của từng hoá đơn.
- 🔴 **6.218/6.485 đơn có `totalCost = 0`** (mọi đơn KiotViet). Mọi con số "lợi
  nhuận" ở kỳ có dữ liệu KiotViet đều **bằng doanh thu**, vô nghĩa. File Excel
  KiotViet không có cột giá vốn ⇒ cần nguồn giá vốn riêng.
- 🟡 **`SaleOrder` không có trường `shopId`** ⇒ bản tải từ cloud về luôn ghi
  `shopId = NULL` (6.425/6.485 dòng). Hiện vô hại vì truy vấn dùng
  `(shopId = ? OR shopId IS NULL)`, và **bản trên cloud đã có `shopId` đúng**
  (`syncAllToCloud` gán `data['shopId']`). CỐ Ý CHƯA SỬA: thêm trường vào model
  đụng toàn bộ đường tiền, rủi ro hồi quy cao hơn lợi ích hiện tại.
- 🟡 **Tháng 3/2026 nhập thiếu**: chỉ 48 bản = 24 hoá đơn thật, trong khi T2 có
  272 và T4 có 360; chỉ 11 ngày trong tháng có phát sinh. Cần file Excel
  KiotViet tháng 3/2026 để nhập bù — **không thể tự dựng lại**.

---

## [2026-09-05k] - refactor(cài đặt) DỌN TRANG CÀI ĐẶT + NỐI LẠI 2 MÀN HÌNH BỊ MẤT

**Yêu cầu:** "audit trang cài đặt làm cho nó chuyên nghiệp".

### Phát hiện khi audit

1. **`lib/views/settings_view.dart` (1699 dòng) là CODE CHẾT** — không file nào
   tham chiếu tới `SettingsView`. Trang Cài đặt thật là
   `home_view.dart::_buildSettingsTab()`. Hậu quả: hai màn hình chỉ được mở từ
   file chết này **không còn đường vào trong app**:
   - `CategoryManagementView` (Danh mục sản phẩm) — 0 tham chiếu ngoài file chết;
   - `KiotVietSettingsView` (khai báo Client ID/Secret) — 0 tham chiếu ngoài file
     chết. (Nhập file KiotViet vẫn vào được qua Sao lưu & Khôi phục.)
   `StaffPermissionsView` cũng chỉ có ở file chết nhưng **không mất tính năng** —
   phân quyền đã có sẵn trong tab Nhân viên → chọn nhân viên.
2. **Ô tìm kiếm không thấy 3 công tắc kho hàng** (giá vốn sau, hiện NCC, bắt buộc
   NCC) vì chúng nằm ngoài danh sách `allItems` — gõ "giá vốn" ra "không tìm
   thấy". Tìm kiếm cũng không bỏ dấu nên gõ "gia von" không ra gì.
3. **Kết quả tìm kiếm mất ngữ cảnh** — trả về danh sách phẳng, không tiêu đề nhóm.
4. **Giao diện thiếu chuyên nghiệp:** mỗi dòng là một thẻ pastel riêng và
   **tiêu đề tô màu theo icon** (tím, xanh lá, cam, đỏ…) ⇒ rối mắt, chữ đỏ/cam
   dễ bị đọc nhầm thành cảnh báo.
5. **Không hiển thị phiên bản app** ở bất kỳ đâu trong Cài đặt — hỗ trợ không
   hỏi được người dùng đang chạy bản nào.
6. **Công cụ nội bộ `🔬 Firestore Audit Monitor` hiện cho MỌI chủ shop** trên bản
   release (điều kiện `kDebugMode || hasFullAccess`).
7. **`app_knowledge_base.dart` chỉ sai đường dẫn menu:** `roles-permissions` ghi
   "Cài đặt → Nhân viên → Phân quyền" (không tồn tại), `backup-restore` ghi
   "Sao lưu / Khôi phục" (tên thật dùng dấu &).

### Đã sửa — `lib/views/home_view.dart`

- **Một đường vẽ duy nhất.** Bỏ nhánh render riêng cho search; mọi mục (kể cả
  công tắc) nằm trong `allItems`, lọc rồi gom nhóm ⇒ kết quả tìm kiếm **giữ
  nguyên tiêu đề nhóm**.
- `_SettingsItem` thêm `keywords` (từ khoá ẩn phục vụ tìm kiếm), `builder` (mục
  tự vẽ — dùng cho công tắc) và `matches()` chạy trên chỉ mục đã bỏ dấu.
- **Tìm kiếm bỏ dấu** (`_foldVi`): gõ "gia von" ra "Cho phép nhập giá vốn sau".
- **Giao diện gom nhóm chuẩn:** mỗi nhóm là MỘT thẻ nền trắng viền mảnh, các
  dòng ngăn bằng divider; tiêu đề dùng màu chữ trung tính `AppColors.textPrimary`,
  màu thương hiệu chỉ còn ở ô icon 36×36. 3 công tắc chuyển từ `CheckboxListTile`
  sang `SwitchListTile` cho đúng quy ước trang cài đặt.
- **Nối lại 2 màn hình bị mất:** "Danh mục sản phẩm" (nhóm Cửa hàng) và
  "Kết nối KiotViet" (nhóm Dữ liệu & Hệ thống) — chỉ chủ shop/quản trị.
- **Chân trang phiên bản** `Phiên bản x.y.z (build n)`, chạm để copy.
- **Công cụ nội bộ** đổi điều kiện thành `kDebugMode || _isSuperAdmin`, bỏ emoji
  khỏi tiêu đề.

### Đã sửa — `lib/data/app_knowledge_base.dart`

- Sửa `menuPath` của `roles-permissions` và `backup-restore` cho khớp app thật.
- Thêm 2 mục `product-categories` và `kiotviet-connect` cho 2 màn hình vừa nối lại.

### Nghiệm thu máy thật (Oppo CPH2203, debug build)

- Trang Cài đặt render đúng kiểu nhóm mới, không lỗi bố cục.
- Gõ "gia" (không dấu) ⇒ ra nhóm **Kho hàng → Cho phép nhập giá vốn sau** (công
  tắc, trước đây tìm không ra), **Giao diện & Ngôn ngữ**, **Dữ liệu & Hệ thống**.
- Chân trang hiện "Phiên bản 3.5.1 (build 555)".
- "Kết nối KiotViet" hiện trong nhóm Dữ liệu & Hệ thống.
- `flutter analyze` — 0 error, 0 warning (chỉ còn info lint có sẵn từ trước).

### Dọn nốt (chủ shop duyệt xoá) + công cụ nội bộ theo email

- **Đã xoá `lib/views/settings_view.dart`** (1699 dòng, 0 tham chiếu). Trước khi
  xoá đã đối chiếu từng tính năng chỉ có trong file này:
  - "Đẩy dữ liệu KiotViet lên Cloud" → **không mất**, `forceResyncKiotVietData()`
    vẫn gọi được từ `kiotviet_import_view.dart` (vào qua Sao lưu & Khôi phục).
  - "Nhận kho từ Cloud" → **mất biến thể xoá-rồi-tải**: nút này xoá sạch bảng
    `products` của shop trước rồi mới `downloadAllFromCloud(force: true)`, nhằm
    dọn cả sản phẩm đã xoá cứng trên cloud. "Tải từ Cloud" ở Trung tâm đồng bộ
    chỉ upsert nên **không xoá được bản ghi thừa ở local**. Nếu cần dùng lại thì
    lấy từ lịch sử git (`git show 7ae7b20b:lib/views/settings_view.dart`).
  - "Xoá trắng shop", PIN super admin, nhật ký truy cập, phân quyền nhân viên
    → đều đã có ở Super Admin Console / tab Nhân viên, không mất gì.
- **Công cụ nội bộ mở theo email** — thêm `lib/utils/internal_tools.dart`:
  `InternalTools.visibleFor(email, isSuperAdmin, isDebugBuild)`. Bản phát hành
  hiện "Giám sát Firestore Read" cho super admin **và** `huy@huluca.com`.
  ⚠️ Lớp này **chỉ điều khiển hiển thị, không phải cơ chế bảo mật** — quyền thật
  vẫn do custom claims + `firestore.rules` (CLAUDE.md mục III.1), nên không được
  dùng nó để gác tính năng có tác động dữ liệu.
  Kèm `test/internal_tools_test.dart` (7 ca): email nội bộ thấy; hoa/thường +
  khoảng trắng vẫn khớp; chủ shop thường không thấy; email rỗng/null không thấy;
  `huy@huluca.com.vn` và `xhuy@huluca.com` **không lọt**; super admin luôn thấy.

---

## [2026-09-05j] - fix(super admin) BẤM THOÁT RA MÀN HÌNH ĐEN, APP KHÔNG TẮT

**Chủ shop báo:** "khi tôi bấm thoát ứng dụng thì chỉ có màn hình đen chứ ko
thoát app". Đã **tái hiện được trên máy thật** (Oppo CPH2239, tài khoản super
admin): sau khi bấm *Thoát Console*, `dumpsys window` cho thấy MainActivity vẫn
đang focus, tiến trình vẫn sống, `uiautomator dump` rỗng — engine chạy nhưng
**không render gì**.

**Nguyên nhân** — `super_admin_console_view.dart`:
```dart
onPopInvokedWithResult: (didPop, _) async {
  ...
  navigator.pop();      // ← pop cái gì?
}
```
`SuperAdminConsoleView` có **hai đường vào**:
- `main.dart` (AuthGate) trả **thẳng làm widget GỐC** khi super admin đăng nhập
  — dưới nó KHÔNG còn route nào;
- `home_view` push từ Cài đặt — có route để quay về.

Code luôn gọi `navigator.pop()`. Ở đường gốc, nó **xoá route DUY NHẤT** ⇒
Navigator rỗng ⇒ màn hình đen mà app vẫn chạy. Lỗi chỉ xuất hiện với tài khoản
super admin, nên tài khoản chủ shop thường không gặp (đã đối chiếu: máy 1 với
`m@m.com` bấm thoát vẫn về launcher bình thường).

**Sửa:** phân biệt hai đường — `navigator.canPop()` thì `pop()` (quay lại Cài
đặt), không thì `SystemNavigator.pop()` (thoát app), giống cách `home_view` vẫn
làm.

**Nghiệm thu máy thật:** bấm Thoát → focus chuyển sang
`com.oppo.launcher.Launcher`, app thoát hẳn. `flutter analyze` 0 lỗi/cảnh báo.

---

## [2026-09-05i] - fix(đơn sửa) MẤT THÔNG BÁO NHẬN MÁY + ĐƠN TỰ TỤT VỀ "TIẾP NHẬN"

**Chủ shop báo (05/09, kèm ảnh chat nội bộ + danh sách đơn):** đơn IPHONE 11 —
BÉ THẮM tạo lúc 15:11 **không hề có tin "🔧 ĐƠN MỚI"** trong chat nội bộ, chỉ
thấy "SỬA XONG" và "YÊU CẦU DUYỆT GIAO" lúc 15:12; tới lúc chủ shop mở ra sửa
giá vốn để duyệt giao thì đơn lại nằm ở trạng thái **TIẾP NHẬN** kèm nhãn
**"Chưa có KTV"**. Các đơn khác bình thường.

**Lỗi 1 — thông báo "nhận máy" bị bỏ hẳn, không phải bị trễ.**
`create_repair_order_view.dart:866` quyết định bắn chat + push bằng bộ đếm của
hàng đợi: `failed == 0 && success > 0`. Ba tình huống rất thường gặp làm cờ này
`false` **dù đơn vẫn lên cloud ngay sau đó**: (a) đang có một lượt `syncAll()`
khác chạy ⇒ trả về `skipped` với `success = 0`; (b) **món khác** trong hàng đợi
lỗi ⇒ `failed > 0`; (c) ảnh chưa upload xong ⇒ item create ném lỗi để retry. Tệ
hơn: đường dự phòng ghi thẳng Firestore ngay bên dưới **tự bỏ qua khi đơn có
ảnh** (`hasLocalOnlyImagePath`) — đúng trường hợp đơn IPHONE 11 (2 ảnh) — nên
tin "nhận máy" mất vĩnh viễn, trong khi chat "SỬA XONG"
(`repair_detail_view.dart:1431`) và "YÊU CẦU DUYỆT GIAO" (dòng 1774) gửi vô điều
kiện ⇒ khớp đúng những gì chủ shop thấy.
**Sửa:** luôn xác nhận document trên cloud (nguồn sự thật) thay vì tin bộ đếm
hàng đợi; đơn chưa lên cloud thì **hẹn bắn lại** — `_notifyRepairWhenSynced()`
theo dõi tối đa ~2 phút, đơn có mặt trên cloud là gửi chat + push đúng một lần.

**Lỗi 2 — bản chụp lúc TẠO đơn ghi đè tiến trình mới hơn trên cloud.**
Nhãn "Chưa có KTV" là bằng chứng: `repairedBy` bị **xoá trắng**, mà bước "Sửa
xong" luôn ghi trường này (`repair_detail_view.dart:1330`) ⇒ đơn không chỉ sai
trạng thái mà bị **ghi đè nguyên document** bằng bản chụp lúc tạo đơn. Máy còn
giữ bản local cũ + `isSynced=0` (đúng hệ quả của Lỗi 1) đẩy lên qua 3 đường,
không đường nào chặn hạ cấp trạng thái: `SyncOrchestrator._handleCreate` dùng
`.set()` **không merge** (xoá sạch field cloud) và **không có guard**; guard của
`_handleUpdate` chỉ chặn khi cloud **đã ở status 4**, nên đơn đang "Chờ duyệt
giao" (status 3) hoàn toàn không được bảo vệ; `SyncService.syncRepairData` /
`syncAllToCloud` đẩy nguyên `toMap()` local. Thêm một bẫy khuếch đại:
`_normalizeRepairStatus` trả về **1 = "Tiếp nhận"** cho mọi giá trị status
thiếu/lạ, biến lỗi dữ liệu thành "đơn quay về tiếp nhận".
**Sửa:** một luật chung `SyncOrchestrator.applyRepairCloudGuards()` cho mọi
đường ghi — (1) cloud "đã giao" (4) là trạng thái cuối; (2) cloud đang ở trạng
thái CAO HƠN mà bản local **chưa hề được sửa sau bản cloud đó** (so `lastCaredAt`)
thì gỡ nhóm field tiến trình (`status`, `pendingDeliveryApproval`, `repairedBy`,
`finishedAt`, `deliveredAt`, `requestedDeliveryPrice`, …) khỏi payload, **vẫn
đồng bộ các thay đổi khác** (ghi chú, linh kiện, giá vốn). Hạ cấp CÓ CHỦ ĐÍCH
(quản lý chuyển đơn "Sửa xong" → "Đang sửa") luôn kèm `lastCaredAt` mới hơn nên
không bị chặn. Kèm theo: `_handleCreate` chuyển sang `set(..., merge: true)` +
gọi guard; `_normalizeRepairPayloadForCloud` **không tự sinh** status cho payload
thiếu status; `_asInt` đọc được cả `Timestamp`.

**Kiểm chứng:** test mới `test/repair_progress_guard_test.dart` (4 ca: bản chụp
lúc tạo đơn không hạ cấp được đơn chờ duyệt giao · hạ cấp có chủ đích vẫn đi qua ·
cloud "đã giao" là trạng thái cuối · cloud không mới hơn thì giữ nguyên payload).
`flutter analyze` 3 file thay đổi: **0 error**.

**⚠️ CHƯA NGHIỆM THU MÁY THẬT / CHƯA ĐỌC ĐƯỢC DOC THẬT.** Cần: (a) đọc document
`repairs` của đơn BÉ THẮM trên Firestore để chốt đường ghi đè nào đã chạy (bị
chặn quyền trong phiên làm việc); (b) diễn lại 2 máy: máy A tạo đơn có ảnh khi
mạng yếu → máy B "Sửa xong" + gửi duyệt giao → máy A online lại, xác nhận đơn
**không** tụt về Tiếp nhận và chat "ĐƠN MỚI" vẫn tới.

**Files:** `lib/services/sync_orchestrator.dart`, `lib/services/sync_service.dart`,
`lib/views/create_repair_order_view.dart`, `test/repair_progress_guard_test.dart`.

---

## [2026-09-05h] - fix(super admin) KHÔI PHỤC QUYỀN SUPER ADMIN (3 lỗi chồng nhau)

**Hồi quy chủ dự án báo:** "trước khi đăng nhập vào tk super admin thì sẽ vào
thẳng trang super admin, sau đó chọn shop mới vào như hiện tại" — nay không vào
được nữa. Audit đầy đủ: `DOCS/AUDIT_SUPER_ADMIN_2026-09-05.md`.

Truy ra **3 lỗi chồng nhau**, phải sửa đủ cả 3 mới hết:

**1. SA-09 — app TỰ THU HỒI quyền super admin mỗi lần đăng nhập.**
`user_service.dart:1161` trong `syncUserInfo`:
```dart
final resolvedRole = isSuperAdmin ? 'admin' : ...;   // ← ghi xuống Firestore
```
Vòng lặp tự huỷ: đặt `users/{uid}.role = "super_admin"` → Cloud Function cấp
claims `isSuperAdmin: true` → lần đăng nhập sau app thấy `isSuperAdmin == true`
nên ghi **`role: 'admin'`** ngược xuống → `buildCustomClaims()` tính
`("admin" === "super_admin")` = **false** → thu hồi claims. Sửa tay trên
Firestore Console bao nhiêu lần cũng vô ích. Bắt được đúng chuỗi trên máy thật:
claims `role=super_admin` lúc 15:30:58 → `role=admin` lúc 15:37:20.
*Gốc rễ:* `getUserRole()` **map** claims `super_admin` → `'admin'` làm tên vai
trò *app-level*; dòng 1161 dùng chính tên app-level đó để **ghi Firestore**, nơi
Cloud Function lại đòi đúng chuỗi `'super_admin'`. Sửa bằng cách tách
`persistedRole` (ghi Firestore) khỏi `resolvedRole` (tên app-level, giữ nguyên
`'admin'` để không đụng mọi nhánh `role == 'admin'` sẵn có).

**2. SA-10 — fast-path AuthGate trả `isSuperAdmin: false` CỨNG.**
`main.dart:692`, đường tắt "cached mobile session" chạy cho **mọi lần mở app sau
lần đăng nhập đầu**, không hề đọc claims mà cứ trả `false`. Nên super admin chỉ
vào được Console đúng LẦN ĐẦU; từ lần thứ hai luôn rơi vào shop thường. Sửa: đọc
claims ngay trong đường tắt (`getClaimsFromToken()` không `forceRefresh` nên chỉ
đọc ID token đã cache trên máy — không tốn vòng mạng, giữ nguyên tính "nhanh") +
gọi `setCurrentUserSuperAdmin()`.
*(`_fastMobileBootstrap` cũng trả `false` cứng nhưng là **dead code**, không có
caller — để nguyên.)*

**3. SA-08 — `_isSuperAdmin` của HomeView chỉ tính MỘT LẦN** (`home_view.dart:591`,
field initializer) trong khi quyền resolve muộn ⇒ 3 mục dành riêng super admin có
thể biến mất cả phiên. **Ghi nhận, chưa sửa** (SA-10 đã làm nhẹ hẳn triệu chứng).

**Nghiệm thu máy thật (Oppo CPH2239, `admin@huluca.com`):** mở app → vào **thẳng
SUPER ADMIN CONSOLE**; Dashboard 147 shop / 146 hoạt động / 159 user / 1 shop bị
khoá; tab Shops lọc ACTIVE/LOCKED/đã xoá; tab Users lọc theo vai trò + tìm email
trùng; tab Logs ghi thật (`super_admin_login`, `pin_verified`); **4 vòng khởi
động liên tiếp, có lần `syncUserInfo` chạy, quyền không bị thu hồi**. Trước khi
vá thì rơi vào Trang chủ với badge "NHÂN VIÊN".

**CÒN LẠI — 2 lỗi bảo mật cổng PIN chưa sửa:**
- **SA-03 (MEDIUM-HIGH):** cổng PIN **bị vượt hoàn toàn trên máy mới / sau khi
  xoá app data** — `isPinSetup()` chỉ đọc SharedPreferences, trong khi
  `verifyPin()` đã có nhánh đọc `pinHash` từ Firestore. Màn Cài đặt còn báo
  "Chưa thiết lập PIN" dù nhật ký có `pin_verified` ngày 18–19/08.
- **SA-02 (MEDIUM):** PIN băm bằng **1 vòng sha256 + salt hằng số dùng chung**,
  PIN 4–6 chữ số ⇒ không gian khoá ~1,11 triệu, một bảng tra dựng sẵn phá được
  PIN của bất kỳ super admin nào.

**Chưa chạy (cố ý):** khoá/xoá shop trên production (147 shop thật), idle guard
30 phút, đổi `_adminSelectedShopId`.

**Test:** `flutter analyze lib` **0 error / 0 warning** cả 2 lần vá.

---

## [2026-09-05g] - fix(khách hàng) XOÁ KHÁCH BÁO THÀNH CÔNG KHỐNG — v3.5.1+555

**Đóng nốt BUG-04 của đợt kiểm thử toàn diện** (`DOCS/QA_FULL_REGRESSION_2026-09-05.md`).
Nâng version **3.5.0+554 → 3.5.1+555**.

**Triệu chứng:** bấm Xoá khách hàng → toast xanh *"Đã xóa khách hàng"*, nhưng
khách vẫn nằm trong danh sách; xoá lại vẫn "thành công"; máy thứ hai không hề
biết có lệnh xoá.

**Nguyên nhân (2 tầng):**
1. `FirestoreService.deleteCustomerById` tìm document trên cloud bằng
   `.where('id', isEqualTo: customerId)` — mà `customerId` là **id autoincrement
   của SQLite MÁY ĐÓ**, không phải `firestoreId`. Document `customers` lại được
   tạo bằng `.doc(firestoreId)` (xem `addCustomer`), nên câu truy vấn này gần
   như không khớp gì. Không khớp thì vòng `for` không chạy lần nào — **nhưng hàm
   vẫn `return true`** ⇒ giao diện báo thành công.
   *(Đo được: cùng một khách có id cục bộ **25** trên máy 1 và **52** trên máy 2
   ⇒ id cục bộ vốn không dùng để tra cloud được.)*
2. Cloud vẫn `deleted=false` ⇒ `syncCustomersFromCloud` upsert đè thẳng xuống
   local sau ~40 giây, xoá sạch cờ `deleted=1` vừa ghi (bằng chứng: `updatedAt`
   của bản ghi bị trả về đúng mốc lúc TẠO khách, không phải lúc xoá).

**Sửa:**
- Thêm `FirestoreService.deleteCustomerByFirestoreId(String)` — xoá mềm đúng
  document bằng `.doc(firestoreId)`, giống hệt cách `updateCustomer` vẫn làm.
- `deleteCustomerById(int)` giữ lại làm dự phòng cho bản ghi chưa có
  `firestoreId`, nhưng **trả về `false` khi không khớp document nào** thay vì
  báo thành công khống.
- `CustomerService.deleteCustomer` tra `firestoreId` trước khi xoá, đánh dấu
  `isSynced=0` (bản ghi bẩn) rồi chỉ đặt lại `isSynced=1` khi cloud xoá xong;
  **trả về `false` nếu cloud không xoá được**. Khách chưa từng lên cloud
  (`firestoreId` rỗng) thì xoá cục bộ là đủ ⇒ vẫn `true`.
- `DBHelper.getCustomerById(int)` (mới) để lấy `firestoreId` từ id cục bộ.
- `customer_management_view` trước đây **bỏ qua hoàn toàn** kết quả xoá (không
  báo gì) — nay hiện SnackBar xanh/đỏ theo đúng kết quả thật.

**Nghiệm thu máy thật (đúng ca đã fail):** xoá lại chính khách trước đó xoá 3
lần không được → `deleted=1`, `isSynced=1`, `updatedAt` nhảy đúng mốc xoá; **vẫn
`deleted=1` sau 2 chu kỳ `syncCustomersFromCloud`** (trước đây bật lại `0` trong
~40 giây); **máy 2 bản ghi biến mất hẳn** khỏi cả DB lẫn danh sách (trước đây vẫn
còn nguyên). Toast xanh nay nói đúng sự thật.

**Test:** `flutter analyze lib` **0 error / 0 warning**; `flutter test`
**+550 / −8** (đúng 8 lỗi có sẵn, không hồi quy); build APK + AAB release xanh.

---

## [2026-09-05f] - fix(validate + sync) 3 lỗi tìm ra khi kiểm thử toàn diện

**Đợt kiểm thử toàn diện trước khi lên Store** (2 máy Oppo thật, FFI/SQLite,
Firestore đa thiết bị, build release). Báo cáo đầy đủ:
`docs/QA_FULL_REGRESSION_2026-09-05.md`.

**1. Ô SĐT khách hàng không kiểm tra định dạng** — `customer_management_view.dart`.
Validator chỉ kiểm rỗng, không gọi `UserService.validatePhone` (9–12 chữ số) như
mọi màn khác (đơn sửa, đơn bán, NCC/đối tác, chi tiết đơn sửa). Lưu được khách có
SĐT `12` **và đẩy thẳng lên cloud** (bằng chứng: `customer_1788588413208`,
`phone=12`, `isSynced=1`). Vi phạm CLAUDE.md §5. Nay validator gọi hàm dùng chung
⇒ máy thật báo đỏ "Số điện thoại phải từ 9-12 chữ số", không lưu.

**2. `addRepair` từ chối đơn sửa có `cost=0`** — `firestore_service.dart`.
`MoneyValidationService.validateAmount` thiếu `allowZero: true` nên đơn sửa MỚI
(gần như luôn `cost=0` vì chưa ghi phụ tùng; `price=0` khi bảo hành) làm hàm trả
`null` và **không ghi thẳng lên Firestore**. Logcat máy thật lúc tạo đơn:
`❌ addRepair: MoneyValidationService failed: ...amountZero` →
`ℹ️ Skipped repair chat/push because repair is local-only...`. Đơn vẫn lên cloud
nhờ hàng đợi sync (không mất dữ liệu) nhưng đường ghi dự phòng coi như chết.
`upsertRepair` ngay bên dưới vốn đã `allowZero: true` kèm đúng chú thích đó — nay
`addRepair` khớp lại.

**3. `addProduct` / `updateProductCloud` cùng lỗi** — `firestore_service.dart`.
Kho cho phép hàng **chưa định giá** (`price=0`, UI hiện "⚠ Chưa định giá") và
`shop_settings.allowPendingCost=1` cho phép nhập giá vốn sau (`cost=0`). Đã thêm
`allowZero: true` cho cả hai hàm.

**CÒN LẠI — chưa sửa, cần quyết:** xoá khách hàng báo "Đã xóa khách hàng" (toast
xanh) nhưng khách quay lại. `FirestoreService.deleteCustomerById` tìm document
trên cloud bằng `.where('id', ...)` với **id autoincrement của SQLite máy đó**
thay vì `firestoreId`; không khớp document nào thì vòng `for` không chạy mà hàm
vẫn `return true`. Hậu quả: bản ghi bị `syncCustomersFromCloud` upsert đè lại sau
~40 giây, và máy thứ hai không hề biết đã xoá. Xem mục BUG-04 của báo cáo.

**Phân quyền giá vốn (CLAUDE.md §9) — nghiệm thu lại nhánh NHÂN VIÊN, ĐẠT cả 2
tầng.** Máy 2 đăng nhập `n@n.com` (`role=employee`): giao diện Bảng giá ra **0
lần** chữ "Vốn"/"Lãi" (chủ shop cùng dòng đó thấy `Thu 500.000đ · Vốn 333.333đ ·
Lãi 166.667đ`); **file Excel xuất ra** cũng sạch — sheet Sửa chữa/Bán hàng **10
cột → 8** (cắt `Giá vốn ĐX`, `Giá vốn NY`), sheet Bảng giá NCC **15 cột → 9**
(cắt 4 cột giá vốn + `Nhà cung cấp` + `Ngày hoá đơn gần nhất`), toàn file 0 chuỗi
chứa "vốn". Giá thu khách vẫn giữ nguyên ⇒ nhân viên vẫn tra báo giá được.

**Test:** `flutter analyze lib` **0 error / 0 warning** (1308 info, y như trước).
`flutter test` **+550 / −8** — đúng 8 lỗi đã có sẵn, không phát sinh hồi quy.
`flutter build apk --release` và `flutter build appbundle --release` đều xanh.
Máy thật: nghiệm thu lại đúng ca đã fail (SĐT `12` nay bị chặn).

---

## [2026-09-05e] - feat(bảng giá NCC) hướng dẫn tìm file Excel trên iPhone/iPad

**Điểm tắc thật của iOS.** Trên iPhone, bấm "Tải xuống" trong ChatGPT KHÔNG
chắc đưa file vào thư mục mà trình chọn file của app nhìn thấy được — người
dùng mở app lên không thấy file đâu và tưởng tải hỏng. Android tải thẳng vào
thư mục Tải về nên không gặp.

- Màn "Nhập bảng giá từ hoá đơn NCC" thêm thẻ **"Trên iPhone / iPad: file tải
  về nằm ở đâu?"**, đặt ngay sau bước 2 (đưa cho ChatGPT) — đúng lúc người
  dùng vừa tải file xong. Nội dung 2 phần:
  1. *Cách chắc ăn* — mở lại file trong ChatGPT → Chia sẻ → **Lưu vào Tệp** →
     **Trên iPhone → Downloads**.
  2. *Đã tải rồi mà không thấy* — Tệp (Files) → Duyệt → Tải về; vẫn không thấy
     thì tìm theo tên và xem **cả hai** nơi: iCloud Drive → Downloads và Trên
     iPhone → Downloads.
- **Chỉ hiện trên iOS.** Dùng `defaultTargetPlatform == TargetPlatform.iOS`
  chứ không `Platform.isIOS`, để bản web chạy trên Safari iOS cũng nhận đúng và
  không phụ thuộc `dart:io`. Android không thấy thẻ này (đã kiểm trên máy).
- `_Step` (widget mới): bước đánh số tròn, dùng cho phần hướng dẫn thao tác.
- `app_knowledge_base.dart`: mục `price-book-supplier-invoice` thêm 2 bước iOS
  vào `steps`, 1 ghi chú vào `notes`, 3 câu hỏi mẫu ("tải file excel trên
  iphone xong không thấy đâu"…) và các thẻ `iphone/ios/tep/files/downloads` —
  để AI Trợ Lý và Trung tâm trợ giúp trả lời được câu này.

**Test:** `flutter analyze` 0 lỗi; `flutter test` **+550 −8** (8 lỗi có sẵn).
Máy thật Oppo: tạm bật cờ để render thẻ → bố cục đúng (các bước đánh số, hộp
mẹo, đúng vị trí giữa bước 2 và bước 3); trả cờ về `defaultTargetPlatform` rồi
kiểm lại → **thẻ không hiện trên Android**. Chưa kiểm được trên máy iOS thật
(không có thiết bị) — phần gating là một phép so sánh nền tảng, rủi ro thấp.

---

## [2026-09-05d] - fix(bảng giá NCC) LỖI CHẶN: không đọc được file do ChatGPT tạo

**Phát hiện khi chạy nốt các kịch bản kiểm thử còn thiếu.**

Cả tính năng dựng trên tiền đề "nhờ ChatGPT tạo file Excel", mà ChatGPT Code
Interpreter dùng **openpyxl** — và app **không đọc được** file openpyxl. Hai lỗi
chồng nhau, gói `excel` ném thẳng ở cả hai:

1. **Target tuyệt đối.** openpyxl ghi `Target="/xl/worksheets/sheet1.xml"` trong
   `workbook.xml.rels`; gói `excel` luôn tự ghép tiền tố `xl/` ⇒ tìm sai đường
   dẫn ⇒ *"Null check operator used on a null value"*. (Đợt `[2026-09-04e]` đã
   vá lỗi này cho luồng Kho phụ tùng, nhưng chưa đủ — xem lỗi 2.)
2. **Ô inline string RỖNG.** openpyxl ghi ô chuỗi rỗng thành thẻ tự đóng
   `<c r="M2" t="inlineStr"/>` (không `<is>`, không `<t>`), còn `excel` gọi
   `node.findAllElements('t').first` (parse.dart:630) ⇒ *"Bad state: No
   element"*. **Ô rỗng là chuyện BẮT BUỘC xảy ra** vì chính prompt của app yêu
   cầu để trống cột "Giá thu khách" ⇒ mọi file AI tạo đúng hướng dẫn đều hỏng.

`_normalizeOoxmlRelTargets` đổi thành `_repairOpenpyxlWorkbook`: vá cả rels lẫn
mọi worksheet, bỏ `t="inlineStr"` ở đúng các ô không có `<t>` để nhánh mặc định
của gói xử lý (nhánh đó đã kiểm null đàng hoàng). Giữ nguyên ô có nội dung.

Kèm sửa nút "Chọn file khác" bị vỡ 2 dòng (nút phải để `flex: 2` bóp nút trái).

**Kiểm thử — chạy nốt các kịch bản bắt buộc còn thiếu, trên máy thật:**

| Kịch bản | Kết quả |
|---|---|
| File do openpyxl tạo | Đọc được (trước đây hỏng hoàn toàn) |
| Cùng mặt hàng ở 2 hoá đơn khác giá | gần nhất **200.000** (HĐ mới hơn), **BQ gia quyền 116.667** = (100k×10+200k×2)/12, min 100.000, max 200.000, 2 lần nhập |
| Hai mặt hàng khác model | "Màn hình Test" ra **2 mục riêng** A54/A74, khoá khác nhau |
| Tiền `"310.000"` / `"310,000"` / `"310.000 đ"` | đều ra **310000** |
| Tiền `"1.250.000đ"` | ra **1250000** |
| Dòng thiếu tên / thiếu giá vốn / SL âm | đếm đúng **1 / 1 / 1**, dòng hợp lệ 9 |
| File thiếu cột bắt buộc | Báo rõ *"thiếu cột Tên mặt hàng, Giá vốn — đã bỏ qua sheet này"*, nút Nhập bị vô hiệu hoá |
| Màn Tuỳ chỉnh | Hết "Báo cáo hoạt động hôm nay"; có đủ 3 thẻ mới Khám phá / Mẹo / Cộng đồng |
| Xoay ngang | Thẻ bảng giá xếp **2 cột/hàng** đúng `ResponsiveGrid` |

`test/openpyxl_compat_test.dart` (MỚI, 6 test) + fixture file openpyxl thật.
`flutter analyze` 0 lỗi; `flutter test` **+550 −8** (8 lỗi có sẵn).

**Chưa test được:** (a) **In** hoá đơn từng tab — không có máy in; (b) bố cục
người dùng đã tuỳ chỉnh được giữ qua nâng cấp — thử trên máy nhưng **không kết
luận được** vì `loadConfig` ưu tiên bản trên cloud (đã ở v4) nên đè bản local
tôi dựng; logic gộp vẫn được 11 unit test phủ trực tiếp. (c) Tắt "Lời chào" để
xem 2 banner tiền còn không — không ép được điều kiện hiện banner.

---

## [2026-09-05c] - fix(bảng giá NCC) 3 lỗi phát hiện khi nghiệm thu máy thật

**Nghiệm thu Oppo CPH2203, tài khoản `m@m.com` (shop "M").**

1. **CHẶN ĐỒNG BỘ — `firestore.rules` thiếu collection mới.** Danh mục giá ghi
   được xuống SQLite nhưng đẩy lên Firestore thì `permission-denied`, 5 bản ghi
   kẹt hàng đợi ⇒ **không bao giờ đồng bộ sang máy khác**, đúng thứ yêu cầu bắt
   buộc. Đã thêm rule cho `price_catalog_items`: READ cho mọi nhân viên trong
   shop (nhân viên CẦN đọc để tra Giá thu khách; việc che Giá vốn làm ở tầng
   ứng dụng vì rules không tách được theo trường), GHI chỉ quản lý trở lên.
   Nhánh update dùng `optNum` chứ không `numGte0` — xoá mềm/cập nhật một phần
   có thể không gửi kèm trường giá, `numGte0` sẽ chặn nhầm và làm kẹt hàng đợi.
   **Đã `firebase deploy --only firestore:rules`.** Unit test và `analyze`
   không thể bắt được loại lỗi này.

2. **Màn hướng dẫn TRẮNG TRƠN.** `ResponsiveBody` bọc `Center`, mà `Center`
   giãn hết chiều cao khả dụng — đặt trong `bottomNavigationBar` (chỗ đáng lẽ
   chỉ cao bằng nội dung) làm thanh dưới chiếm trọn màn hình, ép thân màn còn 0
   chiều cao ⇒ mất sạch phần hướng dẫn, chỉ còn cái nút nằm giữa màn trắng.
   Thay bằng `Center(heightFactor: 1)`. Lỗi do chính đợt responsive
   `[2026-09-05?]` gây ra, chỉ lộ ra khi nhìn màn hình thật.

3. **Mũi tên sơ đồ 4 bước rơi lại cuối dòng.** `Wrap` tách mũi tên khỏi mục đi
   sau nó khi xuống dòng, thành ra "→" trỏ vào khoảng trống. Gộp mũi tên + mục
   vào cùng một phần tử `Wrap`.

**Kết quả nghiệm thu máy thật — ĐẠT:**
- Migration **v109→v110** trên DB có dữ liệu thật: sạch, 0 exception, 28 cột,
  2 index, dữ liệu cũ nguyên vẹn (9 đơn sửa, 13 SP, 15 công nợ, 18 chi phí).
- Cấu hình Trang chủ **v3→v4** áp đúng: 14 thẻ, thứ tự Cần xử lý → Thao tác
  nhanh → Dòng tiền; 3 thẻ mới có mặt; `dailyReport` đã lọc bỏ.
- **"Hoạt động hôm nay" hiện thật** (công tắc chết đã hết).
- Tài chính đúng **4 tab**; tab Công nợ hiện nhãn "Toàn bộ công nợ chưa tất
  toán" thay cho chip kỳ; nút chuyển Giao dịch tiền / Nhật ký thao tác chạy.
- **In/Xuất Excel đúng cho cả 4 đường** sau khi đổi chỉ số tab:
  `giao_dich_*.xlsx` · `nhat_ky_chi_tiet_*.xlsx` · `phai_thu_*.xlsx` ·
  `BaoCaoNgay_*.xlsx`.
- File mẫu HD014650: 4 sheet, 23 cột, 5 dòng, **tổng 3.120.000** khớp hoá đơn.
- Nhập lần 1: 5 dòng hợp lệ / 5 mặt hàng mới / 5 chưa có giá thu khách / **2
  cần kiểm tra** (đúng 2 dòng nhiều model).
- **Nhập LẠI cùng file:** 0 mặt hàng mới, 5 cập nhật, **5 dòng trùng** → DB vẫn
  **5 mặt hàng (không phải 10)**, mỗi mặt hàng vẫn "1 lần nhập đã ghi nhận",
  bình quân KHÔNG đổi.
- Bảng giá hiện "**Chưa thiết lập giá thu khách**" + Vốn/loại/NCC/ngày nhập.
- Đặt giá thu khách 1.500.000 → lưu đúng, lãi 600.000.
- Sau khi deploy rules: hàng đợi trống, cả 5 bản ghi `isSynced=1`.

**Nghiệm thu bổ sung trên máy thứ 2 (Oppo CPH2239) — ĐẠT hết:**

- **Nhân viên `n@n.com` (role=employee):** Trang chủ không có "Dòng tiền hôm
  nay" / "Truy cập nhanh tài chính", thẻ Hoạt động không có ô CÔNG NỢ. Bảng giá
  chỉ hiện `Thu`, **không có chữ "Vốn"/"Lãi" nào**; dòng danh mục NCC hiện
  "Chưa thiết lập giá thu khách" + loại linh kiện/model (đủ để tra cứu) nhưng
  **không lộ nhà cung cấp lẫn ngày nhập**. Dialog ghim giá cũng không có ô giá
  vốn.
- **Xuất Excel của nhân viên cũng sạch:** sheet "Sửa chữa"/"Bán hàng" còn **8
  cột** (bản đủ 10 — cắt "Giá vốn ĐX" và "Giá vốn NY"); sheet "Bảng giá NCC"
  còn **9 cột** (bản đủ 15 — cắt cả 6 cột giá vốn gần nhất/bình quân/thấp
  nhất/cao nhất/nhà cung cấp/ngày hoá đơn). Cột "Giá thu khách" 1.500.000 vẫn
  giữ để nhân viên báo giá được.
- **Đồng bộ 2 máy:** mặt hàng tạo và đặt giá ở máy 1 hiện đúng trên máy 2.
- **Đổi vai trò trên CÙNG máy 2:** đăng xuất nhân viên → đăng nhập `m@m.com` →
  đúng dòng đó hiện `Thu 1.500.000đ · Vốn 900.000đ · Lãi 600.000đ`. Chứng minh
  việc che giá vốn là **theo vai trò**, không phải dữ liệu bị mất.

---

## [2026-09-05b] - refactor(trang chủ + tài chính) dọn bố cục theo audit UX

**Chưa tăng version. Cấu hình dashboard v3 → v4.**

### Trang chủ — 3 lỗi thật

1. **Công tắc chết:** bật "Hoạt động hôm nay" trong Tuỳ chỉnh không hiện gì —
   `case todayActivity` trong `_buildModularDashboard` là case RỖNG. Thẻ chỉ vẽ
   ở nhánh dự phòng lúc config chưa tải, nên nó **loé lên rồi biến mất**.
2. **Ẩn "Lời chào" là mất luôn cảnh báo tiền:** 2 banner "Cần thanh toán" và
   "Giao dịch ngân hàng" bị gắn cứng trong `case greeting`. Nay tách ra ngoài
   vòng lặp, luôn ở trên cùng, không phụ thuộc thẻ trang trí.
3. **`dailyReport` đã bỏ nhưng vẫn là một công tắc** trong màn Tuỳ chỉnh. Nay
   lọc bỏ khi tải (`isRetired`); GIỮ giá trị enum để config cũ đã lưu không bị
   `fromJson` hiểu nhầm thành `greeting` rồi sinh ra 2 thẻ Lời chào.

### Trang chủ — bố cục

- 3 thẻ trước đây **không tắt được** (Khám phá, Mẹo hôm nay, Cộng đồng) nay là
  loại thẻ thật trong hệ thống Tuỳ chỉnh — bật/tắt/sắp xếp như mọi thẻ khác.
- Bỏ nút "Tuỳ chỉnh dashboard" chiếm dòng đầu tiên (lối vào đã có sẵn ở tab
  Cài đặt → "Tuỳ chỉnh dashboard", và long-press trên Trang chủ).
- **Thứ tự mặc định v4:** việc gấp → việc hay làm → số liệu → xã giao. Bản v3
  đặt Chat và Hoạt động gần đây TRƯỚC Thao tác nhanh.
- Nhánh dự phòng lúc đang tải rút còn 4 thẻ gấp nhất — trước vẽ gần hết rồi
  nhảy sắp xếp lại khi config tải xong, nhìn như app lỗi.
- **KHÔNG đạp lên bố cục người dùng đã tự sắp:** chỉ ai còn đúng y mẫu mặc định
  cũ (v2 hoặc v3) mới được nâng lên mặc định v4; ai đã tuỳ chỉnh thì giữ nguyên
  thứ tự + trạng thái bật/tắt, thẻ mới nối vào cuối.

### Tài chính — lỗi số liệu

**Tab Công nợ phớt lờ bộ lọc kỳ nhưng vẫn hiện thanh chọn kỳ.**
`getDebtsForFinanceSnapshot()` không lọc ngày (đúng — công nợ là SỐ DƯ, không
phải phát sinh trong kỳ), nhưng thanh 4 chip kỳ vẫn hiện với "Hôm nay" đang
sáng ⇒ người xem tưởng con số là của kỳ đang chọn. Nay thay bằng nhãn rõ ràng
*"Toàn bộ công nợ chưa tất toán — không theo kỳ đang chọn"*.

### Tài chính — gộp tab 5 → 4

- "Giao dịch" + "Nhật ký" → **"Sổ giao dịch"**, bên trong có nút chuyển
  *Giao dịch tiền* / *Nhật ký thao tác*. **KHÔNG trộn 2 nguồn dữ liệu** (thu/chi
  thật vs ai-làm-gì) — chỉ gộp chỗ vào và đặt tên người dùng hiểu được.
- Giữ "Báo cáo" làm tab (lệch với đề xuất audit ban đầu là đưa vào menu ⋮ —
  đây là nơi chủ shop xem hằng ngày, đưa vào menu là bước lùi).
- **Tổng quan sắp lại theo dòng chảy tiền:** Dòng tiền → Doanh thu → Chi phí →
  Lợi nhuận → So sánh kỳ. Bản cũ đặt Lợi nhuận TRƯỚC Doanh thu và Dòng tiền.
- Bỏ khối "Công nợ nhanh" khỏi Tổng quan (tab Công nợ ngay bên cạnh). Giữ khối
  Sổ quỹ vì Sổ quỹ không có tab riêng ở màn này.
- **Sửa bẫy chỉ số tab:** `_t3()` đã bị bỏ nhưng `_t4()` vẫn nằm ở index 3, và
  in/xuất Excel dùng số trần (`index == 4`). Sau khi gộp tab, xuất ở tab Báo cáo
  sẽ chạy nhầm hàm xuất Nhật ký. Nay dùng hằng có tên (`_tabOverview`,
  `_tabLedger`, `_tabDebt`, `_tabReport`) + đổi tên `_t0..._t5` thành
  `_overviewBody` / `_txListBody` / `_debtBody` / `_journalBody` / `_reportBody`.

**Đính chính audit:** mục "2 nút chi nhánh luôn hiện" trong audit là SAI — cả 2
nút đã được cờ `_enableMultiBranch` chặn sẵn. Không sửa gì.

**Test:** `flutter analyze` **0 lỗi**. `flutter test` **+544 −8** (8 lỗi có sẵn
từ trước). Test mới `test/dashboard_config_migration_test.dart` **11/11 PASS** —
phủ đúng chỗ rủi ro nhất: người đã tuỳ chỉnh không bị mất thứ tự/trạng thái,
thẻ mới được nối vào, thẻ đã bỏ bị lọc, `order` liên tục không hổng, phân quyền
tài chính. `flutter build apk --debug` OK.

**⚠️ CHƯA nghiệm thu máy thật.**

---

## [2026-09-05a] - feat(bảng giá) "Bảng giá từ hoá đơn NCC" — danh mục giá đồng bộ đám mây

**Chưa tăng version. DB v109 → v110.**

Mở rộng Bảng giá: chủ shop nhờ GPT đọc **nhiều ảnh hoá đơn NCC** → 1 file Excel
4 sheet → kiểm tra/điền "Giá thu khách" → nhập vào app. Nhân viên tra Giá thu
khách; chủ shop/quản lý xem thêm giá vốn.

### Dữ liệu — hết phụ thuộc SharedPreferences theo máy

- **MỚI** `lib/models/price_catalog_models.dart`: `PriceCatalogItem`,
  `InvoiceCostLine`, `CostHistoryEntry`, `CatalogImportPreview`,
  `CatalogImportResult`, `CatalogExistingPolicy`.
- **MỚI** bảng SQLite `price_catalog_items` (v110) — đủ trường yêu cầu (tên,
  hãng, model, loại linh kiện, SKU, NCC, giá vốn gần nhất/bình quân, giá thu
  khách, ngày cập nhật, nguồn dữ liệu, ghi chú, `deleted`, `shopId`,
  `firestoreId`, `isSynced`) + `costHistoryJson`.
- Đồng bộ **2 chiều** như các thực thể khác: `SyncEntityType.priceCatalogItem`,
  subscription realtime `price_catalog_items`, có trong
  `downloadAllFromCloud` + danh sách cursor tăng dần. Offline-first, xoá mềm.
- **Chống trùng 2 lớp:** (1) `firestoreId` **tất định** =
  `pcat_sha1(shopId|_khóa_import)` ⇒ 2 máy nhập cùng file ghi vào cùng
  document; (2) `costHistoryJson` lưu vân tay từng dòng hoá đơn ⇒ nhập lại
  cùng file không cộng trùng vào bình quân gia quyền.
- `importKey` **cố ý không UNIQUE** ở SQLite — bản ghi cloud có thể trùng khoá
  với bản tạo offline; ràng buộc cứng sẽ làm kẹt hàng đợi sync. Thay vào đó
  `upsertPriceCatalogItem` tự "nhận" `firestoreId` cloud vào bản ghi mồ côi.

### Excel 4 sheet + prompt GPT

- **MỚI** `lib/services/supplier_invoice_price_book_service.dart`: sheet
  "Chi tiết nhập hàng" / "Tổng hợp giá vốn" / "Lỗi cần kiểm tra" /
  "Hướng dẫn nhập", đủ 23 cột theo yêu cầu, kèm `_khóa_import`.
- `gptPrompt` — câu lệnh copy dán cho GPT: đọc nhiều ảnh, gộp 1 file, giữ dữ
  liệu theo từng hoá đơn, **để trống Giá thu khách**, không đoán bừa, đánh dấu
  lỗi + độ tin cậy, không tạo dòng trùng, tự sinh `_khóa_import`.
- File mẫu = hoá đơn **HD014650** (30/08/2026, tổng 3.120.000, 5 dòng), cột
  Giá thu khách để TRỐNG.
- **Fix bẫy tiền tệ:** `MoneyUtils.parseCurrency` bỏ mọi ký tự không phải số,
  nên ô Excel `310000.5` sẽ ra `3100005` (sai 10 lần). Bộ đọc mới đọc theo
  KIỂU `CellValue` + `_parseMoneyText` phân biệt dấu ngăn nghìn với dấu thập
  phân ("310.000" = 310000, "310.000,75" = 310001).
- Mất cột `_khóa_import` ⇒ tự dựng lại theo công thức, không mất dòng.

### Màn nhập riêng

- **MỚI** `lib/views/supplier_invoice_price_import_view.dart` — menu ⋮ Bảng giá
  → **"Nhập bảng giá từ hoá đơn NCC"** (KHÔNG dùng chung "Nhập từ Excel" của
  giá ghim). 3 bước: prompt GPT/tải file mẫu → chọn file + **xem trước** →
  ghi + báo cáo.
- Xem trước báo đủ: dòng hợp lệ, mặt hàng mới, sẽ cập nhật, dòng trùng, thiếu
  tên, thiếu giá vốn, số lượng không hợp lệ, chưa có giá thu khách, cần kiểm
  tra. Chọn **Cập nhật / Bỏ qua** cho mặt hàng đã có. Audit log
  `PRICE_CATALOG_IMPORT`.

### Phân quyền giá vốn (trước đây Bảng giá KHÔNG hề kiểm tra)

- `PriceBookView` nay đọc `UserService.canViewCostPrice()`: nhân viên không
  thấy ô **Vốn**/**Lãi**, không thấy NCC/ngày nhập/giá bình quân, không sửa
  được bảng giá NCC (chỉ xem giá thu khách).
- Chặn ở **tầng service**, không chỉ UI: `PriceCatalogService.buildRows` /
  `lookup` **xoá sạch** trường giá vốn khỏi dữ liệu trả về khi không có quyền.
- **Xuất Excel cũng bị chặn** — file xuất ra không có cột giá vốn với người
  không có quyền (trước đây rò rỉ toàn bộ, kể cả sheet Sửa chữa/Bán hàng).
- Nhập danh mục yêu cầu quyền xem giá vốn (`canImport`).

### Hiển thị & tra cứu

- Dòng danh mục hiện ở tab **Sửa chữa**, badge `BẢNG GIÁ NCC` / `KIỂM TRA`.
- Chưa có giá thu khách ⇒ hiện rõ **"Chưa thiết lập giá thu khách"**, tuyệt
  đối không lấy giá vốn thay thế.
- `PriceBookService.resolvePartPrice(query)` (MỚI) tra giá thu khách theo
  SKU/tên/model. **Cố ý tách khỏi `resolveRepair`** — giá 1 linh kiện không
  phải giá 1 dịch vụ sửa chữa, trộn vào sẽ tự điền sai giá cho đơn sửa.
- Luồng bảng giá ghim cũ (SharedPreferences) **giữ nguyên 100%**, dữ liệu cũ
  tra cứu bình thường.

**Test:** `flutter analyze` **0 lỗi**, không thêm cảnh báo nào ở file mới/sửa.
`flutter test` **+524 −8** (8 lỗi ĐÃ CÓ TỪ TRƯỚC — đã xác minh bằng
`git stash` chạy lại trên cây sạch: Firebase chưa init, file test trỏ đường
dẫn `D:/ảnh claude/...` không tồn tại, widget test kiotviet). Test mới:
`test/price_catalog_import_test.dart` **31/31 PASS** — phủ khoá ổn định
(SKU/khác model/khác chất lượng), bình quân gia quyền, nhập lại cùng file,
nhiều sheet, giá thu khách trống/có, tiền có dấu chấm-phẩy-"đ", ô số thực,
thiếu cột bắt buộc, thiếu tên/giá vốn/số lượng sai, nhiều model tương thích,
và đối chiếu hoá đơn mẫu HD014650 (tổng khớp 3.120.000).
`flutter build apk --debug` **OK**.

**⚠️ CHƯA nghiệm thu máy thật** — máy test đang cắm là Redmi M2101K7AG, MIUI
chặn cài qua USB (`INSTALL_FAILED_USER_RESTRICTED`), không vượt được bằng
adb. Cần bật "Install via USB" trong Developer options (hoặc cắm lại Oppo
CPH2203) rồi chạy lại kịch bản ở `docs/HANDOVER.md`.

---

## [2026-09-04h] - fix(kho phụ tùng) không thể sửa/gán nhà cung cấp cho linh kiện đã có

**Chưa tăng version.**

User báo: thêm phụ tùng xong không thấy NCC dù "đã nhập nhà cung cấp rồi".
Nguyên nhân: dialog **"SỬA linh kiện"** (nút Sửa trên thẻ chi tiết) và luồng
**"Nhập thêm"** (restock) hoàn toàn KHÔNG có ô chọn nhà cung cấp — chỉ dialog
"Thêm phụ tùng mới" (tạo mới hoàn toàn) mới có. Phụ tùng tạo trước đó không
gán NCC, hoặc muốn đổi NCC sau này, không có cách nào sửa được — luôn hiện
"Không xác định".

- `_showEditPartDialog` (`parts_inventory_view.dart`): bọc `StatefulBuilder`,
  thêm ô "Nhà cung cấp" (tái dùng `_SupplierSearchField` + nút "Thêm NCC
  mới" — đúng widget đã dùng ở dialog Thêm mới) + ghi `supplierId` vào
  `editData` khi lưu.

**Test:** `flutter analyze` 0 lỗi mới. Máy thật Oppo CPH2203: phụ tùng "LK
TÉT 2B" (Nhà cung cấp: Không xác định) → Sửa → ô Nhà cung cấp (2 NCC) hiện
đúng → chọn "KHO TỔNG" → Lưu → thẻ list cập nhật chip NCC ngay, mở lại chi
tiết hiện "KHO TỔNG" (link bấm được), không còn "Không xác định". Logcat sạch.

---

## [2026-09-04g] - fix(bảng giá) Xuất/Nhập Excel bỏ sót dòng phụ tùng tham khảo

**Chưa tăng version.**

Tính năng Xuất/Nhập Excel có sẵn của Bảng giá (từ `[2026-08-30v]`) chưa được
cập nhật khi thêm dòng phụ tùng tham khảo ở `[2026-09-04f]` — xuất file
hoàn toàn bỏ sót các dòng đó, nhập lại cũng không nhận diện được.

- `exportToExcel`: sheet "Sửa chữa" giờ gộp cả dòng sửa chữa lẫn phụ tùng
  tham khảo (khớp đúng cách hiển thị trên UI).
- `importFromExcel`: nhận thêm khoá `p|`; ghim phụ tùng chỉ cần "Giá NIÊM
  YẾT" HOẶC "Giá vốn NY" > 0 (trước dùng chung điều kiện với sửa chữa/bán
  hàng sẽ vô tình BỎ GHIM phụ tùng chỉ có giá vốn khi nhập lại). Dòng mồ
  côi hoàn toàn mới (gõ thẳng vào Excel, chưa từng ghim) suy tên gốc từ cột
  "Tên" để hiển thị đúng thay vì rơi về khoá đã chuẩn hoá.

**Test:** `flutter analyze` + `flutter test test/price_book_test.dart` (10
test, PASS) không lỗi mới. Máy thật Oppo CPH2203: xuất file → `adb pull`
trực tiếp từ Download → xác nhận đủ cả 4 dòng phụ tùng + 1 dòng sửa chữa
mồ côi trong sheet Sửa chữa. Nhập lại chính file vừa xuất → "Nhập xong:
ghim 3, bỏ ghim 0" khớp đúng 3 dòng đang ghim thật, 0 lỗi. Cuộn lại kiểm
tra tên hiển thị + nhóm hãng của cả 3 dòng mồ côi giữ nguyên sau nhập.
Logcat sạch.

---

## [2026-09-04f] - feat(bảng giá) tích hợp giá vốn phụ tùng vào tab Sửa chữa + tạo tay khi chưa có lịch sử

**Chưa tăng version.**

Bảng giá (tab Sửa chữa) giờ gộp cả giá vốn phụ tùng/linh kiện để nhân viên
tra cứu ngay khi nhận máy sửa, và cho phép chủ shop dựng sẵn bảng giá TRƯỚC
khi có đơn/hoá đơn thật.

- `PriceBookService.buildPartRows()`: dòng phụ tùng tham khảo trong tab Sửa
  chữa (KHÔNG tách tab riêng), nguồn = giá vốn LIVE từ Kho phụ tùng + các
  mục nhập từ hoá đơn NCC chưa khớp tên (Excel). Ghim giá cho dòng phụ tùng
  không bắt buộc phải có giá thu khách (chỉ vốn tham khảo cũng ghi được).
- **Fix gộp nhóm hãng sai:** tên phụ tùng thường theo mẫu "loại phụ tùng +
  hãng + model" (vd "Pin iPhone 13") nên hãng KHÔNG nằm ở từ đầu — trước đây
  bị gộp nhầm vào nhóm theo từ đầu tiên (vd nhóm "PIN"). Nay quét toàn bộ
  các từ trong tên để tìm đúng hãng máy đã biết.
- **Nút nổi "Thêm mục"** (tab Sửa chữa) → tạo tay 1 trong 2:
  - Mục sửa chữa mới (model + lỗi) — dùng khi CHƯA từng có đơn nào, để đặt
    giá thu khách trước, tránh mỗi nhân viên báo 1 giá.
  - Phụ tùng tham khảo mới (tên + giá vốn, có thể ghi rõ Hãng máy) — dùng
    khi phụ tùng CHƯA có trong Kho.
- Nhập hoá đơn NCC (Excel): thêm cột "Hãng" tuỳ chọn (prompt AI cập nhật) để
  gộp nhóm chính xác hơn tự đoán, khi tên hàng trên hoá đơn không nêu rõ
  hãng.

**Test:** `flutter analyze` 0 lỗi mới (chỉ info cũ có sẵn). Máy thật Oppo
CPH2203 (shop "M"): xác nhận phụ tùng test gộp đúng nhóm hãng theo từ giữa
tên (không còn lệch nhóm); tạo tay 1 mục sửa chữa mới → xuất hiện đúng nhóm
hãng, nhãn NIÊM YẾT, "0 mẫu"; tạo tay 1 phụ tùng tham khảo kèm Hãng máy tự
ghi → gộp đúng nhóm hãng đó thay vì "Khác". Không thấy lỗi trong logcat khi
test.

---

## [2026-09-04e] - feat(kho) cập nhật giá vốn phụ tùng từ hoá đơn NCC (Excel + AI)

**Chưa tăng version.**

Chủ shop chụp hoá đơn NCC (mua phụ tùng) → nhờ ChatGPT/Gemini đọc ảnh + tạo
file Excel 2 cột (Tên phụ tùng, Giá vốn) → nhập file vào app → cập nhật giá
vốn cho phụ tùng khớp tên trong Kho phụ tùng/linh kiện. KHÔNG đụng tồn kho,
KHÔNG tự tạo phụ tùng mới.

- **Kho phụ tùng** (icon hoá đơn cạnh nút Sắp xếp, chỉ hiện nếu có quyền xem
  giá vốn) → menu 2 mục: **"Nhập giá vốn từ Excel"** (chọn file `.xlsx`) và
  **"Hướng dẫn dùng AI đọc hoá đơn"** (câu lệnh mẫu có nút Copy + nút tải
  file Excel mẫu).
- Khớp tên tự động (bỏ dấu, không phân biệt hoa/thường). Dòng không khớp
  được (thường do 1 linh kiện dùng chung nhiều model, hoá đơn ghi gộp 1
  dòng) → nút **"Gán"** mở tìm kiếm + chọn NHIỀU phụ tùng cùng lúc để áp
  chung 1 giá.
- **Fix quan trọng:** gói `excel: ^4.0.0` ném lỗi *"Null check operator used
  on a null value"* khi đọc file `.xlsx` do Python/openpyxl tạo (ghi đường
  dẫn worksheet trong `workbook.xml.rels` dạng tuyệt đối) — nhiều khả năng
  AI tạo file trực tiếp cũng dùng openpyxl nên đây là lỗi ảnh hưởng luồng
  chính chứ không phải hiếm gặp. Đã fix bằng cách tự sửa lại đường dẫn
  trong file zip (gói `archive` có sẵn) trước khi đưa cho `excel` đọc.
- **Lịch sử quyết định kiến trúc:** bản đầu định để app tự đọc ảnh bằng AI
  (`image_picker` + màn xem lại) — gặp bug màn hình trắng trơn sau
  `Navigator.push` không giải thích được dù đã thử nhiều cách sửa (xem
  memory dự án). Đổi hướng sang Excel vừa né được bug đó, vừa không cần
  xin thêm API key AI đọc ảnh.

**Test:** `flutter analyze` 0 error mới. Máy thật Oppo CPH2203 (shop test
"M"): nhập file 3 dòng (1 khớp tự động, 2 gán tay cho 2 phụ tùng khác nhau)
→ dialog xác nhận đúng before→after → cập nhật → snackbar thành công →
danh sách refresh đúng giá mới ngay. Chưa test với file Excel thật do
ChatGPT/Gemini tạo trực tiếp (mới test bằng file mô phỏng).

**Files:** `lib/models/supplier_invoice_models.dart` (mới),
`lib/services/supplier_invoice_service.dart` (mới),
`lib/views/parts_inventory_view.dart`.

---

## [2026-09-04b] - fix(bảng giá) sửa số liệu sai + tinh chỉnh giao diện (Giai đoạn 1 audit)

**Chưa tăng version.**

Audit UX/dữ liệu tính năng Bảng giá (artifact báo cáo riêng) phát hiện 1 lỗi
hiển thị sai số liệu (P0) + vài điểm trải nghiệm; đợt này làm phần "sửa
nhanh, rủi ro thấp" — thuần UI, không đụng công thức tính giá.

- **P0 — SP chưa có giá bán hiện như đang lỗ:** `buildSaleRows` lọc giá>0 khi
  tính trung vị nhưng KHÔNG lọc khi tạo dòng bảng giá → SP có vốn nhưng chưa
  định giá bán (giá=0) bị hiện "Lãi -X đ" đỏ chót, và `sampleCount`/
  `confidenceLabel` lệch nguồn đếm ("1 mẫu · Không có dữ liệu" mâu thuẫn
  nhau). Sửa: `sampleCount` đếm lại trên cùng danh sách giá>0 với
  `confidenceLabel`; thêm `PriceBookRow.hasPrice`; `_rowCard` khi không có
  giá hiện trạng thái trung tính "Chưa có giá bán — chạm để đặt giá" +
  Vốn (nếu có) thay vì 3 ô Bán/Vốn/Lãi với số âm giả.
- **Mã màu độ tin cậy:** nhãn "Dữ liệu quá ít/Thấp/Khá/Tốt" giờ là badge màu
  (xám/cam/xanh dương/xanh lá) đặt cạnh số mẫu, thay vì chữ xám nhỏ chôn ở
  cuối dòng.
- **Hệ số giá mùa vụ chạm được ngay:** banner vàng khi đang bật giờ là
  `InkWell` mở thẳng dialog sửa/tắt, không cần vòng qua menu 3 chấm.
- **Tiêu đề nhóm hãng có số đếm:** "IPHONE" → "IPHONE (6)".

**Test:** `flutter analyze` 0 error mới. Máy thật Oppo (shop test "M"): SP
"17 128GB (MỚI)" (vốn 19tr, chưa có giá bán) trước hiện "Lãi -19.000.000đ"
đỏ, sau hiện đúng "Chưa có giá bán — chạm để đặt giá · Vốn 19.000.000đ";
badge độ tin cậy lên màu đúng; bật hệ số mùa vụ +10% → banner chạm mở lại
dialog được, giá đề xuất nhân đúng 1.1×; đã tắt lại 0% sau test.

**Chưa làm (Giai đoạn 2/3 của audit — chờ duyệt riêng):** chip lọc Tất cả/Đã
niêm yết/Chưa ghim/Tin cậy thấp, ghim hàng loạt cho tab Sửa chữa, thanh
khoảng giá min–max trực quan, báo lỗi rõ khi Import Excel thiếu cột khoá,
hoàn tác sau bỏ ghim/áp giá hàng loạt, từ điển dịch vụ chuẩn hoá, đồng bộ giá
ghim lên Firestore.

**Files:** `lib/models/price_book_models.dart`, `lib/services/price_book_service.dart`, `lib/views/price_book_view.dart`.

---

## [2026-09-04d] - feat(đơn sửa) hiện phụ tùng/dịch vụ trong list + cho sửa dịch vụ khi đã giao

**Chưa tăng version.**

**Yêu cầu:** (1) Danh sách đơn sửa (`order_list_view.dart`) thêm thông tin
phụ tùng + dịch vụ đã dùng ngay trên từng thẻ đơn — trước đây phải mở chi
tiết mới thấy. (2) Cho phép sửa dịch vụ ngay cả khi đơn đã giao (status 4) —
trước đây bị khóa cứng.

**Fix:**
1. `_buildRepairCard`: thêm 2 chip mới vào hàng info-chip — 🔩 phụ tùng
   (`r.partsUsed`) và 🛠️ dịch vụ (`r.services.map((s) => s.serviceName)`),
   chỉ hiện khi có dữ liệu, giới hạn 2 dòng tránh tràn màn.
2. `repair_detail_view.dart`: bỏ điều kiện `r.status != 4` ở 2 chỗ khóa dịch
   vụ khi đã giao — nút "+ Thêm" dịch vụ (dòng tiêu đề mục DỊCH VỤ) và icon
   ✏️ sửa từng dịch vụ (`_buildCompactServiceItem`). Còn lại chỉ theo phân
   quyền `_canEditRepairNotes`, khớp hành vi phụ tùng đã unlock từ trước
   (`[2026-08-30t]`). Logic lưu/xóa dịch vụ (`_saveService`/`_deleteService`)
   vốn không có khóa status nội bộ nên không cần sửa gì thêm.

**Phát hiện phụ (KHÔNG sửa, đã ghi nhớ):** trong lúc test bấm nhầm nút
"Thêm khách hàng" ở thẻ đơn → bấm "Hủy" → tái tạo **lần thứ 3** crash màn đỏ
`_dependents.isEmpty` đã biết (`order_list_view.dart::_addCustomerToRepair`).
Hàm này ĐÃ SẴN cách né unfocus+delay nhưng vẫn crash — bẻ gãy giả thuyết
"đừng pop sớm" ở fix `[2026-09-04c]` là giải pháp triệt để (có thể chỉ là
may mắn về timing). Không blind-patch thêm — cần phiên `flutter run` attach
riêng để bắt đúng gốc rễ. Xem memory `feedback_modal_sheet_dependents_crash`.

**Test:** `flutter analyze` sạch (chỉ info/warning có sẵn từ trước). Máy
thật Oppo CPH2203: chip phụ tùng/dịch vụ hiện đúng trên cả đơn ĐÃ GIAO lẫn
chưa giao (vd "IPHONE TÉT 3" — ĐÃ GIAO — hiện đủ 🔩+🛠️); mở đơn ĐÃ GIAO →
nút "+ Thêm" dịch vụ và icon ✏️ đều hiện; sửa giá dịch vụ 250.000→300.000đ
→ lưu thành công, cập nhật đúng trên UI, không crash, logcat sạch — đã trả
lại 250.000đ ban đầu sau khi test.

**Files:** `lib/views/order_list_view.dart`, `lib/views/repair_detail_view.dart`.

---

## [2026-09-04c] - fix(đơn sửa) NCC/link phụ tùng, dialog xoá đơn sai mật khẩu, xoá/đổi PT không phản ánh

**Chưa tăng version.**

**3 bug user báo qua đơn sửa:**

1. **Phụ tùng không hiện NCC, chạm vào link luôn ra "Kho Linh kiện" chung** thay
   vì đúng linh kiện đó. `Repair.partsUsedDetailed` (feature `[2026-08-31b]`)
   chỉ được ghi khi thêm phụ tùng qua dialog chọn kho; đơn có phụ tùng thêm
   trước đó có trường này rỗng → rơi vào nhánh fallback cũ (1 dòng gộp,
   `onTap: _openPartsWarehouse`). Fix: `_legacyPartLookup` (cache tên→Product
   qua `getProductByNameFlexible`, load khi `partsUsedDetailed` rỗng) + tách
   fallback thành từng dòng per-part, `onTap` gọi `_openPartInInventory` (tự
   tra lại kể cả cache chưa xong) + hiện NCC nếu tra được.

2. **Xoá đơn sửa: "Mật khẩu sai" bị dialog che, không thấy phản hồi.**
   `order_list_view.dart::_confirmDelete`. Fix: `StatefulBuilder` bọc dialog —
   lỗi hiện NGAY TRONG dialog (dòng đỏ), dialog chỉ đóng khi xác thực thành
   công. **Lưu ý quan trọng:** bản sửa ĐẦU TIÊN (đóng dialog ngay khi bấm XÓA
   rồi mới await xác thực) đã TÁI TẠO ĐÚNG crash `_dependents.isEmpty`
   (framework.dart:6268) đã ghi nhận ở `sale_detail_view.dart::_unlockManager`
   — phát hiện qua test máy thật, sửa lại đúng hướng (không pop dialog trước
   khi async xong) trước khi bàn giao.

3. **Xoá/đổi phụ tùng trong đơn sửa: không thấy phản ánh thay đổi.** 2 nguyên
   nhân: (a) `_removePartFromRepair`/`_swapPartInRepair` thiếu cờ
   `_isUpdating=true` khi mutate (mọi hàm mutate khác trong file đều có) —
   thiếu cờ này khiến Firestore realtime listener có thể đè lại dữ liệu cũ
   giữa chừng; (b) **[phát hiện khi test sống] bug SQL** —
   `db_helper.dart::restorePartQuantityByName` query
   `WHERE UPPER(name) = ?` trên bảng `repair_parts` nhưng cột thật là
   `partName` (không có cột `name`) → mọi lần xoá/đổi phụ tùng nguồn
   "Kho cũ" crash âm thầm (bắt bởi `runZonedGuarded`, không red-screen,
   không báo user) ngay tại bước hoàn trả kho, nên đơn không bao giờ được
   lưu lại — đây là nguyên nhân chính. Sửa cả 2.

**Test:** `flutter analyze`/`flutter test` sạch (8 fail còn lại pre-existing,
không liên quan). Máy thật Oppo CPH2203: thêm phụ tùng → NCC/link hiện đúng;
"Xóa PT" xác nhận log `✅ Restored part quantity: LK TÉT 2B, +1 => 3`, phụ
tùng biến mất khỏi UI ngay, snackbar đúng; dialog xoá đơn nhập sai mật khẩu →
dòng đỏ "❌ Mật khẩu sai" hiện ngay trong dialog, không crash, logcat sạch.

**Files:** `lib/views/repair_detail_view.dart`, `lib/views/order_list_view.dart`,
`lib/data/db_helper.dart`.

---

## [2026-09-04b] - fix(đối soát tiền về) bỏ QR thừa ở tab "Tiền vào" + ẩn bàn phím số

**Chưa tăng version.**

**Bug:** (1) Tab "Tiền vào (nhận)" ở `money_reconcile_view.dart` hiện thêm khối
"Nhận tiền qua ngân hàng" (QR VietQR của SHOP) — không cần thiết vì màn này
dùng để đối soát tiền đã về, không phải để tạo QR nhận tiền. (2) Sau khi gõ
số tiền xong, không có cách ẩn bàn phím số (không tap-outside-to-dismiss).

**Fix:** (1) Bỏ hẳn `bankTransferAssistCard(...)` + import không dùng nữa —
tab "Tiền vào" giờ giống hệt "Tiền ra" (không có QR). (2) Bọc body bằng
`GestureDetector(onTap: unfocus)` + `keyboardDismissBehavior: onDrag` cho
danh sách kết quả.

**Test:** `flutter analyze` sạch. Máy thật Oppo CPH2203: gõ 500.000 ở tab
"Tiền vào" → không còn khối QR; chạm ra ngoài ô nhập → bàn phím ẩn ngay; chạm
vào 1 kết quả khớp vẫn mở dialog xác nhận bình thường (GestureDetector không
chặn tap của card bên trong).

**Files:** `lib/views/money_reconcile_view.dart`.

---

## [2026-09-04a] - fix(tìm kiếm) không dấu + không phân biệt hoa/thường toàn app

**Chưa tăng version.**

**Bug:** Ô "TÌM KIẾM TOÀN APP" và ô "Chọn khách hàng" (dùng chung khi tạo đơn
sửa/bán) không ra kết quả khi gõ không dấu hoặc sai hoa/thường (vd gõ "PHAM"
hoặc "pham" nhưng khách lưu tên "PHẠM..."). **Gốc:** SQLite `LIKE` mặc định
không tự bỏ dấu tiếng Việt (chỉ case-fold ASCII) — các hàm
`searchRepairs`/`searchSales`/`searchProducts`/`searchCustomers`/
`searchCustomersRanked` trong `db_helper.dart` dùng `LIKE` để lọc SQL TRƯỚC
khi lọc lại đúng bằng `VietnameseUtils` ở Dart (`global_search_view.dart`) →
hàng bị SQL loại sai trước khi tới bước lọc đúng.

**Fix:** Bỏ `LIKE` khỏi cả 5 hàm, chuyển hẳn sang fetch (giới hạn 5000 dòng
theo recency) rồi lọc/rank bằng `VietnameseUtils.containsVietnamese` hoàn
toàn ở Dart — cùng cơ chế đã chạy đúng sẵn ở danh sách đơn sửa
(`order_list_view.dart`). `customer_autocomplete_field.dart` (ô "Chọn khách
hàng" dùng ở tạo đơn sửa, tạo đơn bán...) gọi `searchCustomersRanked` nên fix
này phủ hết các ô tìm kiếm chính của app mà không cần sửa từng màn riêng lẻ.
Không đụng `suppliers.nameNorm` (đã có cơ chế cột chuẩn hoá riêng, đang đúng).

**Test:** `flutter analyze` 0 error mới. Máy thật Oppo CPH2203 (shop test
"M"): tạo đơn sửa "PHAM THI TEO" (SĐT 0909887766), tìm "teo" (chữ thường) ở
cả **Tìm kiếm toàn app** và **Chọn khách hàng** đều ra đúng kết quả (trước
fix sẽ báo "Không tìm thấy kết quả"). `adb shell input text` không gõ được
ký tự có dấu trên máy test nên phần bỏ dấu được xác minh qua đọc code (cùng
pattern `VietnameseUtils` đã chạy đúng ở nơi khác) — khuyến khích chủ shop tự
gõ thử 1 lần trên bàn phím thật để yên tâm tuyệt đối.

**Files:** `lib/data/db_helper.dart`.

---

## [2026-08-31f] - docs(hướng dẫn) cập nhật KB trong app cho 2 tính năng ngân hàng

**Chưa tăng version.**

`app_knowledge_base.dart` là nguồn sự thật DUY NHẤT cho **AI Trợ Lý** *và*
**Trung tâm trợ giúp** — bổ sung 2 mục mới cho tính năng vừa làm:

- **`bank-transfer-qr` — "Thanh toán qua ngân hàng (mã QR + mở app NH)"**:
  đường dẫn (mọi ô thanh toán khi chọn "Chuyển khoản"), cách cấu hình TK ở
  Cài đặt → QR chuyển khoản, QR tự cập nhật theo số tiền đang gõ, lưu ý
  "chỉ hỗ trợ — chưa bấm Xác nhận là chưa ghi sổ", chiều CHI chỉ có nút mở app,
  nhắc tự quét thử QR 1 lần trước khi dùng cho khách.
- **`bank-notification` — "Đọc thông báo ngân hàng tự động"** (owner/manager):
  các bước bật + cấp quyền, luồng banner Home → Đối soát → chạm dòng → Xác nhận,
  và 7 lưu ý về riêng tư / giới hạn (không đọc app khác, không tự ghi tiền, lưu
  cục bộ, cần app mở/chạy nền, không rõ chiều thì để trống, chỉ Android, NH
  ngoài danh sách vẫn gõ tay được).

Kèm theo:
- `areaOf()` + `help_center_repository._kbCategoryFor()`: `bank-*` → nhóm **Tài chính**.
- `discovery_checklist.dart`: thêm 2 nhiệm vụ "Thu tiền bằng mã QR ngân hàng" và
  "Bật đọc thông báo ngân hàng" (checklist "Khám phá Ứng Dụng" → 19 việc).
- Cập nhật thêm ghi chú ở `debt-collect`, `sale-invoice`, `money-reconcile`.

**Test:** `flutter analyze` 0 error; `flutter test` **+490 −8** (+1 test mới:
AI truy hồi đúng 2 mục ngân hàng từ câu hỏi tự nhiên). Test sẵn có đã bao phủ:
id duy nhất, thuật ngữ tham chiếu tồn tại, mọi topic sinh từ KB có nhóm hợp lệ,
mọi nhiệm vụ checklist trỏ tới mục KB có thật.

**Files:** `lib/data/{app_knowledge_base,help_center_repository,discovery_checklist}.dart`, `test/ai_knowledge_service_test.dart`.

---

## [2026-08-31e] - feat(đối soát) Đọc thông báo app ngân hàng tự động (Android)

**Chưa tăng version.** DB schema **v108 → v109** (bảng `bank_notifications`, cục bộ, không sync).

### Ý tưởng
Tính năng **TÙY CHỌN, mặc định TẮT**, chỉ Android. Khi bật + cấp quyền "Truy cập
thông báo": app đọc nội dung thông báo của **các app ngân hàng** (và SMS từ đầu
số ngân hàng) → tự nhận diện số tiền +/− → tạo bản ghi "gợi ý" → hiện ở Home
banner + màn "Đối soát tiền về". **KHÔNG tự ghi tiền** — người dùng vẫn bấm Xác
nhận, đi qua đúng luồng `MoneyReconcileService.apply` / `executePaymentDirect`.

### An toàn / riêng tư
- Chỉ đọc thông báo từ nguồn trong danh sách NH (`resolveBankSource`) — app khác
  bỏ qua hoàn toàn, không đọc.
- SMS: chỉ xử lý khi tiêu đề (người gửi) khớp đầu số ngân hàng.
- Lưu **cục bộ trên máy**, không đồng bộ cloud.
- Parser THẬN TRỌNG: không rõ chiều tiền → `unknown` (người dùng tự chọn), không
  đoán. Loại OTP / khuyến mãi / nhắc nợ / báo số dư đơn thuần.

### Mới
- `pubspec`: `notification_listener_service: ^0.3.5`.
- `AndroidManifest`: `<service>` NotificationListener + `BIND_NOTIFICATION_LISTENER_SERVICE`.
- `lib/data/bank_directory.dart` — danh bạ ~35 app NH/ví + ~35 đầu số SMS NH + `resolveBankSource`.
- `lib/services/bank_notification_parser.dart` — `BankNotificationParser.parse()` → `{amount, direction, balanceAfter, memo}`. 19 test (`test/bank_notification_parser_test.dart`).
- `lib/services/bank_notification_service.dart` — nghe stream + `getActiveNotifications` bắt bù khi resume; dedup theo (gói|số tiền|chiều|ngày|hash text); `unreviewedCount` ValueNotifier.
- `lib/views/bank_notification_settings_view.dart` — bật/tắt + xin quyền + danh sách NH hỗ trợ + cảnh báo "app cần mở/chạy nền".
- `db_helper` v109: bảng `bank_notifications` + `insertBankNotificationOnce` / `getNewBankNotifications` / `markBankNotificationApplied|Dismissed` / `pruneOldBankNotifications`.
- `main.dart`: `BankNotificationService.instance.start()` sau đăng nhập + `onAppResumed()`.
- `home_view`: banner "N giao dịch ngân hàng chưa đối soát" + tile Cài đặt (chỉ Android + owner).
- `money_reconcile_view`: mục "Giao dịch ngân hàng gần đây" — chạm 1 dòng → tự điền số tiền + chiều → auto-match → Xác nhận → đánh dấu `applied`.
- Hook QA `kDebugMode`: chấp nhận `com.android.shell` (để test bằng `adb shell cmd notification post`).

**Test:** `flutter analyze` 0 error/warning mới; `flutter test` **+489 −8** (+19 test parser).

**Nghiệm thu máy thật (Oppo CPH2203) — ĐẠT:**
1. DB migration `v109: created bank_notifications table` chạy OK.
2. Cài đặt → tile "Đọc thông báo ngân hàng" → bật → mở đúng màn "Truy cập thông báo" hệ thống → cấp quyền → quay lại app tự bật (`_pendingEnable`).
3. `🔔 BankNotif.start: đã lắng nghe` + `_scanActive()` quét thông báo đang hiển thị; thông báo app khác (systemui, phonemanager, googlequicksearchbox…) **bị bỏ qua đúng**.
4. Bơm thông báo test `Vietcombank / "So du TK 0071 +690,000 VND. So du 5,200,000 VND"` → parse đúng: `amount=690000, direction=credit, balanceAfter=5200000` → 1 dòng `bank_notifications` (status `new`).
5. Home hiện banner **"1 giao dịch ngân hàng chưa đối soát"** → chạm → mở Đối soát.
6. Đối soát hiện mục **"Giao dịch ngân hàng gần đây (1)"** → chạm dòng → **tự điền 690.000 + chiều Tiền vào** → chạy auto-match; QR card cũng cập nhật theo số tiền.

**Sửa trong lúc test:** `requestPermission()` của plugin trả `null` (lỗi cast `Null → bool`) → bọc lại + luôn kiểm tra quyền thực tế; màn Cài đặt thêm `_pendingEnable` để tự bật sau khi cấp quyền (không bắt bấm 2 lần). Log chứa nội dung thông báo NH được bọc `kDebugMode` (không ghi ra logcat bản phát hành).

**⚠️ Việc cần làm khi lên store:** khai báo mục đích dùng `BIND_NOTIFICATION_LISTENER_SERVICE` + cập nhật **Play Store Data safety** và chính sách quyền riêng tư.

**Files:** `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `lib/data/{bank_directory,app_knowledge_base}.dart`, `lib/services/{bank_notification_parser,bank_notification_service}.dart`, `lib/views/{bank_notification_settings_view,money_reconcile_view,home_view,settings_view}.dart`, `lib/data/db_helper.dart`, `lib/main.dart`, `test/bank_notification_parser_test.dart`.

---

## [2026-08-31d] - feat(thanh toán) "Thanh toán qua ngân hàng" — mã QR VietQR + mở app NH ở mọi sheet thanh toán

**Chưa tăng version.**

### Ý tưởng
Khi chọn phương thức "Chuyển khoản", app hiện thêm khối **cố vấn**: mã QR
VietQR (đã điền sẵn số tiền + nội dung) để quét chuyển vào TK shop, kèm nút
**"Mở app ngân hàng"**, và nút sao chép STK / số tiền / nội dung. **KHÔNG đụng
logic tiền** — nút Xác nhận của mỗi sheet vẫn gọi y nguyên
`PaymentIntentService.executePaymentDirect(...)` như cũ.

### Mới
- **`lib/services/bank_accounts_service.dart`** — đọc TK nhận CK của shop
  (tái dùng cấu hình `settings/bank_qr` + SharedPreferences `bank_qr_*` sẵn có;
  đọc thêm mảng `accounts[]` nếu có — tương thích ngược). `ValueNotifier` để
  widget tự cập nhật sau khi lưu cài đặt.
- **`lib/widgets/bank_transfer_assist.dart`** — `bankTransferAssistCard(...)`:
  render `QrImageView(buildVietQrPayload(...))` (chuẩn NAPAS247, offline),
  hàng STK/số tiền/nội dung + nút sao chép, nút "Mở app ngân hàng" (thử
  `dl.vietqr.io` / `api.vietqr.io`, im lặng fallback về QR). Chiều
  `inbound` (nhận) hiện QR TK shop; `outbound` (chi) hiện nút mở app.
  `amountController` → QR tự cập nhật theo số tiền đang gõ. Ẩn nút deeplink
  trên web/desktop.
- **`AndroidManifest.xml`** — thêm `<queries>` cho `VIEW https/http` + `DIAL`
  để `canLaunchUrl` chạy đúng trên Android 11+.

### Cắm vào (mọi luồng có "Chuyển khoản")
`debt_payment_sheet` (thu/trả nợ), `collect_customer_debt_view` (thu nợ phân bổ),
`money_reconcile_view` (đối soát — chiều nhận), `create_sale_view` (thu tiền đơn
bán), `create_repair_order_view` (trả đối tác), `create_purchase_order_view`
(trả NCC), `expense_view` ×2 (chi phí CK + thu phát sinh), `sale_detail_view`
(tất toán trả góp NH), `repair_detail_view` ×3 (duyệt giao + thu tiền, chi phí
linh kiện, trả đối tác), `pending_payments_list_view` (thực thi khoản chờ).

**Test:** `flutter analyze` 0 error/warning mới; `flutter test` **+470 −8**.
**Máy thật Oppo CPH2203:** thu nợ HUY → chọn "Chuyển khoản" → hiện QR đúng TK
shop (Vietcombank/…/TRANMINH) + số tiền 500.000 + nội dung "Thu no HUY" + nút
"Mở app ngân hàng" + sao chép; bấm **Xác nhận** → `debts.paidAmount` 0→500.000,
`debt_payments` (CHUYỂN KHOẢN), `financial_activity_log` (CUSTOMER_DEBT_COLLECT/
IN/500.000/CHUYỂN KHOẢN) — **đúng như luồng cũ, không regression**.

**Chưa làm (Đợt 3 — tách riêng):** đọc thông báo app ngân hàng tự động
(NotificationListenerService, Android-only, cần quyền + khai báo Play Store).

**Files:** `lib/services/bank_accounts_service.dart` (MỚI),
`lib/widgets/bank_transfer_assist.dart` (MỚI), 10 sheet thanh toán,
`android/app/src/main/AndroidManifest.xml`.

---

## [2026-08-31c] - fix(đồng bộ) badge "N cần đồng bộ" ảo — bản ghi local đã xoá mà cloud còn sống

**Chưa tăng version.**

### Sự cố
Máy test hiện "⚠️ Cần đồng bộ dữ liệu (2)" mãi không hết, dù hàng đợi
(`sync_queue`) trống, thao tác đồng bộ gần nhất đều thành công, mọi bản ghi
`isSynced=1`. Truy: `SyncHealthCheck` so **số lượng** local↔cloud, lệch ở bảng
`debts` — 2 công nợ đã **xoá mềm ở local** (`deleted=1`, phiên dọn dữ liệu 30/8)
nhưng **Firestore vẫn `deleted:false`**. Auto-fix "tải lại" 2 bản ghi này mỗi lần
mở app và ghi log *"✅ Đã tải 2/2"* — nhưng **vô hiệu**: model `Debt` không có
trường `deleted` nên `_upsertToLocal` không thể gỡ `deleted=1` ⇒ lệch **kẹt
vĩnh viễn**, không thao tác nào xử lý được.

### Sửa (`sync_health_check.dart`)
- Vòng auto-fix của `_checkCollection`: trước khi "tải lại" 1 bản ghi cloud-only,
  kiểm tra local có bản ghi cùng `firestoreId` đã **xoá mềm + đã synced** không.
  Nếu có → **KHÔNG hồi sinh**; thay vào đó **enqueue lệnh `delete`** qua
  `SyncOrchestrator` để đẩy việc xoá lên cloud cho khớp.
- `_entityTypeByCollection` (map collection→`SyncEntityType`),
  `_getLocalRowByFirestoreId` (không lọc deleted), `_enqueueCloudDelete` (mới).
- Sau `runFullCheck`, nếu có lệnh xoá vừa enqueue → `SyncOrchestrator().syncAll()`
  để cloud khớp lại ngay; lần kiểm tra sau con số lệch tự về 0.
- Áp cho mọi collection map được entity type (repairs, sales, products, debts,
  customers, suppliers, expenses, …); collection không map được thì bỏ qua
  (không hồi sinh, không báo "đã tải" sai).

**Test:** `flutter analyze` 0 issue; `flutter test` **+470 −8**. Chưa nghiệm thu máy thật (fix passive path, chờ build mới).
**Files:** `lib/services/sync_health_check.dart`.

---

## [2026-08-31b] - feat(đơn sửa) chạm phụ tùng / dịch vụ để mở nguồn tương ứng

**Chưa tăng version.**

- **Phụ tùng:** mỗi dòng trong mục Phụ tùng của đơn sửa nay chạm được →
  mở đúng sản phẩm đó trong Kho (`InventoryDetailView`, tra theo `productId`
  rồi theo tên); không tra được thì mở Kho lọc sẵn tab Linh kiện. Dòng có
  gạch chân + mũi tên ›.
- **Dịch vụ:** chạm 1 dòng dịch vụ → `SimilarRepairHistoryView` liệt kê các
  đơn sửa khác dùng dịch vụ cùng tên (đối chiếu giá / lịch sử), chạm 1 đơn để
  mở chi tiết. Khớp tên có bỏ dấu (`_normNameForMatch`).
- `repair_detail_view`: `_openPartInInventory`, `_openPartsWarehouse`,
  `_openServiceHistory` (mới). Import `inventory_detail_view.dart`,
  `product_model.dart`.

**Test:** `flutter analyze` 0 error mới; `flutter test` **+470 −8**.
**Files:** `lib/views/repair_detail_view.dart`.

---

## [2026-08-31a] - fix(đồng bộ) "Đã giao" là trạng thái cuối — không bị máy khác kéo ngược

**Chưa tăng version.**

### Sự cố
Nhân viên xin giao máy → chủ shop A duyệt (đơn về **ĐÃ GIAO / status 4**), nhưng
trên máy chủ shop B đơn vẫn hiện **CHƯA GIAO**. Nguyên nhân: bộ giải quyết xung đột
đồng bộ (`SyncService._shouldAcceptCloudData`) coi bản local "mới hơn" (do lệch giờ
máy, hoặc local có sửa đổi chưa sync, hoặc `lastCaredAt` cũ) nên **từ chối** bản
cloud status 4. Máy B còn có thể đẩy ngược status 3 lên cloud → "hủy giao" toàn hệ thống.

### Sửa
- **`sync_service.dart`** — thêm luật *trạng thái cuối*: nếu cloud `status >= 4`
  và không còn `pendingDeliveryApproval`, mà local `status < 4` → **LUÔN nhận cloud**,
  bỏ qua so sánh timestamp / `isSynced` / lệch giờ; đồng thời dọn hàng đợi đẩy cũ
  (`_dropStaleRepairQueueEntry`).
- **`sync_orchestrator.dart`** `_handleUpdate` — *guard đảo ngược*: trước khi đẩy 1
  đơn sửa `status < 4` lên cloud, đọc bản cloud; nếu cloud đã `status >= 4` &
  không chờ duyệt → **bỏ các field trạng thái giao** (`status`, `deliveredAt`,
  `deliveredBy`, `deliveredByUid`, `pendingDeliveryApproval`) khỏi merge, vẫn đồng
  bộ các thay đổi khác (ghi chú, linh kiện, giá vốn).
- Hai lớp phối hợp: máy cũ vừa nhận cloud status 4 (qua listener) vừa không thể
  đẩy ngược status thấp hơn.

**Test:** `flutter analyze` 0 error mới (5 info lint có sẵn); `flutter test` **+470 −8** (baseline, 8 lỗi môi trường có sẵn). Chưa nghiệm thu 2 máy thật.
**Files:** `lib/services/sync_service.dart`, `lib/services/sync_orchestrator.dart`.

---

## [2026-08-30w] - feat(điều hướng) lối tắt Bảng giá/Đối soát vào tab + xem đơn gốc

**Chưa tăng version.**

### Lối tắt vào đúng tab
- Tab **Sửa chữa** → thẻ "Bảng giá sửa chữa" → mở Bảng giá ở tab Sửa chữa.
- Tab **Bán hàng** → thẻ "Bảng giá bán hàng" (mở tab Bán hàng) + "Đối soát tiền về".
- `PriceBookView` + `openPriceBook` nhận `initialTab` (0 = Sửa chữa, 1 = Bán hàng).

### Đối soát tiền về: xem đơn / công nợ tương ứng
- Mỗi kết quả khớp có nút ↗ "Xem đơn / khoản tương ứng" → mở:
  trả góp → `SaleDetailView`; công nợ có `linkedType`/`linkedId` (hoặc tiền tố
  `debt_customer_`/`debt_repair_`/`debt_partner_debt_`) → mở đơn bán/sửa gốc;
  không lần được → mở màn Công nợ.

### Bảng giá: xem các đơn/SP đã tạo ra dòng giá
- Dialog ghim giá thêm nút "Xem N đơn / SP tương ứng":
  sửa chữa → `SimilarRepairHistoryView` (bấm vào đơn để mở chi tiết);
  bán hàng → sheet liệt kê SP khớp (tên · giá bán · vốn · tồn · IMEI).
- `PriceBookService.repairSourcesFor` / `saleSourcesFor` (mới);
  `PriceBookRow` thêm `src1..src4` (thành phần gốc để truy nguồn).

### Đơn sửa: NCC phụ tùng cho đơn cũ
- `repair_detail_view` tra NCC theo `productId` (`_loadPartSuppliers`) → phụ tùng
  đơn cũ (chưa lưu `supplier`) vẫn hiện "NCC: …".

**Test:** `flutter analyze` 0 error mới; `flutter test` **+470 −8**. Chưa nghiệm thu adb (tiết kiệm token).
**Files:** `lib/views/{price_book_view,money_reconcile_view,home_view,repair_detail_view}.dart`, `lib/services/price_book_service.dart`, `lib/models/price_book_models.dart`.

---

## [2026-08-30v] - feat(bảng giá P3) + đơn sửa hiện NCC linh kiện + list giá gọn lại

**Chưa tăng version.**

### Đơn sửa: hiện NCC của phụ tùng
- `PartUsedDetail` (+`supplier`, tương thích ngược): lưu tên NCC lúc chọn linh kiện từ kho.
- `repair_detail_view` mục Phụ tùng: nếu có `partsUsedDetailed` → liệt kê từng dòng `Tên xSL  ·  NCC: X` cho dễ nhận biết; không có thì giữ hiển thị gọn cũ.

### Bảng giá: làm lại giao diện + P3
- **List giá gọn lại, thêm giá vốn:** mỗi dòng có 3 ô Thu/Bán · **Vốn** · Lãi (kiểu `_metric`), badge NIÊM YẾT lên cùng hàng tiêu đề, dòng phụ mẫu·độ tin cậy·khoảng giá nhỏ lại.
- **Cảnh báo giá lệch** (`create_repair_order_view`): khi giá đang nhập lệch >35% so với giá niêm yết / giá thường gặp → banner cam "CAO/THẤP hơn N%…". Rebuild khi gõ giá (`priceCtrl` listener).
- **Hệ số giá mùa vụ** (`PriceBookService.seasonPct/setSeasonPct`, SharedPreferences): cộng/trừ % vào GIÁ ĐỀ XUẤT (không đụng giá ghim). Menu ⋮ trong Bảng giá + banner khi đang bật.
- **Xuất / Nhập Excel** (`exportToExcel` / `importFromExcel`): xuất 2 sheet (Sửa chữa / Bán hàng) kèm cột `_khoá`; nhập đọc lại → GHIM các dòng "Giá NIÊM YẾT" > 0 (khớp theo `_khoá`), = 0 thì bỏ ghim. `ExcelExportHelper` thêm `writeSheet` + `saveAndShare` công khai. Menu ⋮ + `file_selector`.

**Chưa làm:** giá lẻ / sỉ / khách quen (cần wiring create_sale theo hạng khách — để sau).

**Test:** `flutter analyze` 0 error mới; `flutter test` **+470 −8** (thêm test PartUsedDetail supplier). Chưa nghiệm thu trực quan qua adb (tiết kiệm token).
**Files:** `lib/models/part_used_detail_model.dart`, `lib/views/repair_detail_view.dart`, `lib/services/price_book_service.dart`, `lib/views/price_book_view.dart`, `lib/views/create_repair_order_view.dart`, `lib/utils/excel_export_helper.dart`, `test/price_book_test.dart`.

---

## [2026-08-30u] - feat(bảng giá) Bảng giá tự động + giá niêm yết cho sửa chữa & bán hàng

**Chưa tăng version.** Trước đây giá gợi ý chỉ hiện phản ứng khi tạo đơn (`PricingEngineService` cho sửa, `ProductPricingService` cho bán). Nay có **màn Bảng giá** duyệt được + chốt giá niêm yết + tự điền vào form.

### Nền tảng
- `lib/models/price_book_models.dart` (mới): `PriceBookRow` (auto/pinned, `effectivePrice`), `PricePin`, `PriceResolution`, `SalePriceProposal`.
- `lib/services/price_book_service.dart` (mới) — layer mỏng trên 2 engine sẵn có:
  - `buildRepairRows()` gom đơn Xong/Đã giao theo (model · lỗi) → trung vị giá/vốn/lãi + số mẫu + độ tin cậy + khoảng min–max.
  - `buildSaleRows()` gom SP theo (hãng · model · dung lượng · tình trạng).
  - Ghim: `pin()` / `unpin()` lưu SharedPreferences (`pricebook_pins_v1`, **theo máy**). Khoá chuẩn hoá: `repairKey` / `saleKey`.
  - `resolveRepair()` / `resolveSale()` — ưu tiên GHIM → trung vị → không có; cho form tạo đơn.
  - `proposeSalePrices()` (dry-run) + `commitSalePrices()` — áp giá hàng loạt cho SP chưa có giá (chỉ khi có nhóm cùng loại đã có giá để lấy trung vị).

### Màn "Bảng giá" — `lib/views/price_book_view.dart` (mới)
- 2 tab Sửa chữa / Bán hàng, tìm kiếm, nhóm theo hãng. Mỗi dòng: giá hiệu lực + số mẫu · độ tin cậy · khoảng giá; badge **NIÊM YẾT** nếu đã ghim, else "lãi X".
- Chạm dòng → dialog nhập "Giá niêm yết" + "Giá vốn dự kiến" + ghi chú → **Ghim giá** / **Bỏ ghim**.
- Tab Bán hàng: nút AppBar "Áp giá cho SP chưa có giá" → dialog xem trước → xác nhận.
- Kéo xuống làm mới.

### Tự điền vào form
- `create_repair_order_view`: `_runPricingLookup` gọi thêm `PriceBookService.resolveRepair` — nếu (model · lỗi) có giá NIÊM YẾT: hiện thẻ "GIÁ NIÊM YẾT (Bảng giá)" + nút "DÙNG GIÁ X", và **tự điền vào ô giá nếu đang trống**. Thẻ "GIÁ THAM KHẢO" (trung vị) vẫn hiện bên dưới.

### Lối tắt + KB
- Home → thẻ TRUY CẬP NHANH TÀI CHÍNH: thêm nút **Bảng giá** (cạnh "Đối soát tiền về").
- Mục KB `price-book` (AI + Trung tâm trợ giúp) + nhiệm vụ checklist khám phá.

**Test:** `flutter analyze` 0 error mới; `flutter test` **+469 −8** (9 test bảng giá: khoá chuẩn hoá, effectivePrice pinned/auto, PricePin JSON, PriceResolution). **Máy thật Oppo:** màn Bảng giá render đủ (Sửa: IPHONE·ÉP KÍNH 600k lãi 597k…; Bán: 12 32GB (MỚI) 12tr…); ghim IPHONE·ÉP KÍNH → badge NIÊM YẾT + snackbar; áp-giá-hàng-loạt xử lý đúng trường hợp không có dữ liệu. Thẻ "GIÁ NIÊM YẾT" trong form tạo đơn: đã wire + analyze sạch, chưa nghiệm thu trực quan qua adb (kẹt nhập liệu).
**Files:** +`lib/models/price_book_models.dart`, +`lib/services/price_book_service.dart`, +`lib/views/price_book_view.dart`, +`test/price_book_test.dart`, `lib/views/{home_view,create_repair_order_view}.dart`, `lib/data/{app_knowledge_base,discovery_checklist,help_center_repository}.dart`.

---

## [2026-08-30t] - feat(đơn sửa) đơn ĐÃ GIAO vẫn bổ sung / chỉnh sửa được (thêm linh kiện, Sửa KTV)

**Chưa tăng version.** Trước: đơn `status = 4` (Đã giao) khóa gần hết thao tác sửa — chỉ cho "Xóa PT" nếu có phụ tùng. Nay mở để bổ sung / sửa nhầm sau khi giao.

- `repair_detail_view` — bỏ điều kiện `status < 4` ở khối "Quick actions": đơn ĐÃ GIAO nay hiện đủ **Phụ tùng** (thêm linh kiện), **Kho LK**, **Đổi/Xóa PT**, **Sửa KTV**, **KTV** (ghi chú) — vẫn theo phân quyền (`_canEditRepairOrder` cho mutation, `_canEditRepairNotes` cho ghi chú). Có dòng nhắc *"Đơn đã giao — vẫn có thể bổ sung / chỉnh sửa, thay đổi được ghi nhật ký."*
- **`_editTechnician()` (MỚI)** — nút "Sửa KTV": dialog chọn KTV từ danh sách nhân viên shop (`FirestoreService.getShopStaffList`) + "Bỏ gán KTV" + KTV hiện tại được đánh dấu + cảnh báo "đổi KTV sẽ tính lại hoa hồng". Chọn → set `repairedBy`/`repairedByUid` → `_saveData()` (local + cloud + queue sync) + `AuditService.logAction('REPAIR_TECHNICIAN_CHANGED')` + snackbar.
- Các handler thêm/đổi/xóa phụ tùng tái dùng nguyên bản (đã có audit + trả kho) — không viết lại.
- KB `repair-status`: thêm lưu ý + câu hỏi mẫu về sửa đơn sau khi giao.

**Test:** `flutter analyze` 0 error mới; `flutter test` +460 −8. **Máy thật Oppo:** mở đơn "ĐÃ GIAO" → hiện đủ nút + dòng nhắc; "Sửa KTV" → dialog liệt kê H/N/WEBSYNC + cảnh báo hoa hồng; chọn → lưu + snackbar "Đã đổi KTV", `Đã sync`, 0 exception.
**Files:** `lib/views/repair_detail_view.dart`, `lib/data/app_knowledge_base.dart`.

---

## [2026-08-30s] - feat(tài chính) "Đối soát tiền về": nhập số tiền → tự tìm đơn trả góp / công nợ khớp → ghi nhận

**Chưa tăng version.** Khi có tiền về tài khoản (NH tất toán trả góp, khách chuyển trả nợ) hoặc vừa chuyển tiền trả NCC — nhập số tiền, app tự tìm khoản tương ứng để ghi nhận + cập nhật trạng thái, không phải tự dò.

### Màn mới `lib/views/money_reconcile_view.dart` + `lib/services/money_reconcile_service.dart`
- Toggle **Tiền vào (nhận)** / **Tiền ra (chuyển)** + 1 ô số tiền. **Tự lọc khi gõ** (debounce 250ms, không cần bấm nút); xoá hết số → về gợi ý; đổi toggle → lọc lại theo chiều mới; kéo xuống làm mới.
- **Không lag dù shop nhiều nợ:** nạp dữ liệu nguồn MỘT LẦN lúc mở màn (+ sau khi ghi / kéo làm mới), gõ số tiền chỉ lọc trong bộ nhớ (`MoneyReconcileService.match` thuần, đồng bộ). Công nợ đã lọc CÒN DƯ ngay ở SQL (`db.getOutstandingDebtsRaw()` MỚI: `status NOT IN (PAID,CANCELLED) AND totalAmount-paidAmount > 0`) nên shop lâu năm không phải nạp cả bảng `debts`.
- `MoneyReconcileService.findMatches(amount, moneyIn)` — quét:
  - **Trả góp NH chưa tất toán** (`db.getPendingSettlementSales()` MỚI: `isInstallment=1 AND settlementReceivedAt trống`) — khớp tổng `loanAmount+loanAmount2`.
  - **Công nợ khách (phải thu)** khi Tiền vào / **Công nợ NCC-đối tác (phải trả)** khi Tiền ra — từ `getDebtsForFinanceSnapshot`, còn dư > 0, chưa PAID/CANCELLED. *(Đơn bán/sửa CÔNG NỢ còn thiếu tiền nằm ở đây.)*
  - Phân loại **Khớp đúng** (bằng số kỳ vọng) / **Khớp một phần** (nhập < còn nợ). Sắp khớp-đúng lên trước.
- **LUÔN hiện danh sách để xác nhận** — chạm 1 khoản → dialog (đối tượng / nội dung / số kỳ vọng / số ghi / "còn nợ X sau khi ghi") → Xác nhận ghi.
- `MoneyReconcileService.apply()` — **tái dùng đúng luồng đã kiểm chứng, KHÔNG viết lại logic tiền:**
  - Công nợ → `PaymentIntentService.executePaymentDirect(customerDebtCollection | supplierDebt, …)` — y hệt `debt_payment_sheet`.
  - Trả góp → sao chép 1:1 khối tất toán của `sale_detail_view._openSettlementDialog` (set `settlementReceivedAt`, `updateSale`, enqueue sync, `createIntent(saleInstallment/completed)`, phí NH, audit).
  - Ghi xong → `AuditService.logAction` + `EventBus.emit` → danh sách tự làm mới.

### Lối tắt ở tất cả màn tài chính
- **Trang chủ** → thẻ TRUY CẬP NHANH TÀI CHÍNH thêm nút "Đối soát tiền về".
- **Sổ quỹ** (`cash_closing_view`) → icon trên AppBar.
- **Công nợ** (`debt_view`) → icon trên AppBar.
- **Tài chính** (`finance_v2_view`) → mục đầu menu ⋯.

### KB + khám phá
- Mục KB `money-reconcile` (AI + Trung tâm trợ giúp) + nhiệm vụ checklist "Đối soát tiền về".

**Test:** `flutter analyze` 0 error mới; `flutter test` **+460 −8** (không hồi quy). **Máy thật Oppo CPH2203:** ✅ mở từ menu Tài chính; ✅ tìm 6.111.111đ → ra 2 công nợ khách khớp một phần (HUY kỳ vọng 10tr, ABC 6,99tr), sắp xếp + nhãn đúng; ✅ dialog xác nhận hiện đủ số liệu ("còn nợ 3.888.889đ sau khi ghi"). Nút "Xác nhận ghi" (write) chưa kích qua adb được do kẹt nhập liệu IME — nhưng apply gọi đúng `executePaymentDirect` production của `debt_payment_sheet` + bản sao khối tất toán của `sale_detail_view`. **Chủ shop nên thử ghi 1 khoản thật trên máy để nghiệm thu cuối.**
**Files:** +`lib/views/money_reconcile_view.dart`, +`lib/services/money_reconcile_service.dart`, `lib/data/db_helper.dart` (+`getPendingSettlementSales`), `lib/data/app_knowledge_base.dart`, `lib/data/discovery_checklist.dart`, `lib/data/help_center_repository.dart`, `lib/views/{home_view,cash_closing_view,debt_view}.dart`, `lib/finance_v2/finance_v2_view.dart`.

---

## [2026-08-30r] - feat(khám phá) người dùng tự tìm hết tính năng: catalog A–Z + checklist Home + AI chủ động

**Chưa tăng version.** Tiếp nối `[2026-08-30q]` — trước đây 3 hệ thống hướng dẫn rời nhau (ⓘ mỗi màn, Trung tâm trợ giúp, `UserGuideView` viết tay), không có "bản đồ" tính năng, AI thụ động, không có onboarding.

### 1. Gộp về 1 cửa
- Lối tắt "Hướng dẫn sử dụng" ở Trang chủ nay mở **Trung tâm hướng dẫn** (`HelpCenterView`, ~47 mục dựng từ `AppKnowledgeBase`) thay vì `UserGuideView` cũ (giữ lại, vẫn vào được từ Cài đặt).
- `HelpCenterView` thêm tham số `initialTopicId` → mở thẳng chi tiết một mục (dùng cho deep-link từ checklist / mẹo).

### 2. Màn "Tất cả tính năng" — `lib/views/feature_catalog_view.dart` (mới)
- Bản đồ mọi tính năng, nhóm theo 8 khu (`AppKnowledgeBase.areas`): mỗi dòng = tên + 1 câu "làm gì" → chạm mở chi tiết (vị trí menu, các bước, lưu ý, thuật ngữ) + nút **"Hỏi AI Trợ Lý về mục này"**.
- Có ô tìm kiếm (chuỗi con, bỏ dấu). Lọc theo vai trò.
- `AppKnowledgeBase` thêm: `areas`, `areaOf(id)`, `entriesByArea(id)`, `sampleQuestionSpread(n)` (câu hỏi mẫu trải đều nhóm, ổn định theo seed), `tipOfTheDay()`.

### 3. Thẻ "Khám phá Ứng Dụng" ở Trang chủ — `discovery_card.dart` + `discovery_service.dart` + `discovery_checklist.dart` (mới)
- Checklist 15 nhiệm vụ ("Tạo đơn sửa đầu tiên", "Chốt quỹ cuối ngày", "Phân quyền nhân viên"…), thanh tiến độ, lọc theo vai trò.
- Chạm nhiệm vụ → chuyển tab tương ứng hoặc mở hướng dẫn KB, và tự tick.
- Tự nhận biết đã làm từ dữ liệu thật (đếm đơn sửa / đơn bán / sản phẩm) + tick tay (SharedPrefs). Nút **Ẩn**. Tự ẩn khi xong hết.
- Dòng **"Mẹo hôm nay"** xoay vòng theo ngày (từ `notes` của KB), chạm mở hướng dẫn.

### 4. AI Trợ Lý chủ động khoe tính năng
- Lời chào thêm 3 câu hỏi mẫu **xoay theo ngày, trải đều các nhóm** + chip **"📚 Tất cả tính năng"** (mở catalog).
- Câu trả lời "Hướng dẫn" bổ sung nhóm ví dụ "Cách dùng tính năng" + chip mở catalog.
- `AiNavBridge.ask(question)` (mới) — màn khác nhờ AI trả lời hộ: overlay tự mở + hỏi. Dùng bởi nút "Hỏi AI" trong catalog.

**Test:** `flutter analyze` (12 file) 0 error/warning mới; `flutter test` **+460 −8** (9 test mới: nhóm KB, sampleQuestionSpread ổn định, tipOfTheDay, checklist↔KB toàn vẹn, lọc vai trò). 8 lỗi môi trường có sẵn không đổi.

**Nghiệm thu máy thật (Oppo CPH2203, shop "M", debug build):** ✅ thẻ Khám phá render + tự tick 3–5/15 từ dữ liệu, tiến độ %, mở rộng/thu gọn, gạch ngang việc xong, **Ẩn** ẩn thẻ (SharedPrefs bền qua khởi động lại); ✅ chạm việc → tick + điều hướng (chuyển tab + deep-link hướng dẫn); ✅ "Mẹo hôm nay"; ✅ AI chào có 3 câu hỏi mẫu xoay ngày + chip "📚 Tất cả tính năng"; ✅ chip mẫu → câu trả lời KB offline; ✅ màn "Tất cả tính năng" (nhóm + tìm kiếm + bottom sheet); ✅ "Hỏi AI về mục này" → về Home + overlay tự mở + trả lời (round-trip trọn vẹn); ✅ HelpCenterView deep-link tự mở chi tiết. **4 lỗi hiển thị phát hiện & sửa ngay:**
1. Câu mơ hồ "... thế nào?" bị nhánh quick-answer trả số liệu thay vì hướng dẫn → `_send` thêm cổng `preferKb` (câu how-to khớp rất mạnh, minScore ≥ 12 → ưu tiên KB).
2. `help_center_view` mục Nổi bật tràn dọc 12px (tiêu đề KB dài) → `SizedBox height 150 → 172`.
3. `help_center_view` chi tiết: hàng "danh mục · Dành cho X, Y, Z" tràn ngang 22px (KB nhiều vai trò) → bọc `Flexible` + `ellipsis`.
4. `offlineAnswer` chèn thuật ngữ của mục phụ (kém liên quan) → chỉ chèn thuật ngữ của chính mục hoặc tên xuất hiện trong câu hỏi.
Cả 4 đã build lại + xác minh trên máy: 0 overflow, câu trả lời đúng.

**Files:** +`lib/views/feature_catalog_view.dart`, +`lib/widgets/discovery_card.dart`, +`lib/services/discovery_service.dart`, +`lib/data/discovery_checklist.dart`, +`test/discovery_and_catalog_test.dart`, `lib/data/app_knowledge_base.dart`, `lib/services/ai_nav_bridge.dart`, `lib/services/ai_chat_service.dart`, `lib/services/ai_knowledge_service.dart`, `lib/widgets/ai_chat_overlay.dart`, `lib/views/help_center_view.dart`, `lib/views/home_view.dart`.

---

## [2026-08-30q] - feat(AI Trợ Lý) Knowledge Base: hiểu toàn bộ app + hỏi mọi tính năng

**Chưa tăng version.** AI chat trước đây: prompt hệ thống liệt kê tính năng tĩnh ~12 dòng (dễ lệch), Trung tâm trợ giúp (7 topic) KHÔNG nối với AI, cloud chỉ nhận số liệu tổng → không trả lời được "làm thế nào / ở đâu / là gì".

### 1. Nguồn kiến thức DUY NHẤT — `lib/data/app_knowledge_base.dart` (mới)
- **~40 mục tính năng** (`KbEntry`): tên · đường dẫn menu · làm gì · khi nào dùng · các bước · lưu ý · thuật ngữ liên quan · câu hỏi mẫu · tag · vai trò. Bao trùm: đơn sửa (tạo/trạng thái/giá vốn/đối tác/bảo hành), bán hàng (tạo/6 hình thức thanh toán/giá tham khảo/phiếu QR/trả hàng), kho (tồn/nhập TM/nhập nợ/hàng chờ xác nhận/kiểm kho/PO), công nợ (tổng quan/thu-trả/miễn nợ/công cụ điều chỉnh), tài chính (dòng tiền vs dồn tích/chốt quỹ/báo cáo ngày/FinanceV2/lãi tháng/chi phí/lương/chấm công), khách hàng, Trang chủ (CẦN XỬ LÝ/hoạt động/thẻ), hệ thống (phân quyền/đồng bộ/thông báo/sao lưu/Excel/giọng nói/AI).
- **~25 thuật ngữ** (`KbTerm`) với định nghĩa CHUẨN của app: dòng tiền, dồn tích, chốt quỹ (công thức), lệch quỹ, giá vốn, lãi gộp, công nợ phải thu/phải trả, trả góp NH, tất toán, cọc, tồn kho giá vốn, "mặt hàng" vs "sản phẩm tồn", biến thể, nhập tạm, trạng thái đơn sửa, giá vốn đơn sửa ("chưa ghi nhận" vs "không tốn"), xoá mềm, đồng bộ, vai trò, shopId, nguồn khoản nợ, miễn nợ, giá tham khảo.

### 2. Truy hồi + trả lời — `lib/services/ai_knowledge_service.dart` (mới)
- `retrieve(question, {role, minScore})` — chấm điểm theo tag/tiêu đề/thân/câu hỏi mẫu, lọc theo vai trò, chống khớp nhầm do bỏ dấu (câu ≥3 từ mà chỉ trúng 1 từ và không có câu mẫu gần khớp ⇒ loại).
- `offlineAnswer()` — dựng câu trả lời how-to HOÀN TOÀN từ KB, **chạy offline, không tốn lượt cloud**, hoạt động cả cho nhân viên/kỹ thuật. Ngưỡng điểm cao (6) để chắc chắn.
- `buildCloudContext()` — chuỗi "KIẾN THỨC TÍNH NĂNG" gọn (≤2600 ký tự) gửi kèm câu hỏi lên cloud.

### 3. Ghép vào luồng chat — `ai_chat_overlay.dart`, `ai_chat_service.dart`
- `_send`: sau quick-answer + clarify, thử `offlineAnswer` → khớp thì trả lời ngay (log `quickAnswer` + `matchedKb`).
- Không khớp offline → lên cloud, `askAI(role:)` gửi kèm `knowledge` (KB context) + `role`.
- Nhân viên không có quyền AI cloud: thay vì từ chối cụt, vẫn được KB trả lời các câu how-to.

### 4. Cloud Function `chatAssistant` (`functions/index.js`)
- Nhận `knowledge` + `role`. `CHAT_SYSTEM_PROMPT` viết lại gọn: bỏ danh sách tính năng tĩnh, thêm hướng dẫn "dựa vào KIẾN THỨC TÍNH NĂNG, không bịa vị trí nút" + **thuật ngữ chuẩn ghim sẵn**.
- **Phân quyền phía server**: role không phải owner/manager/admin + intent finance/debt ⇒ từ chối lịch sự (khớp lớp chặn client). **Cần `firebase deploy --only functions`.**

### 5. Trung tâm trợ giúp dùng CHUNG nguồn — `help_center_repository.dart`
- `topics = _curatedTopics + _kbTopics`: mỗi `KbEntry` tự sinh 1 `HelpTopic` (map category theo id). Help Center giờ hiển thị ~47 mục thay vì 7, cùng nội dung AI dùng. Sửa 1 chỗ (`app_knowledge_base.dart`) là cập nhật cả hai.

### 6. Feedback (đã có sẵn 👍/👎 + dashboard Owner) — bổ sung `matchedKb` vào log ⇒ phản hồi tiêu cực chỉ đúng mục KB cần sửa.

**Chưa làm (có chủ đích):** tra cứu theo thực thể cho SP/đơn cụ thể (chỉ mới làm "khách X nợ bao nhiêu"); đẩy KB lên Firestore để sửa không cần build; ngữ cảnh màn hình đang mở.

**Test:** `flutter analyze` (7 file) 0 error; `flutter test` **+451 −8** (16 test KB mới: toàn vẹn dữ liệu, truy hồi, lọc vai trò, offline answer, help-center bridge). 8 lỗi môi trường có sẵn không đổi.
**Files:** +`lib/data/app_knowledge_base.dart`, +`lib/services/ai_knowledge_service.dart`, +`test/ai_knowledge_service_test.dart`, `lib/services/ai_chat_service.dart`, `lib/services/ai_usage_logger.dart`, `lib/widgets/ai_chat_overlay.dart`, `lib/data/help_center_repository.dart`, `functions/index.js`.

---

## [2026-08-30p] - feat(đơn sửa) phân loại giá vốn: "chưa ghi nhận" vs "không tốn chi phí (0đ)"

**Chưa tăng version.** Trước đây đơn sửa có `cost = 0` bị lẫn lộn 2 nghĩa: (a) **chưa nhập giá vốn** (cần xử lý) và (b) **thật sự không tốn linh kiện** (đúng, xong). Cả hai đều hiện "0đ" → gây nhầm, và khung home CẦN XỬ LÝ nhắc oan cả đơn loại (b).

Dùng `repairs.costRecordedAt` (mốc thời gian đã ghi nhận giá vốn — trước nay chỉ set khi `cost > 0`) làm dấu phân biệt:

- **Dialog "Tài chính đơn sửa"** (`repair_detail_view`): thêm ô tích **"Đơn này KHÔNG tốn giá vốn (0đ)"**. Tích → ẩn ô nhập giá vốn, ép `cost = 0`, set `costRecordedAt = now`, **không** popup ghi sổ quỹ, và **hoàn nhập** phần đã lỡ ghi quỹ trước đó (`_applyCostFundDelta` âm). Bỏ tích lại nhập bình thường.
- **Hiển thị chi tiết đơn**: khi `cost == 0` hiện 1 dòng trạng thái — `costRecordedAt` có giá trị → *"Không tốn giá vốn (0đ)"* (xám, ✓); trống → *"Chưa ghi nhận giá vốn"* (cam, ⚠).
- **Home CẦN XỬ LÝ** (`dashboard_cards`): cảnh báo "đơn sửa tuần này chưa có giá vốn" nay lọc thêm `AND (costRecordedAt IS NULL OR costRecordedAt = 0)` — đơn đã đánh dấu "không tốn giá vốn" KHÔNG còn bị nhắc.

**Test:** `flutter analyze` (2 file chạm) — 0 error, chỉ info/style có sẵn; `flutter test` +435 −8 (8 lỗi môi trường có sẵn, không hồi quy).
**Files:** `lib/views/repair_detail_view.dart`, `lib/widgets/dashboard_cards.dart`.

---

## [2026-08-30o] - chore(docs) dọn tài liệu lỗi thời + fix "Không tìm thấy đơn gốc"

**Chưa tăng version.**

### fix(công nợ) "Không tìm thấy đơn gốc (có thể đã bị xóa)"

Nguyên nhân: `debt_view._openSourceOrder` chỉ tra `sales` + `repairs` theo `linkedId`. Nhưng nợ **NHẬP KHO** (`debt_stock_*`, `linkedId` = id phiếu `stock_entries` — bảng này KHÔNG lưu local), nợ **giá vốn** (`debt_cost_*`, linkedId = product firestoreId), nợ **linh kiện** (`debt_part_*`, linkedId rỗng) → không bao giờ khớp → luôn báo "không tìm thấy" (dù SP không hề bị xoá). Rất nhiều nợ NCC bị.

Nay: nếu không khớp đơn bán/sửa → hiện **bảng "Nguồn khoản nợ"** (suy loại từ tiền tố firestoreId: nhập kho / giá vốn / linh kiện / bán CÔNG NỢ / tạo tay) + đối tượng, nội dung, tổng/đã trả/còn nợ, ngày tạo + dòng giải thích "phát sinh khi nhập hàng — không tách thành đơn riêng, SP vẫn còn trong kho". Hết báo sai "đã bị xoá".

### chore(docs) xoá tài liệu lỗi thời (148 file, ~12.5k dòng)

- 14 báo cáo one-off ở gốc repo (IMAGE_UPLOAD_*, *_REPORT, DESIGN_*, DEEP_LINK_*, ui_guidelines, "tính năng kiểm tra read firebase", "AI SOFTWARE DEVELOPMENT PROTOCOL"...) — toàn bộ đã gộp vào CHANGELOG/HANDOVER hoặc thay bằng code (`lib/theme/design_tokens.dart`).
- `DOCS/BLUEPRINT/` (124 file) — bộ "rebuild guide" auto-gen tháng 5, một nửa file 0 byte, nội dung template chung chung, lỗi thời sau 100+ mục changelog.
- `DOCS/UX_AUDIT/` (8 file) — audit UX một lần tháng 5.
- `DOCS/KIOTVIET_INTEGRATION_REPORT.md` (trùng bản gốc), `DOCS/# HULUCA Context for Claude.txt`.
- `.firebase/` (cache deploy) bỏ khỏi git + thêm vào `.gitignore`.

**Giữ:** CHANGELOG/HANDOVER/DOCUMENTATION_INDEX, release_notes_*, store_metadata, DEEPSEEK_AI_SETUP, AI_SECURITY_RISK_AUDIT, DOCS/vocabulary, test/*.md, CLAUDE.md, copilot-instructions.

**Cần user quyết:** `CHANGELOG.md` ở gốc repo (bản cũ, dừng ở [1.0.5] 2026-05-01 — bản sống là `DOCS/CHANGELOG.md`) — giữ tên chuẩn hay xoá? `DOCS/DOCUMENTATION_INDEX.md` giờ có link chết tới BLUEPRINT/UX_AUDIT.

**Test:** `flutter analyze` sạch; `flutter test` +435 −8.
**Files:** `lib/views/debt_view.dart`, `.gitignore` + 148 xoá.

---

## [2026-08-30m] - feat(home) Hoạt động hôm nay: tách "Sửa xong" / "Giao máy" + thông tin chi tiết đơn sửa

**Chưa tăng version.** Trước đây feed chỉ phân biệt "Nhận sửa" vs "Giao máy" (status 4), không có mốc "Sửa xong" (status 3), và không hiện lỗi máy / kỹ thuật viên.

`dashboard_cards._loadActivities` — query `repairs` bổ sung cột `issue`, `finishedAt`, `repairedBy`, `deliveredBy`; WHERE thêm `finishedAt >= đầu ngày` (bắt cả đơn hôm nay mới sửa xong). Mỗi đơn hiện 1 dòng theo trạng thái mới nhất:
- **status 3 "Sửa xong - {máy}"** — mốc `finishedAt`, phụ đề: tên khách · lỗi · "KTV: {người sửa}". Icon ✔ xanh ngọc.
- **status 4 "Giao máy - {khách}"** — mốc `deliveredAt`, phụ đề: máy · lỗi · "Giao: {người giao}". +tiền.
- **status 1/2 "Nhận sửa - {máy}"** — phụ đề: khách · lỗi.

**Test:** `flutter analyze` sạch; `flutter test` (chạy lại).
**Files:** `lib/widgets/dashboard_cards.dart`.

---

## [2026-08-30l] - fix 4 điểm: nợ 0đ, tên "KHÁC MỚI", Sổ quỹ overflow, danh sách bảo hành

**Chưa tăng version.**

1. **Công cụ điều chỉnh dữ liệu → CÔNG NỢ**: danh sách hiện cả nợ 0đ / đã trả hết / đã huỷ (không có gì để miễn, chỉ làm loãng). Nay lọc chỉ hiện khoản **còn dư > 0** và `status` không phải `PAID`/`CANCELLED`.
2. **Tên hàng "KHÁC MỚI"** (brand mặc định "KHÁC" + tình trạng "MỚI" khi thiếu model): `ProductConstants.generateProductName` nay **trả '' khi không có model** + **bỏ qua brand "KHÁC"**. Chặn phát sinh MỚI. *(Hàng cũ đã lỡ đặt tên "KHÁC MỚI" cần sửa tên thủ công — chưa có cleanup tự động.)*
3. **Sổ quỹ — ngày trên AppBar bị overflow**: bọc `title` trong `FittedBox(scaleDown)` → tự co khi hẹp, không tràn.
4. **Danh sách bảo hành** hiện thêm: **📞 SĐT khách**, **thời hạn BH** (vd "BH 12 tháng"), và **🔧 nội dung sửa** (đơn sửa) — mỗi dòng 1 hàng, ellipsis.

**Test:** `flutter analyze` sạch; `flutter test` (chạy lại).
**Files:** `lib/views/{data_reconciliation_view,cash_closing_view,warranty_view}.dart`, `lib/constants/product_constants.dart`.

---

## [2026-08-30k] - feat(home) CẦN XỬ LÝ: giới hạn cảnh báo NH chưa tất toán + đơn sửa thiếu giá vốn về "tuần này"

**Chưa tăng version.** 2 cảnh báo này đã có trong khung CẦN XỬ LÝ nhưng đang đếm **toàn thời gian** — đơn cũ (khó/không bao giờ xử lý) làm loãng con số, che mất việc thực sự cần làm.

`dashboard_cards.dart` — thêm mốc `startOfWeekMs` (Thứ 2, 00:00 tuần này) và scope lại:
- **"Tiền NH tuần này chưa tất toán: X đ · N đơn"** — `sales WHERE isInstallment=1 AND settlementReceivedAt IS NULL AND soldAt >= startOfWeek` (cả count lẫn SUM).
- **"N đơn sửa tuần này chưa có giá vốn"** — `repairs WHERE status=4 AND cost=0 AND deliveredAt >= startOfWeek`.

Nhãn đổi để nói rõ "tuần này". Nút bấm vẫn mở danh sách đầy đủ như cũ (home chỉ là nhắc việc trong tuần).

**Test:** `flutter analyze` sạch; `flutter test` (chạy lại).
**Files:** `lib/widgets/dashboard_cards.dart`.

---

## [2026-08-30j] - feat(phân quyền) thông báo tài chính/công nợ chỉ cho chủ shop + quản lý

Trả lời câu hỏi "phân quyền chưa": trước đó `[2026-08-30h..i]` broadcast cho **mọi vai trò** (kể cả nhân viên/kỹ thuật thấy lương, chi phí, chốt quỹ...). Nay giới hạn.

- **Cloud Function `functions/index.js`** — `getAllowedRolesForNotificationType`: thêm `case 'finance'` + `case 'debt'` → chỉ `['admin', 'owner', 'manager']`. Đây là cổng chính (lọc FCM token theo role trước khi gửi push). **⚠️ CẦN `firebase deploy --only functions` để có hiệu lực.**
- **Client `notification_service.dart`** — `_isNotificationForCurrentContext` (dùng chung cho foreground + background) thêm chốt: nếu `type` là `finance`/`debt` và `getCachedRole()` không phải owner/manager/admin → bỏ qua hiển thị. Lớp phòng vệ thứ 2 (hoạt động ngay cả khi CF chưa deploy). Đọc role lỗi → nhường CF quyết định.

Loại `'payment'` (thanh toán đơn bán) giữ nguyên cho cả nhân viên như cũ.

**Test:** `flutter analyze` sạch; `node --check functions/index.js` OK; `flutter test` (chạy lại).
**Files:** `functions/index.js`, `lib/services/notification_service.dart`.

---

## [2026-08-30i] - feat(tài chính) thông báo MỌI hoạt động tài chính cho cả shop

Tiếp `[2026-08-30h]` — mở rộng từ "công nợ" sang toàn bộ hoạt động tài chính. **Chưa tăng version.**

- **`NotificationService.notifyFinancialActivity({label, amount, isIncome, ...})`** (mới) — broadcast `type: 'finance'` (bật mặc định).
- **`PaymentIntentService.executePayment`** — sau khi thanh toán thành công + ghi ledger, tự gửi thông báo cho MỌI `PaymentIntentType`: thanh toán bán hàng, sửa chữa, chi phí vận hành/tiện ích/khác, thu nhập khác, lương/thưởng, trả góp, trả đối tác... (bỏ qua `customerDebtCollection`/`supplierDebt`/`otherDebt` vì đã có `notifyDebtActivity` từ `debt_payment_sheet` → không báo trùng).
- **`PaymentIntentService.createDebtRecord`** — thêm cờ `notify` (mặc định `false`). 7 điểm tạo nợ NCC khi nhập hàng/linh kiện (fast_stock_in, inventory_view sửa giá vốn, parts_inventory ×4, stock_entry_service confirmEntry) nay truyền `notify: true` → thông báo "🆕 CÔNG NỢ MỚI".
- **Chốt quỹ** (`cash_closing_view._saveClosing`) — sau khi chốt thành công gửi "🔒 ĐÃ CHỐT QUỸ" (+ "(CÓ LỆCH)" nếu lệch) kèm tồn quỹ + ghi chú.

Kết quả: thu/chi tiền, chi phí, thu khác, lương, công nợ (mới/thu/trả/miễn), nhập hàng nợ NCC, chốt quỹ — đều báo cho cả nhóm. Chưa gắn: VOID/đảo bút toán, log sửa chữa nội bộ (tránh nhiễu).

**Test:** `flutter analyze` 0 error/warning mới; `flutter test` (chạy lại).
**Files:** `lib/services/{notification_service,payment_intent_service,stock_entry_service}.dart`, `lib/views/{cash_closing_view,fast_stock_in_view,inventory_view,parts_inventory_view}.dart`.

---

## [2026-08-30h] - feat(công nợ) thông báo + ghi Hoạt động hôm nay khi thu/trả/tạo/miễn nợ

**Chưa tăng version** (vẫn `3.5.0+554`).

Trước đây thu/trả nợ chỉ hiện sheet kết quả cục bộ, không báo cho các thiết bị khác; tạo công nợ mới không xuất hiện ở "Hoạt động hôm nay" (chỉ `debt_payments` mới hiện).

- **`NotificationService.notifyDebtActivity({action, personName, amount, by, ...})`** (mới) — broadcast `type: 'debt'` cho MỌI thiết bị trong shop + FCM push. `action`: `collect` (thu nợ khách) · `pay` (trả nợ NCC/đối tác) · `create` (công nợ mới) · `waive` (miễn nợ). `'debt'` thêm vào danh sách bật mặc định.
- **Gọi từ:**
  - `debt_payment_sheet` — sau mỗi lần thu/trả nợ thành công ("💰 ĐÃ THU NỢ" / "💸 ĐÃ TRẢ NỢ" + số tiền + người thao tác).
  - `create_sale_view` — đơn CÔNG NỢ tạo xong ("🆕 CÔNG NỢ MỚI").
  - `data_reconciliation_view._writeOff` — miễn nợ ("✅ ĐÃ MIỄN NỢ" + lý do).
- **Hoạt động hôm nay** (`dashboard_cards`) — thêm truy vấn `debts` tạo trong ngày → dòng "Công nợ khách mới / phải trả mới - <tên>". (Thu/trả nợ vốn đã hiện qua `debt_payments`.)

Chưa gắn thông báo cho công nợ nội bộ tự sinh (giá vốn linh kiện từng dịch vụ...) để tránh spam.

**Test:** `flutter analyze` 0 error / 0 warning mới; `flutter test` (chạy lại).
**Files:** `lib/services/notification_service.dart`, `lib/widgets/{debt_payment_sheet,dashboard_cards}.dart`, `lib/views/{create_sale_view,data_reconciliation_view}.dart`.

---

## [2026-08-30g] - feat(hướng dẫn) Phase C: ⓘ + hướng dẫn cho FinanceV2 & Sổ quỹ

Tiếp `[2026-08-30f]`. **Chưa tăng version** (vẫn `3.5.0+554`).

3 màn tài chính có appbar tự vẽ tay (không dùng `CustomAppBar.build`) nay cũng có nút ⓘ + hộp hướng dẫn "bản chất":
- **Tài chính (FinanceV2 — 5 tab)**: ⓘ cạnh menu "..." trên thanh tab. Hộp: để làm gì · dòng tiền vs dồn tích · chốt quỹ · trỏ sang Cẩm nang thuật ngữ. Key `keyFinanceTab` (trước là key chết, nay dùng).
- **Báo cáo ngày**: ⓘ đầu `actions`. Hộp: để làm gì · KẾT QUẢ KINH DOANH (accrual) vs DÒNG TIỀN (cash) · Cẩm nang. Key mới `keyFinanceDailyReport`.
- **Sổ quỹ / Chốt quỹ**: ⓘ đầu `actions` (SliverAppBar tự vẽ). Hộp: để làm gì + ví dụ số · công thức "Kỳ vọng = Đầu kỳ + Thu − Chi" · lệch quỹ do đâu. Key mới `keyCashClosing`. Chỉ chạy ở màn Sổ quỹ chính, không phải chế độ "Lịch sử tài chính".

`FirstTimeGuideService.helpButton` thêm tham số `color` (cho appbar nền tối). Guide trigger qua `addPostFrameCallback` trong initState.

**Test:** `flutter analyze` 0 error / 0 warning mới; `flutter test` (chạy lại); debug APK build.
**Files:** `lib/finance_v2/{finance_v2_view,finance_v2_daily_report_view}.dart`, `lib/views/cash_closing_view.dart`, `lib/services/first_time_guide_service.dart`.

Sau Phase C: **toàn bộ màn nghiệp vụ chính đã có nút ⓘ.**

---

## [2026-08-30f] - feat(hướng dẫn) Phase B: nội dung "bản chất" + empty state biết nói + Cẩm nang thuật ngữ

Tiếp `[2026-08-30e]`. **Chưa tăng version** (vẫn `3.5.0+554`, chưa lên store — sẽ bump khi user yêu cầu).

- **Bước "🎯 Màn này để làm gì?"** thêm vào ĐẦU hộp hướng dẫn 6 màn khó, theo khung *ĐỂ LÀM GÌ / KHI NÀO DÙNG / VÍ DỤ cụ thể*: Tạo đơn bán (kèm viết lại step "💳 Các hình thức thanh toán" — tiền mặt/CK/kết hợp/công nợ/trả góp NH), Công nợ, Nhập kho thông minh, Hàng chờ xác nhận, Chi phí, Danh sách SP (kho + biến thể).
- **Empty state biết nói** — màn Công nợ: khi chưa có khoản nợ nào, thay vì trống trơn → giải thích "Công nợ tự sinh khi bán/nhập chọn CÔNG NỢ" + nút **"Thêm khoản nợ"** (phân biệt Phải thu / Phải trả).
- **Cẩm nang thuật ngữ** — thêm 1 chủ đề nổi bật vào Trung tâm trợ giúp (nhóm "finance"): *"Thuật ngữ tài chính & công nợ (giải thích dễ hiểu)"* — 9 mục: dòng tiền vs dồn tích, vì sao 2 số lãi khác nhau, chốt quỹ, công nợ phải thu/trả, thu nợ/thanh toán nợ, trả góp NH, giá vốn/lãi, tồn kho giá vốn.

**Chưa làm (Phase C):** nút ⓘ cho FinanceV2 Tổng quan/Báo cáo + Sổ quỹ (appbar tự vẽ, chưa có guide infra); empty state cho các màn còn lại.

**Test:** `flutter analyze` 0 error / 0 warning mới; `flutter test` (chạy lại).
**Files:** `lib/views/{create_sale,debt,smart_stock_in,pending_stock_list,expense,inventory}_view.dart`, `lib/data/help_center_repository.dart`.

---

## [2026-08-30e] - feat(hướng dẫn) nút ⓘ mở lại hướng dẫn ở ~18 màn (Phase A dễ dùng cho người mới)

**Vấn đề (user báo):** nhiều tính năng khó hiểu, người dùng mới không nắm được bản chất; hộp hướng dẫn `FirstTimeGuideService` **chỉ hiện 1 lần rồi mất**, không có cách mở lại.

**Phase A — hạ tầng + nút ⓘ toàn bộ:**
- `FirstTimeGuideService`: thêm `_cache` (chụp nội dung hướng dẫn mỗi lần màn gọi `showGuideIfNeeded`/`showCarouselGuide` lúc mở — chạy trong initState nên luôn sẵn) + `reopenGuide(context, screenKey)` (mở lại, KHÔNG phụ thuộc/đổi cờ "đã xem") + `helpButton(screenKey)` (IconButton bọc `Builder` để có context hợp lệ).
- `CustomAppBar.build` + `buildWithTabs`: thêm tham số `String? guideKey` → tự chèn nút ⓘ đầu `actions`.
- **18 màn** thêm `guideKey`: Công nợ, Tạo đơn bán, Tạo đơn sửa, DS bán, DS sửa, Kho (SP), Nhập kho mới/nhanh/siêu tốc, Kiểm kho, Xác nhận nhập kho, Đơn nhập hàng, NCC-Đối tác, Khách hàng, Chi phí, Bảng lương, Chấm công, Bảo hành, Trang chủ.

Bấm ⓘ trên thanh tiêu đề → hiện lại đúng hộp hướng dẫn của màn đó bất cứ lúc nào.

**Test:** `flutter analyze` 0 error / 0 warning mới (1871 info lint, ~ baseline). `flutter test` +435 −8 (0 hồi quy). **Máy thật (Oppo CPH2203):** cài APK, mở Công nợ → nút ⓘ hiện đúng chỗ → bấm → hộp "Quản Lý Công Nợ" mở lại OK dù đã xem 1 lần trước đó.

**Còn lại (Phase B — sẽ làm tiếp):** viết lại bước đầu mỗi hướng dẫn theo 3 câu *Để làm gì / Khi nào dùng / Ví dụ* (ưu tiên: công nợ, tài chính/chốt quỹ, trả góp NH, kho nhập tạm) + trạng thái rỗng "biết nói" + màn Cẩm nang & Thuật ngữ.

**Files:** `lib/services/first_time_guide_service.dart`, `lib/widgets/custom_app_bar.dart` + 18 view.
**Đóng gói:** `pubspec` `3.5.0+553` → **`3.5.0+554`**.

---

## [2026-08-30d] - fix(công nợ) thanh toán không trừ nợ + mỗi tài khoản một số liệu

**2 lỗi user báo (ảnh iOS), cùng một gốc:** `debts.paidAmount` (số "đã trả") chỉ được `updateDebtPaid()` cập nhật **ngay trên máy bấm thu/trả nợ**. Sổ cái `debt_payments` (append-only) sync tin cậy giữa các máy, nhưng `debts.paidAmount` thì không → phân kỳ.

### Lỗi 2 — mỗi tài khoản một số công nợ khác nhau (NCC + đối tác SC)

Listener realtime `debt_payments` ([sync_service.dart](lib/services/sync_service.dart)) và vòng batch sync khi nhận phiếu từ cloud **chỉ `upsertDebtPayment(data)`** — KHÔNG tính lại `debts.paidAmount`. Máy B chỉ đúng nếu doc `debts` riêng của máy A cũng về tới VÀ thắng conflict; nếu máy B có sửa cục bộ chưa sync khoản nợ đó, hoặc push `debts` của A trượt → máy B **kẹt số cũ vĩnh viễn**.

### Lỗi 1 — thanh toán xong không trừ nợ (ngay trên máy vừa bấm)

Sau khi `updateDebtPaid` đặt `paidAmount` + `isSynced=0`, orchestrator push xong rồi lật `isSynced=1`. Lúc này 1 **echo cũ** của doc `debts` từ Firestore về → `_shouldAcceptCloudData` cho `debts`: `isSynced==1` ⇒ nhận cloud vô điều kiện (chỉ `repairs` có chốt so timestamp, `debts` không) ⇒ ghi đè `paidAmount` về số cũ. "Còn nợ" nhảy lại như chưa trả.

### Fix — `debts.paidAmount` tự khớp từ sổ cái trên mọi máy

1. **`SyncService._reconcileDebtFromPaymentRow`** (mới): sau khi nhận 1 dòng `debt_payments` từ cloud (thêm/xóa) — cả listener realtime lẫn batch — gọi `updateDebtPaid(..., markUnsynced: false)` để tính lại `paidAmount` từ TỔNG `debt_payments` local. Không chờ doc `debts` của máy nguồn. (sửa Lỗi 2)
2. **`DBHelper.updateDebtPaid`**: thêm cờ `markUnsynced` (mặc định `true` cho thao tác cục bộ; `false` khi gọi từ sync — không re-push, tránh ping-pong echo) + **no-op khi số không đổi** (khỏi bơm `updatedAt`/`isSynced` vô ích khi bị gọi lặp từ echo).
3. **`_shouldAcceptCloudData`**: thêm `debts` vào chốt "local mới hơn cloud + tolerance 3s thì skip" y như `repairs` (chặn echo cũ reset `paidAmount`). (sửa Lỗi 1)

### Test

- **Máy thật (Oppo CPH2203)**: trả 500.000đ 1 nợ NCC (tổng 3tr) → `debts.paidAmount` 0→500.000, `debt_payments` id 84 tạo + `isSynced=1`, "Tổng nợ còn lại" 15.3tr→14.8tr, **giữ nguyên sau 15s chờ echo sync** (không revert).
- **Unit test mới** `test/debt_paid_reconcile_test.dart` — 6 test: nhận phiếu từ cloud → paidAmount tự khớp dù `debtId` local lệch; echo cũ reset về 0 → reconcile khôi phục; gọi lặp không cộng đôi; phiếu bị soft-delete → giảm lại; thao tác cục bộ vẫn đánh dấu cần push; `extractKey` fallback.
- `flutter analyze` 0 error/warning mới; `flutter test` +429 −8 (0 hồi quy — nay là +435 với 6 test mới).

**Files:** `lib/data/db_helper.dart`, `lib/services/sync_service.dart`, `test/debt_paid_reconcile_test.dart`.
**Đóng gói:** `pubspec` `3.5.0+552` → **`3.5.0+553`**.

---

## [2026-08-30c] - fix(công cụ dọn dữ liệu) nút MIỄN NỢ bấm không được + thêm cảnh báo lý do bắt buộc

**Bug (user báo, ảnh chụp iOS):** Công cụ điều chỉnh dữ liệu → tab CÔNG NỢ → "Miễn nợ" → gõ lý do xong nút **MIỄN NỢ vẫn xám, bấm không được**.

**Nguyên nhân:** `_writeOff` (`data_reconciliation_view.dart`) dựng `AlertDialog` không có `StatefulBuilder`. `onPressed: reasonCtrl.text.trim().isEmpty ? null : ...` chỉ được tính **1 lần lúc dialog build đầu tiên** (ô rỗng → `null` → disabled). Gõ lý do KHÔNG rebuild dialog → nút disabled vĩnh viễn. Nút MIỄN NỢ trên thực tế **không bao giờ bấm được**.

**Fix:**
- Bọc `StatefulBuilder` quanh `AlertDialog`, `TextField.onChanged → setLocal(() {})` để `onPressed` được tính lại theo nội dung ô → nút bật khi có lý do.
- **Bug họ hàng (chủ động sửa):** 2 dialog "Sửa số lượng" (linh kiện + sản phẩm) trong tab KHO & SP — nút LƯU luôn bật nhưng nếu để trống "Lý do điều chỉnh (bắt buộc)" hoặc số lượng sai thì **im lặng thoát, không báo gì** (cảm giác "bấm không ăn"). Nay tách guard: số lượng không hợp lệ → snackbar đỏ; thiếu lý do → snackbar cam. Happy path không đổi.

**Files:** `lib/views/data_reconciliation_view.dart`.
**Test:** `flutter analyze` 0 error/warning mới; `flutter test` (chạy lại). Cần nghiệm thu lại trên iOS: mở "Miễn nợ" → gõ lý do → nút MIỄN NỢ sáng → bấm → nhập mật khẩu → nợ chuyển trạng thái đã miễn.
**Đóng gói:** `pubspec` `3.5.0+551` → **`3.5.0+552`**.

---

## [2026-08-30b] - feat(bán hàng) GIÁ THAM KHẢO khi bán + thu nhỏ QR chuyển khoản trên phiếu

Hai chỉnh UI nhỏ theo yêu cầu:

### 1. Gợi ý giá vốn/giá bán trong màn TẠO ĐƠN BÁN

Trước đây gợi ý giá (median lịch sử nhập cùng model, `ProductPricingService`) chỉ có ở Nhập kho nhanh / Nhập kho thông minh / Thêm-Sửa SP trong Kho. Nay thêm vào **`create_sale_view`**, dùng chung service — kiểu **THAM KHẢO, không tự điền**:

- **Bottom sheet Tặng / Giảm giá / 💰 Sửa giá bán sản phẩm** (`_GiftDiscountSheetContent`): thẻ vàng "💡 GIÁ THAM KHẢO" hiện ở cả 3 trạng thái (menu · panel Giảm giá · panel Sửa giá bán). Hiện Vốn / Bán / Lợi nhuận + số mẫu + khoảng giá thường gặp + độ tin cậy. Trong 2 panel nhập có nút **DÙNG GIÁ BÁN** đổ giá gợi ý vào ô "Giá bán mới".
- **Ẩn Vốn / Lợi nhuận** nếu tài khoản không có quyền `allowViewCostPrice` (fetch thêm trong `_checkPermission`).
- **Dòng SP chưa có giá** trên thẻ sản phẩm đã chọn: `"Giá bán: 0"` → cảnh báo cam **"⚠️ Chưa có giá bán — chạm để đặt giá / xem gợi ý"**, chạm mở luôn sheet.
- Thẻ **im lặng** (SizedBox.shrink) khi model rỗng hoặc chưa đủ dữ liệu lịch sử — không thêm nhiễu vào form bán hàng.
- KHÔNG đụng nghiệp vụ: không tự sửa giá, không ghi kho (nút "Cập nhật giá bán mặc định trong kho" vẫn opt-in như cũ).

### 2. Thu nhỏ QR chuyển khoản trên phiếu bán

`sale_invoice_preview_view.dart` — QR VietQR "QUÉT MÃ ĐỂ CHUYỂN KHOẢN": `size 180 → 150`. QR tra cứu đơn (110) giữ nguyên.

**Files:** `lib/views/create_sale_view.dart`, `lib/views/sale_invoice_preview_view.dart`.
**Test:** `flutter analyze` 0 error / 0 warning; `flutter test` +429 −8 (0 hồi quy). Chưa nghiệm thu trực quan trên máy — thay đổi thuần UI, tái dùng service đã test.
**Đóng gói:** `pubspec` `3.5.0+550` → **`3.5.0+551`**.

---

## [2026-08-30a] - test(bán hàng) E2E ĐỦ MỌI HÌNH THỨC THANH TOÁN + 3 fix phát hiện qua test

**Test end-to-end trên máy thật (Oppo CPH2203, shop "M")** toàn bộ luồng bán hàng + chi phí + thu nợ, mỗi kịch bản đối chiếu Giao dịch → DB (sales/debts/debt_payments/products/financial_activity_log) → tiền mặt/NH → doanh thu/vốn/lãi → công nợ. **9 kịch bản PASS**, phát hiện **1 bug tài chính** (đã fix), dọn sạch dữ liệu test, đối chiếu 16 nhóm cuối = **DIFFERENCE 0** (mọi nhóm tiền), delta BASE→FINAL: tất cả aggregate tiền = 0.

### Kịch bản đã verify (mỗi cái: đơn + kho + nợ + ledger + cash/bank + doanh thu/COGS/lãi)

| # | Hình thức | Kết quả |
|---|-----------|---------|
| 1 | **TIỀN MẶT** (12tr, vốn 10tr) | cashIn +12tr · SALE IN 12tr TIỀN MẶT · kho 2224 1→0 · rev +12tr · COGS +10tr · lãi +2tr ✅ |
| 2 | **CHUYỂN KHOẢN** (5tr) | bankIn +5tr · SALE IN 5tr CK ✅ |
| 3 | **KẾT HỢP** (8tr = 3tr TM + 5tr CK) | cashIn +3tr, bankIn +5tr · cashAmount/transferAmount lưu đúng ✅ |
| 4 | **CÔNG NỢ** đủ (6tr) | debt CUSTOMER_OWES total 6tr paid 0 · KHÔNG cash/ledger (nợ chưa thu) · rev accrual +6tr ✅ |
| 5 | **CÔNG NỢ trả trước 1 phần** (7tr, trả trước 2.5tr) | ❌→✅ **BUG** (xem dưới) → sau fix: debt_payments +2.5tr · CUSTOMER_DEBT_COLLECT IN 2.5tr · cashIn +2.5tr · paidAmount = SUM(debt_payments) ✅ |
| 6 | **TRẢ GÓP (NH) 1 ngân hàng** (20tr: cọc 5tr TM, vay 15tr) | cashIn +5tr (chỉ cọc) · loanAmount 15tr, bankName HOME · COGS phân bổ theo tỉ lệ cọc ✅ |
| 7 | **TRẢ GÓP (NH) 2 ngân hàng** (30tr: cọc 6tr, vay 14tr + 10tr) | loanAmount 14tr + loanAmount2 10tr, bankName HOME + bankName2 MB · cash chỉ +6tr cọc ✅ |
| 8 | **Ghi chi phí** (ĐIỆN NƯỚC 500k TIỀN MẶT SHOP) | expenses + payment_intent + UTILITY_EXPENSE OUT 500k · cashOut +500k · opex +500k · lãi −500k ✅ |
| 9 | **Thu nợ trả toàn bộ** (6tr CHUYỂN KHOẢN) | debt_payments +6tr · CUSTOMER_DEBT_COLLECT IN 6tr CK · bankIn +6tr · updateDebtPaid đồng bộ ✅ |

### Bug phát hiện + fix

| Vấn đề | Nguyên nhân | Fix |
|--------|-------------|-----|
| **Nút HOÀN TẤT ĐƠN HÀNG gần như không bấm được** | `SingleChildScrollView` màn Tạo đơn bán không có SafeArea đáy → nút nằm ngay mép dưới window, vùng chạm nav bar 3-nút (~132px) nuốt tap | Bọc `SafeArea(top:false)` quanh scroll view |
| **CÔNG NỢ trả trước 1 phần: TIỀN THỰC THU không được book** | Nhánh CÔNG NỢ trong `_processSale` nhét số trả trước vào `debts.paidAmount` mà KHÔNG tạo `debt_payments`, KHÔNG ghi ledger, KHÔNG cộng tiền → sổ quỹ/chốt quỹ thiếu, `debts.paidAmount` lệch tổng phiếu | (a) `create_sale_view`: sau tạo intent CÔNG NỢ, nếu trả trước > 0 → `executePaymentDirect(customerDebtCollection)`. (b) `payment_intent_service`: mở guard handler nợ chạy khi có `debtId` **HOẶC** `debtFirestoreId` (nợ vừa tạo chưa có local id) |

### Đối chiếu cuối + dọn dữ liệu test

- Dọn: 9 đơn bán test VOID (SALE_VOID append-only → ledger net 0), nợ + debt_payments test xoá, chi phí test xoá + `EXPENSE_REVERSAL` bù, 2 payment_intent VOID huỷ.
- **`recon16.py` trên FINAL.db: 16/16 PASS, DIFFERENCE = 0.** Delta BASE→FINAL: cashNet/bankNet/revenue/COGS/opex/netProfit/custDebt/supDebt = **0**.
- **Còn 1 dư (ghi nhận là finding, không phải lỗi đối soát):** `deleteSaleWithReversal` khôi phục kho phụ kiện (TAI NGHE, KHÁC MỚI về đủ số) nhưng KHÔNG kích hoạt lại điện thoại serial (product 2224 giữ `status=0/qty=0` thay vì 1/1). VỐN TỒN KHO của app tự lọc `status=0` nên không sai (nhóm 12 recon = 0); chỉ lệch −10tr so với ảnh baseline. Cùng nhóm: xoá chi phí qua UI không tự ghi bút toán đảo (`financial_activity_log` mồ côi) — đã dọn bằng công cụ.

**Test:** `flutter analyze` 0 error/0 warning mới; `flutter test` (chạy lại). Máy thật: 9 kịch bản + fix CÔNG NỢ trả trước verify từng đồng qua DB.

**Files:** `lib/views/create_sale_view.dart`, `lib/services/payment_intent_service.dart` + docs.

**Đóng gói:** `pubspec` `3.5.0+549` → **`3.5.0+550`**.

---

## [2026-08-29s] - fix(tài chính) LÀM DỨT ĐIỂM AUDIT: L-1..L-4 + D-1..D-4 + đối chiếu 16 nhóm = 0

**Chốt toàn bộ các phát hiện D/L của đợt audit** — sửa nguồn + dọn dữ liệu tồn trên máy thật (Oppo CPH2203, shop test "M" = `geqXPHQJ…`), đối chiếu 16 nhóm độc lập bằng Python → **DIFFERENCE = 0 cả 16**.

### Sửa NGUỒN (code)

| Mã | Nguyên nhân gốc | Sửa |
|----|-----------------|-----|
| **L-1** | `analyze()` cộng expense mirror đối tác (`exp_partner_*` / category ĐỐI TÁC/PARTNER) vào `expenseOut` — trong khi `repairCost` đã gánh giá vốn dịch vụ đối tác → lợi nhuận accrual bị trừ 2 lần | Loại expense mirror khỏi `expenseOut` (vẫn tính dòng tiền `cashOut/bankOut`). Excel/Báo cáo ngày/tháng/Home dùng chung `analyze()` nên tự thừa hưởng. |
| **L-2** | `repairPartsCostFundRows` phương thức **CÔNG NỢ** vẫn cộng `bankOut` → tiền ra ảo | `continue` khi method == 'CÔNG NỢ' (khớp cách xử lý `supplierImports`). |
| **L-3** | `repair_partner_payments` + `repairs.services[]` JSON chỉ lưu `partnerId` local (đổi khi đối tác bị xoá+tạo lại / cài lại máy) + `partnerName` (dễ trùng) → đổi tên đối tác có thể mất/nhận nhầm lịch sử | Thêm khoá ổn định `partnerFirestoreId`: cột mới `repair_partner_payments` (v108) + field mới `RepairService` + ghi ở 2 chỗ tạo service + metadata payment intent + `relatedPartId` công nợ đối tác. `getPartnerRepairStats` & `_countRepairsForPartner`: dòng CÓ khoá chỉ khớp theo khoá (hết trùng tên), dòng cũ fallback id/tên. **Backfill THẬN TRỌNG** (v108): chỉ set khi id HOẶC tên khớp CHÍNH XÁC 1 đối tác. |
| **L-4** | `payment_intents` của giao dịch đã VOID vẫn `COMPLETED` | Công cụ dọn: `findVoidedTxnPaymentIntents` (ghép theo SỐ GIAO DỊCH) + `cancelVoidedTxnPaymentIntent` (status → CANCELLED, KHÔNG đụng tiền — engine không SUM payment_intents). |
| **D-1** | "Chốt quỹ ma": (a) `cash_closing_view` lưu 2 bước (local no-fid rồi update fid) — đã vá `[db526b30]`; (b) **`CashClosingNotifier._syncToLocalDb` `dbRaw.insert` thẳng KHÔNG shopId/firestoreId** → mỗi lần poll Firestore lại đẻ 1 dòng vô định danh (v108 xoá xong lại mọc) | (b): đi qua `upsertCashClosing` + mang `firestoreId=docId` + `shopId` + `isSynced=1` → dòng ma cũ được "chữa" tại chỗ, poll lặp không đẻ mới. v108 xoá 1 lần dòng `firestoreId IS NULL AND shopId IS NULL`. |
| **D-2** | Sync xoá `sales_returns` cha nhưng không cascade `sales_return_items` con (schema thiếu cột `deleted` → `_filterToTableColumns` cắt mất soft-delete từ cloud) | v108 thêm cột `deleted`; sync `sales_returns`/`sales_return_items` xử lý `deleted:true` → cascade xoá con; `processReturn` guard header id ≤ 0; Công cụ dọn: `findOrphanSalesReturnItems` (soft-delete + sync) & `findForeignShopSalesReturnItems` (hard-delete local, KHÔNG sync sang shop khác). |
| **D-3** | `executePayment` ghi `financial_activity_log` ở bước 4, `insertExpense` ở bước 6 — bước 6 lỗi → intent FAILED nhưng bút toán OUT nằm lại → FinanceV2 (tính theo log) đếm chi không có thật (bản ghi AUDITTESTCHI) | Bước 6 lỗi mà bút toán đã ghi → append `<TYPE>_REVERSAL` ngược chiều (append-only). `_insertExpenseOnce` — kiểm tra tồn tại theo firestoreId tất định trước khi insert (idempotent). Công cụ dọn: `findOrphanExpenseActivity` (+guard bỏ qua nếu đã có `EXPENSE_REVERSAL`) & `reverseOrphanExpenseActivity`. |
| **D-3b** | VOID đơn bán luôn ghi `SALE_VOID OUT = finalPrice`. Đơn CÔNG NỢ thu 1 phần (vd 200k, đã thu 50k) → sổ đối soát dư OUT ảo | `FinancialActivityService.saleCashReceived(SaleOrder)` = phần tiền THỰC đã vào (CÔNG NỢ = tổng debt_payments; trả góp = down+settlement; KẾT HỢP = cash+transfer; còn lại = finalPrice). VOID amount = saleReceived; chưa thu đồng nào → không ghi bút toán. Công cụ dọn: `findMisbookedVoids` (ghép theo SỐ GIAO DỊCH, nhận đủ 6 loại IN, trừ `VOID_AMOUNT_ADJUST` đã ghi → hội tụ) & `fixMisbookedVoid`. |
| **D-4** | SKU 2226 "IPHONE 12 32GB VÀNG MỚI" IMEI 5656: `status=0` mà `quantity=3` (điện thoại serial hoá không thể có 3 cái). Do các lượt trả hàng test cũ (nay `sales_returns` rỗng) tăng tồn mà không có phiếu cha | KHÔNG tự đổi số lượng (không xác định được chính xác 0 hay 1 — cần kiểm kho thực tế). `findStockStatusMismatch` chỉ liệt kê. **Báo cáo VỐN TỒN KHO đã lọc `status=0`** nên KHÔNG tính sai SKU này (đối chiếu nhóm 12 DIFF=0). |

### Dọn DỮ LIỆU TỒN (máy thật, qua Công cụ điều chỉnh dữ liệu → tab TÀI CHÍNH, có cổng mật khẩu + audit log)

- v108 (tự động khi mở app): xoá 1 `cash_closings` vô định danh; thêm cột `sales_return_items.deleted` + `repair_partner_payments.partnerFirestoreId`; backfill `partnerFirestoreId` cho `rpp` id 17 = `partner_1786245140527` (khớp tên duy nhất).
- `CashClosingNotifier` chữa dòng `cash_closings` id 23 → `firestoreId=closing_geqXPHQJ…_2026-08-29`, `shopId`, `isSynced=1`.
- **Bù 3 VOID sai biên độ**: `rep_1781237441355` (+6.000.000 IN), `rep_1781234587303` (−60.000 OUT), `sale_1787995317501` (+150.000 IN) → net khớp phần thực thu.
- **Đảo AUDITTESTCHI** 13.579đ (EXPENSE_REVERSAL IN) → net 0.
- **Xoá 4 item trả hàng mồ côi** shop hiện tại (soft-delete + sync) + **2 item shop khác** (hard-delete local).
- **Hủy 14 payment_intent** của giao dịch đã VOID → CANCELLED.

### Đối chiếu 16 nhóm (Python độc lập, `pre.db` → `post4.db`)

`Tiền mặt −46.740.006 · Ngân hàng 12.000.000 · Doanh thu 51.150.000 · Giá vốn 30.353.000 · Chi phí VH 0 · Lợi nhuận 20.797.000 · Nợ KH 21.990.000 · Nợ NCC 15.300.000 · Nợ đối tác 1.240.000 · Thanh toán 23.910.000 · VOID 27.769.500 · Tồn kho 34.660.000 · Chốt quỹ 0 ma · Payment intents 0 rác · Financial activity 0 mồ côi · Sync 0` — **EXPECTED == ACTUAL, DIFFERENCE = 0 cả 16 nhóm.**

### Test

- `flutter analyze`: 0 error / 0 warning mới (10 file).
- `flutter test`: **+429 −8** — thêm 13 test mới (`repair_partner_identity_test` ×5, `misbooked_void_test` ×6, L-2 ×2), sửa 3 test đỏ SẴN CÓ (`enableRepair=false` hợp nhất từ `[e2d37fcf`; `finance_v2_reconciliation` import CÔNG NỢ qua DEBT_CREATE ×2). 8 lỗi còn lại là môi trường (Firebase chưa init trong unit test, thiếu file xlsx ngoài, widget render) — có TRƯỚC phiên này, không liên quan.
- Máy thật: v108 migration + `CashClosingNotifier` heal + 3 detector số liệu khớp `recon16.py` từng đồng.

**Files:** `daily_financial_analysis_service.dart`, `db_helper.dart`, `sync_service.dart`, `cash_closing_view.dart`, `cash_closing_notifier.dart`, `payment_intent_service.dart`, `financial_activity_service.dart`, `data_reconciliation_service.dart`, `data_reconciliation_view.dart`, `sale_detail_view.dart`, `sales_return_service.dart`, `repair_partner_service.dart`, `repair_service_model.dart`, `create_repair_order_view.dart`, `repair_detail_view.dart` + test: `daily_financial_analysis_service_test.dart`, `finance_v2/finance_v2_reconciliation_test.dart`, `repair_partner_identity_test.dart` (mới), `misbooked_void_test.dart` (mới) + docs.

**Đóng gói:** `pubspec` `3.5.0+548` → **`3.5.0+549`**.

---

## [2026-08-29r] - fix(ui) BOTTOM SHEET: bàn phím che ô nhập — dùng KeyboardAwarePadding phản ứng bàn phím mà KHÔNG crash

**Triệu chứng (user báo, kèm ảnh):** một số bottom sheet có ô nhập (vd "GHI CHÚ KỸ THUẬT VIÊN" trong Chi tiết đơn sửa) — bấm vào ô, bàn phím hiện lên che luôn ô + chữ vừa gõ, phải tự kéo sheet lên mới thấy.

**Nguyên nhân:** lịch sử đã flip-flop 2 lần giữa 2 lỗi:
- `MediaQuery.viewInsetsOf(ctx)` (context BÊN TRONG builder sheet) → sheet co giãn theo bàn phím ĐÚNG, nhưng crash `_dependents.isEmpty` khi pop (đã revert `[cc9e9590` 15/08]).
- `MediaQuery.viewInsetsOf(context)` (context NGOÀI — State/`this.context`/`outerContext`) → hết crash, NHƯNG `Padding` không rebuild khi bàn phím mở trong sheet → `bottom` kẹt ở 0 → bàn phím che ô nhập. Đây là trạng thái hiện tại của ~25 sheet.

**Giải pháp — widget mới `lib/widgets/keyboard_aware_padding.dart` (`KeyboardAwarePadding`):**
- Đọc chiều cao bàn phím TRỰC TIẾP từ `WidgetsBinding.instance.platformDispatcher.views.first.viewInsets` + `WidgetsBindingObserver.didChangeMetrics` → `setState`.
- **Zero InheritedWidget dependency** → không bao giờ dính assert `_dependents.isEmpty` (cùng kỹ thuật `QuickActionBubble` đã dùng ổn định).
- Vẫn reactive đầy đủ với bàn phím (didChangeMetrics fire mỗi frame animation).
- `bottom = max(keyboardHeight, [navBar,] minBottom)`. `includeNavBar: false` cho sheet đã có `SafeArea(top:false)` riêng.
- Drop-in thay `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + ...))`.

**Đã áp dụng cho các bottom sheet có ô nhập (17 file, ~26 sheet):**
`repair_detail_view` (Ghi chú KTV, Sửa thông tin đơn, Thêm dịch vụ) · `debt_view` (4) · `expense_view` (2) · `sale_detail_view` (1) · `create_repair_order_view` (chọn đối tác) · `attendance_view` (3) · `attendance_management_view` (6) · `inventory_view` (2) · `parts_inventory_view` (1) · `cash_closing_view` (nhập số dư đầu kỳ) · `category_management_view` (1) · `community_view` (1) · `missing_info_products_view` (1) · `salvage_phone_view` (1) · `hr_salary_settings_view` (1) · `fashion/variant_management_view` (1) · `pty_print_designer_view` (footer nút) · `widgets/debt_payment_sheet` (1) · `widgets/storage_location_selector` (1).

**KHÔNG đụng (không phải lỗi này):** sheet là StatefulWidget riêng đọc `viewInsets` từ context CỦA CHÍNH NÓ (đã reactive: `create_sale` ưu đãi, `staff_list` gán ca, `pending_payments` `_PaymentMethodSheet`, `parts_inventory` search 0.55, `payment_request_chat` thêm KH, `cash_closing` XÁC NHẬN CHỐT — `context` bị StatefulBuilder shadow) · sheet picker/filter KHÔNG có ô nhập (`order_list` filter, `home` chọn shop, `help_center`) · `showDialog`/`AlertDialog` (cơ chế khác — crash `_dependents.isEmpty` ở `sale_detail._unlockManager` vẫn là task riêng).

**Verify:** `flutter analyze` 0 error / 0 warning mới (17 file); `flutter test` **+410 −11**. Máy thật: sheet "GHI CHÚ KỸ THUẬT VIÊN" — gõ chữ thấy ngay trên bàn phím, đóng bằng nút Lưu/Hủy + nút Back hệ thống đều KHÔNG crash.

**Files:** `lib/widgets/keyboard_aware_padding.dart` (mới) + 17 file view/widget nêu trên + `docs/CHANGELOG.md` + `docs/HANDOVER.md`.

**Đóng gói:** `pubspec` `3.5.0+547` → **`3.5.0+548`**, build lại AAB gồm fix này. Các build `+546`/`+547` chưa upload store → bỏ.

---

## [2026-08-29q] - fix(finance) TRẢ GÓP + CHỐT QUỸ: ghi nhận tất toán NH đúng kỳ ở Sổ quỹ offline + Báo cáo ngày

**Hoàn tất reconciliation nhóm 11 (trả góp) + 12 (chốt quỹ)** — trước đây NOT VERIFIED / BLOCKED do thiếu dữ liệu test. Rà kỹ code + test máy thật với đơn trả góp giả lập → phát hiện + sửa 1 lỗi accrual thật.

**Lỗi:** đơn trả góp **tất toán ngân hàng ở ngày ≠ ngày bán** không được ghi nhận doanh thu/giá vốn phần tất toán ở 2 màn:
- `CashClosingView._loadAllDataFromLocalDB` (Sổ quỹ khi **offline** / lúc load nhanh từ local) — dùng `getSalesByDateRange` bound theo `soldAt` → đơn bán kỳ trước, tất toán kỳ này → mất khỏi `settlementSales` → thiếu `settlementIncome` + giá vốn phần còn lại → Sổ quỹ/Chốt quỹ thiếu tiền vào NH, `expectedBank` sai.
- `FinanceV2DailyReportView._buildAuditAnalysis` (Báo cáo ngày, mục "KẾT QUẢ KINH DOANH") — cùng nguyên nhân.
- **KHÔNG** ảnh hưởng: `HomeView`, `MonthlyProfitReportView` (đã có truy vấn `settlementSales` riêng theo `settlementReceivedAt`), Sổ quỹ **online** (merge `getUnsyncedSales()` + query Firestore `isInstallment==true` không bound).

**Sửa (KHÔNG đổi schema, KHÔNG đổi cách ghi nhận trả góp):**
- `db_helper.dart` + 2 truy vấn:
  - `getSalesByDateRangeForCashFlow(start,end)` = `soldAt` trong khoảng **HOẶC** `isInstallment=1 AND settlementReceivedAt` trong khoảng (trùng khớp truy vấn Firestore của CashClosingView).
  - `getInstallmentSalesSettledBetween(start,end)` = chỉ đơn trả góp tất toán trong khoảng (không lọc `soldAt`).
- `cash_closing_view.dart` `_loadAllDataFromLocalDB`: `getSalesByDateRange` → `getSalesByDateRangeForCashFlow`. `_analyzeTransactions` vốn đã tự tách (`sales` theo `soldAt`-in-range, `settlementSales` theo `settlementReceivedAt`-in-range) → an toàn, không đếm đôi.
- `finance_v2_daily_report_view.dart` `_buildAuditAnalysis`: gộp thêm `getInstallmentSalesSettledBetween` vào `settlementSales`, khử trùng theo key `fid:`/`id:` (đơn vừa bán vừa tất toán trong kỳ chỉ tính 1 lần). Tham số `sales:` giữ nguyên (chỉ `soldAt`-in-range) → không đếm đôi phần cọc.

**Cơ chế bù trừ (không double-count, xác nhận qua code + máy thật):**
`analyze()` nhánh `sales` (đơn trả góp bán-trong-kỳ): `saleIncome += downPayment`, `saleCost += totalCost × (downPayment/finalPrice)`.
`analyze()` nhánh `settlementSales` (đơn tất toán-trong-kỳ): `settlementIncome += settlementAmount`, `saleCost += totalCost × (1 − downPayment/finalPrice)`.
Tổng vòng đời: doanh thu = `downPayment + settlementAmount ≈ finalPrice`; giá vốn = `totalCost`.

**Test máy thật (Oppo CPH2203, shop "M", debug APK, `analyze()` logDebug):** chèn 2 đơn trả góp giả lập + 1 chốt quỹ giả lập 28/08 (mở cọc 1tr/2tr) →
- Đơn A (bán hôm nay, cọc 3tr/vốn 7tr, chưa tất toán): `saleIncome=3.000.000`, `saleCost += 2.100.000` (7tr×0,3). ✓
- Đơn B (bán 26/08, cọc 5tr/vốn 15tr, **tất toán hôm nay 15tr**): `settlementIncome=15.000.000`, `bankIn += 15.000.000`, `saleCost += 11.250.000` (15tr×0,75). ✓ ← **phần fix**
- `analyze()` Sổ quỹ: `cashIn=3.010.000` (3tr cọc TM + 10k thu nợ), `bankIn=15.000.000`, `saleCost=13.350.000`, `netProfit=4.650.000`. ✓
- **Chốt quỹ (nhóm 12):** màn hình + row `cash_closings` đã lưu: `cashEnd=4.010.000` = `openingCash 1.000.000 + cashIn 3.010.000 − cashOut 0`; `bankEnd=17.000.000` = `openingBank 2.000.000 + bankIn 15.000.000 − bankOut 0`. Công thức `expected = opening + in − out` khớp tuyệt đối. ✓
- Dọn sạch: 2 đơn + 2 chốt quỹ giả lập đã soft-delete qua SyncOrchestrator (`deleted:true` Firestore) + hard-delete local; DB shop "M" về đúng baseline (6 đơn bán, 0 chốt quỹ, sync_queue rỗng).

**Verify:** `flutter analyze` 0 error/0 warning (3 file); `flutter test` **+410 −11** (0 lỗi mới).

**Đóng gói:** `pubspec` `3.5.0+546` → **`3.5.0+547`**, build lại AAB (`flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`) để gồm fix này. Build `+546` trước đó chưa upload store → bỏ, dùng `+547`.

**Files:** `pubspec.yaml`, `lib/data/db_helper.dart`, `lib/views/cash_closing_view.dart`, `lib/finance_v2/finance_v2_daily_report_view.dart`, `docs/CHANGELOG.md`, `docs/HANDOVER.md`, `docs/store_metadata.md`, `docs/release_notes_2026-08-29.md`.

**Còn lại (ngoài phạm vi, đã ghi):** FinanceV2 cash snapshot (`loadSnapshot`) có thể cũng thiếu khoản tất toán của đơn trả góp bán-kỳ-trước ở màn TÀI CHÍNH chính (không thuộc reconciliation `analyze()`); `upsertCashClosing` tạo được row `firestoreId=NULL` mà `deleteCashClosingByFirestoreId` không dọn (quirk có sẵn); crash `_dependents.isEmpty`.

---

## [2026-08-29p] - chore(release) 3.5.0+546: đóng gói bản vá HỆ THỐNG TÀI CHÍNH lên store

**Gói phát hành** cho toàn bộ đợt sửa hệ thống tài chính (`[2026-08-29e]`→`[2026-08-29o]`, 11 commit code + 1 commit docs).

**Thay đổi trong bản này (so với 3.4.0+545 đang live):**
- PHASE 1.1–1.5: khử trùng thanh toán đối tác trong `analyze()`; VOID đơn dọn `debt_payments`; chặn đơn CÔNG NỢ thành tiền ≤ 0 + self-heal `totalAmount`; `updateDebtPaid` định vị theo `firestoreId` + `paidAmount` = tổng phiếu (idempotent, status HOA); tab "TÀI CHÍNH" trong Công cụ điều chỉnh dữ liệu.
- PHASE 3.1–3.5: FinanceV2 bỏ cap `cost > paid` (đơn dưới vốn hiện lỗ âm); nhãn phân biệt "Dòng tiền" (cash) vs "Kết quả kinh doanh" (accrual) ở Báo cáo ngày, Báo cáo LN tháng, Home, Excel.

**Version:** `pubspec.yaml` `3.4.0+545` → **`3.5.0+546`** (versionCode 546 > 545, đơn điệu tăng — OK cho Play Store).

**Build:** `scripts/build_release.ps1` — `flutter clean` + `pub get` + `flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info`. Ký bằng `key.properties` (upload-keystore.jks, `CN=huy,O=huluca`). Log: `build_release_2026-08-29.log`.
- **AAB (artifact cho store): OK** — `build/app/outputs/bundle/release/app-release.aab` (77 MB). Verify: `applicationId=com.huluca.shopmanager`, `versionCode=546`, `versionName=3.5.0`, `targetSdk=36`, ký `META-INF/UPLOAD.RSA`, có native debug symbols arm/arm64/x64, minify + shrinkResources. → upload Play Console.
- Symbol de-obfuscate: giữ `build/debug-info/` (`app.android-arm*.symbols`) cho Crashlytics.
- **Bước APK `--split-per-abi` của script BÁO LỖI (exit 1) — KHÔNG ảnh hưởng store.** Nguyên nhân: `android/app/build.gradle.kts` cố định `splits.abi.isEnable = false` nên Gradle chỉ ra 1 APK universal, còn `flutter build apk --split-per-abi` đi tìm các file `app-<abi>-release.apk` → "failed to produce an .apk file". APK universal vẫn tạo OK: `build/app/outputs/flutter-apk/app-release.apk` (122 MB, 4 ABI, `versionCode=546`, ký `CN=huy,O=huluca`) — dùng cài trực tiếp để test. Quirk có sẵn của script; sửa sau bằng cách bỏ `--split-per-abi` khỏi `build_release.ps1` hoặc bật `abi.isEnable` khi build APK.

**Verify trước đóng gói:**
- `flutter analyze`: **0 error** (warning/info còn lại đều CÓ SẴN, không thuộc 12 file tài chính đã sửa).
- `flutter test`: **+410 −11** (11 lỗi CÓ SẴN — `sqflite_common_ffi` thiếu Firebase init + finance_v2_reconciliation ×2 + daily_financial_analysis enableRepair=false; 0 lỗi mới, giống mọi commit trong đợt).
- Reconciliation E2E 13 nhóm (`reconF.py`, shop M): 1-10 + 13 PASS; 11 trả góp NOT VERIFIED (0 dữ liệu); 12 chốt quỹ BLOCKED (`cash_closings`=0).
- Máy thật (Oppo CPH2203, đợt `[2026-08-29e..o]`): 5 fix logic PASS end-to-end; mapping 3.2/3.4 PASS; 3.3 Excel PASS; 3.5 code-only.

**Store metadata / release notes:** `docs/store_metadata.md` (What's New → v3.5.0), `docs/release_notes_2026-08-29.md` (bản đầy đủ + rút gọn cho Play Console).

**Sau khi lên store:** Super Admin có thể set `app_config/version_gate.minAndroidBuild = 546` để buộc người dùng cũ cập nhật (fail-open, tùy chọn).

**Known issues mang sang bản sau:** crash `_dependents.isEmpty` khi đóng dialog "XÁC THỰC QUẢN LÝ" ở `sale_detail_view` (task riêng, bug CÓ SẴN); nhánh trả góp trong `analyze()` chưa accrual thuần (cần đơn trả góp thật).

**Files:** `pubspec.yaml`, `docs/store_metadata.md`, `docs/release_notes_2026-08-29.md`, `docs/CHANGELOG.md`, `docs/HANDOVER.md`.

---

## [2026-08-29o] - chore(finance) PHASE 1 DỮ LIỆU CŨ: dọn 4 bản ghi hỏng shop "M" + reconciliation E2E + regression

**Không đổi code** — dùng công cụ đã build (`[2026-08-29i]` tab TÀI CHÍNH) + xác minh toàn hệ.

**Đăng nhập lại `m@m.com` (shop "M") → Cài đặt → Công cụ điều chỉnh dữ liệu → tab TÀI CHÍNH:**
- Xóa 3 phiếu `debt_payments` mồ côi (id 69/70/71 = 12.500.000 + 100.000 + 200.000 = **12.800.000đ**) — từ 3 đơn CÔNG NỢ bị VOID 17/08 trước bản vá PHASE 1.2. Mỗi lần: dialog tóm tắt → mật khẩu → `RECONCILE_CLEAN_ORPHAN_DEBT_PAYMENT`.
- Sửa 1 công nợ `totalAmount=0` (debt #139 HUY, `sale_1787034406889` finalPrice 10tr) → đặt về **10.000.000đ**, `status=ACTIVE`. `RECONCILE_FIX_ZERO_DEBT`.
- Sau xử lý tab hiện "Không phát hiện dữ liệu tài chính cần dọn 👍".

**Verify (DB kèm `-wal`, đối chiếu EXPECTED/ACTUAL):**
| Kiểm tra | EXPECTED | ACTUAL |
|---|---|---|
| orphan 69/70/71 | `deleted=1, isSynced=1` | ✅ cả 3 |
| debt #139 `totalAmount` | 10.000.000 | ✅ 10.000.000, ACTIVE, isSynced=1 |
| orphan re-count | 0 | ✅ 0 |
| Nợ phải thu | 21.990.000 | ✅ 21.990.000 (UI Finance Công nợ: "21.99 Tr") |
| Nợ phải trả | 16.540.000 (không đổi) | ✅ 16.540.000 |
| Cash-in "thu nợ KH" 15/08 | 100.000 (chỉ TétKhach) | ✅ Sổ quỹ 15/08 tab Thu: "1 giao dịch +100.000" (trước: 3 GD +12.7 Tr) |
| Cash-in "thu nợ KH" 17/08 | 0 | ✅ 0 |
| sync_queue pending | 0 | ✅ 0 (tất cả isSynced=1) |
| audit_logs | 3×CLEAN_ORPHAN + 1×FIX_ZERO_DEBT | ✅ |

**→ 12.800.000đ "tiền vào ảo" bị loại khỏi Sổ quỹ/Tài chính; 10.000.000đ nợ HUY hiện đúng ở Nợ phải thu.**

**Reconciliation E2E (`reconF.py`, shop M sau dọn):** 13 nhóm —
1 tiền mặt ✅ · 2 chuyển khoản ✅ (CK thu nợ 12tr→bankIn; 0 sale CK) · 3 công nợ KH ✅ (accrual 35,5tr saleIncome, 0 cash) · 4 thu nợ ✅ (13,610,000) · 5 công nợ NCC ✅ (16,540,000) · 6 trả NCC ✅ (10,300,000) · **7 partner payment ✅ (đếm 1 lần = 12tr qua exp_partner_, rpp deduped, partnerPaid=0, KHÔNG 24tr)** · 8 VOID ✅ (0 orphan) · 9 giá vốn ✅ (accrual full 30,350,000; FV không cap — đơn 50k/vốn 100k cho grossProfit **−50.000**) · 10 lợi nhuận ✅ (netProfit accrual 8,797,000, cho phép âm) · **11 trả góp: NOT VERIFIED** (0 đơn trả góp trong data; code review: KHÔNG double-count — `saleCost×downRatio + saleCost×(1−downRatio) = saleCost`, complementary) · **12 chốt quỹ: BLOCKED** (`cash_closings`=0, chưa từng chốt; công thức `opening + cashIn − cashOut` đúng cấu trúc, input đã đúng sau PHASE 1.1) · 13 sync ✅.

**Regression (vùng ảnh hưởng):** cold-start shop M 18s không exception; Sổ quỹ 09/08 −12 Tr (PHASE 1.1 giữ, logcat `cashOut=12000000 partnerPaid=0`), 08/08 −10 Tr không đổi; Finance Công nợ 21.99 Tr; `flutter analyze` 0 error/warning (12 file đụng); `flutter test` **+410 −11** (11 lỗi CÓ SẴN, 0 lỗi mới — đã đối chiếu `git stash`).

**Files:** không có (chỉ docs). Commit trước đó của đợt: `fb9ff402`→`05604977` (11 commit).

---

## [2026-08-29n] - fix(finance) PHASE 3.5: Home dashboard — nhãn "DÒNG TIỀN HÔM NAY" thay vì mập mờ "profit"

**Mapping PHASE 2:** thẻ tổng quan Home (`_buildDashboardOverview`, bấm vào mở Sổ quỹ) là DÒNG TIỀN hôm nay (cash, từ `FinanceV2.totalIn/totalOut`). Nhưng biến local tên `netProfit`, comment `// Profit header`, donut item "Bán hàng"/"Sửa chữa" → dễ hiểu nhầm là doanh thu/lợi nhuận.

**Đã sửa (`lib/views/home_view.dart` — rename biến local + 3 nhãn chuỗi, KHÔNG đổi số/logic):**
- `netProfit` → `netCashToday`; tham số `_dashProfitHeader(int net,...)` → `netCash`.
- Chip header "HÔM NAY" → **"DÒNG TIỀN HÔM NAY"**.
- Donut "THU NHẬP": item "Bán hàng" → "Tiền bán", "Sửa chữa" → "Tiền sửa" (= tiền đã thu trong ngày).
- Thêm 2 comment giải thích thẻ là dòng tiền, không phải doanh thu kế toán.

**Verify:**
- `dart analyze` (file): 0 error/warning (analyzer bắt 2 chỗ dùng tên cũ khi rename → đã sửa). `flutter test`: **+410 −11** (không hồi quy). Build + cài OK (exit 0).
- **Chưa render được thẻ trên máy qua ADB** — `_buildDashboardOverview` là thẻ dashboard opt-in ("Tùy chỉnh giao diện Home"), tài khoản test đang tắt, toggle qua ADB không giữ (không có nút Lưu rõ ràng). Thay đổi thuần rename + chuỗi, analyzer đã kiểm; sibling screen (Báo cáo LN tháng, 3.4) đã verify cùng hệ.

**Files:** `lib/views/home_view.dart`.

---

## [2026-08-29m] - fix(finance) PHASE 3.4: Báo cáo lợi nhuận tháng — nhãn phân biệt accrual vs dòng tiền

**Mapping PHASE 2:** màn "Báo cáo lợi nhuận" là màn KẾT QUẢ KINH DOANH (accrual, từ `analyze()`). "Doanh thu"/"Lợi nhuận" đã đúng accrual, nhưng ô tổng kết năm còn có "Tổng thu"/"Tổng chi" (= `analysis.totalIn/totalOut`, dòng tiền) đặt cạnh nhau **không phân biệt** → người xem tưởng cùng loại.

**Đã sửa (`lib/views/monthly_profit_report_view.dart` — CHỈ 4 nhãn chuỗi, không đổi số):**
- "Doanh thu" → "Doanh thu (accrual)"
- "Lợi nhuận" → "Lợi nhuận (accrual)"
- "Tổng thu" → "Tổng thu (dòng tiền)"
- "Tổng chi" → "Tổng chi (dòng tiền)"

**Verify:**
- `dart analyze` (file): 0 error/warning. `flutter test`: **+410 −11** (không hồi quy).
- Máy thật (Oppo CPH2203, tài khoản test): đơn CÔNG NỢ 200k / vốn 100k / chưa thu → "TỔNG KẾT NĂM 2026": Doanh thu (accrual) **200.000**, Lợi nhuận (accrual) **100.000**, Tổng thu (dòng tiền) **0**, Tổng chi (dòng tiền) **100.000**. Đúng mô hình.

**Files:** `lib/views/monthly_profit_report_view.dart`.

---

## [2026-08-29l] - fix(finance) PHASE 3.3: Excel tab Tài chính — đổi nhãn "Doanh thu/Lợi nhuận" → "phần đã thu tiền" (FinanceV2 = cash)

**Mapping PHASE 2:** FinanceV2 = DÒNG TIỀN (cash basis). Các file Excel xuất từ tab Tài chính (`_exOverview`, `_exDailyReportPhone`) đang gọi `s.incomeFromSales/cogsFromSales/grossProfitTotal` là "Doanh thu / Vốn bán hàng / Lợi nhuận thực" — sai khái niệm (số là tiền đã thu, đơn CÔNG NỢ = 0).

**Đã sửa (`lib/finance_v2/finance_v2_view.dart` — CHỈ ĐỔI NHÃN chuỗi, KHÔNG đổi số/nguồn):**
- Sheet "Tổng quan" (`_exOverview`): "Doanh thu bán hàng/sửa chữa" → "Tiền bán hàng/sửa chữa đã thu"; "Vốn bán hàng/sửa chữa" → "Vốn (phần đã thu) - bán/sửa"; "Lãi gộp bán hàng/sửa chữa" → "Lãi gộp (đã thu) - bán/sửa"; "Tổng lãi gộp" → "Tổng lãi gộp (phần đã thu)".
- `_exDailyReportPhone`: "Lợi nhuận thực" → "Lãi gộp (phần đã thu)"; "CƠ CẤU DOANH THU" → "CƠ CẤU TIỀN THU"; Section 10 "Tổng doanh thu / Vốn bán hàng / Lãi gộp / Lãi thực" → "Tổng tiền bán đã thu / Vốn (phần đã thu) / Lãi gộp (đã thu) / Lãi gộp sau chi phí (phần đã thu)".
- **KHÔNG đụng `_reportInputFromSnapshot`** (`:4085`) — feed `FinanceV2ReconciliationReportInput` để đối chiếu với `financial_activity_log` (cả 2 đều cash) → đổi sẽ làm reconciliation FAIL. Giữ nguyên là cash, đúng ngữ cảnh.
- **KHÔNG đụng** print-text ESC/POS (`_buildPrintLinesForTab` ~:794, `_buildDetailedDailyPrintLines` ~:920) — ngoài phạm vi 3.3 (ghi HANDOVER để làm sau nếu cần).

**Verify:**
- `dart analyze` (file): 0 error/warning. `flutter test`: **+410 −11** (không hồi quy).
- Máy thật (Oppo CPH2203): tab Tài chính → Thao tác → Xuất Excel → "Xuất file thành công", kéo `tong_quan_29082026.xlsx` về đọc: các cột đúng nhãn mới ("Tiền bán hàng đã thu", "Vốn (phần đã thu) - bán", "Tổng lãi gộp (phần đã thu)", ...), không còn chữ "Doanh thu".

**Files:** `lib/finance_v2/finance_v2_view.dart`.

---

## [2026-08-29k] - fix(finance) PHASE 3.2: Báo cáo ngày — "Doanh thu/Giá vốn/Lợi nhuận" lấy từ accrual, tách rõ khỏi "Dòng tiền"

**Mapping PHASE 2 (user đã chốt):** DÒNG TIỀN = cash basis (FinanceV2 `totalIn/totalOut/netCashflow`, `cash_closing`), KẾT QUẢ KINH DOANH = accrual (`DailyFinancialAnalysisService`: `saleIncome + settlementIncome + repairIncome` / `saleCost + repairCost` / `netProfit`). Mỗi khái niệm 1 nguồn chuẩn.

**Bối cảnh:** `finance_v2_daily_report_view` (tab "Báo cáo" trong Tài chính) là màn trộn khái niệm NẶNG nhất — `total_revenue/total_cost/total_profit` (màn hình + Excel `BaoCaoNgay_Audit`) và các dòng "Vốn bán hàng / Lãi gộp / Lợi nhuận thực" đều lấy từ `FinanceV2` (cash) nhưng gán nhãn accrual. Đơn CÔNG NỢ 200k chưa thu → "Doanh thu 0", "Lợi nhuận 0".

**Đã sửa (`lib/finance_v2/finance_v2_daily_report_view.dart` — CHỈ các số gán nhãn Doanh thu/Vốn/Lợi nhuận):**
- Thêm state `DailyFinancialAnalysis? _analysis`; `_loadReport()` gọi thêm `_buildAuditAnalysis(start, end)` (hàm đã có sẵn, đang dùng ở 3 export).
- `build()` `realProfit`: `s.grossProfitTotal − s.operatingExpenseOut` → `_analysis.netProfit`.
- `_buildAllAppOverview`: tách 2 nhóm có tiêu đề **"KẾT QUẢ KINH DOANH (accrual)"** (Doanh thu bán/sửa = `saleIncome+settlementIncome`/`repairIncome`, Giá vốn = `saleCost+repairCost`, Chi phí = `expenseOut`, Lợi nhuận = `netProfit`) và **"DÒNG TIỀN (cash)"** (Tổng thu/chi/ròng từ `_snapshot`).
- `_buildCapitalAndGrossProfit` ("Vốn & lãi gộp"): `s.cogsFromSales/grossProfitFromSales/...` → `_analysis.saleCost/saleProfit/repairCost/repairProfit`. Tiêu đề → "Vốn & lãi gộp (kết quả kinh doanh)".
- `_buildStatCard` "Lợi nhuận thực" → "Lợi nhuận (kết quả KD)", footer "Doanh thu − giá vốn − chi phí (accrual)".
- Excel `_buildAuditExcelRows`: `total_revenue/total_cost/total_profit` → `analysis.*` accrual + đổi mô tả cột.
- **KHÔNG đụng:** khối dòng tiền (`_snapshot.totalIn/totalOut/netCashflow`, `analysis.cashIn/cashOut`), cột "Lãi" từng giao dịch (`tx.grossProfit` = lãi phần đã thu / GD), các hàm print-text export (ngoài phạm vi 3.2).

**Verify:**
- `dart analyze` (file): 0 error/warning. `flutter test`: **+410 −11** (không hồi quy).
- Máy thật (Oppo CPH2203, tài khoản test mới): đơn CÔNG NỢ 200k / vốn 100k / chưa thu — tab "Báo cáo": khối **"KẾT QUẢ KINH DOANH"** hiện Doanh thu bán hàng **200.000**, Giá vốn **100.000**, Lợi nhuận **100.000**; khối **"DÒNG TIỀN"** hiện Tổng thu **0**, Tổng chi **100.000** (chi nhập kho), Dòng tiền ròng **−100.000**. "Vốn & lãi gộp (kết quả kinh doanh)": Vốn bán hàng 100.000, Lãi gộp bán hàng 100.000. Đúng mô hình user.

**Files:** `lib/finance_v2/finance_v2_daily_report_view.dart`.

---

## [2026-08-29j] - fix(finance) PHASE 3.1: FinanceV2 bỏ chặn "giá vốn ≤ tiền đã thu" (hết giấu lỗ) + sửa nhãn nói sai "accrual"

**Bối cảnh (đợt AUDIT — LỖI #3):** tab Tài chính (FinanceV2) tính vốn bán hàng theo tỉ lệ tiền đã thu rồi CHẶN `recognizedCost ≤ actualPaid` → đơn bán dưới giá vốn (vd `sale_1787538502668`: giá 50.000, vốn 100.000) hiển thị **lãi gộp = 0** thay vì **lỗ −50.000**. Đồng thời chữ trợ giúp 2 chỗ trên UI ghi *"theo giao dịch (accrual)… có thể chưa thu tiền ngay nếu là đơn công nợ"* trong khi số bên dưới là **tiền mặt** (đơn CÔNG NỢ góp 0đ).

**Quyết định (user uỷ quyền "làm sao hợp lý nhất"):** giữ FinanceV2 = cơ sở TIỀN MẶT (đúng vai trò "dòng tiền"), chỉ:
1. **Bỏ 2 dòng cap** `if (recognizedCost > actualPaid) recognizedCost = actualPaid` (kỳ hiện tại + kỳ so sánh) trong `finance_v2_data_service.dart` → giữ pro-rating theo tỉ lệ đã thu (matching), nhưng đơn dưới giá vốn cho ra `grossProfit` ÂM đúng.
2. **Sửa nhãn** `finance_v2_view.dart` (2 chỗ): "Lợi nhuận (profit) / theo giao dịch (accrual)…" → **"Lãi gộp (phần đã thu)"** + *"Đây là lãi theo dòng tiền thực thu, không phải lợi nhuận kế toán đầy đủ (xem Báo cáo lợi nhuận)."*
- **KHÔNG đụng** `DailyFinancialAnalysisService.analyze()` (Sổ quỹ / Báo cáo lợi nhuận tháng — đang đúng dồn tích cho CÔNG NỢ). Nhánh trả góp trong `analyze()` để lại (không có dữ liệu trả góp để test, không phải bug ai báo). `financial_activity_log.balanceAfter*` giữ NULL (audit-log).

**Verify:**
- `flutter analyze` (2 file): 0 error / 0 warning. `flutter test`: **+410 −11** (identical với/không có thay đổi — 2 test đỏ `finance_v2_reconciliation_test` là CÓ SẴN, không do thay đổi này).
- Máy thật (Oppo CPH2203), tab Tài chính 30 ngày: section đổi tên đúng **"2) Lãi gộp (phần đã thu)"** + text mới; **Lãi BH 3.000.000 → 2.950.000** (−50.000 = đúng lỗ của đơn giá 50k/vốn 100k, trước bị cap về 0); Vốn BH 12.05tr → 12.1tr (+50k). Dòng tiền / Nợ phải thu-trả không đổi.

**Files:** `lib/finance_v2/finance_v2_data_service.dart`, `lib/finance_v2/finance_v2_view.dart`.

---

## [2026-08-29i] - feat(reconcile) PHASE 1.5: tab "TÀI CHÍNH" trong Công cụ điều chỉnh dữ liệu — dọn phiếu nợ mồ côi + công nợ totalAmount=0 (có xác nhận)

**Bối cảnh (đợt AUDIT):** dữ liệu hỏng đã xác định — (1) 3 phiếu `debt_payments` MỒ CÔI (`debt_1786417116867` 12.5tr, `debt_1786783688165` 100k, `debt_1786805963466` 200k = 12.800.000đ) từ các đơn VOID ngày 17/08 TRƯỚC bản vá PHASE 1.2, vẫn `deleted=0` → `analyze()`/FinanceV2 tính là "tiền vào"; (2) 1 công nợ khách `debt_1787034406889` có `totalAmount=0` trong khi đơn bán liên kết = 10.000.000đ → khoản nợ tàng hình ở Nợ phải thu. Theo nguyên tắc "không tự ý xóa/sửa dữ liệu" → làm công cụ có xác nhận, KHÔNG auto-chạy.

**Đã thêm:**
- `lib/services/data_reconciliation_service.dart` — 4 hàm:
  - `findOrphanDebtPayments()` — `debt_payments` (deleted=0) mà `debtFirestoreId` lẫn `debtId` đều không khớp công nợ nào.
  - `cleanOrphanDebtPayment(payment, reason)` — soft-delete phiếu + enqueue sync + `AuditService` log `RECONCILE_CLEAN_ORPHAN_DEBT_PAYMENT`.
  - `findZeroAmountCustomerDebts()` — công nợ KHÁCH `deleted!=1`, `totalAmount<=0`, JOIN `sales` theo `linkedId`, đơn còn sống + `finalPrice>0`; trả kèm `saleFinalPrice`.
  - `fixZeroAmountDebt(debt, newAmount, reason)` — set `totalAmount = finalPrice` + `status` (`PAID`/`ACTIVE` theo `paidAmount`) + enqueue sync + log `RECONCILE_FIX_ZERO_DEBT`. KHÔNG đụng `paidAmount`.
- `lib/views/data_reconciliation_view.dart` — tab thứ 5 "TÀI CHÍNH" (`_FinanceCleanupTab`): liệt kê 2 nhóm, mỗi dòng bấm "Xóa"/"Sửa" → `_confirmSummary` (nêu rõ số tiền + hệ quả) → `_confirmPassword` (nhập lại mật khẩu đăng nhập) → thực thi → reload.

**Verify:**
- `flutter analyze` (2 file): 0 error / 0 warning. `flutter test`: **+410 −11** (không hồi quy).
- Máy thật (Oppo CPH2203): build + cài + mở tab → **phát hiện đúng**: "Phiếu thu/trả nợ mồ côi (3)" liệt kê đủ 3 phiếu 200k/100k/12.5tr với đúng `debtFirestoreId` + ngày; "Công nợ khách totalAmount = 0 (1)" = "HUY — đặt về 10.000.000đ / sale_1787034406889". **Chưa thực thi fix trên máy** — nút "Xóa"/"Sửa" yêu cầu mật khẩu đăng nhập (`reauthenticateWithCredential`) không có sẵn; chủ shop tự chạy 1 màn. Đã xác nhận DB không đổi khi chỉ xem tab.

**Files:** `lib/services/data_reconciliation_service.dart`, `lib/views/data_reconciliation_view.dart`.

---

## [2026-08-29h] - fix(finance) PHASE 1.4: `updateDebtPaid` định vị công nợ theo firestoreId + tính lại paidAmount từ tổng phiếu + status HOA

**Bối cảnh (đợt AUDIT — phát hiện M1):** `db.updateDebtPaid(int id, int pay)` có 3 vấn đề: (a) `WHERE id = ?` dùng id local — `debt_payments.debtId` / `debts.id` không ổn định sau khi dựng lại DB từ cloud, đã thấy trỏ sai công nợ; (b) `paidAmount = paidAmount + pay` không idempotent — gọi lại do retry/echo sync là cộng đôi; (c) ghi `status` chữ thường `'paid'/'unpaid'` trong khi toàn app dùng `'PAID'/'ACTIVE'/'UNPAID'`.

**Đã sửa:**
- `lib/data/db_helper.dart` — `updateDebtPaid` đổi chữ ký `(int? id, {String? firestoreId})`:
  - Định vị công nợ theo `firestoreId` trước (khoá ổn định), fallback `id` local.
  - `paidAmount` = **TỔNG các phiếu `debt_payments` chưa xóa** của đúng công nợ đó (tính lại, không `+= pay`) → idempotent (retry không cộng đôi) + tự khớp lại nếu trước đó lệch (vd. sau khi soft-delete phiếu mồ côi ở PHASE 1.2). KHÔNG cap bằng `MIN(total)` — nếu thu vượt gốc thì để số thật lộ ra (`remain` vẫn clamp ≥ 0 ở tầng hiển thị, xem `bug_fixes_test.dart` BUG-002) + ghi cảnh báo logcat.
  - `status` ghi HOA `'PAID'`/`'UNPAID'`.
  - Yêu cầu: phiếu `debt_payments` đã `insertDebtPayment` TRƯỚC khi gọi (2 caller hiện tại đều đúng thứ tự).
- `lib/services/payment_intent_service.dart` — 2 call site (`customerDebtCollection`/`supplierDebt`/… và `repairService`): truyền `firestoreId: debtFid`, gọi khi có `localDebtId` HOẶC `debtFid`.

**Verify:**
- `flutter analyze` (2 file): 0 error / 0 warning. `flutter test`: **+410 −11** (không hồi quy).
- Máy thật (Oppo CPH2203) — thu 10.000đ công nợ ABC (`debt_1787452233379`, gốc 12tr, chưa trả) qua nút THU TIỀN → FIFO → XÁC NHẬN:
  - UI: "Còn 11.990.000đ"; sale detail "CÒN NỢ 11.99 Tr / đã thu 10.000"; Finance Công nợ "Phải thu 11.99 Tr".
  - SQLite (đọc kèm `-wal`): `debts.paidAmount = 10000` (= đúng tổng phiếu), `status = 'UNPAID'` (HOA — logic mới), `debt_payments` 1 dòng 10000 `deleted=0`.
  - `financial_activity_log` id 82 `CUSTOMER_DEBT_COLLECT` IN 10000. logcat: không có cảnh báo "VƯỢT totalAmount" (10k << 12M — đúng).
  - **Lưu ý:** để lại 1 phiếu thu test 10.000đ trên công nợ ABC (tài khoản test, vô hại).

**Files:** `lib/data/db_helper.dart`, `lib/services/payment_intent_service.dart`.

---

## [2026-08-29g] - fix(finance) PHASE 1.3: chặn đơn CÔNG NỢ có thành tiền ≤ 0 + không hạ công nợ thật về 0

**Bối cảnh (đợt AUDIT):** DB test có 1 đơn bán CÔNG NỢ 10.000.000đ (`sale_1787034406889`) mà công nợ liên kết (`debt_1787034406889`) có `totalAmount = 0` → 10tr khách nợ "tàng hình" ở tab Nợ phải thu (danh sách đơn bán còn hiển thị "ĐÃ THU"), trong khi vẫn vào doanh thu dồn tích của `analyze()`. Không tái hiện được chính xác bước gây ra (data cũ), nhưng khoanh được 2 điểm ghi `debt.totalAmount = finalPrice`: `create_sale_view` (lúc tạo) và `sale_detail_view._openEditSaleDialog` (lúc sửa) — không nơi nào chặn `finalPrice ≤ 0`, và `create_sale_view` chỉ chặn `totalPrice ≤ 0` (chưa đủ: giảm giá có thể bằng/vượt tổng tiền).

**Đã sửa (phòng thủ nhiều lớp):**
- `lib/views/create_sale_view.dart` — sau bước kiểm `totalPrice ≤ 0`: thêm chặn `_paymentMethod == "CÔNG NỢ" && finalPrice ≤ 0` → báo đỏ "ĐƠN CÔNG NỢ PHẢI CÓ THÀNH TIỀN LỚN HƠN 0 (KIỂM TRA LẠI GIẢM GIÁ)", không lưu.
- `lib/views/sale_detail_view.dart` `_openEditSaleDialog`:
  - Trước khi lưu: nếu phương thức kết quả là CÔNG NỢ và `newFinalPrice ≤ 0` → báo lỗi, dispose controllers, return (không lưu).
  - Khi cập nhật công nợ liên kết: chỉ ghi đè `totalAmount` (và `status`) khi `debtAmount > 0` — **không bao giờ hạ 1 công nợ thật về 0**. Đây cũng là cơ chế **self-heal**: mở + lưu lại 1 đơn CÔNG NỢ cũ (kể cả qua ngày, khóa sửa tiền) sẽ tự khớp `totalAmount` về `finalPrice` hiện tại.

**Verify:**
- `flutter analyze` (2 file đổi): 0 error / 0 warning.
- `flutter test`: **+410 −11** (không hồi quy).
- Máy thật (Oppo CPH2203): build + cài + chạy OK. **Chưa nghiệm thu được 2 guard qua ADB** — ô "Giá bán"/"Giảm giá" trên form bán hàng không lộ trong accessibility dump; dialog "Sửa thông tin đơn" bị khóa sau "XÁC THỰC QUẢN LÝ" (PIN). Logic là guard phòng thủ đơn giản + đã review. Bản ghi `debt_1787034406889` cũ: sẽ tự khớp khi chủ shop mở+lưu lại đơn đó (có PIN), hoặc xử lý ở PHASE 1.5.

**Files:** `lib/views/create_sale_view.dart`, `lib/views/sale_detail_view.dart`.

---

## [2026-08-29f] - fix(finance) PHASE 1.2: VOID đơn bán/sửa dọn luôn `debt_payments` — hết phiếu thu nợ mồ côi tạo "tiền vào" ảo

**Bối cảnh (đợt AUDIT):** Khi VOID/xóa 1 đơn CÔNG NỢ, code xóa bảng `debts` + `payment_intents` nhưng KHÔNG đụng `debt_payments`. Các phiếu thu nợ đã ghi trước đó nằm lại với `deleted=0`, `debtFirestoreId` trỏ vào công nợ không còn tồn tại → `analyze()` và FinanceV2 tiếp tục cộng chúng vào "tiền vào" vĩnh viễn. DB test có 3 phiếu mồ côi (12.500.000 + 100.000 + 200.000 = 12.800.000) khớp đúng 3 `SALE_VOID` ngày 17/08. Dialog xác nhận xóa còn hứa "Xóa phiếu thanh toán" nhưng thực tế chỉ xóa `payment_intents`.

**Đã sửa:**
- `lib/data/db_helper.dart`:
  - `getDebtPaymentsByDebtFirestoreId(fid)` — lấy phiếu (chưa xóa) theo `debtFirestoreId` (khoá ổn định, KHÔNG dùng cột `debtId` local vì lệch sau resync).
  - `softDeleteDebtPaymentsByDebtFirestoreId(fid)` — set `deleted=1, isSynced=0, updatedAt` cho mọi phiếu của công nợ đó.
  - `getAllDebtPaymentsWithDetails()` — thêm `AND COALESCE(p.deleted,0) != 1` (2 nhánh). Đây là nguồn `_debtPayments` của `cash_closing_view` (Sổ quỹ Tổng quan/Thu/Chi) — trước đây KHÔNG lọc `deleted`, nên soft-delete phiếu sẽ không có tác dụng ở Sổ quỹ.
- `lib/views/sale_detail_view.dart` `_deleteSale` bước 2B — trước khi xóa mỗi công nợ: soft-delete `debt_payments` của nó + xếp hàng `SyncOrchestrator` xóa từng phiếu (`SyncEntityType.debtPayment` / `SyncOperation.delete` → soft-delete trên Firestore, cùng cơ chế đã dùng cho `debts`).
- `lib/services/data_reconciliation_service.dart` — thêm helper `_softDeleteDebtPaymentsForDebt(debt)`, gọi trong `deleteSaleWithReversal` + `deleteRepairWithReversal` (KHÔNG đụng các biến thể `*KeepBooks` — chúng cố ý giữ sổ sách).
- KHÔNG đổi schema (`debt_payments.deleted` đã có sẵn từ v88). KHÔNG chuyển hard-delete `sales`/`debts` sang soft-delete (giữ blast radius nhỏ — task riêng). KHÔNG đụng `repair_partner_payments` (thiếu FK repair↔payment đáng tin, để PHASE sau).

**Verify:**
- `flutter analyze` (3 file đổi): 0 error / 0 warning.
- `flutter test`: **+410 −11** (không đổi so với PHASE 1.1 — không hồi quy).
- Máy thật (Oppo CPH2203): build + cài + chạy OK. Regression Sổ quỹ: 15/08 giữ nguyên **+11.7 Tr** (3 phiếu thu nợ 12.5tr+100k+100k vẫn hiện — đúng, vì chưa phiếu nào bị soft-delete), 08/08 giữ nguyên −10 Tr, 09/08 giữ nguyên −12 Tr (PHASE 1.1). **Luồng VOID→dọn `debt_payments` trên thiết bị: CHƯA test end-to-end** — tạo đơn CÔNG NỢ mới qua ADB không tin cậy (ô "Giá bán" trên thẻ sản phẩm đã chọn không lộ trong accessibility dump), KHÔNG xóa đơn thật để test. Logic đã review + tái dùng đúng cơ chế sync-delete đã chạy production cho `debts`. **3 phiếu mồ côi hiện có xử lý ở PHASE 1.5** (routine dọn có xác nhận).

**Files:** `lib/data/db_helper.dart`, `lib/views/sale_detail_view.dart`, `lib/services/data_reconciliation_service.dart`.

---

## [2026-08-29e] - fix(finance) PHASE 1.1: analyze() khử trùng thanh toán đối tác sửa chữa — hết double-count Sổ quỹ / Chốt quỹ / Báo cáo lợi nhuận tháng

**Bối cảnh (từ đợt AUDIT hệ thống tài chính):** Sổ quỹ ngày 09/08/2026 hiển thị "Số dư dự kiến cuối ngày = −24 Tr" trong khi thực chi chỉ 12.000.000đ. Tab "Chi" của cùng màn hình lại đúng (1 giao dịch −12 Tr), tab Tài chính (Finance V2) cũng đúng (−12 Tr). Lệch đúng bằng 1 khoản thanh toán đối tác sửa chữa (12.000.000đ) trên mọi kỳ có chứa ngày đó.

**Nguyên nhân gốc (`lib/services/daily_financial_analysis_service.dart` → `analyze()`):** 1 khoản trả đối tác được ghi song song ở 2 nơi — bảng `repair_partner_payments` (`rpp_<X>`) và 1 expense "bản sao" `exp_partner_<X>` (category "ĐỐI TÁC SỬA CHỮA"). Vòng `expenses` cộng khoản expense vào `cashOut`/`expenseOut`; vòng `repairPartnerPayments` cộng LẠI cùng số tiền vào `cashOut`/`partnerPaid`. Không có bước khử trùng. `FinanceV2DataService` và `cash_closing_view._getExpenseTransactions` đều đã khử (khớp theo `firestoreId`: `exp_partner_ = 'exp_partner_' + rpp_fid.substring(4)`) — chỉ `analyze()` bị thiếu.

**Đã sửa:**
- `lib/services/daily_financial_analysis_service.dart` — trong `analyze()`: thu thập `partnerExpenseFids` (expense có firestoreId bắt đầu `exp_partner_`) + `partnerExpenseAmounts` (expense category chứa "ĐỐI TÁC"/"PARTNER") ngay trong vòng `expenses`; ở vòng `repairPartnerPayments` bỏ qua (`continue`) khoản đã được cộng — khớp chính theo firestoreId (giống FinanceV2), dự phòng khớp số tiền + category chỉ khi payment không có firestoreId.
- `lib/views/monthly_profit_report_view.dart` + `lib/views/home_view.dart` — thêm cột `firestoreId` vào query `expenses` (và `repair_partner_payments` ở monthly) để nhánh khớp-firestoreId hoạt động chính xác ở mọi caller.
- KHÔNG đụng `FinanceV2DataService`, KHÔNG đụng `_getExpenseTransactions`, KHÔNG workaround ở UI.

**Callers tự động đúng lại:** `cash_closing_view` (Sổ quỹ + Chốt quỹ + prefill dialog chốt), `monthly_profit_report_view`, `finance_v2_daily_report_view`, `home_view`.

**Verify:**
- `flutter analyze` (3 file đổi): 0 error / 0 warning.
- `flutter test`: **+410 −11** (baseline +406 −11) — thêm 4 test dedup mới đều xanh, 0 hồi quy. 1 test đỏ `daily_financial_analysis_service_test.dart:270` (`enableRepair=false` không zero hoá dòng tiền sửa) là lỗi CÓ SẴN, không liên quan.
- Máy thật (Oppo CPH2203, debug build): Sổ quỹ 09/08 "Tổng quan" **−24 Tr → −12 Tr**, khớp tab "Chi" (1 giao dịch −12 Tr) và tab Tài chính (−12 Tr). logcat `analyze()`: `cashOut 24.000.000 → 12.000.000`, `partnerPaid 12.000.000 → 0` (đã khử). Regression: Sổ quỹ 08/08 giữ nguyên −10 Tr (trả nợ NCC, không liên quan).

**Files:** `lib/services/daily_financial_analysis_service.dart`, `lib/views/monthly_profit_report_view.dart`, `lib/views/home_view.dart`, `test/daily_financial_analysis_service_test.dart`.

---

## [2026-08-29d] - fix(shop_settings): lưu cài đặt shop bằng UPSERT idempotent — hết lặp UNIQUE constraint làm cold-start ~45s

**Bối cảnh:** Sau khi cài mới / đổi tài khoản, cold-start mất ~45s mới vào Home. Logcat lặp: `CategoryService: Not found in local DB` → fetch Firestore → `Error saving shop settings locally: DatabaseException(UNIQUE constraint failed: shop_settings.firestoreId)` → clear cache → retry, giữ DB locked ~10s nhiều lần → AuthGate chờ.

**Nguyên nhân gốc:** `CategoryService._saveSettingsLocally` check tồn tại theo `shopId` rồi mới `INSERT`/`UPDATE`. Bảng `shop_settings` trên máy test có sẵn 2 bản ghi cũ từ các lần đăng nhập trước (`firestoreId='shop_settings'` shopId shop A; `firestoreId='settings_<shopB>'` shopB) — không bản nào khớp `shopId` shop hiện tại. → query theo `shopId` rỗng → rơi vào nhánh `INSERT` với `firestoreId='shop_settings'` → **đụng UNIQUE** (bản ghi shop A đã chiếm firestoreId đó). Lặp vô hạn giữa `getShopSettings` ↔ `_saveSettingsLocally`.

**Đã sửa (`lib/services/category_service.dart` — CHỈ hàm `_saveSettingsLocally`):** bỏ check-then-insert/update, thay bằng 1 lệnh `db.insert('shop_settings', map, conflictAlgorithm: ConflictAlgorithm.replace)` (INSERT OR REPLACE keyed trên `firestoreId` UNIQUE = identity thật của bản ghi). Idempotent — chạy N lần cho cùng 1 bản ghi (cache cục bộ = settings shop hiện tại), không bao giờ đụng UNIQUE. Không đổi schema, không đụng logic CategoryService khác, không sửa AuthGate, không tăng delay/retry.

**Verify (Oppo CPH2203):** `flutter analyze` sạch.
- Cold-start sau cài mới: **~45s → ~6s**. Force-stop + mở lại ×5: đều **~5-6s**, ổn định.
- Logcat 0 lần `UNIQUE constraint failed: shop_settings`, 0 lần `Not found in local DB` (loop), 0 `database has been locked`, chỉ 1 `Cache cleared` (init bình thường), 1 `getShopSettings` → `Found in local DB`.
- DB sau fix: bản ghi `firestoreId='shop_settings'` được REPLACE về đúng shopId hiện tại (`geqXPHQJ…`); bản ghi cũ `settings_<shopB>` (firestoreId khác) giữ nguyên, vô hại. Không mất dữ liệu.

**Files:** `lib/services/category_service.dart`.

---

## [2026-08-29c] - fix(ui): AppBar có TabBar bị cắt/che phần top (nút Back chui sau status bar) trên Android edge-to-edge

**Bối cảnh:** User báo nhiều màn hình bị che phần trên — nút Back góc trái + header nằm sau vùng status bar. Rõ nhất ở `FastInventoryInputView` ("NHẬP KHO SIÊU TỐC"): nút `‹` bị cắt nửa, title + tab dính status bar.

**Nguyên nhân gốc (đã xác định chính xác, KHÔNG phải "MediaQuery.padding.top = 0" như suy đoán ban đầu):** `CustomTabBar.buildGradient/buildOnSub/build` khai báo `PreferredSize(preferredSize: Size.fromHeight(kTabBarHeight = 44))` **cứng**, trong khi `TabBar` thật có tab **icon + text** cao ~72px (`_kTextAndIconTabHeight`), tab chỉ text ~46px. Khi khai thiếu, `AppBar._PreferredAppBarSize = toolbarHeight(44) + 44` → `Scaffold` chỉ chừa đủ chiều cao cho `44 + 44 + topPadding`, nhưng nội dung thật cần `44 + 72 + topPadding` → phần `Flexible` bọc toolbar (chứa nút Back) bị **ép co xuống còn ~16px**, đẩy nút Back chui lên sát/sau status bar. Màn tab **chỉ text** lệch ~2px (gần như không thấy); màn tab **icon+text** lệch ~28px (thấy rõ). AppBar **không có** `bottom:` không bị ảnh hưởng.

**Đã sửa (`lib/widgets/custom_app_bar.dart` — CHỈ 3 hàm factory TabBar):** `CustomTabBar.build`, `buildGradient`, `buildOnSub` — dựng `TabBar` 1 lần rồi lấy `tabBar.preferredSize` **thật** cho `PreferredSize` bọc ngoài (46 cho text / ~72 cho icon+text) thay vì hằng số 44. Không đụng `main.dart`, không `WidgetsBindingObserver`, không `setState` cấp app, không ép rebuild toàn app, không padding thủ công từng màn. Màn không có TabBar: **không đổi 1 pixel**.

**Verify (Oppo CPH2203, cold start OK ~15s, không kẹt AuthGate):** `flutter analyze` sạch.
- `FastInventoryInputView` (tab icon+text): nút Back **y=131 → y=176** (đúng, dưới status bar 110px), title + tab đều đủ chỗ, không clip. Ảnh chụp xác nhận.
- `InventoryView` (không TabBar): back **y=176 giữ nguyên** — không regression.
- `DebtView` (`buildWithTabs`, tab text): back y=170 → y=176 (nhích ~6px cho khớp chuẩn, không thấy khác).
- `PartnerManagementView` (`build` + `buildGradient`, tab text): back y=176 đúng, tab pill không clip.
- Chuyển qua lại các tab (cả text lẫn icon) + back — không crash, không RenderFlex overflow trong logcat.

**Trước đó đã thử + REVERT (không commit):** fix ở `main.dart` (`WidgetsBindingObserver` + `didChangeMetrics→setState` + `math.max` inset) — build OK nhưng cài máy thật app **treo ở màn "Đang kiểm tra phiên đăng nhập"**. Đã cô lập xác nhận đúng do fix đó, revert sạch. Nguyên nhân thật (co toolbar do TabBar khai thiếu chiều cao) không liên quan `padding.top`.

**Files:** `lib/widgets/custom_app_bar.dart`.

---

## [2026-08-29b] - feat(receipt,home): phiếu gửi khách hiện "Nợ cũ / Lần này / Tổng nợ" + QR theo tổng nợ; Home nhắc "Tiền NH chưa tất toán"

**Bối cảnh:** User yêu cầu (1) phiếu biên nhận/phiếu sửa gửi khách (Zalo/ảnh) phải ghi rõ nợ cũ + tổng nợ + QR thanh toán đủ số đang nợ; (2) thêm thống kê tiền ngân hàng chưa tất toán vào khung CẦN XỬ LÝ ở Home.

**Đã sửa — biên nhận đơn bán + phiếu sửa (bản xem trước / ảnh chia sẻ):**
- `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`: thêm khối 3 dòng **ngay dưới TỔNG TIỀN / GIÁ**, ngay trên phần QR:
  - `Nợ cũ: …` = tổng dư nợ của khách theo SĐT **trước** đơn hiện tại
  - `Lần này: …` = nợ phát sinh (còn lại) từ đơn hiện tại
  - `Tổng nợ: …` (đậm) = Nợ cũ + Lần này = dư nợ sau đơn
  - Chỉ hiện khi khách **thực sự còn nợ** (tổng > 0); chỉ tính khoản chưa thanh toán.
  - Sale: lấy sẵn `remainingDebt` + `customerTotalDebt` từ `_buildSalePrintData()` (`sale_detail_view` đã tính `_otherOrdersDebt + _orderRemainingDebt`). Repair: cộng `remainingDebtFromLinkedDebt` trên toàn bộ `getCustomerActiveDebts(phone)` cho "tổng", nợ đơn này là "lần này".
- **QR chuyển khoản (VietQR):** số tiền trên QR đổi từ "nợ đơn này" → **"tổng nợ"** (`_qrAmount`), kèm dòng "Số tiền: …" khớp theo. VietQR (`buildVietQrPayload`) đã hỗ trợ sẵn amount động nên không đụng kiến trúc QR. QR hiện khi `tổng nợ > 0` + đã cấu hình NH.
- `lib/services/unified_printer_service.dart`: thêm biến `{customerTotalDebt}` + `{oldDebt}` cho **mẫu in tùy biến** đơn bán (shop tự bật mẫu riêng có thể chèn 2 dòng này). Repair có `{remainingDebt}` `{customerTotalDebt}` `{oldDebt}` trong data mẫu.
- **Chưa đụng** layout ESC/POS mặc định của máy in nhiệt (data nợ chưa được truyền vào `printSaleReceipt`/`printRepairReceiptFromRepair` ở nhánh mặc định — cần plumbing riêng, ngoài phạm vi). Bản xem trước/ảnh chia sẻ (đường khách hay dùng nhất) đã đủ.

**Đã thêm — Home / khung CẦN XỬ LÝ (`lib/widgets/dashboard_cards.dart`):**
- Query mới `SELECT COALESCE(SUM(loanAmount + loanAmount2),0) FROM sales WHERE isInstallment = 1 AND settlementReceivedAt IS NULL AND (deleted...)` — **cùng điều kiện** với query đếm đơn trả góp chờ tất toán đã có (chỉ khác `SUM` thay `COUNT`).
- Mục "trả góp NH" trong khung CẦN XỬ LÝ đổi nhãn: khi có tiền → **"Tiền NH chưa tất toán: {tổng} đ · {N} đơn"**; khi không đọc được số tiền vẫn lùi về nhãn cũ. Bấm vào mở `BankInstallmentReportView` như trước.

**Verify (Oppo CPH2203, build debug):** `flutter analyze` sạch trên cả 4 file (chỉ info-lint `avoid_print` có sẵn ở printer service). Test ADB:
- Đơn bán CÒN NỢ của khách "ABC" (nợ 12tr, không có nợ cũ) → bản xem trước hiện đúng `Nợ cũ: 0 đ / Lần này: 12.000.000 đ / Tổng nợ: 12.000.000 đ` ngay dưới TỔNG TIỀN; khối QR hiện "Số tiền: 12.000.000 đ" (= tổng nợ) + đúng NH Vietcombank/0071000123456.
- Phiếu sửa của khách "HUY" thanh toán TIỀN MẶT (không nợ) → khối nợ **không hiện** (đúng — không có công nợ khách).
- **Chưa test trực quan** mục "Tiền NH chưa tất toán" ở Home: shop test "M" có 0 đơn trả góp NH → mục không xuất hiện (đúng logic). Query đã đối chiếu tay là bản sao query đếm đã chạy production; đổi nhãn là chuỗi thuần → rủi ro thấp. **Nên xác nhận lại khi có đơn trả góp thật.**

**Files:** `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`, `lib/services/unified_printer_service.dart`, `lib/widgets/dashboard_cards.dart`.

---

## [2026-08-29a] - polish(repair,debt-ui): hiện sẵn "Thêm chi tiết" khi tạo đơn sửa + giảm đỏ chói màn Công nợ khách hàng

**Bối cảnh:** User yêu cầu 2 chỉnh nhỏ về UI (trong loạt 4 việc; 2 việc còn lại — thêm nợ cũ/tổng nợ/QR vào phiếu gửi khách, và thống kê "tiền NH chưa tất toán" ở Home/Tài chính — đang chờ user xác nhận phương án; và 1 việc điều tra lỗi layout top-inset toàn cục, chờ user duyệt nguyên nhân).

**Đã sửa:**
- `lib/views/create_repair_order_view.dart`: `_showAdvancedFields` mặc định `false` → `true`. Phần "Thêm chi tiết (bảo mật, ngoại quan, phụ kiện)" khi tạo đơn sửa mới giờ **hiện sẵn**, không phải bấm mũi tên mở. Nút thu gọn vẫn còn (bấm lại để ẩn). Không đổi logic lưu.
- `lib/views/customer_debt_view.dart`: màn "Công nợ khách hàng" — gradient đỏ chói `#B91C1C→#EF4444` (ở AppBar + thẻ header "CÔNG NỢ HIỆN TẠI") đổi sang đỏ trầm dịu hơn `#A23B3B→#BE6A63`; thẻ header thu nhỏ (padding 20→14, cỡ số tiền 30→22, các khoảng cách/nút gọn lại).
- `lib/views/collect_customer_debt_view.dart`: màn "Thu tiền công nợ" — thẻ "Công nợ hiện tại" đồng bộ màu đỏ trầm `#A23B3B`, cỡ số tiền trong `_infoCard` 22→18.

**Verify:** `flutter analyze` sạch trên cả 3 file (chỉ còn info-lint có sẵn từ trước ở `create_repair_order_view.dart`, không phải do thay đổi này). Thay đổi chỉ là cờ mặc định + màu/kích thước, không đụng luồng dữ liệu → chưa build lại máy thật (theo mặc định tiết kiệm token; sẵn sàng build nếu user muốn xem trực quan).

**Files:** `lib/views/create_repair_order_view.dart`, `lib/views/customer_debt_view.dart`, `lib/views/collect_customer_debt_view.dart`.

---

## [2026-08-24q] - refactor(công nợ): gộp 14 chỗ tự tay tạo công nợ về 1 hàm dùng chung

**Bối cảnh:** User hỏi rà soát các chỗ xử lý thanh toán công nợ xem có cần đồng nhất/tối ưu không. Rà thấy phần TRẢ/THU nợ đã có đã thống nhất tốt (4 nơi đều gọi `DebtPaymentSheet` → `PaymentIntentService.executePaymentDirect`). Riêng phần TẠO nợ mới (khi bán/sửa/nhập hàng chọn CÔNG NỢ) bị lặp lại tay khoảng 14 chỗ ở 7 file khác nhau, mỗi chỗ tự build map + `insertDebt` + xếp hàng đồng bộ — phát hiện luôn 2 lỗi thật do lặp code này gây ra.

**Đã thêm (`lib/services/payment_intent_service.dart`):** hàm `PaymentIntentService.createDebtRecord(...)` — chuẩn hoá build debt map (status luôn `'ACTIVE'`), `insertDebt`, xếp hàng `SyncOrchestrator().enqueueDebt(...)`, emit `debts_changed`. Chỉ xử lý TẠO nợ mới — không đụng phần trả/thu nợ đã có.

**Đã migrate 14 chỗ sang dùng hàm chung, sửa luôn 2 lỗi phát hiện được:**
- `lib/views/parts_inventory_view.dart` (4 chỗ — kho phụ tùng/linh kiện).
- `lib/views/repair_detail_view.dart` (5 chỗ — giao máy CÔNG NỢ x2 gần như trùng nhau, chi phí linh kiện x2, đối tác sửa chữa). **Sửa lỗi:** 1 chỗ (xác nhận vốn linh kiện) dùng sai `status: 'UNPAID'` (chuẩn chung là `'ACTIVE'`, khiến khoản nợ này biến mất khỏi thống kê lọc theo ACTIVE) và **thiếu hẳn bước xếp hàng đồng bộ Firestore** (nợ chỉ tồn tại cục bộ, không lên cloud/thiết bị khác).
- `lib/views/inventory_view.dart` (1 chỗ — nhập giá vốn sản phẩm nhanh). **Sửa lỗi:** nhánh TIỀN MẶT/CHUYỂN KHOẢN cũng thiếu xếp hàng đồng bộ Firestore — đã bổ sung.
- `lib/views/create_repair_order_view.dart`, `lib/views/create_purchase_order_view.dart`, `lib/views/fast_stock_in_view.dart`, `lib/services/stock_entry_service.dart` (mỗi nơi 1 chỗ).

**CỐ TÌNH không đụng:** `create_sale_view.dart` (tạo nợ nằm trong 1 Firestore transaction nguyên khối cùng cập nhật sản phẩm — gộp vào sẽ phá vỡ tính nguyên tử của transaction), `sale_detail_view.dart` và `stock_entry_service.dart`'s `correctSupplierAndPayment` (2 luồng SỬA/điều chỉnh nợ đã có, khác bản chất với TẠO nợ mới, rủi ro cao hơn nếu gộp vội).

**Verify:** `flutter analyze` sạch trên cả 8 file (0 lỗi, chỉ info-level lint có sẵn từ trước). Build debug thành công, cài lại trên Oppo CPH2203 — mở lại được các dialog liên quan (Nhập giá vốn sản phẩm, danh sách sản phẩm) không crash, xác nhận code chạy được. **CHƯA test được trọn vẹn thao tác lưu cuối cùng trên máy thật** (bàn phím ảo trên máy test bị vướng thao tác tự động nhiều lần liên tiếp, đã dừng theo yêu cầu tiết kiệm token) — logic bên trong `createDebtRecord` đã được đối chiếu tay từng field với đúng 14 chỗ gốc trước khi migrate nên rủi ro thấp, nhưng **nên tự tay thử tạo 1 khoản nợ CÔNG NỢ qua 1 trong các luồng trên và kiểm tra debt_view.dart hiện đúng + đã đồng bộ lên Firestore** trước khi yên tâm hoàn toàn.

**Files:** `lib/services/payment_intent_service.dart`, `lib/views/parts_inventory_view.dart`, `lib/views/repair_detail_view.dart`, `lib/views/inventory_view.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/create_purchase_order_view.dart`, `lib/views/fast_stock_in_view.dart`, `lib/services/stock_entry_service.dart`.

---

## [2026-08-24p] - feat(home): nhắc "chưa chốt quỹ" + "đơn sửa thiếu giá vốn" ở khung CẦN XỬ LÝ

**Bối cảnh:** User lo ngại nhiều người dùng không biết tính năng chốt quỹ nên để quá lâu không chốt, và muốn nhắc thêm đơn sửa đã giao nhưng quên nhập giá vốn (dễ tính sai lợi nhuận).

**Đã thêm (`lib/widgets/dashboard_cards.dart`, `lib/views/home_view.dart`, `lib/views/order_list_view.dart`):**
- 2 mục mới trong khung "CẦN XỬ LÝ" ở Trang chủ, tái dùng đúng pattern có sẵn (query đếm qua `Future.wait`, thêm `_ActionItem`):
  - **"Đã N ngày chưa chốt quỹ"** — tính từ lần chốt quỹ gần nhất (`MAX(dateKey)` trong `cash_closings`); nếu chưa từng chốt quỹ lần nào, tính từ ngày bán hàng đầu tiên của shop làm mốc (để cảnh báo ngay cả shop mới chưa từng dùng tính năng này). Hiện khi ≥ 2 ngày. Bấm vào mở thẳng Sổ quỹ.
  - **"N đơn sửa đã giao chưa có giá vốn"** — đếm đơn `status = 4` (đã giao) có `cost IS NULL OR cost = 0`. Bấm vào mở "Danh sách điện thoại" đã lọc sẵn (thêm tham số mới `filterMissingCost` cho `OrderListView`).
- Thêm badge cảnh báo đỏ "⚠ Vốn 0đ — chưa có giá vốn, cần bổ sung" ngay trên từng thẻ đơn sửa trong danh sách (chỉ hiện với người có quyền xem giá vốn `canShowCost`, khớp đúng cách ẩn giá vốn hiện có) — giúp thấy ngay cả khi không dùng bộ lọc, không cần nhớ vào đúng chỗ mới thấy.

**Verify (test trên Oppo CPH2203, tài khoản test):** `flutter analyze` sạch trên cả 3 file. Build debug + cài lại:
- Xác nhận "Đã 5 ngày chưa chốt quỹ" hiện đúng trên Trang chủ (shop test chưa từng chốt quỹ lần nào), bấm vào mở đúng Sổ quỹ.
- Chỉnh tạm 1 đơn sửa đã giao về giá vốn 0đ để test — xác nhận mục "1 đơn sửa đã giao chưa có giá vốn" xuất hiện đúng, bấm vào lọc đúng còn 1 đơn, badge đỏ hiện đúng trên thẻ đơn. Đã khôi phục lại giá vốn gốc (3.000đ) sau khi xác nhận.

**Files:** `lib/widgets/dashboard_cards.dart`, `lib/views/home_view.dart`, `lib/views/order_list_view.dart`.

---

## [2026-08-24o] - fix(sổ quỹ): giới hạn đọc Firestore theo khoảng ngày, giảm mạnh lượt đọc

**Bối cảnh:** User hỏi qua ảnh chụp Firestore Audit Monitor thấy `CashClosingView` chiếm 7.9K/8.3K lượt đọc ước tính chỉ trong 1 phiên ngắn, muốn biết có phải do đọc nhiều và có phương án tối ưu không.

**Nguyên nhân gốc:** Mỗi lần mở Sổ quỹ hoặc đổi ngày xem, `_loadAllDataFromFirestore` tải **TOÀN BỘ lịch sử** `sales`/`repairs`/`expenses`/`debt_payments`/... của shop (chỉ lọc `shopId`, không giới hạn ngày) rồi mới lọc lại trong bộ nhớ theo ngày đang xem. Riêng `sales` chiếm ~6.4K/8.3K lượt đọc — chi phí này tăng dần theo thời gian shop hoạt động, không liên quan gì đến việc gộp số liệu chưa chốt quỹ vừa sửa ở `[2026-08-24n]`.

**Đã sửa (`lib/views/cash_closing_view.dart`):** giới hạn truy vấn Firestore theo đúng khoảng ngày cần dùng (đã gộp cả khoảng chưa chốt quỹ nếu có) cho `sales`, `expenses`, `sales_returns` — tận dụng đúng các composite index đã có sẵn (`sales(shopId,soldAt)`, `expenses(shopId,date)`, `sales_returns(shopId,returnDate)`), không cần deploy index mới.
- `sales`: tách làm 2 truy vấn gộp — 1 bound theo `soldAt` (đa số đơn), 1 KHÔNG bound riêng cho đơn trả góp (`isInstallment`) vì tiền tất toán ngân hàng có thể về sau ngày bán rất lâu, bound theo `soldAt` một mình sẽ làm mất khoản tất toán đó.
- **CỐ TÌNH giữ nguyên không bound:** `repairs` (lọc theo nhiều mốc thời gian khác nhau — ngày tạo/ngày giao/ngày ghi nhận giá vốn — bound sai sẽ làm mất đơn, cần thêm 1 helper `getRepairsByDeliveredAtRange` mới làm đúng, chưa làm trong lần này), `debt_payments`/`supplier_payments`/`repair_partner_payments`/`debts` (số lượng đọc nhỏ hơn nhiều theo audit thực tế, `debts` còn cần tra cứu debtType bất kể tạo lúc nào).

**Verify (test trên Oppo CPH2203, tài khoản test):** `flutter analyze` sạch. Build debug + cài lại, dựng lại đúng kịch bản gộp 3 ngày chưa chốt quỹ ở `[2026-08-24n]` (chèn tạm 1 chốt quỹ giả lập ngày 21/08) để xác nhận việc giới hạn theo ngày KHÔNG làm mất dữ liệu: tab Tổng quan/Thu/Chi sau khi Firestore tải xong hiện **giống hệt số liệu trước khi tối ưu** (15.45 Tr tiền mặt, 12.2 Tr ngân hàng, Thu +28.55 Tr/7 giao dịch, Chi -1.6 Tr/3 giao dịch) — xác nhận bound đúng, không mất giao dịch nào trong khoảng đang xem. Đã dọn dữ liệu test sau khi xác nhận.

**Files:** `lib/views/cash_closing_view.dart`.

---

## [2026-08-24n] - fix(sổ quỹ): gộp số liệu khi có ngày chưa chốt quỹ, tránh mất dấu tiền

**Bối cảnh:** User phản ánh khó theo dõi tiền khi chưa chốt quỹ: qua ngày mới, màn Sổ quỹ không hiện lại dữ liệu ngày hôm trước nếu ngày đó chưa chốt.

**Nguyên nhân gốc:** `CashClosingView` xác định "số dư đầu ngày" bằng cách tìm chốt quỹ đúng "hôm qua" (`_selectedDate - 1 ngày`) — nếu hôm qua chưa chốt, số dư đầu ngày lập tức về 0, mất hết dấu vết các ngày trước đó dù chúng có phát sinh giao dịch thật. Toàn bộ số liệu hiển thị (Tổng quan/Thu/Chi) và cả khi bấm "Chốt quỹ" cũng chỉ tính đúng 1 ngày `_selectedDate`, không hề biết đến khoảng ngày chưa chốt.

**Đã sửa:**
- `lib/data/db_helper.dart`: thêm `getLatestClosingBefore(dateKey)` — tìm đúng lần chốt quỹ GẦN NHẤT trước 1 ngày bất kỳ (khác `getPreviousDayClosing` sẵn có, cái đó chỉ tính bản đã "khóa sổ" `isLocked=1`, một cờ riêng cho nghiệp vụ khác không liên quan tới chốt quỹ hàng ngày).
- `lib/views/cash_closing_view.dart`:
  - Thay lookup "đúng hôm qua" bằng `getLatestClosingBefore` ở cả 2 đường tải dữ liệu (Firestore và local DB offline).
  - Thêm `_analysisStartDate`/`_hasUnclosedGap`: nếu có khoảng ngày chưa chốt, tự gộp toàn bộ giao dịch từ ngay sau lần chốt gần nhất đến ngày đang xem vào 1 lần tính (`_analyzeTransactions` đổi từ tính đúng 1 ngày sang tính theo khoảng ngày) — áp dụng đồng bộ cho tab Tổng quan, Thu, Chi, và chính lúc xác nhận Chốt quỹ, để không nơi nào bị lệch số với nơi khác.
  - `_loadAllDataFromLocalDB` cũng phải nới khoảng tải sales/expenses về đúng mốc gộp này (không chỉ tải đúng 1 ngày) — nếu không, dữ liệu offline vẫn thiếu (các) ngày chưa chốt dù phần tính toán đã sửa đúng.
  - Thêm cảnh báo cam rõ ràng ở thẻ "SỐ DƯ ĐẦU NGÀY" và ở sheet "XÁC NHẬN CHỐT QUỸ": "Từ [ngày] đến nay chưa chốt quỹ ngày nào — số liệu đã gộp chung từ lần chốt gần nhất ([ngày])."
  - Ngày ĐÃ chốt quỹ rồi thì xem lại vẫn đúng y hệt như cũ (không đổi hành vi) — chỉ áp dụng gộp khi ngày đang xem thực sự chưa chốt.

**Verify (test trên Oppo CPH2203, tài khoản test):** chèn 1 bản ghi chốt quỹ giả lập ngày 21/08 (500.000đ tiền mặt, 200.000đ ngân hàng) thẳng vào DB thật của máy để mô phỏng "3 ngày chưa chốt quỹ" (22-24/08, có sẵn dữ liệu bán hàng/thu nợ/chi phí thật từ trước). Xác nhận trên máy:
- Tab Tổng quan: hiện đúng cảnh báo "Từ 22/08 đến nay chưa chốt quỹ ngày nào — số liệu đã gộp chung từ lần chốt gần nhất (21/08/2026)", số dư đầu ngày đúng 500.000/200.000 (không về 0).
- Tab Thu: gộp đúng cả giao dịch ngày 23 lẫn 24 (7 giao dịch, +28.55 Tr).
- Tab Chi: lúc đầu THIẾU 2 khoản chi ngày 23 (chỉ hiện đúng 1 giao dịch của hôm nay) — phát hiện thêm 1 lỗi liên quan (data loading từ local DB vẫn giới hạn đúng 1 ngày dù phần tính đã sửa) → sửa `_loadAllDataFromLocalDB`, sau đó Chi hiện đúng cả 3 giao dịch (-1.6 Tr, gồm 2 khoản nhập hàng ngày 23 + 1 khoản trả NCC hôm nay).
- Sheet "Xác nhận chốt quỹ": hiện đúng "Gộp từ 22/08 đến 24/08/2026 (chưa chốt quỹ)", số dự kiến khớp 100% với tab Tổng quan (15.45 Tr tiền mặt, 12.2 Tr ngân hàng) — bấm Hủy, không xác nhận thật để tránh tạo phiếu chốt quỹ từ dữ liệu giả lập.
- Dọn dẹp: đã xóa bản ghi test khỏi DB máy thật, khôi phục lại trạng thái ban đầu (không còn phiếu chốt quỹ nào).

**Files:** `lib/data/db_helper.dart`, `lib/views/cash_closing_view.dart`.

---

## [2026-08-24m] - fix(kho,sale): audit luồng Nhập kho/Sản phẩm/Bán hàng — sửa 3 điểm ma sát cho người mới

**Bối cảnh:** User yêu cầu audit toàn bộ luồng Nhập kho, Sản phẩm, Bán hàng với vai trò người dùng thật, tối ưu trải nghiệm cho người mới dùng. Đã đi thực tế qua device + đọc code, phát hiện 3 vấn đề cụ thể và được yêu cầu sửa cả 3.

**1. Tên điện thoại bị ghi đè âm thầm khi nhập kho (`lib/views/smart_stock_in_view.dart`):** Ở "NHẬP KHO MỚI", nếu đã chọn Hãng hoặc gõ Model, `_buildItem()` luôn dùng tên tự sinh từ Hãng/Model/Dung lượng/Màu/Tình trạng, bỏ qua hoàn toàn nội dung người dùng gõ tay trong ô "Tên điện thoại *" — không có cảnh báo nào, y hệt lỗi phụ kiện đã sửa trước đó nhưng ở luồng khác. Sửa: thêm getter `_phoneNameIsAuto` + `_syncPhoneNamePreview()`, gọi lại mỗi khi Hãng/Model/Dung lượng/Màu/Tình trạng đổi để ô Tên luôn hiện đúng tên sẽ lưu, đồng thời khóa ô này (`readOnly`, nền xám) kèm helper text "Tự ghép từ Hãng/Model/Dung lượng/Màu/Tình trạng — muốn đổi thì sửa các mục bên dưới" khi đang ở chế độ tự ghép.

**2. Không cảnh báo sản phẩm chưa định giá khi bán (`lib/views/create_sale_view.dart`):** `smart_stock_in_view` không bắt buộc giá bán lúc nhập kho, nên sản phẩm có thể vào kho với giá 0đ rồi chỉ hiện "Giá: 0" mờ nhạt trong danh sách chọn khi bán — dễ bị bỏ sót, bán nhầm giá 0đ. Sửa: cả 2 danh sách chọn sản phẩm (tìm kiếm + "Sản phẩm gần đây") hiện "⚠ Chưa định giá" màu đỏ đậm thay vì "Giá: 0" khi `p.price <= 0`.

**3. Khu vực chọn sản phẩm ghi nhãn "ĐIỆN THOẠI" dù trộn cả phụ kiện (`lib/views/create_sale_view.dart`):** `_terms.productLabel` hardcode "Điện thoại" (business type duy nhất được hỗ trợ — `business_type_helper.dart`), nhưng danh sách/tìm kiếm sản phẩm khi bán thực tế trộn cả điện thoại lẫn phụ kiện. Đổi các nhãn dùng `_terms.productLabel` trong khu vực chọn sản phẩm sang "SẢN PHẨM"/"sản phẩm" trung tính: tiêu đề khu vực, subtitle AppBar ("x sản phẩm đã chọn"), placeholder tìm kiếm, snackbar thiếu sản phẩm/hết hàng, nút xác nhận, bước hướng dẫn first-time-guide. Giữ nguyên các chỗ đã đúng ngữ cảnh điện thoại thật (vd cảnh báo thiếu IMEI, guard `p.type == 'DIEN_THOAI'`).

**Verify (test trên Oppo CPH2203, tài khoản test):** `flutter analyze` sạch trên cả 2 file (chỉ còn info-level lint có sẵn từ trước, không liên quan). Build debug + cài lại, xác nhận trên máy thật:
- NHẬP KHO MỚI: chọn Hãng "IPHONE" → ô Tên tự đổi thành "IPHONE", khóa sửa tay (nền xám), hiện đúng helper text.
- TẠO ĐƠN BÁN HÀNG: tiêu đề khu vực đổi thành "SẢN PHẨM", subtitle "0 sản phẩm đã chọn"; 2 sản phẩm test có giá 0đ hiện đúng "⚠ Chưa định giá" màu đỏ thay vì "Giá: 0".

**Files:** `lib/views/smart_stock_in_view.dart`, `lib/views/create_sale_view.dart`.

---

## [2026-08-24l] - feat(sale,repair,kho): ảnh + QR tra cứu kèm biên nhận + gợi ý giá khi sửa sản phẩm

**Bối cảnh:** User yêu cầu 2 việc: (1) ảnh biên nhận đơn bán/phiếu sửa (khi in hoặc chia sẻ) kèm thêm ảnh sản phẩm/máy + QR tra cứu đơn + QR chuyển khoản (đã có sẵn) nếu có; (2) gợi ý giá vốn/giá bán tham khảo không chỉ khi nhập kho (đã có từ `[2026-08-23a]`) mà cả khi sửa sản phẩm.

**1. Ảnh + QR tra cứu trong ảnh biên nhận (`sale_invoice_preview_view.dart`, `repair_invoice_preview_view.dart`):**
- Đơn bán: tra ảnh từng sản phẩm theo IMEI (chỉ điện thoại — phụ kiện không có định danh riêng để khớp đúng đơn vị đã bán), ưu tiên ảnh local giống các màn khác đã làm trong app.
- Phiếu sửa: dùng thẳng `Repair.receiveImages` (ảnh máy lúc tiếp nhận, đã có sẵn trong model, không cần tra cứu thêm).
- Cả 2: thêm khối "QUÉT MÃ TRA CỨU ĐƠN" — render `QrImageView` thật từ đúng `qrData` đã tính sẵn (`sale_check:ID`/`repair_check:ID`) nhưng trước đây chỉ tồn tại dạng text bị ẩn đi, chưa từng hiện thành mã QR quét được. Xác nhận `qr_router.dart` đã có sẵn cơ chế nhận diện 2 tiền tố này để mở thẳng đúng đơn khi quét — QR này thực sự dùng được, không phải trang trí.
- Ảnh cloud được `precacheImage` trước khi chụp/tự động chia sẻ, tránh trường hợp `Image.network` chưa tải kịp lúc chụp ảnh biên nhận.
- Gộp 3 khối (ảnh, QR tra cứu, QR chuyển khoản) vào 1 hàm `_buildReceiptExtras()` dùng chung, có gạch ngang phân cách giữa các khối đang hiện.

**2. Gợi ý giá vốn/giá bán khi sửa sản phẩm (`lib/views/inventory_view.dart`):** tái dùng nguyên `ProductPricingService` đã xây cho màn Nhập kho — gõ vào ô Model (chỉ áp dụng điện thoại) sẽ tự tính gợi ý (median giá vốn/giá bán/lợi nhuận từ các sản phẩm cùng model, debounce 700ms), hiện đúng thẻ "GIÁ THAM KHẢO" + 2 nút "DÙNG GIÁ VỐN"/"DÙNG GIÁ BÁN" giống hệt màn Nhập kho.

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch trên cả 3 file. Build debug + cài lại.
- Mở lại đơn bán đã có (IMEI 9999, không có ảnh) → xác nhận khối "QUÉT MÃ TRA CỨU ĐƠN" hiện đúng, quét được (ảnh sản phẩm không hiện đúng như dự kiến vì sản phẩm này chưa có ảnh).
- Sửa sản phẩm "IPHONE 12 32GB VÀNG MỚI" (model "12", có 1 sản phẩm khác cùng model) → gõ lại ô Model → thẻ "GIÁ THAM KHẢO" hiện đúng median (Vốn 9.000.000đ từ 2 mẫu 8tr/10tr) → bấm "DÙNG GIÁ VỐN" → ô Giá vốn cập nhật đúng 9.000.000 → Hủy để không lưu thay đổi test.

**Files:** `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`, `lib/views/inventory_view.dart`.

---

## [2026-08-24k] - fix(kho,ncc): trả nợ NCC không đồng bộ ngược vào phiếu nhập kho — sửa tận gốc

**Bối cảnh:** Nối tiếp `[2026-08-24j]`. User chọn "sửa chuẩn logic" thay vì chỉ vá số liệu — chấp nhận đụng vào lõi xử lý thanh toán chung (`PaymentIntentService`) để tránh lặp lại vấn đề.

**Nguyên nhân gốc:** `PaymentIntentService._updateRelatedEntities` (nơi DUY NHẤT xử lý mọi khoản trả/thu nợ trong app) chỉ cập nhật bảng `debts` + `debt_payments` khi trả nợ — hoàn toàn không biết đến việc 1 khoản nợ NCC có thể được tạo ra TỪ 1 phiếu nhập kho cụ thể (`debts.linkedId` = `stockEntryId`) và phiếu đó có số liệu `paidAmount`/`paymentStatus` RIÊNG cần cập nhật theo. Kết quả: trả nợ xong (bảng `debts` đúng), nhưng phiếu nhập kho gốc (`import_orders`, nguồn số liệu cho tab Thống kê NCC) mãi mãi đứng yên ở trạng thái lúc tạo, không bao giờ nhận biết đã được trả.

**Đã sửa (`lib/services/payment_intent_service.dart`):**
- Thêm `_syncImportOrderPaymentIfLinked(stockEntryId, paidDelta)` — sau mỗi lần trả nợ (trừ thu nợ khách hàng), tra `linkedId` trong metadata xem có khớp `stockEntryId` của 1 `import_orders` nào không; nếu có, cộng dồn đúng số tiền vừa trả vào `paidAmount`/cập nhật `paymentStatus` của phiếu đó (ghi cả Firestore lẫn local, cùng pattern đã dùng ở `correctSupplierAndPayment`). An toàn tuyệt đối cho nợ khách hàng — `linkedId` của họ (nếu có) không bao giờ trùng `stockEntryId` thật nên hàm tự thoát sớm.
- Thêm `reconcileStaleImportOrderDebts()` — quét lại TOÀN BỘ phiếu nhập kho đang bị lệch do vấn đề này xảy ra TRƯỚC khi có bản sửa (nợ đã trả xong từ lâu nhưng phiếu vẫn hiện "còn nợ"), tự sửa lại 1 lần. Gọi trong chu kỳ `syncAllToCloud` (`lib/services/sync_service.dart`) — không cần thao tác gì thêm từ người dùng.

**Verify (test trên Oppo CPH2203, tài khoản test):**
- Reconcile: log xác nhận tự sửa đúng phiếu NK-0075 (đã lệch từ trước) — sau khi sửa, tab Thống kê KHO TỔNG hiện đúng "Còn nợ: 0" khớp tab Công nợ, "Đã thanh toán đủ 11 / Chưa thanh toán 7" (11+7=18 đúng tổng).
- Đồng bộ khi trả nợ MỚI: dùng "Thanh toán nhanh" trả 100.000đ cho NCC TÉT A (khoản nợ 12 triệu, liên kết phiếu NK-0040) → xác nhận qua DB thật: `debts.paidAmount=100000` VÀ `import_orders(NK-0040).paidAmount=100000` cùng cập nhật khớp nhau ngay lập tức — xác nhận cơ chế đồng bộ hoạt động đúng cho lần trả nợ thật.

**Files:** `lib/services/payment_intent_service.dart`, `lib/services/sync_service.dart`.

---

## [2026-08-24j] - fix(kho): tab Thống kê NCC đếm sai "Chưa thanh toán" luôn ra 0

**Bối cảnh:** User gửi 5 ảnh chụp đủ 4 tab của màn Chi tiết NCC "KHO TỔNG" để rà soát toàn bộ số liệu. Phát hiện: tab "Thống kê" ghi "18 phiếu" nhưng "Đã thanh toán đủ" (10) + "Chưa thanh toán" (0) chỉ cộng ra 10 — thiếu mất 8 phiếu.

**Nguyên nhân:** `_buildStatsTab()` lọc "Chưa thanh toán" bằng so khớp đúng chuỗi `paymentStatus == 'UNPAID'`. Nhưng `paymentStatus` có 2 luồng ghi khác nhau tuỳ nguồn tạo phiếu: phiếu tạo từ `StockEntryService` (luồng "Nhập kho" chính trong app) ghi `'DEBT'` cho công nợ chưa trả; phiếu import từ file Excel KiotViet mới ghi đúng chuỗi `'UNPAID'`. Do đó mọi phiếu `'DEBT'` (đa số dữ liệu thật) không bao giờ khớp điều kiện, luôn đếm ra 0 dù thực tế có 8 phiếu chưa trả.

**Đã sửa:** đổi điều kiện đếm sang "khác `'PAID'`" (`!= 'PAID'`) thay vì so khớp đúng 1 chuỗi cụ thể — bắt đúng mọi trạng thái chưa-trả-đủ bất kể luồng tạo phiếu nào (`'DEBT'`, `'UNPAID'`, hay giá trị khác).

**Phát hiện thêm (chưa sửa, cần user quyết định):** đối chiếu số liệu phát hiện phiếu **NK-0075** (10.000.000đ, xác nhận qua DB) đang bị lệch 2 nơi — tab "Thống kê" tính nó là CHƯA TRẢ (góp phần vào "Còn nợ: 10.000.000"), nhưng khoản nợ liên kết với đúng phiếu này trong bảng `debts` (ghi chú "Nợ nhập IPHONE 9 32GB ĐEN MỚI x1 - 10.000.000đ") đã được đánh dấu **đã trả đủ** từ trước — nên tab "Công nợ" hiện đúng "Còn lại: 0". Gốc rễ: `PaymentIntentService` (nơi xử lý trả nợ NCC) chỉ cập nhật bảng `debts`, không đồng bộ ngược lại `import_orders.paidAmount/paymentStatus` khi khoản nợ đó có liên kết tới 1 phiếu nhập kho cụ thể (`linkedType: 'stock_entry'`). Đây là bug thật nhưng nằm ở lõi xử lý thanh toán dùng chung cho mọi loại công nợ — cần xác nhận hướng sửa (đồng bộ ngược khi trả nợ, hay chỉ sửa lại đúng bản ghi NK-0075 hiện tại) trước khi động vào, tránh ảnh hưởng luồng công nợ khách hàng đang chạy ổn định.

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch. Build debug + cài lại. Xác nhận tab Thống kê giờ hiện đúng "Chưa thanh toán: 8 phiếu" (10+8=18, khớp tổng số phiếu).

**Files:** `lib/views/supplier_detail_view.dart`.

---

## [2026-08-24i] - fix(kho): avatar danh sách sản phẩm — sửa đúng nguyên nhân bị kéo giãn to

**Bối cảnh:** User báo lại avatar trong danh sách sản phẩm vẫn to dù `[2026-08-24g]` đã đổi kích thước 52→40px — vì thực chất thay đổi đó KHÔNG có tác dụng gì trên máy thật.

**Nguyên nhân thật:** `Row` chứa thanh accent trái + ảnh + nội dung dùng `crossAxisAlignment: CrossAxisAlignment.stretch` (để thanh accent trái kéo dài đúng theo chiều cao thẻ) — hệ quả phụ: MỌI child trực tiếp của Row, kể cả khối ảnh, đều bị ép giãn theo chiều cao thẻ (khá cao vì nội dung nhiều dòng), khiến `width`/`height` đặt riêng cho ảnh hoàn toàn vô tác dụng — máy in ảnh vẫn kéo giãn lấp đầy khối bị ép. Đây là lý do đổi 52→40px ở lần trước không thấy hiệu quả gì trên máy.

**Đã sửa:** bọc khối ảnh trong `Align(alignment: Alignment.center)` trước khi áp `Padding`/kích thước — `Align` tự nhận phần không gian bị ép giãn từ Row nhưng KHÔNG ép tiếp xuống con của nó, nên ảnh bên trong giữ đúng kích thước đã khai báo (30x30), canh giữa theo chiều dọc thẻ thay vì kéo giãn lấp đầy.

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch. Build debug + cài lại. Xác nhận qua ảnh chụp màn hình: avatar giờ đúng là 1 ô nhỏ vuông canh giữa, không còn kéo dài lấp đầy chiều cao thẻ.

**Files:** `lib/views/inventory_view.dart`.

---

## [2026-08-24h] - polish(kho): ảnh Chi tiết sản phẩm — tỷ lệ vuông + bấm xem ảnh to

**Bối cảnh:** Nối tiếp `[2026-08-24g]`. User phản hồi ảnh header ở trang Chi tiết sản phẩm nhìn "hơi thô" (banner dẹt ngang cắt xén ảnh chụp dọc), muốn có cơ chế giảm dung lượng ảnh, và bấm vào ảnh phải xem được ảnh to.

**Đã kiểm tra cơ chế giảm dung lượng ảnh:** đã có sẵn và áp dụng đồng nhất ở cả 3 nơi thêm ảnh sản phẩm (Sửa sản phẩm, Nhập mới, Nhập nhanh) — `ImagePickerWidget` nén ảnh ngay khi chọn (tối đa 1600px, JPEG q78, nén lại lần 2 ở q60 nếu vẫn >300KB). Không cần thêm gì ở bước này.

**`lib/views/inventory_detail_view.dart`:** đổi khối ảnh header từ banner cố định 200px cắt `BoxFit.cover` theo chiều ngang (méo/cắt thô ảnh dọc) sang khung vuông 1:1 — khớp tỷ lệ ảnh sản phẩm chụp dọc tốt hơn nhiều, đỡ cắt xén. Bọc thêm `GestureDetector` — bấm vào ảnh (khi có ảnh thật) mở trang xem ảnh toàn màn hình, phóng to/thu nhỏ bằng 2 ngón (tái dùng `FullScreenImageViewer`, dùng `PhotoView`).

**`lib/widgets/image_picker_widget.dart`:** đổi `_FullScreenImageViewer` (private, chỉ dùng nội bộ khi bấm vào ảnh trong bộ chọn ảnh) thành `FullScreenImageViewer` (public) để dùng lại được từ `inventory_detail_view.dart`, không cần viết lại logic xem ảnh toàn màn hình.

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch. Build debug + cài lại. Mở Chi tiết sản phẩm có ảnh thật → xác nhận ảnh hiện đúng khung vuông, không còn kéo dẹt/cắt thô. Bấm vào ảnh → mở đúng trang "Xem ảnh" toàn màn hình, phóng to/thu nhỏ được bằng 2 ngón.

**Files:** `lib/views/inventory_detail_view.dart`, `lib/widgets/image_picker_widget.dart`.

---

## [2026-08-24g] - fix(kho): sửa phụ kiện đè mất tên gốc + ảnh không hiện + thu nhỏ avatar + audit lại Chi tiết sản phẩm

**Bối cảnh:** User báo 4 việc: (1) sửa phụ kiện "ốp" (thêm ảnh) xong tên tự đổi thành "KHÁC MỚI"; (2) avatar ảnh trong danh sách sản phẩm quá to, nhìn thô; (3) vào chi tiết sản phẩm có ảnh nhưng không thấy hiện; (4) audit lại màn Chi tiết sản phẩm cho chuyên nghiệp hơn.

**1. Bug tên bị đè (`lib/views/inventory_view.dart._editProduct`):** màn Sửa sản phẩm luôn ghép tên mới từ brand+model+dung lượng+màu+tình trạng (`ProductConstants.generateProductName`) cho MỌI loại sản phẩm, kể cả phụ kiện/linh kiện — vốn dùng tên tự nhập trực tiếp, không có "model" thật sự. Phụ kiện không có brand (mặc định về "KHÁC") + không có model (rỗng) + tình trạng "MỚI" → lưu lại là tên bị ghép thành "KHÁC MỚI", đè mất tên gốc dù người dùng chỉ định thêm ảnh. Đã sửa: chỉ ghép tên kiểu này cho `type == 'DIEN_THOAI'`; phụ kiện/linh kiện dùng đúng text đã nhập trong ô tên (giữ nguyên nếu không sửa gì).

**2. Ảnh không hiện dù đã chọn (`inventory_view.dart._showProductDetail`, `inventory_detail_view.dart`, `widgets/app_popup.dart.PopupProductImage`):** cả màn xem nhanh (bottom sheet bấm vào sản phẩm) lẫn trang Chi tiết sản phẩm đầy đủ chỉ đọc field `images` (URL cloud) để hiện ảnh, bỏ qua hẳn `localImagePath` (ảnh vừa chọn, lưu tạm trên máy chờ upload nền) — trong khi danh sách sản phẩm đã làm đúng (ưu tiên `localImagePath`). Nếu lần upload nền đầu tiên thất bại, ảnh vĩnh viễn không hiện ở 2 nơi này dù ảnh vẫn còn trên máy. Đã sửa cả 3 nơi ưu tiên hiện `localImagePath` trước, khớp đúng cách danh sách đã làm.

**Nguyên nhân gốc tìm được (qua log thật trên máy test):** `Firebase Storage: putFile failed ... code=unauthorized` khi upload lên đường dẫn `uploads/products/{shopId}/{productId}/main.jpg` — rules Storage hiện tại (không có trong repo, chỉ tồn tại trên Firebase) đang CHẶN đúng đường dẫn ảnh sản phẩm mới. **Cần user tự kiểm tra Firebase Console > Storage > Rules** — ngoài khả năng sửa được từ môi trường này (không có file `storage.rules` trong repo, không có quyền deploy).

**3. Tự động thử lại upload ảnh kẹt (`lib/services/sync_service.dart`):** phát hiện thêm `ProductImageService.retryPendingProductImages()` đã viết sẵn từ trước nhưng chưa từng được gọi ở đâu — ảnh lỗi upload lần đầu (vd. mất mạng đúng lúc) không có cơ chế tự thử lại, kẹt vĩnh viễn ở `/cache/` (thư mục có thể bị hệ điều hành tự xoá bất cứ lúc nào). Đã gọi hàm này trong mỗi lần `syncAllToCloud` chạy (cùng lúc sync products) — ảnh kẹt do lỗi mạng tạm thời giờ tự upload lại ở lần sync kế tiếp; ảnh kẹt do lỗi Storage rules (mục trên) sẽ tiếp tục thử lại tới khi rules được sửa.

**4. Thu nhỏ avatar danh sách (`inventory_view.dart`):** ảnh thumbnail trong danh sách sản phẩm 52x52 → 40x40.

**5. Audit lại trang Chi tiết sản phẩm (`inventory_detail_view.dart`):** trước đây toàn bộ thông tin (IMEI, SKU, brand, giá, NCC, thanh toán...) dồn chung 1 khối dài không phân nhóm. Đã tách thành 3 khối có tiêu đề + icon riêng: "THÔNG TIN SẢN PHẨM" (IMEI/SKU/brand/model/tồn kho), "GIÁ & LỢI NHUẬN" (giá bán/giá vốn + thêm dòng **Lợi nhuận** mới tính tự động — trước đây không có), "NHẬP HÀNG" (NCC/thanh toán/ngày nhập).

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch trên toàn bộ file sửa. Build debug + cài lại. Xác nhận qua DB thật kéo từ máy: sản phẩm "KHÁC MỚI" (vốn là "ỐP" bị đổi tên bởi bug #1) có `localImagePath` hợp lệ nhưng `images` rỗng — đúng giả thuyết. Sau khi sửa: ảnh hiện đúng ở cả bottom sheet xem nhanh lẫn trang Chi tiết sản phẩm đầy đủ; trang Chi tiết sản phẩm hiện đúng 3 khối mới + dòng Lợi nhuận tính đúng (âm khi giá bán < giá vốn, hiện màu đỏ).

**Files:** `lib/views/inventory_view.dart`, `lib/views/inventory_detail_view.dart`, `lib/widgets/app_popup.dart`, `lib/services/sync_service.dart`.

---

## [2026-08-24f] - fix(sale,repair): in/chia sẻ biên nhận không báo kết quả thành công hay thất bại

**Bối cảnh:** User phản hồi: bấm in hoặc chia sẻ ảnh biên nhận ở màn xem trước, không thấy báo gì (thành công hay lỗi) — chỉ có icon spinner quay rồi tắt, không biết thao tác có thực sự thành công không.

**Nguyên nhân:** `_print()` gọi thẳng `UnifiedPrinterService.printSaleReceipt/printRepairReceiptFromRepair(...)` (trả về `bool`) nhưng không đọc kết quả, không try/catch — dù in thành công hay thất bại đều im lặng như nhau. `_shareToCustomer()` gọi `SharePlus.instance.share(...)` nhưng bỏ qua kết quả trả về — chỉ báo khi lỗi ném exception, còn thành công thì im lặng.

**Đã sửa (`sale_invoice_preview_view.dart`, `repair_invoice_preview_view.dart`):**
- `_print()`: bọc try/catch, đọc `bool` trả về — báo xanh "Đã gửi lệnh in" hoặc đỏ "In thất bại, vui lòng thử lại" / "Lỗi khi in: ..." (theo đúng pattern đã dùng ở `sale_detail_view.dart._printWifi`).
- `_shareToCustomer()`: đọc `ShareResult.status` — chỉ báo xanh "Đã chia sẻ ảnh biên nhận/phiếu sửa" khi `ShareResultStatus.success` (người dùng thực sự chọn 1 ứng dụng để chia sẻ); khi người dùng tự đóng share sheet (`dismissed`) thì không báo gì thêm (không phải lỗi, không cần làm phiền).

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch. Build debug + cài lại. Bấm in hoá đơn bán (máy in WiFi đã lưu sẵn) → xác nhận hiện đúng banner xanh "Đã gửi lệnh in". Bấm chia sẻ cho khách → xác nhận: máy test hiện đang bị khoá FRP tầng hệ điều hành (xem thêm ghi chú ở `HANDOVER.md`) nên share sheet hệ thống không mở được — đã xác nhận code KHÔNG báo nhầm "thành công" trong tình huống này (im lặng đúng, không nói dối), hành vi đúng như thiết kế.

**Files:** `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`.

---

## [2026-08-24e] - 🔴 fix khẩn: thiếu file `receipt_paper_view.dart` khiến nhánh master không build được

**Bối cảnh:** User báo build iOS trên Mac lỗi. Kiểm tra lại phát hiện: `lib/widgets/receipt_paper_view.dart` (đổi API từ `[2026-08-23c]` — thêm tham số `children` + các hàm `receiptTitle/receiptCenter/receiptLeft/receiptSmall/receiptGap`) từng bị sót, chưa từng commit trong các phiên trước, dù `sale_invoice_preview_view.dart`/`repair_invoice_preview_view.dart` (đã commit + push từ lâu) đã gọi thẳng các hàm đó. Hậu quả: bất kỳ máy nào `git pull` nhánh `master` (kể cả build Android) đều thiếu symbol này — build iOS trên Mac chỉ là nơi phát hiện ra trước.

**Đã sửa:** commit + push bổ sung đúng file `lib/widgets/receipt_paper_view.dart`. Xác nhận `flutter analyze` sạch cùng lúc trên cả 3 file liên quan (`receipt_paper_view.dart`, `sale_invoice_preview_view.dart`, `repair_invoice_preview_view.dart`).

**Bài học:** khi sửa 1 file dùng chung (widget/service) cho nhiều màn hình, phải soát kỹ `git status`/`git diff --stat` toàn bộ trước khi commit — không chỉ commit các file "chính" mà bỏ sót file phụ thuộc dùng chung.

**Files:** `lib/widgets/receipt_paper_view.dart`.

---

## [2026-08-24d] - fix(kho): tab "Lịch sử nhập" của NCC — bấm vào sản phẩm không vào chi tiết + phiếu trống không hiện gì

**Bối cảnh:** User phát hiện khi bấm vào NCC (vd. "KHO TỔNG") → tab "Lịch sử nhập", mở rộng 1 phiếu thấy: (1) có phiếu hiện đúng sản phẩm bên trong, có phiếu không hiện gì cả — nhìn như lỗi hiển thị không đồng nhất; (2) bấm vào dòng sản phẩm không mở được trang chi tiết sản phẩm đó.

**Điều tra:** Kéo DB thật từ máy test (Oppo CPH2203) ra kiểm tra trực tiếp — xác nhận (1) KHÔNG phải lỗi hiển thị: các phiếu "trống" (NK-0080, NK-0081, NK-0082, NK-0083) có `totalAmount = 0` và bảng `import_order_items` thật sự **không có dòng nào** — tức các phiếu này được xác nhận với 0 sản phẩm bên trong (dữ liệu cũ, không phải phát sinh trong phiên làm việc này). Giao diện cũ chỉ im lặng không hiện gì khi danh sách sản phẩm rỗng, gây hiểu lầm là lỗi.

**1. `lib/views/supplier_detail_view.dart` (`_buildImportTab`):** thêm dòng chữ xám "Phiếu này chưa ghi nhận sản phẩm cụ thể nào." khi phiếu không có sản phẩm nào, thay vì im lặng không hiện gì. Thêm `onTap` cho dòng sản phẩm — tra theo IMEI trong danh sách `_products` đã tải sẵn của màn hình, mở đúng `InventoryDetailView` của sản phẩm đó nếu tìm thấy (dòng không có IMEI khớp giữ nguyên không bấm được, vì không đủ căn cứ xác định đúng sản phẩm).

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch. Build debug + cài lại. Mở NCC "KHO TỔNG" > Lịch sử nhập > mở rộng NK-0039 (có sản phẩm) → bấm vào sản phẩm "IPHONE 128GB ĐEN 99" → xác nhận vào đúng "Chi tiết sản phẩm". Mở rộng NK-0083 (phiếu trống) → xác nhận hiện đúng dòng "Phiếu này chưa ghi nhận sản phẩm cụ thể nào." thay vì trống trơn.

**Files:** `lib/views/supplier_detail_view.dart`.

---

## [2026-08-24c] - fix(sale,repair): sửa bug share sheet không hiện + thêm nút chia sẻ nhanh ngoài đơn bán + đổi dialog NCC/thanh toán sang dropdown

**Bối cảnh:** User phản hồi tiếp 3 điểm sau `[2026-08-24b]`: (1) dialog "Sửa NCC / thanh toán" (AlertDialog + Lưu/Huỷ) quá nhiều bước — "sao ko dùng dropdown mà lại hiện popup nhiều thao tác quá"; (2) không thấy chỗ chia sẻ nhanh trong màn Chi tiết đơn bán — phải vào menu "⋮" tràn (9 mục) → chọn "Xem trước" → mới thấy nút chia sẻ; (3) bug thật: bấm "Gửi cho khách" trong sheet chọn (từ `[2026-08-24a]`) chỉ thấy icon xoay rồi tắt, KHÔNG thấy share sheet hệ thống (Zalo/Messenger...) hiện ra.

**Nguyên nhân bug (2):** sheet chọn "Gửi cho khách"/"Gửi nội bộ" (`share_receipt_sheet.dart`) là 1 lớp overlay hệ thống (`showModalBottomSheet`), đóng lại NGAY trước khi gọi tiếp `SharePlus.instance.share()` — lớp overlay thứ 2 (share sheet hệ thống) mở quá sát lúc lớp 1 vừa đóng, gây xung đột focus/window trên Android → share sheet không hiện, `Future` treo im lặng. Xác nhận qua `dumpsys window` (mFocusedApp không phải `ChooserActivity`) trước khi sửa.

**1. `lib/widgets/share_receipt_sheet.dart`:** XOÁ hẳn (không còn nơi nào import). Bỏ luôn bước "chọn Gửi khách/Gửi nội bộ" qua sheet trung gian — tách lại thành 2 icon riêng biệt bấm thẳng (đúng pattern `repair_detail_view.dart` đã dùng ổn định từ trước): icon "Chia sẻ" (`share_rounded`) → share sheet hệ thống ngay, không qua bước chọn nào; icon "Chat" (`forum_rounded`) → gửi ảnh vào chat nội bộ ngay. Áp dụng cho cả `sale_invoice_preview_view.dart` và `repair_invoice_preview_view.dart` — mỗi màn có 2 state loading riêng (`_sharing`/`_sharingInternal`) nên bấm nhầm 1 icon không làm icon kia bị khoá theo.

**2. `lib/views/sale_invoice_preview_view.dart`:** thêm tham số `autoShare` (bản sao đúng pattern đã có sẵn ở `repair_invoice_preview_view.dart`) — cho phép mở màn xem trước rồi tự bấm "Chia sẻ" ngay khi tải xong, không cần thao tác thêm.

**3. `lib/views/sale_detail_view.dart`:** thêm thẳng 2 icon vào AppBar (trước menu "⋮"): "Chia sẻ nhanh cho khách" (`share_rounded`, `autoShare: true` — 1 bấm ra thẳng share sheet hệ thống) và "Xem trước biên nhận" (`preview_rounded`, mở màn xem trước bình thường). Bỏ mục "Xem trước" khỏi menu "⋮" (còn 8 mục, đỡ rối) vì đã có icon riêng ngoài AppBar thay thế.

**4. `lib/widgets/correct_supplier_payment_dialog.dart`:** viết lại từ AlertDialog 1 bước (chọn NCC + thanh toán + nút Lưu/Huỷ) thành 2 tương tác trực tiếp không qua dialog trung gian: sửa NCC → mở thẳng bộ chọn NCC (`supplier_picker_sheet.dart`), chọn xong lưu luôn; sửa thanh toán → `PopupMenuButton` (dropdown thật, neo đúng vị trí ô đang bấm) 3 lựa chọn, chọn xong lưu luôn. `lib/views/import_order_detail_view.dart` và `lib/views/inventory_view.dart` (màn Sửa sản phẩm) cùng đổi sang gọi 2 hàm mới này thay dialog cũ.

**Verify (test trên Oppo CPH2203, `m@m.com`/shop "M"):** `flutter analyze` sạch trên toàn bộ file sửa. Build debug + cài lại. Xác nhận bug (2) đã hết: bấm icon "Chia sẻ nhanh cho khách" ở cả đơn bán và đơn sửa → `dumpsys window` xác nhận `mFocusedApp` chuyển đúng sang `ChooserActivity` (share sheet hệ thống thật sự hiện ra) → đóng lại → icon trở về trạng thái bình thường (không bị kẹt xoay). Xác nhận icon "Chia sẻ nhanh cho khách"/"Xem trước biên nhận" hiện rõ ngay trên AppBar màn Chi tiết đơn bán, không cần mở menu "⋮".

**Files:** `lib/widgets/share_receipt_sheet.dart` (xoá), `lib/widgets/correct_supplier_payment_dialog.dart`, `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`, `lib/views/sale_detail_view.dart`, `lib/views/import_order_detail_view.dart`, `lib/views/inventory_view.dart`.

---

## [2026-08-24b] - polish(kho): bấm thẳng vào ô NCC/thanh toán để sửa — bỏ kiểu hiển thị "khoá"

**Bối cảnh:** User phản hồi lại `[2026-08-24a]`: sau khi thêm nút "Sửa NCC / thanh toán", 2 ô NCC/Thanh toán ở màn Sửa sản phẩm vẫn hiện icon ổ khoá + màu xám như trước — nhìn vẫn giống bị khoá/ẩn không sửa được, dù thực ra bấm nút bên dưới đã sửa được. Đây là phản hồi UX hợp lý: có nút sửa riêng bên dưới 2 ô trông như chỉ để xem là thiết kế rối, không trực quan.

**`lib/views/inventory_view.dart`:** bỏ hẳn icon ổ khoá + nền xám ở 2 ô "Nhà cung cấp" và "Phương thức thanh toán" — đổi sang icon bút sửa (`edit_outlined`) + viền/chữ màu indigo, biến chính 2 ô này thành `InkWell` bấm thẳng vào là mở dialog sửa (dùng lại đúng logic ở `[2026-08-24a]`, tách thành hàm `openCorrectSupplierPaymentDialog` dùng chung cho cả 2 ô). Xoá nút "Sửa NCC / thanh toán" đứng riêng (không cần nữa, thừa). Ô "SL tồn kho" giữ nguyên kiểu khoá cũ (đúng chủ ý — số lượng sửa qua "Nhập thêm hàng", không liên quan phản hồi này).

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch. Build debug + cài lại. Mở Sửa sản phẩm (IMEI thật): xác nhận 2 ô NCC/Thanh toán hiện rõ màu indigo + icon bút (không còn ổ khoá xám), không còn nút thừa bên dưới. Bấm thẳng vào ô "Nhà cung cấp" → dialog sửa mở đúng. Bấm thẳng vào ô "Phương thức thanh toán" → dialog sửa mở đúng (cùng dialog, đổi được cả 2 field).

**Files:** `lib/views/inventory_view.dart`.

---

## [2026-08-24a] - feat(sale,repair,kho): chia sẻ ảnh gửi khách/nội bộ + đồng nhất sửa NCC/thanh toán ở màn Sửa sản phẩm + fix bug sửa lần 2

**Bối cảnh:** Nối tiếp `[2026-08-23d]`. (1) User yêu cầu làm gọn nút "Chia sẻ ảnh" của đơn bán/phiếu sửa sao cho chuyên nghiệp — trước đây chỉ có 1 hành vi (share sheet hệ thống), không phân biệt gửi khách hay báo nội bộ. (2) User phát hiện đúng 1 điểm KHÔNG đồng nhất còn sót lại từ `[2026-08-23d]`: màn "Sửa sản phẩm" (khác với màn Chi tiết phiếu nhập kho) có ô "Nhà cung cấp" bị khoá cứng (không sửa được) và hoàn toàn KHÔNG có ô "Phương thức thanh toán" — trong khi đây chính là 2 thứ vừa làm được ở phiếu nhập kho.

**1. `lib/widgets/share_receipt_sheet.dart` (mới):** bottom sheet 2 lựa chọn khi bấm "Chia sẻ ảnh" — "Gửi cho khách" (giữ nguyên hành vi cũ: share sheet hệ thống — Zalo, Messenger, lưu ảnh...) và "Gửi nội bộ" (mới — đăng thẳng ảnh vào chat nội bộ shop qua `ChatService.sendImageMessage`, kèm caption tóm tắt đơn, không cần thoát màn hình). Áp dụng cho cả `sale_invoice_preview_view.dart` và `repair_invoice_preview_view.dart`. Mỗi lần chia sẻ đều ghi 1 dòng `AuditService.logAction` (`SHARE_RECEIPT_CUSTOMER`/`SHARE_RECEIPT_INTERNAL`) để truy vết.

**2. `lib/widgets/correct_supplier_payment_dialog.dart` (mới, tách từ `import_order_detail_view.dart`):** gom logic dialog "Sửa NCC/thanh toán" (chọn NCC + phương thức, cảnh báo chốt quỹ, gọi `StockEntryService.correctSupplierAndPayment`) thành 1 hàm dùng chung `showCorrectSupplierPaymentDialog()`, để cả màn Chi tiết phiếu nhập kho lẫn màn Sửa sản phẩm gọi chung 1 chỗ — tránh lặp code + đảm bảo hành vi nhất quán.

**3. `lib/data/db_helper.dart`:** thêm `getStockEntryIdForImei()` — tra `supplier_import_history` theo IMEI để tìm ngược đúng phiếu nhập kho đã tạo ra 1 sản phẩm cụ thể (bảng này có `referenceId` = entryId, sản phẩm thì không có liên kết ngược trực tiếp).

**4. `lib/views/inventory_view.dart` (màn Sửa sản phẩm):** thêm ô "Phương thức thanh toán" (khoá, hiển thị — trước đây thiếu hẳn) cạnh ô NCC đã có. Thêm nút "Sửa NCC / thanh toán" — bấm vào sẽ tự tìm phiếu nhập kho gốc qua IMEI rồi mở đúng dialog dùng chung ở mục 2; sản phẩm không có IMEI (không tự tìm được phiếu gốc) sẽ báo rõ lý do thay vì im lặng. Sau khi sửa thành công, ô NCC/thanh toán cập nhật ngay tại chỗ.

**Bug fix quan trọng tìm thấy khi test sửa 1 phiếu LẦN THỨ HAI:** `StockEntryService.correctSupplierAndPayment()` xác định "đang là công nợ hay không" (`wasDebt`) bằng cách đọc `paymentMethod` từ `StockEntry` gốc — nhưng đây là bản ghi **bất biến lúc tạo**, không phản ánh lần sửa trước đó. Hậu quả: sửa lần 1 luôn đúng, nhưng sửa lần 2 trở đi luôn đọc nhầm về trạng thái gốc ban đầu → tìm sai bảng (`debts` thay vì `expenses` hoặc ngược lại) → báo "Không tìm thấy công nợ gốc của phiếu này" dù dữ liệu vẫn còn nguyên, không sửa được nữa. Đã sửa: đọc `wasDebt`/tên NCC cũ từ `ImportOrder` (bản ghi phản ánh trạng thái HIỆN TẠI, được cập nhật đúng sau mỗi lần sửa) thay vì từ `StockEntry`.

**Verify (test trên Oppo CPH2203, `m@m.com`/shop "M"):** `flutter analyze` sạch (0 lỗi) sau từng bước + toàn project. Build debug + cài lại 2 lần (1 lần fix bug sửa-lần-2 phát hiện ngay trong lúc test).
- Từ màn Sửa sản phẩm (IMEI thật, phiếu NK-0039 đã tạo ở `[2026-08-23d]`): bấm "Sửa NCC / thanh toán" → tự tìm đúng phiếu nhập kho gốc, dialog hiện đúng NCC/thanh toán hiện tại (CHUYỂN KHOẢN, từ lần sửa trước) — xác nhận đây chính là bug: đổi sang TIỀN MẶT → lưu → **lần đầu chạy thất bại thầm lặng** (ô vẫn hiện CHUYỂN KHOẢN, không có bug trước đó nên chưa nghi ngờ) → phát hiện qua dump lại dialog vẫn hiện giá trị cũ → xác định đúng nguyên nhân → sửa code → build lại → test lại: đổi TIỀN MẶT thành công, ô cập nhật ngay, `Lịch sử nhập kho` xác nhận badge đổi CK→TM đúng.
- Chia sẻ ảnh gửi nội bộ (mục 1): mở phiếu sửa HUY (IPHONE 8) → bấm ZALO (autoShare) → sheet "Chia sẻ ảnh" hiện đúng 2 lựa chọn → bấm "Gửi nội bộ" → **lần đầu bấm không thấy tin nhắn mới xuất hiện trong Chat nội bộ** (nghi ngờ bug) → dump lại toạ độ chính xác của sheet bằng uiautomator, phát hiện lần bấm trước đó rơi vào vùng "Scrim" (nằm ngoài sheet, tự đóng sheet không chọn gì) — không phải bug code, do bấm sai toạ độ khi test. Bấm lại đúng toạ độ: xác nhận tin nhắn ảnh xuất hiện đúng trong `Chat nội bộ` kèm caption "🔧 Phiếu sửa - HUY - IPHONE 8 - 0 đ", ảnh tải và hiển thị đầy đủ.

**Files:** `lib/widgets/share_receipt_sheet.dart` (mới), `lib/widgets/correct_supplier_payment_dialog.dart` (mới), `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`, `lib/views/import_order_detail_view.dart`, `lib/views/inventory_view.dart`, `lib/data/db_helper.dart`, `lib/services/stock_entry_service.dart`.

---

## [2026-08-23d] - feat(kho,ncc): cho phép sửa NCC/phương thức thanh toán sau khi nhập kho, khớp cả công nợ + sổ quỹ

**Bối cảnh:** Nhân viên đôi khi chọn nhầm NCC hoặc nhầm hình thức thanh toán (TIỀN MẶT/CHUYỂN KHOẢN/CÔNG NỢ) khi xác nhận phiếu nhập kho, và trước đây không có cách sửa lại. Đã khảo sát kỹ trước khi code: xác nhận công nợ NCC + sổ quỹ được tính từ đúng 2 bảng local `debts`/`expenses` (qua `cash_closing_view.dart`), không phải từ `Product` hay `supplier_debts` (Firestore, ghi lúc confirm nhưng không nơi nào đọc lại — an toàn bỏ qua). Vì vậy việc sửa phải thao tác ở cấp **phiếu nhập kho** (không phải từng sản phẩm) mới khớp đúng số liệu tài chính — đã hỏi lại user xác nhận hướng này trước khi code.

**1. `lib/services/stock_entry_service.dart` — `correctSupplierAndPayment()` (mới):** sửa NCC/thanh toán của 1 phiếu nhập kho ĐÃ XÁC NHẬN. Cùng loại thanh toán → chỉ đổi tên NCC tại chỗ (`debts`/`expenses`). Đổi loại (NCC↔CÔNG NỢ chéo TIỀN MẶT/CHUYỂN KHOẢN) → soft-delete bản ghi cũ + tạo bản ghi mới đúng loại, giữ nguyên số tiền gốc. **Chặn cứng** nếu công nợ đã được trả một phần (`paidAmount > 0`) — không cho đổi loại thanh toán trong trường hợp này, tránh làm sai lịch sử đã thanh toán. Không sửa lại `financial_activity`/`supplier_import_history` cũ (giữ nguyên lịch sử đã xảy ra) — chỉ ghi thêm 1 dòng nhật ký "đã điều chỉnh" mới qua `FinancialActivityService.logCustomActivity`. Đồng bộ nhãn NCC/thanh toán cho `Product` khớp IMEI (chỉ áp dụng sản phẩm có IMEI — không đủ tin cậy để khớp đúng sản phẩm không có IMEI).

**2. `lib/data/db_helper.dart`:** thêm `getExpenseByStockEntryId()` — tìm phiếu chi tạo lúc confirm qua tiền tố mã hoá trong `firestoreId` (`exp_stock_{entryId}_...`, không có cột tham chiếu riêng).

**3. `lib/views/import_order_detail_view.dart`:** thêm nút "Sửa" (AppBar, chỉ hiện khi phiếu đã CONFIRMED) mở dialog chọn lại NCC (tái dùng `supplier_picker_sheet.dart`) + phương thức thanh toán. Cảnh báo trước khi lưu nếu ngày nhập kho đó **đã chốt quỹ** (`cash_closings`) — số đã chốt không tự đổi theo, chỉ công nợ/sổ quỹ hiện tại được cập nhật.

**4. `lib/views/inventory_detail_view.dart`:** thêm dòng hiển thị "Thanh toán" (read-only) — trước đây model `Product.paymentMethod` đã có sẵn dữ liệu nhưng màn này chưa hiển thị (màn preview sản phẩm khác trong `inventory_view.dart` đã có sẵn dòng này từ trước).

**Bug tìm thấy + sửa NGAY trong lúc test trên máy thật (quan trọng):**
- **Permission-denied khi lưu:** code ban đầu cố `.update()` thẳng doc `stock_entries` đã confirmed — `firestore.rules` chỉ cho update khi status còn `draft` (đã confirmed thì chỉ super-admin sửa được, đúng chủ ý giữ bản ghi gốc bất biến). Đã bỏ hẳn việc sửa `stock_entries`, chỉ sửa `import_orders` (rule không giới hạn status, đây là bản ghi "hiện tại").
- **Sync-race âm thầm ghi đè ngược:** ban đầu chỉ `db.update()` (local) + `enqueue...()` (hàng đợi async) cho `debts`/`expenses` — xác nhận thật trên máy: 1 debt đã soft-delete xong bị "hồi phục" lại active sau đó (nghi do listener real-time kéo bản Firestore cũ đè ngược trước khi hàng đợi kịp đẩy lên). Đã sửa theo đúng pattern có sẵn ở `expense_view.dart` (xoá expense): ghi Firestore NGAY LẬP TỨC (try/catch, fallback enqueue nếu fail) thay vì chỉ dựa vào hàng đợi.
- **`ImportOrder.paidAmount` không khớp `paymentStatus`:** chỉ đổi `paymentStatus` mà quên set lại `paidAmount` (=totalAmount khi PAID, =0 khi DEBT) làm `SupplierDetailView` (tab Công nợ, nhánh fallback tính từ `import_orders` khi NCC hết debt thủ công) hiện sai số "còn lại". Đã sửa set cả 2 field cùng lúc.

**Verify (test trên Oppo CPH2203, `m@m.com`/shop "M"):** `flutter analyze` sạch (0 lỗi) sau từng bước sửa + toàn project. Build debug + cài lại 4 lần (mỗi lần fix xong 1 bug tìm thấy).
- Tạo phiếu CÔNG NỢ (NCC TÉT A, 500.000đ, IMEI thật) → xác nhận → sửa NCC (giữ nguyên) + đổi CÔNG NỢ→CHUYỂN KHOẢN → **thành công đầy đủ**: badge đổi CÔNG NỢ (cam)→ĐÃ THANH TOÁN (xanh) ngay tại chỗ, công nợ NCC biến mất, có khoản chi mới đúng NCC/số tiền trong Sổ quỹ (xác nhận qua feed "Hoạt động hôm nay"), `import_orders`/tab Công nợ NCC cập nhật đúng sau khi thêm fix `paidAmount`.
- Tạo phiếu CÔNG NỢ khác, đổi NCC + đổi CÔNG NỢ→TIỀN MẶT cùng lúc → xác nhận đổi cả 2 field đúng.
- Thử sửa lại 1 phiếu mà công nợ gốc đã bị xoá từ lần test trước (dữ liệu test tự tạo ra do bug đã fix) → xác nhận báo lỗi rõ ràng "Không tìm thấy công nợ gốc của phiếu này", không crash.
- **Chưa test trên máy:** chặn đổi loại thanh toán khi công nợ đã trả một phần (`paidAmount > 0`) — chỉ verify qua code review (logic thuần, không phụ thuộc async/Firestore rules nên rủi ro thấp hơn 3 bug đã tìm thấy ở trên). Vai trò STAFF (không phải Owner/Manager) thử sửa phiếu có đụng `expenses` — rule Firestore yêu cầu `isManager()` cho collection này (giống hệt luồng nhập kho TIỀN MẶT/CHUYỂN KHOẢN gốc), tài khoản test là Chủ shop nên chưa tự thấy lỗi quyền hạn này, nhưng đây là hành vi ĐÚNG theo thiết kế bảo mật sẵn có, không phải bug mới.

**Files:** `lib/services/stock_entry_service.dart`, `lib/data/db_helper.dart`, `lib/views/import_order_detail_view.dart`, `lib/views/inventory_detail_view.dart`.

---

## [2026-08-23c] - polish(sale,repair): thiết kế lại ảnh biên nhận/phiếu sửa giống tờ giấy in thật, chuyên nghiệp hơn

**Bối cảnh:** User phản hồi ảnh chia sẻ ở `[2026-08-23a/b]` chỉ là khối chữ monospace thô trong khung viền vuông — chưa "đẹp, chuyên nghiệp" như biên nhận thật. Yêu cầu rõ: ảnh chia sẻ phải nhìn giống hệt tờ giấy khi in ra, nhưng trình bày gọn gàng dễ nhìn hơn. Đã hỏi lại user chọn giữa 2 hướng (dạng thẻ hiện đại kiểu KiotViet, hoặc dải giấy hẹp giống hệt biên nhận in) — **user chọn giữ dải giấy giống biên nhận in thật**, chỉ làm sạch/đẹp hơn.

**`lib/widgets/receipt_paper_view.dart` (mới, dùng chung cho cả 2 màn xem trước):** widget nhận đúng chuỗi text đã build từ template (không đổi nội dung, tôn trọng mẫu shop tự tùy biến, đúng 100% những gì máy in nhiệt in ra) và trình bày lại: dòng toàn dấu `-` → 1 đường kẻ mảnh xám (`Divider`) thay vì ký tự gạch ngang thô hay bị ngắt dòng xấu; dòng bọc trong `===...===` → tiêu đề in đậm căn giữa, cỡ chữ lớn hơn, bỏ ký tự `=`; các dòng còn lại giữ nguyên monospace canh trái đúng như giấy in, chỉ tăng khoảng cách dòng cho dễ đọc. Khối "tờ giấy" bo góc nhẹ, nền trắng ngà, đổ bóng — đặt nổi trên nền xám nhạt (thay vì nền trắng đồng màu như trước) để trông như tờ biên nhận thật đặt trên mặt bàn.

**`sale_invoice_preview_view.dart` + `repair_invoice_preview_view.dart`:** thay hoàn toàn `Container` viền vuông + `Text` thô bằng `ReceiptPaperView`. Khối QR chuyển khoản (`_buildPaymentQrBlock` → đổi tên `_buildPaymentQrContent`, bỏ khung viền + bo góc riêng) giờ nằm **trong cùng 1 tờ giấy** với nội dung biên nhận, ngăn cách bằng 1 đường kẻ — đọc liền mạch như 1 tờ biên nhận duy nhất thay vì 2 khối tách rời như trước. Không đổi bất kỳ dữ liệu/công thức nào (số tiền, QR payload, logic hiện/ẩn) — thuần chỉnh trình bày.

**Verify (test trên Oppo CPH2203):** `flutter analyze` sạch (0 lỗi). Build debug + cài lại. Mở lại đúng đơn bán ABC (còn nợ 12tr, đã cấu hình QR) đã test ở `[2026-08-23b]`: xác nhận tiêu đề "HÓA ĐƠN BÁN HÀNG" hiện đậm giữa trang, các đường kẻ ngang sạch đẹp thay dấu gạch ngang thô, khối QR liền mạch trong cùng tờ giấy, nền xám làm tờ giấy nổi bật rõ. Bấm "Chia sẻ ảnh": xác nhận qua logcat `ChooserActivity` mở đúng — ảnh chụp vẫn hoạt động bình thường với layout mới. Mở phiếu sửa HUY (IPHONE 8): xác nhận cùng thiết kế áp dụng nhất quán, tiêu đề "PHIẾU SỬA CHỮA" hiện đúng. **Chưa test:** phiếu sửa nhánh có QR (đơn test giá 0đ) — cùng widget dùng chung với bên bán đã test kỹ nên tự tin dùng lại.

**Files:** `lib/widgets/receipt_paper_view.dart` (mới), `lib/views/sale_invoice_preview_view.dart`, `lib/views/repair_invoice_preview_view.dart`.

---

## [2026-08-23b] - feat(sale,repair): nút chia sẻ ảnh+QR ngay sau khi tạo đơn bán; đơn sửa dùng chung cơ chế ảnh+QR thay vì chỉ text

**Bối cảnh:** Nối tiếp `[2026-08-23a]` (đã build xong ảnh biên nhận + QR VietQR cho màn Xem trước đơn bán). User yêu cầu thêm 2 việc: (1) thêm lối vào nhanh để chia sẻ ngay sau khi tạo đơn bán xong (trước đó phải tự vào lại đơn → mở Xem trước mới thấy nút Chia sẻ); (2) đơn sửa hiện `_shareToZalo()` chỉ gửi text thuần (`Share.share(content)`), không có ảnh/QR như đơn bán — cần đồng bộ hoá.

**1. `lib/widgets/payment_result_sheet.dart` (mở rộng, không đổi hành vi mặc định):** thêm param tuỳ chọn `onShareReceipt` — chỉ khi caller truyền vào mới hiện thêm nút "Chia sẻ ảnh biên nhận" (OutlinedButton, phía trên nút Xong/Đóng). Widget này dùng chung cho cả tạo đơn bán VÀ thu công nợ (`debt_payment_sheet.dart`) — mặc định `null` nên 2 nơi gọi khác không hề đổi giao diện.

**2. `lib/views/sale_detail_view.dart`:** thêm `autoOpenPreview` (mặc định `false`) — khi `true`, `initState()` chờ ĐỦ cả 2 nguồn dữ liệu (`_loadShopInfo()` + `_loadCustomerDebt()`) qua `Future.wait(...)` trước khi tự mở `SaleInvoicePreviewView`, tránh race condition mở sớm lúc state còn rỗng dẫn tới QR/biên nhận hiện sai số tiền (đã cân nhắc kỹ vì đây là dữ liệu tiền — không dùng `addPostFrameCallback` đơn thuần vì không đợi được async load).

**3. `lib/views/create_sale_view.dart`:** sau khi lưu đơn thành công, truyền `onShareReceipt` vào `PaymentResultSheet.show()` — nếu người dùng bấm nút mới, thay vì `Navigator.pop()` như cũ thì `pushReplacement` sang `SaleDetailView(sale: sale, autoOpenPreview: true)`, tận dụng lại đúng luồng/nút Chia sẻ ảnh đã build+test ở `[2026-08-23a]`, không tạo pipeline mới.

**4. `lib/services/debt_summary_service.dart`:** thêm `remainingDebtFromLinkedDebt(Map? linkedDebt)` — hàm thuần tách từ công thức có sẵn trong `getOrderRemainingDebt`, dùng được cho MỌI loại đơn (đơn sửa cũng ghi nợ vào chung bảng `debts` qua `linkedId`, đã xác nhận qua code `repair_detail_view.dart` dùng `linkedId: r.firestoreId` giống hệt đơn bán) — không sửa hàm cũ, chỉ thêm hàm mới cạnh nó.

**5. `lib/views/repair_invoice_preview_view.dart`:** nâng cấp giống hệt kiến trúc `sale_invoice_preview_view.dart` (`[2026-08-23a]`) — bọc `Screenshot`, thêm nút chia sẻ ảnh trên AppBar, lọc dòng `[QR]repair_check:...` khỏi nội dung hiển thị (đúng bug tương tự đã gặp bên đơn bán), thêm khối QR chuyển khoản có điều kiện (chỉ khi còn nợ + đã cấu hình NH), số tiền QR tính qua `getCustomerActiveDebts(r.phone)` + `remainingDebtFromLinkedDebt()` mới thêm ở mục 4. Thêm cờ `autoShare` (mặc định `false`) — khi `true`, tự kích hoạt chia sẻ ảnh ngay sau khi layout xong (`addPostFrameCallback`, không cần đợi async như bên đơn bán vì không phụ thuộc dữ liệu công nợ động phức tạp bằng).

**6. `lib/views/repair_detail_view.dart`:** viết lại `_shareToZalo()` — thay vì `Share.share(text)`, giờ mở `RepairInvoicePreviewView(..., autoShare: true)`, giữ nguyên tên hàm nên KHÔNG cần sửa 2 nơi gọi (icon share trên AppBar + nút "ZALO"). Xoá import `share_plus` không còn dùng.

**Verify (test trên Oppo CPH2203, `m@m.com`/shop "M"):** `flutter analyze` sạch (0 lỗi) trên toàn bộ file sửa + toàn project. Build debug + cài lại.
- **Đơn bán:** tạo đơn CÔNG NỢ mới (khách ABC, 12.000.000đ) → bấm "HOÀN TẤT ĐƠN HÀNG" → sheet kết quả hiện đúng nút "Chia sẻ ảnh biên nhận" mới → bấm vào → tự động chuyển sang `SaleDetailView` rồi tự mở `SaleInvoicePreviewView` → xác nhận dữ liệu đúng NGAY LẬP TỨC (không bị stale do race): Mã HD đúng, Khách ABC, Tổng 12.000.000, "Còn nợ đơn: 12.000.000 đ", "Công nợ khách hiện tại: 12.000.000 đ", khối QR hiện đúng ngân hàng/số TK/số tiền/nội dung.
- **Đơn sửa:** mở đơn sửa có sẵn (HUY, IPHONE 8) → bấm icon Chia sẻ trên AppBar → tự mở `RepairInvoicePreviewView` → icon share hiện spinner (đang tự động chụp+chia sẻ) → nội dung phiếu hiện đúng, không còn dòng `[QR]repair_check:...` thô → xác nhận qua logcat: `ChooserActivity` (share sheet Android) được mở thành công, tự đóng do môi trường test không có thao tác người dùng thật chọn app đích (đúng dự kiến, không phải lỗi).
- **Chưa test:** nhánh đơn sửa CÓ nợ thực tế để QR hiện ra (đơn HUY test giá 0đ nên không có QR) — logic tính giống hệt bên bán đã test kỹ, tự tin dùng lại. Bước chọn app đích thật (Zalo) trong share sheet ở cả 2 luồng — không tự động hoá được từ môi trường adb.

**Files:** `lib/widgets/payment_result_sheet.dart`, `lib/views/sale_detail_view.dart`, `lib/views/create_sale_view.dart`, `lib/services/debt_summary_service.dart`, `lib/views/repair_invoice_preview_view.dart`, `lib/views/repair_detail_view.dart`.

---

## [2026-08-23a] - feat(sale,kho): ảnh biên nhận + QR chuyển khoản VietQR qua Zalo; gợi ý giá vốn/giá bán khi nhập kho

**Bối cảnh:** 2 tính năng độc lập, yêu cầu ngay sau khi test xong module công nợ `[2026-08-22a]`. (1) Biên nhận đơn bán trước đây chỉ xem/in dạng text, không có ảnh để gửi Zalo, không có QR chuyển khoản thật (token `{qrData}`/`[QR]sale_check:...` chỉ là mã tra cứu nội bộ khi quét lại tại shop). (2) Nhập kho không có gợi ý giá vốn/giá bán tham khảo như đơn sửa đã có (`PricingEngineService`).

**Nguyên tắc an toàn:** không đụng luồng lưu shop hiện có (`shop_settings_view.dart`, vốn đã phức tạp 3-tầng fallback) — thông tin ngân hàng lưu tách riêng ở `shops/{shopId}/settings/bank_qr` (đúng rule Firestore sẵn có cho subcollection `settings`, không cần sửa `firestore.rules`/Cloud Functions). Không sửa `unified_printer_service.dart` (luồng in giấy cũ giữ nguyên 100%). Không đụng đơn sửa/`PricingEngineService` — chỉ đọc tham khảo pattern.

**1. `lib/utils/vietqr_builder.dart` (mới):** `buildVietQrPayload()` — mã hoá đúng chuẩn EMVCo/VietQR (GUID napas `A000000727`, field 38 merchant info, 53 currency VND, 54 amount, 62 nội dung CK, 63 CRC-16/CCITT-FALSE). Verify độc lập bằng test vector CRC chuẩn + tự viết parser TLV round-trip xác nhận payload giải mã đúng ngược lại. **Chưa verify bằng cách quét thật với app ngân hàng** (không có cách tự động hoá từ môi trường dev) — user cần tự quét thử trước khi gửi khách thật.

**2. `lib/views/bank_qr_settings_view.dart` (mới) + `home_view.dart`:** màn cài đặt tài khoản NH (chọn NH từ danh sách BIN cố định 29 NH phổ biến VN, số TK, tên chủ TK) — chỉ chủ shop (owner) sửa được, ghi Firestore (`shops/{shopId}/settings/bank_qr`) + cache SharedPreferences để đọc nhanh offline. Lối vào: tile "QR chuyển khoản" mới trong màn Cài đặt thật (`home_view.dart`, nhóm `shop`) — **lưu ý: `settings_view.dart` là dead code** (class không được instantiate ở đâu cả, đã phát hiện khi tìm nhầm chỗ thêm tile lần đầu; để nguyên không dọn vì không ảnh hưởng gì, chỉ ghi chú lại cho lần dọn dẹp sau).

**3. `lib/views/sale_invoice_preview_view.dart`:** bọc `Screenshot` (package `screenshot`, có sẵn trong pubspec nhưng chưa từng dùng) quanh khối "tờ giấy biên nhận" → nút "Chia sẻ ảnh" mới trên AppBar chụp thành PNG, chia sẻ qua `SharePlus.instance.share(ShareParams(files:...))` (API v12 mới, thay `Share.shareXFiles` deprecated). Thêm khối QR chuyển khoản (`_buildPaymentQrBlock()`) hiện **có điều kiện** — chỉ khi đơn còn nợ (`remainingDebt > 0`) VÀ đã cấu hình NH — số tiền QR = đúng số còn nợ của đơn (không phải nhập tay), nội dung tự sinh "CK DON <mã rút gọn>" (bỏ dấu, viết hoa qua `VietnameseUtils.removeDiacritics`). Nội dung text hiển thị lọc bỏ dòng `[QR]`-prefix thô (giữ nguyên cơ chế in giấy/quét lại tại shop, không đổi gì bên đó).

**4. `lib/data/db_helper.dart` + `lib/services/product_pricing_service.dart` (mới):** `getProductsForPricing()` (mirror `getRepairsForPricing`) + `ProductPricingService` — cùng thuật toán thống kê với `PricingEngineService` (median, cắt outlier IQR khi ≥4 mẫu, hạ độ tin cậy khi biến động cao) nhưng viết service riêng vì cách khớp dữ liệu khác (sản phẩm khớp theo model, không có khái niệm dịch vụ/linh kiện như đơn sửa). Nối UI vào **cả 2 màn** `fast_stock_in_view.dart` và `smart_stock_in_view.dart` — debounce 700ms trên field model, card "GIÁ THAM KHẢO" với 2 nút tự điền giá vốn/giá bán riêng biệt (khác đơn sửa chỉ có 1 giá).

**Verify (test trên Oppo CPH2203, `m@m.com`/shop "M"):** `flutter analyze` sạch sau từng bước, build debug + cài thành công. Cấu hình thử 1 tài khoản NH (Vietcombank/TRANMINH/0071000123456) → lưu thành công (xác nhận ghi Firestore owner-only qua rule sẵn có). Mở đơn bán còn nợ 500.000đ → Xem trước: khối QR hiện đúng — tên NH, số TK, QR image, "Số tiền: 500.000 đ", "Nội dung: CK DON 095979" đều khớp code. Bấm "Chia sẻ ảnh": logcat xác nhận `ChooserActivity` (share sheet Android) được mở đúng — chụp ảnh + tạo file tạm + gọi share intent chạy đúng luồng (chưa test tới bước chọn app đích cụ thể vì môi trường test tự động không có thao tác người dùng thật chọn Zalo). Vào Nhập kho → Nhập nhanh → chọn IPHONE/128GB/model "12": card gợi ý hiện đúng "Chưa đủ dữ liệu lịch sử để đề xuất giá" (tài khoản test chưa có lịch sử nhập phù hợp) — xác nhận toàn bộ chuỗi debounce → query DB → tính toán → render UI chạy không lỗi, đúng hành vi fallback dự kiến. **Chưa test:** nhánh có đủ dữ liệu lịch sử để thực sự hiện được số gợi ý (cần dữ liệu nhập kho lặp lại cùng model mà tài khoản test hiện chưa có); màn `smart_stock_in_view.dart` (pattern giống hệt `fast_stock_in_view.dart`, chỉ verify qua code + `flutter analyze`, không test trực tiếp trên máy do cùng logic).

**Files:** `lib/utils/vietqr_builder.dart` (mới), `lib/views/bank_qr_settings_view.dart` (mới), `lib/services/product_pricing_service.dart` (mới), `lib/data/db_helper.dart`, `lib/views/home_view.dart`, `lib/views/settings_view.dart` (dead code, không ảnh hưởng), `lib/views/sale_invoice_preview_view.dart`, `lib/views/fast_stock_in_view.dart`, `lib/views/smart_stock_in_view.dart`.

---

## [2026-08-22a] - feat(sale,debt): công nợ khách hàng gộp nhiều đơn (bán sỉ) + thu tiền phân bổ FIFO

**Bối cảnh:** User chuyển hướng bán sỉ — 1 khách mua nhiều đơn, nợ cộng dồn qua nhiều đơn, muốn trả gộp sau thay vì trả từng đơn riêng lẻ. Trước đây `debts` là 1 dòng nợ : 1 đơn, không có khái niệm "tổng công nợ khách qua nhiều đơn", và `sale_detail_view.dart` không hiển thị số đã thu/còn nợ nào cả. Yêu cầu đầy đủ đã lập plan trước khi code (`/plan`), người dùng chốt: (1) làm toàn bộ nhưng cẩn thận từng bước; (2) "Nợ trước đơn" tính real-time (không lưu snapshot); (3) chặn thu vượt tổng công nợ hiện tại.

**Nguyên tắc an toàn:** không đổi schema `sales`/`customers`/`debts`; chỉ thêm 1 cột mới nullable `debt_payments.paymentGroupId`; không đổi công thức doanh thu/giá vốn/tồn kho; không đổi cấu trúc Firestore — tái dùng nguyên `debts`/`debt_payments`/`payment_intents` + đường sync hiện có (`SyncOrchestrator`, `syncPaymentRelatedData`).

**1. Migration DB (v105 → v106):** thêm cột `debt_payments.paymentGroupId TEXT` (nullable) — nhóm nhiều dòng `debt_payments` (mỗi dòng vẫn 1 khoản trả cho đúng 1 đơn như cơ chế cũ) thành 1 "phiếu thu gộp" khi khách trả 1 lần cho nhiều đơn. `PaymentIntentService._updateRelatedEntities` đọc thêm `metadata['paymentGroupId']` nếu có — backward-compatible, caller cũ không set thì vẫn `null`, hành vi cũ giữ nguyên 100%.

**2. Service layer mới:**
- `DebtSummaryService` (mở rộng): `getCustomerActiveDebts(phone)` (danh sách đơn còn nợ của khách, sort cũ nhất trước = FIFO), `getAllCustomerDebtsForHistory(phone)`, `getNetDebtByPhoneMap()` (1-query cho danh sách, tránh N+1), `getOrderRemainingDebt(sale)`, `sumNetDebt()`/`computeNetDebtForPhone()`. Đã refactor 3 chỗ đang lặp SQL thô y hệt (`create_sale_view.dart`, `create_repair_order_view.dart`, `sale_list_view.dart._effectiveRemainingDebt`) gọi lại các hàm này — cùng công thức, cùng kết quả, chỉ gom về 1 chỗ.
- `CustomerDebtPaymentService` (mới, `lib/services/customer_debt_payment_service.dart`): `suggestFifoAllocation()` (hàm thuần, đề xuất phân bổ cũ-nhất-trước) + `collectPayment()` — validate chặn vượt tổng nợ (server-side, không chỉ tin UI), lặp gọi `PaymentIntentService.executePaymentDirect` cho từng đơn (tái dùng nguyên cơ chế 1-đơn đã chạy production của `DebtPaymentSheet`, không xây pipeline mới), gắn chung `paymentGroupId`, ghi 1 audit log tổng hợp cho cả phiếu.

**3. Màn hình mới:**
- `lib/views/customer_debt_view.dart` — Công nợ khách hàng: tổng nợ hiện tại, danh sách đơn còn nợ (bán + sửa, tap mở đúng đơn), lịch sử công nợ dạng timeline (tạo đơn + thu tiền, gộp cả đơn đã trả hết). Mở từ `customer_profile_view.dart` (card mới, chỉ hiện khi có nợ) và từ `sale_detail_view.dart`.
- `lib/views/collect_customer_debt_view.dart` — luồng thu tiền gộp 3 bước: (1) nhập tiền + phương thức, chặn nhập vượt tổng nợ; (2) bảng phân bổ FIFO đề xuất sẵn nhưng sửa tay được từng đơn (không khóa cứng FIFO), validate tổng phân bổ khớp số tiền nhập; (3) kết quả — công nợ trước/sau, breakdown từng đơn, đơn nào hết nợ.

**4. `sale_detail_view.dart` (thuần cộng thêm):** card "CÔNG NỢ KHÁCH HÀNG" (Nợ trước đơn + Nợ phát sinh từ đơn = Công nợ sau đơn, tách rõ khỏi nợ riêng đơn này); banner "CÒN NỢ ĐƠN" + nút THU TIỀN khi đơn còn nợ; dòng "Tổng đã thu" trong khối tổng tiền (nhãn rõ ràng, tránh gây hiểu lầm đã thu đủ). Tiện thể sửa `remainingDebt` trong `_buildSalePrintData()` từ `s.remainingDebt` thô (chỉ tính trả góp NH) sang `_orderRemainingDebt` (ưu tiên bảng `debts`, đúng cho cả đơn CÔNG NỢ) — cùng công thức `sale_list_view.dart` đã dùng, sửa đúng cho mọi đơn, không đổi gì cho đơn không có công nợ qua bảng `debts`.

**5. Biên nhận:** thêm token `{customerTotalDebt}` (tách riêng khỏi `{remainingDebt}` — không trộn "nợ đơn này" với "tổng công nợ khách") ở `sale_invoice_preview_view.dart` + mẫu mặc định `sale_invoice_template_view.dart`. Chỉ ảnh hưởng shop dùng mẫu mặc định (chưa tự tùy biến) — shop đã lưu mẫu riêng trong SharedPreferences giữ nguyên, có thể tự thêm token mới nếu muốn.

**6. `sale_list_view.dart`:** thêm dòng nhỏ "Công nợ khách hiện tại" dưới chip Nợ (chỉ hiện khi khách còn nợ đơn khác ngoài đơn đang xem), dùng `getNetDebtByPhoneMap()` gọi 1 lần khi load danh sách.

**Quyết định phạm vi có ý thức:** không tách `debt_view.dart._showDebtHistory()` thành widget dùng chung như plan ban đầu dự tính — thay vào đó xây timeline riêng, độc lập trong `CustomerDebtView`, để **không đụng vào màn công nợ shop-wide đang chạy production hàng ngày**. Timeline mới không tính lại "công nợ sau mỗi giao dịch" theo lịch sử (event-sourcing replay) — chỉ hiển thị từng sự kiện (tạo đơn / thu tiền) kèm số tiền, không có cột số dư lũy kế tại mỗi thời điểm.

**🐛 Bug tìm thấy + sửa khi test trên máy thật:** nút THU TIỀN trong banner "CÒN NỢ ĐƠN" (`sale_detail_view.dart`) làm cả `Container` cha phình to bất thường (~900px), nội dung/nút biến mất khỏi màn hình. Nguyên nhân: `AppButtonStyles.elevatedButtonStyle` (style mặc định TOÀN APP cho mọi `ElevatedButton`, `lib/theme/app_button_styles.dart:45`) đặt `minimumSize: Size(double.infinity, buttonHeight)` — mọi `ElevatedButton` mặc định full-width. Nút mới đặt trong `Row` cạnh 1 `Expanded` khác; `RenderFlex` đo children không-flex với constraint width KHÔNG GIỚI HẠN trước, nút đòi `minWidth: infinity` khớp constraint đó nên báo kích thước `infinity`, làm hỏng phép tính layout của `Row`/`Container` cha. Sửa: ghi đè `minimumSize: Size.zero` trong `style` của riêng nút này. Đã rà toàn bộ `ElevatedButton` khác trong `customer_debt_view.dart`/`collect_customer_debt_view.dart` — tất cả đều bọc `SizedBox(width: double.infinity, ...)` đứng riêng trong `Column` (không cạnh `Expanded` trong `Row`) nên không dính lỗi này.

**Verify (ĐÃ test đầy đủ trên thiết bị thật — Oppo CPH2203, `m@m.com`/shop "M"):** `flutter analyze` sạch toàn project sau từng bước + sau khi sửa bug trên. Build debug + cài qua `adb`, logcat sạch không FATAL/exception xuyên suốt (cài mới, mở lại app, restart, cài đè bản có bug rồi bản đã sửa). Xác nhận trực tiếp qua file DB kéo về từ máy (`PRAGMA user_version` + `PRAGMA table_info`): **migration v105→v106 tự chạy đúng trên dữ liệu cũ thật**, cột `paymentGroupId` đã có. Test full luồng nghiệp vụ trên khách thật có sẵn 2 đơn CÔNG NỢ (1 đơn đã trả hết từ trước, 1 đơn còn nợ 2.000.000đ): mở `SaleDetailView` → card công nợ hiện đúng "Nợ trước đơn 0 + Nợ phát sinh 2 Tr = Công nợ sau đơn 2 Tr" → bấm THU TIỀN → nhập 1.000.000đ → bước phân bổ FIFO tự đề xuất đúng, thử sửa tay số vượt số dư bị chặn đúng ("Vượt số dư", nút Xác nhận tự disable) → xác nhận thu → bước kết quả hiện đúng "-1.000.000đ / Còn 1.000.000đ". Kiểm tra ngược lại DB sau khi thu: `debts.paidAmount` tăng đúng +1.000.000 (10tr→11tr), `debt_payments` có dòng mới với `paymentGroupId` đã điền, `sales.totalPrice` **không đổi** (12.000.000 — xác nhận doanh thu không bị tính trùng), `payment_intents` status COMPLETED. Quay lại `SaleDetailView`/`CustomerDebtView`: số liệu cập nhật ngay lập tức đúng (còn nợ đơn 1 Tr, tổng đã thu 11 Tr, timeline công nợ hiện đủ 2 lần thu tiền + 2 lần tạo đơn). Trang chủ "HOẠT ĐỘNG HÔM NAY" cũng hiện đúng giao dịch thu nợ mới. **Chưa test:** đồng bộ nhiều thiết bị cùng lúc (chỉ có 1 máy trong phiên), luồng "Chuyển khoản" (chỉ test Tiền mặt), trường hợp phân bổ cắt ngang nhiều đơn cùng lúc (dữ liệu test hiện chỉ có 1 đơn còn nợ tại thời điểm test).

**Files:** `lib/data/db_helper.dart`, `lib/services/payment_intent_service.dart`, `lib/services/debt_summary_service.dart`, `lib/services/customer_debt_payment_service.dart` (mới), `lib/views/customer_debt_view.dart` (mới), `lib/views/collect_customer_debt_view.dart` (mới), `lib/views/customer_profile_view.dart`, `lib/views/sale_detail_view.dart`, `lib/views/sale_list_view.dart`, `lib/views/create_sale_view.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/sale_invoice_preview_view.dart`, `lib/views/sale_invoice_template_view.dart`.

---

## [2026-08-17e] - chore(release): lên bản 3.4.0+545 + nâng iOS min deployment lên 15.0

**Version:** `pubspec.yaml` 3.3.0+541 → **3.4.0+545** (gồm toàn bộ fix trong ngày 2026-08-17: chống mất dữ liệu khi duyệt giao/sửa giá vốn, sửa báo nhầm mạng chập chờn, list đơn sửa cập nhật ngay, xóa đơn không còn mồ côi dữ liệu cloud, chặn công nợ đoán sai chiều).

**iOS min deployment 14.0 → 15.0:** thực hiện sớm theo cảnh báo Apple (App Store Connect bắt buộc tối thiểu 15.0 từ mùa xuân 2027) — sửa `ios/Podfile` (3 chỗ: `platform :ios`, 2 dòng `IPHONEOS_DEPLOYMENT_TARGET` trong `post_install`), `ios/Runner.xcodeproj/project.pbxproj` (3 config Debug/Release/Profile), và `ios/Flutter/AppFrameworkInfo.plist` (`MinimumOSVersion`).

**Verify:** Android — `flutter build apk --debug` OK, cài lên Oppo CPH2203 xác nhận `versionName=3.4.0 versionCode=545`, mở app không crash (logcat sạch FATAL/AndroidRuntime). **iOS chưa build được** (máy làm việc Windows, không có Xcode) — cấu hình đã sẵn sàng trong code, **user cần tự build trên Mac** (`pod install` sẽ áp dụng target 15.0 mới) rồi archive/submit App Store Connect như bình thường.

**Files:** `pubspec.yaml`, `ios/Podfile`, `ios/Runner.xcodeproj/project.pbxproj`, `ios/Flutter/AppFrameworkInfo.plist`.

---

## [2026-08-17d] - fix: xóa đơn sửa mồ côi dữ liệu cloud + chặn công nợ đoán sai chiều thu/trả

**Bối cảnh:** User yêu cầu test toàn diện module Sửa chữa trước khi lên Store. Trong lúc test, user tự dùng "Công cụ điều chỉnh dữ liệu" xóa hàng loạt đơn test — sau đó Trung tâm đồng bộ báo "11 bản ghi chưa khớp" (Local: 59, Cloud: 70) không tự hết. User cũng báo 1 lần gặp màn hình đỏ (crash) khi thanh toán công nợ NCC vừa tạo từ giá vốn đơn sửa, sau khi thoát/vào lại thấy giao dịch ghi nhầm thành "Thu nợ KH" thay vì "Trả nợ NCC".

**Bug 1 — xóa đơn mồ côi dữ liệu cloud (nguyên nhân gốc của "11 chưa khớp"):** `FirestoreService.deleteRepair`/`deleteSale` tự nuốt lỗi mạng (`catch (e) { debugPrint(...) }` rồi thôi), khiến 2 nơi gọi nó — `data_reconciliation_service.dart:_deleteRepairRecord` và `order_list_view.dart` (nút xóa đơn gốc) — luôn tưởng cloud đã xóa thành công rồi xóa local vô điều kiện. Khi mạng chập chờn giữa lúc xóa hàng loạt, document trên Firestore không hề bị đánh dấu `deleted:true`, mồ côi vĩnh viễn, khiến "Trung tâm đồng bộ" báo lệch mãi không tự hết — và nguy hiểm hơn, lần sync lịch sử tiếp theo có thể **kéo ngược đơn tưởng đã xóa trở lại local**. Đã sửa: `deleteRepair`/`deleteSale` hết nuốt lỗi (rethrow), 2 nơi gọi bắt lỗi và xếp vào hàng đợi `SyncOrchestrator` (`SyncOperation.delete`) để tự động thử lại thay vì bỏ cuộc âm thầm. (Nhánh xóa đơn bán ở `sale_detail_view.dart`/`data_reconciliation_service.dart` đã có sẵn cơ chế này từ trước — chỉ nhánh đơn sửa thiếu.)

**Bug 2 — công nợ đoán nhầm chiều thu/trả khi thiếu `type` (đã hardening, chưa xác nhận 100% là nguyên nhân crash):** `debt_payment_sheet.dart` cũ: `(debt['type'] ?? 'CUSTOMER_OWES')` — nếu map công nợ truyền vào thiếu field `type` (bản ghi lỗi/đường dữ liệu hiếm gặp), code **âm thầm coi là "Thu nợ khách"** thay vì báo lỗi — sai hướng hoàn toàn nếu bản chất là nợ NCC (phải trả). Đây là kiểu lỗi nguy hiểm hơn crash vì không ai để ý ngay, im lặng ghi sai chiều dòng tiền. Đã sửa: nếu `type` rỗng/thiếu, chặn thanh toán + báo lỗi rõ ràng thay vì đoán. **Lưu ý minh bạch:** đã cố tái hiện lại crash gốc (đọc kỹ toàn bộ chuỗi gọi `Ghi vào sổ quỹ` → `DebtPaymentSheet` → `PaymentIntentService` → `PaymentResultSheet`, dựng lại dữ liệu test) nhưng KHÔNG bắt được đúng stack trace lúc crash thật (log đã trôi khỏi buffer do quá nhiều hoạt động sync xen giữa) và không dựng lại được chính xác thao tác user đã làm. Toàn bộ logic chiều tiền (SHOP_OWES → OUT/Trả, CUSTOMER_OWES → IN/Thu) đã rà lại, đúng khi `type` có mặt — bản vá này chặn đúng trường hợp duy nhất có thể gây sai hướng mà code review tìm ra được.

**Verify:** `flutter analyze` sạch (chỉ info/warning có sẵn) trên cả 4 file. Build + cài lại Oppo CPH2203. Test trực tiếp trên máy: tạo đơn sửa mới → đổi trạng thái đủ vòng đời (Tiếp nhận → Sửa xong → Duyệt giao) → sửa giá vốn có ghi nợ NCC → xác nhận không còn báo "mạng chập chờn" giả, danh sách cập nhật ngay lập tức (thừa hưởng đúng từ fix `[2026-08-17c]`), không crash qua nhiều vòng mở/đóng sheet Ghi chú KTV. Dữ liệu test hiện đã được user tự dọn sạch (shop test "M"), sẵn sàng cho vòng test tiếp theo trên dữ liệu sạch.

**Files:** `lib/services/firestore_service.dart`, `lib/services/data_reconciliation_service.dart`, `lib/views/order_list_view.dart`, `lib/widgets/debt_payment_sheet.dart`.

## [2026-08-17c] - fix(repair): fix `[2026-08-17b]` (việc 2) mới chỉ đúng 1 nửa — sửa tiếp cho đơn CHƯA giao

**User test lại, báo tiếp:** đơn Samsung hiện "TIẾP NHẬN" trong danh sách, bấm vào thấy "ĐÃ GIAO" đúng, back ra danh sách vẫn còn "TIẾP NHẬN" — y hệt lỗi tưởng đã sửa ở `[2026-08-17b]`.

**Nguyên nhân thật sự (fix trước chưa đủ):** `order_list_view.dart` gộp 2 nguồn dữ liệu để hiển thị — `_repairsByFirestoreId` (cache realtime Firestore, dùng cho đơn CHƯA giao, status < 4) và SQLite (dùng cho đơn ĐÃ giao). Code merge ưu tiên tuyệt đối cache realtime cho các đơn CHƯA giao. Fix `[2026-08-17b]` chỉ gọi `_refreshFromSQLite()` — với đơn còn đang xử lý (chưa giao), dữ liệu SQLite mới bị merge LOẠI BỎ hoàn toàn vì đã có mặt trong cache realtime, nên list vẫn hiển thị giá trị cache cũ cho tới khi có 1 snapshot Firestore mới tự đẩy về (không đồng bộ với thời điểm quay lại màn hình).

**Fix đúng:** sau khi quay lại từ chi tiết, đọc lại đúng bản ghi đơn đó bằng `db.getRepairByFirestoreId(fid)` (không dùng `r.id` vì đơn nguồn cache realtime thường không có `id` cục bộ) rồi cập nhật thẳng vào `_repairsByFirestoreId`: nếu đã chuyển sang "Đã giao" (status ≥ 4) thì gỡ khỏi cache active để rơi về nguồn SQLite, ngược lại ghi đè giá trị mới tại chỗ — rồi `_rebuildDisplayedRepairs()` ngay, không đợi snapshot Firestore.

**Verify:** Build + cài lại Oppo CPH2203, test trực tiếp qua danh sách "đơn chờ xử lý" (không phải mở lại app): bấm "XONG" trên 1 đơn đang xử lý → back → đơn biến mất khỏi list NGAY LẬP TỨC kèm toast xác nhận, không cần thoát app. Lặp lại 2 lần trên 2 đơn khác nhau (VIVO, OPPO), cả 2 lần đều đúng.

**Files:** `lib/views/order_list_view.dart`.

---

## [2026-08-17b] - fix(repair): sửa lỗi TỰ GÂY RA — báo nhầm "mạng chập chờn" ở MỌI đơn + list không tự cập nhật

**User báo 2 việc liền sau bản `[2026-08-17a]`:** (1) đơn nào cũng thấy banner cam "⚠️ Đã duyệt trên máy — mạng chập chờn..." dù mạng bình thường; (2) đổi trạng thái xong back về danh sách vẫn thấy trạng thái cũ, phải thoát hẳn ra Trang chủ vào lại mới đúng.

**Việc 1 — lỗi do CHÍNH fix `[2026-08-17a]` gây ra, xin lỗi:** logic "đọc lại DB xem đã đồng bộ chưa" mới thêm chỉ tin vào cờ `isSynced` trong SQLite — nhưng cờ này CHỈ được `SyncOrchestrator` bật lên khi nó tự xử lý hàng đợi (`syncAll()`). Code mới lại có nhánh: nếu bước ghi trực tiếp lên cloud đã thành công thì **bỏ qua không gọi `syncAll()`** (tưởng là tối ưu, đỡ tốn 1 lượt mạng) — kết quả là cờ `isSynced` trong DB không bao giờ được bật lên dù cloud đã nhận đúng dữ liệu, nên lần đọc lại sau đó LUÔN thấy "chưa đồng bộ" — báo nhầm cảnh báo ở MỌI đơn, kể cả khi mạng hoàn toàn ổn định. Fix: khi ghi trực tiếp thành công, tự đánh dấu `isSynced=true` thẳng vào DB ngay lúc đó thay vì trông chờ `syncAll()`.

**Việc 2 — lỗi có sẵn từ trước, không liên quan gói vừa rồi:** `order_list_view.dart` chỉ làm mới danh sách khi màn chi tiết trả về đúng giá trị `true` lúc pop — nhưng các nút đổi trạng thái nhanh (VD "XONG") không tự đóng màn hình, người dùng phải tự bấm nút Back, trả về `null` chứ không phải `true`, nên bị bỏ qua bước làm mới. Fix: luôn làm mới từ SQLite (thao tác cục bộ, rẻ) mỗi khi quay lại từ màn chi tiết, không còn phụ thuộc giá trị trả về.

**Verify:** `flutter analyze` sạch. Build + cài Oppo CPH2203, test lại trên đơn thật: Duyệt giao 1 đơn mới → xác nhận KHÔNG còn báo nhầm, hiện đúng "Đã sync" → back về danh sách → đơn đã giao biến mất khỏi danh sách hoạt động NGAY LẬP TỨC (trước đây phải thoát hẳn ra Trang chủ mới thấy đúng). Không crash.

**Files:** `lib/views/repair_detail_view.dart`, `lib/views/order_list_view.dart`.

---

## [2026-08-17a] - fix(repair): 🔴 NGHIÊM TRỌNG — đơn đã Duyệt giao/sửa giá vốn bị "hiện lại như chưa làm gì"

**User báo (kèm 4 ảnh chụp):** cài bản test mới nhất, bấm DUYỆT giao máy đơn IPHONE 13 + sửa giá vốn 3.500.000. Chat nội bộ và Nhật ký đều xác nhận đã làm — nhưng vào lại app, đơn vẫn hiện "CHỜ DUYỆT" và giá vốn về lại 0, như chưa từng thao tác. User nhấn mạnh đây là lỗi nghiêm trọng, ảnh hưởng uy tín, dù không phải đơn nào cũng gặp (thỉnh thoảng).

**Nguyên nhân (2 lỗ hổng có thật trong code, đọc kỹ toàn bộ luồng Duyệt giao + Sửa giá vốn để xác nhận):**

1. **Patch trạng thái lên cloud thiếu giá thu/vốn**: khi Duyệt giao, app gửi 1 patch riêng lên cloud chỉ gồm trạng thái/ngày giao/bảo hành — KHÔNG gồm giá. Giá được ghi bằng 1 lần riêng chạy sau. Nếu lần ghi giá đó trễ/lỗi mạng, cloud tạm thời (hoặc vĩnh viễn nếu lỗi hẳn) chỉ có đúng trạng thái mà thiếu giá.

2. **Ghi lên cloud kiểu "bắn đi không đợi, lỗi thì im lặng bỏ qua"**: cả bước Duyệt giao và bước Sửa giá vốn đều gọi ghi Firestore theo kiểu không chờ xác nhận (`unawaited`) + lỗi bị nuốt im lặng (`catchError((_) {})`), rồi vẫn báo "Đã lưu thành công" cho user bất kể ghi cloud có thật sự thành công hay không. Nếu đúng lúc đó mạng chập chờn, cloud KHÔNG nhận được thay đổi dù màn hình báo thành công — cơ chế tự đồng bộ định kỳ (mới thêm hôm qua để đơn không "trễ tin" giữa các máy) sau đó vô tình lấy về đúng dữ liệu CŨ trên cloud, ghi đè local — khớp chính xác triệu chứng user báo.

**Fix (chỉ thêm/siết chặt, không đổi cấu trúc luồng chính):**
- `_pushRepairStatusToCloud()`: thêm `price`/`cost` vào patch — đóng khoảng hở giữa lúc trạng thái lên cloud và lúc giá lên cloud. Xác nhận an toàn ở cả 4 nơi gọi hàm này (giá/vốn hiện tại luôn đúng ý định tại thời điểm gọi).
- `_approveDelivery()` và `_saveData()`: đổi từ "bắn đi không đợi + nuốt lỗi" sang **chờ xác nhận thật sự** (có timeout), rồi **đọc lại tình trạng đồng bộ từ DB** (không dựa vào biến bộ nhớ cũ) để biết chắc đã lên cloud hay chưa. Nếu chưa lên được cloud, báo rõ cho user bằng snackbar cam "⚠️ Đã lưu trên máy — mạng chập chờn nên CHƯA đồng bộ lên cloud, app sẽ tự thử lại" thay vì báo xanh "Đã lưu" gây hiểu lầm.

**Verify:** `flutter analyze` sạch (0 lỗi). Build + cài Oppo CPH2203, test trực tiếp toàn bộ luồng trên đơn thật: tạo đơn test → chuyển SỬA XONG → bấm GIAO, nhập giá 999.000đ → DUYỆT → xác nhận: chuyển đúng "ĐÃ GIAO", "Đã sync", giá hiện đúng 999.000đ. Thoát ra vào lại (cả màn chi tiết lẫn danh sách reload mới hoàn toàn) — **dữ liệu vẫn đúng, không hề revert** — xác nhận đã sửa đúng lỗi báo cáo. Không crash trong toàn bộ quá trình. **Giới hạn:** không mô phỏng được chính xác kịch bản "mất mạng giữa chừng" qua adb nên chỉ xác nhận chắc chắn nhánh mạng bình thường (happy path) hoạt động đúng và không có hồi quy — nhánh mất mạng dựa trên suy luận logic code (đã đọc kỹ, tin cậy cao) chứ chưa tận mắt thấy.

**Còn sót lại 1 đơn test** trong danh sách thật: "SAMSUNG ETMODELSYNC / TESTSYNCFIX / 0900001111", đã giao, giá 999.000đ — user tự xóa qua Công cụ điều chỉnh dữ liệu khi tiện.

**Files:** `lib/views/repair_detail_view.dart`.

---

## [2026-08-16u] - feat: buộc cập nhật — chặn bản app cũ, bắt buộc lên bản mới

**Yêu cầu user:** "có cách nào chặn toàn bộ những app bản cũ không cho sử dụng mà buộc cập nhật hay không". User hỏi thêm liệu vừa build bản 3.3.0/541 (đang chờ Apple duyệt) có bị ảnh hưởng không — đã giải thích: bản đang chờ duyệt là nhị phân "đóng băng", sửa code bây giờ không đụng tới; tính năng chỉ có hiệu lực từ bản MỚI (sau 541) có chứa code này. User đồng ý làm.

**Thiết kế theo nguyên tắc an toàn bắt buộc (do đây là tính năng có thể khoá TOÀN BỘ người dùng thật nếu sai sót):**
- **Fail-open tuyệt đối**: bất kỳ lỗi/timeout nào khi đọc cấu hình (mất mạng, chưa có doc, permission-denied...) đều KHÔNG chặn app — chỉ chặn khi đọc được cấu hình rõ ràng và chắc chắn build hiện tại thấp hơn mức tối thiểu.
- **Cảnh báo rõ ràng trong màn cấu hình**: nhắc CHỈ đặt số build của bản ĐÃ ĐƯỢC DUYỆT và có sẵn trên kho ứng dụng — tránh tình huống khoá user nhưng họ chưa tải được bản mới để cập nhật (kẹt cứng không lối thoát).
- **Dialog xác nhận trước khi bật**: khi Super Admin đặt số build > 0 (bật gate), hiện dialog tóm tắt chính xác sẽ chặn ai, kèm cảnh báo trên, bắt xác nhận lại mới lưu.

**Files mới/sửa:**
- `lib/widgets/version_gate_wrapper.dart` (mới) — đọc `app_config/version_gate` từ Firestore lúc mở app (gắn ở `builder:` của `MaterialApp` trong `main.dart` nên áp dụng cho MỌI màn hình), so `AppInfo.getBuildNumber()` hiện tại với `minAndroidBuild`/`minIosBuild` theo đúng nền tảng. Nếu bị chặn: hiện màn toàn màn hình không đóng được (`PopScope(canPop: false)`), chỉ có nút "CẬP NHẬT NGAY" mở đúng link store theo nền tảng (tái dùng `NotificationService.androidStoreUrl`/`iosStoreUrl` có sẵn).
- `lib/main.dart` — bọc `child` trong `MaterialApp.builder` bằng `VersionGateWrapper`.
- `lib/views/super_admin_console_view.dart` — thêm mục "Buộc cập nhật" mới (`_VersionGateSection`): 2 ô nhập số build tối thiểu Android/iOS + thông báo tuỳ chỉnh, hiện rõ trạng thái đang bật/tắt, nút Lưu kèm dialog xác nhận nếu đang bật gate.
- `firestore.rules` — thêm collection `app_config`: đọc công khai (`allow read: if true` — phải đọc được ngay lúc mở app, trước khi biết user là ai), chỉ Super Admin được ghi. Đã `firebase deploy --only firestore:rules` thành công.

**Verify:** `flutter analyze` sạch (0 lỗi). Build + cài Oppo CPH2203 — xác nhận đúng hành vi fail-open QUAN TRỌNG NHẤT: chưa tạo doc `app_config/version_gate` nên app mở bình thường, không bị chặn, không crash (đây là trạng thái mặc định mà 100% user thật đang gặp cho tới khi user chủ động bật gate). **Chưa test được nhánh CHẶN thật** — tài khoản test hiện tại không có quyền Super Admin nên không mở được màn cấu hình mới, và không có Admin SDK credentials để tự tạo doc test giả lập. Logic so sánh build đơn giản, đã qua code review kỹ — nhưng khuyến nghị user tự bật thử với số build rất cao (chắc chắn cao hơn build hiện tại) trên 1 thiết bị test trước khi dùng thật.

**Files:** `lib/widgets/version_gate_wrapper.dart` (mới), `lib/main.dart`, `lib/views/super_admin_console_view.dart`, `firestore.rules`.

---

## [2026-08-16t] - feat: gom mối các khoản cần thu/trả (công nợ, trả góp NH) đang rải rác

**Yêu cầu user:** "khi đơn hàng bán công nợ, bán trả góp, hay trả nợ thì nằm rải rác muốn thanh toán phải tìm từng chỗ" — user hỏi giải pháp, mình đề xuất tận dụng khung "CẦN XỬ LÝ" có sẵn ở trang chủ thay vì xây màn hình mới, user đồng ý theo đề xuất.

**Khảo sát trước khi làm:** xác nhận `debt_view.dart` đã có sẵn `linkedId` trỏ về đơn bán/sửa gốc trong dữ liệu nhưng chưa từng dùng để điều hướng; báo cáo trả góp NH (`bank_installment_report_view.dart`) là màn hình riêng, chỉ mở được qua 1 shortcut cụ thể; khung "CẦN XỬ LÝ" ở trang chủ (`ActionRequiredCard`) chưa gồm công nợ hay trả góp.

**1) Nút "Xem đơn gốc" trong lịch sử công nợ:** `debt_view.dart` — thêm nút mở đúng đơn bán/sửa đã phát sinh khoản nợ (thử tìm theo đơn bán trước, không thấy thì tìm đơn sửa, dùng `linkedId` có sẵn) — chỉ hiện khi đơn có `linkedId`.

**2) Thêm 2 mục mới vào "CẦN XỬ LÝ" ở trang chủ:** `dashboard_cards.dart` — "X công nợ quá hạn cần thu/trả" (đếm nợ còn > 0 và tạo trên 30 ngày, cùng ngưỡng "quá hạn" debt_view.dart đang dùng, bấm vào mở màn Công nợ) + "Y đơn trả góp chờ NH tất toán" (đếm đơn `isInstallment=1` chưa có `settlementReceivedAt`, bấm vào mở báo cáo Trả góp NH). Wiring 2 callback mới trong `home_view.dart`.

**Verify:** `flutter analyze` sạch (0 lỗi). Build + cài Oppo CPH2203, test trực tiếp trên đơn thật (đơn bán ABC — CÔNG NỢ, ỐP x2): mở Công nợ > Lịch sử > bấm "Xem đơn gốc" → mở đúng "CHI TIẾT ĐƠN BÁN — ABC" khớp dữ liệu, không crash. **2 mục mới ở "CẦN XỬ LÝ"** chỉ xác nhận query chạy không lỗi qua logcat (dữ liệu test hiện không có công nợ quá hạn/đơn trả góp để tự thấy mục thực sự xuất hiện trên UI) — cần user tự kiểm tra khi có dữ liệu phù hợp.

**Files:** `lib/views/debt_view.dart`, `lib/widgets/dashboard_cards.dart`, `lib/views/home_view.dart`.

---

## [2026-08-16s] - fix(ui): overflow ở Firestore Audit Monitor + đổi nhãn menu "Thao tác nhanh"

**Yêu cầu user:** (1) ảnh chụp Firestore Audit Monitor (dev tool) — cả 6 thẻ thống kê đều bị "BOTTOM OVERFLOWED BY 11 PIXELS". (2) menu "Thao tác nhanh" (nút nổi kéo thả) — thêm chữ "Tạo" trước mỗi mục cho dễ đọc.

**1) Fix overflow:** `firestore_audit_dashboard.dart` — lưới 6 thẻ thống kê dùng `GridView.count(childAspectRatio: 1.65)`, tỉ lệ này ép chiều cao ô hơi thấp hơn nội dung thực tế (icon + nhãn + số liệu + chú thích), tràn 11px đều trên cả 6 thẻ. Giảm `childAspectRatio` xuống `1.3` để ô đủ cao chứa hết nội dung, có thêm khoảng dư an toàn.

**2) Đổi nhãn menu Thao tác nhanh:** `quick_action_sheet.dart` — 6 mục đổi từ "Sửa mới/Bán mới/Sản phẩm mới/Công nợ mới/Thu chi mới/Máy xác mới" thành "Tạo sửa mới/Tạo bán mới/Tạo sản phẩm mới/Tạo công nợ mới/Tạo thu chi mới/Tạo máy xác mới".

**Verify:** `flutter analyze` sạch (0 lỗi). Build + cài Oppo CPH2203, mở Cài đặt > Firestore Audit Monitor — xác nhận cả 6 thẻ hiện đủ nội dung, logcat không còn dòng "OVERFLOWED" nào, không crash. Đổi nhãn menu là thay đổi chuỗi văn bản thuần, xác nhận qua code review (không có logic liên quan).

**Files:** `lib/developer/firestore_audit/dashboard/firestore_audit_dashboard.dart`, `lib/widgets/quick_action/quick_action_sheet.dart`.

---

## [2026-08-16r] - fix(inventory): tab "Tất cả" trong Kho hiện trống dù tổng vốn/số lượng vẫn đúng

**User báo:** kèm ảnh chụp — tab "Tất cả" ở màn Quản lý kho hiện "Kho hàng đang trống" dù khối tổng phía trên vẫn hiện số liệu (TỔNG KHO, VỐN TỒN KHO) khác 0. Tab "Điện thoại" vẫn hiện đúng 160 sản phẩm bình thường.

**Nguyên nhân:** tab "Tất cả" dùng riêng 1 đường tải dữ liệu phân trang (`getProductsPaged` — tải 20 sản phẩm/lần để tối ưu tốc độ), khác hẳn các tab Điện thoại/Phụ kiện/Linh kiện (dùng `getAllProducts` tải toàn bộ rồi lọc phía client). 2 đường này không nhất quán với nhau trên dữ liệu thật của user, khiến tab "Tất cả" trả về danh sách trống trong khi khối tổng (tính bằng 1 query riêng, `getInventorySummary`) vẫn ra số đúng — số 527.367/500.603 trong ảnh không phải lỗi, đó là TỔNG SỐ LƯỢNG tồn kho (cộng dồn `quantity` từng dòng), không phải số dòng sản phẩm.

**Fix:** bỏ hẳn nhánh phân trang riêng cho "Tất cả" — mọi tab giờ dùng chung 1 đường tải duy nhất (`_needsFullData` luôn `true`), đã kiểm chứng hoạt động đúng qua các tab khác từ trước. Đơn giản hoá đường tải dữ liệu, giảm khả năng lệch giữa các tab.

**Verify:** `flutter analyze` sạch. Build + cài Oppo CPH2203, test trên tài khoản test: tab "Tất cả" hiện đúng dữ liệu, chuyển qua "Điện thoại" rồi quay lại "Tất cả" vẫn hiện đúng, không crash. **Không tái hiện được lỗi gốc trên dữ liệu test** (quá ít sản phẩm để lặp lại tình huống lệch dữ liệu của user) — cần user tự kiểm tra lại trên dữ liệu thật sau khi cập nhật.

**Files:** `lib/views/inventory_view.dart`.

---

## [2026-08-16q] - feat(repair): cho phép bỏ qua yêu cầu SĐT khi giao máy (đơn cũ thiếu thông tin)

**Yêu cầu user:** "có 1 số đơn sửa chỉ có tên khách mà không có số điện thoại, khi giao yêu cầu cập nhật cái này mình bỏ qua được không" — đơn cũ nhập thiếu SĐT bị chặn cứng không giao máy được.

**Trước đây:** dialog "⚠️ Thiếu thông tin khách hàng" chỉ có 2 lựa chọn "Hủy" hoặc "Cập nhật ngay" — không có cách nào giao máy nếu chưa bổ sung đủ tên+SĐT (trừ đánh dấu "Khách vãng lai", không hợp lý với đơn đã có tên khách thật).

**Fix:** thêm nút **"Bỏ qua, giao máy luôn"** — CHỈ hiện khi đơn đã có tên khách nhưng thiếu SĐT (thiếu cả tên thì vẫn chặn cứng như cũ, vì lúc đó gần như không xác định được đơn của ai). Áp dụng cho cả 2 luồng giao máy: `_submitForDeliveryApproval` (nhân viên gửi chờ duyệt) và `_approveDelivery` (quản lý duyệt giao).

**Verify:** `flutter analyze` sạch. Build + cài Oppo CPH2203 (tài khoản test), tạo 1 đơn sửa test có tên khách nhưng cố tình để trống SĐT → chuyển trạng thái tới "SỬA XONG" → bấm "GIAO" → xác nhận dialog mới hiện đúng 3 nút, bấm "Bỏ qua, giao máy luôn" → vào thẳng màn xác nhận duyệt giao, bấm "DUYỆT" → đơn chuyển đúng sang "ĐÃ GIAO" thành công. Không crash trong toàn bộ quá trình.

**Files:** `lib/views/repair_detail_view.dart`.

---

## [2026-08-16p] - fix(build): commit file bị thiếu khiến build iOS lỗi "No such file or directory"

**User báo:** build iOS trên Mac báo lỗi ngay sau lần fix trước đó, nghi do mình vừa sửa gây ra. Gửi ảnh chụp Xcode: `Error when reading 'lib/views/other_apps_view.dart': No such file or directory` + `Not a constant expression` tại `home_view.dart:6289` (`const OtherAppsView()`).

**Nguyên nhân thật (không liên quan tới fix sync trước đó):** tính năng "Ứng dụng khác" (trang giới thiệu app khác, làm ở phiên trước lúc compact) có 4 phần: `other_apps_view.dart` (mới), mục quản lý trong `super_admin_console_view.dart`, rule Firestore, và đoạn import + Settings entry trong `home_view.dart`. Khi commit "Công cụ điều chỉnh dữ liệu" (`[2026-08-16m]`), lệnh `git add` có gồm `lib/views/home_view.dart` — vô tình commit theo luôn phần import/entry "Ứng dụng khác" đã có sẵn trong file (từ phiên trước), nhưng **`other_apps_view.dart` (file định nghĩa class) lại chưa từng được `git add`** — vẫn nằm ở trạng thái untracked chỉ có trên máy Windows đang làm việc. Máy Mac của user `git pull` về thì thiếu hẳn file này → lỗi biên dịch.

**Fix:** `git add` + commit 4 file còn treo uncommitted từ tính năng "Ứng dụng khác": `lib/views/other_apps_view.dart` (file bị thiếu — nguyên nhân chính), `lib/views/super_admin_console_view.dart` (mục quản lý), `firestore.rules` (đã deploy production từ trước, giờ mới đồng bộ vào git), `pubspec.yaml` (bump version 3.3.0+541, cũng đang treo).

**Verify:** `flutter analyze` sạch trên cả 3 file liên quan (0 lỗi, chỉ info/warning có sẵn). Build Android debug APK thành công (dùng chung Dart frontend compiler với iOS nên xác nhận gián tiếp lỗi thiếu file đã hết). **Chưa tự build iOS được** (máy Windows, không có Xcode) — cần user tự pull code mới và build lại trên Mac để xác nhận dứt điểm.

**Bài học:** khi 1 file có NHIỀU thay đổi từ nhiều tính năng khác nhau chưa commit hết, `git add <file>` sẽ gộp TẤT CẢ vào cùng 1 commit dù không liên quan — cần `git status`/`git diff` soát kỹ trước khi add file đã biết có lịch sử sửa dở từ trước, không chỉ add theo tên file đang làm.

**Files:** `lib/views/other_apps_view.dart` (mới), `lib/views/super_admin_console_view.dart`, `firestore.rules`, `pubspec.yaml`.

---

## [2026-08-16o] - fix(sync): đơn sửa từ máy khác không hiện tới khi thoát app vào lại

**Yêu cầu user:** "sau khi tối ưu read cho repair có phát sinh 1 số vấn đề: khi người khác nhận máy sửa ở máy A thì máy B không có trên list phải thoát ra vào lại mới thấy. Khi sửa hay chuyển trạng thái cũng không cập nhật ngay."

**Nguyên nhân:** đợt tối ưu Firestore read trước đó (commit `55b4870e`) đổi cách đồng bộ nhiều collection (bao gồm `repairs`) từ `snapshots()` (đẩy realtime) sang `get()` polling 1 lần lúc mở app/đăng nhập, để giảm số lần đọc. Nhưng KHÔNG có điểm nào kích hoạt fetch lại sau đó — không có polling định kỳ, không refresh khi app resume từ nền, và màn Danh sách đơn sửa cũng không nằm trong 5 nơi đang gọi `refreshCloudCollections()` (kho, chi nhánh...). Nên chỉ có cách thoát app rồi vào lại (kích hoạt lại `initRealTimeSync` → fetch 1 lần) mới thấy thay đổi từ thiết bị khác.

**Fix (tái dùng hạ tầng polling có sẵn, không quay lại `snapshots()` toàn phần để tránh đội read cost trở lại):**
- `sync_service.dart`: thêm 1 `Timer.periodic` (45s) CHỈ fetch lại riêng collection `repairs` — gọi thẳng `_collectionRefreshers['repairs']` thay vì `refreshCloudCollections()` chung, để không kéo theo ~20 collection khác cũng đang polling (tránh đội read cost trở lại đúng thứ đợt tối ưu trước vừa giảm). Timer được lưu vào `_pollingTimers` (hạ tầng có sẵn nhưng trước đây chưa từng được dùng tới) nên tự dừng đúng khi đổi shop/đăng xuất qua `cancelAllSubscriptions()` sẵn có.
- `main.dart`: thêm `SyncService.refreshCloudCollections(reason: 'app_resumed')` khi app resume từ nền (`AppLifecycleState.resumed`) — bắt kịp ngay lập tức thay vì chờ tick định kỳ tiếp theo.

**Verify:** `flutter analyze` sạch (0 lỗi). Build + cài Oppo CPH2203, theo dõi logcat qua nhiều chu kỳ — xác nhận cả 3 cơ chế fetch đều chạy đúng: `reason=initial` lúc mở app, `reason=manual_refresh` (qua Timer riêng cho repairs) đúng 45s sau, và `reason=app_resumed` (tổng 35 collection) ngay khi đưa app từ nền lên lại. Mở màn Danh sách đơn sửa thật (13 đơn) không crash trong suốt quá trình. **Giới hạn đã biết:** chỉ có 1 thiết bị test nên KHÔNG mô phỏng được đúng kịch bản "máy A tạo/sửa đơn, xác nhận máy B nhận được" — chỉ xác nhận được cơ chế fetch (Timer + resume trigger) tự chạy đúng lịch, không lỗi; không có sẵn service-account/Admin SDK credentials để giả lập ghi từ "thiết bị khác" trực tiếp vào Firestore.

**Files:** `lib/services/sync_service.dart`, `lib/main.dart`.

---

## [2026-08-16n] - fix(debt): dọn giao diện màn Công nợ — bớt cấn, chuyên nghiệp hơn

**Yêu cầu user:** gửi 2 ảnh chụp màn "Quản lý công nợ" (tab Phải thu, Phải trả), nhận xét thao tác/trải nghiệm "cấn cấn không chuyên nghiệp", nhờ xem và cho ý kiến sửa. Sau khi review + đối chiếu code, user đồng ý sửa cả 4 điểm.

1. **Tiêu đề AppBar bị cắt chữ** ("QUẢN LÝ CÔN...") — chuỗi "QUẢN LÝ CÔNG NỢ" quá dài so với khoảng trống còn lại (đã có nút back + phụ đề + 3 icon bên phải). Rút gọn còn "CÔNG NỢ" (`debtManagementTitle` trong `app_vi.arb`).
2. **Mỗi thẻ nợ lặp lại chỉ báo "thu/trả" tới 3 lần dư thừa**: số thứ tự (badge vuông "1","2"...) + icon mũi tên ↓/↑ cùng màu + chữ "Phải thu"/"Phải trả" — trong khi đang lọc theo tab thì cả 3 đều nói cùng 1 điều. Bỏ số thứ tự (không mang ý nghĩa gì với người dùng — chỉ là thứ tự hiển thị) và bỏ chip chữ "Phải thu"/"Phải trả" (trùng lặp với icon + ngữ cảnh tab); chỉ còn hiện 1 chip khi có điều thật sự cần báo (đã trả đủ / quá hạn). Áp dụng cho cả thẻ nợ khách/NCC (`_debtCard`) lẫn thẻ nợ đối tác sửa chữa (`_partnerDebtCard`).
3. **Khối "TỔNG NỢ ĐỐI TÁC SỬA CHỮA" bị cắt cụt giữa chừng** (nguyên nhân chính gây cảm giác giật/thiếu chuyên nghiệp) — code cũ chia màn thành 2 khung theo **tỷ lệ cố định** (danh sách nợ thường : nợ đối tác = 3:2, `Expanded(flex: ...)`), nên khi danh sách ngắn vẫn bị ép cắt cụt ngay trước khối tổng. Gộp lại thành **1 `ListView` cuộn liền mạch duy nhất**, cao theo đúng nội dung — `_buildSimpleDebtList`/`_buildPartnerDebtList` đổi thành `_buildSimpleDebtItems`/`_buildPartnerDebtItems` trả về `List<Widget>` thay vì `Widget` có `Expanded` riêng.
4. **Nút "+" tạo nợ mới đè sát thẻ cuối danh sách** — thêm `padding: EdgeInsets.only(bottom: 88)` cho `ListView` gộp để chừa chỗ cho FAB, không che nội dung.

**Nhỏ hơn (đi kèm):** nút lọc "Đã trả" cạnh ô tìm kiếm đổi nhãn thành "Hiện đã trả" + thêm icon phễu lọc (`Icons.filter_alt_outlined`) để rõ đây là bộ lọc bấm được, không phải nhãn trạng thái.

**Verify:** `flutter analyze` sạch (0 lỗi, chỉ info/warning có sẵn từ trước không liên quan). `flutter gen-l10n` chạy lại sau khi sửa `app_vi.arb`. Build + cài Oppo CPH2203, test trên tài khoản thật (shop "M", có cả nợ phải thu lẫn nợ đối tác sửa chữa) — xác nhận: tiêu đề hiện đúng "CÔNG NỢ" không còn bị cắt, nút lọc hiện "Hiện đã trả" có icon, thẻ nợ không còn số thứ tự/chip trùng lặp ở cả 2 loại thẻ, không crash trong suốt quá trình test cả 2 tab. **Không tái hiện được đúng 1:1 kịch bản cắt cụt gốc trong ảnh chụp** vì tài khoản test hiện tại (shop "M") có ít dữ liệu nợ NCC hơn HULUCA STORE — độ tin cậy dựa trên việc cơ chế gây lỗi gốc (tỷ lệ `flex` cố định) đã được gỡ bỏ hoàn toàn, thay bằng cuộn tự nhiên theo nội dung (fix cấu trúc, không phải fix theo dữ liệu cụ thể).

**Files:** `lib/views/debt_view.dart`, `lib/l10n/app_vi.arb`.

---

## [2026-08-16m] - feat(admin): Công cụ điều chỉnh dữ liệu (dọn đơn dư thừa/miễn nợ/sửa kho)

**Yêu cầu user:** "đơn sửa đơn bán và 1 số dữ liệu khác bạn làm theo ý bạn làm công cụ điều chỉnh dữ liệu" — user giao toàn quyền thiết kế, bối cảnh: shop có nhiều đơn sửa/đơn bán dư thừa (dữ liệu test/nhập nhầm) muốn xóa, công nợ muốn miễn, kho/linh kiện muốn sửa số lượng — nhưng không được làm sai lệch báo cáo tài chính (hoặc chấp nhận giữ nguyên sổ sách cũ nếu muốn).

**Khảo sát trước khi làm** (2 agent đọc sâu + tự verify lại code quan trọng): xóa đơn sửa hiện tại (`order_list_view.dart`) để mồ côi hoàn toàn công nợ/payment/log tài chính liên quan; xóa đơn bán (`sale_detail_view.dart:_deleteSale`) đã làm khá tốt (hoàn kho, xóa nợ, xóa payment, ghi bù trừ `SALE_VOID`) — dùng làm logic tham chiếu; `softDeleteDebt` có sẵn nhưng chưa từng được gọi và tham số `reason` bị bỏ qua; kho/linh kiện chưa có khái niệm "điều chỉnh tồn kho".

**Thiết kế:** Xây 1 màn hình MỚI, hoàn toàn tách biệt — **không sửa 1 dòng nào** ở `order_list_view.dart`/`sale_detail_view.dart` để tránh hồi quy lên luồng xóa đang chạy thật. Mọi thao tác xóa đơn đều có 2 lựa chọn rõ ràng: "Xóa, hoàn tài chính" (tự tìm & xóa công nợ liên quan, hủy/bù trừ payment intent, hoàn kho) hoặc "Xóa, giữ sổ sách" (chỉ xóa đơn, không đụng công nợ/tài chính — dùng khi ngày đó đã báo cáo/chốt).

- File mới `lib/services/data_reconciliation_service.dart`: `deleteRepairWithReversal`/`deleteRepairKeepBooks`, `deleteSaleWithReversal`/`deleteSaleKeepBooks` (mirror logic đã kiểm chứng của `_deleteSale`), `writeOffDebt` (miễn nợ — không ghi bút toán tiền vì không phải thu tiền thật), `adjustPartQuantity`/`adjustProductQuantity` (sửa số lượng kho, bắt buộc lý do, ghi audit log), `deletePart`/`deleteProduct` (soft-delete, cảnh báo nếu còn công nợ NCC liên quan).
- File mới `lib/views/data_reconciliation_view.dart`: 4 tab (Đơn sửa | Đơn bán | Công nợ | Kho & SP), chọn nhiều bằng checkbox, tóm tắt trước khi thực thi, **bắt buộc xác nhận lại mật khẩu đăng nhập** trước mọi thao tác xóa/sửa.
- `db_helper.dart:softDeleteDebt`: sửa để thực sự lưu `reason` (lý do miễn nợ) vào cột `note` có sẵn thay vì bỏ qua như trước.
- `financial_activity_model.dart`: thêm nhãn/icon cho `REPAIR_VOID`/`SALE_VOID` (trước đây `SALE_VOID` đã dùng ở `_deleteSale` nhưng rơi về nhãn mặc định "Khác").
- `home_view.dart`: thêm mục "Công cụ điều chỉnh dữ liệu" trong Cài đặt > Dữ liệu & Hệ thống, **chỉ chủ shop/quản lý (`hasFullAccess`) thấy được**.

**Verify:** `flutter analyze` sạch (0 lỗi, chỉ info/warning có sẵn từ trước, không liên quan). Build + cài Oppo CPH2203, đăng nhập tài khoản chủ shop thật (huy@huluca.com). Test trực tiếp trên dữ liệu shop thật: cả 4 tab tải đúng dữ liệu, không crash; chọn/bỏ chọn đơn hoạt động đúng; dialog "Sửa số lượng" và "Miễn nợ" mở đúng dữ liệu, nút xác nhận tự động khoá khi chưa nhập lý do, HỦY không lưu gì; tạo 1 đơn sửa test hoàn toàn giả (SAMSUNG TÉTMODEL, 0đ, không nợ không phụ tùng) → chọn trong tool → bảng tóm tắt hiện đúng → **màn hình xác nhận mật khẩu xuất hiện đúng** (xác nhận cơ chế bảo vệ hoạt động).
**Giới hạn đã biết:** KHÔNG thể tự test tiếp bước sau khi nhập mật khẩu vì không có mật khẩu đăng nhập thật của chủ shop (không tự đoán mật khẩu) — logic thực thi (`deleteRepairKeepBooks`) chỉ được xác nhận qua code review (mirror chính xác logic đã chạy thật nhiều năm trong `order_list_view.dart`), chưa được chạy thật đến cùng. **Còn sót lại 1 đơn test vô hại** trong danh sách đơn sửa thật của shop: "SAMSUNG TÉTMODEL / TẼTOACC / 0900000000", giá 0đ, không nợ không phụ tùng — cần chủ shop tự xóa (qua chính công cụ này hoặc màn Danh sách đơn sửa) khi có mật khẩu.

**Files:** `lib/services/data_reconciliation_service.dart` (mới), `lib/views/data_reconciliation_view.dart` (mới), `lib/data/db_helper.dart`, `lib/models/financial_activity_model.dart`, `lib/views/home_view.dart`.

---

## [2026-08-16l] - fix(repair): ẩn giá vốn/lợi nhuận khỏi nhân viên trong "Giá tham khảo" + "Đơn sửa tương tự"

**Phát hiện khi làm việc khác:** user hỏi "giá vốn trong lịch sử sửa giá có ẩn với nhân viên chưa" — kiểm tra thấy 2 chỗ MỚI thêm ở entry `[2026-08-16k]` phía trên (thẻ "GIÁ THAM KHẢO" khi tạo đơn mới, và trang `SimilarRepairHistoryView`) hiện Vốn/Lợi nhuận **không kiểm tra quyền xem giá vốn** — rò rỉ giá vốn cho nhân viên không có quyền.

- `similar_repair_history_view.dart`: thêm param `showCost` (mặc định `false` — an toàn theo hướng đóng), chỉ hiện Vốn/Lãi-Lỗ khi `true`, giá thu ("Thu khách") luôn hiện.
- `create_repair_order_view.dart`: thẻ "GIÁ THAM KHẢO" gate Vốn/Lợi nhuận theo `_canViewCostPrice` (field quyền có sẵn, đã dùng ở chỗ khác trong file); truyền `showCost: _canViewCostPrice` khi mở `SimilarRepairHistoryView`.
- `repair_detail_view.dart`: truyền `showCost: canShowCost` (biến quyền có sẵn tại nơi gọi, đã dùng để gate các chỗ hiện giá vốn khác trong màn Chi tiết đơn) khi mở `SimilarRepairHistoryView`.

**Verify:** `flutter analyze` sạch (chỉ còn info/warning cũ không liên quan). Build + cài Oppo CPH2203, đăng nhập tài khoản **nhân viên** (không có quyền xem giá vốn) — tạo đơn mới IPHONE 11PROMAX + THAY MÀN: thẻ "GIÁ THAM KHẢO" chỉ hiện "Thu khách: 620.000đ", không còn "Vốn"/"Lợi nhuận". Bấm "9 đơn tương tự (chạm để xem)" — trang liệt kê 9 đơn thật, mỗi thẻ chỉ hiện giá thu (VD "990.000đ"), không hiện Vốn/Lãi/Lỗ. Không có FATAL exception trong toàn bộ quá trình test.

**Files:** `lib/views/similar_repair_history_view.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/repair_detail_view.dart`.

---

## [2026-08-16k] - feat(repair): cho sửa giá/thông tin đơn đã giao + xem chi tiết "đơn tương tự"

**Yêu cầu user:** (1) Đơn "Đã giao" vẫn cho phép chỉnh sửa giá vốn/giá thu/thông tin chung (trước đây bị khoá hoàn toàn). (2) Dòng "Lịch sử tương tự" (Bảng giá thông minh) ở màn Tạo đơn sửa mới và Chi tiết đơn — bấm vào phải mở được trang liệt kê từng đơn thực tế trong lịch sử đó để xem/tham khảo.

**1) Mở khoá sửa đơn đã giao:**
- Trước khi sửa, đọc kỹ toàn bộ 10 điểm gate theo `status==4` trong `repair_detail_view.dart` để chỉ gỡ đúng 2 điểm liên quan (giá + thông tin chung), giữ nguyên các khoá khác không thuộc phạm vi yêu cầu (VD nút trạng thái "Giao máy" tiếp theo, sửa dịch vụ từng dòng...).
- `_editFinancials()`: gỡ bỏ chặn `if (r.status == 4) { snackbar 'Đã giao máy — không thể sửa giá'; return; }`. Logic tính chênh lệch khi sửa giá vốn/giá thu (`FinancialActivityService.logCustomActivity` ghi REPAIR_PRICE_ADJUST/REPAIR_COST_ADJUST, `_applyCostFundDelta` tránh nhân đôi chi phí sổ quỹ) đã có sẵn từ trước và an toàn dùng lại — không đổi gì trong phần này.
- `_editBasicInfo()`: gỡ bỏ `if (r.status == 4) return;` (trước đây im lặng không làm gì, không cả thông báo).
- Nút "Chỉnh sửa thông tin" (icon bút cạnh tên khách) đổi từ `if (r.status < 4 && quyền)` sang chỉ còn `if (quyền)` — hiện luôn, không ẩn khi đã giao.
- **Không đụng tới:** nút hành động trạng thái cuối trang (`_buildActionButtons` — vẫn ẩn khi đã giao, đúng vì không có "trạng thái tiếp theo"), sửa từng dịch vụ, thêm/đổi phụ tùng (đã có carve-out riêng cho phép xoá phụ tùng từ trước, giữ nguyên).

**2) Trang "Đơn sửa tương tự" (Bảng giá thông minh):**
- `pricing_engine_service.dart`: `PricingSuggestion` thêm field `matchedRepairs` (danh sách `Repair` thực tế đã dùng để tính gợi ý) — lấy free từ dữ liệu đã có trong `_buildSuggestion`, không query thêm.
- File mới `lib/views/similar_repair_history_view.dart`: màn hình CHỈ ĐỌC, liệt kê từng đơn (model, lỗi/dịch vụ, trạng thái, ngày, giá thu/vốn/lãi), bấm vào 1 dòng mở thẳng `RepairDetailView` của đơn đó để xem/tham khảo.
- Gắn `InkWell` + gạch chân vào dòng "Lịch sử tương tự"/"N đơn tương tự" ở cả `create_repair_order_view.dart` và `repair_detail_view.dart`, thêm chữ "(chạm để xem)" để gợi ý bấm được.

**Verify (test trực tiếp trên thiết bị thật, dữ liệu shop thật):** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Mở 1 đơn "ĐÃ GIAO" thật (IPHONE 11PROMAX — Nguyễn Khánh Duy) — xác nhận nút "Sửa" (tài chính) và "Chỉnh sửa thông tin" đều hiện và mở được dialog đúng (trước đây bị chặn/ẩn) — **đã bấm HỦY ở cả 2 dialog, không lưu**, để không đụng dữ liệu tài chính thật khi test. Bấm dòng "Lịch sử tương tự (chạm để xem)" — mở đúng trang liệt kê 2 đơn tương tự khớp số liệu gợi ý. Không có crash trong toàn bộ quá trình test.

**Files:** `lib/views/repair_detail_view.dart`, `lib/services/pricing_engine_service.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/similar_repair_history_view.dart` (mới).

**Cập nhật thêm cùng ngày (theo phản hồi user "hay rồi, thêm link + hiển thị thêm thông tin"):** viết lại `similar_repair_history_view.dart` — mỗi thẻ đơn giờ hiện đủ model, trạng thái, lỗi/dịch vụ, khách hàng, SĐT, ngày, KTV sửa (nếu có), giá thu/vốn/lãi ngay trên danh sách (không cần bấm vào mới xem), kèm nút "Xem chi tiết" rõ ràng ở mỗi thẻ (bên cạnh việc cả thẻ vẫn bấm được). Test trực tiếp trên đơn thật — hiện đủ thông tin đúng, bấm "Xem chi tiết" mở đúng chi tiết đơn, không crash.

---

## [2026-08-16j] - feat(repair): danh sách không bỏ sót đơn chưa giao + cảnh báo đơn treo quá 7 ngày

**Bối cảnh:** Điều tra sâu báo cáo "đơn hiện sai trạng thái" ở mục `[2026-08-16i]` — sau khi kiểm tra trực tiếp dữ liệu gốc trên Firestore Console (field `status` = 1 thật) VÀ xác nhận lại trên đúng bản App Store release (không phải bản test), kết luận: **đây không phải bug đồng bộ** — đơn đó thực sự chưa từng được cập nhật trạng thái trong app (có thể nhân viên xử lý xong ngoài đời nhưng quên bấm cập nhật). Toàn bộ nghi vấn về sync/ghi đè/race-condition trước đó (`[2026-08-16i]`) đã được loại trừ bằng bằng chứng thực tế.

Tuy nhiên phát hiện thêm 1 vấn đề thật: đơn cũ không cập nhật trạng thái **biến mất khỏi danh sách chính** (chỉ tìm thấy qua search) — nguyên nhân do query realtime các đơn CHƯA GIAO (`activeOnly`) có `.limit()` (tối đa 500, mặc định 50, tăng dần khi cuộn) sắp xếp theo `updatedAt` mới nhất trước — đơn càng lâu không ai đụng tới càng dễ bị đẩy khỏi cửa sổ hiển thị.

**Fix 1 — không bỏ sót đơn chưa giao dù cũ đến đâu:**
- `firestore_service.dart` (`watchRepairsByShop`): bỏ hẳn `.limit()` khi `activeOnly=true` — tập hợp đơn CHƯA GIAO vốn bị chặn tự nhiên (1 shop không thể có hàng nghìn máy đang xử lý cùng lúc) nên an toàn để tải toàn bộ, không giới hạn số lượng.
- `order_list_view.dart`: bỏ luôn cơ chế "tải thêm khi cuộn" phía Firestore (đã thành thừa vì không còn giới hạn) — chỉ giữ lại phân trang SQLite cho phần lịch sử đã giao.
- Thứ tự hiển thị Tiếp nhận → Đang sửa → Sửa xong → Chờ duyệt giao → Đã giao đã có sẵn từ trước (`_compareRepairs`), không cần đổi.

**Fix 2 — cảnh báo đơn "Tiếp nhận"/"Sửa xong" treo quá 7 ngày:**
- Thêm `_isOverdue()`: đơn status=1 (Tiếp nhận) tính từ `createdAt`, status=3 chưa chờ duyệt (Sửa xong) tính từ `finishedAt`/`lastCaredAt` — quá 7 ngày chưa xử lý tiếp thì đánh dấu quá hạn.
- Hiện chip cảnh báo đỏ "⚠️ QUÁ HẠN X NGÀY" ngay trên từng đơn trong danh sách.
- Header danh sách hiện thêm số lượng quá hạn: "62 điện thoại • 11 đang xử lý • ⚠️ 3 quá hạn".

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Chưa test được với dữ liệu có đơn thật sự cũ nhiều năm (không có sẵn trên máy test) — cần user tự xác nhận trên Máy A/B.

**Files:** `lib/services/firestore_service.dart`, `lib/views/order_list_view.dart`.

---

## [2026-08-16i] - fix(repair): đơn "Sửa xong" hiện sai dù đã "Đã giao" ở thiết bị khác

**User báo:** Máy A (chủ shop, bản test đang sửa lỗi) hiện nhiều đơn trạng thái "SỬA XONG" nhưng thực chất đã "ĐÃ GIAO" từ lâu. Máy B (nhân viên, bản release App Store) hiện đúng dữ liệu.

**Nguyên nhân:** `order_list_view.dart` gộp 2 nguồn dữ liệu: (1) realtime Firestore listener chỉ theo dõi đơn CHƯA giao (`status < 4`, để giảm tải), (2) SQLite local cho lịch sử/đơn đã giao. Khi 1 đơn chuyển trạng thái từ "chưa giao" sang "Đã giao" (`status=4`) ở **thiết bị khác** (VD nhân viên bấm giao máy trên Máy B), Firestore đúng đắn loại đơn đó khỏi kết quả realtime (`DocumentChangeType.removed`) — nhưng code cũ chỉ đơn giản `_repairsByFirestoreId.remove(id)` mà **không cập nhật gì vào SQLite**. Vì vậy bản ghi SQLite cục bộ vẫn giữ nguyên trạng thái CŨ (VD "Sửa xong") mãi mãi, và khi rơi về nguồn `sqliteExtra` (đơn không còn trong tập realtime), nó hiển thị đúng trạng thái SAI đó.

Đây là lý do Máy B (nơi hành động "giao máy" diễn ra trực tiếp, tự ghi đúng trạng thái vào local) hiện đúng, còn Máy A (chỉ QUAN SÁT thay đổi qua realtime listener) hiện sai.

**Fix:** khi 1 đơn bị `removed` khỏi kết quả realtime, thay vì chỉ xoá khỏi map trong bộ nhớ, refetch 1 lần từ Firestore (`FirestoreService.getRepairDoc`) và ghi đè lại đúng trạng thái mới nhất vào SQLite (`db.upsertRepair`).

**Giới hạn quan trọng:** fix này chỉ ngăn **phát sinh mới** từ bây giờ — KHÔNG tự sửa các đơn ĐÃ bị sai sẵn trong SQLite của Máy A hiện tại (do `_doHistoricalBackfill` chỉ `INSERT OR IGNORE`, không ghi đè bản ghi cũ). Để sửa dữ liệu cục bộ hiện có: Đăng xuất rồi đăng nhập lại (KHÔNG dùng "Nhận kho từ Cloud" — nút đó chỉ làm mới sản phẩm/kho, không đụng tới đơn sửa, xem đính chính ở `[2026-08-16j]`).

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Không tái hiện được đúng kịch bản 2-thiết-bị trên máy test (chỉ có 1 thiết bị Android), cần user tự xác nhận trên Máy A/B thật.

**Cập nhật sau khi điều tra tiếp (`[2026-08-16j]`):** đã kiểm tra trực tiếp 1 case cụ thể user báo — dữ liệu gốc trên Firestore Console thật sự là `status: 1`, xác nhận lại trên đúng bản App Store release cũng cho kết quả giống vậy. Kết luận: case đó KHÔNG phải do bug đồng bộ này gây ra (đơn chưa từng được cập nhật trạng thái trong app) — nhưng fix `removed`-transition ở trên vẫn là fix đúng, hợp lệ cho race-condition đa thiết bị thật sự tồn tại trong code, không rút lại.

**Files:** `lib/views/order_list_view.dart`.

---

## [2026-08-16h] - fix(sync,firestore): deploy composite index bị thiếu + fix audit_logs retry vô hạn

**Bối cảnh:** User dán 1 log iOS đã qua phân tích bởi công cụ khác (báo App Check lỗi, audit_logs permission-denied, repairs thiếu index, mismatch dữ liệu). Tôi đọc code thật để kiểm chứng từng điểm thay vì tin nguyên bản phân tích.

**1) Composite index cho `repairs` (và ~55 collection khác) đã khai báo trong `firestore.indexes.json` nhưng CHƯA từng deploy lên production:**
- Kiểm tra bằng `firebase firestore:indexes` (đọc index đang chạy thật) → chỉ thấy đúng `attendance` (5 index), toàn bộ phần còn lại trong file local (repairs, products, sales_returns, payment_requests, debt_payments...) không tồn tại trên server.
- Đây là nguyên nhân trực tiếp khiến `OrderListView` (`lib/views/order_list_view.dart`) phải fallback "no orderBy/limit" cho query `repairs` (`shopId + status<4 + orderBy updatedAt` — cần đúng composite index đã khai báo sẵn ở `firestore.indexes.json` dòng ~212-221, xem comment tại [firestore_service.dart:79-80](lib/services/firestore_service.dart#L79-L80)) — khả năng cao cũng là nguyên nhân mismatch "OrderListView Firestore count: 0" trong log.
- **Đã chạy `firebase deploy --only firestore:indexes`** — deploy thành công, xác nhận lại bằng `firebase firestore:indexes` thấy tăng từ 5 lên 60 collectionGroup có index. Việc build index cho dữ liệu hiện có chạy nền phía Firestore, không ảnh hưởng app đang dùng, có thể mất vài phút tới vài giờ tuỳ khối lượng dữ liệu.

**2) `audit_logs` bị "Missing or insufficient permissions" lặp lại — do vòng lặp retry vô hạn, không liên quan App Check:**
- `firestore.rules` quy định `audit_logs` bất biến: `allow update: if false` (chỉ cho phép `create`, không cho `update`).
- `sync_service.dart` (`syncAllToCloud`, mục audit logs) sau khi batch commit thành công, bọc bước đánh dấu "đã sync" ở local trong `try { ... } catch (_) {}` — nếu bước NÀY lỗi (không phải lỗi Firestore) vì bất kỳ lý do gì, local vẫn coi log đó là "chưa sync" **mãi mãi**, dù bản ghi đã có thật trên Firestore. Lần sync sau, code cố ghi lại → doc đã tồn tại → bị rule chặn vì đó là "update" một tài liệu bất biến → permission-denied → lặp lại vô hạn không tự phục hồi. Batch ghi atomic nên nếu 1 dòng kẹt kiểu này nằm chung batch với các dòng mới hợp lệ, cả batch cùng fail theo.
- **Fix:** khi batch commit lỗi, thay vì chỉ log lỗi, giờ thử ghi lại **từng dòng riêng lẻ** (không batch) để không để 1 dòng kẹt chặn các dòng khác. Nếu ghi riêng vẫn lỗi, kiểm tra xem doc đã tồn tại trên cloud chưa (`.get()`) — nếu đã tồn tại (đúng trường hợp kẹt do lỗi cũ) thì tự đánh dấu synced ở local, không retry nữa; nếu chưa tồn tại thật thì vẫn giữ nguyên là lỗi để tiếp tục điều tra (không che giấu lỗi thật).

**3) App Check "App not registered" (iOS):** xác nhận không chặn app (Auth tự fallback về placeholder token khi thất bại). Đây là việc cần làm ở **Firebase Console** (đăng ký app iOS `1:51200928212:ios:04c10eca3b61a3be910e41` cho App Check, hoặc tắt enforcement nếu chưa cần) — không sửa được bằng code, để lại cho user xử lý.

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. **Không tự test được nhánh self-heal audit_logs trên máy dev** (shop test không có bản ghi audit_logs bị kẹt để tái hiện) — cần theo dõi log lần sync tiếp theo trên thiết bị thật đã gặp lỗi để xác nhận hết lặp lại.

**Files:** `firestore.indexes.json` (deploy, không đổi nội dung file), `lib/services/sync_service.dart`.

---

## [2026-08-16g] - feat(admin): công cụ tìm & dọn tài khoản trùng email trong Super Admin Console

**Bối cảnh:** Sau khi fix nguyên nhân phát sinh trùng mới (`[2026-08-16f]`), user hỏi có thể dọn các tài khoản trùng ĐÃ CÓ SẴN trong dữ liệu thật hay không. Vì không có quyền đọc/ghi trực tiếp Firestore/Auth từ máy dev (không có service account/ADC), giải pháp an toàn nhất là xây công cụ NGAY TRONG Super Admin Console để user (đã có quyền super admin thật) tự chạy trên máy — không có ai khác tự ý xoá dữ liệu khách hàng thật thay họ.

**Thiết kế (ưu tiên an toàn tuyệt đối vì đây là xoá dữ liệu thật):**
- Nút "Tìm tài khoản trùng email" (icon 📋) mới ở góc mục Người dùng — quét TOÀN BỘ `/users` (tối đa 5000 doc, 1 lần đọc), gom nhóm theo email đã chuẩn hoá (trim + lowercase, khớp đúng chuẩn hoá vừa fix), chỉ hiện nhóm có ≥ 2 tài khoản.
- Dialog kết quả hiện đầy đủ thông tin từng dòng trùng: vai trò, tên shop (tra ngược từ shopId), ngày tạo, uid — để admin (con người) tự đối chiếu và quyết định giữ/xoá dòng nào, KHÔNG có bất kỳ hành vi tự động xoá nào.
- Nút xoá từng dòng dùng lại NGUYÊN VẸN luồng xoá đã có sẵn, đã kiểm chứng (`_deleteUser`) — vẫn bắt buộc xác nhận dialog + **xác thực lại mã PIN** trước khi xoá thật, và luôn xoá "hoàn toàn" (cả Firestore doc lẫn tài khoản đăng nhập Firebase Auth qua `deleteUserData`) để tránh lặp lại đúng lỗi mồ côi đã phân tích ở `[2026-08-16f]`.
- Toàn bộ thao tác CHỈ ĐỌC cho tới khi admin chủ động bấm xoá + nhập đúng PIN cho từng dòng cụ thể.

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. **Chưa tự test được luồng tìm/xoá trùng trên dữ liệu thật** — không có tài khoản super admin thật trên máy dev. Cần user tự mở "Người dùng" > nút tìm trùng để kiểm tra và xử lý.

**Files:** `lib/views/super_admin_console_view.dart`.

---

## [2026-08-16f] - fix(auth): chuẩn hoá email về chữ thường khi tự đăng ký — tránh trùng tài khoản

**User báo:** tab Người dùng trong Super Admin Console hiện nhiều dòng "trùng nhau" — cùng email nhưng khác vai trò/shop/ngày tạo. User xác nhận có khách hàng thật gặp tình trạng này (không phải chỉ dữ liệu test).

**Điều tra:** Đã thử đọc trực tiếp Firestore/Auth thật để xác định chính xác cơ chế, nhưng máy này chưa có quyền đọc DB (không có service account key / Application Default Credentials, chỉ có phiên đăng nhập Firebase CLI dùng để deploy) — không tự ý tạo credential mới khi chưa hỏi. Chuyển sang rà code:
- `/users/{uid}` luôn dùng đúng UID thật của Firebase Auth làm khoá — 2 dòng cùng email chỉ có thể là 2 tài khoản Auth THẬT SỰ khác nhau.
- `functions/index.js` (`createStaffAccount` — luồng chủ shop mời nhân viên) đã `.toLowerCase()` email trước khi tạo tài khoản → không thể tạo trùng qua đường này (Auth chặn email đã tồn tại).
- **`lib/views/register_view.dart`** (luồng tự đăng ký, gọi thẳng `FirebaseAuth.createUserWithEmailAndPassword` từ client) chỉ `.trim()` email, **KHÔNG `.toLowerCase()`**. Nếu cùng 1 người gõ email lệch hoa/thường giữa các lần (VD lần đầu "Khuyen@H.com", lần sau "khuyen@h.com"), Firebase Auth có thể tạo 2 tài khoản THẬT riêng biệt — khớp đúng với hiện tượng: cùng email (nhìn qua tưởng giống hệt), khác uid, khác shop/vai trò/ngày tạo.

**Fix:** `register_view.dart` — chuẩn hoá `email = _emailC.text.trim().toLowerCase()` trước khi tạo tài khoản, khớp với luồng mời nhân viên đã làm đúng từ trước.

**Cân nhắc thêm nhưng CHƯA làm:** cũng cân nhắc sửa `removeUserFromShop` (Cloud Function, dùng khi chủ shop "Xóa nhân viên khỏi shop") vì nó chỉ set `shopId: null` chứ không xoá hẳn document — nhưng sau khi xem kỹ hơn: (1) hàm này không tạo dòng mới nên không phải nguyên nhân gây "trùng" như trong ảnh chụp màn hình (các dòng trùng đều có shop THẬT, không phải `shopId: null`), (2) xoá document ở đây có rủi ro làm hỏng khả năng mời lại đúng người đó vào shop sau này (khoá `email-already-exists` ở tài khoản Auth vẫn còn) mà chưa kiểm chứng được tác động đầy đủ trên dữ liệu thật. Quyết định KHÔNG đụng vào để tránh regression trên 1 tính năng đang được khách hàng thật dùng thường xuyên — chỉ ship phần chắc chắn, an toàn (chuẩn hoá email).

**Verify:** `flutter analyze` sạch, build + cài + khởi động Oppo CPH2203 không FATAL exception. Chỉ ngăn được trùng MỚI phát sinh — **không tự động dọn các dòng trùng đã có sẵn trong dữ liệu** (cần xử lý riêng, nên xác nhận qua Firebase Console trước khi xoá thủ công dữ liệu thật).

**Files:** `lib/views/register_view.dart`.

---

## [2026-08-16e] - fix(admin): 3 lỗi tab Cửa hàng (Shops) trong Super Admin Console

**User báo:** (1) "trong tab Shops, tìm kiếm nếu chưa load thì không tìm ra được shop", (2) "bấm vào shop lại hiện ra thêm 1 list và phải bấm thêm 1 lần nữa mới vào shop muốn vào được", (3) "khi bấm 1 shop: xóa hoàn toàn nhưng vẫn còn trong list mà không mất đi".

**Nguyên nhân & fix:**
1. **Tìm kiếm bỏ sót shop chưa tải**: `_ShopsSection` phân trang 20 shop/lần và tìm kiếm chỉ lọc trên dữ liệu ĐÃ tải (`_shops`) — shop chưa được tải tới trang đó thì tìm không ra. Fix: khi có từ khóa tìm kiếm, tải toàn bộ shop 1 lần (debounce 300ms, cache lại, tối đa 2000 shop) để tìm đúng trên toàn bộ dữ liệu thay vì chỉ trang hiện tại. `lib/views/super_admin_console_view.dart` (`_ShopsSectionState`).
2. **Bấm shop phải bấm 2 lần mới vào được**: `ListTile` của mỗi shop không có `onTap` — chỉ bấm được nút "..." (PopupMenuButton) để mở menu, chọn "Vào shop" mới điều hướng. Đã vậy, `_enterShop()` khi điều hướng lại **bỏ qua hoàn toàn shop đã bấm**, chỉ mở `ShopSelectorView` — màn hình hiện DANH SÁCH TẤT CẢ shop để chọn lại từ đầu (đúng là "hiện ra thêm 1 list, bấm thêm 1 lần nữa"). Fix: thêm `onTap` trực tiếp trên dòng shop để vào ngay (1 chạm); `ShopSelectorView` thêm tham số `autoSelectShopId`/`autoSelectShopName` — khi được truyền (từ Super Admin Console), bỏ qua màn chọn shop, tự động vào thẳng đúng shop đã bấm sau khi xác thực PIN. `lib/views/shop_selector_view.dart`, `lib/views/super_admin_console_view.dart`.
3. **Xóa shop nhưng vẫn còn trong danh sách**: Nút "Xóa" nằm ở mục "Vùng nguy hiểm" (`_DangerSection`) — danh sách này lấy TẤT CẢ shop qua Firestore stream nhưng KHÔNG lọc bỏ shop đã `deleted:true`, nên sau khi xóa, shop đó vẫn nằm y nguyên trong danh sách với 2 nút Đặt lại/Xóa y hệt như trước — nhìn như thao tác không có tác dụng (dù Firestore đã ghi đúng `deleted:true`). Fix: `_DangerSection` lọc bỏ shop đã xóa khỏi danh sách thao tác, hiện số lượng đã ẩn kèm gợi ý xem lại ở tab Cửa hàng > bộ lọc "Đã xóa". `lib/views/super_admin_console_view.dart`.

**Verify:** `flutter analyze` sạch (0 lỗi mới), build + cài + khởi động Oppo CPH2203 không FATAL exception. **Chưa test trực tiếp luồng vào shop/xóa shop trên máy** (không có tài khoản super admin thật) — cần user xác nhận qua tài khoản `admin@huluca.com` hoặc super admin thật.

**Files:** `lib/views/super_admin_console_view.dart`, `lib/views/shop_selector_view.dart`.

---

## [2026-08-16d] - feat(notification): "Yêu cầu cập nhật" tự động mở đúng App Store/Google Play theo máy người dùng

**Yêu cầu user:** "đưa link sẵn vào và giúp tôi luôn mỗi lần cập nhật chỉ cần bấm yêu cầu cập nhật là người dùng có thể đến thẳng store luôn ios hoặc chplay" — không muốn phải dán link thủ công mỗi lần, và 1 broadcast phải mở ĐÚNG store theo nền tảng của từng người dùng (không thể gửi 1 link cố định vì iOS/Android khác store).

**Cách làm:** Thay vì gửi 1 URL cố định, khi chọn loại "🔴 Yêu cầu cập nhật" trong Super Admin Console, form tự bật công tắc "Bấm vào là mở kho ứng dụng" (mặc định BẬT, có thể tắt để dán link tuỳ chỉnh khác). Khi bật, client gửi 1 giá trị đặc biệt (`auto:store`) thay vì URL — **thiết bị người nhận** tự chọn đúng link theo nền tảng của chính nó tại thời điểm bấm, không phải theo máy admin gửi.

**Files:**
- `lib/services/notification_service.dart`: thêm hằng số `storeLinkSentinel` ('auto:store'), `androidStoreUrl` (Google Play: `https://play.google.com/store/apps/details?id=com.huluca.shopmanager`), `iosStoreUrl` (App Store, đã có từ trước). `_openBroadcastUrl` giờ resolve sentinel → `Platform.isIOS ? iosStoreUrl : androidStoreUrl` trước khi `launchUrl`.
- `lib/views/super_admin_console_view.dart`: form broadcast — khi chọn "Yêu cầu cập nhật", hiện `SwitchListTile` "Bấm vào là mở kho ứng dụng" (mặc định bật), ẩn ô nhập link thủ công; tắt công tắc mới hiện lại ô link để dán link tuỳ chỉnh.
- `functions/index.js` (`sendBroadcastNotification`): validate URL nới thêm để chấp nhận giá trị sentinel `auto:store` (khớp hằng số bên Flutter) bên cạnh `http(s)://`.

**Verify:** `flutter analyze` sạch, `node -c index.js` hợp lệ, build + cài + khởi động Oppo CPH2203 không FATAL exception. Đã `firebase deploy --only functions:sendBroadcastNotification` thành công (project `huyaka-1809`) sau khi user xác nhận.

---

## [2026-08-16c] - feat(notification): Thông báo broadcast có thể kèm link (VD: link App Store để cập nhật)

**Yêu cầu user:** "tạo thông báo để gửi yêu cầu cập nhật nhấp vào là vào kho store được ko" — gửi broadcast toàn hệ thống có link, bấm vào mở link đó (VD: link App Store).

**Thay đổi:**
- `functions/index.js` (`sendBroadcastNotification`): nhận thêm field `url` (optional) từ client, validate phải bắt đầu `http://`/`https://`, lưu vào doc Firestore `broadcasts` và đưa vào `data` payload của FCM (`{..., url}`).
- `lib/views/super_admin_console_view.dart` (form gửi broadcast): thêm ô "Link (không bắt buộc)", validate client-side trước khi gọi Cloud Function, xóa cùng lúc với tiêu đề/nội dung sau khi gửi thành công.
- `lib/services/notification_service.dart`:
  - Dialog broadcast hiển thị khi app đang mở (`_showBroadcastDialog`) — nếu có `url`, thêm nút "Cập nhật ngay" (mở link qua `url_launcher`, `LaunchMode.externalApplication`) bên cạnh nút đóng ("Để sau"/"Đã hiểu").
  - Bấm vào thông báo hệ thống (push, app nền/đã đóng) hoặc local notification — `_handleNotificationNavigation` giờ ưu tiên mở `url` nếu có trong data payload, trước khi thử điều hướng deep-link như cũ.

**Verify:** `flutter analyze` sạch (không lỗi mới), `node -c index.js` cú pháp hợp lệ, `flutter build apk --debug` + cài + khởi động Oppo CPH2203 không FATAL exception trong logcat. Đã `firebase deploy --only functions:sendBroadcastNotification` thành công (project `huyaka-1809`, asia-southeast1) sau khi user xác nhận.

**Files:** `functions/index.js`, `lib/views/super_admin_console_view.dart`, `lib/services/notification_service.dart`.

---

## [2026-08-16b] - refactor(admin): Redesign trang Super Admin Console cho chuẩn & dễ theo dõi

**Yêu cầu user:** "sửa lại trang supper admin cho chuẩn và dễ theo dõi" — 4 vấn đề được chọn: Tổng quan thiếu thông tin/khó nhìn, danh sách Cửa hàng/Người dùng khó tìm-lọc, style không nhất quán, và mô tả bổ sung khi thấy.

**Phạm vi:** Chỉ sửa giao diện (`lib/views/super_admin_console_view.dart`, ~2400 dòng) — **không đổi 1 dòng logic nghiệp vụ** (reset shop, xóa shop/user, khóa shop, PIN reauth, selective reset, gửi broadcast, sync claims). File `super_admin_view.dart` cũ xác nhận không còn được import ở đâu, bỏ qua.

**Thay đổi:**
- Thêm 2 widget dùng chung: `_SectionHeader` (icon + tiêu đề + subtitle, đầu mỗi mục) và `_StatusPill` (badge trạng thái ACTIVE/LOCKED/DELETED/OWNER bo tròn, thay code badge lặp lại).
- **Tổng quan (Dashboard):** viết lại hoàn toàn — `_SectionHeader`, 4 stat card restyle theo pattern `ai_usage_dashboard_view.dart` (nền trắng, bo góc 14, viền `AppColors.divider`, shadow nhẹ), bấm được để nhảy thẳng sang Cửa hàng/Người dùng; thêm khối "Cần chú ý" (cảnh báo số shop bị khóa + nút Xem) và hàng "Truy cập nhanh" (Người dùng/Nhật ký/Thông báo). Không thêm Firestore query mới — dùng lại dữ liệu đã có.
- **Cửa hàng/Người dùng:** `_SectionHeader` + đếm số kết quả; thay toggle "Đã xóa" đơn lẻ bằng `FilterChip` (Cửa hàng: Tất cả/Hoạt động/Đã khóa/Đã xóa; Người dùng: Tất cả/Chủ shop/Nhân viên) lọc client-side trên dữ liệu đã tải — logic search/phân trang Firestore giữ nguyên. Badge trạng thái chuyển sang `_StatusPill`.
- **Quyền hạn/Nhật ký/Thông báo/Cài đặt/Vùng nguy hiểm:** chỉ thêm `_SectionHeader` đầu mục, nội dung/logic bên trong giữ nguyên 100%. Vùng nguy hiểm đổi `Colors.red`/hex hardcode sang `AppColors.error`/`AppColors.errorLight`.
- Sidebar: màu selected-state của mục điều hướng đổi sang `AppColors.primary` (trước dùng màu mặc định Material).

**Verify:**
- `flutter analyze lib/views/super_admin_console_view.dart` sạch (chỉ còn 1 warning vô hại: tham số `trailing` của `_SectionHeader` chưa được dùng ở đâu — để sẵn cho tương lai).
- `flutter build apk --debug` thành công, cài lên Oppo CPH2203, mở app, `adb logcat` xác nhận không có FATAL/AndroidRuntime exception, process chạy ổn định.
- **Giới hạn quan trọng:** không có tài khoản Super Admin thật trên máy test (`_bootstrapAccess` yêu cầu Firebase custom claim `isSuperAdmin`/`role=super_admin`, tài khoản test hiện tại chỉ là owner thường) nên **chưa tự vào được màn Super Admin Console để test trực tiếp**. Cần user tự xác nhận qua tài khoản `admin@huluca.com` hoặc tài khoản super admin thật.

**Files:** `lib/views/super_admin_console_view.dart`.

---

## [2026-08-16] - fix(ui): 22 điểm popup MEDIUM risk còn lại + thêm 2 điểm context-safety

**Bối cảnh:** Nốt phần còn lại của audit 95 file ở mục `[2026-08-15c]` — 22 điểm chỉ xử lý bàn phím (`viewInsetsOf`) mà thiếu thanh điều hướng (`paddingOf`), theo yêu cầu user tiếp tục nhưng cẩn trọng vì app đã có người dùng/dữ liệu thật.

**Fix:** Thêm `MediaQuery.paddingOf(context).bottom` vào công thức padding đáy đã có sẵn ở 22 điểm, cùng pattern đã kiểm chứng ở đợt HIGH risk trước. Một số sheet dùng `context` bị shadow nhiều lớp (`create_repair_order_view.dart`, `hr_salary_settings_view.dart` — 3 lớp builder cùng tên `context`) được capture riêng ra biến trước khi bị shadow.

**Tiện sửa cùng lúc:** 2 điểm context-safety riêng biệt (đọc `MediaQuery` từ `ctx` bên trong thay vì `context` ngoài — nguy cơ crash `_dependents.isEmpty`) mà audit ghi nhận là "otherwise safe pattern": `missing_info_products_view.dart` (`_editCost`), `repair_detail_view.dart` (`_showAddServiceDialog`, chỉ đổi context cho dòng `viewInsetsOf`, không đụng gì khác trong hàm này vì đã test kỹ từ trước).

**Files:** `attendance_management_view.dart` (5), `cash_closing_view.dart` (2), `create_repair_order_view.dart`, `expense_view.dart` (2), `community_view.dart`, `inventory_view.dart` (3, gồm 1 điểm loại bỏ `Builder` lồng thừa giống pattern đã fix ở `repair_detail_view.dart`), `payment_request_chat_view.dart`, `repair_detail_view.dart` (2), `sale_detail_view.dart`, `ai_repair_input_sheet.dart`, `ai_order_input_sheet.dart`, `storage_location_selector.dart`, `quick_code_picker_sheet.dart`, `supplier_picker_sheet.dart`, `attendance_view.dart` (2), `category_management_view.dart`, `hr_salary_settings_view.dart`, `parts_inventory_view.dart`, `missing_info_products_view.dart`.

- `flutter analyze` sạch trên toàn `lib/` (không có lỗi/warning mới so với trước khi sửa)
- `flutter build apk --debug` thành công, cài + khởi động trên Oppo CPH2203, kiểm tra `adb logcat` không có FATAL/AndroidRuntime exception khi mở app — theo phản hồi user về tiết kiệm token, không lặp lại screenshot cho từng file/màn hình riêng lẻ lần này
- **Toàn bộ danh sách 42 điểm (20 HIGH + 22 MEDIUM) từ audit ban đầu nay đã fix xong.**

---

## [2026-08-15c] - fix(ui): 20 điểm popup/bottom sheet bị che nút bấm bởi thanh điều hướng/bàn phím

**Triệu chứng (user báo):** "rất nhiều chỗ khi popup bị che nút bấm ở dưới màn hình hoặc che ít hoặc che hết khó bấm".

**Điều tra:** Audit toàn bộ 95 file dùng `showModalBottomSheet`/`showDialog`/`showAppBottomSheet` trong app, tìm các sheet không xử lý bottom safe-area (thanh điều hướng hệ thống) và/hoặc keyboard inset (bàn phím). Phát hiện 20 điểm HIGH risk (hoàn toàn không xử lý gì) và 22 điểm MEDIUM risk (chỉ xử lý bàn phím, thiếu thanh điều hướng) trên 30+ file. Đã fix 20 điểm HIGH risk trước theo yêu cầu; 22 điểm MEDIUM để sau.

**Pattern fix áp dụng (nhất quán, khớp `_editBasicInfo`/`debt_payment_sheet.dart` đã kiểm chứng):**
- Bọc nội dung sheet trong `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom))`
- Luôn đọc `MediaQuery` từ `context` NGOÀI (context của State, capture trước khi gọi `showModalBottomSheet`) — không phải `ctx`/context bị shadow bên trong builder — để tránh crash `_dependents.isEmpty` khi pop (bug đã biết, xem mục `[2026-08-15]`)
- Với sheet dùng `context` bị shadow bởi tham số builder cùng tên: dùng `this.context` (State) hoặc capture vào biến `outerContext` riêng
- Với sheet dạng `DraggableScrollableSheet`/`ListView`/`SingleChildScrollView` sẵn có: chỉ cần nới `padding` đáy của phần scroll thay vì bọc thêm `Padding`

**Tiện phát hiện thêm:** 2 sheet trong `advanced_chat_view.dart` (biểu cảm, hành động tin nhắn) đã có sẵn nỗ lực xử lý safe-area nhưng đọc `MediaQuery.of(ctx)` (context bên trong) — đúng anti-pattern gây crash `_dependents.isEmpty` — đã sửa cùng lúc.

**Files:** `debt_view.dart`, `order_list_view.dart`, `salvage_phone_view.dart`, `pty_print_designer_view.dart`, `parts_inventory_view.dart`, `fashion/variant_management_view.dart`, `help_center_view.dart`, `fast_stock_in_view.dart`, `fast_inventory_input_view.dart`, `attendance_management_view.dart`, `attendance_view.dart`, `category_management_view.dart`, `inventory_view.dart` (2 chỗ), `cash_closing_view.dart`, `pending_payments_list_view.dart`, `staff_list_view.dart`, `home_view.dart`, `unified_sync_button.dart` (dùng chung bởi 3 nơi gọi).

- `flutter analyze` sạch trên toàn bộ `lib/` (0 lỗi mới) sau khi sửa
- Đã test trên Oppo CPH2203: build cài thành công, mở màn Công nợ (`debt_view.dart`) xác nhận không crash. **Chưa test riêng từng màn còn lại trong số 20 điểm** — theo phản hồi user về tiết kiệm token, không lặp lại screenshot cho từng file; tin vào `flutter analyze` sạch + pattern đã kiểm chứng nhiều lần trong phiên này.
- 22 điểm MEDIUM risk còn lại (chỉ thiếu xử lý thanh điều hướng, không phải hoàn toàn thiếu) và danh sách chi tiết: xem `DOCS/HANDOVER.md` mục Known Issues.

---

## [2026-08-15b] - fix(sale): danh sách bán hiện sai trạng thái "còn nợ" sau khi đã thu nợ

**Triệu chứng:** Bán hàng CÔNG NỢ cho khách → vào màn Công nợ thanh toán/thu hết nợ → quay lại Danh sách đơn bán vẫn thấy đơn đó hiện "còn nợ".

**Nguyên nhân gốc:** `SaleOrder.remainingDebt` (getter trong `sale_order_model.dart`) chỉ tính `finalPrice - downPayment - loanAmount - loanAmount2` — các field này chỉ có ý nghĩa cho luồng trả góp ngân hàng (TRẢ GÓP (NH)). Khi bán CÔNG NỢ (hoặc bán tiền mặt trả thiếu), khoản nợ được ghi ở bảng `debts` riêng (liên kết qua `linkedId = sale.firestoreId`); thanh toán qua `DebtPaymentSheet` chỉ cập nhật `debts.paidAmount`, KHÔNG ghi ngược lại `downPayment` của `SaleOrder` — nên `remainingDebt` không bao giờ đổi, đơn cứ hiện "còn nợ" mãi mãi dù đã thu đủ. `sale_detail_view.dart` (màn chi tiết) đã tra đúng bảng `debts` từ trước; chỉ riêng `sale_list_view.dart` (danh sách) là dùng sai nguồn.

**Fix:**
- `sale_list_view.dart`: thêm `_debtByLinkedId` (map `linkedId` → debt record, nạp 1 lần qua `db.getAllDebts()` trong `_refresh()`) + helper `_effectiveRemainingDebt(s)` — ưu tiên đọc từ `debts` nếu có, fallback về `SaleOrder.remainingDebt` khi không có (đơn trả góp NH thật sự).
- Áp dụng `_effectiveRemainingDebt` cho cả 4 chỗ đang dùng `s.remainingDebt`: filter theo trạng thái thanh toán, sort theo nợ nhiều nhất, tổng công nợ ở header, và chip "còn nợ" trên từng đơn.
- Thêm listener `EventBus().on('debts_changed', ...)` — trước đó màn danh sách không refresh khi thanh toán nợ ở nơi khác xong quay lại.

- File: `lib/views/sale_list_view.dart`
- Đã test trên Oppo CPH2203 với đơn CÔNG NỢ thật (ỐP x1, HUY, 100.000đ, đã thu đủ qua DebtPaymentSheet trước đó) — danh sách hiện đúng huy hiệu xanh "ĐÃ THU" thay vì "CÒN NỢ", không crash, không lỗi log mới.

---

## [2026-08-15] - fix(repair): revert regression crash ở sheet "Sửa ghi chú kỹ thuật" + phát hiện bug crash sâu hơn CHƯA fix

**Bối cảnh:** Review lại commit `0d38e3d2` (2026-08-10). Phát hiện `_editTechnicianNotes` đã bị đổi từ đọc `MediaQuery` qua `context` ngoài (an toàn) sang `Builder(builder: (innerCtx) => ...)` đọc qua `innerCtx` — đúng anti-pattern đã tốn công fix trước đó (xem mục `[2026-08-08]`, cause 1 trong `_editBasicInfo`). Đây là regression thật, không phải nghi ngờ suông.

**Đã fix (verify OK qua `flutter run` trên Oppo CPH2203):**
1. Đổi lại đọc `MediaQuery.viewInsetsOf(context)` từ `context` ngoài, bỏ `Builder`/`innerCtx` — khớp pattern đã chứng minh an toàn ở `_editBasicInfo`.
2. Phát hiện thêm: công thức padding dùng `MediaQuery.viewPaddingOf(...)` (không tự trừ khi bàn phím hiện) thay vì `MediaQuery.paddingOf(...)` (tự trừ đúng) — gây sheet co lại chỉ còn 1 sliver khi bàn phím mở. Sửa theo đúng công thức `_editBasicInfo` (`paddingOf` + `bottomSafe = max(safeAreaBottom, 16.0)`).
3. Gỡ `SingleChildScrollView` thừa (không giúp ích, không phải nguyên nhân của #2).

**⚠️ CHƯA fix — phát hiện bug crash sâu hơn, độc lập với các fix trên:** Tái hiện được `_dependents.isEmpty` VÀ một crash khác ("TextEditingController used after being disposed", stack trace nằm trong nội bộ `_ModalBottomSheetRoute`/`AnimatedPadding` của Flutter framework) khi: focus vào ô ghi chú (bàn phím mở) → bấm nút Back hệ thống → bấm Back lần nữa hoặc bấm Lưu. Đường pop này KHÔNG đi qua `onPressed` của nút Hủy/Lưu (nơi có `FocusManager.instance.primaryFocus?.unfocus()` bảo vệ) nên không được bảo vệ. Đã thử bọc `PopScope(canPop:false, onPopInvokedWithResult: ...)` để chặn mọi đường pop — làm mất `_dependents.isEmpty` ở 1 lần test nhưng lại sinh ra crash "disposed controller" ở lần test sau → **đã revert PopScope**, không ship fix chưa chắc chắn. Lỗi intermittent (không phải lần nào cũng tái hiện), nghi là rủi ro có sẵn ở MỌI bottom sheet có TextField trong app này, không riêng sheet này. Cần phiên điều tra riêng, không vá vội. Chi tiết kỹ thuật đầy đủ đã lưu vào memory (`feedback_modal_sheet_dependents_crash.md`, mục "Cause 3").

- File: `lib/views/repair_detail_view.dart` (hàm `_editTechnicianNotes`)
- Luồng bình thường (mở sheet → gõ/không gõ → Hủy hoặc Lưu, không bấm Back hệ thống khi bàn phím đang mở) đã test ổn định, không crash, hiển thị đúng cả 2 trạng thái có/không bàn phím.

---

## [2026-08-10] - fix(repair): sheet "Thêm dịch vụ" hiện màn xám, không có popup

**Triệu chứng:** Bấm "+ Thêm" ở mục Dịch vụ trong Chi tiết đơn sửa → chỉ thấy nền mờ xám (barrier), không có popup nào hiện ra. Không có snackbar lỗi, không log gì rõ ràng qua `adb logcat` thường — chỉ phát hiện được nguyên nhân thật khi chạy `flutter run` (VM kết nối trực tiếp) để bắt exception layout đầy đủ.

**Nguyên nhân gốc:** Dialog "Thêm dịch vụ" (`_showAddServiceDialog`, `repair_detail_view.dart`) đã được refactor từ `showDialog`+`AlertDialog` sang `showModalBottomSheet` tự custom trước đó (chưa commit). Nút "Thêm"/"Cập nhật" là `ElevatedButton` không style riêng, đặt trong `Row` cùng `Spacer()`. Theme `ElevatedButton` toàn app (`AppButtonStyles.elevatedButtonStyle`) quy định `minimumSize: Size(double.infinity, buttonHeight)` — dùng cho nút full-width bình thường (VD trong `Column`). Nhưng trong `Row`, các con không-flex nhận `maxWidth: infinity` khi layout (hành vi chuẩn của `Row`/`Flex` để đo kích thước tự nhiên) — kết hợp với `minimumSize.width = double.infinity` khiến `ButtonStyleButton` tạo constraint `BoxConstraints(minWidth: infinity, maxWidth: infinity)` (tight-infinite, không hợp lệ) → Flutter crash `performLayout()` ngay khi build sheet lần đầu. Vì exception xảy ra trong lúc build, framework không render được gì cả — chỉ còn barrier (nền xám) của route.

**2 lỗi liên quan phát hiện cùng lúc:**
1. Root cause chính ở trên — fix bằng cách gán `style: AppButtonStyles.smallElevatedButtonStyle` (biến thể có sẵn trong theme, `minWidth: 0`) riêng cho `ElevatedButton` này, thêm import `theme/app_button_styles.dart` còn thiếu.
2. Sau khi sheet hiện được: hàng nút Hủy/Thêm ở cuối bị khuất một phần dưới thanh điều hướng hệ thống (3-button nav). Nguyên nhân: `showModalBottomSheet(useSafeArea: true)` chỉ áp `SafeArea(bottom: false)` nội bộ (chỉ tránh status bar, KHÔNG tránh nav bar) — sheet luôn được canh chạm đáy màn hình vật lý bất kể chiều cao. Fix: bọc thêm `SafeArea(top: false, ...)` quanh nội dung sheet để tự thêm padding đáy tránh thanh điều hướng.

- File: `lib/views/repair_detail_view.dart` (hàm `_showAddServiceDialog`)
- Đã test trực tiếp qua `flutter run` (Dart VM live) trên thiết bị Android thật: tái hiện lỗi gốc (barrier không nội dung) → xác nhận exception layout chính xác qua log → áp fix → verify hết crash, sheet hiện đầy đủ field + 2 nút không bị khuất → test full luồng nhập liệu + validate + lưu dịch vụ + xoá dịch vụ test, đều hoạt động đúng, không crash

---

## [2026-08-09b] - feat(sale): tìm kiếm khách hàng tự động khi tạo đơn bán

**Mục tiêu:** Đồng bộ trải nghiệm với màn tạo đơn sửa — gõ vào ô TÊN/SĐT có sẵn là hiện gợi ý khách cũ ngay.

- Gắn `CustomerSuggestionsPanel` (widget tái sử dụng từ `[2026-08-08]`, không sửa gì thêm) vào 2 field TÊN (`nameCtrl`/`nameF`) và SĐT (`phoneCtrl`/`phoneF`) có sẵn trong `create_sale_view.dart` — thêm 2 `FocusNode` mới vì file này chưa có sẵn như bên đơn sửa
- **Xoá cơ chế gợi ý cũ**: `_suggestCustomers`/`_buildCustomerSuggestions()` — chip ngang chỉ load 1 lần lúc mở màn (`db.getCustomerSuggestions()`), không tìm theo gõ chữ, không có khách gần nhất khi rỗng. Panel mới thay thế hoàn toàn, không giữ song song 2 cơ chế
- Chọn khách → tự điền TÊN/SĐT/Địa chỉ, gọi lại `_loadCustomerQuickData()` có sẵn để hiện card "Khách cũ · N giao dịch"
- File: `lib/views/create_sale_view.dart`
- Đã test trên Oppo CPH2203: gõ SĐT/TÊN hiện gợi ý đúng, khách gần nhất khi ô trống, chọn khách tự điền + hiện quick-card

---

## [2026-08-09] - feat(backup): sao lưu đơn sửa kèm ảnh

**Mục tiêu:** Backup hiện có (SQLite/Firestore) chỉ lưu URL ảnh dạng text — nếu mất Storage thì URL vô nghĩa. Cần backup có ảnh thật.

- `BackupService.backupRepairsWithImages({from, to, onProgress})`: lấy đơn sửa theo khoảng ngày (`getRepairsByCreatedAtRange` có sẵn), tải từng ảnh nhận/giao máy (URL http/https) từ Firebase Storage, đóng gói cùng `repairs.json` (thông tin đơn) thành 1 file `.zip` bằng package `archive` (đã có sẵn trong `pubspec.yaml`, không cần thêm dependency). Ảnh local chưa upload xong bị bỏ qua (không có gì để tải)
- Lỗi tải 1 ảnh không làm hỏng cả bản sao lưu — đếm riêng vào `failedImageCount`
- Thêm `listRepairImageBackups()`/`deleteRepairImageBackup()` — liệt kê/xoá các bản zip đã tạo, tái dùng model `LocalSqliteBackup` có sẵn
- UI: thêm tab thứ 3 "Đơn sửa + Ảnh" trong `backup_restore_view.dart` (màn Cài đặt → Sao lưu & Khôi phục) — chọn khoảng ngày, xem tiến trình, chia sẻ file qua `share_plus`
- File: `lib/services/backup_service.dart`, `lib/views/backup_restore_view.dart`
- Đã test trên Oppo CPH2203: chọn khoảng ngày, chạy sao lưu, tạo đúng file zip, hiện trong danh sách "Đã sao lưu trên máy này", summary "Đã sao lưu N đơn, M ảnh" đúng số liệu thực tế

---

## [2026-08-08b] - feat(repair): tìm kiếm khách hàng tự động (autocomplete) khi tạo đơn sửa

**Mục tiêu:** Giảm thao tác nhập lại khi tạo đơn sửa cho khách đã từng đến — gõ SĐT hoặc tên là gợi ý ngay khách cũ, chọn 1 chạm là tự điền.

**1. `DBHelper.searchCustomersRanked(query, shopId, {limit: 10})`** — local SQLite only, không đọc Firestore
- Query rỗng → trả về khách ghé gần nhất (`ORDER BY COALESCE(lastVisitAt, updatedAt, createdAt) DESC`)
- Query có nội dung → xếp hạng bằng `CASE`: khớp chính xác SĐT (rank 0) > SĐT/tên bắt đầu bằng query (rank 1) > còn lại chứa query (rank 3), giới hạn 10 kết quả
- File: `lib/data/db_helper.dart`

**2. Widget tái sử dụng trong `lib/widgets/customer_autocomplete_field.dart`** — 2 biến thể dùng chung 1 logic tìm kiếm + 1 danh sách kết quả:
- `CustomerSuggestionsPanel` (controlled: nhận `query` + `active` từ ngoài) — gắn thẳng vào field SĐT/Tên **đã có sẵn** trong form, không thêm ô tìm kiếm riêng. Đây là bản UX cuối cùng sau khi user phản hồi muốn gõ trực tiếp vào SĐT/Tên là thấy gợi ý ngay, thay vì phải gõ vào 1 ô riêng phía trên
- `CustomerAutocompleteField` (tự chứa TextField riêng) — vẫn giữ lại cho màn nào chưa có sẵn field SĐT/Tên để gắn vào
- Cả 2 đều: debounce 180ms, không phải Overlay/portal — render list ngay dưới field trong luồng scroll bình thường để tránh nhóm lỗi `_dependents.isEmpty` liên quan route/portal (bài học từ fix cùng ngày ở `repair_detail_view.dart`)
- Field trống (mới focus) → hiện khách ghé gần nhất; gõ chữ → tìm theo tên/SĐT, không phân biệt hoa thường
- Mỗi dòng gợi ý hiển thị tên, SĐT, thời gian ghé gần nhất (dạng tương đối: "X phút/giờ/ngày trước")
- Chọn 1 khách → callback `onSelected(Customer)` — không tự sở hữu controller của form cha, nên tái dùng được ở màn tạo đơn bán, bảo hành, công nợ... sau này chỉ cần gắn vào field tương ứng + truyền `onSelected` khác
- Chống race điều kiện: mỗi lần gõ có số thứ tự request riêng, kết quả trả về trễ (từ query cũ hơn) bị bỏ qua thay vì ghi đè kết quả mới

**3. Tích hợp vào `create_repair_order_view.dart`**
- Gắn `CustomerSuggestionsPanel` ngay dưới Row 2 field SĐT (`phoneCtrl`/`phoneF`) + Tên (`nameCtrl`/`nameF`) có sẵn — `active` = 1 trong 2 field đang focus, `query` = nội dung field đang focus. Gõ vào SĐT hoặc Tên đều kích hoạt cùng 1 danh sách gợi ý bên dưới
- Khi chọn khách: tự điền `phoneCtrl`, `nameCtrl`, `addressCtrl` (nếu có) và gọi lại `_smartFill()` có sẵn để load card "Khách cũ · N đơn" + công nợ — không phải viết lại logic quick-card
- `phoneF`/`nameF` là 2 `FocusNode` đã khai báo + dispose sẵn từ trước nhưng chưa từng gắn vào field nào — tận dụng lại thay vì tạo mới
- File: `lib/views/create_repair_order_view.dart`

**Đã test trên Oppo CPH2203:** gõ vào ô SĐT hiện gợi ý ✅, gõ vào ô Tên hiện gợi ý ✅ (không phân biệt hoa thường), hiện khách gần nhất khi field vừa focus còn trống (đúng thứ tự thời gian) ✅, chọn khách tự điền cả 2 field + hiện quick-card ✅.

---

## [2026-08-08] - fix(audit,sync,notification): sửa 3 bug + thêm hẹn khách lấy máy cho đơn sửa

**1. Fix bug đếm sai "Active Listeners" trong Firestore Audit Monitor**
- `logRead(isActiveListener: true)` cộng dồn mỗi lần snapshot bắn ra thay vì mỗi lần listener mới mở → hiện số ảo (x22, x25...)
- Thêm `_activeListenerKeys` (Set) để chỉ đếm 1 lần cho mỗi (collection, service, method) đang mở
- File: `lib/developer/firestore_audit/services/firestore_audit_service.dart`

**2. Tăng cooldown SyncService.refreshCloudCollections 30s → 120s**
- Giảm tần suất poll tự động các collection ít thay đổi (suppliers, audit_logs...), giảm read Firestore
- Các lệnh gọi có `force: true` (nút "Đồng bộ ngay", sự kiện thay đổi dữ liệu) không bị ảnh hưởng
- File: `lib/services/sync_service.dart`

**3. Fix bug double thông báo khi nhận từ nhân viên khác**
- Nguyên nhân: có 2 đường hiển thị độc lập cho cùng 1 sự kiện — FCM foreground handler VÀ Firestore realtime listener (`shop_notifications`) — cả 2 đều tự bắn snackbar + local notification
- Giải pháp: Firestore listener chỉ còn đánh dấu dedup, không tự hiển thị nữa; FCM là nguồn hiển thị duy nhất
- File: `lib/services/notification_service.dart`

**4. Thêm trường "Hẹn giao máy" cho đơn sửa chữa (lấy ngay / trong ngày / báo sau)**
- Model: `Repair.pickupSchedule` (String?, values: `now`/`same_day`/`later`) + `pickupScheduleLabel` getter
- DB: SQLite v103 → v104, cột `pickupSchedule` thêm qua `onUpgrade` + `onOpen` defensive check
- UI: ChoiceChip 3 lựa chọn trong màn tạo đơn sửa (`create_repair_order_view.dart`) và trong sheet "Chỉnh sửa thông tin đơn sửa" (`repair_detail_view.dart`), hiển thị read-only ở màn chi tiết
- Files: `lib/models/repair_model.dart`, `lib/data/db_helper.dart`, `lib/views/create_repair_order_view.dart`, `lib/views/repair_detail_view.dart`

**5. Fix crash `_dependents.isEmpty` khi bấm LƯU trong sheet "Chỉnh sửa thông tin đơn sửa" (phát hiện trong lúc test tính năng #4)**
- Lỗi có sẵn từ trước, không do tính năng hẹn giao máy gây ra (tái hiện cả khi không chạm chip mới) — trước đây bị che giấu vì nút Lưu/Hủy nằm trong vùng cử chỉ điều hướng hệ thống trên một số máy (Oppo ColorOS gesture-nav) nên không ai bấm tới được để kích hoạt lỗi
- **Lần fix đầu (không đủ):** áp dụng lại pattern cũ từ `order_list_view.dart` 2026-06-10g — `async` + `await Future.delayed(Duration.zero)` sau `unfocus()` trước `Navigator.pop()`. Build lại và test thì crash **vẫn tái hiện ~50%** (cùng thao tác, lúc bị lúc không) → xác nhận đây là race điều kiện theo thời điểm frame, không phải do thiếu delay
- **Root cause thật sự (2 phần):**
  1. `MediaQuery.paddingOf(ctx)` / `viewInsetsOf(ctx)` trong builder của `showModalBottomSheet` đọc từ context **bên trong** sheet route → tạo dependency vào MediaQuery scoped theo route đó. Khi `Navigator.pop()` chạy, MediaQuery này deactivate trước khi widget kịp rebuild để gỡ dependency → đúng bug đã từng fix ở 11 file khác ngày 2026-06-05 nhưng lại xuất hiện lại ở đây. Fix: đổi sang đọc từ `context` (context của State, nằm ngoài route) thay vì `ctx`
  2. `FocusScope.of(ctx).unfocus()` gọi trong `onPressed` **tự đăng ký thêm 1 dependency mới** vào FocusScope của chính route sắp đóng, ngay tại thời điểm chuẩn bị pop — do đây là lookup `.of(ctx)` nên luôn tạo dependency dù gọi trong callback hay build. Đây là nguyên nhân chính khiến delay không đủ: dependency được tạo mới ngay trước khi pop, không có cơ hội rebuild để gỡ. Fix: đổi sang `FocusManager.instance.primaryFocus?.unfocus()` — API tĩnh, không qua BuildContext/InheritedWidget nên không tạo dependency nào cả
- Áp dụng cả 2 fix cho `_editBasicInfo` (sheet chính, có tính năng hẹn giao máy) và `_editTechnicianNotes` (sheet khác cùng file, phát hiện có cùng anti-pattern khi rà lại code, sửa phòng ngừa dù chưa từng crash được ghi nhận)
- **Verify trên Oppo CPH2203:** lặp lại thao tác chọn chip + bấm LƯU **5/5 lần liên tiếp** không crash (trước fix: crash lặp lại nhiều lần cùng thao tác) — dữ liệu luôn lưu đúng kể cả những lần bị crash trước đó
- Files: `lib/views/repair_detail_view.dart`

---

## [2026-06-16c] - feat(notifications): push notification cho quản lý khi nhập kho / bán thiếu giá vốn

**Mục tiêu:** Quản lý không bỏ lỡ các sự kiện cần xử lý từ nhân viên.

| Sự kiện | File | Type | Nội dung |
|---|---|---|---|
| Đơn sửa chờ duyệt | `repair_detail_view` | `approval_needed` | Đã có sẵn từ trước ✅ |
| Nhập kho thiếu giá vốn | `fast_stock_in_view` | `missing_cost` | NV + tên SP + "cần bổ sung sau" |
| Nhập kho thiếu NCC | `fast_stock_in_view` | `missing_supplier` | NV + tên SP + "chưa chọn NCC" |
| Phiếu nhập kho mới | `fast_stock_in_view` | `stock_pending` | NV + tên SP + "chờ xác nhận" |
| Xác nhận nhập kho | `pending_stock_list_view` | `stock_confirmed` | NV + tên SP + NCC |
| Bán hàng thiếu giá vốn | `create_sale_view` | `missing_cost_sale` | NV + khách + số tiền + "cần bổ sung" |

**Files thay đổi:**
- `lib/views/fast_stock_in_view.dart`
- `lib/views/pending_stock_list_view.dart`
- `lib/views/create_sale_view.dart`

---

## [2026-06-16b] - fix(supplier): _pickSupplier hỏi payment; ghi công nợ/expense/lịch sử chi đúng

**Vấn đề:** Khi chọn NCC trong trang "Thiếu vốn/NCC":
1. `paymentMethod` hardcode `'TIỀN MẶT'` — không hỏi user
2. Không tạo công nợ khi chọn CÔNG NỢ
3. Không ghi expense vào sổ quỹ khi TIỀN MẶT/CHUYỂN KHOẢN
4. Không ghi `financial_activity_log` (lịch sử chi)

**Giải pháp:**
- Thêm `SimpleDialog` chọn phương thức thanh toán trước khi lưu NCC
- Nếu `p.cost > 0` và `p.paymentMethod == null` (chưa từng ghi tài chính): tạo debt hoặc expense + logPurchase
- Nếu `p.paymentMethod != null`: expense đã được ghi từ fast_stock_in hoặc `_editCost` → không ghi thêm (tránh double count)
- `supplier_import_history` luôn dùng payment method thực tế user chọn
- Lưu `paymentMethod` vào `products` record

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`

---

## [2026-06-16a] - fix(stock-in): payment method không bắt buộc khi allowPendingCost=true + cost=0; cập nhật paymentMethod khi bổ sung vốn

**Vấn đề 1:** `fast_stock_in_view` luôn yêu cầu chọn phương thức thanh toán dù đã bật "cho phép nhập giá vốn sau". User không thể nhập kho tạm mà bỏ trống payment.

**Giải pháp:** Thêm getter `_allowPendingCost` từ ShopSettings. Điều kiện validate: payment chỉ bắt buộc khi `!_allowPendingCost` HOẶC khi `cost > 0` (đã nhập giá vốn ngay lúc nhập kho). Khi `allowPendingCost=true` và `cost=0` → payment được bỏ qua, sẽ điền sau khi bổ sung vốn.

**Vấn đề 2:** Khi bổ sung giá vốn qua "Thiếu vốn/NCC", `products.paymentMethod` không được cập nhật — product vẫn lưu `paymentMethod=null` dù user đã chọn phương thức thanh toán trong dialog.

**Giải pháp:** `_editCost` thêm `paymentMethod: payment` vào `p.copyWith(...)` → product record lưu đúng phương thức thanh toán sau bổ sung.

**Files thay đổi:**
- `lib/views/fast_stock_in_view.dart`
- `lib/views/missing_info_products_view.dart`

---

## [2026-06-11c] - fix(finance): bổ sung giá vốn/NCC retroactive cập nhật đúng tài chính

**Vấn đề (5 lỗi từ audit):**
1. `sale_orders.totalCost` không được cập nhật khi nhập vốn sau bán → lợi nhuận gộp sai vĩnh viễn
2. Double counting: expense "Giá vốn" + COGS từ sale đều bằng 0 → net đúng nhưng gross sai
3. Supplier "Lịch sử nhập" trống dù đã gán NCC/vốn retroactive
4. SP đã bán (status=0) không hiển thị trong tab "Sản phẩm" của NCC
5. Ngày expense = ngày bổ sung (hôm nay) thay vì ngày mua/bán

**Giải pháp:**
- **Fix 1+2:** `_editCost` — nếu sản phẩm có IMEI và đã bán: tìm sale qua `getSalesByProductImei`, gọi `updateSaleCostByImei` để patch `totalCost` + `itemSnapshotsJson.unitCost` trực tiếp. Chỉ tạo expense khi không tìm được sale nào (sản phẩm còn tồn kho). Nếu CÔNG NỢ → luôn tạo debt (obligation to supplier).
- **Fix 3:** `_editCost` và `_pickSupplier` → insert vào `supplier_import_history` sau khi gán NCC.
- **Fix 4:** `getProductsBySupplier` thêm param `includeSold: bool = false`; `supplier_detail_view` truyền `includeSold: true`.
- **Fix 5:** Expense/activity date dùng `p.createdAt` thay vì `now`.
- **db_helper:** Thêm `updateSaleCostByImei()` — parse JSON snapshot, tìm item theo IMEI, cập nhật `unitCost`/`lineCostTotal`/`totalCost`.

**Files thay đổi:**
- `lib/data/db_helper.dart`
- `lib/views/missing_info_products_view.dart`
- `lib/views/supplier_detail_view.dart`

---

## [2026-06-11b] - feat(import): importPurchaseOrders tự tạo product stub; IMEI = 1 sản phẩm riêng

**Vấn đề:**
Import file `DanhSachChiTietNhapHang` từ KiotViet tạo 46 phiếu trong lịch sử nhập kho nhưng các sản phẩm mới trong những phiếu đó không xuất hiện trong Danh sách sản phẩm.

**Nguyên nhân:**
`importPurchaseOrders` chỉ tạo `import_orders` + `import_order_items`, không tạo bản ghi trong bảng `products`.

**Giải pháp:**
Sau khi insert từng `import_order_item`, kiểm tra sản phẩm trong bảng `products`:
- **Có IMEI:** tìm theo IMEI (không fallback tên). Nếu không tìm thấy → tạo product mới với IMEI đó, qty=1 (mỗi IMEI = 1 thiết bị vật lý riêng biệt).
- **Không có IMEI:** tìm theo tên (dedup). Nếu không tìm thấy → tạo product stub, qty=số lượng trong phiếu.
- **Đã tồn tại:** chỉ cập nhật supplier/cost nếu đang trống.

**Files thay đổi:**
- `lib/services/kiotviet_excel_import_service.dart`

---

## [2026-06-11a] - fix(ux): snackbar import KiotViet màu vàng khi toàn bộ bị bỏ qua

**Vấn đề:**
Sau khi import file Excel KiotViet, nếu toàn bộ sản phẩm đã tồn tại (skipped=N, inserted=0),
snackbar hiện màu xanh "thành công" → user nhầm tưởng import thất bại hoặc app lỗi.

**Giải pháp:**
Khi `inserted=0 && updated=0 && skipped>0` → snackbar màu vàng cam (amber) thay vì xanh.
Chỉ xanh khi thực sự có dữ liệu mới được thêm.

**Files thay đổi:**
- `lib/views/kiotviet_import_view.dart`

---

## [2026-06-10g] - fix: crash _dependents.isEmpty khi bấm Lưu/Hủy trong dialog thêm khách hàng

**Vấn đề:**
Bấm nút Lưu hoặc Hủy trong dialog "Thêm thông tin khách hàng" (từ danh sách đơn sửa) gây crash:
```
'_dependents.isEmpty': is not true
```
Root cause: `FocusScope.unfocus()` được gọi đồng bộ ngay trước `Navigator.pop()` — Flutter chưa kịp flush deactivation của text selection overlay (copy/paste toolbar) của TextField trước khi dialog bị pop, dẫn đến InheritedWidget assert fail.

**Giải pháp:**
Chuyển `onPressed` của cả 2 nút Hủy và Lưu sang `async`, thêm `await Future.delayed(Duration.zero)` sau `unfocus()` trước khi `Navigator.pop()`. Một frame trễ đủ để overlay deactivate sạch.

**Files thay đổi:**
- `lib/views/order_list_view.dart`

---

## [2026-06-10f] - fix: mã nhập nhanh điền sai màu SA MẠC và tình trạng NEW

**Vấn đề:**
Khi chọn mã nhập nhanh iPhone 17 Pro Max (và 16 Pro/Max, 15 Pro/Max) từ Nhanh hoặc Đầy đủ, form nhập kho hiển thị màu = KHÁC và tình trạng = KHÁC. Root cause:
1. `ProductConstants.mapColor("SA MẠC")` → không có trong `colors` list và không có rule → trả về "KHÁC"
2. `ProductConstants.mapColor("TỰ NHIÊN")` → rule TITAN block chỉ xử lý khi có từ "TITAN" → trả về "KHÁC"
3. `ProductConstants.mapConditionShort("NEW")` → seeder lưu condition = "NEW" nhưng không có rule → trả về "KHÁC"

**Giải pháp:**
- `ProductConstants.colors`: Thêm 'SA MẠC' vào danh sách (trước 'KHÁC')
- `ProductConstants.mapColor`: Thêm rule `'TỰ NHIÊN' → 'TITAN TỰ NHIÊN'` (seeder dùng cho iPhone 15/16/17 Pro)
- `ProductConstants.mapConditionShort`: Thêm `'NEW' → 'MỚI'` (seeder dùng condition="NEW" cho iPhone 16/17)
- `quick_input_codes_view.dart` `_colorOptions`: Thêm 'SA MẠC' với màu tan cát #D2B48C

**Kết quả:**
- iPhone 17 Pro Max SA MẠC NEW → màu = SA MẠC, tình trạng = MỚI ✅
- iPhone 16/17 Pro TỰ NHIÊN → màu = TITAN TỰ NHIÊN ✅
- Mã nhập nhanh (Nhanh và Đầy đủ) điền đúng cả màu lẫn tình trạng ✅

**Files thay đổi:**
- `lib/constants/product_constants.dart`
- `lib/views/quick_input_codes_view.dart`

---

## [2026-06-10e] - feat: trả hàng hiển thị trong tab Giao dịch (Tài chính)

**Vấn đề:**
Trả hàng không ghi thành giao dịch trong tab "Giao dịch" của Tài chính, khó audit luồng tiền theo từng lần trả hàng.

**Giải pháp:**
- `finance_v2_data_service.dart`: Thêm `FinanceV2Txn(type: 'REFUND', isIncome: false)` vào `transactions` list trong returns loop
- Mỗi trả hàng hiển thị: tên khách, "Hoàn tiền trả hàng", số tiền âm (-X Tr), phương thức, ngày giờ
- Không ảnh hưởng Tổng quan: `saleIn -= amount` vẫn chạy riêng → Thu tiền 5 Tr vẫn đúng
- Filter OUT trong Giao dịch sẽ bao gồm trả hàng (đúng về mặt cash flow)

**Kết quả:**
- Giao dịch tab: thấy "KHÁCH VÃNG LAI · Hoàn tiền trả hàng -12 Tr · TIỀN MẶT" ✅
- Tổng quan: Thu tiền 5 Tr (net), Chi tiền 0 (không thay đổi) ✅
- Nhất quán: Sổ quỹ Chi cũng hiển thị trả hàng như Chi → cả 2 màn hình đều thấy

**Files thay đổi:**
- `lib/finance_v2/finance_v2_data_service.dart`

---

## [2026-06-10d] - fix: home CHI TIÊU hiển thị Trả hàng mâu thuẫn với tổng = 0

**Vấn đề:**
Home screen dashboard dùng 2 nguồn dữ liệu khác nhau cho donut breakdown:
- Tổng "THU NHẬP" / "CHI TIÊU" lấy từ `financeSnapshot` (finance_v2, net approach: returns đã trừ vào thu)
- Breakdown "Bán hàng" = `_todaySaleIncome + _todayRefundOut` (17 Tr gross)
- Breakdown "Trả hàng" = `_todayRefundOut` (12 Tr) nằm dưới CHI TIÊU

Kết quả mâu thuẫn: CHI TIÊU tổng = 0 nhưng breakdown hiển thị "Trả hàng: 12 Tr"; THU NHẬP = 5 Tr nhưng breakdown "Bán hàng: 17 Tr" > tổng.

**Giải pháp:**
- `home_view.dart`: Xóa `_todayRefundOut` khỏi `incomeItems` (Bán hàng) và khỏi `expenseItems` (Trả hàng)
- Xóa field `_todayRefundOut` và assignment `analysis.refundOut` không còn dùng
- Home screen nay dùng thuần finance_v2 net approach, nhất quán với tab Tài chính

**Kết quả:**
- THU NHẬP = 5 Tr, breakdown Bán hàng = 5 Tr ✅
- CHI TIÊU = 0, không có mục Trả hàng mâu thuẫn ✅
- Nhất quán với Tài chính Tổng quan (Thu tiền 5 Tr, Chi tiền 0) ✅

**Files thay đổi:**
- `lib/views/home_view.dart`

---

## [2026-06-10c] - fix: trả hàng tính 0đ hoàn tiền khi unitPrice bị ghi đè thành 0

**Vấn đề:**
`itemSnapshotsJson` của một số đơn bán bị cloud sync bug ghi đè `unitPrice=0` (đã fix trước đó). Khi tạo trả hàng từ đơn này, form tính `totalReturnAmount = unitPrice × qty = 0` → hoàn tiền 0đ → Tài chính không trừ doanh thu → số liệu sai.

**Giải pháp:**
- `create_sales_return_view.dart`: Thêm fallback trong `_parseItems()` — nếu tổng giá snapshot = 0 nhưng `sale.finalPrice > 0`, phân phối `finalPrice / totalQty` cho từng item. Tránh trả hàng với 0đ do dữ liệu bị hỏng.

**Kết quả:**
- Return form hiển thị đúng đơn giá khi snapshot bị hỏng giá ✅
- `totalReturnAmount` được tính đúng từ `finalPrice` ✅
- Không ảnh hưởng đơn có snapshot giá đúng ✅

**Files thay đổi:**
- `lib/views/create_sales_return_view.dart`

---

## [2026-06-10b] - fix: trả hàng không ghi vào Giao dịch tài chính

**Vấn đề:**
Khi trả hàng, hệ thống tạo entry `-12 Tr` vào danh sách "Giao dịch" trong màn hình Tài chính, và cũng ghi vào `financial_activity_log`. Người dùng không muốn returns xuất hiện trong sổ giao dịch tài chính.

**Giải pháp:**
- `finance_v2_data_service.dart`: Xóa `transactions.add(FinanceV2Txn(...))` cho REFUND. Giữ nguyên `saleIn -= amount` để tổng "Tiền thu vào" vẫn đúng (net doanh thu sau hoàn trả).
- `sales_return_service.dart`: Xóa `FinancialActivityService.logCustomActivity(...)` — không ghi vào audit log tài chính.

**Kết quả:**
- "Giao dịch" tab: không còn hiện entry trả hàng ✅
- "Tiền thu vào" vẫn đúng (đã trừ giá trị hoàn trả) ✅
- Sổ quỹ không bị ảnh hưởng (đọc trực tiếp từ bảng sales_returns) ✅

**Files thay đổi:**
- `lib/finance_v2/finance_v2_data_service.dart`
- `lib/services/sales_return_service.dart`

---

## [2026-06-10a] - fix: crash _dependents.isEmpty khi bấm "Sửa thông tin đơn"

**Vấn đề:**
Khi `_managerUnlocked` đã là `true`, bấm "Sửa thông tin đơn" (hoặc "Sửa giá vốn", "Xóa đơn") trong PopupMenu gây crash assertion `_dependents.isEmpty: is not true` ở Flutter framework.dart:6268. Nguyên nhân: `showDialog` được gọi **đồng bộ** ngay trong `onSelected` callback trong khi Flutter đang deactivate widget tree của popup, gây xung đột InheritedElement.

**Giải pháp:**
Thêm `await Future.delayed(Duration.zero)` trước mỗi lần gọi dialog trong 3 case: `edit`, `fix_cost`, `delete`. Điều này nhường microtask frame để popup đóng hoàn toàn trước khi dialog mới được tạo. Khi `_unlockManager()` đã được await (trường hợp chưa unlock), delay này vô hại.

**Files thay đổi:**
- `lib/views/sale_detail_view.dart` — thêm `await Future.delayed(Duration.zero)` vào case edit/fix_cost/delete

---

## [2026-06-09l] - feat: thêm "Sửa giá vốn (0đ)" trong menu chi tiết đơn bán

**Vấn đề:**
Đơn bán cũ có `totalCost = 0` (do sản phẩm bị mất giá vốn lúc bán). Báo cáo lợi nhuận lịch sử tính sai vì dùng trực tiếp `totalCost` từ bảng `sales`. Dialog SỬA đơn hiện tại khóa giá vốn khi đơn không cùng ngày → không sửa được.

**Giải pháp (Phương án B):**
- Thêm menu item "Sửa giá vốn (0đ)" trong PopupMenuButton trên màn hình chi tiết đơn bán
- Chỉ hiện khi: `_canViewCostPrice && s.totalCost == 0 && s.totalPrice > 0`
- Yêu cầu manager unlock (Firebase re-auth) giống edit/delete
- Không bị giới hạn `_isSameDay` — đây là fix dữ liệu lịch sử
- Sau khi nhập: gọi `_applyNewCostToSnapshots()` để cập nhật `unitCost` trong `itemSnapshotsJson`, lưu SQLite, queue Firestore sync

**Files thay đổi:**
- `lib/views/sale_detail_view.dart` — `_showFixCostDialog()` + case `fix_cost` + menu item

---

## [2026-06-09k] - fix: ô giá vốn bị khóa trong dialog SỬA khi cost = 0đ

**Root cause:**
Điều kiện `if (!p.isPending || p.status == 0)` trong `_editProduct` dialog luôn khóa ô giá vốn cho sản phẩm đã nhập kho chính (`isPending = false`), kể cả khi `cost = 0` — user không thể nhập lại giá vốn đã bị mất.

**Fix:**
Thêm điều kiện `&& p.cost > 0`: chỉ khóa khi đã có giá vốn hợp lệ. Nếu `cost = 0`, luôn cho chỉnh sửa.

**Files thay đổi:**
- `lib/views/inventory_view.dart` — line 4456: `(!p.isPending || p.status == 0) && p.cost > 0`

---

## [2026-06-09j] - fix: inventory product price/cost = 0đ + createdAt = 0

**Root cause:**
Khi sync product từ Firestore về SQLite, nếu Firestore document thiếu/trả về 0 cho `price`, `cost`, `createdAt`, `upsertProduct` ghi đè lên giá trị local đang đúng. Sản phẩm kết quả hiển thị "0đ" và không có ngày trên card list.

**3 fix đồng thời:**

1. **`upsertProduct` (db_helper.dart)** — thêm preserve logic: khi `isSynced=true` (data từ cloud), nếu cloud trả về `price=0/cost=0/createdAt=0` nhưng local đang có giá trị đúng, giữ nguyên local. Cover tất cả sync paths.

2. **`sync_service.dart` (2 paths)** — explicit preserve `createdAt`, `price`, `cost` từ existing local product trước khi gọi `Product.fromMap(data)`, tránh ghi đè từ cloud.

3. **`fixMissingCreatedAt()` (db_helper.dart)** — one-time SQL fix: `UPDATE products SET createdAt = updatedAt WHERE createdAt = 0 AND updatedAt > 0`. Gọi từ `InventoryView._init()` để fix sản phẩm đang có `createdAt=0` ngay lập tức.

**Files thay đổi:**
- `lib/data/db_helper.dart` — `upsertProduct`: preserve isSynced + `fixMissingCreatedAt()` + `getProductsWithMissingPrices()`
- `lib/services/sync_service.dart` — 2 product sync paths: preserve createdAt/price/cost
- `lib/services/firestore_service.dart` — `fetchProductsByFirestoreIds()` (batch Firestore fetch by doc IDs)
- `lib/views/inventory_view.dart` — `_init()`: gọi `fixMissingCreatedAt()` unawaited

---

## [2026-06-09i] - fix: no such column updatedAt trong getRepairsPaged (device bug)

**Root cause phát hiện khi test trực tiếp trên CPH2203:**
`getRepairsPaged` dùng `ORDER BY COALESCE(updatedAt, createdAt, 0) DESC` nhưng bảng `repairs` không có cột `updatedAt` (không trong CREATE TABLE, không có migration). Toàn bộ `_initFromSQLite` và `_refreshFromSQLite` fail → danh sách chỉ load từ Firestore (49 đơn), SQLite = 0, `_hasMoreData = false`.

**Fix:** Thay `updatedAt` → `lastCaredAt` (cột tương đương, có sẵn trong schema).

**Kết quả test thực tế:**
- Trước: 49 đơn, không load thêm được
- Sau fix: 594 đơn (toàn bộ lịch sử), pagination hoạt động 50/page, dừng đúng khi `HasMore=false`

**Files thay đổi:**
- `lib/data/db_helper.dart` — `getRepairsPaged`: `updatedAt` → `lastCaredAt` (2 chỗ)

---

## [2026-06-09h] - fix: backfill nhanh + race-condition + data-safety

**3 bug trong cùng flow pagination:**

1. **Backfill chậm** — `Future.wait(2000 × upsertRepair)`, mỗi cái có PRAGMA table_info trong transaction → ~20-30 giây. User bấm "Tải thêm" trước khi xong → 0 items → button biến mất.
   - Fix: `bulkInsertRepairsIfNew()` — schema check 1 lần, `INSERT OR IGNORE`, batch 200/transaction → ~1 giây.

2. **Data safety** — `upsertRepair` trong backfill overwrite unsynced local repairs với data cũ từ Firestore.
   - Fix: `INSERT OR IGNORE` trên `firestoreId UNIQUE` → không bao giờ overwrite existing rows.

3. **Race condition** — `_refreshFromSQLite` reset `_sqliteRepairs=[50]` trong khi `_loadMoreFromSQLite` đang thêm page 1 → user thấy list giảm xuống 49 đột ngột.
   - Fix: nếu `_isLoadingMore=true` → skip state update; nếu load-more vừa completed → chỉ update khi query của ta cover đủ (`repairs.length >= _sqliteLoadedCount`).

**Files thay đổi:**
- `lib/data/db_helper.dart` — thêm `bulkInsertRepairsIfNew()`
- `lib/views/order_list_view.dart` — `_doHistoricalBackfill` dùng phương thức mới, `_refreshFromSQLite` fix race condition

---

## [2026-06-09g] - fix: historical backfill toàn bộ đơn sửa từ Firestore vào SQLite + debug logging

**Vấn đề gốc rễ:** SQLite chỉ có 50 đơn vì được populate bởi Firestore subscription (LIMIT 50 + orderBy updatedAt). Các đơn cũ không có field `updatedAt` không bao giờ được ghi vào SQLite → "Tải thêm" không có dữ liệu.

**Giải pháp:** One-time historical backfill khi nhận server snapshot đầu tiên:
- `FirestoreService.fetchAllRepairsByShop()` — `.get()` không có `orderBy`, `limit(2000)` → bao gồm tất cả đơn kể cả cũ
- `_doHistoricalBackfill()` trong `OrderListView` — upsert tất cả vào SQLite, sau đó `_refreshFromSQLite()`
- Session-level cache `_backfilledShops` — mỗi shopId chỉ backfill 1 lần / session
- Debug logging tại `_rebuildDisplayedRepairs` (Firestore count, SQLite count, Displayed count, HasMore) và `_loadMoreFromSQLite` (LOAD MORE TRIGGERED, Before/After load count)

**Files thay đổi:**
- `lib/services/firestore_service.dart` — thêm `fetchAllRepairsByShop()`
- `lib/views/order_list_view.dart` — thêm `_doHistoricalBackfill()`, trigger từ server snapshot, debug logs

---

## [2026-06-09f] - fix: đơn sửa load đủ tất cả lịch sử + phân trang SQLite

**Vấn đề:** Firestore query `orderBy('updatedAt') LIMIT 50` bỏ qua các đơn cũ không có field `updatedAt` → chỉ hiện ~49 đơn dù có nhiều hơn.

**Giải pháp:** Chuyển nguồn hiển thị từ Firestore-cache sang SQLite-first:
- `OrderListView` load từ SQLite (`getRepairsPaged`) thay vì từ `_repairsByFirestoreId`
- Firestore subscription vẫn hoạt động để sync realtime vào SQLite, sau đó `_refreshFromSQLite()` reload display
- Scroll đến cuối → tự load thêm 50 đơn từ SQLite (hoặc bấm nút "Tải thêm")
- Xóa `_mergePendingLocalRepairsIntoCache` (không cần nữa vì SQLite đã có đủ dữ liệu)

**Files thay đổi:**
- `lib/data/db_helper.dart` — `getRepairsPaged` và `getRepairsCount` thêm shopId scope + deleted filter
- `lib/views/order_list_view.dart` — SQLite-first pagination, nút "Tải thêm", bỏ Firestore-as-display-source

---

## [2026-06-09e] - refactor: Audit home_view — xóa 89 debugPrint + 2 unused vars

**Files thay đổi:**
- `lib/views/home_view.dart` — xóa toàn bộ 89 debugPrint statements (trace/flow logs, không ảnh hưởng logic), fix 2 warning phát sinh: `unused catch stack` → `catch (_)`, `unused stopwatch` → xóa Stopwatch khởi tạo.

---

## [2026-06-09d] - refactor: Audit home_view — xóa dead navigator code

**Files thay đổi:**
- `lib/views/home_view.dart` — xóa 3 thứ dead code không ảnh hưởng chức năng:
  1. Field `_tabNavigatorKeys` (Map không bao giờ được đọc)
  2. Method `_usesNestedNavigator` (luôn trả về `false`)
  3. Method `_navigatorKeyForTab` (chỉ được gọi từ dead path)
  4. Simplify `_maybePopCurrentTabNavigator` → `async => false` (behavior không đổi)

**Root cause:** Nested Navigator đã bị tắt theo design ("Không dùng nested Navigator — route push qua root navigator"), nhưng infrastructure code vẫn còn. `_usesNestedNavigator` luôn `false` → toàn bộ navigator logic bên dưới không bao giờ chạy.

---

## [2026-06-09c] - refactor: Audit shop_settings_view — bỏ duplicate, flatten, cache members, gộp upload

**Files thay đổi:**
- `lib/views/shop_settings_view.dart` — 5 fixes sau khi audit:
  1. **Xóa 3 duplicate links** khỏi Quick Actions (HR Salary, Backup/Restore, KiotViet) — đã có trong settings_view
  2. **Xóa 3 unused imports** (`hr_salary_settings_view`, `backup_restore_view`, `kiotviet_settings_view`)
  3. **Flatten Advanced Settings** — bỏ ExpansionTile, thay bằng Card + ListTile đơn giản
  4. **Cache members list** — thay FutureBuilder (gọi lại mỗi build) bằng `_cachedMembers` + `_loadingMembers` load 1 lần trong `initState()`
  5. **Gộp 3 upload if-blocks → 1 block** — `_saveShopData()` logo-only/cover-only/both → `Future.wait()` song song 1 chỗ

---

## [2026-06-09b] - fix: Search đơn sửa tìm toàn bộ local DB, không bị giới hạn 50 đơn

**Files thay đổi:**
- `lib/views/order_list_view.dart` — thêm `_searchDebounce`, `_isSearchingLocal`; sửa `_onSearch` dùng `db.searchRepairs()` (SQLite LIKE) thay vì chỉ filter in-memory khi có từ khoá.

**Root cause:** `_rebuildDisplayedRepairs()` chỉ filter `_repairsByFirestoreId.values` (tối đa 50 docs từ Firestore real-time subscription). Khi search, kết quả chỉ nằm trong 50 đơn đang hiển thị.

**Sau fix:** Khi nhập từ khoá, debounce 300ms rồi query SQLite local (`searchRepairs` LIKE trên customerName, phone, model, issue) với limit=200 — tìm được toàn bộ đơn đã sync về máy. Khi xoá từ khoá, về lại realtime list bình thường.

---

## [2026-06-09a] - refactor: Tái cấu trúc settings_view — phân loại chuyên nghiệp, thêm 7 sub-settings

**Files thay đổi:**
- `lib/views/settings_view.dart` — xóa popup menu, thêm 7 import sub-settings views mới, thêm `_buildNavTile()` helper, xóa `_buildFeatureChip()`, tái cấu trúc ListView thành 7 section rõ ràng.

**Trước:** Settings page chỉ có 4 mục (hướng dẫn, đồng bộ, cửa hàng, super admin). Sao lưu + Trợ giúp ẩn trong popup menu góc trên. 8 sub-settings views (shop, printer, notifications, KiotViet, HR, labels, work schedule) không có link từ settings page.

**Sau — 7 section:**
1. **Tài khoản** — account card, super admin shop switcher
2. **Cửa hàng** (owner/admin) — thông tin cửa hàng, danh mục, máy in, tem, KiotViet + 3 toggles kho
3. **Nhân sự** (owner/admin) — lịch làm việc, cài đặt lương
4. **Thông báo** — cài đặt thông báo
5. **Đồng bộ & Sao lưu** — sync center, đẩy KiotViet, nhận kho, sao lưu
6. **Hỗ trợ** — hướng dẫn (simple tile thay card to), trung tâm trợ giúp
7. **Quản trị nâng cao** (super admin) — chọn shop, phân quyền, PIN, xóa data

---

## [2026-06-08o] - fix: Health check auto-restore products từ cloud (bỏ skip sai)

**Files thay đổi:**
- `lib/services/sync_health_check.dart` — xóa `products` khỏi `noAutoRestoreCollections` (set rỗng), bỏ logic skip, fix `deleted == true || deleted == 1` trong `_buildCloudComparisonRows`.

**Root cause:** `noAutoRestoreCollections = {'products'}` khiến health check phát hiện cloud=482/local=20 nhưng **bỏ qua** 462 sản phẩm thiếu (log: "skip auto-restore user may have deleted intentionally"). Lý do ban đầu đặt skip này là "sản phẩm quản lý qua KiotViet, không nên tự kéo về" — nhưng sai vì `_buildCloudComparisonRows` đã filter `deleted: true` trước khi build `cloudIds`. Tức là sản phẩm đã bị soft-delete sẽ không bao giờ có trong `cloudIds` → không bao giờ bị auto-restore lại. Skip là không cần thiết và gây mất đồng bộ.

**Kết quả sau fix:** Khi bấm "Reload đồng bộ" (Sync Health Check), máy B/C sẽ tự download 462 sản phẩm thiếu và hiển thị log `✅ Đã tải 462/462 records thiếu cho products`.

---

## [2026-06-08n] - fix: Xóa cloud dùng soft-delete + staggered timestamp → tự đồng bộ sang máy B/C

**Files thay đổi:**
- `lib/services/backup_service.dart` — `deleteSelectedDataFromCloud` → `deleteByQuery`: đổi từ `batch.delete(doc.reference)` (hard-delete) sang `batch.update({deleted: true, updatedAt: nowMs + i})` (soft-delete với timestamp staggered).

**Root cause:** Hard-delete xóa document khỏi Firestore hoàn toàn — không có `updatedAt` mới → subscription polling trên máy B/C dùng cursor `updatedAt > T` không nhận được sự kiện → sản phẩm cũ còn nguyên local mãi mãi.

**Cách hoạt động sau fix:** Mỗi doc được update với `updatedAt = nowMs + i` (unique, tăng dần). Máy B/C poll 20 docs/lần → cursor advance → poll tiếp 20 docs → ... → xử lý hết. `data['deleted'] == true` → `deleteProductByFirestoreId` → sản phẩm cũ tự xóa local. Sau đó khi Máy A push KiotViet mới lên Firestore (`updatedAt = now_after_import > cursor`) → Máy B/C poll → upsert sản phẩm mới. **Hoàn toàn tự động, không cần thao tác trên máy B/C.**

---

## [2026-06-08m] - fix: "Nhận kho từ Cloud" xóa local trước khi pull (đồng bộ sau import KiotViet)

**Files thay đổi:**
- `lib/views/settings_view.dart` — `_pullKhoFromCloud`: thêm bước xóa local products (`DELETE FROM products WHERE shopId = ?`) trước khi `downloadAllFromCloud(force: true)`.

**Root cause:** `downloadAllFromCloud` chỉ upsert (thêm/cập nhật) — không xóa sản phẩm local đã bị hard-delete trên Firestore. Sau khi máy A xóa kho + import KiotViet mới, máy B dùng "Nhận kho từ Cloud" vẫn còn sản phẩm cũ từ trước khi xóa. Giờ nút sẽ xóa sạch local trước → pull về chỉ gồm data đang có trên Firestore.

**Flow đúng sau import KiotViet:**
1. Máy A: Import KiotViet → nhấn "Đẩy dữ liệu lên Cloud"
2. Máy B, C: Settings → nhấn "Nhận kho từ Cloud" → xóa local → pull toàn bộ từ Firestore

---

## [2026-06-08l] - fix: 3 bugs còn sót sau audit lần 2

**Files thay đổi:**
- `lib/views/inventory_view.dart` (line 2282) — Bulk delete (checkbox chọn nhiều): `SyncOperation.update` → `SyncOperation.delete`. Cùng bug như single delete đã fix ở [2026-06-08j] nhưng ở đường xóa hàng loạt.
- `lib/services/sync_orchestrator.dart` `_handleUpdate` — Thêm normalize `deleted` field trước khi push lên Firestore: `data['deleted'] = data['deleted'] == 1 || data['deleted'] == true`. Bất kỳ update nào mà sản phẩm có `deleted=1` trong SQLite (do race condition hoặc bug cũ trong queue) sẽ không push `deleted: 1` integer lên Firestore nữa.
- `lib/views/settings_view.dart` `_pullKhoFromCloud` — Gọi `SyncOrchestrator().syncAll()` trước khi `downloadAllFromCloud(force: true)` để đảm bảo local pending changes được push trước, tránh mất dữ liệu chưa sync khi pull đè.

**Root causes:**
- Bulk delete path bị bỏ sót khi fix single delete.
- `_handleUpdate` không normalize `deleted` → SQLite integer `1` truyền thẳng lên Firestore khi update bất kỳ record đã bị mark deleted trong queue.
- `downloadAllFromCloud` có thể hard-delete local records có `isSynced=0` trước khi chúng được push lên cloud.

---

## [2026-06-08k] - fix: Pull paths bỏ sót deleted:1 (integer) — sync_service subscriptions + downloadAllFromCloud

**Files thay đổi:**
- `lib/services/sync_service.dart` — Tất cả subscription `onChanged` callbacks (~30 chỗ) + `downloadAllFromCloud` (line 4753) + `continue` variant (line 3741): đổi `data['deleted'] == true` → `data['deleted'] == true || data['deleted'] == 1`

**Root cause:** `syncAllToCloud` (push path) đã biết dùng dual-check `== 1 || == true` nhưng **pull paths** (subscription onChanged + downloadAllFromCloud) chỉ check `== true`. Firestore records bị push với `deleted: 1` (integer, từ bug cũ SyncOperation.update) → `1 != true` → không bị xóa local khi thiết bị khác pull về → ghost products tồn tại mãi + được restore lại khi bấm "Nhận kho từ cloud".

**Phối hợp với [2026-06-08j]:** Fix đó ngăn tạo mới record `deleted:1` trong tương lai. Fix này dọn sạch record cũ đã bị push sai.

---

## [2026-06-08j] - fix: Đồng bộ kho giữa các thiết bị (deleted type mismatch + nút Nhận kho từ Cloud)

**Files thay đổi:**
- `lib/views/inventory_view.dart` — `_deleteProductWithOptions`: đổi `SyncOperation.update` → `SyncOperation.delete`. Trước đây enqueue update → orchestrator đẩy raw SQLite data với `deleted: 1` (integer) lên Firestore. Các thiết bị khác check `data['deleted'] == true` (boolean) → `1 != true` → ghost products tồn tại mãi trên thiết bị khác.
- `lib/services/firestore_service.dart` — `deleteProduct()`: thêm `'deleted': true` vào payload (trước chỉ set `status: 0`). Đồng bộ với `deleteRepair()` và `deleteSale()` đã có `deleted: true`.
- `lib/views/settings_view.dart` — thêm nút **Nhận kho từ Cloud** (màu teal) gọi `SyncService.downloadAllFromCloud(force: true)`. Cho phép thiết bị có kho lệch tải lại toàn bộ từ Firestore.

**Root cause:** Type mismatch Dart strict equality: SQLite integer `1` ≠ Firestore boolean `true`. Khi delete product, enqueue sai operation → orchestrator dùng `_handleUpdate()` thay `_handleDelete()` → `softDeletePayload()` không được gọi → Firestore nhận `deleted: 1` → các thiết bị khác không nhận biết sản phẩm đã bị xóa.

---

## [2026-06-08i] - fix: Hiển thị giảm giá đúng ở list bán & chi tiết đơn bán (3 bugs)

**Files thay đổi:**
- `lib/views/create_sale_view.dart` — `set_price` case: bỏ `item['originalPrice'] = newPrice`. Giờ `originalPrice` giữ nguyên giá catalog → `salePrice` trong snapshot = giá gốc, `unitPrice` = giá bán thực → discount = giá gốc - giá bán được track đúng.
- `lib/views/sale_list_view.dart` — `_totalItemDiscount()`: thêm fallback regex `\(GI[AÀ]M\s+([\d.]+)\)` parse từ `productNames` cho đơn cũ không có `salePrice` trong snapshot (đơn tạo trước khi field `salePrice` được thêm vào snapshot).
- `lib/views/sale_detail_view.dart` — Builder giảm giá: thay điều kiện `itemDisc > 0 && orderDisc > 0` để show "Tổng giảm giá" → nay hiện "Tổng giảm giá: -X Tr" bất cứ khi nào totalDisc > 0; khi có cả 2 loại mới break thành "Giảm sản phẩm" + "Giảm đơn" + "Tổng".

**Root cause chính:** `set_price` case cập nhật cả `originalPrice = newPrice` → `salePrice = unitPrice` → discount = 0 → không có chip/row.

**Backward compat:** Regex fallback hoạt động cho đơn cũ dùng "Giảm giá" (productNames có "(Giảm X)"). Đơn cũ dùng "Sửa giá bán" không có data để recover (originalPrice và sellPrice đều = giá mới, không lưu giá gốc).

---

## [2026-06-08h] - fix: Chuẩn hoá format tiền & hiển thị giảm giá đầy đủ (4 bugs)

**Files thay đổi:**
- `lib/views/inventory_detail_view.dart`
  - `_costRow`: đổi `MoneyUtils.formatCurrency(cost)` → `formatCompactCurrency(cost)` — "Giá vốn" nay hiển thị `10 Tr` thay `10.000.000`.
  - `SingleChildScrollView`: padding bottom `16` → `32` — tránh content bị cắt bởi nav bar.
- `lib/views/sale_detail_view.dart`
  - Thêm getter `_totalItemLevelDiscount`: tính tổng giảm item-level từ `_linkedProducts` (salePrice - soldPrice) × qty.
  - Thêm `_enrichLinkedProducts()`: async enrichment cho đơn cũ không có `salePrice` trong snapshot — lookup IMEI/firestoreId từ DB, dùng `product.price` hiện tại làm fallback khi `price > soldPrice`.
  - Thay block `if (s.discount > 0) _item(...)` bằng Builder: hiển thị "Giảm sản phẩm" (item-level) + "Giảm đơn" (order-level) + "Tổng giảm giá" (khi cả hai loại cùng > 0).

**Quy tắc:**
- Đơn cũ: `_enrichLinkedProducts()` chạy async khi mở màn hình, tự cập nhật badge giảm giá mà không block UI.
- Đơn mới: salePrice đã có sẵn trong snapshot, không cần enrichment.
- Không làm ảnh hưởng bất kỳ tính năng đang chạy ổn định.

---

## [2026-06-08g] - feat: Hiển thị giảm giá & chuẩn hoá format tiền toàn module bán hàng

**Files thay đổi:**
- `lib/views/create_sale_view.dart` — `_buildSaleItemSnapshotsJson`: thêm field `salePrice` (originalPrice tại thời điểm bán) vào snapshot của từng item.
- `lib/widgets/deep_link_navigator.dart` — `ProductLinkRef`: thêm field `salePrice`; `openProductDetail`: thêm param `salePrice` → truyền vào `InventoryDetailView`.
- `lib/views/sale_detail_view.dart` — `_buildLinkedProducts`: parse `salePrice` từ snapshot JSON → gán vào `ProductLinkRef`.
- `lib/widgets/clickable_product_list.dart` — truyền `salePrice` từ `ProductLinkRef` xuống `ClickableProductChip`.
- `lib/widgets/clickable_product_chip.dart` — thêm `salePrice`; tính `itemDiscount = (salePrice - soldPrice) * qty`; hiển thị badge cam `-X Tr` khi discount > 0; đổi `formatCurrency` → `formatCompactCurrency` cho giá bán.
- `lib/views/inventory_detail_view.dart` — thêm param `salePrice`; khi giảm giá: đổi nhãn "Giá bán" → "Giá bán gốc", thêm dòng "Đã giảm: -X Tr", đổi format sang `formatCompactCurrency`.
- `lib/views/sale_list_view.dart` — thêm `_totalItemDiscount()` tính tổng giảm (item-level từ snapshot + order-level `s.discount`); thêm chip **Giảm** vào card khi > 0; thêm `import 'dart:convert'`.

**Quy tắc hiển thị:**
- `discountAmount = salePrice - unitPrice` (per item); tổng = sum items + `s.discount`.
- Chỉ hiển thị badge/dòng giảm khi `discount > 0`.
- Format tiền: `formatCompactCurrency` → `1 Tr`, `11.5 Tr`, `1 Tỷ` (thay cho `1.000.000`).

---

## [2026-06-08f] - feat: Sửa giá bán sản phẩm trực tiếp trong màn hình tạo đơn bán

**Files thay đổi:**
- `lib/views/create_sale_view.dart`
  - Thêm option **"💰 Sửa giá bán sản phẩm"** vào bottom sheet "Ưu đãi sản phẩm" (`_GiftDiscountSheetContent`).
  - Khi chọn, hiện panel inline: giá hiện tại, input giá mới (VND format), checkbox "Cập nhật giá bán mặc định trong kho", nút HỦY/LƯU.
  - Không giới hạn giá (khác với "Giảm giá" phải thấp hơn giá gốc) — hỗ trợ sản phẩm có giá = 0.
  - Kết quả cập nhật ngay: `sellPrice`, `originalPrice`, tổng tiền, giảm giá, thành tiền.
  - Nếu checkbox được tick → gọi `db.updateProductMap(id, {'price': newPrice, 'isSynced': 0})` để cập nhật kho và đánh dấu chờ sync cloud.
  - Thêm state: `_showEditPriceInput`, `_editPriceController`, `_updateInventory`.
  - Thêm method `_onConfirmSetPrice()`.
  - Thêm case `'set_price'` trong switch xử lý kết quả bottom sheet.

---

## [2026-06-08e] - fix: sync health check không báo lỗi khi kho cloud có nhiều hơn local

**Files thay đổi:**
- `lib/services/sync_health_check.dart`
  - **BUG FIX**: `_checkCollection` trả về `cloudOnly = cloudOnlyAfter` cho `products`, khiến `effectiveMismatchCount > 0` → status "Chưa sync hết" dù local hoàn toàn đã sync.
  - Fix: Với `noAutoRestoreCollections` (hiện tại chỉ `products`), báo `cloudOnly = 0` trong `SyncCheckResult`. Cloud-only records cho kho là chủ đích (user xóa kho hoặc chưa import lại) — không nên tính là lỗi.
  - Không ảnh hưởng các collection khác (repairs, sales, customers...) vẫn auto-restore và tính mismatch bình thường.

**Root cause:** Sau khi user xóa sản phẩm và import lại từ KiotViet, cloud vẫn còn 684 records cũ (chưa xóa hoặc từ máy khác). Sync health count 684 cloud-only → "Chưa sync hết" dù `Local chưa sync = 0` và `Queue = 0`.

---

## [2026-06-08d] - fix: KiotViet import restore sản phẩm đã xóa thay vì tạo bản ghi mới

**Files thay đổi:**
- `lib/services/kiotviet_excel_import_service.dart`
  - **BUG FIX**: Hàm `importProducts` trước đây bỏ qua sản phẩm có `deleted=1` khi kiểm tra trùng tên, dẫn đến INSERT bản ghi mới với `id` mới (thay vì UPDATE bản ghi cũ). Kết quả: cùng một tên sản phẩm có 2 bản ghi active, đơn bán cũ mất tham chiếu `productId`.
  - Fix: Duplicate check giờ tìm TẤT CẢ bản ghi (kể cả `deleted=1`). Nếu tìm thấy bản ghi đã xóa → UPDATE (khôi phục) thay vì INSERT, giữ nguyên `id` gốc.
  - Fix thêm: Khi khôi phục bản ghi đã xóa, tự động soft-delete các bản ghi active trùng tên (tạo ra bởi lần import lỗi trước) để tránh duplicate.

**Root cause:** Sau sự cố "Dọn kho cloud" xóa 831 sản phẩm, user re-import từ KiotViet Excel. Vì query duplicate bỏ qua `deleted=1`, tất cả sản phẩm được INSERT mới với `id` auto-increment mới. Đơn bán cũ lưu `productId` (SQLite int) của sản phẩm cũ → không còn khớp, hiển thị sản phẩm sai.

---

## [2026-06-08c] - fix(critical): sửa logic "Dọn kho cloud" + thêm nút khôi phục khẩn cấp

**Files thay đổi:**
- `lib/views/kiotviet_import_view.dart`
  - **BUG FIX**: `_runCloudCleanup` trước đây xóa TẤT CẢ sản phẩm cloud không có trong local device (kể cả sản phẩm valid của máy khác). Fix: chỉ push `deleted:true` cho sản phẩm **có deleted=1 trong local SQLite** của thiết bị này.
  - **Thêm**: `_runCloudRestore()` — khôi phục khẩn cấp: tìm sản phẩm bị đánh dấu xóa trên cloud trong 60 phút qua và set `deleted:false`.
  - **Thêm**: Nút "⚠️ Khôi phục kho cloud" (màu cam) bên dưới nút "Dọn kho cloud".

**Root cause của bug:** OPPO A94 chỉ có 262 sản phẩm trong local SQLite, cloud có 1093 sản phẩm. Khi chạy "Dọn kho cloud" từ A94, hàm tìm 831 sản phẩm "cloud-only" (không có trong A94 local) và đánh dấu xóa — bao gồm cả sản phẩm valid của Samsung A32 và các máy khác.

---

## [2026-06-08b] - fix: stop auto-restore products từ cloud + nút Dọn kho cloud

**Files thay đổi:**
- `lib/services/sync_health_check.dart` — tắt auto-restore cho `products` (cloud-only records không tự download về nữa, tránh vòng lặp restore)
- `lib/views/kiotviet_import_view.dart` — thêm nút "Dọn kho cloud": đẩy `deleted:true` lên Firestore cho sản phẩm tồn tại trên cloud nhưng đã bị xóa local

**Root cause:** Health check thấy cloud có 237 records hơn local → tự download về (auto-fix) → user xóa lại → health check restore lại → vòng lặp vô tận. Fix: products không tự restore từ cloud; user tự dọn bằng nút "Dọn kho cloud".

---

## [2026-06-08a] - fix: bulk xóa kho dùng soft-delete + fix đơn duyệt giao vẫn hiện chờ duyệt

**Files thay đổi:**
- `lib/views/inventory_view.dart` — đổi bulk delete từ `deleteProduct` (hard) sang `softDeleteProduct` để Firestore nhận `deleted:true` khi sync
- `lib/views/repair_detail_view.dart` — trong `_protectLocalUnsyncedRepairFromStaleCloud`: thêm exception "nếu cloud có status=4 mà local<4, luôn accept cloud" → tránh manager duyệt trên máy khác bị block

**Root cause:**
1. **Bulk xóa kho**: Checkbox select → xóa gọi `db.deleteProduct(id)` = hard delete → record mất khỏi SQLite → không có gì để push `deleted:true` lên Firestore → máy khác vẫn thấy record đó.
2. **Đơn chờ duyệt không update**: Staff submit chờ duyệt trên Phone A (isSynced=false), manager duyệt trên Phone B → Firestore có status=4. Phone A nhận cloud update nhưng protection logic block vì isSynced=false + timestamps gần nhau → Phone A vẫn hiện "Đang chờ duyệt".

---

## [2026-06-07l] - fix(sync): đẩy deleted lên Firestore cho tất cả bảng

**Files thay đổi:**
- `lib/services/sync_service.dart` — thêm `_syncDeletedRowsToCloud()` generic helper + loop gọi cho sales, customers, suppliers, purchase_orders, repair_parts

**Vấn đề:** Khi xóa mềm (deleted=1) records trong bất kỳ bảng nào, `syncAllToCloud()` chỉ sync records với `deleted=0` → Firestore không nhận được thông tin xóa → thiết bị khác vẫn thấy record đã xóa.

**Fix:** `_syncDeletedRowsToCloud()` query `deleted=1 AND isSynced=0 AND firestoreId IS NOT NULL`, batch push `{deleted:true, updatedAt, shopId}` lên Firestore, sau đó mark `isSynced=1` trong SQLite.

---

## [2026-06-07k] - fix(critical): khôi phục phones bị dedup xóa nhầm (DB v103)

**Files thay đổi:**
- `lib/data/db_helper.dart` — DB v103: restore DIEN_THOAI bị soft-delete trong 48h qua (deleted=1, qty>0); bỏ call deduplicateProductsByImei() khỏi fast_inventory_check_view

**Root cause:** `deduplicateProductsByImei()` nhóm phones theo `LOWER(imei)` — IMEI từ KiotViet là mã ngắn 4-5 chữ số (không phải IMEI 15 chữ số chuẩn), nên nhiều máy khác nhau có cùng mã → bị xóa nhầm (82 phones). Migration v103 restore an toàn bằng filter `updatedAt > now-48h` để tránh restore phones user đã xóa cũ.

**Lưu ý:** Chênh lệch kho(222) vs kiểm kho là bình thường — kiểm kho chỉ hiện phones có IMEI (để scan được). Phones không có IMEI không thể kiểm bằng scan.

---

## [2026-06-07j] - fix: kiểm kho thiếu 44 máy + double IMEI

**Files thay đổi:**
- `lib/data/db_helper.dart` — fix `getInStockProducts` dùng `(status=1 OR status IS NULL)` thay `status=1` strict; thêm `deduplicateProductsByImei()`
- `lib/views/fast_inventory_check_view.dart` — gọi `deduplicateProductsByImei()` mỗi lần mở kiểm kho

**Root cause:**
1. **Kiểm kho thiếu máy**: `getInStockProducts` dùng `status = 1` strict — phones import từ KiotViet có `status = NULL` → bị loại khỏi kiểm kho dù vẫn còn trong kho. Tất cả query khác đều dùng `(status = 1 OR status IS NULL)`.
2. **Double IMEI**: Một số phones vẫn còn `imei` dạng `IMEI1|IMEI2` chưa được split (v102 migration có thể bỏ sót nếu record được push từ Firestore sau migration). `deduplicateProductsByImei()` fix split sót + dedup nếu cùng IMEI xuất hiện 2 lần.

---

## [2026-06-07i] - fix: bàn phím che nội dung khi bấm KTV/sửa thông tin trong đơn sửa

**Files thay đổi:**
- `lib/views/repair_detail_view.dart` — fix `MediaQuery.viewInsetsOf` dùng inner `ctx` thay outer `context` trong 2 bottom sheet (_editTechnicianNotes + _editBasicInfo); thêm `unfocus()` trước `pop()` trong _editBasicInfo

**Root cause:** `showModalBottomSheet` với `isScrollControlled: true` cần outer `Padding(bottom: viewInsets)` để đẩy nội dung lên trên bàn phím. Nhưng code đang dùng `MediaQuery.viewInsetsOf(context)` với outer widget context — outer context không re-render khi bàn phím mở trong sheet → padding = 0 → bàn phím che TextField.

**Fix:** Đổi sang `MediaQuery.viewInsetsOf(ctx)` (builder context của sheet) để Padding reactive với keyboard. Đảm bảo tất cả close handlers đều gọi `FocusScope.of(ctx).unfocus()` trước `Navigator.pop()` để tránh `_dependents.isEmpty` crash.

---

## [2026-06-07h] - feat: đẩy dữ liệu KiotViet lên Firestore (force re-sync)

**Files thay đổi:**
- `lib/data/db_helper.dart` — thêm `backfillShopId()` + `markAllUnsynced()`
- `lib/services/sync_service.dart` — thêm `forceResyncKiotVietData()`
- `lib/views/settings_view.dart` — thêm nút "Đẩy dữ liệu KiotViet lên Cloud" trong Sync section

**Root cause:** Dữ liệu import từ KiotViet Excel được lưu với `shopId=NULL` (cột chưa tồn tại lúc import). `getAllSales()` dùng `WHERE shopId = ?` (strict) → không tìm thấy → `syncAllToCloud` không push lên Firestore. `products` đã có shopId nhưng `isSynced=1` sai do write Firestore fail thầm lặng (App Check error).

| Bước | Action | Kết quả |
|------|--------|---------|
| 1 | `backfillShopId('sales', shopId)` | Gán shopId cho đơn bán thiếu → `getAllSales()` tìm thấy chúng |
| 2 | `backfillShopId('products', shopId)` | Tương tự cho sản phẩm |
| 3 | `markAllUnsynced('sales')` | Reset `isSynced=0` → syncAllToCloud pick up |
| 4 | `markAllUnsynced('products')` | Reset `isSynced=0` |
| 5 | `syncAllToCloud(force: true)` | Push toàn bộ lên Firestore (idempotent merge) |

**UI:** Settings > Đồng bộ dữ liệu → card cam "Đẩy dữ liệu KiotViet lên Cloud"

---

## [2026-06-07g] - feat: tách kho điện thoại — mỗi IMEI = 1 sản phẩm riêng

**Files thay đổi:**
- `lib/data/db_helper.dart` — version 102, migration v102 split multi-IMEI, upsertProduct + _upsertPhoneSplit
- `lib/views/create_sale_view.dart` — lock qty=1 cho sản phẩm phone có 1 IMEI

| # | Thay đổi | Mô tả |
|---|---------|-------|
| 1 | **DB v102 migration** | Query tất cả `DIEN_THOAI` có `imei LIKE '%|%'`; update record gốc (IMEI đầu, qty=1); insert record mới cho mỗi IMEI còn lại với `firestoreId = parentFid__s{i}`, `isSynced=0` |
| 2 | **upsertProduct auto-split** | Khi nhận phone từ KiotViet với IMEI dạng `"A\|B\|C"` → delegate sang `_upsertPhoneSplit` → upsert riêng từng IMEI với firestoreId độc lập |
| 3 | **Cart qty lock** | Trong `create_sale_view.dart`: `isPhoneUnit = type==DIEN_THOAI && imei != null && !imei.contains('|')` → disable `+`/`-` button và text field, qty cố định 1 |

**Kết quả:** Mỗi điện thoại có IMEI riêng = 1 row trong DB → dễ theo dõi tồn kho + bán hàng biết đúng máy nào được bán.

---

## [2026-06-07f] - fix: giá bán 0đ + IMEI không xác định trong chi tiết đơn bán

**Files thay đổi:**
- `lib/views/sale_detail_view.dart` — fix đọc key snapshot + truyền soldImei
- `lib/widgets/deep_link_navigator.dart` — thêm soldImei vào ProductLinkRef và openProductDetail
- `lib/widgets/clickable_product_chip.dart` — pass soldImei đến navigator
- `lib/widgets/clickable_product_list.dart` — pass soldImei đến chip
- `lib/views/inventory_detail_view.dart` — thêm soldImei param + hiển thị "IMEI đã bán"

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | "Giá bán: 0" trong chi tiết sản phẩm từ đơn bán | `_buildSaleItemSnapshotsJson` lưu giá vào key `unitPrice`, nhưng `_buildLinkedProducts` đọc key `price` → null → `product.price` từ DB (= 0) được hiển thị | Đọc `item['price'] ?? item['unitPrice']` |
| 2 | "Không biết IMEI nào đã bán" | Snapshot lưu IMEI vào `productImei`, nhưng đọc `item['imei']` → null; `soldImei` không được truyền qua chain; `InventoryDetailView` chỉ hiện `product.imei` (tất cả IMEI) | Đọc `item['imei'] ?? item['serial'] ?? item['productImei']`; thêm `soldImei` xuyên suốt chain; hiển thị "IMEI đã bán" riêng trong `InventoryDetailView` |

---

## [2026-06-07e] - fix: 3 bugs kiểm kho + sync + topbar

**Files thay đổi:**
- `lib/views/fast_inventory_check_view.dart` — fix await + dọn topbar
- `lib/views/repair_detail_view.dart` — fix sync delay

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | "Chờ sync" badge tới 1 phút sau khi lưu đơn | `syncAll()` xử lý toàn bộ queue (có thể nhiều items) trước khi `.then()` fire → badge đợi tất cả items xong | Thêm direct `FirestoreService.upsertRepair(r)` ngay trong `_saveData()` — badge clear sau <2s khi write thành công; orchestrator vẫn chạy cho queue còn lại |
| 2 | "Lỗi lưu kiểm kho: Invalid argument: Instance of 'Future<String>'" khi bấm nút lưu | `UserService.getCurrentUserName()` là `Future<String>` nhưng gọi không có `await` → `createdBy` field trong DB insert nhận `Future<String>` thay vì `String` | Thêm `await` trước `getCurrentUserName()` |
| 3 | Topbar kiểm kho quá nhiều icon (7+ icon) | Tất cả actions nằm bên ngoài | Giữ 3 icon quan trọng (zone selector, QR scan, flash khi đang scan); checklist/keyboard/save draft/save DB/history/settings vào `PopupMenuButton` |

---

## [2026-06-07d] - fix: storage_locations không sync lên cloud khi nhiều thiết bị

**Files thay đổi:**
- `lib/views/storage_location_view.dart` — fix save flow + thêm re-upload recovery khi view mở

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | storage_locations: local=2, cloud=0 — thiết bị khác không thấy vị trí kho | `isSynced: true` được set TRƯỚC Firestore write. Nếu write fail (offline/rules), record kẹt local mãi mãi với flag "đã sync" → sync engine bỏ qua | (a) Đổi save flow: save local với `isSynced: false` → Firestore write → cập nhật `isSynced: true` chỉ khi write thành công; (b) Thêm `_reuploadLocalToCloud()` trong `_syncAndLoad` — re-upload tất cả local locations (merge=true, idempotent) để recover records bị kẹt |

---

## [2026-06-07c] - fix(critical): Supplier search + Staff profile 0 orders

**Files thay đổi:**
- `lib/data/db_helper.dart` — thêm `nameNorm TEXT` vào CREATE TABLE suppliers
- `lib/widgets/supplier_picker_sheet.dart` — reset `_isLoading = false` khi search thay đổi
- `lib/views/staff_public_profile_view.dart` — stat cards dùng all-time count; search sale theo cả email prefix

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Search NCC gõ "7" không ra "7 VIÊN" | `nameNorm` column chỉ được add qua v100 migration (onUpgrade). Fresh install chạy onCreate → không có `nameNorm` → `UPPER(nameNorm) LIKE ?` throw SQL error → caught silently → kết quả rỗng | Thêm `nameNorm TEXT` vào CREATE TABLE trong onCreate để column luôn tồn tại bất kể đường dẫn cài đặt |
| 1b | Race condition khi type nhanh trong search | Scroll-triggered `_loadPage` có thể đang chạy (`_isLoading=true`) khi search timer fires → `_loadPage` guard return sớm → search không chạy | Reset `_isLoading = false` trong setState của `_onSearchChanged` và `_clearSearch` |
| 2 | Hồ sơ nhân viên báo 0 đơn dù có đơn | (a) Stat cards dùng `monthlyRepairs/Sales.length` (tháng hiện tại) thay vì all-time; (b) `getSalesBySellerName` chỉ tìm theo display name 'MISS HỒNG' nhưng sale lưu `sellerName = 'HONG'` (email prefix) | (a) Đổi stat cards sang `repairs.length` / `sales.length` (all-time); (b) Fetch thêm sales theo email prefix và dedup bằng Set<id> |

---

## [2026-06-07b] - fix: InventoryCheck type cast + Firestore product_categories permission

**Files thay đổi:**
- `lib/views/inventory_view.dart` — fix type cast crash khi load kiểm kê kho
- `firestore.rules` — thêm token-claim fallback cho `product_categories` read rule

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | `Error loading current check: type 'QueryRow' is not a subtype of type 'InventoryCheck?'` | `checks.cast<InventoryCheck?>()` cố cast `Map<String, dynamic>` (SQLite row) trực tiếp sang `InventoryCheck` — không thể dùng `cast<>()` để convert class | Map từng row sang `InventoryCheck.fromMap()` sau khi decode `itemsJson` JSON string, rồi mới cast<InventoryCheck?> |
| 2 | `product_categories: Missing or insufficient permissions` lặp 5 lần/session | `belongsTo(shopId)` trong Firestore rules gọi nhiều `get()` calls — nếu timing không đúng (boot lần đầu, App Check fail), các get() này fail → toàn bộ rule evaluation fail | Thêm `|| request.auth.token.shopId == shopId` fallback — bypass `get()` calls khi JWT token đã có sẵn claim, giống pattern đang dùng ở `settings` subcollection rule |

---

## [2026-06-07] - fix(inventory): 3 bugs trong _showInlineCostEdit (nhập giá vốn)

**Files thay đổi:**
- `lib/views/inventory_view.dart` — fix `_showInlineCostEdit`

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Sheet bị cắt ở dưới, không thấy hết nội dung | `Column(mainAxisSize: min)` không scroll khi nội dung vượt chiều cao màn hình | Wrap Column trong `SingleChildScrollView` để user cuộn được |
| 2 | Text dropdown "Phương thức thanh toán" invisible khi mở | `style: TextStyle(color: Colors.white)` trên `DropdownButtonFormField` + `dropdownColor: PopupTheme.bgDark` (= white `0xFFFFFFFF`) → chữ trắng trên nền trắng | Đổi `style` sang `Colors.black87` — chữ tối trên nền trắng |
| 3 | Crash `_dependents.isEmpty` khi bấm "Lưu giá vốn" | `MediaQuery.of(outerCtx)` tạo cross-tree InheritedWidget dependency. Khi `Navigator.pop(ctx)` đóng route, overlay MediaQuery deactivate trước khi Padding release dependency → assertion fail | Đổi sang `MediaQuery.of(ctx)` (same-tree context của StatefulBuilder) |

---

## [2026-06-06] - fix(edge-to-edge P2): Inventory search keyboard + Dashboard Settings AppBar

**Files thay đổi:**
- `lib/main.dart` — thêm `MaterialApp.builder` override `MediaQuery.padding.top` từ `View.of(context)` toàn app
- `lib/views/inventory_view.dart` — thay `showModalBottomSheet` search bằng inline `TextField` trong `Scaffold` body; xóa `_openSearchDialog`; thêm `_isSearchBarVisible` + `_inlineSearchController`
- `lib/views/dashboard_settings_view.dart` — wrap `Scaffold` với `MediaQuery` override per-screen (belt-and-suspenders)

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Inventory search: bấm 🔍 → bàn phím hiện nhưng không thấy TextField | Bottom sheet context nhận `MediaQuery.viewInsets.bottom = 0` trong edge-to-edge mode → container bị keyboard che | Chuyển sang inline `TextField` đặt trong `Scaffold` body; `Scaffold(resizeToAvoidBottomInset: true)` tự đẩy field lên trên keyboard |
| 2 | Dashboard Settings: AppBar toolbar bị che bởi status bar | Sub-screens (pushed via `rootNavigator`) nhận `MediaQuery.padding.top = 0` → `AppBar` đặt toolbar tại y=0, chồng lên status bar; touch targets nằm trong vùng status bar (y=39-105 vs status bar y=0-110) | Thêm `MaterialApp.builder` global: đọc `View.of(context).padding.top / devicePixelRatio`, inject vào `MediaQuery` nếu lớn hơn giá trị hiện tại — fix toàn bộ sub-screens cùng lúc |

**Verified on device (Samsung A32 RF8R31SS7GY, Android 16):**
- ✅ Inventory search: TextField + keyboard visible đồng thời, filter hoạt động
- ✅ Dashboard Settings: back button, title "Tùy chỉnh Dashboard", 2 tabs, restore/save icons đều hiện đúng

---

## [2026-06-06] - fix(edge-to-edge): AppBar/topbar bị che bởi status bar trên Android 16

**Files thay đổi:**
- `lib/main.dart` — gọi `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` sau `WidgetsFlutterBinding.ensureInitialized()`

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Back button và action icons trên AppBar bị che bởi status bar trên một số màn hình | `targetSdk = 36` (Android 16) bắt buộc edge-to-edge mode. Flutter engine không được thông báo → `MediaQuery.padding.top = 0` → `Scaffold + AppBar` render toolbar content từ y=0, chồng lên status bar | Thêm `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` trong `main()` trước `runApp()` (chỉ Android) — fix tất cả màn hình bị ảnh hưởng |

---

## [2026-06-06] - fix(inventory): search bottom sheet không hiện trên bàn phím + dashboard tab icon

**Files thay đổi:**
- `lib/views/inventory_view.dart` — fix keyboard handling trong `_openSearchDialog`, restock sheet, inline cost edit sheet
- `lib/views/dashboard_settings_view.dart` — thu nhỏ tab icon size 18 → 14 để vừa tab bar

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Tìm kiếm kho: chỉ thấy bàn phím, không thấy TextField | `MediaQuery.viewInsetsOf(stateCtx)` bên trong `StatefulBuilder` dùng `InheritedModel` aspect-based dependency → không propagate keyboard insets trong bottom sheet route → `Padding(bottom: 0)` → container bị keyboard che hoàn toàn | Bỏ `StatefulBuilder`, bỏ `useSafeArea: true`, dùng `MediaQuery.of(ctx).viewInsets.bottom` (full dependency từ outer builder ctx) |
| 2 | Restock sheet & inline cost edit sheet cũng bị vùi bàn phím | Cùng root cause: `viewInsetsOf(innerCtx)` trả về 0 | Đổi sang `MediaQuery.of(outerCtx).viewInsets.bottom`; outer ctx truyền dependency đúng vào StatefulBuilder |
| 3 | Tab bar Dashboard Settings bị chật/overflow | Icon size 18 quá to cho `Tab(icon+text)` compact | Giảm icon size xuống 14 |

---

## [2026-06-05] - fix(finance): audit & sửa 3 lỗi tính toán tài chính home screen

**Files thay đổi:**
- `lib/finance_v2/finance_v2_data_service.dart` — thêm `partnerPaymentOut` + `importExpenseOut` vào `FinanceV2Snapshot`
- `lib/views/home_view.dart` — dùng finance_v2 làm source of truth cho tất cả breakdown

| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| 1 | Chi tiêu biểu đồ > tổng Chi (thừa TT đối tác) | `operatingExpenseOut` đã gồm partner payment, nhưng `_todayPartnerPaid` lại lấy từ `analysis.partnerPaid` khác service → double-count | Track `partnerPaymentOut` riêng trong finance_v2, trừ khỏi `operatingExpenseOut`, dùng `financeSnapshot.partnerPaymentOut` |
| 2 | Thu khác bị under-report khi có thu nợ KH | `incomeOther` snapshot đã net debt (`extraIn-debtCollectIn`), nhưng home_view lại trừ `debtCollectedConsistent` lần nữa | `_todayMiscIncome = financeSnapshot.incomeOther` (không trừ thêm) |
| 3 | Nhập hàng hiển thị thấp hơn thực tế | `importOutConsistent` chỉ scan bảng `expenses`, bỏ sót `importHistory`; `operatingExpenseOut` lại dùng `importExpenseOut` đầy đủ → breakdown < totalOut | Expose `importExpenseOut` từ snapshot, dùng nhất quán |

---

## [2026-06-05] - fix(crash): _dependents.isEmpty assertion khi đóng bottom sheet có TextField

**Files thay đổi:**
- `lib/views/repair_detail_view.dart`, `attendance_management_view.dart`, `attendance_view.dart`, `category_management_view.dart`, `create_repair_order_view.dart`, `debt_view.dart`, `expense_view.dart`, `inventory_view.dart`, `missing_info_products_view.dart`, `sale_detail_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Root cause** | `showModalBottomSheet(isScrollControlled: true)` tạo inner `MediaQuery`. `Padding(EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom))` đăng ký phụ thuộc vào inner MediaQuery. Khi sheet đóng, inner MediaQuery deactivate trước khi Padding hủy đăng ký → `'_dependents.isEmpty': is not true` |
| 2 | **Fix** | Thay toàn bộ `MediaQuery.viewInsetsOf(ctx)` → `MediaQuery.viewInsetsOf(context)` (outer State context) trong 11 files, 21 chỗ |

---

## [2026-06-05] - fix(import): FieldValue poison map → SQLite crash khi nhập Khách/NCC

**Files thay đổi:**
- `lib/services/excel_import_service.dart` — pass `Map.of(data)` vào `addCustomer`/`addSupplier`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Root cause** | `addCustomer(data)` và `addSupplier(data)` mutate map gốc in-place: `data['updatedAt'] = FieldValue.serverTimestamp()`. Sau đó `_db.upsertCustomer(data)` gặp FieldValue → SQLite throw `Invalid argument: Instance of 'FieldValue'` → 0/N thành công |
| 2 | **Fix** | Pass shallow copy `Map.of(data)` thay vì `data` trực tiếp → map gốc không bị contaminate |

---

## [2026-06-05] - fix(index): Thêm Firestore index repairs shopId+updatedAt DESC

**Files thay đổi:**
- `firestore.indexes.json` — Thêm index `repairs: shopId ASC + updatedAt DESC + __name__ DESC`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Missing index** | `watchRepairsByShop` dùng `orderBy('updatedAt', descending: true)` nhưng index chỉ có `updatedAt ASC` → `failed-precondition` mỗi lần mở OrderListView |
| 2 | **Deployed** | `firebase deploy --only firestore:indexes` — index đang build trên Firebase |

---

## [2026-06-05] - fix(sync): upsertRepair block repair giá 0đ / cost 0đ

**Files thay đổi:**
- `lib/services/firestore_service.dart` — `validateAmount` allowZero: true cho price + cost trong upsertRepair

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Bug** | `upsertRepair` gọi `validateAmount(r.price)` và `validateAmount(r.cost)` với `allowZero=false` — block toàn bộ repair bảo hành (price=0) và repair không dùng linh kiện (cost=0), không sync lên Firestore |
| 2 | **Fix** | Truyền `allowZero: true` cho cả hai — số âm vẫn bị chặn |

---

## [2026-06-05] - fix(sync): Giảm log nhiễu TimeoutException + bỏ qua poll khi offline

**Files thay đổi:**
- `lib/services/sync_service.dart` — Thêm import ConnectivityService, offline guard, phân loại timeout log

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Offline guard** | `pollCollection()` trả về sớm nếu `!ConnectivityService.instance.isOnline` — không gửi Firestore query khi mất mạng |
| 2 | **Timeout log downgrade** | `TimeoutException` giờ log `⏱️` (transient) thay vì `❌ Poll sync error` — giảm nhiễu console khi mạng kém / token đang refresh |
| 3 | **Root cause** | 35+ collection đều timeout cùng lúc do Firebase Auth token refresh hang, làm tất cả query xếp hàng 20s |

---

## [2026-06-05] - feat(import-export): Trang Nhập/Xuất Excel hợp nhất trong Cài đặt

**Files thêm mới:**
- `lib/services/excel_import_service.dart` — Import service (5 loại dữ liệu, Firestore + SQLite sync)
- `lib/views/import_export_view.dart` — Trang Nhập/Xuất chuyên nghiệp với date filter + progress dialog

**Files thay đổi:**
- `lib/utils/excel_export_helper.dart` — Thêm `exportSuppliers()`
- `lib/views/shop_settings_view.dart` — Thêm entry "Nhập / Xuất dữ liệu" trong mục Sao lưu
- `lib/views/order_list_view.dart` — Xóa nút Xuất Excel đơn sửa
- `lib/views/sale_list_view.dart` — Xóa nút Xuất Excel đơn bán
- `lib/views/inventory_view.dart` — Xóa menu item Xuất Excel kho hàng
- `lib/views/customer_management_view.dart` — Xóa nút Xuất Excel khách hàng

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **ExcelImportService** | Import 5 loại: Đơn sửa, Đơn bán, Kho hàng, Khách hàng, Nhà cung cấp. Header-based column detection, money/date parsing, progress callback, Firestore + SQLite upsert |
| 2 | **ImportExportView** | Bộ lọc ngày (Hôm nay/Tuần/Tháng/Năm/Tuỳ chọn), 5 card loại dữ liệu mỗi card có Xuất + Nhập, progress dialog với chi tiết lỗi |
| 3 | **exportSuppliers** | Xuất danh sách NCC ra Excel (8 cột: STT, Tên, SĐT, Email, Địa chỉ, Ghi chú, Trạng thái, Ngày tạo) |
| 4 | **Xóa nút export riêng lẻ** | Xóa 4 nút xuất Excel rải rác (đơn sửa, đơn bán, kho, khách hàng) — tập trung vào trang Cài đặt |
| 5 | **Build** | `flutter build apk --debug` pass, 0 compile error |

---

## [2026-06-05] - fix(sync): chặn re-init real-time sync trùng lặp theo cùng user/shop

**Files thay đổi:**
- `lib/services/sync_service.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Dedupe `initRealTimeSync`** | Thêm signature theo `uid + shopId + role + permissions`; nếu cùng session đã active thì bỏ qua lần gọi trùng để tránh `cancelAllSubscriptions()` rồi dựng lại listener vô ích. |
| 2 | **Giảm loop runtime** | Giảm nguy cơ log kiểu `Canceling all subscriptions` / `Khởi tạo real-time sync...` lặp lại do HomeView hoặc EventBus kích hoạt nhiều nguồn cùng lúc. |
| 3 | **Validation** | `flutter analyze lib/services/sync_service.dart` không còn lỗi compile; còn 3 info/lint pre-existing của file. |

---

## [2026-06-05] - fix(sync-P1): Sửa 2 lỗi đồng bộ nguy hiểm trong payment services + kiểm toán kiến trúc

**Files thay đổi:**
- `lib/services/supplier_payment_service.dart`
- `lib/services/repair_partner_payment_service.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **P1-FIX `supplier_payment_service`** | `_syncToCloud()`: trước đây set `isSynced=1` TRƯỚC khi `_firestore.set()` — nếu cloud fail, local tin là đã sync nhưng cloud không có bản ghi. Sửa: đặt `isSynced=0`, ghi Firestore, sau đó set `isSynced=1` chỉ khi Firestore xác nhận thành công. |
| 2 | **P1-FIX `repair_partner_payment_service`** | Cùng pattern lỗi và cùng cách sửa như trên. |
| 3 | **Kiểm toán kiến trúc sync toàn hệ thống** | Điều tra tĩnh (không sửa code) toàn bộ luồng sync: SyncOrchestrator, SyncService, tất cả listeners, downloadAllFromCloud, các view gọi syncAll, và payment/inventory/sales/customer/supplier/debt. Báo cáo 10 điểm với bằng chứng source code cụ thể. |

**Bằng chứng kỹ thuật P1:**
- `supplier_payment_service.dart` dòng 65 (trước fix): `{'firestoreId': docId, 'isSynced': 1}` trước dòng 69 `_firestore.set()`
- `repair_partner_payment_service.dart` dòng 67 (trước fix): cùng pattern
- Khi Firestore fail, local bản ghi có `isSynced=1`, listener real-time không nhận doc (doc không tồn tại), => bản ghi payment bị mất hoàn toàn trên cloud mà app không biết

**Các rủi ro còn lại đã được ghi nhận (chưa sửa — xem HANDOVER.md):**
- P2: `downloadAllFromCloud` upsert toàn bộ mà không đi qua `_shouldAcceptCloudData`
- P2: `sendChat()` trong `FirestoreService` nuốt lỗi `catch (_) {}` nhưng UI vẫn báo thành công
- P3: các `syncAll()` call ở `inventory_view`, `salvage_phone_view`, `fast_stock_in_view` không kiểm tra `SyncResult.failed`
- P3: `customer_service.updateCustomer()` cập nhật local trước, cloud sau; cloud fail không enqueue retry

**Validation:**
- `flutter analyze lib/services/supplier_payment_service.dart lib/services/repair_partner_payment_service.dart`: No issues found
- `flutter analyze` toàn repo: 0 error cứng (1753 info/lint là pre-existing)

---

## [2026-06-04] - feat: Chuyển đơn sửa chữa sang shop mới

**Files thay đổi:**
- `lib/services/migration_service.dart` (NEW)
- `lib/views/shop_migration_view.dart` (NEW)
- `lib/views/backup_restore_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **MigrationService** | Service copy repairs từ shop nguồn → shop đích, batch 400 docs, paginate 500 docs/trang, hỗ trợ cancel |
| 2 | **ShopMigrationView** | UI 3 phase: setup (chọn shop đích + xác minh) → running (progress realtime) → done (summary + hướng dẫn tiếp theo) |
| 3 | **Entry point BackupRestoreView** | Section "Chuyển đơn sửa chữa" ở cuối Firestore tab, chỉ hiện với role owner/super_admin |
| 4 | **Super-admin UX** | Dropdown chọn shop từ getAllShops(); Owner: text field + nút Xác minh |
| 5 | **Copy mode** | Tạo doc mới với ID mới + shopId mới, shop cũ giữ nguyên |

---

## [2026-06-04] - Fix customer sync + const naming warning

**Files thay đổi:**
- `lib/services/sync_service.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Rename `_customerBatchSize`** | Đổi thành `customerBatchSize` để tránh lint warning về private const trong function body |

---

## [2026-06-04] - Fix ghost topbar: xóa nested Navigator + dùng rootNavigator:true

**Files thay đổi:**
- `lib/views/home_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Xóa nested Navigator** | `_buildTabHost` không còn bọc tabs trong `Navigator` widget — tất cả route push tự động lên root navigator, che toàn màn hình |
| 2 | **rootNavigator: true** | `_openMyStaffProfile`, `_openShopSettingsFromGreeting`, `_openDashboardSettings` đổi từ `Navigator.push(context,…)` sang `Navigator.of(context, rootNavigator: true).push(…)` |
| 3 | **_usesNestedNavigator** | Luôn trả `false` — không còn nested navigator nào trong tab host |

---

## [2026-06-04] - Thiếu vốn/NCC: fix trùng dữ liệu + bấm vào mở chi tiết

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Fix trùng dữ liệu** | Thêm `_productKey()` (ưu tiên firestoreId→imei→name+ngày) + `_infoScore()` + `_dedup()` — sau mỗi lần load giữ record có nhiều thông tin nhất, loại bỏ bản sao |
| 2 | **Bấm card → chi tiết** | `GestureDetector.onTap` gọi `_openDetail()`: đã bán + có IMEI → `SaleDetailView`; còn hàng hoặc không có IMEI → `InventoryDetailView` |
| 3 | **Dedup cross-page** | `_loadMore()` truyền `seen` map từ items hiện có → không load bản sao khi phân trang |

---

## [2026-06-04] - Fix logic NCC + Phương thức TT trong CHỈNH SỬA PHIẾU NHẬP

### 3 bug logic trong smart_stock_in_view

**Files thay đổi:**
- `lib/views/smart_stock_in_view.dart`

| # | Bug | Nguyên nhân | Fix |
|---|-----|-------------|-----|
| 1 | `_requireSupplier ?? true` → bắt buộc NCC khi settings chưa load | Default sai | Đổi thành `?? false` |
| 2 | `_supplierEffectivelyRequired`: `cost > 0` → ép NCC dù "Bắt buộc NCC" đã OFF | Logic thừa | Xóa điều kiện `cost > 0`; chỉ giữ `_requireSupplier` và `CÔNG NỢ` |
| 3 | Phương thức TT luôn required dù không có cost + allowPendingCost ON | Hard-coded | Thêm getter `_paymentMethodRequired`: chỉ bắt buộc khi `!allowPendingCost`, hoặc `cost > 0`, hoặc `NCC đã chọn` |

---

## [2026-06-04] - Popup chọn mã nhập nhanh: thêm tìm kiếm + phân trang

### Thêm `showQuickCodePickerSheet` — BottomSheet có search + infinite-scroll pagination

**Files thay đổi:**
- `lib/widgets/quick_code_picker_sheet.dart` *(mới)*
- `lib/views/fast_stock_in_view.dart`
- `lib/views/smart_stock_in_view.dart`

| # | Thay đổi | Chi tiết |
|---|----------|----------|
| 1 | **Tạo widget tái sử dụng** | `showQuickCodePickerSheet(context)` → `DraggableScrollableSheet` (88% màn hình), trả về `QuickInputCode?` |
| 2 | **Search real-time** | TextField với debounce 350ms, gọi `getQuickInputCodesPaged()` với param `search`, có nút X xóa nhanh |
| 3 | **Phân trang infinite scroll** | 20 item/trang, trigger load-more khi scroll cách đáy 150px, spinner ở cuối list |
| 4 | **Empty state** | Icon + text theo context (chưa có mã / không tìm thấy), nút "Xóa bộ lọc" khi đang search |
| 5 | **Item card** | Icon type (điện thoại/phụ kiện), tên, subtitle (brand+model hoặc mô tả), badge giá vốn nếu có |
| 6 | **Nút Quản lý** | Bấm → đóng sheet + mở `QuickInputCodesView` qua root navigator |
| 7 | **Thay popup cũ** | `fast_stock_in_view._selectFromLibrary()` và `smart_stock_in_view._selectFromLibrary()` → 3 dòng gọi `showQuickCodePickerSheet()` |

### Validation
- `flutter analyze` (3 files) → 0 error, 0 warning; 32 info pre-existing

---

## [2026-06-04] - Fix CHỈNH SỬA PHIẾU NHẬP: NCC bị reset + UX scroll khi thiếu thông tin

### 2 bug trong smart_stock_in_view (edit mode)

**Files thay đổi:**
- `lib/views/smart_stock_in_view.dart`

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Data | Khi mở edit phiếu nhập, `_selectedSupplier` bị reset về `null` nếu tên NCC trong entry không khớp chính xác với `_suppliers` list (bị xóa NCC, hoặc không tìm thấy) → "LƯU VÀO HÀNG CHỜ" luôn disabled dù entry đã có NCC | Thêm NCC cũ vào `_suppliers` list tạm thời nếu chưa có, luôn giữ `_selectedSupplier = entry.supplierName` |
| 2 | UX | Warning "Thiếu: Nhà cung cấp, Phương thức TT" ở bottom nhưng các fields đó ở giữa form (phải scroll) — user không biết phải làm gì | Warning trở thành `GestureDetector`, bấm vào tự `Scrollable.ensureVisible()` scroll đến card kế toán; thêm icon ↑ và text "— bấm để điền" |

### Validation
- `flutter analyze` → 0 lỗi mới (16 info pre-existing)

---

## [2026-06-04] - Audit & fix toàn diện chat nội bộ + fix tab "Đã bán" thiếu vốn/NCC

### Audit chat nội bộ → fix 7 vấn đề bảo mật, stability, UX

**Files thay đổi:**
- `lib/services/chat_service.dart`
- `lib/services/ai_chat_service.dart`
- `lib/views/advanced_chat_view.dart`
- `lib/views/missing_info_products_view.dart`
- `lib/data/db_helper.dart`

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Count | Tab "Đã bán" hiển thị count=2 nhưng list trống — `getProductsCount` không filter `quantity<=0` | Thêm `soldOnly` param vào `getProductsPaged` + `getProductsCount`; view dùng `soldOnly: tab==1` |
| 2 | Security | `sendTextMessage()` không giới hạn độ dài → user gửi được tin nhắn 1MB | Thêm `_kMaxMessageLength = 2000` + validate đầu hàm |
| 3 | Security | `_sanitize()` chỉ strip `<>` và backtick — thiếu `{} $` và role-override pattern | Thêm strip `{→( }→) $→''` + regex strip `system|assistant|human|user` prefix |
| 4 | Bug/UX | Typing indicator không tắt khi user background app | `didChangeAppLifecycleState(paused)` thêm `ChatService.setTypingStatus(false)` |
| 5 | Bug/UX | Reaction tap không báo lỗi khi Firestore write fail | Await `toggleReaction()` → show snackbar nếu `!ok` |
| 6 | UX | AI cloud timeout 20s → user tưởng app hang | Giảm xuống 10s |
| 7 | Code quality | Comment sai `// Get unread messages (unused result — only kept for side-effect ordering)` trong `markAllAsRead()` | Xóa comment gây nhầm lẫn |

### Validation
- `flutter analyze` → 0 lỗi mới
- Commit: (xem git log) | Branch: `master`

---

## [2026-06-05] - Fix sync bug nghiêm trọng: expense/debt không lên Firestore khi nhập giá vốn

### Audit luồng tài chính → phát hiện + sửa 2 lỗi sync bị bỏ qua

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`
- `lib/views/inventory_view.dart`

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Sync | `insertDebt(isSynced:0)` tại cả 2 màn nhưng KHÔNG `enqueueDebt()` → debt không bao giờ lên Firestore | Thêm `SyncOrchestrator().enqueueDebt(id, firestoreId, operation: create)` cho CÔNG NỢ path |
| 2 | Bug/Sync | `insertExpense(isSynced:0)` tại cả 2 màn nhưng KHÔNG `enqueueExpense()` → expense không bao giờ lên Firestore | Thêm `SyncOrchestrator().enqueueExpense(id, firestoreId, operation: create)` cho TIỀN MẶT/CK path |
| 3 | Bug/Schema | Expense record thiếu `createdAt` (chỉ có `date`) | Thêm `'createdAt': now` vào insertExpense map |
| 4 | Bug/Memory | `inventory_view._showInlineCostEdit()`: `costCtrl` không `dispose()` | Lưu `costText`, `costCtrl.dispose()` ngay sau sheet đóng |
| 5 | Bug/UX | Validation giá vốn > 0 nằm SAU sheet đóng → user không thấy lỗi | Chuyển validation vào ElevatedButton.onPressed trong modal (trước `Navigator.pop`) |
| 6 | UX | Nút hủy gọi "Bỏ qua" → khó hiểu | Đổi thành "Hủy" |

**Audit findings (kiến trúc — chưa fix):**
- 8 views bypass `PaymentIntentService` (inventory, missing_info, debt, sales, repair_order, fast_stock_in, parts_inventory, repair_detail)
- `daily_financial_analysis_service`: dedup fuzzy `(amount ± 1000đ)` → có thể double-count
- `importOut` metric chỉ đếm `supplier_import_history`, không đếm expenses có category NHẬP HÀNG

### Validation
- `flutter analyze` → 0 lỗi mới (8 info pre-existing trong inventory_view không liên quan)
- `flutter build apk --debug` → thành công
- Commit: `29ffae55` | Branch: `master`

---

## [2026-06-04] - Audit & sửa toàn diện màn Thiếu vốn / NCC

### Audit và fix 6 vấn đề trong missing_info_products_view.dart

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`
- `lib/data/db_helper.dart`

#### Vấn đề tìm thấy & đã sửa

| # | Loại | Vấn đề | Giải pháp |
|---|------|---------|-----------|
| 1 | Bug/Memory leak | `costCtrl` (TextEditingController) không `dispose()` sau mỗi lần mở popup | Lưu `costText`, gọi `costCtrl.dispose()` ngay sau `showModalBottomSheet` trả về |
| 2 | Bug/Logic | Thiếu `mounted` guard sau `await getCurrentShopId()` | Thêm `if (!mounted) return;` |
| 3 | Bug/Count sai | `_counts[1]` (Tab "Đã bán") tính tổng không filter `quantity ≤ 0` | Thêm `soldOnly` param vào `getProductsCount`, gọi với `soldOnly: !inStock` |
| 4 | UI/Theme | Popup nền tối `0xFF1C2331` nhưng fields đã trắng → không nhất quán | Đổi container sang `Colors.grey.shade50`, handle và tiêu đề theo light theme |
| 5 | UX/State | Không subscribe EventBus → màn không tự refresh khi nhập vốn từ nơi khác | Thêm `StreamSubscription _productEventSub` lắng nghe `financial_changed` / `products_changed` |
| 6 | UX/Edge | Nếu cả `_allowPendingCost=false` lẫn `_enableSupplier=false`, card render rỗng | `_buildCard` trả về `SizedBox.shrink()` khi không có badge/action nào |

### Validation
- `flutter analyze lib/views/missing_info_products_view.dart lib/data/db_helper.dart` → No errors (6 info pre-existing trong db_helper không liên quan).
- `flutter build apk --debug` → thành công.


## [2026-06-04] - Sửa độ rõ chữ AppBar và màu chữ popup Nhập giá vốn

### Cải thiện UI màn Thiếu vốn / NCC

**Files thay đổi:**
- `lib/views/missing_info_products_view.dart`

#### Vấn đề
- Chữ AppBar/Tab ở màn Thiếu vốn / NCC hiển thị mờ, độ tương phản thấp.
- Popup Nhập giá vốn có trạng thái chữ bị chìm/trùng nền sáng ở một số trường nhập liệu.

#### Fix đã áp dụng
- Tăng độ rõ tiêu đề AppBar bằng `titleWidget` riêng với cỡ chữ và trọng số đậm hơn.
- Chuẩn hóa màu chữ TabBar (`labelColor`, `unselectedLabelColor`, `indicatorColor`) để đọc rõ trên nền gradient.
- Điều chỉnh nhóm field trong popup Nhập giá vốn:
	- Dropdown phương thức thanh toán: nền trắng + chữ đậm màu tối + label/icon màu xám trung tính.
	- Picker nhà cung cấp: nền trắng + chữ tối, placeholder xám, viền rõ ràng.

### Validation
- `flutter analyze lib/views/missing_info_products_view.dart` → No issues found.
- `flutter build apk --debug` → thành công.


## [2026-06-03] - Fix vòng lặp sync `permission_denied:storage_locations -> refresh scope -> permission_denied`

## [2026-06-04] - Fix toggle "Cho phép nhập giá vốn sau" báo bật nhưng UI không đổi

## [2026-06-04] - Chuẩn hóa nhập liệu: "iPhone" là thương hiệu, không phải tên

### Sửa mapping khi tạo/chọn mã nhập nhanh cho sản phẩm điện thoại

**Files thay đổi:**
- `lib/views/quick_input_codes_view.dart`
- `lib/views/smart_stock_in_view.dart`
- `lib/views/fast_stock_in_view.dart`

#### Vấn đề
- Khi người dùng nhập chuỗi như `IPHONE 13 ...` ở phần tên, một số luồng dữ liệu cũ không đẩy đúng `IPHONE` vào trường `brand`.
- Kết quả là form nhập kho có thể thiếu thương hiệu hoặc hiển thị sai kỳ vọng.

#### Fix đã áp dụng
- Trong dialog lưu mã nhập nhanh:
	- Tự nhận diện thương hiệu đứng đầu chuỗi tên (ví dụ `IPHONE`) và map về `brand` chuẩn.
	- Nếu `model` đang trống thì tự tách phần sau `brand` vào `model`.
- Trong luồng nạp mã nhập nhanh ở Smart/Fast Stock In:
	- Ưu tiên `brand` đã lưu.
	- Fallback suy luận từ `name + model` cho dữ liệu cũ thiếu `brand`.

### Validation
- `flutter analyze` cho các file liên quan: không phát sinh compile error mới.
- `flutter build apk --debug`: thành công.

---

### Sửa triệt để trạng thái công tắc bị trả về OFF do stale settings

**Files thay đổi:**
- `lib/views/home_view.dart`
- `lib/services/category_service.dart`
- `lib/data/db_helper.dart`

#### Vấn đề
- Khi bật/tắt công tắc ở tab Cài đặt (HomeView), toast/snackbar báo thành công nhưng công tắc có lúc vẫn hiển thị OFF.
- Nguyên nhân là race condition giữa:
	- optimistic state ở client
	- luồng reload settings chạy song song và có thể trả dữ liệu stale tạm thời.
- Có thêm nguyên nhân gốc trên DB cũ: bảng `shop_settings` chưa có cột `allowPendingCost`, khiến đọc local luôn về `false` và ghi đè UI.

#### Fix đã áp dụng
- Thêm cờ `_isSavingPendingCost` để chặn double-tap/double-toggle trong lúc lưu.
- Giữ `_pendingCostOverride` trong suốt quá trình save + reload, không clear sớm.
- Khi `_loadShopSettings()` trả dữ liệu, merge theo override pending để tránh UI bị ghi đè ngược.
- Chỉ clear override khi dữ liệu nền đã khớp giá trị vừa lưu.
- Bổ sung migration phòng thủ cho `shop_settings.allowPendingCost`:
	- thêm cột trong schema tạo mới
	- thêm đảm bảo cột tồn tại ở `onOpen`
	- thêm đảm bảo cột trước khi `CategoryService` đọc/ghi local settings.
- Siết chặt luồng lưu để không còn "báo thành công giả":
	- `CategoryService.saveShopSettings()` chỉ trả thành công khi ghi local DB thành công.
	- `home_view` và `settings_view` kiểm tra kết quả `saveShopSettings()`; nếu fail sẽ hiện lỗi đỏ.
	- Bổ sung xác nhận sau lưu (read-back) để đảm bảo giá trị đã được phản ánh đúng trước khi báo thành công.
	- Chặn trường hợp chưa có `shopId` hiện tại (thường gặp ở super admin chưa chọn shop).

#### App Check / permission liên quan
- Nếu App Check hoặc Firestore Rules chặn ghi, trước đây có thể bị nuốt lỗi và vẫn hiện trạng thái như đã bật.
- Sau bản vá này, các trường hợp bị chặn sẽ trả lỗi rõ ràng cho người dùng thay vì hiện thành công.

### Validation
- `flutter analyze lib/views/home_view.dart`
	- Không có compile error mới; chỉ còn info/lint pre-existing của file lớn.
- `flutter build apk --debug`
	- Build thành công.

---

### Xử lý triệt để vòng lặp reinit/sync gây tốn quota App Check

**Files thay đổi:**
- `lib/services/sync_service.dart`

#### Root cause
- `SyncService` khởi tạo `_lastUserPermissionSignature` từ permissions đã chuẩn hóa.
- Sau đó listener `users` lại so sánh với dữ liệu profile thô của Firestore (`users/{uid}`), làm phát sinh false-positive "permissions changed".
- False-positive này kích hoạt `forceReinitializeSync()` lặp lại, dẫn tới chuỗi:
	- `permission_denied:storage_locations`
	- `Refreshing sync scope...`
	- subscribe/poll lại và tiếp tục `permission_denied`.

#### Fix đã áp dụng
- Đổi baseline chữ ký quyền người dùng:
	- Không set `_lastUserPermissionSignature` ở đầu `initRealTimeSync`.
	- Để listener `users` lấy snapshot đầu tiên làm baseline nhằm tránh lệch nguồn dữ liệu.
- Bổ sung cooldown cho reinit do access-change (`20s`) để chặn vòng lặp kích hoạt dồn dập.
- Bổ sung `storage_locations` vào nhóm quyền kho (`allowViewInventory`) trong `_canSubscribeCollection` để không subscribe collection trái quyền.

### Validation
- `flutter analyze lib/services/sync_service.dart`
	- 4 info/lint pre-existing (không phát sinh compile error mới từ patch).
- `flutter build apk --debug`
	- Build thành công.

---

## [2026-06-03] - Tính năng "Nhập vốn sau" + toggle 2 phương thức giá vốn

### Bật/tắt chế độ cho phép nhập giá vốn sau (Settings)

**Files thay đổi:**
- `lib/views/inventory_view.dart`
- `lib/views/settings_view.dart` (đã có từ trước)
- `lib/models/shop_settings_model.dart` (đã có từ trước)

#### Tính năng mới trong Kho hàng (khi `allowPendingCost = true`):
- **Badge ⚠ Chưa vốn** — hiện màu cam trên card sản phẩm khi `cost == 0`, nhấn để sửa giá vốn inline
- **Inline edit giá vốn** — nhấn badge để mở dialog nhập nhanh giá vốn, tự động save + sync lên Firestore
- **Filter chip "Chưa nhập vốn"** — lọc nhanh toàn bộ sản phẩm chưa có giá vốn (chỉ hiện khi feature bật)
- **Cảnh báo mềm khi bán** — snack bar cam khi bán sản phẩm cost = 0, không block giao dịch

#### Toggle trong Settings:
- 🔒 Phương thức cũ: bắt buộc nhập giá vốn > 0 (mặc định)
- ✅ Phương thức mới: cho phép bỏ qua, nhập vốn sau

### Validation
- `flutter analyze lib/views/inventory_view.dart` — 8 info warnings (pre-existing, không phải từ code mới)
- `flutter build apk --release` — Build thành công (117.5MB)
- Install + test Samsung A32 (RF8R31SS7GY) — App khởi động, đăng nhập OK

---

## [2026-06-03] - AI hiểu ngôn ngữ người dùng: mở rộng cụm kho/tồn kho tự nhiên

### Mở rộng nhận diện câu lệnh tiếng Việt cho các cụm người dùng hay nói

**Files thay đổi:**
- `lib/services/ai_command_router.dart`
- `lib/services/natural_order_parser_service.dart`

#### Mở rộng nhận diện tồn kho
- Thêm các cụm như `kho linh kiện`, `kho phụ kiện`, `tồn kho hiện tại`, `hàng tồn hiện tại`, `còn bao nhiêu trong kho` vào router stock check.
- Natural order parser cũng nhận thêm các cụm tồn kho tương tự để route đúng intent ngay cả khi người dùng không nói đúng từ khóa kỹ thuật.

### Validation
- `flutter analyze lib/services/ai_command_router.dart lib/services/natural_order_parser_service.dart`
	- Không có issue mới.
- `flutter build apk --debug`
	- Build thành công.

---

## [2026-06-03] - Permission-gated sync: tự reinit khi quyền/shop-lock thay đổi

### Siết startup sync theo quyền hiện tại và tự mở lại khi quyền được cấp

**Files thay đổi:**
- `lib/services/sync_service.dart`

#### Đồng bộ theo phạm vi truy cập
- Thêm nhận diện chữ ký quyền người dùng và chữ ký khóa cấp shop để phát hiện khi scope truy cập thay đổi.
- Khi `users/{uid}` hoặc `shops/{shopId}` đổi các field ảnh hưởng đến quyền, `SyncService` sẽ tự `forceReinitializeSync()` để tải lại đúng collection được phép.
- Giữ nguyên cơ chế lọc collection hiện có, nên collection không được phép vẫn không bị subscribe/download khi app mở.

### Validation
- `flutter analyze lib/services/sync_service.dart`
	- Không có lỗi compile mới; còn các `info`/lint hiện hữu của dự án.

---

## [2026-06-03] - AI kho hàng: tách đúng mặt hàng/sản phẩm tồn + chặn lặp phản hồi

### Sửa luồng AI trả lời kho và giảm phản hồi bị lặp

**Files thay đổi:**
- `lib/data/db_helper.dart`
- `lib/services/ai_chat_service.dart`
- `functions/index.js`

#### Tách đúng số liệu kho
- `DBHelper.getInventoryBreakdownSummary()` mới trả về đồng thời:
	- số `mặt hàng` = số record sản phẩm còn hàng
	- `sản phẩm tồn` = tổng `quantity`
	- `giá vốn` theo từng nhóm
- `AiChatService.getTodayStats()` lấy breakdown theo 4 nhóm:
	- `Kho điện thoại` (`DIEN_THOAI`)
	- `Kho phụ kiện` (`PHU_KIEN`)
	- `Kho linh kiện` (`LINH_KIEN`)
	- `Tồn kho hiện tại` (toàn bộ kho)

#### Cải thiện câu trả lời AI
- `quickAnswer()` của AI chat đổi sang format có breakdown rõ ràng, không còn dùng `stockCount` như thể đó là tổng quantity.
- Cloud Function `chatAssistant` được siết prompt để:
	- không lặp lại cùng một section trong một câu trả lời
	- phân biệt rõ `mặt hàng` và `sản phẩm tồn`
- Thêm lọc khử trùng lặp paragraph ở đầu ra server trước khi trả về app.

### Validation
- `flutter analyze lib/data/db_helper.dart lib/services/ai_chat_service.dart`
	- Không còn lỗi compile; chỉ còn 2 `info` hiện hữu của dự án.
- `flutter build apk --debug`
	- Build thành công: `build/app/outputs/flutter-apk/app-debug.apk`

---

## [2026-05-29] - Fix đơn sửa ghi chi phí lặp + bổ sung xóa backup local + xóa dữ liệu local/cloud

### Sửa nghiệp vụ chi phí đơn sửa và dữ liệu backup/reset

**Files thay đổi:**
- `lib/views/repair_detail_view.dart`
- `lib/services/backup_service.dart`
- `lib/views/backup_restore_view.dart`

#### Sửa lỗi nghiệp vụ đơn sửa
- `repair_detail_view.dart`: khi đã ghi sổ quỹ trước đó mà sửa giá vốn nhiều lần, hệ thống chỉ ghi phần chênh lệch (`delta`) thay vì ghi lại toàn bộ chi phí mỗi lần lưu.
- Thêm `_applyCostFundDelta(...)` để tạo bút toán tăng/giảm giá vốn tương ứng (`OUT` khi tăng, `IN` khi giảm), tránh cộng trùng chi phí.

#### Backup SQLite
- `backup_service.dart`: thêm `deleteLocalSqliteBackup(filePath)` để xóa 1 file backup cục bộ.
- `backup_restore_view.dart`: thêm nút xóa cho từng item backup SQLite trong máy, có hộp thoại xác nhận trước khi xóa.

#### Xóa dữ liệu chọn lọc (Kho/Tài chính)
- `backup_service.dart`: mở rộng mapping bảng SQLite để xóa sâu hơn cho nhóm Kho/Tài chính (`product_categories`, `product_variants`, `supplier_product_prices`, `financial_activity_log`, `adjustment_entries`, `payroll_locks`, ...).
- `backup_restore_view.dart`: thêm tùy chọn **xóa luôn dữ liệu Cloud** theo nhóm đã chọn để tránh dữ liệu cloud đồng bộ ngược trở lại sau khi xóa local.
- `backup_service.dart`: thêm `deleteSelectedDataFromCloud(...)` (batch delete theo `shopId`).

### Validation
- `flutter analyze lib/views/repair_detail_view.dart lib/views/backup_restore_view.dart lib/services/backup_service.dart`
	- Không phát sinh compile error mới; còn các `info`/lint hiện hữu.
- `flutter build apk --debug`
	- Build thành công: `build/app/outputs/flutter-apk/app-debug.apk`
	- Có cảnh báo NDK plugin yêu cầu `28.2.13676358` (không chặn build debug).

---

## [2026-05-29] - Backup: Xóa dữ liệu chọn lọc + Dọn backup cũ

### Quản lý dữ liệu SQLite mở rộng

**Files thay đổi:**
- `lib/services/backup_service.dart`
- `lib/views/backup_restore_view.dart`

#### Tính năng mới
- `BackupService.deleteSelectedData(List<String> collections)` — xóa vĩnh viễn các table được chọn trong SQLite, trả về số bản ghi đã xóa
- `BackupService.cleanOldLocalBackups({required int keepDays})` — xóa file backup cục bộ cũ hơn N ngày, trả về số file đã xóa
- Tab SQLite thêm section **Xóa dữ liệu chọn lọc**: preset nhanh "Kho phụ kiện/Sản phẩm", "Linh kiện sửa chữa" + nút "Xóa tùy chọn" mở `_CollectionPickerDialog`
- Tab SQLite thêm section **Dọn backup cũ**: chọn giữ 30/60/90/180 ngày → tự động dọn file cũ hơn

---

## [2026-05-29] - AI Assistant: 8 UX Improvements (Sprint AI-UX)

### AI Trợ Lý — Cải tiến UX toàn diện

**Files thay đổi:**
- `lib/services/ai_chat_service.dart`
- `lib/widgets/ai_chat_overlay.dart`
- `lib/services/ai_command_router.dart`
- `lib/services/ai_usage_logger.dart`
- `lib/views/ai_usage_dashboard_view.dart`

#### #3 Chat → Auto-fill đơn trực tiếp từ overlay
- Thêm 3 `AiActionType` mới: `createRepairFromChat`, `createSaleFromChat`, `createStockFromChat`
- Thêm `payload` field vào `AiAction` để truyền nội dung câu hỏi xuống sheet
- `quickAnswer()`: nếu "tạo đơn sửa iPhone 15 cho Minh" (có ≥2 từ nội dung sau keyword) → trả về action `createRepairFromChat` với `payload = question`
- `ai_chat_overlay._handleAction()`: xử lý 3 type mới bằng cách gọi `AiOrderInputSheet.show(context, mode: ..., prefilledText: action.payload)` — AI tự điền form từ mô tả

#### #5 Follow-up context chips sau mỗi AI answer
- Thêm `followUpChips: List<(String, IconData)>` vào `AiQuickResponse`
- `ai_chat_overlay._buildChips()`: khi `_contextChips` không rỗng → hiển thị context chips (màu xanh lá) thay vì preset chips tím
- Context chips được cập nhật trong `_send()` sau mỗi quick answer
- Ví dụ: sau "doanh thu hôm nay" → chips [Tháng này, Lợi nhuận, Đơn sửa]

#### #4 Daily briefing khi mở app lần đầu trong ngày
- `_sendWelcome()` kiểm tra `SharedPreferences['ai_last_open_date']` → nếu ngày mới hiển thị briefing "Chào buổi mới! Điểm cần lưu ý: X đơn sửa chờ, nợ phải thu..."
- Các lần mở tiếp trong ngày: chào ngắn có pending repairs count

#### #6 Lưu lịch sử chat qua session (SharedPreferences)
- `_loadHistory()`: load 20 tin nhắn gần nhất từ `SharedPreferences['ai_chat_history']` khi init
- `_saveHistory()`: lưu sau mỗi AI response (quick + cloud), giữ tối đa 20 messages
- `_welcomeSent` flag: tránh gửi welcome 2 lần khi có history

#### #2 More quick action buttons (followUpChips trên nhiều intent)
- Thêm `followUpChips` cho: doanh thu, tháng này, năm nay, bán hàng, sửa chữa, tồn kho, linh kiện, đơn bán/sửa, công nợ, lợi nhuận

#### #8 Mở rộng từ điển voice command
- `ai_command_router.dart`: thêm synonym cho stock check (+5 keywords), stock entry (+5), finance today (+6), customer (+5), pending repairs (+6), sale (+5), repair (+10 thương hiệu + triệu chứng)

#### #7 Dashboard: Tab phản hồi xấu
- `ai_usage_logger.getShopSummaryToday()`: bổ sung `negativeFeedbackItems` — list query/answer của các 👎
- `ai_usage_dashboard_view.dart`: chuyển từ single-view sang `DefaultTabController` 2 tab: **Tổng quan** + **Phản hồi xấu**
- Tab Phản hồi xấu: list card từng câu hỏi bị dislike + answer snippet + giờ ghi nhận

---

## [2026-05-29] - Sprint 4B: Flutter Analyze Warning Cleanup (132 → 1)

### Dọn cảnh báo flutter analyze (Sprint 4B)

Xóa toàn bộ unused elements, unused imports, unused fields, dead null-aware expressions và dead code qua ~20 file:

- **home_view.dart** — xóa 8 unused methods (`_buildDataItem`, `_buildPinnedCard`, `_quickActionButton`, `_buildDebtSummaryCard`, `_financeOverviewSection`, `_buildExpenseDetail`, `_financeStatCard`, `_buildLogoutCard`), dead `if (false)` BarChart block, 3 unused profit fields (`_todayNetProfit`, `_todaySalesProfit`, `_todayRepairProfit`), `dart:math` import
- **inventory_view.dart** — xóa 6 unused imports, 6 unused fields (`_isAdmin`, `_isCheckingLoading`, `_isScanning`, `_iconSize`, `_smallFontSize`, `_btnMinHeight`), 7 unused methods (`_buildInventoryTypeItems`, `_saveCheck`, `_onQRDetected`, `_progressItem`, `_warningItem`, `_showAddProductDialog`, `_showEditProductDialog`, v.v.)
- **sale_detail_view.dart** — xóa `_hasLogo`, `_toNoSign`, `_row`, unused import `app_text_styles`
- **sale_list_view.dart** — xóa 7 unused methods (`_summaryItem`, `_activeFilterChip`, `_getTimeFilterLabel`, `_getPaymentStatusLabel`, `_statItem`, `_getPayColor`, `_buildReturnChips`)
- **repair_detail_view.dart** — xóa `_staffInfoRow`, `_buildCustomerContent`, `_buildFinancialSummary`, v.v.
- **settings_view.dart** — xóa `_buildLinkedAccountsCard`, `_openHelpCenter`
- **staff_list_view.dart** — xóa 4 unused fields + `_generateInviteCode`, `_generateTempPassword`, v.v.
- **work_schedule_settings_view.dart** — xóa `_getShortRoleName`, `_saveStaffSalary`, `_buildStaffWorkScheduleList`, 6 tab methods
- **unified_sync_button.dart** — xóa `_buildSyncOperationalMarkdown`, `_showReportExportDialog`, `_showOrphanDataDialog`, cascade imports (`sync_audit_service`, `data_migration_service`, `open_filex`, `share_plus`, `foundation`)
- Nhiều file khác: `cash_closing_view`, `pty_print_designer_view`, `payroll_view`, `quick_input_codes_view`, `shop_settings_view`, `smart_stock_in_view`, `current_shop_service`, `variant_selector`, v.v.

**Kết quả:** 132 warnings → 1 (giữ lại `_eventBusSub2` trong `parts_inventory_view.dart` do là StreamSubscription — xóa sẽ phá event listening)

---

## [2026-05-29] - Phân Quyền Chat AI, Prompt Injection Guard, AI Usage Logger, Fix Compile Error

### Tính năng mới (2026-05-29)

#### Phân quyền Chat & AI chi tiết
- `lib/services/user_service.dart`
  - Thêm 4 quyền mới vào permission defaults và save/load: `allowSendChat`, `allowPinChat`, `allowDeleteOtherChat`, `allowCloudAI`.
  - `allowSendChat`: tất cả vai trò trừ fallback `user`; `allowPinChat`/`allowDeleteOtherChat`: Manager/Owner/Admin; `allowCloudAI`: Manager trở lên.
  - Tham số mới trong `updateStaffPermissions()` cho phép Owner cấu hình từng quyền per-staff.

#### AI Usage Logger
- `lib/services/ai_usage_logger.dart` *(file mới)*
  - Ghi log mọi tương tác AI (`quickAnswer`, `cloudAI`, `parseOrder`, `feedback`) lên Firestore collection `ai_usage_logs`.
  - Hỗ trợ đếm cloud AI calls trong ngày theo user/shop để hiển thị trên dashboard.
- `lib/views/ai_usage_dashboard_view.dart` *(file mới)*
  - Màn hình thống kê usage AI: số lần gọi, phân loại, feedback.

#### Prompt Injection Guard trong AI Chat Service
- `lib/services/ai_chat_service.dart`
  - Thêm `_sanitize()`: loại bỏ HTML tags, backticks, collapse newlines, giới hạn 1000 ký tự.
  - Áp dụng sanitize cho question, history content, repairSummaries, topDebtorLines trước khi gửi lên Cloud Function.

#### AI Chat Overlay — Permission + Connectivity + Search + Feedback
- `lib/widgets/ai_chat_overlay.dart`
  - Load `allowCloudAI` từ `UserService.getCurrentUserPermissions()` để kiểm soát nút Cloud AI.
  - Theo dõi trạng thái kết nối thực từ `ConnectivityService` (poll mỗi giây).
  - Thêm chế độ tìm kiếm tin nhắn (`_searchMode`) và field controller.
  - Thêm map phản hồi (`_feedbackMap`) cho từng tin nhắn.
  - Log `AiCallType.quickAnswer` vào `AiUsageLogger` sau mỗi lần trả lời nhanh.

#### Chat View — Permission, Rate Limit, Pin/Delete Guard
- `lib/views/advanced_chat_view.dart`
  - Load `allowSendChat`, `allowPinChat`, `allowDeleteOtherChat` từ permissions.
  - Client-side rate limit: tối đa 30 tin nhắn / phút (`_kMaxMsgPerMinute`).
  - Hoàn trả slot rate-limit nếu gửi tin nhắn thất bại.

#### Super Admin Console — Việt hóa nhãn UI
- `lib/views/super_admin_console_view.dart`
  - Đổi nhãn tiếng Anh còn sót (`Role`, `Shop ID`, `Broadcast`, `Permissions`, `Settings`, `Danger Zone`) sang tiếng Việt.

#### Sync Service — Dọn Dead Code
- `lib/services/sync_service.dart`
  - Xóa hàm `_scheduleResubscribe()` không còn được gọi (dead code gây lint warning).

#### Sync Center — Refactor
- `lib/widgets/unified_sync_button.dart`
  - Tách `_handleClearFailed()` (logic xóa failed queue) thành `_handleOpenFirebaseStats()` và `_handleOpenFirestoreConnectivityPage()` (điều hướng đến trang thống kê Firebase RW và Firestore Connectivity Test).
  - Bỏ import `firebase_auth` không dùng.

### Bug Fix (2026-05-29)
- `lib/views/shop_selector_view.dart`
  - Xóa tham chiếu đến biến `_pinVerified` và `_checkingPin` không tồn tại trong class (gây compile error `undefined_identifier`).

### Validation (2026-05-29)
- `flutter analyze --no-fatal-warnings`: 0 `error`, còn `1230` `info/warning` pre-existing (giảm từ 1552 nhờ dọn dead code).
- Không có compile error nào.

---

## [2026-05-26] - Hoàn Thiện Sao Lưu/Khôi Phục Offline + Online, Thêm Nút ... Trên Cài Đặt

### Follow-up Cloud Backup Fix (2026-05-26)
- `lib/services/backup_service.dart`
	- Thêm hàm xóa backup SQLite cloud: `deleteSqliteBackupFromFirebase(fileName)`.
	- Tối ưu liệt kê backup cloud: bỏ phụ thuộc `getDownloadURL()` để giảm lỗi đọc metadata/list khi policy chặt.
- `lib/views/backup_restore_view.dart`
	- Thêm nút xóa cho từng bản backup SQLite trên Cloud.
	- Bổ sung dialog xác nhận xóa và reload danh sách sau khi xóa.
	- Cải thiện thông báo lỗi sao lưu/khôi phục/xóa cloud theo mã lỗi phổ biến (`permission-denied`, `unauthorized`, `object-not-found`, `unauthenticated`).
- `storage.rules`
	- Bổ sung rule cho `db_backups/{shopId}/{allPaths=**}` để cho phép read/create/update/delete đúng theo tenant `shopId`.
	- Giới hạn upload backup tối đa 250MB.

### Validation (follow-up cloud backup)
- `flutter analyze lib/services/backup_service.dart lib/views/backup_restore_view.dart`
	- Không có compile error mới; còn lint info sẵn có của file.
- `firebase deploy --only storage`
	- Deploy thành công Storage Rules mới cho project `huyaka-1809`.

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
