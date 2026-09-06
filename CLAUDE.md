# CLAUDE.md - Hướng Dẫn AI Agent cho HULUCA Shop Manager

## I. TỔNG QUAN DỰ ÁN

**Tên:** HULUCA Shop Manager  
**Phiên bản:** 1.x  
**Miền:** Quản lý cửa hàng sửa chữa điện thoại  
**Stack:** Flutter (Dart) + Firebase + SQLite  
**Ngôn ngữ UI:** Tiếng Việt (với dấu)  
**Ngôn ngữ Code/Comment:** Tiếng Anh  

---

## II. KIẾN TRÚC TỔNG THỂ

### Lớp Tầng

```
┌─────────────────────────────────────────┐
│  Views (UI Screens)                      │
│  lib/views/*.dart                        │
└────────────────────┬────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│  Widgets & Components                   │
│  lib/widgets/*.dart                      │
└────────────────────┬────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│  Services (Business Logic)               │
│  lib/services/*.dart                     │
│  - FirestoreService                      │
│  - UserService                           │
│  - SyncService                           │
│  - NotificationService                   │
│  - PaymentIntentService                  │
│  - ConnectivityService                   │
└────────────────────┬────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│  Models (Data Structures)                │
│  lib/models/*.dart                       │
│  - RepairModel, ProductModel, etc.       │
└────────────────────┬────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│  Database Layer                          │
│  lib/data/db_helper.dart                 │
│  - SQLite (offline-first)                │
│  - Real-time sync with Firestore        │
└────────────────────┬────────────────────┘
                     │
┌────────────────────▼────────────────────┐
│  External Integrations                   │
│  - Firebase Auth/Firestore/Storage       │
│  - Cloud Functions                       │
│  - KiotViet API                          │
│  - Thermal Printer                       │
│  - Geolocation                           │
└──────────────────────────────────────────┘
```

### Phân Loại Module

| Module | Đường Dẫn | Mô Tả |
|--------|---------|-------|
| **Core** | `lib/main.dart` | Entry point, Firebase init, global error handling |
| **Auth** | `lib/services/user_service.dart` | Quản lý quyền, role, shopId |
| **Firestore** | `lib/services/firestore_service.dart` | Tất cả tương tác với Firestore |
| **Sync** | `lib/services/sync_service.dart` | Real-time subscriptions, offline-first |
| **Local DB** | `lib/data/db_helper.dart` | SQLite schema v111, upsert patterns |
| **Bảng giá** | `lib/services/price_book_service.dart` | Giá đề xuất + giá GHIM (SharedPreferences, theo máy) |
| **Danh mục giá NCC** | `lib/services/price_catalog_service.dart` | Bảng giá từ hoá đơn NCC — SQLite + Firestore theo `shopId` |
| **Payments** | `lib/services/payment_intent_service.dart` | Xử lý thanh toán |
| **Notifications** | `lib/services/notification_service.dart` | Firebase Cloud Messaging + local |
| **UI/Views** | `lib/views/` | Các màn hình (login, home, create repair, etc.) |

---

## III. CÁC NGUYÊN TẮC QUAN TRỌNG

### 1. Admin Detection
- **Nguồn sự thật DUY NHẤT: Firebase custom claims.** KHÔNG còn kiểm email hardcode
  (`main.dart` ghi rõ *"dựa trên custom claims, không dùng email hardcode"*).
  Mọi nơi đều so cùng một điều kiện:
  `claims['isSuperAdmin'] == true || claims['role'] == 'super_admin'`.
- **Claims do Cloud Function cấp:** `functions/index.js` → `buildCustomClaims()` đặt
  `isSuperAdmin = (users/{uid}.role === "super_admin")`. Muốn cấp/thu quyền super
  admin thì **sửa field `role` của doc `users/{uid}`**, trigger `syncUserClaims`
  tự cấp lại claims. `VALID_ROLES` = owner | manager | employee | technician | user | super_admin.
- **⚠️ BẪY ĐẶT TÊN:** `UserService.getUserRole()` **map claims `super_admin` → trả
  về `'admin'`** (tên role app-level). Nghĩa là `'admin'` trong app ≠ `'admin'`
  dưới Firestore. Ghi `role: "admin"` xuống `users/{uid}` sẽ khiến
  `isSuperAdmin=false` và **super admin mất sạch quyền** — xem
  `docs/AUDIT_SUPER_ADMIN_2026-09-05.md` mục SA-01. Tuyệt đối KHÔNG "sửa" bằng
  cách coi `role=='admin'` là super admin: `getCurrentUserPermissions` cấp full
  quyền cho `role=admin`, đó là vai trò của chủ shop/quản lý.
- **`UserService._isSuperAdmin(user)`** chỉ đọc cache trong bộ nhớ
  (`_cachedIsSuperAdmin && _cachedIsSuperAdminUid == user.uid`) — cache này do các
  đường trên set sau khi đọc claims, và bị xoá trong `clearCache()` khi đăng xuất.
- **Quyền hạn:** super admin KHÔNG bypass `shopId` ở tầng dữ liệu. Cách hoạt động là
  **chọn shop** → `getShopIdSync()` trả `_adminSelectedShopId`, mọi truy vấn vẫn lọc
  theo `shopId` như người thường (`firestore_service.dart` có 0 tham chiếu `isSuperAdmin`).
- **Server luôn kiểm lại:** `firestore.rules` → `isSuperAdmin()` chỉ đọc
  `request.auth.token` (~30 chỗ dùng). Client bị sửa cũng không qua được.

### 2. Service-First Access
- **Quy tắc:** Tất cả Firestore reads/writes phải thông qua service classes
- **Không bao giờ:** Gọi Firebase SDK trực tiếp từ widgets
- **Ví dụ:** `FirestoreService.addRepair(repairModel)` trả về doc ID hoặc null

### 3. Data Isolation (Multi-Tenant)
- **ShopId:** Từ `UserService.getCurrentShopId()` (lưu cache)
- **Filtering:** Tất cả queries phải filter theo `shopId` trừ super-admin
- **Firestore structure:** Dữ liệu lưu dưới `/shops/{shopId}/{collection}`

### 4. Sync on Auth
- **Trigger:** `UserService.syncUserInfo()` gọi từ `AuthGate`
- **Tác vụ:** Đảm bảo user/shop setup, tạo shop doc nếu cần
- **Callback:** SyncService tự động subscribe sau khi auth thành công

### 5. Validation
- **Location:** `lib/services/user_service.dart`
- **Ví dụ:** `validatePhone()` kiểm tra 9-12 chữ số (sau khi làm sạch)
- **Exception handling:** Throw exception nếu invalid, catch ở caller

### 6. Error Handling
- **Global:** `runZonedGuarded` trong `main.dart`
- **Services:** try/catch + rethrow
- **Soft failures:** Trả về null/false thay vì throw

### 7. Notifications
- **Init:** `NotificationService.init()` trong `main.dart`
- **Listener:** `listenToNotifications()` trong `AuthGate` hiển thị snackbars
- **Rate limit:** 3 thông báo / 10 giây

### 8. Local Persistence
- **Pattern:** Upsert (insert or replace)
- **Unique key:** `firestoreId`
- **Conflict resolution:** `isSynced` flag

### 9. Giá vốn — phân quyền BẮT BUỘC 2 tầng
- **Quyền:** `UserService.canViewCostPrice()` (`allowViewCostPrice`; super-admin luôn true)
- **Quy tắc:** chặn ở CẢ UI lẫn tầng service — service phải **xoá trường giá vốn khỏi dữ liệu trả về**, không chỉ ẩn trên giao diện. Xuất Excel cũng phải bỏ cột giá vốn.
- **Không bao giờ** lấy giá vốn thay cho giá thu khách khi chưa đặt giá — hiển thị "Chưa thiết lập giá thu khách".
- Tham khảo: `PriceCatalogService.buildRows/lookup`, `PriceBookService.exportToExcel`

### 10. Soft Deletes
- **Firestore:** Update với `deleted: true` + `updatedAt: serverTimestamp()`
- **Local DB:** Mark deleted nhưng giữ records
- **Queries:** Luôn filter `deleted != true`

---

### 11. Ghi đơn sửa lên cloud — BẮT BUỘC qua guard
- **Mọi đường ghi `repairs` lên Firestore** phải gọi
  `SyncOrchestrator.applyRepairCloudGuards(data, cloudData)` trước khi ghi:
  `_handleCreate`, `_handleUpdate` (sync_orchestrator) và
  `syncRepairData` / `syncAllToCloud` (sync_service).
- **Không dùng `.set()` không merge** cho `repairs` — ghi đè nguyên document sẽ
  xoá sạch field mà bản local không có (`repairedBy`, `finishedAt`, …).
- **Lý do:** sự cố 2026-09-05 — một máy còn giữ bản chụp lúc TẠO đơn
  (`isSynced=0`) đẩy lên, làm đơn đang "Chờ duyệt giao" tụt về "Tiếp nhận" và
  mất tên KTV trên toàn shop. Xem `docs/CHANGELOG.md` mục `[2026-09-05i]`.
- **Bẫy:** `_normalizeRepairStatus` trả về **1 = "Tiếp nhận"** khi thiếu/không
  đọc được status. Tuyệt đối không dùng giá trị đoán này để ghi đè trạng thái
  thật trên cloud cho payload một phần.
- **Thông báo tạo đơn:** chat/push "ĐƠN MỚI" phải căn cứ **document trên cloud**,
  không căn cứ bộ đếm của `syncAll()` (`skipped` / `failed` do món khác trong
  hàng đợi đều làm mất thông báo).

---

## IV. WORKFLOW PHÁT TRIỂN

### Chạy Ứng Dụng
```bash
flutter pub get
flutter run
```

### Build APK Release
```bash
flutter build apk --release
```

### Chạy Analyze
```bash
flutter analyze
```

### Chạy Tests
```bash
flutter test
```

### Chạy Integration Tests
```bash
flutter test integration_test/
```

---

## V. CONFIGURATION FILES

### Firebase Config
- **Path:** `lib/firebase_options.dart`
- **Android:** `android/app/google-services.json`
- **Cloud Functions:** `functions/` (Node.js)

### Localization
- **ARB files:** `lib/l10n/`
- **Generate:** `flutter gen-l10n`

### Database
- **Local DB path:** `repair_shop_v22.db`
- **Schema version:** 111
- **Location:** `lib/data/db_helper.dart`

---

## VI. CỤC BỘ ĐIỀU HƯỚNG

### Điểm Cần Kiểm TRA TRƯỚC TIÊN

| File | Mục đích | Ưu tiên |
|------|---------|--------|
| `lib/main.dart` | Bootstrap, auth gate, global error handling | ⭐⭐⭐ |
| `lib/services/user_service.dart` | Role logic, shopId caching, validation | ⭐⭐⭐ |
| `lib/services/firestore_service.dart` | Firestore CRUD + shopId filtering | ⭐⭐⭐ |
| `lib/services/sync_service.dart` | Real-time subscriptions | ⭐⭐ |
| `lib/data/db_helper.dart` | SQLite schema, upsert patterns | ⭐⭐ |
| `lib/models/` | Data structures (RepairModel, etc.) | ⭐⭐ |
| `pubspec.yaml` | Dependencies | ⭐ |

---

## VII. QUI TRÌNH TÀI LIỆU HÓA BẮT BUỘC

Mỗi thay đổi code PHẢI tự động cập nhật:

1. **CLAUDE.md** - Nếu thay đổi kiến trúc, module, quy tắc
2. **.github/copilot-instructions.md** - Nếu thay đổi hướng dẫn AI, workflow
3. **docs/CHANGELOG.md** - Thêm mục mới (ngày, summary, files)
4. **docs/HANDOVER.md** - Cập nhật status, tasks, issues
5. **docs/DOCUMENTATION_INDEX.md** - Nếu thêm/xóa file tài liệu
6. **DOCS/FULL_DOCUMENTATION.md** - Nếu thay đổi kiến trúc/services
7. **Tài liệu chuyên biệt** - Permission, UI, Finance, KiotViet, Image Upload
8. **`lib/data/app_knowledge_base.dart`** - Nếu THÊM / ĐỔI / BỎ một tính năng hoặc màn hình, hoặc đổi đường dẫn menu. Đây là nguồn sự thật DUY NHẤT cho AI Trợ Lý *và* Trung tâm trợ giúp (`HelpCenterRepository.topics`). Không cập nhật ⇒ AI trả lời sai vị trí / thiếu tính năng.

---

## VIII. DANH SÁCH FILE QUAN TRỌNG

### Views (Màn Hình)
- `lib/views/login_view.dart` - Đăng nhập
- `lib/views/home_view.dart` - Trang chủ
- `lib/views/create_repair_order_view.dart` - Tạo đơn sửa
- `lib/views/inventory_view.dart` - Kho hàng
- `lib/views/sales_view.dart` - Bán hàng
- `lib/views/customer_view.dart` - Khách hàng
- `lib/views/report_view.dart` - Báo cáo

### Services
- `lib/services/firestore_service.dart` - ⭐ Firestore CRUD
- `lib/services/user_service.dart` - ⭐ Auth & role
- `lib/services/sync_service.dart` - Real-time sync
- `lib/services/notification_service.dart` - Thông báo
- `lib/services/payment_intent_service.dart` - Thanh toán
- `lib/services/connectivity_service.dart` - Kết nối mạng

### Models
- `lib/models/repair_model.dart`
- `lib/models/product_model.dart`
- `lib/models/sale_model.dart`
- `lib/models/customer_model.dart`

### Database
- `lib/data/db_helper.dart` - ⭐ SQLite wrapper

---

## IX. QUICK REFERENCES

### Lấy Role
```dart
final role = await UserService.getUserRole(uid);
// Returns: 'admin', 'manager', 'staff', or null
```

### Thêm Repair
```dart
final docId = await FirestoreService.addRepair(repairModel);
// Tự động thêm shopId, trả về doc ID hoặc null
```

### Initialize Sync
```dart
await SyncService.initRealTimeSync((changes) {
  // Callback với thay đổi từ Firestore
});
```

### Validate Phone
```dart
try {
  UserService.validatePhone(phone);
  // Valid, tiếp tục
} catch (e) {
  // Thông báo lỗi (Vietnamese)
  print(e.toString());
}
```

---

## X. TRẠNG THÁI HIỆN TẠI

- **Phiên bản:** 1.x (develop)
- **Build Status:** ✓ Passing
- **Analyze Status:** ✓ No errors
- **Database:** SQLite v111
- **Firebase:** Integrated (Auth, Firestore, Storage, Functions)
- **KiotViet:** Integrated (API sync)
- **Payments:** Integrated (PaymentIntentService)
- **Finance V2 Excel:** Tất cả nhãn kỹ thuật đã chuyển sang tiếng Việt (action types, column headers, sheet names, số tiền có dấu phẩy)

---

## XI. LIÊN HỆ & HỖ TRỢ

- **Main Config:** `.github/copilot-instructions.md`
- **Full Documentation:** `DOCS/FULL_DOCUMENTATION.md`
- **Handover Notes:** `docs/HANDOVER.md`
- **Changelog:** `docs/CHANGELOG.md`
- **Documentation Index:** `docs/DOCUMENTATION_INDEX.md`

---

**Cập nhật lần cuối:** 2026-05-19  
**Người cập nhật:** GitHub Copilot  
**Phiên bản:** 1.0
