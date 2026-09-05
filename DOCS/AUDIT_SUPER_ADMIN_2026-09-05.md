# AUDIT SUPER ADMIN — 2026-09-05

**Phạm vi:** đường cấp quyền super admin (client + Cloud Functions + Firestore
rules), Super Admin Console, cổng PIN, nhật ký kiểm toán, xoá shop.
**Máy thật:** Oppo CPH2239 (`WCE65565HMDYOB59`), tài khoản `admin@huluca.com`
(uid `46H9mmb68BQFDz6o6QkNzpWk1I33`), project `huyaka-1809`.

**Kết luận:** ✅ **Hồi quy ĐÃ SỬA XONG và nghiệm thu trên máy thật** — đăng nhập
super admin nay vào thẳng Console như thiết kế. Còn **2 lỗi bảo mật cổng PIN
chưa sửa** (SA-02, SA-03) và 3 mục ghi nhận (SA-04/05/06/08).

Hồi quy do **3 lỗi chồng nhau**, đã sửa cả 3:
| Mã | Lỗi | Trạng thái |
|---|---|---|
| **SA-09** | `syncUserInfo` ghi `role:'admin'` xuống Firestore ⇒ Cloud Function thu hồi claims mỗi lần đăng nhập | ✅ đã sửa + nghiệm thu |
| **SA-10** | fast-path AuthGate trả `isSuperAdmin: false` **cứng** ⇒ từ lần mở app thứ 2 không bao giờ vào Console | ✅ đã sửa + nghiệm thu |
| **SA-08** | `_isSuperAdmin` của HomeView chỉ tính 1 lần lúc dựng State | ⚠️ ghi nhận, chưa sửa (SA-10 đã làm nhẹ hẳn triệu chứng) |

> **Cập nhật quan trọng:** SA-01 ban đầu được ghi nhận là "dữ liệu cấu hình sai".
> Sau khi sửa dữ liệu và quan sát trên máy thật thì phát hiện **dữ liệu bị chính
> app ghi đè trở lại** — nguyên nhân thật là SA-09. Sửa tay trên Firestore
> Console bao nhiêu lần cũng vô ích nếu chưa vá SA-09.

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

**⚠️ VÌ SAO doc lại có `role: "admin"` — xem SA-09.** Ban đầu tưởng là cấu hình
sai một lần; thực tế **chính app ghi đè nó mỗi lần đăng nhập**. Sửa tay trên
Firestore Console mà chưa vá SA-09 thì chỉ giữ được tới lần đăng nhập kế tiếp
(đã đo được: claims đúng lúc 15:30:58, hỏng lại lúc 15:37:20).

**Cách sửa đúng — 2 bước, phải đủ cả hai:**
1. **Code:** vá SA-09 (đã làm) để app thôi ghi đè.
2. **Dữ liệu:** đặt lại `users/46H9mmb68BQFDz6o6QkNzpWk1I33.role = "super_admin"`
   một lần. Trigger `syncUserClaims` (`onDocumentWritten("users/{userId}")`) tự
   cấp lại claims; từ đó app sẽ **giữ nguyên** giá trị này.

> ⚠️ **KHÔNG** sửa code kiểu "coi `role=='admin'` là super admin":
> `getCurrentUserPermissions` cấp **full quyền** cho `role=admin`, đó là vai trò
> app-level của chủ shop/quản lý ⇒ sẽ cấp nhầm quyền super admin hàng loạt.

**Trạng thái:** code đã vá + đã cài lên máy 2; chờ đặt lại `role` trên Firestore
Console lần cuối. Phần audit Console / cross-shop vì vậy vẫn là
**NOT RUN (BLOCKED)**.

---

## 2b. 🔴 SA-09 — APP TỰ THU HỒI QUYỀN SUPER ADMIN MỖI LẦN ĐĂNG NHẬP ✅ ĐÃ SỬA

**Đây là nguyên nhân gốc của SA-01.** Không phải ai đó lỡ ghi sai `role` — chính
`UserService.syncUserInfo()` ghi đè nó về `'admin'` sau mỗi lần đăng nhập.

**Mã lỗi** (`lib/services/user_service.dart:1161`, trước khi sửa):
```dart
final resolvedRole = isSuperAdmin
    ? 'admin'                                   // ← ghi thẳng xuống Firestore
    : (data['role'] ?? (shopId == uid ? 'owner' : 'user')) as String;

final userData = { ..., 'role': resolvedRole, ... };
await userRef.set(userData, SetOptions(merge: true));
```

**Vòng lặp tự huỷ:**
1. Admin đặt `users/{uid}.role = "super_admin"` → CF cấp claims
   `role: super_admin, isSuperAdmin: true`. ✅
2. Lần đăng nhập kế tiếp, app thấy `isSuperAdmin == true` ⇒ ghi **`role: 'admin'`**
   ngược xuống `users/{uid}`.
3. Trigger `syncUserClaims` chạy lại:
   `isSuperAdmin = ("admin" === "super_admin")` ⇒ **false** ⇒ claims bị hạ cấp.
4. Super admin mất quyền. Vĩnh viễn, ngay lần đăng nhập sau.

**Bằng chứng bắt được đúng chuỗi trên máy thật:**
```
15:30:58  🔑 Token claims: shopId=IXmcXpc13VMPocoE8oN8hq73uHz1, role=super_admin
          (ngay sau khi sửa tay trên Firestore Console)
15:37:20  🔑 Token claims: shopId=46H9mmb68BQFDz6o6QkNzpWk1I33, role=admin
          (sau vài lần đăng nhập — app đã ghi đè)
```

**Vì sao lập trình viên viết ra lỗi này:** `UserService.getUserRole()` **map**
claims `super_admin` → trả về `'admin'` làm tên vai trò *app-level*. Dòng 1161
dùng đúng cái tên app-level đó để **ghi xuống Firestore** — nơi Cloud Function
lại đòi đúng chuỗi `'super_admin'`. Hai tầng đặt tên khác nhau cho cùng một vai
trò, bị gộp làm một.

**Chủ shop xác nhận đây là HỒI QUY:** trước kia đăng nhập tài khoản super admin
là vào thẳng trang Super Admin rồi mới chọn shop — đúng như `main.dart:1091`
thiết kế.

**Đã sửa** — tách hẳn hai khái niệm, chỉ đổi giá trị ghi xuống Firestore:
```dart
final persistedRole = isSuperAdmin
    ? 'super_admin'                             // ghi Firestore — CF đọc chuỗi này
    : (data['role'] ?? (shopId == uid ? 'owner' : 'user')) as String;
final resolvedRole = isSuperAdmin ? 'admin' : persistedRole;  // tên app-level, giữ nguyên
...
'role': persistedRole,
```
`resolvedRole` vẫn là `'admin'` nên **không đụng** hai chỗ dùng còn lại
(`isNewShop && resolvedRole == 'owner'` và `saveAuthCache`), cũng như mọi nhánh
`role == 'admin'` sẵn có trong app.

---

## 2c. 🟡 SA-08 — `_isSuperAdmin` của HomeView chỉ tính MỘT LẦN (LOW-MEDIUM)

`lib/views/home_view.dart:591`
```dart
final bool _isSuperAdmin = UserService.isCurrentUserSuperAdmin();
```
Đây là **field initializer**, chỉ chạy đúng một lần lúc tạo State và **không bao
giờ tính lại**. Trong khi đó quyền super admin resolve **muộn** (đo được trên
máy: `syncAllToCloud`/`initRealTimeSync` báo `isSuperAdmin=false`, mãi tới
`runFullCheck` mới `true`). Nếu HomeView dựng trúng lúc chưa resolve thì
`_isSuperAdmin=false` bị **đóng băng cả phiên** ⇒ 3 mục chỉ dành cho super admin
("Trung tâm quản trị", "Kiểm tra kết nối", "Thống kê đọc/ghi") **biến mất suốt
phiên đó**, dù quyền đã đúng.

Đã quan sát trực tiếp: `runFullCheck ... isSuperAdmin=true` nhưng danh sách Cài
đặt vẫn **không có** mục "Trung tâm quản trị". Nên chuyển sang đọc động (hoặc
rebuild khi claims resolve xong).

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

## 9. NGHIỆM THU SUPER ADMIN CONSOLE (sau khi sửa SA-09 + SA-10)

Máy thật Oppo CPH2239, `admin@huluca.com`. **Toàn bộ chỉ ĐỌC** — dữ liệu là
production thật (147 shop, 159 user), không thao tác khoá/xoá bất kỳ shop nào.

| # | Hạng mục | Kết quả |
|---|---|---|
| 1 | Đăng nhập → vào **thẳng** Super Admin Console | ✅ ĐẠT (trước khi vá thì rơi vào Trang chủ, badge "NHÂN VIÊN") |
| 2 | Dashboard tổng quan | ✅ 147 tổng shop · 146 hoạt động · 159 tổng user · 1 shop bị khoá; có cảnh báo "1 shop đang bị khóa app" |
| 3 | Tab **Shops** | ✅ liệt kê kèm trạng thái ACTIVE/LOCKED, email chủ shop, shopId; lọc Tất cả / Hoạt động / Đã khoá / Đã xoá |
| 4 | Tab **Users** | ✅ liệt kê vai trò + shop + ngày tham gia; lọc Tất cả / Chủ shop / Nhân viên; có "Tìm tài khoản trùng email" |
| 5 | Tab **Logs** (`admin_audit_log`) | ✅ ghi thật: `super_admin_login` 05/09 15:47 & 15:09, `pin_verified` 19/08 08:46, 18/08 10:24 |
| 6 | Quyền không bị thu hồi qua nhiều phiên | ✅ 4 vòng khởi động (17:42→17:51), có lần `syncUserInfo` chạy, `isSuperAdmin` vẫn `true` |
| 7 | Cổng PIN | ⚠️ **KHÔNG hỏi PIN lần nào** — xem SA-03 bên dưới |

**Củng cố thêm cho SA-03:** màn *Cài đặt → Bảo mật PIN* báo **"Chưa thiết lập
PIN"**, trong khi nhật ký kiểm toán có `pin_verified` ngày 18–19/08. Trạng thái
PIN được đọc từ `isPinSetup()` — tức **chỉ từ SharedPreferences của máy này** —
nên trên máy có app data mới, app vừa *không hỏi PIN* vừa *báo là chưa từng đặt
PIN*. Nếu super admin bấm "Thiết lập" ở đây thì sẽ **ghi đè** hash trên Firestore.

> Chưa loại trừ được 100% khả năng "PIN đã bị gỡ sau 19/08" vì không đọc được
> Firestore từ môi trường này. Cách tái hiện dứt điểm (2 phút): đặt PIN trên máy
> A → xác nhận vào lại có hỏi PIN → cài app lên máy B (hoặc xoá dữ liệu app) →
> đăng nhập super admin → **sẽ không bị hỏi PIN**.

### Vẫn CHƯA CHẠY (cố ý)

* **Khoá / xoá shop:** không chạy trên production (147 shop thật). Chỉ nên kiểm
  trên shop rác tự tạo, hoặc trên project staging.
* **Idle guard + timeout 30 phút:** cần chờ thực 30 phút, chưa chạy.
* **Chọn shop (`_adminSelectedShopId`) rồi đối chiếu dữ liệu:** chưa chạy để
  tránh đổi ngữ cảnh shop của tài khoản admin production.
* **Đối chiếu người thường mở thẳng console:** cổng vào đã bị ẩn theo
  `_isSuperAdmin` và console tự xác minh lại bằng `forceRefresh` — đã đọc kỹ mã,
  nhưng chưa dựng lại được ca chạy sạch trên máy.


---

## 10. AUDIT BẢO MẬT MỞ RỘNG (ngoài phạm vi super admin)

### 🔴 AR-01 — Leo thang đặc quyền lên super admin ✅ ĐÃ VÁ + DEPLOY

`changed()` trong rules chỉ chặn SỬA, không chặn THÊM MỚI:
```
function changed(field) {
  return field in resource.data && ...   // doc CŨ chưa có field ⇒ false
}
```
Chuỗi: đăng ký → tạo `users/U` chỉ với `{email}` (rule create cho phép vì `role`
là tuỳ chọn ⇒ whitelist bị bỏ qua) → tự update thêm `role: "super_admin"`
(`!changed('role')` = true vì doc cũ không có `role`) → `syncUserClaims` cấp
claims `isSuperAdmin: true` → toàn quyền 147 shop. Cùng lỗ còn cho THÊM MỚI
`isAdmin` / `isSuperAdmin` / `balance` / `ownerUid`.

**Vá:** thêm `addedOrChanged()` (chặn cả thêm lẫn sửa) cho mọi field đặc quyền;
thêm `roleValueOK()` — client không bao giờ được ghi `role: 'super_admin'`.

### 🔴 AR-04 — Chiếm quyền TOÀN BỘ một shop bằng 1 lệnh ghi ✅ ĐÃ VÁ + DEPLOY

Nghiêm trọng hơn AR-01 vì **không cần mẹo gì**:
1. `myShopId()` đọc `users/{uid}.shopId` — chính document người dùng tự ghi được.
2. `myRole()` cũng đọc từ đó; người tự đăng ký mặc định là `owner`.
3. `isOwner()` = `myRole()=='owner'` — **không ràng buộc shop nào**.
4. `protectedOK()` cũ cho đổi `shopId` nếu `isOwner()` ⇒ đổi sang shopId bất kỳ.
5. Sau đó `docInMyShop()`, `isManager()`, `isEmployee()` đều true trên shop nạn
   nhân ⇒ toàn quyền đơn sửa, đơn bán, kho, khách hàng, công nợ, sổ tiền.

shopId nạn nhân lấy từ `invites` (đọc được bởi mọi user đăng nhập — AR-05).

**Vá:** `shopIdWriteOK()` chỉ chấp nhận 4 đường hợp lệ — (a) shop do chính người
thao tác sở hữu (`isShopOwner`), (b) đúng shopId trong custom claims đã ký (cho
nhân viên đăng nhập lại), (c) có mã mời hợp lệ chưa dùng đúng shop
(`hasValidInvite`), (d) super admin. Kèm sửa client: `useInviteCode` ghi thêm
`joinInviteCode` để rules xác minh được.

### 🟠 AR-05 — `invites` đọc được bởi mọi user đăng nhập ⚠️ CHƯA VÁ

`allow read: if isAuth()` không kèm ràng buộc nào ⇒ liệt kê được **toàn bộ mã
mời của mọi shop**, mỗi mã chứa `shopId` + `role`. Sau khi vá AR-04 thì không
còn dùng để chiếm shop được nữa (mã phải chưa dùng và rules kiểm đúng shop),
nhưng vẫn là rò rỉ thông tin + cho phép **dùng trộm mã mời của shop khác**.
Đề xuất: `allow read` chỉ cho `belongsTo(resource.data.shopId)`, còn việc đổi mã
khi đăng ký thì chuyển sang Cloud Function.

### 🟠 AR-06 — `users` đọc được toàn bộ, xuyên shop ✅ ĐÃ VÁ + DEPLOY

`match /users/{userId} { allow read: if isAuth(); }` — bất kỳ ai đăng nhập cũng
đọc/liệt kê được **toàn bộ 159 user của 147 shop**: email, tên, **số điện thoại,
địa chỉ**, vai trò, shopId, các cờ quyền. Chú thích trong rules ghi "for
collaboration features" nhưng không giới hạn theo shop.

**Vá:** `allow read: if isAuth() && (isSuperAdmin() || uid() == userId ||
resource.data.shopId == myShopId())`.

**Hai truy vấn client phải sửa kèm** (đã soát toàn bộ 20 chỗ truy vấn `users`;
các chỗ còn lại đều là `.doc(uid)` hoặc đã lọc `shopId`):
1. `advanced_chat_view` lấy avatar bằng `where(FieldPath.documentId, whereIn:)`
   — truy vấn collection không kèm `shopId` thì Firestore không chứng minh được
   là hợp lệ ⇒ bị từ chối cả mẻ. Đổi sang đọc **từng document** (được đánh giá
   theo từng doc nên vẫn chạy); mỗi mẻ tối đa 10 người, lại có cache.
2. `notification_service` dọn token FCM trùng bằng `where('fcmToken', ==)` không
   lọc shop. Đã thêm `where('shopId', ==, shopId)`.
   **GIỚI HẠN đã biết:** chỉ dọn được token trùng trong CÙNG shop; máy dùng chung
   giữa hai shop khác nhau thì token cũ còn ở doc của tài khoản shop kia. Muốn
   dọn triệt để phải làm ở Cloud Function (chạy quyền admin, không vướng rules).

Cả hai đều đã nằm trong `try/catch` từ trước nên bản app CŨ đang cài ngoài thị
trường chỉ **suy giảm nhẹ** (avatar chat về chữ cái đầu), không crash.

**Nghiệm thu máy thật:** máy 1 (`m@m.com`, chủ shop) mở *Quản lý nhân viên* →
liệt kê đúng 3 thành viên shop M (`n@n.com` Nhân viên, `websync3@huluca.vn` Chủ
shop, `m@m.com`); **không có `permission-denied`** trên cả 2 máy.

### 🟡 AR-03 — Mã hoá dữ liệu gần như không có tác dụng ⚠️ GHI NHẬN, KHÔNG SỬA

`encryption_service.dart` mã hoá AES-256 các trường nhạy cảm trước khi lên
Firestore (bật mặc định, dùng khắp `firestore_service`), nhưng:
1. **Khoá suy ra được từ APK** — `_masterSecret = 'HuLuCa_Shop_2024_Secure_Key_@!#'`
   hardcode, khoá = `sha256(shopId + masterSecret)`, mà `shopId` nằm plaintext
   trên mọi document ⇒ ai có APK cũng dựng lại được khoá của **mọi shop**.
2. **IV cố định theo shop** — `IV = md5('IV_' + shopId)`, không đổi. AES-CBC với
   IV cố định ⇒ cùng plaintext cho cùng ciphertext ⇒ kể cả không có khoá vẫn
   biết bản ghi nào trùng tên/trùng SĐT, dựng được thống kê tần suất.

**Quyết định:** ghi nhận, chưa sửa. Sửa IV (thêm định dạng `ENC3:` IV ngẫu nhiên)
đụng đường ghi của mọi bản ghi trên 147 shop production trong khi lợi ích hạn
chế — chừng nào khoá còn suy ra được từ APK thì vá IV chỉ chặn được người xem DB
mà không có APK. Muốn giải quyết tận gốc phải đổi kiến trúc khoá (server/KMS),
nên làm thành một đợt riêng có kế hoạch migration.

### 🟡 AR-07 — `chat_online` / `chat_typing` đọc chéo shop (LOW)

`allow read: if isAuth()` ⇒ thấy trạng thái online/đang gõ của người thuộc shop
khác. Độ nhạy thấp nhưng vẫn là rò rỉ xuyên tenant.

### ✅ Không phải lỗi

`app_config` `allow read: if true` — có chủ ý và đã ghi rõ lý do: phải đọc được
cấu hình "buộc cập nhật" trước khi biết user là ai; ghi thì chỉ super admin.
`broadcasts` / `other_apps` đọc bởi mọi user — thông báo hệ thống toàn cục.
