# PHASE 03 — Offline Auth
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 02 hoàn thành

---

## 1. Mục tiêu

Tạo hệ thống authentication cho offline flavor: không dùng Firebase Auth, dùng PIN hoặc password lưu trong SQLite.

---

## 2. Phạm vi công việc

- [ ] Tạo `local_users` table trong SQLite (nếu chưa có)
- [ ] Tạo `lib/services/offline/local_auth_service.dart`
  - [ ] `setup(username, password)` — lần đầu setup
  - [ ] `login(username, password)` → returns AppUser?
  - [ ] `logout()`
  - [ ] `getCurrentUser()` → AppUser?
  - [ ] `isSetup` → bool
- [ ] Tạo UI: `lib/views/offline_setup_view.dart` — màn hình setup lần đầu
- [ ] Tạo UI: `lib/views/offline_login_view.dart` — màn hình đăng nhập
- [ ] Cập nhật `AuthGate` để handle offline flavor
- [ ] Register `LocalAuthService` trong `main_offline.dart`

---

## 3. Files đã sửa

*Chưa thực hiện*

---

## 4. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/services/offline/local_auth_service.dart` | PIN/password auth |
| `lib/views/offline_setup_view.dart` | Setup account lần đầu |
| `lib/views/offline_login_view.dart` | Login màn hình |

---

## 5. Quyết định kiến trúc

- Xem ADR-005 trong `DECISIONS.md`
- Password hash: SHA-256 + salt (không bcrypt để tránh dependency)
- `AppUser` model dùng chung với online flavor
- Role mặc định: `admin` cho offline (1 user, toàn quyền)

---

## 6. Vấn đề dự kiến

- AuthGate hiện tại hardcode Firebase Auth stream
- `UserService.getCurrentShopId()` cần trả về local shopId trong offline mode

---

## 7. Cách xử lý dự kiến

- AuthGate check `FlavorConfig.isOffline` → dùng `LocalAuthService` thay vì Firebase stream
- `getCurrentShopId()` trong offline trả về fixed value `'offline_shop'`

---

## 8. Kết quả test

*Chưa thực hiện*

---

## 9. Kết luận

*Chưa thực hiện*

---

## 10. Công việc tiếp theo

→ Phase 04, 05, 06 (có thể chạy song song)
