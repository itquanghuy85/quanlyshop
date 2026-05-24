# UX Improvements

## Nguyên tắc cải thiện
Không nên vá từng lỗi lẻ. Cần sửa theo lớp hệ thống để giảm nợ UX bền vững.

## 1. Chuẩn hóa hệ thống giao diện trước

### Việc cần làm
- Chốt **một** chuẩn AppBar duy nhất cho toàn app.
- Chốt taxonomy cho card: summary, record, warning, action, settings.
- Chốt button hierarchy: primary, secondary, tertiary, destructive, quick action.
- Chốt loading states: inline, full-screen, blocking, refreshing, background sync.
- Chốt feedback states: success, partial success, warning, failure, queued offline.

### Tác động
- Giảm cảm giác app bị ghép từ nhiều module.
- Giảm thời gian thiết kế và review UI về sau.

---

## 2. Tái cấu trúc Home thành command center thật sự

### Hiện trạng
Home đang là dashboard + router + notification center + quick action hub + sync surface.

### Cải thiện đề xuất
- Chia Home thành 4 vùng rõ:
  1. Tình trạng cửa hàng hôm nay
  2. Việc cần xử lý ngay
  3. Truy cập nhanh theo vai trò
  4. Dòng hoạt động gần đây
- Giảm số shortcut cùng cấp xuất hiện mặc định.
- Cho phép vai trò khác nhau có home khác nhau.
- Những mục ít dùng nên đi qua “More / Tools / Settings”, không chiếm prime real estate.

### KPI mong muốn
- Nhân viên mới hiểu home trong dưới 10 giây.
- Tác vụ phổ biến nhất phải vào trong 1-2 chạm.

---

## 3. Tái thiết kế Repair Intake

### Mục tiêu
Biến tạo đơn sửa thành flow cực nhanh ở quầy, không bắt người dùng hoàn thành mọi dữ liệu ngay lập tức.

### Cải thiện đề xuất
- Bước 1: Khách + máy + lỗi chính + phụ kiện + ảnh nhanh.
- Bước 2: Giá tạm tính + ghi chú.
- Bước 3: Lưu đơn ngay.
- Bước 4: Các chi tiết sâu để bổ sung sau.

### UI đề xuất
- Sticky action footer với CTA rõ ràng.
- Section collapse cho thông tin nâng cao.
- Auto-focus và Next/Done flow tối ưu keyboard.
- Tự gợi ý khách cũ theo số điện thoại với preview card ngắn.

---

## 4. Tách Inventory thành experience theo mục đích

### Hiện trạng
Một screen phải phục vụ quá nhiều nhiệm vụ khác nhau.

### Cải thiện đề xuất
- `Kho` trở thành lớp danh mục và kiểm tra tồn.
- `Nhập hàng` là flow riêng.
- `Kiểm kho` là flow riêng.
- `In tem / tiện ích` gom vào utility layer.
- Mỗi item trong kho có quick action sheet chuẩn.

### Tác động
- Giảm số quyết định trong một thời điểm.
- Tăng tốc thao tác vì user không phải “tìm mode”.

---

## 5. Debt thành operations console

### Cải thiện đề xuất
- Default sort theo urgency.
- Header chỉ 4 KPI thực dụng.
- Chip lọc nhanh: quá hạn, lớn, hôm nay, chưa liên hệ, đã hẹn.
- Card nợ có CTA chính duy nhất theo ngữ cảnh.
- Tạo follow-up actions rõ ràng thay vì chỉ mở detail.

### Lợi ích
Debt từ màn hình “đọc thông tin” chuyển thành màn hình “xử lý công việc”.

---

## 6. Settings IA cần tái cấu trúc

### Cải thiện đề xuất
Tạo một landing settings duy nhất với:
- group title
- mô tả ngắn
- trạng thái hiện tại
- entry points sâu
- search settings
- recently changed settings

### Nhóm đề xuất
1. Cửa hàng
2. Bán hàng & sửa chữa
3. Kho & tem nhãn
4. Nhân sự & lịch làm
5. Thiết bị & in ấn
6. Quản trị nâng cao

---

## 7. Đồng bộ hóa offline/sync feedback

### Cải thiện đề xuất
- Một component status bar/sync chip chung toàn app.
- Một từ điển trạng thái chuẩn:
  - Đã lưu trên máy
  - Chờ đồng bộ
  - Đang đồng bộ
  - Đã đồng bộ
  - Cần kiểm tra
- Tất cả create/edit/payment flows dùng cùng từ điển này.

### Lợi ích
- User hiểu dữ liệu đang ở đâu.
- Giảm panic khi mạng chập chờn.

---

## 8. Loading UX phải phân loại theo tình huống

### Cải thiện đề xuất
- Full-screen loading: chỉ dùng lúc bootstrapping hoặc đổi ngữ cảnh lớn.
- Skeleton loading: dùng cho list/card/report.
- Inline loading: dùng cho nút hoặc section nhỏ.
- Background refresh: dùng badge/status nhỏ, không chặn thao tác.

### Điều cần tránh
- Spinner toàn màn hình cho mọi trường hợp.
- Dialog loading chặn người dùng khi không thật cần thiết.

---

## 9. Mobile ergonomics

### Cải thiện đề xuất
- Đưa action tần suất cao xuống vùng tay phải dễ chạm hơn.
- Dùng bottom action bar hoặc sticky footer cho create/edit flows.
- Giảm lệ thuộc vào top-right icon.
- Chuẩn hóa FAB strategy theo loại màn hình.

---

## 10. Chuẩn hóa language cho trust-critical actions

### Áp dụng cho
- thanh toán
- thu nợ/trả nợ
- giao máy
- xóa dữ liệu
- đổi quyền

### Cải thiện đề xuất
- Confirmation sheet rõ hệ quả.
- Outcome screen/state rõ ràng.
- Tránh chỉ hiện SnackBar ngắn cho hành động tài chính quan trọng.

---

## 11. Nên redesign theo thứ tự nào
1. Home
2. Debt
3. Inventory
4. Repair intake + repair detail
5. Settings architecture
6. Finance V2

## Kết luận
Nếu chỉ sửa visual polish, app sẽ đẹp hơn một chút nhưng vẫn mệt khi dùng. Nếu sửa đúng trọng tâm workflow + design system + async feedback, app sẽ tăng tốc thao tác thật và giảm lỗi vận hành rõ rệt.