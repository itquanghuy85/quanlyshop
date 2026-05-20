# TEST RESULTS
**Cập nhật:** 2026-05-21

---

## Baseline (trước flavor split)

### flutter analyze
```
Ngày: 2026-05-21
Kết quả: ✅ 0 errors
Warnings: ~10 (unused imports, deprecated withOpacity — pre-existing)
```

### flutter build apk --release
```
Ngày: Chưa chạy baseline
Kết quả: —
APK Size: —
```

### flutter test
```
Ngày: Chưa chạy
Kết quả: —
```

---

## Phase 1 — Flavors Setup

*Chưa thực hiện*

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| flutter analyze | — | |
| flutter build apk --flavor online | — | |
| flutter build apk --flavor offline | — | |
| Online app chạy được | — | |
| Offline app chạy được | — | |

---

## Phase 2 — Service Locator

*Chưa thực hiện*

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| flutter analyze | — | |
| Online: tất cả tính năng hiện tại hoạt động | — | Regression test |
| Offline: app khởi động không crash | — | |

---

## Phase 3 — Offline Auth

*Chưa thực hiện*

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| Login bằng PIN | — | |
| Wrong PIN bị từ chối | — | |
| Session persist sau restart | — | |

---

## Phase 4 — Firestore Offline

*Chưa thực hiện*

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| Thêm đơn sửa (offline) | — | |
| Xem danh sách đơn (offline) | — | |
| Báo cáo tài chính (offline) | — | |

---

## Phase 5 — Disable Online Features

*Chưa thực hiện*

| Test | Kết quả | Ghi chú |
|------|---------|---------|
| KiotViet UI ẩn trong offline | — | |
| FCM không khởi tạo trong offline | — | |
| Cloud Functions không gọi trong offline | — | |

---

## Phase 6–7 — Storage + Settings

*Chưa thực hiện*

---

## Phase 8 — Final QA

*Chưa thực hiện*

| Test | Online | Offline | Ghi chú |
|------|--------|---------|---------|
| flutter analyze | — | — | |
| flutter build apk --release | — | — | |
| APK size so sánh | — | — | |
| flutter build ios --release | — | — | |
| Regression: đơn sửa | — | — | |
| Regression: bán hàng | — | — | |
| Regression: kho hàng | — | — | |
| Regression: tài chính | — | — | |
| Regression: nhập hàng | — | — | |
| Regression: khách hàng | — | — | |

---

## Template ghi kết quả test

```markdown
### [Phase X] — [Tên test]
Ngày: YYYY-MM-DD
Người thực hiện: —
Kết quả: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL

Chi tiết:
- [test case 1]: PASS/FAIL
- [test case 2]: PASS/FAIL

Lỗi phát hiện:
- [mô tả lỗi nếu có]

Hành động:
- [fix hoặc ghi issue]
```
