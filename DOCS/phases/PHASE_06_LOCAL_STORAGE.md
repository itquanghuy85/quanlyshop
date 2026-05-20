# PHASE 06 — Local Storage
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 02 hoàn thành

---

## 1. Mục tiêu

Thay thế Firebase Storage bằng local filesystem trong offline flavor: ảnh sản phẩm, avatar, hóa đơn lưu vào thư mục app local.

---

## 2. Phạm vi công việc

- [ ] Tạo `lib/services/offline/local_storage_service.dart`
  - [ ] `uploadImage(File file, String path)` → lưu vào `getApplicationDocumentsDirectory()`
  - [ ] `getImageUrl(String path)` → trả về file:// URL
  - [ ] `deleteImage(String path)` → xóa file local
- [ ] Tạo abstract `IStorageService` interface
- [ ] Wrap Firebase Storage calls hiện tại implement `IStorageService`
- [ ] Guard tất cả Firebase Storage calls với `FlavorConfig.hasFirebase`
- [ ] Update image display widgets để handle cả http:// và file:// URLs

---

## 3. Files cần kiểm tra

| File | Firebase Storage calls |
|------|------------------------|
| `lib/services/firestore_service.dart` | `FirebaseStorage.instance.ref(...)` |
| `lib/views/inventory_view.dart` | Image upload |
| `lib/views/create_repair_order_view.dart` | Image upload |
| `lib/widgets/image_picker_widget.dart` | Storage access |

---

## 4. Files đã sửa

*Chưa thực hiện*

---

## 5. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/services/interfaces/i_storage_service.dart` | Storage contract |
| `lib/services/offline/local_storage_service.dart` | Local file storage |

---

## 6. Quyết định kiến trúc

- Local images lưu tại: `{appDocDir}/huluca_images/{shopId}/{type}/{filename}`
- `getImageUrl()` trong offline trả về `file:///` path
- `Image.network()` trong widgets cần handle cả `file://` prefix
- Dùng `Image.file()` nếu path bắt đầu bằng `file://`

---

## 7. Vấn đề dự kiến

- `CachedNetworkImage` không hỗ trợ file:// paths
- Cần wrapper widget để phân biệt online/offline image source

---

## 8. Cách xử lý dự kiến

- Tạo `AppImage` widget: `if (url.startsWith('file://')) Image.file() else CachedNetworkImage()`

---

## 9. Kết quả test

*Chưa thực hiện*

---

## 10. Kết luận

*Chưa thực hiện*

---

## 11. Công việc tiếp theo

→ Phase 07: Offline Settings
