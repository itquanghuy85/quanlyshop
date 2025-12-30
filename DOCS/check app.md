# Shop Off Flutter – Mindmap kiểm tra & rà soát toàn diện (5 Phase)

## PHASE 1 – Chống crash (BẮT BUỘC)
- Không force unwrap `!`
- Bọc `DateTime.parse`, `int.parse`, `double.parse`
- Try–catch cho mọi database operations
- Try–catch cho `await` trong UI (save/delete/update)
- Guard `shopId == null`
- Guard `FirebaseAuth.currentUser == null`
- StreamBuilder/FutureBuilder xử lý `hasError`
- Navigation có `mounted`

## PHASE 2 – Logic tiền & kho
- Check tồn kho trước khi bán
- Không bán máy chưa có IMEI
- Không quantity âm
- Chặn trả nợ vượt số nợ
- Validate trạng thái sửa
- Reload dữ liệu sau bán/sửa
- Một mã hàng dùng xuyên suốt
- Không tạo mã mới trong bán & sửa

## PHASE 3 – Ổn định dài hạn
- Database có `onUpgrade`
- Migration không silent-fail
- Chuẩn hóa parse tiền (1 util)
- Load locale từ SharedPreferences
- Lưu ảnh không dùng dấu phẩy
- Đồng bộ Firestore ↔ SQLite không trùng
- Tách rõ điện thoại vs phụ kiện

## PHASE 4 – UI/UX dùng ngoài tiệm
- Home hiển thị toàn bộ chức năng dạng nút
- Nút màu đậm, tương phản cao
- Không card mờ/màu nhạt
- Input gọn (font 12–14)
- Disable submit khi dữ liệu sai


## PHASE 5 – Test & phòng phá
- Unit test tiền/kho/IMEI
- Test bán/sửa/nhập kho
- Test logout/login/mất mạng
- Test user không có shopId
- Test dữ liệu rỗng
- Log các case bị chặn

## Nguyên tắc làm việc
- Làm theo từng phase
- Không sửa ngoài checklist
- Không refactor/đổi UI nếu không yêu cầu
- Xong phase nào báo phase đó
- Không hỏi lại trừ khi checklist mâu thuẫn

