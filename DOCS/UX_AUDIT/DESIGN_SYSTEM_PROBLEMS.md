# Design System Problems

## Chẩn đoán chính
Design system có tồn tại, nhưng chưa thực sự là “luật chơi bắt buộc” của toàn app. Nó đang là một lựa chọn tốt, không phải nền tảng không thể phá vỡ.

## 1. Inconsistency cấp nền tảng

### 1.1 AppBar fragmentation
- `AppTheme.appBarTheme` định nghĩa một chuẩn khá rõ.
- `CustomAppBar` định nghĩa thêm một chuẩn khác, compact hơn.
- Nhiều màn hình tự viết AppBar trực tiếp với màu, độ cao, chữ và action style riêng.

**Kết luận**
App đang có ít nhất 3 hệ AppBar. Đây là visual debt nghiêm trọng.

### 1.2 Color discipline chưa được enforcement
- Core brand dùng xanh rất rõ.
- Nhưng nhiều màn hình đưa thêm đỏ/cam/tím/xám theo kiểu screen-specific accent hơn là semantic-first.
- Một số màn hình như sales return và notification settings tạo cảm giác như sản phẩm con.

**Ảnh hưởng**
- Nhận diện thương hiệu bị loãng.
- Màu mất ý nghĩa vận hành khi vừa dùng để trang trí vừa dùng để chỉ trạng thái.

## 2. Typography issues
- Có token typography trong theme.
- Nhưng nhiều màn hình vẫn dùng `TextStyle(...)` inline.
- Chữ all-caps được dùng khá tùy hứng ở một số khu vực settings/admin.

**Vấn đề thực tế**
- Scanability giảm khi title/section/metadata không còn hierarchy nhất quán.
- Một số vùng dùng chữ đậm quá nhiều, làm mất điểm nhấn thật sự.

## 3. Spacing issues
- Token spacing tồn tại.
- Thực tế vẫn còn nhiều block tự padding/margin theo cảm tính từng màn hình.

**Biểu hiện**
- Màn hình thì thoáng, màn hình thì chật.
- Khoảng cách giữa card, filter, section header, button footer không theo một nhịp chung.

## 4. Border radius issues
- Radius chuẩn có tồn tại.
- Nhưng dialog/card/chip/list container vẫn dùng nhiều mức bo góc khác nhau theo từng file.

**Hệ quả**
- App thiếu visual rhythm.
- Người dùng thấy app “nhiều kiểu bo”, vô thức cảm nhận thiếu chỉn chu.

## 5. Shadow/elevation debt
- Theme card chuẩn khá phẳng và hiện đại.
- Nhưng nhiều màn hình cũ vẫn thêm elevation/shadow riêng theo logic cục bộ.

**Hệ quả**
- Độ sâu thị giác không nhất quán.
- Có card nhìn premium, có card nhìn như Material 2 cũ.

## 6. Card hierarchy chưa ổn
App dùng card rất nhiều, nhưng chưa có taxonomy rõ ràng:
- card summary
- card action
- card record
- card warning
- card configuration

Hiện tại nhiều card khác chức năng nhưng nhìn gần giống nhau, hoặc ngược lại, cùng chức năng nhưng nhìn quá khác nhau.

## 7. Button hierarchy chưa đủ mạnh
- Filled, outlined, text, icon button đều xuất hiện rộng.
- Nhưng chưa có quy ước nhất quán: đâu là primary CTA, đâu là destructive CTA, đâu là quick action.

**Kết quả**
- Người dùng không thể dựa hoàn toàn vào visual hierarchy để hành động.
- Phải đọc chữ nhiều hơn mức cần thiết.

## 8. Dialog style chưa thành design language
Dialog hiện là một kỹ thuật hiển thị, chưa phải một “ngôn ngữ hệ thống”.

**Thiếu**
- Header pattern thống nhất.
- Footer action order thống nhất.
- Variant rõ ràng: confirm / edit / pick / destructive / secure.

## 9. Icon consistency chưa hoàn chỉnh
- Phần lớn dùng Material icon, đây là điểm tốt.
- Nhưng icon treatment không ổn định: có nơi nền pastel đẹp, có nơi icon trần, có nơi size rất khác.

## 10. Navigation quality chưa đạt scale
- Navigation hiện thiên về “thêm route khi cần” hơn là “kiến trúc điều hướng tổng thể”.
- Home và Settings là hai nơi lộ rõ nhất vấn đề scale.

## Mức độ visual debt

| Hạng mục | Mức nợ | Ghi chú |
|---|---|---|
| AppBar | Rất cao | Nợ hệ thống, không phải lỗi lẻ tẻ |
| Typography | Cao | Có token nhưng chưa cưỡng chế dùng |
| Spacing | Cao | Chưa có rhythm thống nhất toàn app |
| Button hierarchy | Cao | Dễ gây mơ hồ hành động |
| Dialog language | Rất cao | Quá nhiều dialog nhưng không cùng kiểu |
| Card taxonomy | Cao | Thông tin và hành động chưa tách rõ |
| Color semantics | Trung bình cao | Brand mạnh nhưng semantic discipline chưa chặt |

## Kết luận thẳng
Design system hiện tại là nền tốt để cứu app, nhưng chưa đủ quyền lực để kiểm soát app. Nếu không chuyển sang chế độ system-first thật sự, mọi refactor UI sau này sẽ tiếp tục chỉ là “chỉnh từng màn hình” chứ không chữa tận gốc visual inconsistency.