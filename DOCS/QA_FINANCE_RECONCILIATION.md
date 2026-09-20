# QA_FINANCE_RECONCILIATION — Đối chiếu tài chính sau sửa (2026-09-20, shop M, máy A)

## 1. Chuỗi giao dịch ngày 20/09 (giờ máy)
| Giờ | Nghiệp vụ | Tiền | Bảng ghi |
|---|---|---|---|
| 01:23 | Bán CAPLIGHTNING x1 TIỀN MẶT | +120.000 | sales, products(20→19), payment_intents |
| 01:26 | Thu nợ TÉTCARDQC | +100.000 | payment_intents, debt_payments, debts.paid 100k, financial_activity_log |
| 01:37 | Giao máy IPHONE 12 (đơn 69) TIỀN MẶT, vốn 1,5 Tr (MANHINH95) | +1.500.000 | repairs status 4, payment_intents, financial_activity_log, repair_parts 5→4 |
| 01:44 | Trả hàng CAPLIGHTNING hoàn TIỀN MẶT | −120.000 | sales_returns, products(19→20) |
| 08:39 | Bán CAPLIGHTNING x1 (mất mạng, local-first) | +120.000 | sales isSynced 0→1, products 20→19, payment_intents |
| 08:49 | Thu nợ TÉTCARDQC | +50.000 | payment_intents, debt_payments, debts.paid 150k |
| 08:54 | Nhập kho QA-CAP x5 30k (offline confirm) TIỀN MẶT | −150.000 | expenses CHI, import_orders, repair_parts +5 |

## 2. Đối chiếu độc lập
| Read model | Giá trị UI | Công thức / SQL | Khớp |
|---|---|---|---|
| Tab Tiền · Tiền vào (08:50, trước nhập kho) | 1,89 Tr | `SELECT SUM(amount) FROM payment_intents WHERE status='COMPLETED' AND createdAt≥20/09` = 1.890.000 | ✓ |
| Tab Tiền · Tiền ra | 120.000 | `sales_returns.totalReturnAmount` (refundMethod≠CÔNG NỢ) = 120.000 (BUG-09: gross) | ✓ |
| Tab Tiền · Còn lại | 1,77 Tr | 1.890.000 − 120.000 | ✓ |
| Chốt quỹ · Thu trong ngày | 1,89 Tr | = Tiền vào | ✓ (trước sửa: 1,72 vs 1,6) |
| Chốt quỹ · Tiền mặt | 1,77 Tr | = Còn lại | ✓ |
| Tab Lãi · Bán hàng (sau trả hàng 01:44) | 0 → 120.000 (sau 08:39) | doanh thu NET 120k+120k−120k | ✓ |
| Tab Lãi · Sửa chữa | 1,6 Tr | 1,5 Tr giao + 100k thu nợ (phương án A) | ✓ |
| Tab Lãi · Giá vốn | 1,583 Tr (01:4x) | 50k + 1,5 Tr + 33.333 pro-rata (100/450 × 150k) | ✓ theo quy tắc đã chốt |
| Tab Nợ · Phải thu | 17,46 Tr → 17,41 Tr | Σ(total−paid) debts CUSTOMER_OWES status ∈ {ACTIVE, UNPAID} | ✓ |
| Máy B (foreground) | paidAmount 150.000, dp=2 | = máy A | ✓ (RG-04) |

## 3. Trả hàng — kết luận
`sales_returns` là sổ hoàn tiền duy nhất (thiết kế, `sales_return_service.dart:181`). Không tạo `payment_intents`/`expenses` để tránh đếm 2 lần với 2 engine. Sửa ở `FinanceV2DataService`: tách dòng tiền (gross: `refundOut` vào Tiền ra) khỏi lãi (net: `saleRevenueNet`, `saleCogsNet`). Kịch bản `finance_full_scenario_test` cập nhật: totalIn 56.150.000, totalOut 17.500.000, ròng 38.650.000 không đổi; cross-check với Chốt quỹ (`a.totalIn − a.totalOut = snap.netCashflow + 50000`) vẫn PASS.

## 4. Firestore read/write impact trước → sau
| | Trước | Sau |
|---|---|---|
| Máy B foreground nhận thay đổi 28 bảng | không (chỉ resume: ~30 truy vấn) | 1 listener doc `meta/sync_signal` + 1 truy vấn con trỏ/bảng đổi (log `[SYNC][FETCH] … count=2 limit=20`) |
| Write thêm | 0 | 1 `set(merge)` `meta/sync_signal` mỗi lượt ghi cloud (gộp 1,5 s; batch rỗng không bump) |
| Mở app / resume | không đổi | không đổi |
| Bán hàng online | `refreshMyClaims` + transaction | không đổi (chỉ bỏ khi mất mạng) |
