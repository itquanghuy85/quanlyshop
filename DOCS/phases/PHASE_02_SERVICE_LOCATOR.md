# PHASE 02 — Service Locator
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 01 hoàn thành

---

## 1. Mục tiêu

Tạo DI container (Service Locator) và abstract interfaces cho các Firebase services, để online/offline flavor có thể swap implementations mà không thay đổi UI/view code.

---

## 2. Phạm vi công việc

- [ ] Tạo `lib/services/service_locator.dart`
- [ ] Tạo interfaces:
  - [ ] `lib/services/interfaces/i_auth_service.dart`
  - [ ] `lib/services/interfaces/i_firestore_service.dart`
  - [ ] `lib/services/interfaces/i_sync_service.dart`
  - [ ] `lib/services/interfaces/i_notification_service.dart`
- [ ] Refactor `UserService` implement `IAuthService`
- [ ] Refactor `FirestoreService` implement `IFirestoreService`
- [ ] Refactor `SyncService` implement `ISyncService`
- [ ] Refactor `NotificationService` implement `INotificationService`
- [ ] Update `main_online.dart` để register Online implementations
- [ ] Test: online app hoạt động y hệt như trước

---

## 3. Files đã sửa

*Chưa thực hiện*

---

## 4. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/services/service_locator.dart` | Singleton DI map |
| `lib/services/interfaces/i_auth_service.dart` | Auth contract |
| `lib/services/interfaces/i_firestore_service.dart` | Firestore contract |
| `lib/services/interfaces/i_sync_service.dart` | Sync contract |
| `lib/services/interfaces/i_notification_service.dart` | Notification contract |

---

## 5. Quyết định kiến trúc

- Xem ADR-002 trong `DECISIONS.md`
- Không break existing static method calls ngay — wrap dần
- Interfaces chỉ định nghĩa các method thực sự cần swap

---

## 6. Vấn đề dự kiến

- UserService dùng static methods khắp nơi → cần wrapper
- Circular dependencies có thể xuất hiện
- Views gọi service trực tiếp → không thay đổi call sites ngay

---

## 7. Cách xử lý dự kiến

- Tạo instance wrappers song song với static methods hiện có
- Dùng `ServiceLocator.get<IAuthService>()` chỉ ở main_*.dart và AuthGate
- Views tiếp tục dùng static methods (sẽ refactor sau nếu cần)

---

## 8. Kết quả test

*Chưa thực hiện*

---

## 9. Kết luận

*Chưa thực hiện*

---

## 10. Công việc tiếp theo

→ Phase 03: Offline Auth (song song với Phase 04, 05, 06)
