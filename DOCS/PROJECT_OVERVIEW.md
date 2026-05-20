# PROJECT OVERVIEW — HULUCA Shop Manager
**Cập nhật:** 2026-05-21  
**Version:** 1.x → 2.0 (Online + Offline flavors)

---

## 1. Giới thiệu

HULUCA Shop Manager là ứng dụng Flutter quản lý cửa hàng sửa chữa điện thoại.  
Hiện đang được tách thành **2 flavor** độc lập:

| Flavor | Mô tả |
|--------|-------|
| **online** | Đầy đủ tính năng, Firebase backend, multi-tenant |
| **offline** | Chỉ dùng SQLite nội bộ, không cần internet, dành cho cửa hàng độc lập |

---

## 2. Stack kỹ thuật

| Layer | Online | Offline |
|-------|--------|---------|
| UI | Flutter (Dart) | Flutter (Dart) |
| Auth | Firebase Auth | Local PIN/Password |
| Database | SQLite + Firestore | SQLite only |
| Sync | Real-time Firestore | Không |
| Storage | Firebase Storage | Local filesystem |
| Notifications | FCM + Local | Local only |
| Payments | PaymentIntentService | Disabled |
| KiotViet | Integrated | Disabled |

---

## 3. Cấu trúc thư mục dự án

```
lib/
├── main.dart                    # Entry point
├── flavors/
│   ├── flavor_config.dart       # Flavor constants (NEW)
│   └── app_flavor.dart          # Enum AppFlavor (NEW)
├── services/
│   ├── service_locator.dart     # DI container (NEW)
│   ├── firestore_service.dart
│   ├── user_service.dart
│   ├── sync_service.dart
│   └── ...
├── data/
│   └── db_helper.dart           # SQLite wrapper (shared)
├── models/                      # Data models (shared)
├── views/                       # Screens (shared, guarded by flavor)
└── widgets/                     # UI components (shared)
```

---

## 4. Nguyên tắc thiết kế flavor

- **Shared code**: Models, DB helper, UI widgets đều dùng chung
- **Gating**: Online-only features được guard bằng `FlavorConfig.isOnline`
- **Service Locator**: Thay thế trực tiếp Firebase calls bằng interface
- **Zero breaking change**: App online hiện tại phải hoạt động y hệt sau khi refactor

---

## 5. Build commands

```bash
# Online flavor
flutter run --flavor online -t lib/main_online.dart
flutter build apk --flavor online -t lib/main_online.dart --release

# Offline flavor
flutter run --flavor offline -t lib/main_offline.dart
flutter build apk --flavor offline -t lib/main_offline.dart --release
```

---

## 6. Tài liệu liên quan

| File | Nội dung |
|------|---------|
| `ARCHITECTURE.md` | Kiến trúc chi tiết |
| `ROADMAP_ONLINE_OFFLINE.md` | Lộ trình 8 phases |
| `PROGRESS_TRACKER.md` | Tiến độ hiện tại |
| `DECISIONS.md` | Quyết định kiến trúc |
| `HANDOVER.md` | Bàn giao / trạng thái |
| `docs/phases/` | Chi tiết từng phase |
