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