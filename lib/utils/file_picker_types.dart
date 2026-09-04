import 'package:file_selector/file_selector.dart';

/// Bộ lọc loại file dùng chung cho MỌI chỗ gọi `openFile` trong app.
///
/// ⚠️ VÌ SAO PHẢI CÓ FILE NÀY — lỗi iOS đã gặp thật:
/// `file_selector_ios` **ném `ArgumentError`** nếu `XTypeGroup` không có
/// `uniformTypeIdentifiers`:
///
/// ```dart
/// // file_selector_ios/lib/file_selector_ios.dart
/// if (typeGroup.uniformTypeIdentifiers?.isEmpty ?? true) {
///   throw ArgumentError('The provided type group $typeGroup should either '
///       'allow all files, or have a non-empty "uniformTypeIdentifiers"');
/// }
/// ```
///
/// Khai báo kiểu `XTypeGroup(label: 'Excel', extensions: ['xlsx'])` chạy tốt
/// trên Android/Windows nhưng trên iOS thì `openFile()` ném ngay lập tức —
/// người dùng bấm nút và **KHÔNG có gì xảy ra** (ngoại lệ rơi vào khoảng
/// async, không ai bắt, không hiện lỗi). Đây đúng là triệu chứng "bấm import
/// Excel không được" trên iOS.
///
/// iOS lọc file theo **UTI**, không theo đuôi file. Nên mọi nhóm ở đây đều
/// khai báo đủ 3 thứ: `extensions` (Android/Windows), `uniformTypeIdentifiers`
/// (iOS/macOS) và `mimeTypes` (web/Linux).
///
/// **Luôn dùng hằng trong file này thay vì tự viết `XTypeGroup` tại chỗ.**
class FilePickerTypes {
  FilePickerTypes._();

  /// UTI của .xlsx (Excel 2007 trở lên).
  static const String utiXlsx = 'org.openxmlformats.spreadsheetml.sheet';

  /// UTI của .xls (Excel 97–2003).
  static const String utiXls = 'com.microsoft.excel.xls';

  static const String mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const String mimeXls = 'application/vnd.ms-excel';

  /// Chỉ nhận .xlsx — dùng cho các luồng nhập Excel của app (bảng giá, kho
  /// phụ tùng, nhập/xuất dữ liệu, hoá đơn NCC).
  static const XTypeGroup excel = XTypeGroup(
    label: 'Excel (.xlsx)',
    extensions: ['xlsx'],
    uniformTypeIdentifiers: [utiXlsx],
    mimeTypes: [mimeXlsx],
  );

  /// Nhận cả .xlsx lẫn .xls — dùng cho file xuất từ hệ thống ngoài (KiotViet)
  /// vì bản cũ vẫn xuất .xls.
  static const XTypeGroup excelWithLegacy = XTypeGroup(
    label: 'Excel (.xlsx, .xls)',
    extensions: ['xlsx', 'xls'],
    uniformTypeIdentifiers: [utiXlsx, utiXls],
    mimeTypes: [mimeXlsx, mimeXls],
  );

  /// File sao lưu `.db`.
  ///
  /// iOS KHÔNG có UTI riêng cho đuôi `.db` tự đặt, nên buộc phải mở rộng ra
  /// `public.data` (mọi loại file) — nếu khai một UTI không tồn tại thì trình
  /// chọn file sẽ làm mờ hết, không chọn được gì. Các nền tảng khác vẫn lọc
  /// đúng theo `extensions`; app tự kiểm tra tính hợp lệ sau khi đọc file.
  static const XTypeGroup database = XTypeGroup(
    label: 'Database (.db)',
    extensions: ['db'],
    uniformTypeIdentifiers: ['public.data'],
    mimeTypes: ['application/octet-stream'],
  );
}
