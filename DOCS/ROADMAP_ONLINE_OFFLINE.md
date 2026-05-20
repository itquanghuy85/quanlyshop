# ROADMAP — Online / Offline Flavors
**Cập nhật:** 2026-05-21

---

## Tổng quan

Tách HULUCA Shop Manager thành 2 flavor: `online` (Firebase) và `offline` (SQLite-only).  
Mục tiêu: cùng codebase, khác entry point, khác service implementation.

---

## 8 Phases

| # | Phase | Mô tả | Ước lượng | Trạng thái |
|---|-------|-------|-----------|------------|
| 1 | **Flavors Setup** | Cấu hình Android/iOS flavor, entry points, constants | 1 ngày | 🔴 Not Started |
| 2 | **Service Locator** | Tạo DI container, abstract interface cho Firebase services | 2 ngày | 🔴 Not Started |
| 3 | **Offline Auth** | PIN/Password auth thay thế Firebase Auth trong offline flavor | 1 ngày | 🔴 Not Started |
| 4 | **Firestore Offline** | Stub FirestoreService cho offline, chỉ dùng SQLite | 2 ngày | 🔴 Not Started |
| 5 | **Disable Online Features** | Guard FCM, KiotViet, CloudFunctions, Payment bằng FlavorConfig | 1 ngày | 🔴 Not Started |
| 6 | **Local Storage** | Firebase Storage → local filesystem trong offline flavor | 1 ngày | 🔴 Not Started |
| 7 | **Offline Settings** | Cài đặt shop, users, roles lưu hoàn toàn local | 1 ngày | 🔴 Not Started |
| 8 | **Testing & QA** | Kiểm thử toàn bộ 2 flavor, phân tích APK size | 2 ngày | 🔴 Not Started |

**Tổng ước lượng:** 11 ngày

---

## Phụ thuộc giữa các phase

```
Phase 1 (Flavors)
    └── Phase 2 (Service Locator)
            ├── Phase 3 (Offline Auth)
            ├── Phase 4 (Firestore Offline)
            ├── Phase 5 (Disable Online Features)
            └── Phase 6 (Local Storage)
                    └── Phase 7 (Offline Settings)
                                └── Phase 8 (Testing)
```

---

## Tiêu chí hoàn thành toàn dự án

- [ ] `flutter build apk --flavor online` thành công, 0 error
- [ ] `flutter build apk --flavor offline` thành công, 0 error  
- [ ] Online flavor: toàn bộ tính năng hiện tại hoạt động đúng
- [ ] Offline flavor: quản lý đơn, kho, tài chính hoạt động không cần internet
- [ ] Offline APK nhỏ hơn Online APK (do không có Firebase)
- [ ] `flutter analyze` 0 error cho cả 2 flavor
- [ ] Regression test pass cho online flavor

---

## Rủi ro chính

| Rủi ro | Mức độ | Biện pháp |
|--------|--------|-----------|
| Online regression sau refactor | Cao | Unit test + manual regression |
| Firebase init crash trong offline | Cao | Conditional init trong main_offline.dart |
| SQLite schema không đồng bộ | Trung bình | Shared DBHelper, same schema version |
| Build size offline lớn hơn dự kiến | Thấp | Tree-shaking Firebase packages |
