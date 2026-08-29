# Ghi chú cập nhật — Quản Lý Shop (29/08/2026)

**Phiên bản:** 3.5.0 (build 547)

Dành để đăng lên Google Play (Play Console) và App Store (App Store Connect), mục "Thông tin mới trong phiên bản này". Viết cho người dùng thường, không có thuật ngữ kỹ thuật.

---

## Bản đầy đủ (đăng nội bộ / lưu tham khảo)

**🔧 Sửa lỗi tài chính**

- Sửa lỗi Sổ quỹ và báo cáo tài chính cộng nhầm "tiền vào" từ những đơn công nợ đã bị hủy — tiền thu nợ của đơn đã hủy không còn bị tính nữa.
- Sửa lỗi khoản thanh toán cho đối tác sửa chữa bị trừ **hai lần** trong Sổ quỹ và khi Chốt quỹ.
- Sửa lỗi công nợ khách hiển thị sai "số đã trả" — giờ luôn bằng đúng tổng các phiếu thu, trạng thái "còn nợ / đã trả" cũng cập nhật chính xác theo.
- Chặn tạo đơn công nợ có thành tiền bằng 0 (do nhập nhầm giảm giá), và không để công nợ thật bị đưa về 0 khi sửa đơn.
- Đơn bán dưới giá vốn giờ hiển thị đúng là **lỗ** (trước đây bị làm tròn về 0).
- Sửa lỗi đơn **trả góp**: khoản tất toán ngân hàng nhận ở ngày khác ngày bán không được tính vào doanh thu/dòng tiền của Sổ quỹ và Báo cáo ngày (khi mở nhanh từ máy / lúc mất mạng).

**✨ Cải tiến**

- Phân biệt rõ ràng **"Dòng tiền"** (tiền thực sự thu/chi) và **"Kết quả kinh doanh"** (doanh thu − giá vốn − chi phí) trên các màn hình Báo cáo ngày, Báo cáo lợi nhuận tháng, Trang chủ và file Excel xuất ra — không còn gọi lẫn "tiền mặt" thành "doanh thu / lợi nhuận".
- Thêm mục **"Tài chính"** trong Công cụ điều chỉnh dữ liệu (Cài đặt → Dữ liệu & Hệ thống) — tự phát hiện và giúp dọn phiếu thu nợ mồ côi, công nợ lỗi số tiền (có xác nhận mật khẩu, không tự động chạy).
- Toàn bộ số liệu tài chính đồng bộ, ổn định và chính xác hơn.

---

## Bản rút gọn (dễ vừa khung "What's New")

```
🔧 Sửa lỗi tài chính:
• Sổ quỹ/báo cáo cộng nhầm "tiền vào" từ đơn công nợ đã hủy
• Thanh toán đối tác sửa chữa bị trừ 2 lần khi chốt quỹ
• Công nợ khách hiển thị sai "số đã trả" và trạng thái còn nợ
• Đơn bán dưới giá vốn không hiện lỗ

✨ Cải tiến:
• Phân biệt rõ "Dòng tiền" và "Kết quả kinh doanh" ở Báo cáo
  ngày/tháng, Trang chủ và file Excel
• Thêm công cụ dọn dữ liệu tài chính lỗi trong Cài đặt
• Số liệu tài chính đồng bộ, chính xác hơn
```

---

## Bản siêu ngắn (nếu cần rút gọn hơn nữa)

```
• Sửa lỗi Sổ quỹ cộng nhầm tiền từ đơn công nợ đã hủy, thanh toán đối tác bị trừ 2 lần
• Công nợ khách hiển thị đúng số đã trả và trạng thái còn nợ
• Báo cáo phân biệt rõ "Dòng tiền" và "Kết quả kinh doanh"
• Thêm công cụ dọn dữ liệu tài chính lỗi trong Cài đặt
```
