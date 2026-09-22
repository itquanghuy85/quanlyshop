# Ghi chú cập nhật — HULUCA Shop Manager (22/09/2026)

**Phiên bản:** 3.7.2 (build 561)
**Bản đang trên store:** 3.6.0 (build 557)

Dành để đăng lên Google Play / App Store, mục "Thông tin mới trong phiên bản này". Viết cho người dùng, không dùng thuật ngữ kỹ thuật. Gộp mọi thay đổi từ 3.6.0 tới nay (12/09 → 22/09/2026).

---

## Bản đầy đủ (đăng nội bộ / gửi khách hàng)

### 🔌 Mới: dùng app không cần đăng nhập
- Có thể **dùng thử ngay** mà không cần tạo tài khoản — chủ shop "Dùng ngay" là vào thẳng, dữ liệu lưu trên máy.
- Khi sẵn sàng, **kết nối tài khoản** để đưa dữ liệu offline lên cloud và đồng bộ nhiều máy — có hướng dẫn từng bước ngay trong app.
- Ảnh chụp lúc offline không còn bị mất sau khi tắt app; tự động đẩy lên khi có mạng.

### 📴 Mất mạng không còn làm gián đoạn công việc
- **Bán hàng, tạo đơn sửa, nhập kho khi mất mạng**: lưu ngay trên máy, không treo, không báo lỗi — tự động đẩy lên cloud khi có mạng lại.
- **Bán hàng lúc mất mạng không còn cho bán vượt tồn kho** — ô số lượng tự giới hạn theo tồn thực tế, tránh âm kho.
- Máy khác nhận thay đổi (đơn mới, tồn kho, công nợ...) **nhanh hơn hẳn** — thường trong vài giây, kể cả khi máy đó đang khoá màn hình.

### 🔄 Đồng bộ giữa các máy — sửa nhiều lỗi "lệch số liệu"
- **Miễn nợ** giờ đồng bộ đúng lên mọi máy (trước đây nợ đã miễn có thể "sống lại" trên máy khác).
- **Chốt quỹ ngày** báo đúng cho tất cả máy — nhân viên không còn lỡ tạo đơn vào ngày chủ shop đã chốt.
- **Trả nợ nhà cung cấp** đồng bộ đúng số tiền trên mọi máy.
- Sửa lỗi hàng đợi đồng bộ bị "kẹt" mãi ở nút đỏ "Lỗi đồng bộ" trong một số trường hợp.
- Xoá đơn/trả hàng: kho và phiếu thu hoàn đúng, mọi máy nhận đúng.

### 🔧 Đơn sửa — giao diện mới + logic chặt hơn
- **Danh sách đơn sửa và chi tiết đơn sửa thiết kế lại**: gọn hơn, xem nhanh trạng thái/mã đơn/thời gian chờ, ưu tiên đơn cần xử lý lên đầu.
- **Sửa giá đơn đã giao máy tự động ghi công nợ chênh lệch**: tăng giá → tạo khoản khách còn nợ thêm; giảm giá → tạo khoản shop nợ lại khách; sửa nhiều lần hay đổi về giá cũ đều không tạo nợ trùng.
- Linh kiện đã dùng trong đơn giờ hoàn kho đúng món trên mọi máy khi xoá đơn/đổi linh kiện.
- Kiểm tra số điện thoại hợp lệ khi tạo đơn.
- Vá lỗi thoát đột ngột màn hình trắng khi đóng nhanh một số popup.

### 💰 Tài chính — giao diện mới, số liệu đã đối chiếu kỹ
- **4 tab Tiền / Lãi / Nợ / Chốt quỹ** thiết kế lại theo kiểu app tài chính, mở nhanh hơn nhiều (có bộ nhớ đệm thông minh).
- Phiếu thu/chi hiện ngay trên màn hình, không cần mở lại app.
- Hoàn tiền khi trả hàng hiển thị khớp nhau giữa các tab.
- Thu nợ đơn công nợ được tính đúng vào doanh thu/lãi trong ngày.
- Chốt quỹ hoạt động đúng với mọi hình thức thanh toán, không còn mất phiếu trả nợ trong một số trường hợp hiếm.
- Xuất Excel tài chính hiển thị đúng số.

### 🤝 Công nợ
- Thu/trả gộp nhiều khoản nợ cùng lúc ngay trong tab Nợ.
- Sửa lỗi hiển thị lệch khi có phiếu thu "mồ côi" (không gắn đúng khoản nợ).

### 👥 Nhân viên & phân quyền
- **Thêm lại công tắc "Cho phép xem GIÁ VỐN SẢN PHẨM"** trong màn phân quyền nhân viên — chủ shop có thể bật/tắt cho từng người (trước đây bị thiếu, không thu hồi được quyền này).
- Sửa tên nhân viên không lưu được trong một số trường hợp.

### 📐 Xem trên màn hình ngang / máy tính (web)
- 7 màn hình chính (Trang chủ, Bán hàng, Kho, Nhân viên...) hiển thị 2 cột gọn gàng hơn khi mở trên màn ngang hoặc trình duyệt máy tính.

### 🧹 Ổn định & dọn dẹp
- Giảm đáng kể lượng dữ liệu app phải tải mỗi lần mở — tiết kiệm 3G/4G, mở app nhanh hơn.
- Vá nhiều lỗi vặt: thông báo che nút không biến mất, popup tràn màn hình không bấm được nút xác nhận, đơn trả góp chờ ngân hàng tất toán biến mất khỏi nhắc nhở...
- Gỡ bớt các phần không dùng để app nhẹ và ổn định hơn.

---

## Bản rút gọn — dán vào "What's new" (≤ 500 ký tự)

```
🔌 Mới: dùng app không cần đăng nhập, kết nối tài khoản khi sẵn sàng.
📴 Mất mạng không còn gián đoạn: bán hàng/tạo đơn/nhập kho lưu ngay, không treo; hết bán vượt tồn kho.
🔄 Đồng bộ nhiều máy chắc hơn: miễn nợ, chốt quỹ, trả nợ NCC đều đúng trên mọi máy, nhanh hơn.
🔧 Đơn sửa: giao diện mới gọn hơn; sửa giá đơn đã giao tự ghi công nợ chênh lệch, không trùng.
💰 Tài chính 4 tab mới, mở nhanh hơn; số liệu đã đối chiếu kỹ, chốt quỹ ổn định mọi hình thức TT.
👥 Thêm lại công tắc ẩn/hiện giá vốn cho từng nhân viên.
🧹 App nhẹ hơn, mở nhanh hơn, vá nhiều lỗi vặt.
```
