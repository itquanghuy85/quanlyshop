# Ghi chú cập nhật — HULUCA Shop Manager (12/09/2026)

**Phiên bản:** 3.6.0 (build 557)
**Bản đang trên store:** 3.4.0 (build 545) — phát hành 17/08/2026
**Bản 3.5.0 (556)** đã đóng gói ngày 06/09 nhưng **chưa đăng store** ⇒ bản 3.6.0 này gộp toàn bộ nội dung 3.5.0 (xem `release_notes_2026-09-06.md`) **cộng thêm** phần mới từ 07/09 → 12/09 dưới đây.

Dành để đăng lên Google Play (Play Console) và App Store (App Store Connect), mục "Thông tin mới trong phiên bản này". Viết cho người dùng thường, không dùng thuật ngữ kỹ thuật.

> ⚠️ **Số build phải tăng.** Bản live là 545 ⇒ build mới bắt buộc > 545; ở đây dùng **557**. `pubspec.yaml` đang là `3.6.0+557` (chưa commit — commit chung với bản build).

---

## Bản đầy đủ (đăng nội bộ / gửi khách hàng / lưu tham khảo)

### 🔄 Đồng bộ giữa các máy — kiểm thử thật trên 2 điện thoại, sửa tận gốc

Toàn bộ luồng (tạo đơn → sửa xong → gửi duyệt → duyệt giao → xoá; bán hàng; nhập kho; thu nợ) được chạy thật trên 2 máy cùng shop, đối chiếu từng bảng dữ liệu.

- **Nhân viên gửi "Yêu cầu duyệt giao" không còn bị tự biến thành "Đã giao".** Trước đây có trường hợp yêu cầu duyệt tới máy chủ shop lại hiện thành đơn đã giao, không ai duyệt mà máy vẫn báo giao xong.
- **Mỗi thao tác chỉ đẩy lên cloud một lần.** Trước đây một lần bấm "Sửa xong" ghi lên tới 4 lần, tạo đơn ghi 3 lần, bán hàng 2 lần — máy khác nhận đi nhận lại cùng một tin và **thông báo "đơn mới" hiện 2 lần**. Nay 1 thao tác = 1 lần ghi = 1 thông báo.
- **Thông báo trong khay không còn hiện đôi** khi app đang ở nền.
- Nhật ký tài chính, lịch sử nhập nhà cung cấp, thanh toán, công nợ **về đủ ở máy khác** — trước đây một số dòng ghi từ máy này phải tới hôm sau máy kia mới thấy.
- **Máy cài lại / đăng nhập lại kéo đủ dữ liệu từ cloud** (nhật ký tài chính từng về 0 dòng dù cloud có cả trăm).
- Trung tâm đồng bộ **nói rõ "N cần đồng bộ" là gì** — bảng nào, lệch chiều nào, và nút "Tự động sửa" sửa thật (trước báo đã sửa mà không sửa).
- Sửa lỗi 10 bảng bị **kẹt vĩnh viễn ở 20 dòng** và lịch làm việc lệch mãi giữa các máy.
- **Ít tốn dữ liệu / ít tốn tiền Firebase hơn hẳn:** mỗi lần mở app đọc cloud ít hơn ~4 lần so với trước (đo thật: ~170 → ~42 lượt đọc); một số bảng trước đây tải lại toàn bộ mỗi lần mở app nay chỉ tải phần mới.

### 💰 Tài chính — số liệu kiểm bằng kịch bản 25 bước trên máy thật

- **"Lãi sau chi phí" không còn trừ vốn sửa chữa 2 lần.**
- Xuất Excel tài chính ra **số đúng định dạng** (trước ra chữ).
- **Chốt quỹ** mở nhanh hơn nhiều (không tải nguyên bảng từ cloud) và không còn vứt dữ liệu vừa tải vì lỗi quyền.
- Chủ shop giao máy **chọn được Chuyển khoản / Công nợ** ngay trong bảng duyệt.
- Tiền tất toán từ ngân hàng, nhập kho nhiều dòng, ngày ghi sổ… đều đã đối chiếu khớp 100% với kịch bản.

### 🤝 Công nợ

- **Thu / trả gộp ngay trong tab Nợ** — bấm vào người, bấm "Thu/Trả gộp cả N khoản" là xong, không phải sang màn Công nợ đi tìm lại.

### 🏷️ Bảng giá

- **Tìm kiếm dễ hơn:** gõ từ khoá theo bất kỳ thứ tự nào, có dấu hay không dấu, dùng viết tắt quen tay (ip = iPhone, ss = Samsung, mh = màn hình, ek = ép kính, tp = thay pin…). Ví dụ gõ "mh 12 ip" là ra "iPhone 12 · Màn hình". Có nút xoá nhanh.
- Nút "Thêm mục" sửa lại cho đẹp.

### 🔧 Đơn sửa

- **Bảo hành chỉ còn một dòng ghi chú:** chọn nhanh KO BH / 1 / 3 / 6 / 12 tháng hoặc gõ tự do ("BH màn 3 tháng, pin 6 tháng"). Bỏ nhắc "sắp hết hạn" gây rối.
- Sửa điện thoại thiếu Model không còn làm mất tên khách.
- Vá crash lâu năm khi đóng bảng nhập liệu (màn trắng / thoát đột ngột).

### 🧹 Gọn app

- Gỡ hẳn các phần dành cho ngành khác (thời trang, thực phẩm…) và màn "Quản lý danh mục" chưa dùng — app tập trung cho tiệm điện thoại.

### 🛠️ Cộng thêm toàn bộ bản 3.5.0 (chưa lên store)

Tài chính chia 3 phần Tiền / Lãi / Nợ · Tab Nợ gom theo người · Bảng giá tự động + giá tham khảo khi nhập giá · QR VietQR + tự đọc thông báo ngân hàng (Android) · Trang chủ bấm dòng nào cũng mở chi tiết · Tìm kiếm không dấu toàn app · AI Trợ Lý hiểu toàn bộ app · sửa lỗi doanh thu phình 35,6 tỷ do KiotViet trùng, thanh toán không trừ nợ, chốt quỹ dồn tiền vào ngân hàng… (chi tiết: `release_notes_2026-09-06.md`).

---

## Bản rút gọn — dán vào khung "What's New" (≤ 500 ký tự)

```
🔄 Đồng bộ giữa các máy sửa tận gốc: mỗi thao tác 1 lần ghi, hết thông báo đôi, yêu cầu duyệt giao không còn tự thành "Đã giao", dữ liệu về đủ mọi máy. Mở app nhẹ và ít tốn dữ liệu hơn ~4 lần.
💰 Tài chính 3 phần Tiền / Lãi / Nợ, số liệu đã kiểm bằng kịch bản 25 bước; lãi không trừ vốn 2 lần; chốt quỹ nhanh hơn.
🤝 Thu / trả gộp ngay trong tab Nợ.
🏷️ Bảng giá tự động, tìm kiếm viết tắt (ip, ss, mh, ek…).
🏦 QR VietQR + tự đọc thông báo ngân hàng.
🛠️ Vá crash và nhiều lỗi số liệu.
```

---

## Việc cần làm trước khi upload

1. Commit `pubspec.yaml` = `3.6.0+557` cùng bản build này.
2. `flutter build appbundle --release` (Android); iOS: `flutter build ipa --release` (min deployment 15.0).
3. Đối chiếu Play Console: bản live **3.4.0 (545)**, tệp mới build **557 > 545**.
4. Dán "Bản rút gọn" vào *What's new* / *Thông tin mới trong phiên bản này*.
5. Index Firestore `partner_repair_history (shopId, updatedAt)` đã deploy 12/09 — chờ trạng thái **Enabled** trên console trước khi phát hành rộng (chưa xong thì app vẫn chạy, chỉ chưa tiết kiệm đọc cho bảng đó).
