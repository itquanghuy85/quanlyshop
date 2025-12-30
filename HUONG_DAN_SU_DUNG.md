# 📱 CẨM NANG HƯỚNG DẪN SỬ DỤNG HỆ THỐNG QUẢN LÝ SHOP QUANG HUY
**Phiên bản:** 1.0.0  
**Phát triển bởi:** Quang Huy Software  
**Hỗ trợ & Zalo:** 0964.09.59.79  

---

## 📑 MỤC LỤC
1. [Màn Hình Chính (Dashboard)](#1-màn-hình-chính)
2. [Quản Lý Kho & IMEI](#2-quản-lý-kho--imei)
3. [Bán Hàng & In Hóa Đơn](#3-bán-hàng--in-hóa-đơn)
4. [Quản Lý Sửa Chữa & Tiếp Nhận](#4-quản-lý-sửa-chữa--tiếp-nhận)
5. [Siêu Trung Tâm Bảo Hành](#5-siêu-trung-tâm-bảo-hành)
6. [Quản Lý Công Nợ](#6-quản-lý-công-nợ)
7. [Chấm Công & Tính Lương Nhân Viên](#7-chấm-công--tính-lương)
8. [Nhật Ký Hệ Thống (Audit Logs)](#8-nhật-ký-hệ-thống)
9. [Cấu Hình Máy In Nhiệt](#9-cấu-hình-máy-in-nhiệt)

---

## 1. MÀN HÌNH CHÍNH
Đây là "bộ não" của ứng dụng, nơi bạn nắm bắt toàn bộ tình hình kinh doanh trong 5 giây.

*   **Việc cần làm:** Hiển thị cảnh báo đỏ nếu có máy sắp hết hạn bảo hành.
*   **Trạng thái cửa hàng:**
    *   **Máy đang chờ sửa:** Tổng số máy chưa sửa xong (không kể ngày tháng).
    *   **Tổng công nợ:** Số tiền thực tế đang bị nợ bên ngoài.
*   **Tổng quan hôm nay:** Thống kê Máy mới, Đơn bán, Doanh thu và Chi phí phát sinh trong ngày.

> ![Ảnh minh họa: Màn hình Home với các con số nhảy tự động](assets/images/docs/home.png)

---

## 2. QUẢN LÝ KHO & IMEI
Tính năng nhập hàng siêu tốc, hỗ trợ quản lý từng con ốc đến chiếc điện thoại.

*   **Nhập kho siêu tốc:** Gộp 3 trường (Màu, Dung lượng, Tình trạng) thành 1 ô duy nhất. Nhập xong bấm "Nhập tiếp" để quét IMEI máy khác cực nhanh.
*   **Chọn Nhà Cung Cấp:** Mặc định là **KHO TỔNG**.
*   **Thanh toán:** Tự động trừ vào Chi phí (Tiền mặt/CK) hoặc cộng vào Công nợ (Nợ NCC).
*   **Xóa hàng loạt:** Nhấn giữ vào một máy để tick chọn nhiều máy và xóa cùng lúc.

> ![Ảnh minh họa: Giao diện nhập kho với các nút chọn thanh toán](assets/images/docs/inventory.png)

---

## 3. BÁN HÀNG & IN HÓA ĐƠN
Quy trình bán hàng chuyên nghiệp, in hóa đơn nhiệt như siêu thị.

*   **Tìm kiếm:** Nhập tên máy hoặc 4 số cuối IMEI. Hệ thống hiện rõ số lượng tồn và giá bán.
*   **Ghi nợ:** Nếu khách trả thiếu, chỉ cần nhập số tiền thu thực tế, hệ thống tự động đẩy phần còn lại vào Sổ Nợ Khách Hàng.
*   **In hóa đơn:** Hóa đơn hiện đầy đủ tên Shop, IMEI, Thời gian bảo hành và thông tin nợ (nếu có).

> ![Ảnh minh họa: Màn hình tạo đơn bán hàng và hóa đơn mẫu](assets/images/docs/sale.png)

---

## 4. QUẢN LÝ SỬA CHỮA & TIẾP NHẬN
Giúp kỹ thuật viên không bao giờ quên lỗi và tránh tranh cãi với khách.

*   **Tiếp nhận:** Chụp ảnh máy lúc nhận, lưu mật khẩu màn hình, ngoại quan.
*   **Chuyển trạng thái:** Nút **ĐÃ XONG** để báo khách, nút **GIAO MÁY** để kết thúc đơn.
*   **Chọn Bảo Hành:** Khi giao máy, hệ thống hiện sẵn các nút: 1, 3, 6, 12 tháng để chọn nhanh.
*   **Chia sẻ Zalo:** Gửi phiếu nhận máy sang Zalo khách hàng cực kỳ chuyên nghiệp.

> ![Ảnh minh họa: Chi tiết đơn sửa và nút chọn tháng bảo hành](assets/images/docs/repair.png)

---

## 5. SIÊU TRUNG TÂM BẢO HÀNH
Nơi quản lý lời hứa của bạn với khách hàng.

*   **Phân loại:** Máy Bán (Hồng) - Máy Sửa (Cam).
*   **Theo dõi:** Thanh tiến độ và bộ đếm ngày lùi. Sắp hết hạn sẽ hiện màu Đỏ rực.
*   **Tra cứu:** Quét mã QR trên tem hoặc hóa đơn để xem lại lịch sử bảo hành ngay lập tức.

> ![Ảnh minh họa: Danh sách bảo hành với thanh tiến độ xanh/đỏ](assets/images/docs/warranty.png)

---

## 6. QUẢN LÝ CÔNG NỢ
Đối soát tiền bạc minh bạch, không sót một đồng.

*   **Khách nợ:** Tự động cộng dồn từ Bán hàng/Sửa chữa.
*   **Nợ NCC:** Tự động cộng từ Nhập kho.
*   **Trả nợ:** Bấm nút "TRẢ NỢ", nhập số tiền, hệ thống tự trừ dần và chuyển sang "ĐÃ TRẢ" khi hết nợ.

> ![Ảnh minh họa: Sổ nợ với 2 Tab Khách hàng và Nhà cung cấp](assets/images/docs/debt.png)

---

## 7. CHẤM CÔNG & TÍNH LƯƠNG
Quản trị nhân sự bằng công nghệ AI và hình ảnh.

### 🕒 CÀI ĐẶT THỜI GIAN LÀM VIỆC
**Bước 1:** Từ màn hình chính → **Cài đặt** → **Lịch làm việc**

**Bước 2:** Cấu hình thời gian làm việc:
- **Giờ bắt đầu:** 08:00 (mặc định)
- **Giờ kết thúc:** 17:00 (mặc định)  
- **Giờ nghỉ trưa:** 1 giờ
- **Giờ OT tối đa:** 4 giờ/ngày

**Bước 3:** Chọn ngày làm việc trong tuần:
- ✅ Thứ 2 → Thứ 6 (mặc định)
- ❌ Chủ nhật (nghỉ)

**Bước 4:** Thêm ngày nghỉ lễ:
- Nhập ngày nghỉ lễ (VD: 2025-01-01)
- Hệ thống tự động tính lương không bao gồm ngày lễ

### 💰 CÀI ĐẶT TỶ LỆ TĂNG CA (OT)
- **Ngày thường:** 150% (mặc định)
- **Cuối tuần:** 200% (mặc định)  
- **Ngày lễ:** 300% (mặc định)

### 👥 CÀI ĐẶT LƯƠNG TỪNG NHÂN VIÊN
**Bước 1:** Trong **Lịch làm việc** → Tab **Lương nhân viên**

**Bước 2:** Chọn nhân viên từ danh sách

**Bước 3:** Nhập lương cơ bản (VNĐ/tháng):
- VD: Nguyễn Văn A - 8,000,000 đ/tháng
- VD: Trần Thị B - 7,500,000 đ/tháng

**Bước 4:** Lưu cài đặt cho từng nhân viên

### 📊 CÀI ĐẶT CÔNG THỨC TÍNH LƯƠNG CHUNG
**Bước 1:** Từ màn hình chính → **Cài đặt** → **Công thức lương**

**Bước 2:** Cấu hình các tỷ lệ:
- **Lương cơ bản:** 8,000,000 đ/tháng (mặc định)
- **Hoa hồng bán máy:** 1% trên giá bán
- **Thưởng sửa chữa:** 10% trên lợi nhuận

### 📸 CHẤM CÔNG HẰNG NGÀY
**Bước 1:** Nhân viên mở app → **Chấm công**

**Bước 2:** Nhấn **CHECK-IN** khi bắt đầu ca:
- Chụp ảnh selfie
- Hệ thống ghi nhận vị trí GPS
- Tự động phát hiện đi muộn/sớm

**Bước 3:** Nhấn **CHECK-OUT** khi kết thúc ca:
- Chụp ảnh selfie lần nữa
- Tính tổng giờ làm việc
- Tự động tính giờ OT nếu có

### 📈 XEM BÁO CÁO LƯƠNG
**Bước 1:** Từ màn hình chính → **Chấm công** → **Báo cáo**

**Bước 2:** Chọn tháng cần xem

**Bước 3:** Xem chi tiết:
- Số ngày công thực tế
- Giờ làm việc chuẩn/OT
- Lương cơ bản + hoa hồng + thưởng
- Tổng lương tháng

**Bước 4:** Xuất CSV để in bảng lương

> ![Ảnh minh họa: Nhân viên selfie chấm công và bảng lương tổng hợp](assets/images/docs/payroll.png)

---

## 8. NHẬT KÝ HỆ THỐNG (AUDIT LOGS)
"Hộp đen" bảo mật của cửa hàng.

*   Ghi lại mọi hành động: **Ai đã xóa máy? Ai đã sửa giá? Ai đã sửa ngày bảo hành?**
*   Giúp chủ shop truy soát gian lận hoặc sai sót dữ liệu 100%.

> ![Ảnh minh họa: Danh sách nhật ký hoạt động chi tiết](assets/images/docs/audit.png)

---

## 9. CẤU HÌNH MÁY IN NHIỆT
Hỗ trợ mọi loại máy in nhiệt trên thị trường.

*   **Kết nối:** Bluetooth (Tiện lợi) hoặc WiFi/LAN (Ổn định cao).
*   **Cỡ chữ:** Thanh trượt điều chỉnh độ phóng đại (Normal, Large, Extra Large).
*   **Khổ giấy:** Tùy chọn 80mm (Hóa đơn) hoặc 58mm (Tem/Cầm tay).

> ![Ảnh minh họa: Cài đặt máy in và thanh trượt chỉnh cỡ chữ](assets/images/docs/printer.png)

---
**QUANG HUY SOFTWARE - ĐỒNG HÀNH CÙNG SỰ THÀNH CÔNG CỦA BẠN!**
📩 Mọi yêu cầu tính năng mới xin liên hệ Zalo: **0964.09.59.79**
