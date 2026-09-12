# Ghi chú cập nhật — HULUCA Shop Manager (12/09/2026)

**Phiên bản:** 3.6.0 (build 557)
**Bản đang trên store:** 3.5.0 (build 556)

Dành để đăng lên Google Play / App Store, mục "Thông tin mới trong phiên bản này". Viết cho người dùng, không dùng thuật ngữ kỹ thuật. Chỉ gồm những gì mới so với 3.5.0.

---

## Bản đầy đủ (đăng nội bộ / gửi khách hàng)

### 📱 App nhẹ hơn, mở nhanh hơn, ít tốn dữ liệu
- Mỗi lần mở app đọc dữ liệu từ máy chủ **ít hơn hàng trăm lần** so với trước — tiết kiệm 3G/4G và chi phí vận hành, đặc biệt với shop có nhiều đơn.
- Không còn cảnh mở app đứng chờ "đang đồng bộ" lâu; bấm qua các tab không phải tải lại gì.

### 🔄 Đồng bộ giữa các máy — đã kiểm thử thật trên 2 điện thoại
- **Nhân viên gửi "Yêu cầu duyệt giao" hiện đúng là "Chờ duyệt"** trên máy chủ shop — không còn bị tự chuyển thành "Đã giao" khi chưa ai duyệt.
- **Thông báo không còn hiện đôi** (trước đây một đơn mới báo 2 lần, có khi 2 tin cùng nội dung trong khay thông báo).
- Đơn sửa, đơn bán, thu nợ, nhập kho… lên máy khác **ngay lập tức và đủ** — kể cả nhật ký tài chính và lịch sử nhập hàng, trước đây đôi khi phải sang hôm sau máy kia mới thấy.
- Cài lại app hoặc đăng nhập máy mới: dữ liệu về đầy đủ, không còn bảng bị thiếu.
- Trung tâm đồng bộ nói rõ "N cần đồng bộ" là gì, bảng nào lệch, và nút "Tự động sửa" sửa thật.

### 💰 Tài chính — số liệu đã đối chiếu bằng kịch bản 25 tình huống thật
- "Lãi sau chi phí" không còn trừ vốn sửa chữa 2 lần.
- Xuất Excel tài chính ra đúng số (trước bị ra chữ).
- Chốt quỹ mở nhanh hơn nhiều.
- Chủ shop duyệt giao máy chọn được ngay Tiền mặt / Chuyển khoản / Công nợ.

### 📊 Báo cáo
- **"Lãi theo tháng"** và **"Dịch vụ lãi nhất"** nay bấm mở được và có sẵn ngoài Trang chủ (THAO TÁC NHANH). Dịch vụ lãi nhất xem theo 7 / 30 / 90 ngày hoặc 1 năm.
- Bỏ khối "Phân khúc khách hàng" (không phù hợp tiệm sửa chữa, hay báo sai).

### 🤝 Công nợ
- **Thu / trả gộp ngay trong tab Nợ** — bấm vào người rồi "Thu/Trả gộp cả N khoản", không phải sang màn Công nợ đi tìm lại.

### 🏷️ Bảng giá
- Tìm kiếm dễ hơn: gõ từ khoá theo bất kỳ thứ tự, có dấu hay không dấu, dùng viết tắt quen tay (ip = iPhone, ss = Samsung, mh = màn hình, ek = ép kính, tp = thay pin). Ví dụ gõ "mh 12 ip" là ra "iPhone 12 · Màn hình".

### 🔧 Đơn sửa
- Bảo hành chỉ còn một dòng ghi chú: chọn nhanh KO BH / 1 / 3 / 6 / 12 tháng hoặc gõ tự do.
- Sửa điện thoại thiếu Model không còn làm mất tên khách.
- Vá lỗi thoát đột ngột / màn trắng khi đóng bảng nhập liệu.

### 🧹 Gọn hơn
- Gỡ các phần dành cho ngành khác (thời trang, thực phẩm…) và màn "Quản lý danh mục" không dùng — app tập trung cho tiệm điện thoại.

---

## Bản rút gọn — dán vào "What's new" (≤ 500 ký tự)

```
📱 Mở app nhanh hơn, tiết kiệm dữ liệu gấp nhiều lần.
🔄 Đồng bộ giữa các máy chắc hơn: yêu cầu duyệt giao hiện đúng, hết thông báo đôi, dữ liệu về đủ mọi máy.
💰 Số liệu tài chính đã đối chiếu 25 tình huống thật; lãi không trừ vốn 2 lần; chốt quỹ nhanh hơn.
📊 "Lãi theo tháng" và "Dịch vụ lãi nhất" ngay trên Trang chủ.
🤝 Thu / trả gộp ngay trong tab Nợ.
🏷️ Bảng giá tìm bằng viết tắt (ip, ss, mh, ek…).
🔧 Bảo hành 1 dòng ghi chú, vá lỗi thoát đột ngột.
```

---

## Việc cần làm khi upload
1. Android: `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (build 557 > 556).
2. iOS: `flutter build ipa --release` (min deployment 15.0).
3. Web: `flutter build web --release` + `firebase deploy --only hosting`.
4. Dán "Bản rút gọn" vào *What's new*.
