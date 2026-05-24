# UX Problems

## Root Cause cấp hệ thống

### 1. App đang có ít nhất 3 ngôn ngữ giao diện cùng tồn tại
- Theme chuẩn hóa trong `AppTheme`.
- Hệ component riêng như `CustomAppBar`, `AppUIHelpers`.
- Một lớp legacy dùng inline colors, inline TextStyle, inline AppBar trực tiếp trong từng screen.

**Hệ quả thực tế**
- Người dùng không hình thành được muscle memory ổn định.
- Mỗi màn hình đem lại cảm giác như một module từ team khác nhau.
- App giảm độ chuyên nghiệp dù chức năng mạnh.

### 2. UI đang gánh quá nhiều logic vận hành
Các màn hình như `home_view.dart`, `repair_detail_view.dart`, `inventory_view.dart`, `create_repair_order_view.dart`, `create_sale_view.dart` cùng lúc xử lý dữ liệu, sync, permission, navigation, feedback.

**Hệ quả thực tế**
- Trạng thái UI khó đoán.
- Tín hiệu “đã lưu”, “đã sync”, “đang xử lý”, “đang chờ cloud” không luôn rõ ràng.
- Người dùng dễ mất niềm tin khi app chậm hoặc trạng thái đổi liên tục.

### 3. Quá phụ thuộc vào dialog
Repo hiện có `97` lần `showDialog(...)` nhưng chỉ `10` lần `showModalBottomSheet(...)`.

**Hệ quả thực tế**
- Trên mobile, dialog gây ngắt ngữ cảnh mạnh.
- Dialog liên tiếp tạo cảm giác “popup app”, không phải workflow liền mạch.
- Khi cửa hàng đông khách, dialog chồng dialog làm thao tác chậm và căng thẳng.

---

## Vấn đề theo nhóm

## A. Visual Design

### A1. AppBar không đồng nhất
**Bằng chứng**
- `home_view.dart` là trung tâm app nhưng nhiều màn hình khác dùng AppBar riêng kiểu khác nhau.
- `sales_return_list_view.dart` dùng AppBar đỏ trực tiếp.
- `notification_settings_view.dart` dùng gradient riêng và typography all-caps.
- `CustomAppBar` tồn tại nhưng mức dùng còn thấp so với số AppBar trực tiếp.

**Ảnh hưởng thực tế**
- Navigation identity yếu.
- Người dùng không cảm thấy đang ở trong một hệ thống thị giác nhất quán.
- Các module tài chính, kho, cài đặt, trả hàng có độ “chuyên nghiệp nhìn thấy được” khác nhau.

### A2. Visual density thiếu kiểm soát
- Một số màn hình mới theo token khá gọn.
- Một số màn hình cũ vừa chật vừa nhiều màu phụ vừa nhiều card, tạo cảm giác dày và mệt.
- `home_view.dart`, `debt_view.dart`, `finance_v2_view.dart` có nguy cơ bão hòa thông tin rất cao.

**Ảnh hưởng thực tế**
- Nhân viên khó scan nhanh khi có nhiều khách cùng lúc.
- Người dùng phải đọc nhiều hơn mức cần thiết.

### A3. Button hierarchy chưa rõ ràng
- Có màn hình dùng FilledButton rõ ràng.
- Có màn hình dùng TextButton / ElevatedButton / inline IconButton mà mức ưu tiên không nhất quán.
- Nút hành động chính và phụ đôi khi đứng ngang nhau mà không có chênh thị giác đủ lớn.

**Ảnh hưởng thực tế**
- Dễ bấm nhầm.
- Người mới khó xác định nút “đúng để đi tiếp”.

---

## B. UX Consistency

### B1. Loading behavior rời rạc
**Bằng chứng**
- `209` lần dùng trực tiếp `CircularProgressIndicator(...)`.
- Có loading screen đầu app rất đầu tư (`loading_intro_screen.dart`) nhưng phần lớn màn hình vận hành chỉ dùng spinner cơ bản.

**Root cause**
Không có loading language thống nhất theo loại tình huống.

**Ảnh hưởng**
- App cho cảm giác chất lượng không đều.
- Người dùng không phân biệt được: đang tải dữ liệu, đang lưu, đang sync, hay đang bị treo.

### B2. Sync feedback bị chia làm nhiều kiểu
- `PendingSyncIndicator`
- `SimpleSyncIndicator`
- SnackBar thành công/lỗi rải rác theo từng service/screen

**Ảnh hưởng**
- User không có một mental model chung về trạng thái offline/pending/error.
- Cùng một sự kiện sync nhưng mỗi nơi nói theo một cách khác nhau.

### B3. Dialog style chưa chuẩn hóa triệt để
- Có dialog đã bo góc đẹp và có icon.
- Có dialog vẫn rất utilitarian, gần như debug-tool style.
- Super admin dialogs và settings dialogs chưa cùng một chuẩn visual weight.

**Ảnh hưởng**
- Flow quản trị nhìn thiếu premium.
- Cảm giác tin cậy giảm ở các thao tác nhạy cảm như reset/xóa/sửa quyền.

---

## C. Workflow Problems

### C1. Home workflow quá tải
`home_view.dart` đang làm quá nhiều việc:
- dashboard
- notifications
- navigation hub
- sync reaction
- permissions
- stats
- quick actions
- multi-tab host

**Vấn đề UX**
- Đây là “siêu màn hình”, không còn là dashboard đơn thuần.
- Quá nhiều entry points cạnh tranh attention.
- Người dùng phải tìm thay vì thấy ngay.

**Ảnh hưởng thực tế**
- Tốc độ thao tác giảm ở ca bận.
- Đào tạo nhân viên mới lâu hơn.

### C2. Repair workflow mạnh nhưng nặng đầu
`create_repair_order_view.dart` và `repair_detail_view.dart` rất giàu nghiệp vụ, nhưng:
- nhiều field
- nhiều dịch vụ/đối tác/trạng thái/tài chính/ảnh/vị trí kho
- logic sync và permission xen vào trải nghiệm

**Ảnh hưởng thực tế**
- Tốt cho xử lý case phức tạp, nhưng không tối ưu cho intake nhanh 30-60 giây tại quầy.
- Nhân viên thiếu kinh nghiệm dễ bỏ sót hoặc nhập sai.

### C3. Inventory workflow quá nhiều mode trong một screen
`inventory_view.dart` vừa là:
- danh sách tồn
- tìm kiếm/lọc
- điều hướng nhập kho
- điều hướng bán hàng
- in tem
- kiểm kho
- chỉnh sửa
- xử lý linh kiện

**Ảnh hưởng thực tế**
- Không rõ đâu là mode hiện tại của người dùng.
- Màn hình nặng chức năng hơn là mạch công việc.
- Rủi ro click sai cao khi thao tác nhanh.

### C4. Debt workflow quá khó scan
`debt_view.dart` xử lý nhiều loại nợ và nhiều tab, nhưng cấu trúc nhận thức vẫn gần với “data dump” hơn là “operations console”.

**Ảnh hưởng thực tế**
- Người dùng phải suy nghĩ nhiều để biết ai nợ, nợ gì, quá hạn hay chưa, next action là gì.
- App chưa hỗ trợ đủ “triage” trong tình huống áp lực cao.

### C5. Settings workflow phân mảnh
`shop_settings_view.dart`, `notification_settings_view.dart`, `printer_settings_view.dart`, `label_settings_view.dart`, `hr_salary_settings_view.dart`, `work_schedule_settings_view.dart`, `dashboard_settings_view.dart` đều là screen riêng có ngôn ngữ khác nhau.

**Ảnh hưởng thực tế**
- Cài đặt không có kiến trúc thông tin thống nhất.
- Người dùng phải nhớ vị trí từng thiết lập thay vì suy luận tự nhiên.
- Scale lâu dài sẽ trở thành “bãi module cài đặt”.

---

## D. Information Architecture

### D1. Quá nhiều thứ muốn xuất hiện ở cấp đầu tiên
- Home chứa quá nhiều card/shortcut/tab.
- Finance/Debt chứa quá nhiều dạng số liệu ngang cấp.
- Settings chứa nhiều nhóm cấu hình nhưng thiếu grouping và summary.

### D2. Thiếu emphasis cho “next best action”
Nhiều màn hình hiển thị dữ liệu, nhưng không nói rõ hành động tiếp theo hợp lý nhất là gì.

**Ví dụ**
- Debt nên nhấn mạnh “cần thu ngay”, “đã quá hạn”, “nợ lớn”, “nợ mới phát sinh”.
- Inventory nên nhấn mạnh “sắp hết”, “đang pending”, “cần kiểm kho”, “hàng dead stock”.

---

## E. Offline / Async Problems

### E1. Hạ tầng offline tốt hơn UX offline
App có sync queue và local-first khá mạnh, nhưng feedback người dùng chưa tương xứng.

**Biểu hiện**
- Chưa có một ngôn ngữ thị giác chung cho: local saved, pending upload, retrying, failed sync, partial cloud state.
- Người dùng dễ hiểu sai rằng dữ liệu đã “xong hết” trong khi thực tế mới lưu local.

### E2. Spinner abuse
Spinner dùng quá rộng, nhưng spinner không trả lời 3 câu hỏi quan trọng:
1. Đang làm gì?
2. Mất bao lâu?
3. Tôi có cần làm gì không?

---

## F. Animation & Feeling

### F1. Chất lượng motion không đồng đều
- `loading_intro_screen.dart` có tham vọng premium.
- Nhưng phần lớn màn hình nghiệp vụ gần như không có motion system nhất quán, chỉ là transition mặc định + spinner.

**Ảnh hưởng**
- Cảm giác thương hiệu không bền.
- App có chỗ hiện đại, có chỗ giống công cụ nội bộ.

---

## G. Mobile Ergonomics

### G1. Top-heavy actions
- Nhiều action quan trọng nằm trên AppBar hoặc góc trên phải.
- Điều này không tối ưu cho một tay, đặc biệt trên máy màn hình lớn.

### G2. Form UX dài và cần focus management nhiều
- Create Repair và Create Sale có nhiều field liên tiếp.
- Người dùng phải di chuyển nhiều giữa keyboard, picker, dialog, selector.

### G3. FAB placement không có chiến lược nhất quán
- Có màn hình dùng FAB, có màn hình chuyển thành AppBar action, có màn hình giấu trong popup/menu.

**Ảnh hưởng**
- Giảm khả năng dự đoán thao tác.
- Người dùng phải “học lại” cách tạo mới ở từng module.

---

## Màn hình cần redesign toàn phần hoặc near-total redesign
1. `home_view.dart`
2. `debt_view.dart`
3. `inventory_view.dart`
4. `shop_settings_view.dart`
5. `finance_v2_view.dart`

## Màn hình cần cleanup mạnh nhưng chưa cần redesign toàn phần
1. `notification_settings_view.dart`
2. `printer_settings_view.dart`
3. `label_settings_view.dart`
4. `dashboard_settings_view.dart`
5. `sales_return_list_view.dart`
6. `super_admin_console_view.dart`

## Kết luận thẳng
App này không còn ở giai đoạn thiếu chức năng. App đang ở giai đoạn bị chính sự đầy đủ tính năng kéo UX xuống. Nếu không tái cấu trúc UX theo workflow và design system thật sự, mỗi tính năng mới sẽ làm sản phẩm khó dùng hơn chứ không mạnh hơn.