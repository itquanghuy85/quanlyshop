# PHASE 05 — Disable Online Features
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 02 hoàn thành

---

## 1. Mục tiêu

Guard tất cả tính năng chỉ-online bằng `FlavorConfig.hasXxx` để offline app không crash và không hiển thị UI không cần thiết.

---

## 2. Phạm vi công việc

### FCM / Push Notifications
- [ ] Wrap `NotificationService.init()` trong `FlavorConfig.hasFCM`
- [ ] `NoOpNotificationService` — implement `INotificationService`, tất cả no-op
- [ ] Ẩn notification settings UI trong offline

### KiotViet Integration
- [ ] Guard tất cả KiotViet API calls với `FlavorConfig.hasKiotViet`
- [ ] Ẩn KiotViet sync button/menu trong offline flavor
- [ ] `KiotVietService` không được instantiate trong offline

### Cloud Functions
- [ ] Guard `functions.httpsCallable(...)` calls
- [ ] Fallback hoặc disable tính năng phụ thuộc Cloud Functions

### Payment Intent Service
- [ ] Guard `PaymentIntentService` với `FlavorConfig.hasPayments`
- [ ] Ẩn payment UI không cần thiết trong offline

### Multi-tenant / ShopId
- [ ] `UserService.getCurrentShopId()` trong offline → `'offline_shop'`
- [ ] Không filter theo shopId trong offline (single-tenant)

---

## 3. Files cần kiểm tra

| File | Online-only feature |
|------|---------------------|
| `lib/services/notification_service.dart` | FCM |
| `lib/services/kiotviet_service.dart` | KiotViet API |
| `lib/services/payment_intent_service.dart` | Payments |
| `lib/services/connectivity_service.dart` | Network check |
| `lib/main.dart` | Firebase.initializeApp |
| `lib/views/settings_view.dart` | Sync settings UI |

---

## 4. Files đã sửa

*Chưa thực hiện*

---

## 5. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/services/offline/noop_notification_service.dart` | No-op notifications |

---

## 6. Quyết định kiến trúc

- UI elements chỉ-online: ẩn bằng `if (FlavorConfig.isOnline)` widget guard
- Không xóa code — guard bằng conditional, dễ enable lại
- `ConnectivityService` vẫn giữ nhưng no-op trong offline (luôn trả về "offline")

---

## 7. Vấn đề dự kiến

- Có thể có nhiều chỗ gọi Cloud Functions không được document rõ
- Một số tính năng mix online/offline logic

---

## 8. Kết quả test

*Chưa thực hiện*

---

## 9. Kết luận

*Chưa thực hiện*

---

## 10. Công việc tiếp theo

→ Phase 06: Local Storage
