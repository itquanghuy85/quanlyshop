# UX Score Report

## Mục tiêu đánh giá
Báo cáo này đánh giá app như một sản phẩm thương mại đang phục vụ cửa hàng sửa chữa đông khách, nơi tốc độ thao tác, khả năng scan thông tin, độ ổn định tâm lý người dùng và tính đồng nhất giao diện quan trọng hơn sự "đẹp mắt" thuần túy.

## Kết luận nhanh
App có độ phủ nghiệp vụ rất mạnh, nhưng chất lượng UX/UI tổng thể mới ở mức vận hành được chứ chưa đạt mức sản phẩm thương mại cao cấp. Vấn đề lớn nhất không nằm ở thiếu tính năng, mà ở nợ đồng nhất, mật độ nhận thức quá cao và sự phân mảnh giữa các lớp giao diện cũ/mới.

## Chỉ số repo-level quan sát được
- `105` lần tự dựng `AppBar(...)` trong `lib/views`.
- `29` lần dùng `CustomAppBar` chuẩn hóa.
- `209` lần dùng trực tiếp `CircularProgressIndicator(...)`.
- `97` lần dùng `showDialog(...)`.
- `10` lần dùng `showModalBottomSheet(...)`.

Các số này cho thấy app đang nghiêng mạnh về screen-specific UI hơn là system-driven UI.

## Bảng điểm tổng

| Hạng mục | Điểm /10 | Severity | Priority | Nhận định ngắn |
|---|---:|---|---|---|
| Visual Design | 5.8 | Cao | P1 | Có nền design system nhưng bị phá vỡ bởi inline styling và nhiều phong cách song song. |
| UX Consistency | 4.6 | Rất cao | P0 | Cùng một app nhưng AppBar, dialog, spacing, màu và feedback vận hành không nói cùng một ngôn ngữ. |
| Repair Workflow | 6.4 | Cao | P1 | Nghiệp vụ sâu, đủ mạnh cho shop thật, nhưng form và detail screen vẫn nặng đầu khi thao tác nhanh. |
| Inventory Workflow | 5.9 | Cao | P1 | Quyền năng cao nhưng quá nhiều entry point và action cạnh tranh trong cùng một màn hình. |
| Customer Workflow | 6.6 | Trung bình | P2 | Khá thực dụng, nhưng thiếu một mô hình CRM thống nhất và scan-friendly. |
| Payment Workflow | 5.7 | Cao | P1 | Logic thanh toán tốt, nhưng UX chưa truyền được sự an tâm và tiến trình rõ ràng cho nhân viên. |
| Debt Workflow | 5.1 | Rất cao | P0 | Mật độ thông tin cao, khó scan, dễ gây mệt và nhầm khi cửa hàng đông khách. |
| Settings Workflow | 4.8 | Rất cao | P0 | Cài đặt phân mảnh thành nhiều màn hình “mini app”, thiếu thông tin kiến trúc điều hướng. |
| Information Architecture | 4.9 | Rất cao | P0 | Home quá tải, settings tản mạn, finance/debt có nhiều lớp thông tin nhưng thiếu nhấn cấp bậc. |
| Offline UX | 6.1 | Cao | P1 | Hạ tầng offline khá tốt, nhưng feedback cho người dùng chưa đủ rõ và còn phân mảnh. |
| Loading & Async UX | 4.7 | Rất cao | P0 | Lạm dụng spinner, thiếu skeleton và trạng thái trung gian mang tính định hướng. |
| Animation & Feeling | 5.0 | Trung bình | P2 | Một số chỗ có cảm giác hiện đại, nhưng tổng thể không đồng nhất nên cảm nhận độ mượt không bền. |
| Mobile Ergonomics | 5.3 | Cao | P1 | Nhiều action quan trọng đặt trên AppBar/top area, chưa tối ưu đủ cho thao tác một tay. |
| Scale Readiness | 5.4 | Cao | P1 | Tăng thêm module vẫn được, nhưng UX debt sẽ phình to nhanh nếu không chuẩn hóa mạnh. |

## Điểm tổng hợp
- **Tổng điểm hiện tại:** `5.5/10`
- **Mức sản phẩm:** trung bình khá về nghiệp vụ, trung bình về UX/UI, chưa đạt chuẩn “premium commercial operations app”.

## Severity Matrix

### P0 — Phải xử lý sớm
- Phân mảnh AppBar / dialog / loading / settings patterns.
- Home và Debt/Finance gây cognitive load quá cao.
- Async feedback không đủ rõ trong nhiều luồng quan trọng.

### P1 — Ảnh hưởng lớn đến hiệu suất thao tác
- Repair, Inventory, Payment workflow còn nhiều điểm ma sát.
- Mobile ergonomics chưa tối ưu cho one-hand + high-frequency use.
- Visual hierarchy chưa đủ sắc nét ở các màn hình dữ liệu dày.

### P2 — Cần xử lý để nâng app lên level hiện đại
- Animation/transition chưa có hệ thống.
- CRM/customer flow và reporting flow còn cảm giác ghép module.

### P3 — Tinh chỉnh sau cùng
- Microcopy, polish icon rhythm, visual delight, motion polish.

## Màn hình cần ưu tiên redesign hoặc tái cấu trúc mạnh
1. `home_view.dart` — cần tái kiến trúc dashboard và navigation model.
2. `debt_view.dart` — cần redesign toàn diện theo hướng scan-first, action-second.
3. `inventory_view.dart` — cần tách rõ browse, act, check, print, import thay vì dồn nhiều mode trên một mặt phẳng.
4. `shop_settings_view.dart` — cần gom nhóm và tái cấu trúc settings IA.
5. `finance_v2_view.dart` — cần phân tầng thông tin tốt hơn để không “đè” người dùng.

## Nhận định cuối
App này không yếu ở logic. App yếu ở chỗ giao diện chưa theo kịp độ phức tạp nghiệp vụ. Nếu không xử lý UX debt ngay, mỗi tính năng mới sẽ tiếp tục làm app khó dùng hơn, dù backend/service vẫn tốt.