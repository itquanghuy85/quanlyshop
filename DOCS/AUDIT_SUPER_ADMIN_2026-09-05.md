# AUDIT SUPER ADMIN — 2026-09-05

**Phạm vi:** đường cấp quyền super admin (client + Cloud Functions + Firestore
rules), Super Admin Console, cổng PIN, nhật ký kiểm toán, xoá shop.
**Máy thật:** Oppo CPH2239 (`WCE65565HMDYOB59`), tài khoản `admin@huluca.com`
(uid `46H9mmb68BQFDz6o6QkNzpWk1I33`), project `huyaka-1809`.

**Kết luận:** 🔴 **NOT READY** cho tính năng super admin — hiện **không dùng
được**. Kiến trúc phân quyền thì đúng và chắc; vấn đề nằm ở **1 lỗi cấu hình dữ
liệu** (SA-01) cộng **2 lỗi bảo mật cổng PIN** (SA-02, SA-03).

---

## 1. ĐIỂM ĐẠT (kiến trúc phân quyền)

* **Nguồn sự thật là custom claims, không phải client.** Cả 4 đường cấp quyền
  (`main.dart:697`, `user_service.dart:698/730/996`) đều đọc
  `claims['isSuperAdmin'] == true || claims['role'] == 'super_admin'`. Claims do
  Cloud Function ký server-side ⇒ client **không giả mạo được**.
* **Cache client gắn chặt uid.** `_isSuperAdmin()` yêu cầu
  `_cachedIsSuperAdmin && _cachedIsSuperAdminUid == user.uid` ⇒ đổi tài khoản
  không kế thừa nhầm quyền. `clearCache()` xoá cả 2 cờ khi đăng xuất.
* **Rules độc lập hoàn toàn với client.** `firestore.rules` `isSuperAdmin()` chỉ
  đọc `request.auth.token.isSuperAdmin / .role` — 30 chỗ dùng. Client có bị sửa
  cũng không qua được server.
* **Tầng dữ liệu KHÔNG có đường tắt.** `firestore_service.dart` có **0** tham
  chiếu `isSuperAdmin`: super admin làm việc bằng cách **chọn shop**
  (`_adminSelectedShopId`), mọi truy vấn vẫn lọc `shopId` như người thường ⇒
  cách ly multi-tenant giữ nguyên.
* **Nhật ký kiểm toán bất biến thật.** `admin_audit_log`: `allow update: false`,
  `allow delete: false`, chỉ super admin đọc/tạo, bắt buộc có
  `uid/action/timestamp`.
* **`admin_security` khoá đúng chủ.** `allow read/create/update: isSuperAdmin()
  && uid() == docId`, cấm xoá ⇒ super admin A không đọc được PIN của B.
* **Console tự xác minh lại.** `_bootstrapAccess` gọi
  `getClaimsFromToken(forceRefresh: true)` chứ không tin state cũ; có idle guard
  + session timeout 30 phút.

---

## 2. 🔴 SA-01 — TÀI KHOẢN SUPER ADMIN KHÔNG CÓ QUYỀN SUPER ADMIN (CHẶN)

**Hiện trạng:** toàn bộ tính năng super admin **không truy cập được** trên
production.

**Bằng chứng (log máy thật):**
```
🔑 Token claims: shopId=IXmcXpc13VMPocoE8oN8hq73uHz1, role=admin
⚡ runFullCheck: email=admin@huluca.com, isSuperAdmin=false
⚡ initRealTimeSync: email=admin@huluca.com, isSuperAdmin=false
```

**Quan sát được trên máy:**
1. Mục **"Trung tâm quản trị"** bị ẩn trong Cài đặt (`home_view.dart:6385`
   `if (_isSuperAdmin)` = false).
2. Mở thẳng console → màn **"Bạn không có quyền truy cập Super Admin Console."**
3. Đăng nhập không vào console (`main.dart:1091`) mà rơi vào shop thường
   ("Super Admin Shop") như một admin bình thường.

**Nguyên nhân:** `functions/index.js:34-41`
```js
const roleFromDoc = (userData?.role || "user").toString().trim().toLowerCase();
const isSuperAdmin = roleFromDoc === "super_admin";
return { shopId, role: isSuperAdmin ? "super_admin" : roleFromDoc, isSuperAdmin };
```
Doc `users/46H9mmb68BQFDz6o6QkNzpWk1I33` đang có `role: "admin"`. Chuỗi
`"admin"` **không bằng** `"super_admin"` ⇒ claims ra `role:"admin",
isSuperAdmin:false`, khớp đúng log. Đáng chú ý: `"admin"` **không nằm trong**
`VALID_ROLES` (`["owner","manager","employee","technician","user","super_admin"]`).

**Vì sao dễ ghi nhầm:** app dùng `'admin'` làm tên role **nội bộ** cho super
admin — `UserService.getUserRole()` map claims `super_admin` → trả về `'admin'`.
Hai tầng đặt tên khác nhau cho cùng một vai trò.

**Cách sửa (dữ liệu, KHÔNG phải code):** đặt
`users/46H9mmb68BQFDz6o6QkNzpWk1I33.role = "super_admin"`. Cloud Function
`syncUserClaims` (trigger `onDocumentWritten("users/{userId}")`) tự cấp lại
claims. Đảo ngược bằng cách đổi role về như cũ.

> ⚠️ **KHÔNG** sửa code kiểu "coi `role=='admin'` là super admin":
> `getCurrentUserPermissions` cấp **full quyền** cho `role=admin`, đó là vai trò
> app-level của chủ shop/quản lý ⇒ sẽ cấp nhầm quyền super admin hàng loạt.

**Trạng thái:** chờ sửa dữ liệu trên Firebase Console. Phần audit Console /
cross-shop vì vậy là **NOT RUN (BLOCKED)**.

---

## 3. 🟠 SA-02 — PIN super admin băm yếu (MEDIUM)

`super_admin_security_service.dart:243`
```dart
static String _hashPin(String pin) {
  final bytes = utf8.encode('super_admin_salt_huluca_$pin');
  return sha256.convert(bytes).toString();
}
```
* **1 vòng SHA-256**, salt là **hằng số biên dịch dùng chung cho mọi user**.
* PIN chỉ **4–6 chữ số** ⇒ không gian khoá `10⁴+10⁵+10⁶ ≈ 1,11 triệu`.
* Vì salt cố định, **một bảng tra dựng sẵn phá được PIN của bất kỳ super admin
  nào**; duyệt cạn 1,11 triệu SHA-256 mất chưa tới 1 giây trên máy thường.
* Hash nằm ở 2 nơi: `SharedPreferences` (lấy được nếu có app data / bản debug)
  và Firestore `admin_security/{uid}`.

**Đề xuất:** KDF chậm (PBKDF2 nhiều vòng / scrypt / bcrypt) + **salt ngẫu nhiên
theo từng user** lưu kèm hash.

---

## 4. 🟠 SA-03 — Cổng PIN bị vượt hoàn toàn trên máy mới (MEDIUM-HIGH)

`super_admin_console_view.dart:_bootstrapAccess` chỉ hỏi PIN khi:
```dart
final hasPinSetup = await SuperAdminSecurityService.isPinSetup();
if (hasPinSetup && !SuperAdminSecurityService.isSessionValid()) { ...hỏi PIN... }
```
mà `isPinSetup()` **chỉ đọc SharedPreferences**:
```dart
return prefs.getBool(_pinSetKey) ?? false;
```

⇒ **Cài lại app / xoá dữ liệu app / dùng máy khác** thì prefs rỗng,
`isPinSetup()` trả `false`, **console không hỏi PIN lần nào** — vào thẳng chỉ
với email + mật khẩu. PIN trở thành lớp bảo vệ **chỉ có tác dụng trên đúng máy
đã đặt nó**.

**Nghịch lý chứng minh đây là lỗi, không phải chủ ý:** `verifyPin()` ĐÃ có nhánh
đọc `pinHash` từ Firestore khi prefs trống (và comment ở `setupPin` ghi rõ
*"Also store in Firestore for cross-device sync"*). Chỉ riêng `isPinSetup()`
không hỏi cloud.

**Đề xuất:** `isPinSetup()` khi prefs trống thì kiểm `admin_security/{uid}` trên
Firestore (và cache lại), giống hệt cách `verifyPin` đang làm.

---

## 5. 🟡 SA-04 — Không giới hạn số lần thử PIN (LOW-MEDIUM)

`verifyPin` không đếm lần sai, không khoá tạm, không giãn thời gian. Có ghi
`pin_verify_failed` vào nhật ký bất biến (tốt cho điều tra) nhưng **không chặn**.
Cộng với SA-02/SA-03 thì nên thêm khoá luỹ tiến sau N lần sai.

---

## 6. 🟡 SA-05 — `deleteShopSafe` không tự kiểm quyền (LOW, defense-in-depth)

`shop_deletion_service.dart:50` `deleteShopSafe()` — cửa vào của thao tác **xoá
sạch một shop** — **không** gọi `canDeleteShop()`. Quyền hiện chỉ do caller duy
nhất kiểm (`shop_switcher_widget.dart:682` gọi `canDeleteShop` rồi mới
`deleteShopSafe` ở dòng 706).

**Không khai thác được** vì rules chặn thật ở server:
`allow delete: if isAuth() && (isSuperAdmin() || resource.data.ownerUid == uid())`.
Nhưng chỉ cần thêm một caller mới bất cẩn là mất lớp bảo vệ client. Nên kiểm
ngay đầu `deleteShopSafe`.

---

## 7. 🟡 SA-06 — Màn từ chối console là ngõ cụt (LOW, UX)

`super_admin_console_view.dart:652`
```dart
return const Scaffold(
  body: Center(child: Text('Bạn không có quyền truy cập Super Admin Console.')),
);
```
Không AppBar, không nút quay lại — chỉ thoát được bằng phím Back của hệ thống
(đã gặp trên máy thật).

---

## 8. 📄 SA-07 — CLAUDE.md §1 mô tả SAI cơ chế super admin

CLAUDE.md đang ghi:
> **Super-admin email:** `admin@huluca.com` (hardcoded trong `UserService._isSuperAdmin`)
> **Cách kiểm tra:** `UserService.getUserRole(uid)` kiểm tra email đầu tiên, sau đó Firestore

Thực tế: `_isSuperAdmin()` **không đọc email**, chỉ so cache uid; `main.dart:697`
ghi rõ *"dựa trên custom claims, không dùng email hardcode"*. Sai lệch này nguy
hiểm vì AI agent/lập trình viên mới sẽ đi tìm một lớp dự phòng theo email **vốn
không còn tồn tại** — đúng cái lưới an toàn mà SA-01 đang cần.

**Đã sửa** trong đợt này.

---

## 9. HẠNG MỤC CHƯA CHẠY (BLOCKED bởi SA-01)

Chờ `users/{uid}.role = "super_admin"` rồi mới kiểm được:

1. Vào Super Admin Console, danh sách toàn bộ shop / user.
2. Chọn shop (`_adminSelectedShopId`) và kiểm tra dữ liệu đúng shop đó.
3. Cổng PIN: đặt PIN → thoát → vào lại phải hỏi PIN; sai PIN phải bị từ chối.
4. Idle guard + session timeout 30 phút.
5. Nhật ký `admin_audit_log` ghi đúng `logLogin` / `logShopAccess` / `logAction`.
6. Xoá shop: **chỉ kiểm quyền trên shop rác do chính mình tạo**, tuyệt đối không
   đụng shop có dữ liệu thật.
7. Đối chiếu: người thường (`m@m.com`) mở thẳng console phải bị từ chối.
