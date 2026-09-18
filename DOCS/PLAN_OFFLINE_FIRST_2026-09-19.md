# Kế hoạch: Dùng app KHÔNG cần đăng nhập (Offline-first, Online là tuỳ chọn)

**Ngày lập:** 2026-09-19
**Trạng thái:** Bước 1 ✅ (2026-09-19, `[2026-09-19e]`, test 2 máy) · Bước 2 ⏭
**Nhánh:** `feature/offline-first` (tách từ `master` @ `4342e315`, release 3.7.0+559)
**Nguyên tắc số 1:** app đang live trên Play Store — **người dùng đã đăng nhập không được thấy bất kỳ thay đổi hành vi nào** cho tới khi bật cờ tính năng ở bước 3.

---

## 0. Mục tiêu

```
Lần đầu mở app  → không đăng nhập → tự sinh shopId cục bộ → dùng 100% tính năng offline
                → KHÔNG gọi Firebase (0 read/write)
Muốn online     → Cài đặt → Đồng bộ & Tài khoản → đăng nhập/tạo TK
                → GIỮ NGUYÊN dữ liệu local → gắn shop vào tài khoản → upload → bật sync 2 chiều
Đăng xuất       → KHÔNG xoá SQLite (quay về offline với chính dữ liệu đó)
```

## 1. Quyết định thiết kế (đã chốt với chủ dự án)

| # | Quyết định | Lý do |
|---|---|---|
| D1 | **Một shopId duy nhất**, sinh cục bộ dạng `shop_<ms>_<rand>`; khi claim vào tài khoản MỚI thì `shops/{shopId}` trên cloud dùng đúng id này → **không re-tag** bảng nào | `user_service.dart:1111` đã cho client tự chọn id (`shopId = uid`), `firestore.rules:385` "any user can create shop". Không có Cloud Function `auth.onCreate` tự tạo shop. |
| D2 | Offline mode **chỉ Android/iOS**. Web vẫn bắt đăng nhập như cũ | SQLite web nằm trong IndexedDB, xoá cache trình duyệt là mất |
| D3 | Offline: `userId = 'local_owner'`, role `owner`, full quyền (kể cả giá vốn). Khi claim: UPDATE mọi cột `createdBy/createdByUid/userId = 'local_owner'` → uid thật | 24 cột `createdBy`, 3 `createdByUid`, 6 `userId` trong SQLite |
| D4 | **Không merge tự động** local ↔ cloud đã có dữ liệu. Claim vào tài khoản đã có shop: chỉ cho "đưa local lên" khi shop cloud RỖNG; ngược lại chỉ "tải cloud về (mất local — bắt buộc backup trước)" hoặc "huỷ" | Tài chính/công nợ/tồn kho merge sai là thảm hoạ |
| D5 | Cờ tính năng `AppSession.kOfflineModeEnabled` (const) — bước 1–2 ship với cờ **false** (không đổi gì), bước 3 bật | Cho phép release từng bước, rollback = đổi 1 dòng |
| D6 | Sinh id không thêm package `uuid` (chỉ transitive) — dùng pattern sẵn có `<prefix>_<ms>_<rand>` như `rep_…` | Không đụng pubspec |

## 2. Kiến trúc `AppSession`

```
lib/services/app_session.dart

AppSession (static, giống UserService)
 ├── mode            : none | offline | online
 ├── shopId          : String?   ← NGUỒN SỰ THẬT cho UserService.getShopIdSync()
 ├── userId          : String    ← uid thật (online) | 'local_owner' (offline)
 ├── userEmail       : String?
 ├── syncEnabled     : bool      ← mode == online
 ├── isOnline / isOffline
 ├── kOfflineModeEnabled (const, D5)
 ├── restore()       : đọc SharedPreferences lúc khởi động
 │     - FirebaseAuth.currentUser != null  → online (KHÔNG đổi gì cho user cũ)
 │     - prefs.app_session_mode == 'offline' && kOfflineModeEnabled → offline
 │     - còn lại → none (WelcomeView / LoginView)
 ├── startOffline()  : sinh shopId, ghi prefs, mode = offline
 ├── attachCloud(uid, email, shopId) : mode = online (sau claim / login thường)
 └── detachCloud()   : đăng xuất → offline nếu có shop local, KHÔNG xoá DB

Thứ tự ưu tiên trong UserService:
  super admin (chọn shop)  >  AppSession.offline (localShopId)  >  cache cũ theo uid
```

Prefs: `app_session_mode`, `app_session_shop_id`, `app_session_shop_name`, `app_session_created_at`.

## 3. Các bước

### Bước 1 — `AppSession` + đổi ruột `UserService` (0 thay đổi hành vi) — ~0.5 ngày
**Việc**
- Tạo `lib/services/app_session.dart` (mục 2), cờ D5 = `false`.
- `UserService`: `getShopIdSync`, `getCurrentShopId`, `isShopIdReady`, `ensureShopId`, `getCurrentUserPermissionsSync`, `getCurrentUserPermissions`, `canViewCostPrice`, `getUserRole`, `getCurrentUserName`, `clearCache` → thêm nhánh `if (AppSession.isOffline)` **trước** nhánh đọc `FirebaseAuth`. Nhánh online giữ nguyên từng dòng.
- `main.dart`: `AppSession.restore()` sau `Firebase.initializeApp`, trước `runApp`.
- Test unit: `test/app_session_test.dart` — offline → `getShopIdSync()` trả localShopId, quyền owner full; `restore()` với prefs rỗng → none; cờ false → không bao giờ offline.
**Nghiệm thu**
- `flutter analyze` + `flutter test` sạch.
- adb CPH2239 (m@m.com): mở app, list đơn sửa, tạo 1 SP, sync badge = 0, logcat không có exception mới.
- adb CPH2203 (shop thật, chỉ xem): mở app, vào Kho/Đơn sửa/Tài chính, đối chiếu số đơn trước–sau cài.
**Rollback:** revert 1 commit.

### Bước 2 — Hàng rào `syncEnabled` cho mọi đường ra cloud — ~1 ngày
**Việc**
- `FirestoreService`: helper `_cloudOff` + early-return ở **85 hàm static** (Future → null/false/[]; Stream → `Stream.empty()`; void → return). Không throw.
- `SyncService`: `initRealTimeSync`, `refreshCloudCollections`, `refreshCollectionNow`, `syncAllToCloud`, `downloadAllFromCloud`, `syncRepairData`, `syncPaymentRelatedData`, `forceReinitializeSync`, `syncQuickInputCodesToCloud`, `syncCustomersFromCloud` → early return.
- `SyncOrchestrator.init/syncAll`, `SyncHealthCheck.runFullCheck`, `FirebaseUsageStatsService`, `FirebaseRwStatsService`, `NotificationService.init/ensureFCMTokenValid/listen*`, `BankNotificationService.start`, `PaymentIntentService.initialize`, `ChatService`, `ClaimsService`, `PriceCatalogService` (nhánh cloud), `KiotViet*` → early return khi `!AppSession.syncEnabled`.
- Audit bằng grep: `FirebaseFirestore.instance` / `FirebaseStorage.instance` / `FirebaseFunctions` ngoài các service trên → liệt kê, gate từng chỗ.
**Nghiệm thu**
- Unit test `test/cloud_gate_test.dart`: đặt `AppSession` offline (bằng test hook) rồi gọi từng nhóm hàm `FirestoreService`/`SyncService` **không init Firebase** → không throw, trả giá trị trung tính. (Không init Firebase mà đụng SDK là throw ngay ⇒ test này chứng minh hàng rào chạy trước SDK.)
- adb 2 máy online: kịch bản CRUD 2 chiều rút gọn từ `DOCS/SYNC_AUDIT_REPORT_2026-09-18.md` (tạo SP máy A → thấy máy B; sửa đơn B → thấy A) → xác nhận online không đổi.
**Rollback:** revert.

### Bước 3 — Luồng offline lần đầu + màn "Đồng bộ & Tài khoản" — ~2 ngày
**Việc**
- Bật cờ D5.
- `AuthGate` (`main.dart:990`): khi `currentUser == null`:
  - `AppSession.isOffline` → `HomeView(role: 'owner')` **bỏ qua** `_getRoleAfterSync`, `_checkAndClearLocalDataIfShopChanged`, `_startBackgroundUserWarmup`.
  - `mode == none` && mobile → `WelcomeView`: [Dùng ngay, không cần tài khoản] / [Đăng nhập]. Web → `LoginView` như cũ.
  - Huỷ timer `_showLoggedOutFallback` 4s khi offline.
- `startOffline()`: sinh shopId, ghi `shop_settings` cục bộ tên "Cửa hàng của tôi", đặt prefs `last_synced_shop_id/user_id` = shopId/'local_owner' (để bước claim không kích hoạt xoá DB).
- `_checkAndClearLocalDataIfShopChanged`: **return sớm khi offline**; thêm guard "không bao giờ xoá khi `AppSession.justClaimed`".
- `HomeView` + tab Cài đặt: ẩn theo `AppSession.isOnline`: Chat, Thông báo, Nhân viên/Phân quyền/Chấm công/Đổi ca, Yêu cầu thanh toán, KiotViet, AI Trợ lý, Thống kê Firebase, Super admin, "Đồng bộ ngay". Thay `FirebaseAuth.currentUser?.uid` trong **đường ghi DB** ở views bằng `AppSession.userId` (audit 55 chỗ `.uid`, 23 `.email`).
- Màn mới `lib/views/sync_account_view.dart` (Cài đặt → Đồng bộ & Tài khoản):
  ```
  Chưa kết nối:  ● Chế độ Offline — Dữ liệu đang lưu trên thiết bị      [Kết nối tài khoản]
  Đã kết nối:    ● Online · Đã đồng bộ / ● Online · Chờ mạng             Tài khoản: xxx
                 Đồng bộ lần cuối: 20:35                                  [Đồng bộ ngay] [Đăng xuất]
  ```
  (3 trạng thái, tránh người dùng tưởng mất kết nối rồi bấm kết nối lại.)
- Đăng xuất (online → offline): `detachCloud()`, `cancelAllSubscriptions()`, **không** `clearAllData()`. Chỉ xoá khi người dùng chọn "Xoá dữ liệu trên máy" riêng.
- Cập nhật `lib/data/app_knowledge_base.dart` (CLAUDE.md §VII.8), `docs` liên quan.
**Nghiệm thu adb (CPH2239, đăng xuất m@m.com trước)**
1. Mở app → Welcome → "Dùng ngay" → Home hiện, tên shop mặc định.
2. Tạo SP, KH, NCC, nhập kho, bán hàng, đơn sửa (đủ 3 bước), công nợ + thu nợ, xem Tài chính 4 tab, in thử.
3. Kill app → mở lại vẫn offline, dữ liệu còn nguyên.
4. Bật máy bay → lặp mục 2 rút gọn → OK.
5. `logcat | grep -i "firestore\|permission-denied\|FirebaseAuth"` = **0 dòng** đụng cloud trong suốt phiên.
6. Cài lại build này lên CPH2203 (đang đăng nhập shop thật) → vào thẳng Home như cũ, không thấy Welcome, dữ liệu nguyên.
**Rollback:** đổi cờ D5 về `false`.

### Bước 4 — Claim vào tài khoản MỚI (đường chính) — ~2–3 ngày, rủi ro cao nhất
**Việc**
- `lib/services/claim_service.dart`:
  1. Đăng nhập/tạo TK (tái dùng `LoginView`/`RegisterView` ở "link mode": KHÔNG để `AuthGate` chạy bootstrap thường — thêm cờ `AppSession.claiming`).
  2. Đọc `users/{uid}` + claims: nếu đã có `shopId`/shop sở hữu → chuyển sang bước 5.
  3. Tạo `shops/{localShopId}` (`ownerUid`, tên, `createdAt`) + `users/{uid}` (`shopId`, `role: owner`) — sao chép đúng payload `syncUserInfo` `:1111–1121`.
  4. `getIdToken(true)` để nhận claims mới từ `syncUserClaims`.
  5. Ghi prefs `last_synced_*` = (localShopId, uid) **trước** khi AuthGate có cơ hội chạy `_checkAndClearLocalDataIfShopChanged`.
  6. UPDATE `createdBy/createdByUid/userId = 'local_owner'` → uid trên mọi bảng (D3).
  7. `attachCloud()` → `EventBus.shopChanged`.
  8. `InitialUploadJob.run()` (dưới).
  9. `initRealTimeSync` như luồng online bình thường.
- `lib/services/initial_upload_job.dart` — **không** dùng `syncAll()` hiện có (memory: từng trả `skipped` ⇒ ghi thừa):
  - Thứ tự bảng cố định: shop_settings → products → suppliers → customers → stock_entries → sales → repairs (qua `applyRepairCloudGuards`, CLAUDE.md §11) → debts/payments → finance/cash_closing → còn lại.
  - **Backfill §12**: sau khi products có `firestoreId` → UPDATE `itemSnapshotsJson.productFirestoreId`, `partsUsedDetailed.productFirestoreId`, `sales_return_items` theo map `localId → firestoreId` **trước** khi đẩy sales/repairs.
  - Ảnh: path cục bộ → upload Storage → thay URL trước khi đẩy doc.
  - Tiến độ (`Stream<progress>`), resumable (mỗi bảng chỉ đẩy `isSynced = 0`), lỗi giữa chừng → dừng, giữ `mode = online` nhưng hiện "Còn N mục chưa lên — [Thử lại]".
  - Ghi `docs` + counter read/write để đo chi phí 1 lần claim.
**Nghiệm thu adb (CPH2239)**
1. Từ trạng thái offline có dữ liệu bước 3 → Kết nối → tạo TK mới `off1@m.com`.
2. Xem tiến độ upload → xong → trạng thái Online · Đã đồng bộ.
3. Đăng xuất → Đăng nhập lại `off1@m.com` **trên cùng máy sau khi "Xoá dữ liệu trên máy"** → `downloadAllFromCloud` → đối chiếu số SP/KH/đơn/nợ/tồn kho = trước claim.
4. Máy CPH2203 **không** dùng cho test này (shop thật).
5. Kiểm tra snapshot: mở đơn bán cũ → bấm SP → mở đúng SP (§12).
6. Người dùng chạy lệnh `!` (memory: không tự query được Firestore prod) để đếm doc `shops/{id}/products` = số local.
**Rollback:** cờ riêng `kClaimEnabled` ẩn nút "Kết nối tài khoản".

### Bước 5 — Claim vào tài khoản ĐÃ CÓ shop — ~1 ngày
- Dialog 3 lựa chọn (D4):
  - **Đưa dữ liệu máy lên tài khoản** — chỉ bật khi shop cloud rỗng (đếm nhanh `products/sales/repairs` limit 1). Thực hiện: re-tag `shopId` local → shopId cloud (UPDATE mọi bảng có cột `shopId`), rồi chạy đúng `InitialUploadJob`.
  - **Tải dữ liệu tài khoản về máy (mất dữ liệu trên máy)** — bắt buộc bấm "Đã sao lưu" (bước 6) mới cho tiếp; sau đó đi luồng online thường (`clearAllData` + `downloadAllFromCloud`).
  - **Huỷ** — `signOut()`, quay lại offline nguyên trạng.
- Nghiệm thu adb: CPH2239 offline có dữ liệu → đăng nhập m@m.com (shop M có dữ liệu) → chỉ 2 lựa chọn sau khả dụng; tạo TK `off2@m.com` rồi tạo shop rỗng bằng luồng thường → lựa chọn 1 khả dụng → re-tag + upload → kiểm tra như bước 4.

### Bước 6 — Sao lưu / Khôi phục cục bộ — ~1 ngày
- Cài đặt → Sao lưu dữ liệu → **Xuất file**: `PRAGMA wal_checkpoint(TRUNCATE)` → zip `repair_shop_v22.db` + `meta.json` (schemaVersion, shopId, appVersion, ngày) → `share_plus` (memory: kéo SQLite phải kèm `-wal` — checkpoint trước là đủ).
- **Khôi phục** (chỉ khi offline): chọn file (`file_selector`, tránh bug ImagePicker màn trắng) → kiểm `meta.schemaVersion <= hiện tại` → đóng DB → thay file → mở lại (migration tự chạy) → `AppSession.startOffline(shopId từ meta)`.
- Nghiệm thu adb: xuất → xoá dữ liệu → khôi phục → đếm bằng nhau. Test FFI cho phần thay file + migration.

## 4. Kiểm soát rủi ro chung
- Mỗi bước 1 commit riêng trên `feature/offline-first`, CHANGELOG + HANDOVER cập nhật cùng commit; `git add` từng file (memory: repo từng gộp nhầm sửa dở).
- Build cài CPH2203 (shop thật) **chỉ** sau khi bước tương ứng đã đạt trên CPH2239; tuyệt đối `install -r`, không uninstall/`pm clear`.
- Không tạo nhánh code nào có thể gọi `clearAllData()` khi `AppSession.isOffline || claiming`.
- Số đo trước/sau trên CPH2203 (số đơn sửa, số SP, tổng tồn, số nợ) ghi vào HANDOVER mỗi lần cài.
- Bẫy đã biết cần né: `disposeAfterTransition` sau `showDialog`; uiautomator bounds ≠ screenshot; IME Telex phá `input text`.

## 5. Ước lượng
| Bước | Công | Rủi ro | Ship được riêng? |
|---|---|---|---|
| 1 | 0.5 ngày | thấp | có (cờ off) |
| 2 | 1 ngày | thấp | có (cờ off) |
| 3 | 2 ngày | trung bình | có — người dùng cũ không đổi |
| 4 | 2–3 ngày | **cao** | có (cờ `kClaimEnabled`) |
| 5 | 1 ngày | trung bình | có |
| 6 | 1 ngày | thấp | có |
