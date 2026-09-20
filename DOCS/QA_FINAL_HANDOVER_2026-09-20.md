# BÁO CÁO BÀN GIAO — Kiểm thử toàn app & sửa lỗi (19–20/09/2026)

Viết cho: chủ shop / người quản lý app (không cần đọc code). Chi tiết kỹ thuật nằm ở các file `docs/QA_*.md`.

## 1. Kết quả tóm tắt

| | Số lượng |
|---|---|
| Lỗi tìm được (tất cả mức) | **39** |
| Đã sửa và kiểm tra lại trên 2 máy thật | **19** — trong đó **6/6 lỗi NGHIÊM TRỌNG (HIGH)** và 11/14 lỗi VỪA (MEDIUM) |
| Còn mở | **20** — 3 VỪA (MEDIUM), 12 NHẸ (LOW), 5 ghi chú kỹ thuật (code thừa) |
| Lỗi CRITICAL | 0 |
| Test case đã chạy có bằng chứng | **149** mục trên 2 máy thật / giả lập rules / DB (6 đợt) + **725 test tự động** (0 lỗi) |
| Kiểm tra code tự động (`flutter analyze`) | 0 lỗi |

Bản build: **Android 3.7.1 (build 560)** — đã ký bằng khoá phát hành của shop. **iOS chưa build được** (máy đang dùng là Windows; cần máy Mac có Xcode — xem mục 5).

## 2. Những gì đã sửa (theo nhóm, ngôn ngữ dễ hiểu)

### Mất mạng / đồng bộ giữa các máy (gốc của phần lớn lỗi)
- **Trước:** mất mạng thì bán hàng, tạo đơn sửa, nhập kho… bị treo hoặc báo lỗi; máy thứ hai không thấy tồn kho / công nợ mới cho tới khi mở lại app.
- **Sau:** mọi thao tác ghi lên cloud đi qua **một chính sách chung**: có mạng thì ghi và báo cho máy khác kéo về ngay; không có mạng thì **lưu trên máy trước, tự đẩy lên khi có mạng** (không treo, không mất). Máy khác nhận thay đổi trong vài giây (đã đo nhiều lần: 2–15 giây), kể cả khi máy đó đang khoá màn hình.
- Sửa thêm các lỗi ăn theo: hàng đợi đồng bộ kẹt vĩnh viễn với nút "Lỗi đồng bộ" (NEW-06), trả nợ NCC không sang máy khác (NEW-04), chốt quỹ không sang máy khác (NEW-10), **miễn nợ không bao giờ lên cloud** — nợ đã miễn có thể "sống lại" (NEW-08).

### Bán hàng
- Bán khi mất mạng **không còn cho bán vượt tồn** (trước đây tồn có thể âm −102) — ô số lượng tự chặn theo tồn, và có hàng rào thứ hai khi lưu (NEW-05).
- Xoá đơn / trả hàng: kho và phiếu thu hoàn đúng, máy khác nhận đúng.

### Sửa chữa
- Tạo đơn khi mất mạng không treo; số điện thoại được kiểm tra hợp lệ (BUG-02, BUG-03).
- Linh kiện đã dùng trong đơn được ghi kèm mã cloud → xoá đơn / đổi linh kiện **hoàn kho đúng món trên mọi máy** (BUG-07).
- **Sửa giá đơn đã giao** giờ tự tạo khoản chênh lệch: tăng giá → khách còn nợ thêm; giảm giá → shop nợ lại khách; sửa nhiều lần / sửa về giá cũ không tạo nợ trùng (NEW-02).

### Công nợ & Tài chính
- Phiếu thu/chi hiện ngay trên tab Tài chính không cần mở lại app (BUG-06).
- Hoàn tiền trả hàng hiển thị nhất quán giữa tab Tiền và Sổ quỹ (BUG-09).
- Thu gộp nhiều khoản, miễn nợ, chốt quỹ ngày → chặn bán: đều đã kiểm tra trên 2 máy.

### Khác
- Thông báo (snackbar) không còn treo che nút (BUG-08); bỏ 2 bảng ghi thừa trên cloud (D-03); bảng `payment_intents` tạo đúng từ đầu (L-01).

## 3. Lỗi còn mở (cần bạn quyết định có sửa tiếp hay không)

### Mức VỪA (MEDIUM) — nên sửa trong đợt sau
| Mã | Vấn đề | Ảnh hưởng thực tế | Đề xuất |
|---|---|---|---|
| **NEW-09** | Nếu điện thoại **tắt app đúng lúc** đang lưu đơn bán (cửa sổ ~1 giây), đơn và tồn kho được ghi nhưng **phiếu thu không được tạo** → tab Tiền thiếu số tiền đó | Hiếm (cần hệ điều hành giết app đúng khoảnh khắc). Khi xảy ra, tiền vào bị thiếu âm thầm; có thể phát hiện bằng Đối soát | Ghi phiếu thu cùng lúc với đơn trên cloud, hoặc thêm bước tự đối chiếu khi mở app |
| **NEW-07** | Chủ shop **không có công tắc** để bật/tắt quyền xem **giá vốn** cho từng nhân viên trong màn phân quyền (công tắc bị thiếu; màn cũ có công tắc thì không còn đường vào) | Không thể thu hồi quyền xem giá vốn bằng giao diện | Thêm lại công tắc "GIÁ VỐN SẢN PHẨM" vào sheet phân quyền |
| **D-08** | Còn 7 chỗ trong app ghi thẳng lên cloud, chưa đi qua chính sách chung (sửa tên/SĐT trên đơn, hoàn tồn khi xoá đơn bán, nhập linh kiện, xoá phiếu chi, cập nhật linh kiện sau đổi PT) | Khi mất mạng các thao tác này có thể treo; máy khác nhận chậm hơn | Bọc 7 chỗ bằng chính sách chung (như đã làm với chốt quỹ), ~30 phút + test lại |

### Mức NHẸ (LOW) — không ảnh hưởng tiền/tồn, có thể để sau
BUG-10 (nợ có 2 tên trạng thái ACTIVE/UNPAID), L-02 (khoá trùng bảng chốt quỹ), L-03 (nợ không có shopId lọt danh sách), L-04 (đầu trang Kho đếm sai, sản phẩm CUSAC trùng tên), L-05/L-07 (đăng xuất rơi về chế độ offline không hỏi PIN / xoá dữ liệu máy nối bằng "Tải dữ liệu"), L-06 (thiếu rules cho Storage), **L-08 (phiếu kiểm kho chỉ lưu trên máy, không sang máy khác)**, L-09 (đẩy nợ lặp lại sau mỗi lần thanh toán — thừa write, không sai số), NEW-01 (1/2 lần máy B khoá màn hình lâu nhận bản cũ tới khi bấm đồng bộ), NEW-03 (ô Tên/SĐT ngược thứ tự giữa 2 màn tạo đơn), D-07 (màn Đơn đặt hàng NCC chỉ vào được qua Nhắc việc).

### Ghi chú kỹ thuật (INFO): 5 mục code không còn dùng (D-01/02/04/05/06) — dọn khi rảnh.

## 4. Rủi ro còn lại cần biết
1. **Kill app đúng lúc lưu đơn bán** (NEW-09) — hiếm nhưng làm thiếu phiếu thu; nếu thấy tab Tiền lệch so với đơn, kiểm tra Đối soát.
2. **7 chỗ ghi thẳng cloud** (D-08) — mất mạng lúc dùng các thao tác đó có thể treo vài chục giây tới khi có mạng lại (không mất dữ liệu trên máy).
3. **Chưa test được:** đổi wifi ↔ 4G giữa chừng (máy test không có SIM), in máy in vật lý, chặn quyền ở tầng rules với tài khoản nhân viên (giao diện không có thao tác bị cấm), stress nhiều máy cùng lúc.
4. **Tín hiệu đồng bộ** ghi thêm ~1 doc nhỏ mỗi lượt ghi cloud (gộp 1,5 giây) — tăng nhẹ số lượt ghi Firestore.
5. **Dữ liệu test còn để lại trên shop M (m@m.com):** ngày 20/09 đã chốt quỹ (dùng "Sửa chốt quỹ" nếu cần bán tiếp trong ngày), một số đơn/nợ tên QA…/TÉT… — **không đụng shop thật**.

## 5. File build & cách đăng tải (bạn tự làm bằng tài khoản của bạn)

### Android — đã build xong, đã ký
| File | Đường dẫn | Dùng cho |
|---|---|---|
| **App Bundle (khuyên dùng cho Google Play)** | `build/app/outputs/bundle/release/app-release.aab` (≈84 MB) | Google Play Console |
| APK (cài trực tiếp / gửi tester) | `build/app/outputs/flutter-apk/app-release.apk` (≈125 MB, gộp mọi kiến trúc CPU) | Cài tay / kênh nội bộ |

Phiên bản trong file: **3.7.1, versionCode 560** (bản trước trên Play là 3.7.0 / 559). Chữ ký: khoá phát hành trong `android/key.properties` (CN=huy, O=huluca).

Các bước đăng lên Google Play (rút gọn):
1. Vào **Google Play Console → ứng dụng Quản Lý Shop → Sản xuất (Production) → Tạo bản phát hành mới**.
2. Kéo file **`app-release.aab`** vào ô tải lên; Console sẽ tự nhận 3.7.1 (560).
3. Dán ghi chú phát hành (gợi ý): *"Sửa lỗi dùng app khi mất mạng; đồng bộ nhanh giữa các máy; chặn bán vượt tồn; sửa giá đơn sửa đã giao tự ghi nợ chênh lệch; nhiều sửa lỗi công nợ/tài chính."*
4. Lưu → Xem lại bản phát hành → **Bắt đầu triển khai**. (Nếu muốn an toàn: phát hành theo tỷ lệ 20% vài ngày rồi tăng dần.)

### iOS — CHƯA BUILD ĐƯỢC (bị chặn bởi môi trường)
Project có cấu hình iOS (`ios/Runner.xcworkspace`), nhưng bản release iOS **chỉ build được trên macOS có Xcode**; máy hiện tại là Windows nên không tạo được file `.ipa`. Trên máy Mac, chạy:
```
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
```
File ra ở `build/ios/ipa/*.ipa`; mở **Xcode → Window → Organizer** hoặc dùng app **Transporter** để tải lên App Store Connect, rồi tạo bản mới 3.7.1 (560) trong App Store Connect → TestFlight / Gửi xét duyệt. Nếu muốn, có thể làm bước này ở lần bàn giao sau khi có máy Mac.

## 6. Tài liệu kèm theo
- `docs/QA_BUG_REPORT.md` — bảng toàn bộ lỗi, trạng thái, file đã sửa, bằng chứng.
- `docs/QA_TEST_EXECUTION.md` — nhật ký từng test case 6 đợt (giờ, máy, SQLite, log).
- `docs/QA_OFFLINE_SYNC_AUDIT.md` — chính sách ghi cloud chung & tín hiệu đồng bộ.
- `docs/QA_FINANCE_RECONCILIATION.md` — đối chiếu tài chính.
- `docs/QA_FULL_TEST_PLAN.md`, `docs/FULL_TEST_PLAN_2026-09-19.md`, `docs/FULL_TEST_REPORT_2026-09-19.md` — kế hoạch & báo cáo đợt đầu.
- Commit chính: `385b814c` (audit) → `fbe97736` (nền tảng) → `9f50fe02` → `5be09f1a` (NEW-02) → `9955ade7` (NEW-05) → `7d9ae0d1` (NEW-06) → `568c1214` (NEW-08) → `36575a41` (NEW-10) → bản release 3.7.1+560.
