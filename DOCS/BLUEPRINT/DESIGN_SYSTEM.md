# DESIGN_SYSTEM

## DNA giao diện
- Tính cách visual: "xanh vận hành" (blue-first), rõ ràng, ưu tiên đọc nhanh và thao tác chính xác hơn trang trí.
- Cảm giác sử dụng: gọn, phản hồi tức thì, màu trạng thái rõ để nhân viên nhận diện nhanh trong môi trường đông thao tác.

## Colors
- Primary brand: #0068FF và biến thể #0084FF cho gradient AppBar.
- Nền chung: #F8FAFF; card trắng #FFFFFF; viền #E0E0E0.
- Semantic:
  - Success #388E3C
  - Warning #F57C00
  - Error #D32F2F
  - Info #0068FF

## Typography
- Font chính: Roboto.
- Cấp chữ:
  - AppBar/section title: 16-22, w600-w700.
  - Nội dung: 12-16, w400-w500.
  - Caption/badge: 10-12.

## Spacing / radius / elevation
- Radius: 8/12/16 là phổ biến.
- Touch target min: 44.
- Elevation nhẹ, nhiều card dùng border thay vì shadow sâu.

## Component style
- AppBar: gradient xanh, icon trắng, title đậm.
- Button:
  - Primary: xanh nền đặc, chữ trắng.
  - Outlined: viền xám/xanh nhẹ.
- Dialog: nền trắng, bo góc lớn hơn card, typography rõ.
- Bottom sheet: bo góc trên lớn, drag handle mặc định.
- List tile: mật độ dày vừa phải để tối ưu tốc độ scanning.

## Motion
- Motion token: 150ms (nhanh), 220ms (chuẩn), 350ms (chậm).
- Transition ưu tiên ngắn; loading indicator đặt gần vùng dữ liệu thay vì chặn toàn màn hình.

## Visual hierarchy
1. Trạng thái nghiệp vụ (màu + badge)
2. Dữ liệu chính (giá, tên khách, trạng thái đơn)
3. Hành động chính (CTA)
4. Hành động phụ trong menu/dialog
