# Loading And Async UX

## Chẩn đoán tổng quan
App có nền async/offline rất mạnh về kỹ thuật, nhưng ngôn ngữ giao tiếp với người dùng còn thiếu hệ thống. Đây là khoảng cách lớn giữa engineering quality và perceived quality.

## Quan sát chính
- Có `209` lần dùng trực tiếp `CircularProgressIndicator(...)` trong `lib/views`.
- Có loading intro screen khá đầu tư, nhưng phần lớn màn hình nghiệp vụ vẫn dùng spinner cơ bản.
- Sync feedback đang đi qua nhiều cơ chế: icon, badge, dialog, SnackBar, status riêng từng màn hình.

## Vấn đề cốt lõi
Người dùng không chỉ cần biết “app đang bận”. Họ cần biết:
1. App đang làm gì.
2. Dữ liệu đã an toàn chưa.
3. Có cần chờ không.
4. Có thể rời màn hình không.
5. Nếu lỗi thì phải làm gì tiếp.

---

## 1. Spinner abuse

### Hiện trạng
Spinner được dùng như giải pháp mặc định cho hầu hết trạng thái chờ.

### Vì sao đây là anti-pattern
Spinner chỉ biểu đạt “đang có việc”, nhưng không giải thích bản chất công việc.

### Hệ quả
- Người dùng không phân biệt được load vs save vs sync vs retry.
- Dễ sinh cảm giác treo app khi mạng chậm.
- Không tạo được cảm giác kiểm soát.

### Hướng sửa
- Skeleton cho danh sách và card.
- Inline progress cho button submit.
- Progress label có verb rõ: "Đang lưu đơn...", "Đang tải tồn kho...", "Đang đẩy dữ liệu lên cloud...".

---

## 2. Sync UX phân mảnh

### Components hiện có
- `PendingSyncIndicator`
- `SimpleSyncIndicator`
- các SnackBar sync thành công/lỗi rải rác

### Vấn đề
- Hai indicator cùng tồn tại nhưng không hoàn toàn cùng vai trò.
- Có nơi sync là background concern, có nơi lại bật dialog chi tiết.
- Cùng một app nhưng không có sync language thống nhất.

### Hệ quả
- User phải học trạng thái sync nhiều lần.
- Offline confidence thấp hơn mức kỹ thuật thực tế mà app đang sở hữu.

### Hướng sửa
Tạo `UnifiedSyncStatus` với 5 trạng thái chuẩn:
1. Local only
2. Pending upload
3. Syncing
4. Synced
5. Needs attention

Mỗi trạng thái có:
- màu
- icon
- text
- secondary explanation
- optional action

---

## 3. Save feedback chưa đủ phân tầng

### Hiện trạng
Nhiều luồng dùng SnackBar sau submit hoặc đổi trạng thái.

### Vấn đề
SnackBar phù hợp cho feedback nhẹ, nhưng không đủ cho hành động quan trọng như:
- tạo đơn sửa
- tạo đơn bán
- ghi nhận thanh toán
- chốt giao máy
- tạo khoản nợ

### Hướng sửa
- Hành động nhẹ: dùng SnackBar.
- Hành động quan trọng: dùng confirmation/result state rõ ràng.
- Hành động có offline queue: phải nói rõ “đã lưu trên máy, sẽ đồng bộ khi có mạng”.

---

## 4. Full-screen loading chưa được dùng có chiến lược

### Điểm tốt
`loading_intro_screen.dart` cho cảm giác thương hiệu và có đầu tư.

### Vấn đề
Khoảng cách chất lượng giữa loading intro và loading trong app quá lớn.

### Hướng sửa
Chỉ giữ full-screen loading cho:
- bootstrap sau đăng nhập
- chuyển workspace/shop lớn
- import/export/report cực nặng

Còn lại dùng inline hoặc section-based loading.

---

## 5. Dialog blocking quá nhiều

### Quan sát
Repo dùng `showDialog(...)` nhiều hơn bottom sheet rất rõ.

### Vấn đề async liên quan
- Dialog loading hoặc dialog confirm liên tục tạo cảm giác app “chặn người dùng” thay vì “hỗ trợ người dùng”.
- Khi lồng nhiều async events, dialog dễ làm flow gãy nhịp.

### Hướng sửa
- Bottom sheet cho pick/edit/quick actions.
- Dialog chỉ dùng cho destructive / secure / irreversible actions.
- Loading blocking chỉ khi thật sự cần atomic completion.

---

## 6. Empty / partial / error states chưa đủ trưởng thành

### Thiếu phổ biến
- empty state biết dạy người dùng làm gì tiếp
- partial load state
- retry section nhỏ thay vì reload cả màn hình
- explicit offline explanation ở từng module dữ liệu lớn

### Hướng sửa
Mỗi màn hình dữ liệu nên có 4 trạng thái chuẩn:
1. Loading
2. Empty
3. Partial/problematic
4. Ready

---

## 7. Priority fixes cho async UX

### P0
- Chuẩn hóa save/sync state language.
- Giảm spinner thuần, thay bằng progress copy rõ hành động.
- Quy định khi nào được dùng dialog blocking.

### P1
- Thêm skeleton cho list chính: repair, inventory, debt, finance.
- Tạo result state cho payment/repair completion.

### P2
- Motion polish cho async transitions.
- Retry affordances tinh tế hơn.

## Kết luận thẳng
Async của app hiện mạnh ở backend mindset nhưng yếu ở human-facing communication. Người dùng đang phải đoán quá nhiều về trạng thái dữ liệu. Đây là lý do app có thể ổn định về kỹ thuật nhưng vẫn bị cảm nhận là chưa “premium”.