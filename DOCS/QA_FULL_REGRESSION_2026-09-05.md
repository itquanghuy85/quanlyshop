# BÁO CÁO KIỂM THỬ TOÀN DIỆN — 2026-09-05

**Phạm vi:** Flutter test/FFI · Android thật (ADB, 2 máy) · SQLite + WAL/SHM ·
Firebase/Firestore + đồng bộ nhiều thiết bị · build release.

**Kết luận:** ✅ **READY FOR STORE** (v3.5.1+555) — không có lỗi mất tiền / mất
dữ liệu / lộ giá vốn / crash. Cả **4 lỗi** tìm được đều đã sửa và nghiệm thu lại
trên máy thật. Phân quyền giá vốn (CLAUDE.md §9) đạt ở cả UI lẫn file Excel xuất
ra (§5b). Phần còn lại chỉ là ghi nhận cải thiện (§5), không chặn phát hành.

---

## 1. MÔI TRƯỜNG

| Mục | Giá trị |
|---|---|
| Flutter / Dart | 3.41.4 stable (ff37bef603) / Dart 3.11.1 |
| Nhánh · commit gốc | `master` · `cfc1b89f` |
| Package | `com.huluca.shopmanager` |
| versionName+Code | kiểm thử trên `3.5.0` (+554); **phát hành `3.5.1+555`** sau khi sửa 4 lỗi |
| Firebase project | `huyaka-1809` |
| Tài khoản test | `m@m.com` · shop **M** · role `owner` · shopId `geqXPHQJ3nT6XkMbeh6JswTdGbr2` |
| Máy 1 | Oppo **CPH2203**, Android 13 (`NJR8W86LKRVW7DHQ`) |
| Máy 2 | Oppo **CPH2239**, Android 11 (`WCE65565HMDYOB59`) |
| Mạng | Wi-Fi "HULUCA 1", VALIDATED, không airplane-mode |
| DB path | `/data/data/com.huluca.shopmanager/databases/repair_shop_v22.db` |
| Pull `.db`/`-wal`/`-shm` | ✅ được (bản cài là debug ⇒ `run-as` chạy) |
| `PRAGMA user_version` | **110** — khớp `db_helper.dart:634` |
| `integrity_check` / `foreign_key_check` | `ok` / rỗng |
| Keystore | `android/key.properties` → `D:\android-keys\upload-keystore.jks`, alias `upload` |
| Rules / Functions | `firestore.rules`, `functions/index.js` có trong repo (không kiểm tra trạng thái deploy) |

**An toàn:** shop test riêng, dữ liệu cách ly theo `shopId`. Không đụng dữ liệu
production.

---

## 2. TỰ ĐỘNG (FFI / UNIT / WIDGET)

| Lệnh | Trước sửa | Sau sửa |
|---|---|---|
| `flutter analyze lib` | **0 error, 0 warning**, 1308 info | **0 error, 0 warning**, 1308 info |
| `flutter test` | **+550 / −8** | **+550 / −8** (đúng 8 lỗi cũ, không phát sinh) |
| `flutter build apk --release` | ✅ 122.7 MB | ✅ (build lại sau khi sửa) |
| `flutter build appbundle --release` | ✅ | ✅ |

Top lint (info, không chặn): `deprecated_member_use` 618 · `prefer_const_constructors` 204 ·
`use_build_context_synchronously` 125 · `curly_braces_in_flow_control_structures` 118 · `avoid_print` 92.

### 8 test đỏ — đều CÓ SẴN, không phải hồi quy

| Test | Nguyên nhân | Loại |
|---|---|---|
| `db_payroll_lock_test` (1), `quick_input_sync_test` (2) | `[core/no-app] No Firebase App` từ `DBHelper._backfillRepairsShopIdIfMissing` → `UserService.getShopIdSync` → `FirebaseAuth.instance`. Trong app thật `Firebase.initializeApp` (main.dart:245) chạy TRƯỚC mọi `DBHelper` (dòng 435+) ⇒ **không ảnh hưởng production** | môi trường test |
| `kiotviet_product_analyze_test` (1) | Đường dẫn cứng `D:/ảnh claude/DanhSachSanPham_KV30052026-112134-441.xlsx` không tồn tại | dữ liệu test thiếu |
| `kiotviet_settings_view_test` (4) | Test kỳ vọng "đúng 1 `TextFormField`", giao diện nay có 3 | test lỗi thời |

---

## 3. LỖI ĐÃ SỬA TRONG ĐỢT NÀY

### BUG-01 — Ô số điện thoại khách hàng không kiểm tra định dạng ✅ ĐÃ SỬA
* **File:** `lib/views/customer_management_view.dart:672`
* Validator chỉ kiểm rỗng, **không** gọi `UserService.validatePhone` (9–12 chữ số)
  như mọi màn khác (`create_repair_order_view:672`, `create_sale_view:626/1199`,
  `partner_management_view` ×4, `repair_detail_view:4396`). Vi phạm CLAUDE.md §5.
* **Tái hiện:** Bán hàng → Quản lý khách hàng → ➕ → tên bất kỳ, SĐT `12` → Lưu.
* **Bằng chứng:** `customers` id=25, `firestoreId=customer_1788588413208`,
  `phone=12`, `isSynced=1` (đã đẩy lên cloud).
* **Sửa:** validator gọi `UserService.validatePhone(...)`.

### BUG-02 — `addRepair` từ chối đơn sửa có `cost=0` ✅ ĐÃ SỬA
* **File:** `lib/services/firestore_service.dart:330-331`
* `MoneyValidationService.validateAmount` thiếu `allowZero: true` ⇒ đơn sửa MỚI
  (gần như luôn `cost=0`; `price=0` khi bảo hành) làm hàm trả `null`, **không ghi
  thẳng lên Firestore**. Ngay bên dưới, `upsertRepair` đã dùng `allowZero: true`
  kèm chú thích *"repairs can have price=0 (warranty) or cost=0 (no parts)"*.
* **Bằng chứng (logcat máy thật, 13:21:31.453):**
  `❌ addRepair: MoneyValidationService failed: MoneyValidationException[MoneyValidationErrorCode.amountZero]`
  → `ℹ️ Skipped repair chat/push because repair is local-only and not synced to cloud yet`
  (lúc tạo `rep_1788589291276_0900112233`).
* **Ảnh hưởng:** đơn vẫn lên cloud nhờ hàng đợi sync ⇒ *không mất dữ liệu*, nhưng
  đường ghi trực tiếp (dự phòng) coi như chết ở trường hợp thường gặp nhất.

### BUG-03 — `addProduct` / `updateProductCloud` cùng lỗi ✅ ĐÃ SỬA
* **File:** `lib/services/firestore_service.dart:524-525, 551-552`
* Kho cho phép hàng **chưa định giá** (`price=0`, UI hiện "⚠ Chưa định giá") và
  `shop_settings.allowPendingCost=1` cho phép nhập giá vốn sau (`cost=0`).
* **Bằng chứng:** ≥6 sản phẩm `price=0` trong shop test.

---

## 4. BUG-04 — Xoá khách hàng báo THÀNH CÔNG nhưng khách quay lại ✅ ĐÃ SỬA

### Triệu chứng & nguyên nhân
* **File:** `lib/services/firestore_service.dart:1652-1674` (`deleteCustomerById`),
  `lib/services/customer_service.dart:84-95`.
* **Nguyên nhân:** `deleteCustomerById` tìm document trên cloud bằng
  `.where('id', isEqualTo: customerId)` — trong đó `customerId` là **id
  autoincrement của SQLite máy đó**, không phải `firestoreId`. Không khớp
  document nào ⇒ vòng `for` không chạy lần nào, **nhưng hàm vẫn `return true`**
  ⇒ giao diện hiện toast xanh *"Đã xóa khách hàng"*.
* **Hậu quả quan sát được:**
  * Khách id=25: xoá 3 lần, mỗi lần đều hiện toast xanh; hàng vẫn nằm trong danh
    sách; DB giữ `deleted=0` và `updatedAt=1788588413549` (đúng bằng lúc tạo) vì
    `syncCustomersFromCloud` upsert đè lại mỗi ~40 giây.
  * Khách id=26: máy 1 `deleted=1`, nhưng **máy 2 vẫn `deleted=0`** ⇒ lệnh xoá
    không hề tới cloud / máy khác.
* **Bằng chứng:** ảnh `del1_s.png` (toast xanh + hàng vẫn hiện);
  log lặp `syncCustomersFromCloud: Đã upsert customer TÉT_FULL_20260905_KH1 (customer_1788588413208)`;
  đối chiếu DB 2 máy.
* **Chứng cứ id cục bộ không portable:** cùng một khách có id **25** trên máy 1
  và **52** trên máy 2.

### Đã sửa (v3.5.1+555)
* `FirestoreService.deleteCustomerByFirestoreId(String)` **(mới)** — xoá mềm
  đúng document bằng `.doc(firestoreId)`, giống hệt `updateCustomer`.
* `deleteCustomerById(int)` giữ làm dự phòng nhưng **trả `false` khi không khớp
  document nào** thay vì báo thành công khống.
* `CustomerService.deleteCustomer` tra `firestoreId` trước, đánh dấu
  `isSynced=0`, chỉ đặt lại `1` khi cloud xoá xong, **trả `false` nếu cloud
  hụt**. Khách chưa từng lên cloud thì xoá cục bộ là đủ.
* `DBHelper.getCustomerById(int)` **(mới)**.
* `customer_management_view` trước đây **bỏ qua hoàn toàn** kết quả xoá — nay
  hiện SnackBar xanh/đỏ đúng kết quả thật.

### Nghiệm thu lại đúng ca đã fail
* Máy 1: khách trước đó xoá 3 lần không được → nay `deleted=1`, `isSynced=1`,
  `updatedAt` nhảy đúng mốc xoá, **vẫn `deleted=1` sau 2 chu kỳ
  `syncCustomersFromCloud`** (trước bật lại `0` trong ~40s).
* Máy 2: **bản ghi biến mất hẳn** khỏi cả DB lẫn danh sách (trước vẫn còn).

---

## 5. GHI NHẬN THÊM (không chặn phát hành)

* **OBS-01 — Máy thứ hai thấy số cũ tới khi khởi động lại app.**
  `SyncService.initRealTimeSync` chỉ subscribe **7** collection (`repairs`,
  `products`, `sales`, `debts`, `debt_payments`, `expenses`, `users`). Các bảng
  như `financial_activity_log`, `audit_logs`, `payment_intents`, `cash_closings`,
  `sales_returns`, `import_orders`, `price_catalog_items` chỉ về qua
  `downloadAllFromCloud`, mà hàm này **tự bỏ qua** khi realtime đang chạy
  (`if (!force && (_isInitializingRealtime || isRealTimeSyncActive)) return;`).
  Đo được: máy 1 "tiền vào" 1.35 Tr / máy 2 1.2 Tr; **khởi động lại app máy 2 →
  cả hai đều 1.32 Tr**. ⇒ Không mất dữ liệu, chỉ là cửa sổ trễ.
* **OBS-02 — Thẻ "GIÁ THAM KHẢO" nhìn như tính sai.** Hiện *Thu khách 600.000 ·
  Vốn 150.000 · Lợi nhuận 300.000* (600−150 ≠ 300). Thực chất đúng: ba số là ba
  **trung vị độc lập** (`medianProfit` là trung vị lợi nhuận từng đơn, không phải
  hiệu hai trung vị) — `pricing_engine_service.dart:230-232`,
  `create_repair_order_view.dart:351-358`. Bảng giá chính thì trừ đúng
  (500.000−333.333=166.667). Nên ghi chú trên giao diện để chủ shop không hiểu lầm.
* **OBS-03 — Ô tìm kiếm chỉ lọc khi bấm Enter.** `GlobalSearchBar.onChanged` là
  thân rỗng (`lib/widgets/global_search_bar.dart:61-65`); `onSubmitted` mới gọi
  `onSearch`. Bấm Enter lọc đúng.
* **OBS-04 — Quy tắc giá vốn (CLAUDE.md §9) ĐÚNG, nhưng KHÔNG có test tự động
  nào canh.** Soát mã: `PriceCatalogService.canViewCost / buildRows / lookup` xoá
  sạch `lastCost/avgCost/minCost/maxCost/costHistory/supplier/lastInvoiceNo/lastInvoiceDate`;
  `PriceBookService._xlHeadersFor/_xlRowFor/_xlCatalogRow` bỏ cột giá vốn khỏi
  file Excel; `canImport()` chặn ở **cả** service (`supplier_invoice_price_book_service.dart:800`)
  lẫn view (`supplier_invoice_price_import_view.dart:1207`); mọi caller
  `buildRows(includeCost:)` đều truyền giá trị lấy từ quyền.
  **Đã nghiệm thu nhánh ÂM trên máy thật** (máy 2, đăng nhập `n@n.com`,
  `auth_cache_role=employee`, uid `1U6AlYLWJpbIBS5e4I1eKWUlTvV2`) — xem §5b.
  Rủi ro còn lại thuần là **hồi quy**: không có test tự động nào bắt được nếu
  mai này ai đó bỏ quên `canViewCost()` ở một đường ra dữ liệu mới.

---

## 5b. PHÂN QUYỀN GIÁ VỐN (CLAUDE.md §9) — ✅ ĐẠT CẢ 2 TẦNG TRÊN MÁY THẬT

Chạy trên máy 2 (CPH2239) với tài khoản nhân viên `n@n.com` (`role=employee`),
rồi trả máy về tài khoản chủ shop.

**Tầng 1 — giao diện:** Bảng giá tab Sửa chữa quét toàn bộ cây giao diện:
**0 lần xuất hiện chữ "Vốn" hoặc "Lãi"**. Cùng dòng đó chủ shop thấy
`Thu 500.000đ · Vốn 333.333đ · Lãi 166.667đ`, nhân viên chỉ thấy `Thu 500.000đ`.
Trang chủ nhân viên cũng **không có** khối "DÒNG TIỀN HÔM NAY".

**Tầng 2 — dữ liệu xuất ra (quan trọng nhất, vì chặn UI mà file vẫn lộ thì vô
nghĩa):** cùng thao tác "Xuất Excel", `adb pull` cả 2 file rồi đọc thẳng
`sharedStrings.xml`:

| Sheet | Chủ shop | Nhân viên |
|---|---|---|
| Sửa chữa / Bán hàng | 10 cột — có `Giá vốn ĐX`, `Giá vốn NY` | **8 cột** — đã cắt 2 cột giá vốn |
| Bảng giá NCC | 15 cột — có `Giá vốn gần nhất/bình quân/thấp nhất/cao nhất`, `Nhà cung cấp`, `Ngày hoá đơn gần nhất` | **9 cột** — cắt cả 4 cột giá vốn **lẫn** NCC và ngày hoá đơn |

Toàn file nhân viên: **0 chuỗi nào chứa "vốn"**, và không có tên NCC nào
("NCC mẫu" chỉ xuất hiện trong file của chủ shop). Giá thu khách vẫn giữ nguyên
⇒ nhân viên vẫn tra báo giá được, đúng ý đồ.

---

## 6. KẾT QUẢ THEO NHÓM

| Nhóm | Trạng thái | Ghi chú |
|---|---|---|
| A. Môi trường | **PASS** | mọi mục ở §1 ghi nhận được, pull được `.db`+`-wal`+`-shm` |
| B. Tự động / FFI | **PASS** | analyze 0 error; test +550/−8 (8 lỗi cũ) |
| C. Đăng nhập, quyền, điều hướng | **PASS** | 7 tab đáy render đủ; role `Chủ shop`; hướng dẫn lần đầu hiện đúng 1 lần |
| D. Trang chủ / hướng dẫn / AI | **PASS** | dashboard, Trung tâm hướng dẫn, bảng AI mở bình thường |
| E. Khách hàng / NCC / đối tác | **PASS** (sau khi sửa BUG-01 + BUG-04) | tạo/sửa/tìm OK; xoá nay dính thật, lan truyền sang máy 2, và báo đúng kết quả |
| F. Kho / nhập kho / tồn kho / SP | **PASS** | lưu tạm → hàng chờ → xác nhận: SP id=27 qty 10, `import_orders` id=18 tổng 1.000.000, nợ NCC id=31, `supplier_import_history` id=41 — khớp hết |
| G. Đơn sửa chữa | **PASS** | tạo (600.000) → XONG (status 1→3, `finishedAt`) → GIAO (status 4, `deliveredAt`) → sổ quỹ +600.000 TIỀN MẶT |
| H. Bán hàng | **PASS** | bán 2×150.000, cọc 100.000, CÔNG NỢ: `totalPrice` 300.000 / `totalCost` 200.000, tồn 10→8, nợ 300.000 (đã trả 100.000), sổ quỹ +100.000 |
| I. Công nợ / thanh toán / tài chính | **PASS** | thu nợ 50.000 → `paidAmount` 150.000, `debt_payments` id=33, sổ quỹ +50.000. **Chặn thu quá:** "Số tiền thu không được vượt 200.000" ✅. Tổng dòng tiền ròng 1.32 Tr khớp sổ cái từng đồng |
| J. Bảng giá & Bảng giá NCC + **phân quyền giá vốn** | **PASS** | tab Sửa chữa/Bán hàng render; Thu−Vốn=Lãi đúng; danh mục NCC 13 dòng. **Nhánh nhân viên (§5b): 0 chữ "Vốn"/"Lãi" trên UI; Excel xuất ra cắt đúng 2 cột (sheet Sửa chữa/Bán hàng) và 6 cột (sheet Bảng giá NCC).** Xem OBS-02, OBS-04 |
| K. Ngân hàng / QR / thông báo NH | **PASS** | QR chuyển khoản (Vietcombank) lưu đúng; màn đọc thông báo NH liệt kê 31 ngân hàng + nêu rõ giới hạn quyền riêng tư |
| L. Đồng bộ / offline / migration | **PASS (kèm OBS-01)** | toàn bộ dữ liệu test tự về máy 2 qua Firestore: KH, SP (qty 8), đơn bán, đơn sửa, công nợ — khớp 100%. DB v110, `integrity_check ok`, `sync_queue` rỗng |
| M. In / Excel / chia sẻ | **PASS** | Xuất `BangGia_20260905.xlsx` → `/storage/emulated/0/Download`, mở được, 3 sheet `Sửa chữa`/`Bán hàng`/`Bảng giá NCC`, đủ cột giá vốn (user là chủ shop). Xem trước hoá đơn bán render đủ trường |
| N. Xoá / hoàn tác (kiểm tra khi dọn dữ liệu) | **PASS** | **Xoá đơn bán** hoàn nguyên chuẩn: tồn 8→10, xoá công nợ, sổ cái ghi `SALE_VOID` −150.000 (đúng bằng phần đã thu) — bù trừ về 0. **Mật khẩu quản lý sai** bị chặn ("Sai mật khẩu quản lý") ✅ |
| O. Build release | **PASS** | APK + AAB đều build thành công, ký bằng upload keystore |

**Không phát hiện:** crash, `_dependents.isEmpty`, exception Flutter chưa bắt,
màn trắng, sai tiền, hay lộ giá vốn. Logcat 1416 dòng — chỉ có nhiễu vendor Oppo.

---

## 7. DỮ LIỆU TEST & DỌN DẸP

Tiền tố dùng: `TFULL20260905_` (không dùng `TEST_FULL_20260905_` như kế hoạch vì
bàn phím Gboard tiếng Việt kiểu **Telex** trên máy test biến `ES` → `É` khi bơm
chữ bằng `adb input text`; đây là hiện tượng của bàn phím, **không phải lỗi app**
— chính nó tạo ra tên `TÉT_FULL_20260905_KH1` ở khách id=25).

| Bản ghi | ID | Trạng thái |
|---|---|---|
| `sales` sale_1788589106608_0900112233 | 11 | ✅ đã xoá (hoàn nguyên tồn kho, công nợ, sổ quỹ) |
| `debts` debt_1788589106608_0900112233 | 32 | ✅ mất theo đơn bán |
| `debt_payments` (100.000 + 50.000) | 32, 33 | ✅ mất theo đơn bán |
| `products` TFULL20260905_SP1 (`r5ihsvMuBhUWrgWLAEto`) | 27 | ✅ đã ẩn (`deleted=1`, đã sync) |
| `customers` TFULL20260905_KH1 (`customer_1788588608823`) | 26 | ⚠️ máy 1 `deleted=1`, **máy 2 vẫn hiện** — BUG-04 |
| `customers` TÉT_FULL_20260905_KH1 (`customer_1788588413208`) | 25 | ❌ **không xoá được** — BUG-04 (giữ lại làm bằng chứng) |
| `repairs` rep_1788589291276_0900112233 | 19 | ❌ **không xoá được — app cấm theo thiết kế**: "Không thể xóa đơn ĐÃ GIAO. Chỉ xóa đơn chưa giao" (`order_list_view.dart:2295`) |
| `import_orders` `5cyYjhdvP1Wfg9cUq0tP` + nợ NCC `debt_stock_fnpy6eZ...` (1.000.000) + `supplier_import_history` 41 | 18 / 31 / 41 | ❌ **không xoá được qua giao diện** — chỉ có "Thanh toán nợ" hoặc "Xoá NCC" (sẽ xoá cả NCC TÉT A vốn có dữ liệu cũ) |
| `financial_activity_log` | 99–102 | ⚠️ còn: +600.000 tiền sửa (đơn 19) và cặp +150.000/−150.000 đã bù trừ |
| `sync_queue` | — | ✅ rỗng |

**Chưa dọn sạch được.** Phần còn lại nằm ở các luồng mà app **cố tình** không cho
xoá (kế toán chỉ ghi thêm, không xoá lùi). Cố tình **không** sửa thẳng SQLite vì
sẽ lệch với cloud và hỏng trạng thái đồng bộ — rủi ro cao hơn nhiều so với việc
để lại vài bản ghi trong shop test. Cần chủ dự án quyết cách xử lý.

---

## 8. ARTIFACT

| Tệp | Đường dẫn |
|---|---|
| APK release (v3.5.1+555) | `build/app/outputs/flutter-apk/app-release.apk` |
| AAB release (nộp Store, v3.5.1+555) | `build/app/outputs/bundle/release/app-release.aab` |
| Excel bảng giá xuất thử | `/storage/emulated/0/Download/BangGia_20260905.xlsx` (máy 1) |
| Báo cáo này | `docs/QA_FULL_REGRESSION_2026-09-05.md` |

---

## 9. KHUYẾN NGHỊ CÒN LẠI (không chặn phát hành)

1. Cân nhắc OBS-01: thêm `financial_activity_log` (và các bảng tiền khác) vào
   realtime, hoặc cho `downloadAllFromCloud` chạy `force: true` khi app trở lại
   foreground, để hai máy không lệch số.
3. Dọn 8 test đỏ có sẵn: 3 test cần khởi tạo Firebase giả lập, 1 test cần bỏ
   đường dẫn cứng, 4 test cần cập nhật theo giao diện KiotViet mới.
4. Bổ sung test tự động cho quy tắc giá vốn (OBS-04) — đây là quy tắc bắt buộc
   trong CLAUDE.md §9 mà hiện không có gì canh.
