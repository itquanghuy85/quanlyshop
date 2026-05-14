# Báo Cáo Kiểm Tra Phân Quyền (Permission Audit Report)

**Ngày thực hiện:** 2025  
**Phạm vi:** Toàn bộ ứng dụng quản lý cửa hàng  
**Kết quả:** 10 lỗi phát hiện và sửa chữa

---

## 1. Tổng Quan

Cuộc kiểm tra được khởi động do phát hiện lỗi nghiêm trọng: tài khoản chủ shop mới tạo không thể xem "giá vốn" khi chỉnh sửa đơn sửa chữa — hiển thị như một nhân viên thay vì chủ shop. Audit toàn bộ codebase phát hiện 10 lỗi phân quyền từ nghiêm trọng đến thấp (9 lỗi vòng 1-2, 1 lỗi vòng 3).

---

## 2. Lỗi Được Phát Hiện và Sửa Chữa

### Lỗi #1 — NGHIÊM TRỌNG: Dùng sai nguồn vai trò trong `repair_detail_view`

**File:** `lib/views/repair_detail_view.dart` — `_checkPermission()`  
**Vấn đề:** Hàm gọi `getRoleFast()` (đọc từ Firebase Claims) riêng biệt để tính `isManagerLike`, trong khi tất cả các permission flag khác được đọc từ `getCurrentUserPermissions()` (Firestore). Với chủ shop mới tạo, Claims chưa được đồng bộ từ Cloud Function (race condition) → `getRoleFast()` trả về `'user'` → `isManagerLike = false` → không thể chỉnh sửa tài chính và giá vốn bị ẩn.  
**Sửa:** Bỏ hoàn toàn lời gọi `getRoleFast()`. Dùng `perms['isManagerLike'] == true` từ cùng một lần gọi `getCurrentUserPermissions()` — nhất quán và không bị ảnh hưởng bởi Claims trễ.

```dart
// TRƯỚC (lỗi):
final role = await UserService.getRoleFast();
final isManagerLike = (role == 'owner' || role == 'admin' || role == 'manager');
final perms = await UserService.getCurrentUserPermissions(forceRefresh: true);

// SAU (đúng):
final perms = await UserService.getCurrentUserPermissions(forceRefresh: true);
final isManagerLike = perms['isManagerLike'] == true;
```

---

### Lỗi #2 — TRUNG BÌNH: Owner có thể bị mất quyền xem tài chính

**File:** `lib/services/user_service.dart` — `getCurrentUserPermissions()`  
**Vấn đề:** `allowViewRevenue`, `allowViewExpenses`, `allowViewDebts` được đọc từ Firestore `data` field trực tiếp mà không có cơ chế bảo vệ cho owner. Nếu Firestore vô tình có `allowViewRevenue: false` cho owner (ví dụ: do sửa nhầm), owner mất quyền xem tài chính.  
**Sửa:** Thêm force-true cho tất cả permission tài chính khi `isOwnerOrAdmin == true`. Owner/admin không bao giờ có thể bị khóa quyền xem tài chính.

```dart
// Bổ sung force-true cho owner/admin:
'allowViewRevenue': isOwnerOrAdmin ? true : ...,
'allowViewExpenses': isOwnerOrAdmin ? true : ...,
'allowViewDebts': isOwnerOrAdmin ? true : ...,
'allowViewCostPrice': isManagerLike ? true : ...,
'allowViewSettings': isManagerLike ? true : ...,
'allowManageStaff': isManagerLike ? true : ...,
```

---

### Lỗi #3 — TRUNG BÌNH: Shop mới không ghi permission flags cho owner

**File:** `lib/services/user_service.dart` — `syncUserInfo()`  
**Vấn đề:** Khi tạo shop mới (`isNewShop == true`) với vai trò owner, các permission flag không được ghi tường minh vào Firestore. Quyền được tính on-the-fly từ defaults, nhưng thiếu các field explicit có thể gây sự cố trong các luồng khác dựa vào `data['allowViewRevenue']` trực tiếp.  
**Sửa:** Khi `isNewShop == true && resolvedRole == 'owner'`, ghi toàn bộ `_defaultPermissionsForRole('owner')` vào Firestore user document.

```dart
// Được thêm vào syncUserInfo():
if (isNewShop && resolvedRole == 'owner') {
  final ownerPerms = _defaultPermissionsForRole('owner');
  for (final entry in ownerPerms.entries) {
    if (!userData.containsKey(entry.key)) {
      userData[entry.key] = entry.value;
    }
  }
}
```

---

### Lỗi #4 — TRUNG BÌNH: `appLocked` khóa nhầm cả owner

**File:** `lib/services/user_service.dart` — `getCurrentUserPermissions()`  
**Vấn đề:** Khi Super Admin bật `appLocked = true` cho shop, tất cả user kể cả owner bị khóa hoàn toàn. Điều này không đúng: owner phải có thể mở ứng dụng shop của mình.  
**Sửa:** `appLocked` chỉ áp dụng cho user KHÔNG phải owner/admin.

```dart
// TRƯỚC: if (shopAppLocked)
// SAU:   if (shopAppLocked && !isOwnerOrAdmin)
```

---

### Lỗi #5 — THẤP: `hr_salary_settings_view` không cho phép manager

**File:** `lib/views/hr_salary_settings_view.dart` — `_checkPermission()`  
**Vấn đề:** Kiểm tra chỉ gồm `role == 'admin' || role == 'owner'`, thiếu `manager`. Mặc định của ứng dụng cho phép manager có `allowManageStaff: true` và `allowViewSettings: true`, nhưng màn hình cài đặt lương không nhận ra vai trò này.  
**Sửa:** Thêm `|| role == 'manager'`.

```dart
// TRƯỚC:
setState(() => _isAdmin = role == 'admin' || role == 'owner');

// SAU:
setState(() => _isAdmin = role == 'admin' || role == 'owner' || role == 'manager');
```

---

### Lỗi #6 — CẢI TIẾN: Thiếu `role` và `isManagerLike` trong permissions map

**File:** `lib/services/user_service.dart` — `getCurrentUserPermissions()`  
**Vấn đề:** Map trả về không có key `role` và `isManagerLike`. Các views muốn biết `isManagerLike` phải gọi thêm `getRoleFast()` hoặc `getUserRole()` — dẫn tới nguy cơ dùng nguồn không nhất quán (xem Lỗi #1).  
**Sửa:** Thêm `'role': role` và `'isManagerLike': isManagerLike` vào map. Tất cả views giờ có thể dùng một lần gọi duy nhất.

---

### Lỗi #7 — CẢI TIẾN: Super admin path thiếu `role` và `isManagerLike`

**File:** `lib/services/user_service.dart` — `getCurrentUserPermissions()` và `getCurrentUserPermissionsSync()`  
**Vấn đề:** Khi người dùng là super admin, hàm trả về `_defaultPermissionsForRole('super_admin')` không có key `role` và `isManagerLike`. Nếu view dùng `perms['isManagerLike'] == true`, super admin sẽ bị coi là không có quyền.  
**Sửa:** Thêm `role` và `isManagerLike: true` vào kết quả trả về cho super admin path trong cả hai hàm.

```dart
// getCurrentUserPermissions() — super admin path:
return {..._defaultPermissionsForRole('super_admin'), 'role': 'super_admin', 'isManagerLike': true};

// getCurrentUserPermissionsSync() — super admin path:
return {..._defaultPermissionsForRole('admin'), 'role': 'admin', 'isManagerLike': true};
```

---

### Lỗi #8 — NGHIÊM TRỌNG: `_updateStatus()` dùng `getRoleFast()` để quyết định giao máy

**File:** `lib/views/repair_detail_view.dart` — `_updateStatus()` (khi `newStatus == 4`)  
**Vấn đề:** Khi người dùng bấm "Giao máy" (chuyển đơn lên status 4), hàm gọi `getRoleFast()` (Firebase Claims) để kiểm tra vai trò. Với chủ shop mới, Claims chưa sync → trả về `'user'` → `isManagerOrOwner = false` → tưởng là nhân viên → gọi `_submitForDeliveryApproval()` thay vì `_approveDelivery()`.  
**Sửa:** Thay `getRoleFast()` bằng `_isManagerLike` (đã tính từ Firestore trong `_checkPermission()`).

```dart
// TRƯỚC (lỗi):
final currentRole = await UserService.getRoleFast();
final isManagerOrOwner =
    currentRole == 'admin' || currentRole == 'owner' || currentRole == 'manager';

// SAU (đúng):
final isManagerOrOwner = _isManagerLike; // Dùng từ Firestore, không dùng stale Claims
```

---

### Lỗi #9 — NGHIÊM TRỌNG: `_buildBottomActions()` dùng `FutureBuilder` + `getRoleFast()` để chọn nút

**File:** `lib/views/repair_detail_view.dart` — `_buildBottomActions()`  
**Vấn đề:** Hàm render thanh nút dưới màn hình dùng `FutureBuilder<String>` với `UserService.getRoleFast()` để quyết định hiển thị nút "GIAO" hay "Y/C DUYỆT". Với chủ shop mới (Claims chưa sync), `snapshot.data` là `'user'` → `isManager = false` → hiển thị nút "Y/C DUYỆT" thay vì "GIAO" cho owner.  
**Sửa:** Bỏ `FutureBuilder` và `getRoleFast()`, thay bằng `_isManagerLike` (state var đã tính từ Firestore).

```dart
// TRƯỚC (lỗi):
return FutureBuilder<String>(
  future: UserService.getRoleFast(),
  builder: (context, snapshot) {
    final role = snapshot.data ?? 'user';
    final isManager = role == 'admin' || role == 'owner' || role == 'manager';
    ...
  },
);

// SAU (đúng):
final isManager = _isManagerLike; // Đồng bộ, từ Firestore, không gây async flash
...
return Container(...);
```

---

### Lỗi #10 — THẤP: `supplier_list_view` dùng `getRoleFast()` khi mở InventoryView

**File:** `lib/views/supplier_list_view.dart` — nút "Quản lý kho" trong AppBar  
**Vấn đề:** Khi nhấn nút "Quản lý kho", code gọi `UserService.getRoleFast()` (Firebase Claims) để lấy `role` truyền vào `InventoryView(role: role)`. `InventoryView` dùng `widget.role` trong `canManageProduct` để hiển thị/ẩn các nút thêm/sửa sản phẩm. Với chủ shop mới (Claims chưa sync), `getRoleFast()` trả về `'user'` → `canManageProduct = false` → owner không thể thêm/sửa sản phẩm trong kho từ màn hình nhà cung cấp.  
**Sửa:** Thay `getRoleFast()` bằng `getUserRole(uid)` (Firestore-based). Thêm guard `context.mounted` sau async call.

```dart
// TRƯỚC (lỗi):
onPressed: () async {
  final role = await UserService.getRoleFast();
  Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: role)));
}

// SAU (đúng):
onPressed: () async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  final role = uid != null ? await UserService.getUserRole(uid) : 'user';
  if (!context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryView(role: role)));
}
```

---

## 3. Danh Sách File Bị Ảnh Hưởng

| File | Thay đổi |
|------|----------|
| `lib/services/user_service.dart` | Force-true permissions, thêm role/isManagerLike, sửa appLocked, ghi permissions mới khi tạo shop, sửa super admin paths |
| `lib/views/repair_detail_view.dart` | Bỏ `getRoleFast()` trong `_checkPermission()`, `_updateStatus()`, và `_buildBottomActions()` — dùng `_isManagerLike` thống nhất |
| `lib/views/hr_salary_settings_view.dart` | Thêm `manager` vào điều kiện kiểm tra |
| `lib/views/supplier_list_view.dart` | Thay `getRoleFast()` bằng `getUserRole(uid)` khi mở InventoryView; thêm `context.mounted` guard |

---

## 4. Phân Tích Root Cause

**Nguyên nhân gốc của lỗi chính (#1):**  
Firebase Custom Claims có độ trễ khi Cloud Function `syncUserClaims` trigger chưa chạy xong sau khi tạo tài khoản mới. Trong vài giây/phút đầu sau đăng nhập, `getRoleFast()` trả về role cũ hoặc không có role. Vì `_checkPermission()` dùng cả hai nguồn (Claims cho `isManagerLike`, Firestore cho permissions), kết quả không nhất quán.

**Giải pháp dứt điểm:** Chỉ dùng một nguồn duy nhất — `getCurrentUserPermissions()` từ Firestore — cho tất cả kiểm tra quyền.

---

## 5. Phân Quyền Chuẩn Sau Khi Sửa

| Quyền | employee | technician | manager | owner | super_admin |
|-------|----------|------------|---------|-------|-------------|
| allowViewSales | ✅ | ❌ | ✅ | ✅ | ✅ |
| allowViewRepairs | ✅ | ✅ | ✅ | ✅ | ✅ |
| allowViewRevenue | ❌ | ❌ | ⚙️* | ✅ | ✅ |
| allowViewExpenses | ❌ | ❌ | ⚙️* | ✅ | ✅ |
| allowViewDebts | ❌ | ❌ | ⚙️* | ✅ | ✅ |
| allowViewCostPrice | ❌ | ❌ | ✅ | ✅ | ✅ |
| allowViewSettings | ❌ | ❌ | ✅** | ✅ | ✅ |
| allowManageStaff | ❌ | ❌ | ✅ | ✅ | ✅ |

> ⚙️* Manager có thể bị khóa tài chính bởi `shopAdminFinanceLocked` (owner quyết định)  
> ✅** Manager có thể bị khóa settings bởi `staffSettingsLocked` (super admin quyết định)  

---

## 6. Điểm Cần Theo Dõi (Watchpoints)

### 6.1 Claims race condition — đã xử lý triệt để
- **Tình trạng:** Tất cả 3 chỗ trong `repair_detail_view.dart` từng dùng `getRoleFast()` đã được thay bằng `_isManagerLike`. `supplier_list_view.dart` cũng đã được sửa (Lỗi #10).
- **Bài học:** Không bao giờ dùng `getRoleFast()` để quyết định UI hoặc nghiệp vụ. Luôn dùng state vars được tính từ `getCurrentUserPermissions()` hoặc `getUserRole(uid)` (Firestore).
- **Cần theo dõi:** Kiểm tra toàn bộ các lần gọi `getRoleFast()` còn lại trong app — các vị trí còn lại (`main.dart`, `home_view.dart`, `shop_switcher_widget.dart`) đều đã xác nhận là acceptable (Firestore-first pattern hoặc display-only).

### 6.2 `_defaultPermissionsForRole` không có `role`/`isManagerLike` key
- **Nơi:** Hàm `_defaultPermissionsForRole` trả về `Map<String, bool>` (không có hai key dynamic mới).
- **Hành động:** Đây là thiết kế đúng — `role` và `isManagerLike` được thêm bởi `getCurrentUserPermissions()`. Không được thêm vào `_defaultPermissionsForRole`.

### 6.3 Firestore user document mới thiếu permission fields
- **Nơi:** Tài khoản được tạo trước khi sửa Lỗi #3 có thể thiếu explicit permission fields.
- **Hành động:** Lỗi #2 (force-true) giúp mitigate, nhưng nên có migration script nếu cần.

### 6.4 `updateUserPermissions` không bảo vệ owner
- **Nơi:** `lib/services/user_service.dart` — `updateUserPermissions()`.
- **Nguy cơ:** Nếu staff_list_view gọi `updateUserPermissions` với `allowViewRevenue: false` cho owner, Firestore sẽ ghi `false`. Lỗi #2 (force-true trong `getCurrentUserPermissions`) sẽ bù lại khi đọc, nhưng vẫn là data "bẩn" trong Firestore.
- **Hành động (khuyến nghị):** Thêm guard trong `updateUserPermissions` để không cho ghi `false` vào permission cốt lõi của owner.

---

## 7. Kiến Trúc Phân Quyền Sau Audit

```
getCurrentUserPermissions() [Single Source of Truth]
├── Super Admin path → _defaultPermissionsForRole('super_admin') + {role, isManagerLike: true}
├── Cache hit       → _cachedPermissions (đã có role + isManagerLike)
└── Firestore read  → data merge defaults
    ├── isOwnerOrAdmin: force-true Revenue/Expenses/Debts/CostPrice/Settings/ManageStaff
    ├── isManagerLike:  force-true CostPrice/Settings/ManageStaff
    ├── shopAppLocked:  chỉ áp dụng cho !isOwnerOrAdmin
    └── adminFinanceLocked: chỉ áp dụng cho role == 'manager'

repair_detail_view — Luồng Giao Máy (đã sửa)
├── _checkPermission()    → Firestore → _isManagerLike (state var)
├── _buildBottomActions() → _isManagerLike → nút GIAO hoặc Y/C DUYỆT
└── _updateStatus(4)      → _isManagerLike → _approveDelivery() hoặc _submitForDeliveryApproval()
```

---

*Báo cáo được tạo sau quá trình audit tự động toàn bộ codebase.*
