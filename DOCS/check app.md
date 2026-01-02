<<<<<<< HEAD
# QA TEST PLAN – KIỂM TRA ỨNG DỤNG THEO TỪNG PHASE

Tài liệu này dùng để yêu cầu AI hoặc đội QA kiểm tra **toàn bộ hệ thống ứng dụng** theo từng phase rõ ràng, có đầu ra cụ thể, tập trung vào **độ chính xác dữ liệu, logic nghiệp vụ và an toàn tài chính**.

---

## 🔴 PHASE 1 – KIỂM TRA DỮ LIỆU & CHỐNG SAI SỐ TIỀN (BẮT BUỘC)

### Mục tiêu

Đảm bảo **mọi số liệu tiền tệ là chính xác tuyệt đối**, không âm, không trùng, không lệch giữa các module.

### Phạm vi kiểm tra

* Doanh thu bán hàng
* Doanh thu sửa chữa
* Nhập hàng – nhập kho
* Công nợ khách hàng- nhà cung cấp
* Tổng doanh thu – lợi nhuận

### Yêu cầu kiểm tra

* Đối chiếu số tiền giữa các bảng dữ liệu, màn hình và logic xử lý
* Phát hiện:

  * Cộng tiền trùng
  * Làm tròn sai
  * Âm tiền
  * Sửa / xóa dữ liệu làm sai tổng

### Kết quả bắt buộc

* Danh sách lỗi **Critical**
* Mô tả nguyên nhân logic
* Đề xuất hướng sửa cụ thể

---

## 🟠 PHASE 2 – KIỂM TRA LOGIC NGHIỆP VỤ (BÁN – SỬA – KHO)

### Mục tiêu

Đảm bảo mọi nghiệp vụ chạy **đúng thứ tự – đủ bước – không bỏ sót**.

### Phạm vi kiểm tra

* Bán hàng (tiền mặt / chuyển khoản/ trả góp)
* Bán máy theo IMEI
* Sửa chữa có / không linh kiện
* Trừ kho khi bán và sửa chữa

### Yêu cầu kiểm tra

* Duyệt từng luồng nghiệp vụ:

  * Tạo → cập nhật → hoàn tất → hủy
* Phát hiện:

  
  * Sửa xong nhưng không trừ kho
  * Hủy / hoàn nhưng không hoàn kho

### Kết quả bắt buộc

* Danh sách lỗi logic nghiệp vụ
* Luồng gây lỗi
* Điều kiện cần bổ sung để chặn lỗi

---

## 🟡 PHASE 3 – NHẬP KHO, TỒN KHO & DỮ LIỆU NGUY HIỂM

### Mục tiêu

Kho **không âm – không ảo – không mất dấu vết lịch sử**.

### Phạm vi kiểm tra

* Nhập kho
* Nhập trùng hóa đơn
* Xóa phiếu nhập
* Sửa số lượng sau khi đã phát sinh giao dịch

### Yêu cầu kiểm tra

* Phát hiện các tình huống nguy hiểm:

  * Âm kho
  * Sai tồn kho thực tế
  * Mất lịch sử giao dịch

### Kết quả bắt buộc

* Danh sách lỗi nguy hiểm
* Cảnh báo nghiệp vụ
* Đề xuất khóa logic / rule bắt buộc

---

## 🟢 PHASE 4 – CHẤM CÔNG & NHÂN SỰ

### Mục tiêu

Không chấm công ảo, không tính sai giờ làm.

### Phạm vi kiểm tra

* Chấm công vào / ra
* Trùng bản ghi
* Sai ngày, sai giờ
* Logic tính giờ làm

### Yêu cầu kiểm tra

* Phát hiện:

  * Không kiểm tra đầu vào
  * Không khóa thời gian
  * Cho phép sửa dữ liệu tùy ý

### Kết quả bắt buộc

* Lỗi logic chấm công
* Đề xuất validation
* Đề xuất rule chống gian lận

---

## 🔵 PHASE 5 – PHÂN QUYỀN & BẢO MẬT

### Mục tiêu

Người không có quyền **không thể truy cập hoặc thao tác vượt quyền**.

### Phạm vi kiểm tra

* vai trò supper admin
Vai trò chủ shop, quản lý
* Nhân viên bán hàng
* Kỹ thuật sửa chữa

### Yêu cầu kiểm tra

* Kiểm tra quyền ở:

  * Màn hình (UI)
  * Chức năng
  * Logic xử lý phía sau

### Kết quả bắt buộc

* Danh sách màn hình sai quyền
* Function / logic thiếu kiểm tra role
* Đề xuất chặn ở UI và backend logic

---

## 🟣 PHASE 6 – LOGIC NHẬP LIỆU & CRASH NGẦM

### Mục tiêu

Ngăn mọi trường hợp **nhập sai dữ liệu gây crash hoặc sai số liệu**.

### Phạm vi kiểm tra

* Form số tiền
* Form số lượng
* Form ngày giờ
* Trường dữ liệu bắt buộc

### Yêu cầu kiểm tra

* Phát hiện:

  * Nhập số âm
  * Nhập chữ vào trường số
  * Null / rỗng gây lỗi

### Kết quả bắt buộc

* Danh sách lỗi nhập liệu
* Mức độ nguy hiểm
* Validation cần bổ sung

---

## 🟤 PHASE 7 – ĐỒNG BỘ, MẤT MẠNG & KHÔI PHỤC DỮ LIỆU

### Mục tiêu

Ứng dụng **không mất dữ liệu trong mọi tình huống xấu**.

### Phạm vi kiểm tra

* Mất mạng khi đang thao tác
* Đóng app đột ngột
* Mở lại app
* Đồng bộ local ↔ database

### Yêu cầu kiểm tra

* Phát hiện:

  * Trùng dữ liệu
  * Mất dữ liệu
  * Ghi dữ liệu nửa chừng

### Kết quả bắt buộc

* Danh sách rủi ro
* Đề xuất hướng xử lý an toàn

---

## ⚫ PHASE 8 – TỔNG HỢP & KHUYẾN NGHỊ CUỐI

### Báo cáo tổng hợp phải gồm

1. Top lỗi **nghiêm trọng nhất**
2. Lỗi có thể gây **sai tiền hoặc tranh chấp tài chính**
3. Lỗi logic cần sửa ngay
4. Thứ tự sửa khuyến nghị để tránh lỗi dây chuyền
5. Checklist bàn giao ứng dụng an toàn

---

**Lưu ý:**

* Trình bày rõ ràng, có thể dùng làm checklist sửa lỗi cho lập trình viên
* Không thêm tính năng mới nếu không được yêu cầu
* Ưu tiên an toàn dữ liệu và tài chính
=======
✅ CHECKLIST LÀM APP HOÀN CHỈNH (TỪ A → Z)
I. CHECK NỀN TẢNG & CẤU TRÚC

☐ Tạo project chuẩn (Flutter / Android / iOS đúng version)
☐ Chia thư mục rõ ràng:

views / screens

widgets

services

models

utils / constants

☐ Không code UI dồn hết vào 1 file
☐ Mỗi màn hình = 1 file
☐ Widget lặp lại → tách widget riêng

👉 Sai khúc này = về sau sửa muốn khóc.

II. CHECK UI / GIAO DIỆN (RẤT QUAN TRỌNG)

☐ Màu nền – màu chữ tương phản cao (nhìn ngoài trời vẫn rõ)
☐ Font size:

Title ≥ 16–18

Nội dung ≥ 14
☐ Không chữ mờ, không xám nhạt vô lý
☐ Nút bấm:

Cao ≥ 44px

Bấm 1 tay dễ
☐ Không tràn chữ, không overflow vàng đen
☐ Padding đều, không chỗ dày chỗ mỏng

☐ Home nhìn vô là biết:

App này làm gì

Bấm chỗ nào trước

III. CHECK HOME (MÀN QUAN TRỌNG NHẤT)

☐ Hiển thị chức năng chính dạng nút lớn / card
☐ Không giấu tính năng quan trọng trong menu
☐ Mỗi chức năng = 1 nút rõ ràng
☐ Có icon + chữ (đừng icon không chữ)
☐ Sắp xếp theo tần suất dùng (dùng nhiều để trên)

IV. CHECK LUỒNG SỬ DỤNG (FLOW)

☐ Tạo mới → lưu → quay lại → thấy dữ liệu
☐ Sửa → lưu → dữ liệu cập nhật đúng
☐ Xoá → có xác nhận
☐ Back không mất dữ liệu đang nhập
☐ Không bắt người dùng nhập lại vô lý

👉 Test bằng não người dùng, không phải não dev 😆

V. CHECK FORM & NHẬP LIỆU

☐ Label rõ ràng, không đoán
☐ Có validate:

Rỗng

Sai định dạng
☐ Bàn phím đúng loại (số / chữ)
☐ Nhập dài không vỡ layout
☐ Nút lưu disable khi chưa đủ dữ liệu

VI. CHECK DATA & LOGIC

☐ Lưu dữ liệu đúng nơi (local / cloud rõ ràng)
☐ Không hard-code dữ liệu mẫu
☐ Mỗi hành động có xử lý lỗi
☐ Không crash khi data null
☐ Reload app → dữ liệu vẫn còn

VII. CHECK HIỆU NĂNG

☐ Mở app không lag
☐ Scroll list mượt
☐ Không rebuild vô tội vạ
☐ Không setState cả màn hình khi chỉ đổi 1 item

VIII. CHECK DEBUG & BẢO TRÌ

☐ Bật Flutter Inspector test layout
☐ Có log khi lỗi (print / logger)
☐ Code dễ đọc, dễ sửa
☐ Không để code chết (unused)

IX. CHECK TRƯỚC KHI BUILD

☐ Test trên:

Máy nhỏ

Máy lớn
☐ Test xoay ngang / dọc (nếu cần)
☐ Test bấm nhanh liên tục
☐ Không còn banner debug
☐ Icon + splash đúng

X. CHECK GIAO CHO KHÁCH / SỬ DỤNG THẬT

☐ Người không biết code vẫn dùng được
☐ Không cần giải thích miệng quá nhiều
☐ Làm 1–2 thao tác là hiểu app


👉 Nếu còn câu đó = UI FAIL 😅

🔒 NGUYÊN TẮC VÀNG (GHI ĐẬM CHO AI LÀM)

❌ Không sửa chỗ này làm hỏng chỗ khác

❌ Không thay UI mà không báo

✅ Mỗi lần sửa phải test lại toàn flow liên quan

✅ Ưu tiên dễ dùng hơn đẹp
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
