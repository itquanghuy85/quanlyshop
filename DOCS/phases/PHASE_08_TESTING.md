# PHASE 08 — Testing & QA
**Cập nhật:** 2026-05-21  
**Trạng thái:** 🔴 Not Started  
**Phụ thuộc:** Phase 07 hoàn thành

---

## 1. Mục tiêu

Kiểm thử toàn diện cả 2 flavor, đảm bảo Online không bị regression, Offline hoạt động đúng tất cả tính năng core.

---

## 2. Phạm vi công việc

### Build Verification
- [ ] `flutter analyze` — 0 errors cho cả 2 flavor
- [ ] `flutter build apk --flavor online --release`
- [ ] `flutter build apk --flavor offline --release`
- [ ] So sánh APK size: offline phải nhỏ hơn online
- [ ] `flutter build ios --flavor online --release` (nếu có Mac)

### Online Regression Test
- [ ] Đăng nhập / đăng xuất
- [ ] Tạo đơn sửa chữa
- [ ] Bán hàng
- [ ] Nhập kho
- [ ] Xuất báo cáo Excel
- [ ] Tài chính V2
- [ ] Đồng bộ Firestore
- [ ] KiotViet sync
- [ ] Thông báo FCM

### Offline Feature Test
- [ ] Setup tài khoản lần đầu
- [ ] Đăng nhập offline
- [ ] Tạo đơn sửa chữa (offline)
- [ ] Bán hàng (offline)
- [ ] Xem kho (offline)
- [ ] Báo cáo tài chính (offline)
- [ ] Xuất Excel (offline)
- [ ] Không có Firebase calls (verify với network interceptor)
- [ ] Hoạt động hoàn toàn khi tắt internet

### Performance
- [ ] Startup time online vs offline
- [ ] APK size online vs offline
- [ ] Memory usage

---

## 3. Checklist trước khi release

- [ ] `flutter analyze` 0 errors
- [ ] Tất cả regression tests pass
- [ ] APK offline: không có Firebase trong manifest
- [ ] Không có `google-services.json` required trong offline build
- [ ] Version code và version name đúng cho cả 2 flavor
- [ ] CHANGELOG.md cập nhật
- [ ] HANDOVER.md cập nhật
- [ ] PROGRESS_TRACKER.md: 100%

---

## 4. Files đã sửa

*Chưa thực hiện*

---

## 5. Kết quả test

Xem chi tiết tại `TEST_RESULTS.md` — Phase 8 section.

---

## 6. Quyết định kiến trúc

*Ghi lại nếu phát hiện vấn đề trong testing cần điều chỉnh architecture*

---

## 7. Vấn đề gặp phải

*Ghi trong quá trình test*

---

## 8. Kết luận

*Sau khi hoàn thành*

---

## 9. Công việc tiếp theo

→ Release v2.0 (online + offline)  
→ Cập nhật HANDOVER.md final  
→ Tag git release
