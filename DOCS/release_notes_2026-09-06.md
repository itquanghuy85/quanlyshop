# Ghi chú cập nhật — HULUCA Shop Manager (06/09/2026)

**Phiên bản:** 3.5.0 (build 556)
**Bản đang trên store:** 3.4.0 (build 545) — phát hành 17/08/2026

Dành để đăng lên Google Play (Play Console) và App Store (App Store Connect), mục "Thông tin mới trong phiên bản này". Viết cho người dùng thường, không dùng thuật ngữ kỹ thuật.

> ⚠️ **Số build phải tăng.** Bản live là 545 nên build mới bắt buộc lớn hơn 545 — ở đây dùng **556** (các build 546–555 đã đóng gói thử trong nội bộ). Không đặt số nhỏ hơn 545, Play Console sẽ từ chối tệp.

---

## Bản đầy đủ (đăng nội bộ / gửi khách hàng / lưu tham khảo)

Đây là bản cập nhật lớn nhất từ trước tới nay — gần 3 tuần làm liên tục kể từ bản 3.4.0.

### 💰 Tài chính — làm lại toàn bộ cho dễ theo dõi

- **Tab Tài chính chia lại thành 3 phần theo đúng 3 câu hỏi hay gặp:**
  **TIỀN** (hôm nay thu/chi bao nhiêu, gồm những giao dịch nào) · **LÃI** (bán/sửa xong còn lại bao nhiêu) · **NỢ** (ai nợ mình, mình nợ ai).
- Số tiền và danh sách giao dịch sinh ra nó **nằm chung một màn** — bấm "Tiền vào" hoặc "Tiền ra" là lọc ngay danh sách bên dưới, không phải đổi tab đi tìm.
- Thanh chọn kỳ (Hôm nay / 7 ngày / 30 ngày / Tùy chọn) chuyển lên đầu màn, **dùng chung cho cả 3 phần**.
- Khối **Lãi gộp** trình bày kiểu cộng trừ nhìn thấy được: Doanh thu đã thu − Vốn = Lãi.
- **Báo cáo đầy đủ** tách thành màn riêng, lấy lại đủ các nút In / In chi tiết / Xuất Excel / Excel chi tiết.
- **Đối soát tiền về:** nhập số tiền vừa nhận → app tự tìm đơn trả góp hoặc công nợ khớp số → xác nhận là ghi sổ.
- **Sổ quỹ** ghi rõ đang cộng gộp những ngày nào khi có ngày chưa chốt quỹ, và có ô **tìm kiếm giao dịch** theo tên / loại / khoảng ngày.
- Tiền **tất toán từ ngân hàng** (đơn trả góp) nay vào đúng ngày thực nhận, không còn lệch kỳ.
- **Giá vốn được bảo vệ theo quyền:** nhân viên không có quyền xem giá vốn thì không thấy trên màn hình, và file in / Excel xuất ra cũng không kèm cột giá vốn.

### 🏷️ Bảng giá — hết cảnh phải nhớ giá trong đầu

- **Bảng giá tự động** cho cả sửa chữa lẫn bán hàng: app tự tính giá thường gặp từ lịch sử đơn đã xong.
- **Giá niêm yết:** chủ shop ghim giá chính thức cho từng "máy · lỗi", nhân viên cứ thế áp dụng.
- **Bảng giá từ hoá đơn NCC:** đưa file Excel hoá đơn nhà cung cấp vào, app đọc và cập nhật giá vốn phụ tùng — đồng bộ giữa các máy.
- **Giá tham khảo hiện ngay lúc nhập giá**, ở cả khi bán hàng lẫn ở mọi ô nhập giá của đơn sửa (Tài chính đơn sửa, gửi duyệt giao, duyệt giao máy). Có nút **Dùng** để điền thẳng vào ô, khỏi gõ tay nhầm số 0.
- Xuất / nhập Bảng giá bằng Excel để sửa hàng loạt.

### 🏦 Ngân hàng & thanh toán

- **Mã QR chuyển khoản VietQR** ở mọi bảng thanh toán, kèm nút mở thẳng app ngân hàng.
- **Tự đọc thông báo app ngân hàng (Android):** tiền về là app bắt được, gợi ý đối soát ngay.
- Phiếu gửi khách in kèm **Nợ cũ / Lần này / Tổng nợ** và mã QR theo đúng tổng nợ.

### 🔧 Đơn sửa

- **Đơn đã giao vẫn sửa/bổ sung được** (thêm linh kiện, đổi kỹ thuật viên, chỉnh giá) — mọi thay đổi đều được ghi nhật ký.
- Phụ tùng và dịch vụ hiện ngay trong danh sách đơn; chạm vào là mở đúng nguồn (kho / nhà cung cấp / đối tác).
- Phân biệt rõ **"chưa nhập giá vốn"** và **"đơn không tốn giá vốn (0đ)"** — hết bị nhắc nhầm.
- Gán / sửa nhà cung cấp cho linh kiện đã nhập.

### 🤝 Công nợ

- **Tab Nợ gom theo từng người:** trước đây mỗi khoản nợ một dòng nên một nhà cung cấp hiện 5–6 dòng liền nhau (43 khoản trải 3 trang). Nay mỗi người **một dòng** kèm tổng nợ và số khoản — 43 khoản gom lại còn 10 người, xem hết trong một trang.
- **Bấm vào là ra ngay chi tiết:** từng khoản nợ vì việc gì (nhập hàng, linh kiện, gửi sửa đối tác, bán hàng, vay…), số tiền bao nhiêu, phát sinh lúc nào — không phải mở lại màn Công nợ rồi tự đi tìm.
- **Gộp nhiều đơn của một khách** thành một khoản nợ (bán sỉ), thu tiền tự phân bổ lần lượt từ đơn cũ nhất.
- Thông báo cho cả shop khi có người **thu nợ / trả nợ / tạo nợ / miễn nợ**.

### 🏠 Trang chủ

- **Thao tác nhanh** thêm 2 lối tắt: **Đối soát tiền** và **Bảng giá**.
- **Hoạt động hôm nay**: bấm vào bất kỳ dòng nào cũng mở được chi tiết (đơn bán, đơn sửa, thu/chi, công nợ, trả nhà cung cấp, thanh toán đối tác) — trước đây phần lớn bấm vào không có gì xảy ra.
- Gộp "Cần xử lý" vào **Nhắc nhở** cho gọn một đầu mối.

### 🤖 Trợ lý & hướng dẫn

- **AI Trợ Lý hiểu toàn bộ app** — hỏi bất kỳ tính năng nào cũng chỉ được đường đi và cách làm.
- **Bản tin đầu ngày** tóm tắt tình hình shop.
- Nút **ⓘ** mở lại hướng dẫn ở khoảng 18 màn hình, kèm **Trung tâm trợ giúp** và cẩm nang thuật ngữ tài chính.
- Danh mục tính năng A–Z + checklist khám phá cho người mới.

### 🔍 Tìm kiếm & đồng bộ

- **Tìm kiếm không dấu** và không phân biệt hoa/thường trên toàn app — gõ "nguyen van a" vẫn ra "NGUYỄN VĂN A".
- **Trung tâm đồng bộ** gọn lại còn 3 nút thay vì 8.
- Sửa lỗi đơn "Đã giao" bị máy khác kéo ngược về trạng thái cũ.
- Sửa lỗi đồng bộ làm mất dữ liệu trên máy trong một số trường hợp hiếm.

### 🛠️ Sửa lỗi đáng kể khác

- Sửa lỗi hoá đơn nhập từ KiotViet bị trùng làm **doanh thu phình sai tới 35,6 tỷ**.
- Sửa lỗi thanh toán công nợ không trừ nợ, và mỗi tài khoản nhìn thấy một số liệu khác nhau.
- Sửa lỗi tiền của đơn "kết hợp tiền mặt + chuyển khoản" bị dồn hết vào ngân hàng khi chốt quỹ.
- Sửa crash màn Sổ quỹ; sửa lỗi không chọn được phụ tùng cho đơn sửa; sửa lỗi sửa dịch vụ làm mất đối tác nên không ghi công nợ.
- Sửa lỗi bàn phím che ô nhập ở nhiều bảng trượt.
- Khôi phục quyền Super Admin và sửa lỗi thoát app ra màn hình đen.

---

## Bản rút gọn — dán vào khung "What's New" (≤ 500 ký tự)

```
Bản cập nhật lớn nhất từ trước tới nay:

💰 Tài chính chia lại 3 phần Tiền / Lãi / Nợ — số tiền và danh sách giao dịch nằm chung một màn.
🤝 Tab Nợ gom theo từng người, bấm ra ngay chi tiết nợ vì việc gì.
🏷️ Bảng giá tự động + giá tham khảo ngay lúc nhập giá, bấm "Dùng" là xong.
🏦 QR chuyển khoản VietQR + tự đọc thông báo ngân hàng (Android).
🏠 Hoạt động hôm nay: bấm dòng nào cũng mở được chi tiết.
🔍 Tìm kiếm không dấu toàn app.
🛠️ Sửa nhiều lỗi số liệu tài chính.
```

---

## Việc cần làm trước khi upload

1. `flutter build appbundle --release` (Android) — kiểm tra `pubspec.yaml` đang là `3.5.0+556`.
2. Đối chiếu lại: bản live trên Play Console là **3.4.0 (545)**; tệp mới phải có build **> 545**.
3. iOS: `flutter build ipa --release`, min deployment 15.0 (đã nâng từ bản 3.4.0).
4. Dán "Bản rút gọn" ở trên vào ô *What's new* / *Thông tin mới trong phiên bản này*.
