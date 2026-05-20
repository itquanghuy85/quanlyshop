# PHASE 07 — Offline Settings
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 06 hoàn thành

---

## 1. Mục tiêu

Đảm bảo toàn bộ cài đặt shop (tên shop, logo, users, roles, in ấn) hoạt động hoàn toàn offline, lưu vào SQLite.

---

## 2. Phạm vi công việc

### Shop Settings
- [ ] `LabelSettingsService` hoạt động từ SQLite trong offline
- [ ] Tên shop, địa chỉ, số điện thoại lưu local
- [ ] Logo shop lưu local filesystem (Phase 06)

### User Management (offline)
- [ ] Tạo/sửa/xóa users local trong `local_users` table
- [ ] Assign roles (admin/staff) local
- [ ] Không cần invite link, không cần email verification

### Printer Settings
- [ ] Bluetooth printer config lưu SharedPreferences (đã có, giữ nguyên)
- [ ] Thermal print hoạt động giống online (không phụ thuộc Firebase)

### Backup/Restore
- [ ] Export toàn bộ SQLite DB thành file
- [ ] Import/restore từ file backup

---

## 3. Files cần kiểm tra

| File | Vấn đề |
|------|--------|
| `lib/services/label_settings_service.dart` | Có dùng Firestore? |
| `lib/views/settings_view.dart` | UI settings nào phụ thuộc Firebase? |
| `lib/services/user_service.dart` | User management calls |

---

## 4. Files đã sửa

*Chưa thực hiện*

---

## 5. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/views/offline_user_management_view.dart` | Quản lý user offline |
| `lib/services/offline/local_settings_service.dart` | Settings local |

---

## 6. Quyết định kiến trúc

- `LabelSettingsService`: nếu dùng Firestore → add SQLite fallback
- Offline không có multi-tenant → shopId = `'offline_shop'`
- Backup format: SQLite file copy + optional JSON export

---

## 7. Vấn đề dự kiến

- `LabelSettingsService` có thể đã dùng `SharedPreferences` → ít ảnh hưởng
- User management UI hiện tại dùng Firebase Auth → cần offline alternative

---

## 8. Kết quả test

*Chưa thực hiện*

---

## 9. Kết luận

*Chưa thực hiện*

---

## 10. Công việc tiếp theo

→ Phase 08: Testing & QA
