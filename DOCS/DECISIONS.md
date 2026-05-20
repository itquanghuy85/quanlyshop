# DECISIONS — Quyết định kiến trúc
**Cập nhật:** 2026-05-21

---

## Quy tắc ghi chép

Mỗi quyết định phải bao gồm:
- **Ngữ cảnh**: Tại sao phải ra quyết định?
- **Quyết định**: Chọn giải pháp gì?
- **Lý do**: Tại sao chọn giải pháp này?
- **Alternatives bị loại bỏ**: Đã xem xét gì khác?
- **Hậu quả**: Trade-offs?

---

## ADR-001: Dùng Flutter Flavors thay vì Build Configs riêng biệt

**Ngày:** 2026-05-21  
**Trạng thái:** Đề xuất  

**Ngữ cảnh:**  
Cần tách app thành 2 phiên bản: Online (Firebase) và Offline (SQLite-only).

**Quyết định:**  
Dùng Flutter official flavor system với `--flavor online` và `--flavor offline`.

**Lý do:**  
- Flutter flavor là chuẩn chính thức, được CI/CD hỗ trợ
- Dễ tạo các entry points riêng biệt (`main_online.dart`, `main_offline.dart`)
- Play Store / App Store hỗ trợ multiple variants từ cùng codebase
- Có thể có app icon, tên app, màu sắc riêng cho mỗi flavor

**Alternatives loại bỏ:**  
- `--dart-define=FLAVOR=offline`: đơn giản hơn nhưng không có IDE support tốt
- 2 repo riêng biệt: quản lý code chia đôi, khó maintain
- Runtime flag: không cho phép tree-shaking Firebase

**Hậu quả:**  
- Cần cấu hình `android/app/build.gradle` và iOS schemes
- CI pipeline cần build 2 variants

---

## ADR-002: Service Locator thay vì Provider/Riverpod cho DI

**Ngày:** 2026-05-21  
**Trạng thái:** Đề xuất  

**Ngữ cảnh:**  
Cần swap implementations (Firebase vs Stub) dựa theo flavor.

**Quyết định:**  
Dùng simple Service Locator (singleton map) thay vì `get_it` hay Riverpod.

**Lý do:**  
- Codebase hiện tại dùng static methods, không có DI
- Service Locator đơn giản hơn, zero new dependencies
- Đủ cho use case này (swap at startup, không swap at runtime)
- Không phá vỡ existing code — có thể thêm dần

**Alternatives loại bỏ:**  
- `get_it`: thêm dependency, overkill cho 4-5 services
- Riverpod: refactor lớn toàn bộ UI layer
- Constructor injection khắp nơi: quá nhiều thay đổi

**Hậu quả:**  
- Không type-safe hoàn toàn (cần cast)
- Khó test unit nếu không có mocks — chấp nhận được với SQLite isolation

---

## ADR-003: Shared SQLite Schema cho cả 2 flavor

**Ngày:** 2026-05-21  
**Trạng thái:** Đề xuất  

**Ngữ cảnh:**  
Offline flavor cần lưu dữ liệu local. Online flavor đã có SQLite làm offline cache.

**Quyết định:**  
Dùng cùng `DBHelper` và schema cho cả 2 flavor.

**Lý do:**  
- Giảm maintenance — 1 schema thay vì 2
- Cho phép migrate từ offline → online dễ dàng
- Không cần duplicate model classes

**Alternatives loại bỏ:**  
- Schema riêng cho offline: phức tạp, 2 migration paths
- Hive/Isar cho offline: thêm dependency, cần migrate data

**Hậu quả:**  
- Offline app có các columns không dùng (shopId, firestoreId, isSynced)
- Chấp nhận được — disk space không đáng kể

---

## ADR-004: Firebase không được khởi tạo trong Offline flavor

**Ngày:** 2026-05-21  
**Trạng thái:** Đề xuất  

**Ngữ cảnh:**  
Offline APK không cần Firebase. Nếu init Firebase sẽ làm tăng APK size và có thể crash khi offline không có google-services.json hợp lệ.

**Quyết định:**  
`main_offline.dart` không gọi `Firebase.initializeApp()`. Tất cả Firebase imports được guard bằng `FlavorConfig.hasFirebase`.

**Lý do:**  
- APK nhỏ hơn (tree-shaking loại Firebase)
- Không cần `google-services.json` cho offline APK
- Không có crash risk khi không có network

**Alternatives loại bỏ:**  
- Init Firebase nhưng không dùng: APK to hơn, vẫn cần google-services.json
- Separate platform project: quá phức tạp

**Hậu quả:**  
- Cần kiểm tra từng import Firebase để đảm bảo không bị gọi trong offline mode
- Cần conditional imports hoặc stub classes

---

## ADR-005: Offline Auth dùng PIN/Password lưu trong SQLite

**Ngày:** 2026-05-21  
**Trạng thái:** Đề xuất  

**Ngữ cảnh:**  
Offline flavor cần auth nhưng không có Firebase Auth.

**Quyết định:**  
Lưu hashed password (bcrypt hoặc SHA-256) vào SQLite table `local_users`. Login check local.

**Lý do:**  
- Không cần internet
- Đơn giản, không dependency mới
- Đủ secure cho môi trường cửa hàng nội bộ

**Alternatives loại bỏ:**  
- Không có auth: rủi ro bảo mật
- Biometric auth: phức tạp, không phổ biến trên thiết bị thấp cấp
- Third-party offline auth: overkill

**Hậu quả:**  
- Không sync users giữa các thiết bị (offline by design)
- Cần UI đặt password lần đầu setup

---

## Lịch sử

| Ngày | ADR | Hành động |
|------|-----|-----------|
| 2026-05-21 | ADR-001 đến ADR-005 | Khởi tạo decisions cho flavor split |
