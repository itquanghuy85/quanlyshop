# RISKS AND ISSUES
**Cập nhật:** 2026-05-21

---

## Rủi ro đã xác định

| ID | Rủi ro | Xác suất | Tác động | Mức độ | Biện pháp giảm thiểu | Trạng thái |
|----|--------|----------|----------|--------|----------------------|------------|
| R-01 | Online regression sau refactor Service Locator | Cao | Cao | 🔴 Cao | Regression test toàn bộ trước Phase 2 | Open |
| R-02 | Firebase import lọt vào offline build | Trung bình | Cao | 🔴 Cao | `flutter analyze` + manual check imports | Open |
| R-03 | SQLite migration conflict giữa 2 flavor | Thấp | Cao | 🟡 Trung bình | Shared DBHelper, single migration path | Open |
| R-04 | APK offline vẫn lớn do tree-shaking không đủ | Trung bình | Thấp | 🟢 Thấp | So sánh APK size sau Phase 8 | Open |
| R-05 | iOS flavor setup phức tạp hơn Android | Cao | Trung bình | 🟡 Trung bình | Xử lý iOS schemes trong Phase 1 | Open |
| R-06 | StubFirestoreService thiếu edge cases | Trung bình | Trung bình | 🟡 Trung bình | Comprehensive stub với error handling | Open |
| R-07 | Offline auth quá đơn giản, dễ bypass | Thấp | Trung bình | 🟡 Trung bình | Hash + salt password, PIN lockout | Open |
| R-08 | KiotViet code path crash trong offline | Trung bình | Thấp | 🟢 Thấp | Guard tất cả KiotViet calls với FlavorConfig | Open |

---

## Issues đang mở (từ dự án gốc)

| ID | Issue | File | Ưu tiên | Ghi chú |
|----|-------|------|---------|---------|
| I-01 | Kho location chưa đồng bộ đầy đủ | salvage_phone_view.dart | Trung bình | Đã implement, chờ test |
| I-02 | `withOpacity` deprecated | nhiều file UI | Thấp | Cần migrate sang `.withValues()` |

---

## Issues đã đóng

| ID | Issue | Ngày đóng | Giải pháp |
|----|-------|-----------|-----------|
| C-01 | EK partner debt 300k không hiện trong payableTotal | 2026-05-21 | Thêm REPAIR_PARTNER vào 3 checkpoints trong finance_v2 |
| C-02 | Thu khác bị thổi phồng bởi thu nợ KH | 2026-05-21 | Tách debtCollectIn, incomeOther = extraIn - debtCollectIn |
| C-03 | N+1 query trong exportImportOrders | 2026-05-21 | getAllImportOrderItemsForOrders() bulk query |
| C-04 | 14 duplicate DB reads trong _exportDetailedReport | 2026-05-21 | Fetch once, pass pre-loaded data |

---

## Quy trình xử lý rủi ro

1. Phát hiện → Ghi vào bảng Rủi ro với ID mới
2. Phân loại xác suất/tác động
3. Ghi biện pháp giảm thiểu
4. Theo dõi đến khi đóng
5. Khi đóng → chuyển sang Issues đã đóng

---

## Lịch sử cập nhật

| Ngày | Hành động |
|------|-----------|
| 2026-05-21 | Khởi tạo, thêm R-01 đến R-08, I-01 đến I-02 |
