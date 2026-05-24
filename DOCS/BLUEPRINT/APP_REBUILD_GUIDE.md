# APP_REBUILD_GUIDE

## Mục tiêu rebuild
Rebuild lại app mới nhưng giữ nguyên DNA vận hành: tốc độ thao tác, độ chắc dữ liệu, trải nghiệm xanh-thương-hiệu, và hành vi offline-first.

## 1) Project structure đề xuất
1. core: app bootstrap, theme, localization, config.
2. data: sqlite schema, dao/repository local, migration.
3. services: domain services + sync/payment/permission.
4. presentation: views + reusable widgets + navigation.
5. integration: firebase/auth/firestore/storage/functions.

## 2) Setup order
1. Khởi tạo Flutter project + dependencies nền.
2. Thiết lập theme/token/l10n để khóa visual DNA sớm.
3. Dựng SQLite schema + model serialization.
4. Dựng services cốt lõi: user, firestore, sync, payment.
5. Dựng Home + 3 luồng chính: sửa chữa, bán hàng, kho.
6. Bổ sung tài chính, công nợ, nhân sự, quản trị.
7. Tối ưu sync/conflict, test offline thực địa.

## 3) Implementation order ưu tiên
- P0: auth + shop context + home + repair flow + sale flow + inventory flow.
- P1: debt/expense/cash closing + payment intent.
- P2: supplier/customer CRM + reporting.
- P3: expansion modules (branch/crm/food/fashion/vat).

## 4) Critical modules không được sai
- DB schema + migration tương thích dữ liệu cũ.
- SyncOrchestrator + conflict rule local-unsynced ưu tiên.
- PaymentIntent pipeline và financial activity consistency.
- Role/permission theo shopId + super-admin.

## 5) UI recreation priorities
1. AppBar gradient xanh + card trắng viền mảnh.
2. Form tốc độ cao, spacing gọn, cảnh báo màu rõ.
3. Navigation nhấn một chạm từ Home tới tác vụ chính.
4. Snackbar/dialog tiếng Việt, thông báo ngắn và rõ hành động.

## 6) Business logic priorities
1. Repair lifecycle 4 trạng thái + linh kiện + chi phí đối tác.
2. Sale với đa payment method (cash/transfer/debt/installment).
3. Inventory nhập nhanh + IMEI + vị trí lưu kho + ảnh.
4. Debt ledger chính xác với debt_payments và closing.
