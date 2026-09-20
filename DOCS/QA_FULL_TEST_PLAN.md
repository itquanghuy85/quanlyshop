# QA_FULL_TEST_PLAN
Bản kế hoạch đầy đủ: `docs/FULL_TEST_PLAN_2026-09-19.md` (Feature Map, DB/Firestore/Sync/Permission map, ~185 test case).
Kết quả đợt 1 (audit, không sửa): `docs/FULL_TEST_REPORT_2026-09-19.md`.
Chính sách & root cause: `docs/QA_OFFLINE_SYNC_AUDIT.md`. Thực thi sau sửa: `docs/QA_TEST_EXECUTION.md`. Bug: `docs/QA_BUG_REPORT.md`. Tài chính: `docs/QA_FINANCE_RECONCILIATION.md`.

## Tổng kết đến 2026-09-20
- Test case trong plan: ~185 · đã chạy có bằng chứng: 58 (đợt 1) + 16 regression (đợt 2) + 719 unit + 17 rules.
- PASS: 45 + 12 + 719 + 17 · FAIL còn mở: 0 nghiêm trọng (BUG-10 LOW, L-02…L-06 LOW) · BLOCKED: 4 regression + ~127 case chưa chạy (xem FULL_TEST_REPORT §5).
- Thứ tự tiếp theo: chạy nốt nhóm Sửa chữa (REP-13…24), Bán hàng (SALE-05/06/07/16/17/23), Kho (INV-06/07/08/13/15), Nợ (DEBT-05/06/08), 2 máy (MD-04…10), Crash (CR-01…07), Stress.
