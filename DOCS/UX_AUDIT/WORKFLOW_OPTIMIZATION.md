# Workflow Optimization

## Nguyên tắc đánh giá
Workflow trong app này phải được tối ưu cho môi trường cửa hàng đông khách, nơi nhân viên cần:
- thao tác nhanh
- ít bấm
- ít nhớ
- ít chuyển ngữ cảnh
- ít rủi ro nhập sai

---

## 1. Repair Workflow

### Current flow
- Home -> Create Repair
- Nhập khách hàng / máy / lỗi / phụ kiện / giá / dịch vụ / ảnh / vị trí kho
- Lưu local + sync
- Sang Order List / Repair Detail
- Cập nhật tiến độ / linh kiện / chi phí / giao máy / thanh toán / in phiếu

### Đánh giá
- **Số bước thao tác:** nhiều
- **Cognitive load:** cao
- **Tốc độ thực tế:** ổn với người dùng quen, chậm với người mới
- **Tối ưu cho shop đông khách:** chưa đủ

### Điểm dư thừa
- Quá nhiều field ngay từ bước intake đầu tiên.
- Một số dữ liệu đáng lẽ nên “thu sau” nhưng đang cạnh tranh sự chú ý với dữ liệu bắt buộc.
- Detail screen vừa là thông tin vừa là control center, dẫn tới tâm lý nặng đầu.

### Nên tối ưu theo 2 phase
#### Phase 1: Intake siêu nhanh
- SĐT / tên
- model
- lỗi chính
- phụ kiện nhanh
- ảnh nhanh
- giá dự kiến (tùy chọn)
- lưu ngay trong 30-60 giây

#### Phase 2: Enrichment sau
- dịch vụ chi tiết
- đối tác sửa ngoài
- location kho
- ghi chú sâu
- xử lý tài chính phức tạp

### Kết luận
Repair workflow đang mạnh về độ đầy đủ, nhưng chưa mạnh về tốc độ intake. Đây là chỗ cần tối ưu nhất nếu mục tiêu là shop đông khách.

---

## 2. Inventory Workflow

### Current flow
- Home -> Inventory
- Lọc / tìm kiếm / mở chi tiết
- điều hướng sang nhập kho / kiểm kho / bán hàng / in tem / parts / pending stock

### Đánh giá
- **Số bước thao tác:** biến động, nhưng thường nhiều do phải chọn mode đúng
- **Cognitive load:** cao
- **Tốc độ thực tế:** nhanh với power user, chậm với người dùng trung bình
- **Tối ưu cho shop đông khách:** chỉ ở mức trung bình

### Vấn đề chính
- Inventory là một “mega screen” nhiều mode.
- User muốn làm 1 việc nhưng phải đi qua nhiều affordance cạnh tranh.
- Không tách rõ action theo intent: xem tồn, nhập hàng, sửa thông tin, in tem, kiểm kho.

### Đề xuất tối ưu
- Tách Inventory thành 3 lane rõ:
  1. Browse inventory
  2. Stock operations
  3. Label & utility
- Trong list item, ưu tiên hiển thị: tên, tồn, trạng thái, vị trí, next action.
- Dùng quick action bottom sheet cho thao tác theo item thay vì nhồi nhiều action trên bề mặt chung.

---

## 3. Customer Workflow

### Current flow
- Chọn từ create repair / create sale
- Hoặc vào customer management / profile / history

### Đánh giá
- **Số bước:** hợp lý
- **Cognitive load:** trung bình
- **Điểm tốt:** cho phép fallback từ lịch sử và hỗ trợ khách vãng lai
- **Điểm yếu:** chưa có mô hình CRM rõ ràng giữa “customer quick select” và “customer relationship hub”

### Tối ưu đề xuất
- Một “customer quick card” thống nhất trong create flows:
  - tên
  - số điện thoại
  - lần giao dịch gần nhất
  - tổng giá trị gần đây
  - nợ hiện tại nếu có
- Giảm nhu cầu phải mở screen riêng chỉ để xác nhận thông tin cơ bản.

---

## 4. Payment Workflow

### Current flow
- Chọn phương thức thanh toán trong sale/repair/debt
- Qua payment intent / validation / transaction / sync

### Đánh giá
- **Nghiệp vụ:** tốt
- **UX:** chưa truyền được sự chắc chắn tương xứng với độ quan trọng của tiền

### Vấn đề
- Thanh toán là hành động rủi ro cao nhưng feedback chưa luôn đủ mạnh theo từng giai đoạn.
- User cần biết rất rõ:
  1. đang chuẩn bị thanh toán
  2. đã ghi local chưa
  3. đã ghi tài chính chưa
  4. đã sync cloud chưa
  5. có cần làm gì tiếp không

### Tối ưu đề xuất
- Chuẩn hóa payment confirmation sheet chung cho toàn app.
- Tạo “payment outcome state” 4 mức rõ ràng:
  - saved locally
  - queued
  - completed
  - requires attention

---

## 5. Debt Workflow

### Current flow
- Home -> Debt
- Tab nhiều loại nợ
- Tìm kiếm / lọc / mở detail / thanh toán / xem lịch sử

### Đánh giá
- **Số bước:** không quá nhiều
- **Cognitive load:** rất cao
- **Tốc độ thực tế:** giảm mạnh khi danh sách dài hoặc nhiều loại nợ trộn nhau

### Vấn đề cốt lõi
Debt không phải chỉ là data screen. Debt phải là action screen.

Hiện tại màn hình nghiêng về liệt kê hơn là điều phối thu hồi.

### Cần chuyển sang mô hình operational triage
- Ưu tiên đầu: nợ quá hạn
- Sau đó: nợ lớn
- Sau đó: nợ mới phát sinh
- Sau đó: nợ có rủi ro cao

### Đề xuất redesign
- Header có KPI cực ngắn: tổng phải thu, tổng phải trả, quá hạn, cần xử lý hôm nay.
- Danh sách mặc định sort theo urgency chứ không chỉ theo thời gian.
- Card nợ phải có 1 primary action rõ: thu tiền / trả nợ / gọi khách / xem chi tiết.

---

## 6. Settings Workflow

### Current flow
- Home -> nhiều settings screens rời nhau
- Shop / notification / printer / label / salary / schedule / dashboard...

### Đánh giá
- **Số bước:** nhiều
- **Cognitive load:** cao
- **Tính scale:** yếu

### Vấn đề
- Settings không phải một hệ thống, mà là tập hợp các màn hình chuyên đề.
- Thiếu landing page settings đúng nghĩa với group, summary, search và ownership rõ ràng.

### Đề xuất
Tổ chức lại thành 5 nhóm lớn:
1. Cửa hàng & thương hiệu
2. Vận hành & bán hàng
3. Nhân sự & chấm công
4. In ấn & thiết bị
5. Nâng cao & quản trị

---

## Ma trận ưu tiên tối ưu workflow

| Workflow | Hiện trạng | Tác động doanh thu/vận hành | Priority |
|---|---|---|---|
| Repair | Đầy đủ nhưng nặng đầu | Rất cao | P0 |
| Inventory | Quyền năng cao nhưng phân tán | Rất cao | P0 |
| Payment | Logic tốt, feedback chưa đủ chắc | Cao | P1 |
| Debt | Khó scan, khó triage | Rất cao | P0 |
| Settings | Phân mảnh và khó scale | Cao | P1 |
| Customer | Tạm ổn nhưng chưa tối ưu | Trung bình | P2 |

## Kết luận thẳng
Workflow của app hiện tại phù hợp với người dùng đã quen app, nhưng chưa tối ưu cho môi trường áp lực cao và onboarding nhanh. Cần chuyển tư duy từ “màn hình có nhiều chức năng” sang “flow có ít quyết định hơn”.