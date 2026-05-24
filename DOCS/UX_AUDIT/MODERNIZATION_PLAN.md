# Modernization Plan

## Mục tiêu
Hiện đại hóa UX/UI mà không làm hỏng logic vận hành đã ổn định của app đang lên store. Kế hoạch này ưu tiên giảm nợ hệ thống trước khi tô bóng bề mặt.

## Nguyên tắc triển khai
- Không redesign đại trà trong một đợt.
- Không chạm sâu business rules nếu không cần.
- Tách refactor visual system khỏi refactor workflow để giảm rủi ro.
- Mọi redesign phải đo được bằng tốc độ thao tác và tỷ lệ lỗi giảm.

---

## Phase 0 — Audit to Action Spec
**Thời lượng:** 3-5 ngày

### Mục tiêu
Chuyển audit này thành bộ quy chuẩn thực thi.

### Deliverables
- AppBar standard
- Card taxonomy
- CTA hierarchy
- loading/sync/empty/error state spec
- settings IA map
- home IA map
- debt triage model

### Không làm ở phase này
- Không rewrite màn hình lớn.
- Không đổi logic nghiệp vụ.

---

## Phase 1 — System First Cleanup
**Thời lượng:** 1-2 tuần

### Mục tiêu
Khóa các pattern nền tảng để ngăn UX debt tiếp tục tăng.

### Công việc
1. Hợp nhất AppBar strategy.
2. Tạo bộ shared state widgets:
   - loading section
   - skeleton list
   - empty state
   - retry state
   - sync status banner/chip
3. Chuẩn hóa button hierarchy.
4. Chuẩn hóa dialog/bottom-sheet roles.

### KPI
- Giảm mạnh AppBar custom rời rạc.
- Màn hình mới không được phép thêm inline visual pattern mới.

---

## Phase 2 — Home + Settings Architecture
**Thời lượng:** 1-2 tuần

### Mục tiêu
Giải quyết 2 điểm làm app mất scale rõ nhất.

### Công việc
- Redesign `home_view.dart` theo role-based command center.
- Tạo settings landing page mới.
- Gom các settings screen vào nhóm logic rõ ràng.
- Thêm search/settings discovery.

### KPI
- Task phổ biến từ home đạt 1-2 chạm.
- Người dùng tìm đúng settings nhanh hơn rõ rệt.

---

## Phase 3 — Debt + Inventory Operational Redesign
**Thời lượng:** 2 tuần

### Mục tiêu
Tối ưu 2 khu vực đang nặng nhận thức nhất.

### Công việc
- `debt_view.dart`: redesign theo urgency-first triage.
- `inventory_view.dart`: tách browse vs operations vs utilities.
- Chuẩn hóa item action sheet.
- Giảm dialog chaining.

### KPI
- Thời gian tìm khoản nợ cần xử lý giảm.
- Thời gian thực hiện tác vụ kho phổ biến giảm.
- Số lần thao tác sai mode giảm.

---

## Phase 4 — Repair Flow Acceleration
**Thời lượng:** 2 tuần

### Mục tiêu
Tăng tốc create repair và làm repair detail bớt nặng đầu.

### Công việc
- Tách quick intake khỏi advanced enrichment.
- Thiết kế sticky footer CTA.
- Chuẩn hóa card/status/timeline trong repair detail.
- Làm rõ saved/pending/synced states.

### KPI
- Thời gian tạo đơn mới giảm.
- Sai sót nhập liệu ban đầu giảm.

---

## Phase 5 — Payment Trust Layer
**Thời lượng:** 1 tuần

### Mục tiêu
Làm các luồng liên quan tiền trở nên chắc chắn và dễ tin hơn.

### Công việc
- Payment confirmation sheet chuẩn.
- Result state chuẩn cho thu/chi/thanh toán.
- Chuẩn hóa wording cho financial success/failure/queued.

### KPI
- Giảm confusion sau thanh toán.
- Giảm số lần user hỏi “đã lưu chưa?”.

---

## Phase 6 — Visual Polish & Motion System
**Thời lượng:** 1 tuần

### Mục tiêu
Sau khi hệ thống và workflow ổn, mới tăng cảm giác hiện đại.

### Công việc
- Motion guidelines cho page transition, card entrance, async state change.
- Tinh chỉnh icon rhythm, spacing rhythm, empty states.
- Đồng bộ visual tone cho admin/settings/finance surfaces.

### KPI
- Cảm nhận consistency tăng.
- App bớt cảm giác “ghép module”.

---

## Ưu tiên theo ROI
1. AppBar/loading/sync system
2. Home IA
3. Settings IA
4. Debt redesign
5. Inventory redesign
6. Repair intake acceleration
7. Payment trust layer
8. Motion polish

## Những thứ không nên làm ngay
- Không redesign toàn bộ app theo kiểu cosmetic-only.
- Không đổi màu thương hiệu lớn nếu chưa giải quyết hierarchy.
- Không thêm animation tràn lan khi loading/error model còn yếu.
- Không cố unify bằng cách copy/paste screen templates mới lên màn hình cũ.

## Rủi ro nếu không làm
- Mỗi module mới sẽ tăng entropy UX.
- Thời gian đào tạo nhân viên mới tăng.
- Sai sót thao tác tăng ở giờ cao điểm.
- App ngày càng mạnh tính năng nhưng ngày càng nặng cảm giác sử dụng.

## Kết luận
Lộ trình đúng không phải là “làm đẹp app”. Lộ trình đúng là: chuẩn hóa hệ thống, giảm quyết định, làm rõ trạng thái, rồi mới polish. Nếu làm theo thứ tự này, app có thể tăng chất lượng UX rõ rệt mà không gây regression lớn cho logic đang chạy ổn.