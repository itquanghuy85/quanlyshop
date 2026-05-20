# PHASE 04 — Firestore Offline (Stub)
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 02 hoàn thành

---

## 1. Mục tiêu

Tạo `StubFirestoreService` cho offline flavor: implement `IFirestoreService` nhưng chỉ dùng SQLite, không có Firestore calls.

---

## 2. Phạm vi công việc

- [ ] Tạo `lib/services/offline/stub_firestore_service.dart`
  - [ ] Implement tất cả methods của `IFirestoreService`
  - [ ] Tất cả writes → SQLite only, `isSynced = false` (không bao giờ sync)
  - [ ] Tất cả reads → SQLite only
  - [ ] `shopId` = `'offline_shop'` (hardcoded)
- [ ] Tạo `lib/services/offline/noop_sync_service.dart`
  - [ ] `initRealTimeSync()` → no-op
  - [ ] `stopSync()` → no-op
- [ ] Register trong `main_offline.dart`
- [ ] Test: thêm/xem/sửa đơn sửa, bán hàng, kho trong offline mode

---

## 3. Files đã sửa

*Chưa thực hiện*

---

## 4. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/services/offline/stub_firestore_service.dart` | SQLite-only Firestore stub |
| `lib/services/offline/noop_sync_service.dart` | No-op sync |

---

## 5. Quyết định kiến trúc

- Stub không throw exceptions — trả về null/false/empty list
- `firestoreId` trong offline = generated UUID (để schema tương thích)
- Không có `deleted: true` propagation qua Firestore (local only)

---

## 6. Vấn đề dự kiến

- `FirestoreService` hiện tại rất lớn (~5000 lines) — interface cần cover tất cả
- Một số views gọi `FirestoreService.*` trực tiếp (vi phạm service-first rule)

---

## 7. Cách xử lý dự kiến

- Ưu tiên implement các methods được gọi nhiều nhất trước
- Views gọi trực tiếp: wrap vào `ServiceLocator.get<IFirestoreService>()`

---

## 8. Kết quả test

*Chưa thực hiện*

---

## 9. Kết luận

*Chưa thực hiện*

---

## 10. Công việc tiếp theo

→ Phase 07 (sau khi Phase 05 + 06 hoàn thành)
