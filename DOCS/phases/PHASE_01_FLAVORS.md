# PHASE 01 — Flavors Setup
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started

---

## 1. Mục tiêu

Thiết lập Flutter flavor system để app có thể build thành 2 variants độc lập:
- `online`: entry point `lib/main_online.dart`, đầy đủ Firebase
- `offline`: entry point `lib/main_offline.dart`, không Firebase

---

## 2. Phạm vi công việc

- [ ] Tạo `lib/flavors/app_flavor.dart` — enum AppFlavor
- [ ] Tạo `lib/flavors/flavor_config.dart` — static config + feature flags
- [ ] Tạo `lib/main_online.dart` — clone của main.dart hiện tại
- [ ] Tạo `lib/main_offline.dart` — không init Firebase
- [ ] Cấu hình `android/app/build.gradle` — flavorDimensions + productFlavors
- [ ] Tạo `android/app/src/online/` và `android/app/src/offline/` resources
- [ ] Cấu hình `pubspec.yaml` — flutter.flavors (nếu cần)
- [ ] Test build cả 2 flavor

---

## 3. Files đã sửa

*Chưa thực hiện*

| File | Loại | Thay đổi |
|------|------|---------|
| | | |

---

## 4. Files mới tạo

*Chưa thực hiện*

| File | Mục đích |
|------|---------|
| `lib/flavors/app_flavor.dart` | Enum AppFlavor {online, offline} |
| `lib/flavors/flavor_config.dart` | Feature flags dựa theo flavor |
| `lib/main_online.dart` | Entry point Online |
| `lib/main_offline.dart` | Entry point Offline |
| `android/app/src/online/res/values/strings.xml` | App name Online |
| `android/app/src/offline/res/values/strings.xml` | App name Offline |

---

## 5. Quyết định kiến trúc

- Xem ADR-001 trong `DECISIONS.md`
- `FlavorConfig.flavor` được set tại entry point trước khi `runApp()`
- Online flavor app name: "HULUCA Shop"
- Offline flavor app name: "HULUCA Offline"

---

## 6. Vấn đề dự kiến

- iOS scheme setup phức tạp hơn Android (Xcode schemes)
- `google-services.json` chỉ cần cho online flavor
- Có thể cần gradle sync sau khi thêm flavors

---

## 7. Cách xử lý dự kiến

- iOS: Tạo 2 schemes trong Xcode: `Runner-online` và `Runner-offline`
- `google-services.json`: Chỉ đặt trong `android/app/src/online/`
- Gradle sync: `flutter pub get` sau thay đổi build.gradle

---

## 8. Kết quả test

*Chưa thực hiện*

---

## 9. Kết luận

*Chưa thực hiện*

---

## 10. Công việc tiếp theo

→ Phase 02: Service Locator
