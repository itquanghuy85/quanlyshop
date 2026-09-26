# Attendance/Payroll — Real-Device Acceptance Script

**Status: READY FOR REAL-DEVICE ACCEPTANCE**

Mọi phần có thể kiểm chứng bằng code + unit test đã PASS (xem báo cáo nghiệm
thu cuối trong lịch sử chat / `docs/CHANGELOG.md` mục `2026-09-25`). Script
này liệt kê các bước cần chạy trên **thiết bị thật + Firebase project thật**
để đóng nốt các mục "PASS — REAL DEVICE PENDING". Không được đánh dấu PASS
cho bất kỳ dòng nào bên dưới nếu chưa thực sự chạy và quan sát kết quả.

Chuẩn bị:
- 2 thiết bị (Device A, Device B), cùng đăng nhập 1 tài khoản chủ shop hoặc
  2 tài khoản manager+ của cùng 1 shop.
- Build debug/profile mới nhất có commit chứa canonical engine
  (`AttendanceComputationService`, `AttendanceCheckService`).
- Một nhân viên test (ví dụ tài khoản `m@m.com` shop "M" — an toàn ghi thoải
  mái theo memory dự án; **không dùng shop thật `huy@huluca.com`**).
- Cài `adb` hoặc quyền truy cập Firestore console để đối chiếu.

---

## Kịch bản 1 — Checkout không mất field (F-01/F-02)

1. Device A: cho nhân viên test check-in trễ (sau 08:15 nếu lịch 08:00).
2. Manager (Device A hoặc B): mở "Quản lý chấm công" → sửa tăng ca (OT) cho
   bản ghi vừa tạo, ví dụ 60 phút → duyệt (approve) bản ghi.
3. Device A (chính nhân viên đó): bấm CHECK-OUT.
4. Kiểm tra ngay trên UI "Quản lý chấm công" (Device A hoặc B):
   - `isLate` vẫn hiển thị "Có" (trễ giờ).
   - OT vẫn hiển thị 60 phút.
   - Trạng thái vẫn "Đã duyệt" (không tụt về "Chờ duyệt").
   - Ghi chú / người duyệt vẫn còn.

**Expected:** tất cả field trên giữ nguyên sau checkout.
**SQLite kiểm tra (adb):**
```
adb shell run-as <package> cat databases/repair_shop_v22.db | sqlite3 - \
  "SELECT isLate, overtimeOn, status, approvedBy FROM attendance WHERE dateKey='<hôm nay>' AND userId='<uid>';"
```
Kỳ vọng: `isLate=1, overtimeOn=60, status='approved', approvedBy=<mgr uid>`.

---

## Kịch bản 2 — Payroll lock chặn sửa (item 8, đã có DB+logic test, chưa test UI thật)

*(Lưu ý: hiện KHÔNG có UI live nào gọi `setPayrollMonthLock` — PayrollView
là dead code. Kịch bản này yêu cầu gọi trực tiếp qua console/script debug
hoặc chờ tính năng khoá tháng được kích hoạt lại.)*

1. Gọi `DBHelper().setPayrollMonthLock('2026-09', locked: true, lockedBy: 'test')`
   (qua debug console hoặc script tạm) trên Device A.
2. Thử sửa giờ chấm công một bản ghi tháng 9/2026 → kỳ vọng: **thất bại**,
   dữ liệu không đổi.
3. Thử với bản ghi tháng 10/2026 → kỳ vọng: **thành công**.
4. Unlock lại tháng 9 trước khi kết thúc test (tránh khoá nhầm dữ liệu thật).

---

## Kịch bản 3 — Sync 2 chiều không mất field

**Device A:**
1. Check-in.
2. Manager sửa OT (editOvertime) = 90 phút.
3. Manager duyệt (approve).
4. Nhân viên check-out.

**Device B (cùng shop):**
5. Mở "Quản lý chấm công" → pull cloud (hoặc chờ sync tự động).
6. Kiểm tra: `checkInAt, checkOutAt, isLate, isEarlyLeave, overtimeOn,
   overtimeStartAt, overtimeEndAt, status, approvedBy, approvedAt,
   requestType, locked` — **tất cả phải khớp Device A**.

**Device B tiếp tục:**
7. Sửa lại `checkOutAt` (lùi 30 phút) qua "Quản lý chấm công".

**Device A:**
8. Pull cloud → `checkOutAt` mới phải xuất hiện, `isEarlyLeave` phải được
   recompute đúng theo giờ mới, các field khác (OT, approval) không đổi.

**Kiểm tra không trùng document:** đếm số document Firestore
`attendance` có `dateKey=<hôm nay>` và `userId=<uid>` — phải đúng **1**, dù
đã ghi từ cả 2 máy.

**Kiểm tra sync_queue / isSynced:** sau khi sync xong, `isSynced=1` trên cả
2 máy; không được thấy `isSynced=1` được set TRƯỚC khi Firestore write
thành công (audit code: `CloudWritePolicy.guard` — xác nhận qua code, nên
verify thực tế bằng cách tắt mạng giữa chừng bước 2, xem `isSynced` có bị
set sai không).

---

## Kịch bản 4 — Offline hoàn toàn

**Device A (airplane mode BẬT trước khi bắt đầu):**
1. Check-in → check-out (không cần chờ).
2. Mở màn "Tính lương" (nếu quyền truy cập cho phép offline) → tính lương
   tháng hiện tại cho nhân viên vừa chấm công.
3. Ghi lại: worked minutes / OT minutes / lương hiển thị.

**Reconnect (tắt airplane mode):**
4. Chờ sync tự động (hoặc bấm đồng bộ thủ công).
5. Mở lại "Tính lương" cho cùng nhân viên/tháng → tính lại.
6. So sánh với bước 3.

**Expected:** kết quả bước 5 == kết quả bước 3 (cùng schedule local, cùng
attendance local — không có gì thay đổi giữa 2 lần tính vì
`SalaryCalculationService` đã SQLite-first, không phụ thuộc kết nối mạng
cho phần attendance).

**Lưu ý đã biết (không phải lỗi cần sửa trong audit này):** phần cài đặt
lương mặc định của shop (`FirestoreService.getShopDefaultSalarySettings`)
và cài đặt khấu trừ/thuế (`getShopDeductionSettings`) vẫn đọc Firestore —
nếu nhân viên CHƯA có `employee_salary_settings` cục bộ riêng, tính lương
offline có thể dùng giá trị mặc định thay vì cấu hình thật của shop. Đây là
giới hạn đã biết, ghi trong `REMAINING RISKS` của báo cáo nghiệm thu.

---

## Kịch bản 5 — Ca qua đêm (F-07) trên thiết bị thật

1. Cấu hình lịch làm việc (staff hoặc shop_general): 22:00 → 06:00.
2. Check-in lúc ~22:05 (trong giờ hành chính buổi tối).
3. Đợi qua nửa đêm, check-out lúc ~06:10 sáng hôm sau (hoặc chỉnh giờ máy
   để mô phỏng — CHÚ Ý: chỉ dùng trên tài khoản test, không dùng shop thật,
   vì đổi giờ máy có thể ảnh hưởng dữ liệu khác).
4. Kiểm tra: `dateKey` của bản ghi vẫn là ngày check-in (không nhảy sang
   hôm sau), `isLate=0` (trong grace), `isEarlyLeave=0`, OT tự động ≈ 10
   phút (nếu standard/break cấu hình khớp ví dụ trong test).

---

## Kịch bản 6 — Excel/UI đồng nhất

1. Cho 1-2 nhân viên chấm công vài ngày với OT khác nhau (thủ công + tự
   động).
2. Mở "Quản lý chấm công" → ghi lại số "Giờ công • OT" hiển thị trên
   header.
3. Xuất Excel (tổng hợp tháng) → mở file, so sánh cột "Giờ công"/"Tăng ca"
   ở sheet tổng hợp với số ở bước 2.

**Expected:** khớp nhau (đã fix qua `AttendanceSummaryService` +
`AttendanceComputationService` dùng chung — xem
`test/attendance_excel_salary_consistency_test.dart`, nhưng đó là test với
dữ liệu giả lập trong bộ nhớ, KHÔNG phải Excel file thật xuất ra từ app —
bước này xác nhận bằng file thật).

---

## Kết quả

Điền vào từng dòng sau khi chạy thật (không điền trước):

| Kịch bản | Kết quả | Ghi chú |
|---|---|---|
| 1. Checkout preserve fields | ⬜ | |
| 2. Payroll lock block | ⬜ | |
| 3. Sync 2 chiều | ⬜ | |
| 4. Offline salary | ⬜ | |
| 5. Overnight | ⬜ | |
| 6. Excel/UI consistency | ⬜ | |

Chỉ được đóng dấu **PASS — REAL DEVICE PENDING → PASS** trong báo cáo nghiệm
thu sau khi tất cả 6 dòng trên có kết quả ⬜ → ✅ thực tế.
