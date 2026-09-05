import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/price_catalog_models.dart';
import '../utils/excel_export_helper.dart';
import '../utils/money_utils.dart';
import 'audit_service.dart';
import 'price_catalog_service.dart';
import 'user_service.dart';

/// Cầu nối "nhiều ảnh hoá đơn NCC → GPT → 1 file Excel → danh mục giá".
///
/// Khác [SupplierInvoiceService] (file 3 cột, chỉ CẬP NHẬT giá vốn phụ tùng
/// đã có trong Kho): service này nhận file Excel 4 sheet đầy đủ và dựng
/// **danh mục giá** riêng ([PriceCatalogService]) — tạo được mặt hàng mới,
/// giữ lịch sử theo từng hoá đơn, và có ô "Giá thu khách" cho người dùng.
///
/// Không đụng tồn kho, không đụng giá vốn thực tế của đơn hàng đã tạo.
class SupplierInvoicePriceBookService {
  SupplierInvoicePriceBookService._();

  // ── Tên sheet (phải khớp đúng với prompt GPT) ────────────────────────────
  static const String sheetDetail = 'Chi tiết nhập hàng';
  static const String sheetSummary = 'Tổng hợp giá vốn';
  static const String sheetErrors = 'Lỗi cần kiểm tra';
  static const String sheetGuide = 'Hướng dẫn nhập';

  // ── Cột ──────────────────────────────────────────────────────────────────
  static const String cDataType = 'Loại dữ liệu';
  static const String cGroup = 'Nhóm';
  static const String cBrand = 'Hãng';
  static const String cName = 'Tên mặt hàng';
  static const String cModels = 'Model tương thích';
  static const String cPartType = 'Loại linh kiện';
  static const String cSku = 'Mã hàng/SKU';
  static const String cUnit = 'Đơn vị tính';
  static const String cQty = 'Số lượng';
  static const String cUnitPrice = 'Đơn giá nhập';
  static const String cDiscount = 'Chiết khấu';
  static const String cTax = 'Thuế';
  static const String cLineTotal = 'Thành tiền';
  static const String cCost = 'Giá vốn';
  static const String cCustomerPrice = 'Giá thu khách';
  static const String cSupplier = 'Nhà cung cấp';
  static const String cInvoiceNo = 'Số hóa đơn';
  static const String cInvoiceDate = 'Ngày hóa đơn';
  static const String cNote = 'Ghi chú';
  static const String cImageSource = 'Nguồn ảnh';
  static const String cConfidence = 'Mức độ tin cậy';
  static const String cErrorNote = 'Lỗi cần kiểm tra';
  static const String cKey = '_khóa_import';

  /// Thứ tự cột chuẩn của sheet "Chi tiết nhập hàng" và "Tổng hợp giá vốn".
  static const List<String> headers = [
    cDataType,
    cGroup,
    cBrand,
    cName,
    cModels,
    cPartType,
    cSku,
    cUnit,
    cQty,
    cUnitPrice,
    cDiscount,
    cTax,
    cLineTotal,
    cCost,
    cCustomerPrice,
    cSupplier,
    cInvoiceNo,
    cInvoiceDate,
    cNote,
    cImageSource,
    cConfidence,
    cErrorNote,
    cKey,
  ];

  /// Cột BẮT BUỘC phải có thì mới đọc được sheet dữ liệu.
  static const List<String> requiredHeaders = [cName, cCost];

  // ── Prompt cho GPT ───────────────────────────────────────────────────────
  /// Câu lệnh người dùng copy, dán cho ChatGPT/Gemini/Claude kèm NHIỀU ảnh
  /// hoá đơn NCC. Yêu cầu AI tạo thẳng 1 file .xlsx đúng 4 sheet để tải về
  /// và nhập vào app.
  ///
  /// Viết dài và rất cụ thể là CỐ Ý: AI đọc hoá đơn hay tự ý gộp dòng, tự
  /// đoán giá bán, hoặc bịa mã hàng — mỗi ràng buộc dưới đây chặn một kiểu
  /// sai đã gặp thực tế.
  static const String gptPrompt = '''
Tôi gửi kèm các ảnh hoá đơn mua hàng từ nhà cung cấp phụ tùng điện thoại.
Hãy đọc TẤT CẢ các ảnh và tạo cho tôi MỘT file Excel (.xlsx) duy nhất để tôi tải về.

FILE PHẢI CÓ ĐÚNG 4 SHEET, đặt tên chính xác (có dấu):
1. "Chi tiết nhập hàng"
2. "Tổng hợp giá vốn"
3. "Lỗi cần kiểm tra"
4. "Hướng dẫn nhập"

SHEET 1 "Chi tiết nhập hàng" — mỗi dòng hàng của mỗi hoá đơn là 1 dòng, GIỮ NGUYÊN THEO TỪNG HOÁ ĐƠN, không gộp các hoá đơn lại.
Dòng 1 là tiêu đề, đúng thứ tự 23 cột sau:
Loại dữ liệu | Nhóm | Hãng | Tên mặt hàng | Model tương thích | Loại linh kiện | Mã hàng/SKU | Đơn vị tính | Số lượng | Đơn giá nhập | Chiết khấu | Thuế | Thành tiền | Giá vốn | Giá thu khách | Nhà cung cấp | Số hóa đơn | Ngày hóa đơn | Ghi chú | Nguồn ảnh | Mức độ tin cậy | Lỗi cần kiểm tra | _khóa_import

SHEET 2 "Tổng hợp giá vốn" — mỗi MẶT HÀNG duy nhất 1 dòng (gộp các dòng ở Sheet 1 có cùng _khóa_import), cùng 23 cột tiêu đề như trên.
Cột "Giá vốn" ghi giá vốn gần nhất. Cột "Số lượng" ghi tổng số lượng đã nhập.

SHEET 3 "Lỗi cần kiểm tra" — các dòng tôi cần tự kiểm tra lại, cùng 23 cột tiêu đề, ghi rõ lý do ở cột "Lỗi cần kiểm tra".

SHEET 4 "Hướng dẫn nhập" — 2 cột "Mục" và "Nội dung", giải thích ngắn từng cột và cách tôi kiểm tra file trước khi nhập.

ĐỊNH DẠNG FILE (làm sai là app không đọc được):
- Dòng 1 của mỗi sheet dữ liệu PHẢI là dòng tiêu đề, chữ y hệt danh sách trên, CÓ DẤU tiếng Việt, không thêm bớt khoảng trắng.
- Ô số (Số lượng, Đơn giá nhập, Chiết khấu, Thuế, Thành tiền, Giá vốn) phải là Ô SỐ THẬT trong Excel, không phải chữ.
- KHÔNG gộp ô (merge cells), KHÔNG đóng băng dòng, KHÔNG thêm màu/định dạng đặc biệt, KHÔNG thêm dòng trống xen giữa.
- Xuất bằng openpyxl hoặc tương đương đều được — app đọc được cả file do Python tạo.

QUY TẮC BẮT BUỘC:
- "Giá vốn" = đơn giá nhập thực tế cho MỘT đơn vị (đã trừ chiết khấu nếu hoá đơn ghi rõ). Chỉ ghi SỐ NGUYÊN, không ghi "đ", không dấu chấm/phẩy ngăn cách nghìn. Ví dụ: 310000.
- "Giá thu khách": ĐỂ TRỐNG HOÀN TOÀN. Tuyệt đối không tự đoán, không suy ra từ giá vốn. Tôi sẽ tự điền.
- "Ngày hóa đơn" dùng đúng định dạng YYYY-MM-DD (ví dụ 2026-08-30).
- "Số lượng" là số nguyên dương. Không đọc được thì ghi 1 và ghi lý do vào "Lỗi cần kiểm tra".
- KHÔNG GỘP hai mặt hàng khác model, khác chất lượng (Zin/OLED/LCD/dẻo/JAV…), hoặc khác mã hàng. Nếu phân vân thì tách riêng và ghi chú.
- Nếu MỘT dòng hoá đơn liệt kê NHIỀU model tương thích, giữ nguyên 1 dòng, liệt kê đủ các model vào cột "Model tương thích", và BẮT BUỘC ghi vào cột "Lỗi cần kiểm tra": "Nhiều model tương thích — cần kiểm tra". Không tự tách thành nhiều mặt hàng.
- Không chắc chắn thì ĐỂ TRỐNG ô đó và ghi lý do vào "Lỗi cần kiểm tra". Tuyệt đối không bịa số liệu, không bịa mã hàng/SKU.
- "Mức độ tin cậy": ghi Cao / Trung bình / Thấp cho từng dòng, theo mức độ bạn đọc rõ ảnh.
- "Nguồn ảnh": ghi tên hoặc số thứ tự ảnh mà dòng đó lấy ra (ví dụ "Ảnh 1").
- "Loại dữ liệu": ghi "Phụ tùng" cho linh kiện, "Dịch vụ" cho công/dịch vụ.
- KHÔNG tạo dòng trùng: trong Sheet 1, hai dòng chỉ được giống hệt nhau khi hoá đơn thật sự có 2 dòng như vậy.
- Không thêm dòng "Tổng cộng", không thêm cột nào khác, không gộp ô.

CÁCH TẠO "_khóa_import" (rất quan trọng — app dùng cột này để nhận diện và cập nhật mặt hàng, sai là tạo bản ghi trùng):
- Nếu hoá đơn CÓ mã hàng/SKU: _khóa_import = "pc|sku|" + mã hàng viết thường, bỏ dấu tiếng Việt, gộp nhiều khoảng trắng thành một.
- Nếu KHÔNG có mã hàng: _khóa_import = "pc|" + hãng + "|" + tên mặt hàng + "|" + model + "|" + loại linh kiện, tất cả viết thường, bỏ dấu tiếng Việt, gộp khoảng trắng, ngăn nhau bằng dấu "|". Ô nào trống thì để trống nhưng VẪN giữ đủ dấu "|".
- Cùng một mặt hàng ở nhiều hoá đơn khác nhau PHẢI có _khóa_import giống hệt nhau.
- Ví dụ: "Pin DLC Korsnow iPhone 11 Pro Max 4710mAh", hãng iPhone, không có SKU, loại linh kiện Pin
  → pc|iphone|pin dlc korsnow iphone 11 pro max 4710mah||pin

CUỐI CÙNG, hãy trả lời tôi bằng một báo cáo ngắn gồm: tổng số hoá đơn đã đọc, tổng số dòng ở Sheet 1, số mặt hàng ở Sheet 2, và danh sách các dòng cần tôi kiểm tra lại kèm lý do.
''';

  // ── Tạo file Excel mẫu ───────────────────────────────────────────────────
  /// File mẫu 4 sheet + dữ liệu ví dụ (hoá đơn HD014650) để người dùng đối
  /// chiếu, hoặc tự gõ tay khi không dùng AI.
  static Excel buildTemplateExcel() {
    final excel = Excel.createExcel();

    ExcelExportHelper.writeSheet(
      excel[sheetDetail],
      headers,
      _sampleDetailRows(),
    );
    ExcelExportHelper.writeSheet(
      excel[sheetSummary],
      headers,
      _sampleSummaryRows(),
    );
    ExcelExportHelper.writeSheet(
      excel[sheetErrors],
      headers,
      _sampleErrorRows(),
    );
    ExcelExportHelper.writeSheet(
      excel[sheetGuide],
      ['Mục', 'Nội dung'],
      _guideRows(),
    );

    final def = excel.getDefaultSheet();
    if (def != null &&
        def != sheetDetail &&
        def != sheetSummary &&
        def != sheetErrors &&
        def != sheetGuide) {
      excel.delete(def);
    }
    return excel;
  }

  static Future<void> exportTemplate(BuildContext context) async {
    final excel = buildTemplateExcel();
    await ExcelExportHelper.saveAndShare(
      excel,
      'Mau_BangGia_HoaDonNCC.xlsx',
      context,
    );
  }

  /// Dữ liệu mẫu = hoá đơn HD014650 (30/08/2026, tổng 3.120.000).
  /// Cột "Giá thu khách" cố ý ĐỂ TRỐNG — đúng quy tắc không tự đoán giá bán.
  static List<List<dynamic>> _sampleDetailRows() {
    const no = 'HD014650';
    const date = '2026-08-30';
    const sup = 'NCC mẫu';
    List<dynamic> row({
      required String brand,
      required String name,
      String models = '',
      required String partType,
      required int qty,
      required int price,
      String errorNote = '',
      String confidence = 'Cao',
    }) {
      final key = PriceCatalogService.buildImportKey(
        name: name,
        brand: brand,
        model: models,
        partType: partType,
      );
      return [
        'Phụ tùng',
        'Linh kiện điện thoại',
        brand,
        name,
        models,
        partType,
        '', // SKU — hoá đơn mẫu không có
        'Cái',
        qty,
        price,
        0,
        0,
        price * qty,
        price,
        '', // Giá thu khách — để trống
        sup,
        no,
        date,
        '',
        'Ảnh 1',
        confidence,
        errorNote,
        key,
      ];
    }

    return [
      row(
        brand: 'iPhone',
        name: 'Pin DLC Korsnow iPhone 11 Pro Max 4710mAh',
        partType: 'Pin',
        qty: 3,
        price: 310000,
      ),
      row(
        brand: 'Oppo',
        name: 'Màn hình Korsnow cho Oppo A58 4G',
        models:
            'Oppo A58 4G, A98 5G, A79 5G, Realme C55, Realme C67, Realme 11 5G, '
            'Realme 11X, Realme A1 2023, F23, Narzo N55, Narzo 60X, K11X',
        partType: 'Màn hình',
        qty: 1,
        price: 260000,
        errorNote: 'Nhiều model tương thích — cần kiểm tra',
      ),
      row(
        brand: 'iPhone',
        name: 'Phôi pin DLC Vtech Super 13 Pro Max',
        partType: 'Phôi pin',
        qty: 3,
        price: 270000,
      ),
      row(
        brand: 'Realme',
        name: 'Màn hình Korsnow Realme C53',
        models: 'Realme C53, C51, C60, Narzo N53',
        partType: 'Màn hình',
        qty: 1,
        price: 220000,
        errorNote: 'Nhiều model tương thích — cần kiểm tra',
      ),
      row(
        brand: 'iPhone',
        name: 'Màn hình iPhone 13 OLED dẻo JAV',
        partType: 'Màn hình',
        qty: 1,
        price: 900000,
      ),
    ];
  }

  /// Sheet tổng hợp của file mẫu — mỗi mặt hàng 1 dòng (hoá đơn mẫu không có
  /// mặt hàng lặp nên tổng hợp trùng chi tiết, chỉ khác là gộp theo khoá).
  static List<List<dynamic>> _sampleSummaryRows() => _sampleDetailRows();

  static List<List<dynamic>> _sampleErrorRows() => _sampleDetailRows()
      .where((r) => (r[21] as String).trim().isNotEmpty)
      .toList();

  static List<List<dynamic>> _guideRows() => [
        ['Sheet "Chi tiết nhập hàng"', 'Mỗi dòng hàng của mỗi hoá đơn 1 dòng. '
            'Đây là sheet app dùng để tính giá vốn.'],
        ['Sheet "Tổng hợp giá vốn"', 'Mỗi mặt hàng 1 dòng. NHẬP GIÁ THU KHÁCH '
            'Ở SHEET NÀY (cột "Giá thu khách").'],
        ['Sheet "Lỗi cần kiểm tra"', 'Các dòng AI không chắc — kiểm tra rồi '
            'sửa lại ở 2 sheet trên. Sheet này app KHÔNG nhập.'],
        [cName, 'Bắt buộc. Thiếu tên là dòng bị bỏ qua.'],
        [cCost, 'Bắt buộc. Giá nhập thực tế cho 1 đơn vị. Chỉ số nguyên, '
            'không "đ", không dấu chấm ngăn nghìn.'],
        [cCustomerPrice, 'Tuỳ chọn — giá báo cho khách. Để trống thì app hiện '
            '"Chưa thiết lập giá thu khách", KHÔNG lấy giá vốn thay thế.'],
        [cQty, 'Số nguyên dương. Dùng để tính giá vốn bình quân gia quyền.'],
        [cSku, 'Có mã hàng thì điền — app ưu tiên dùng mã hàng làm khoá, '
            'chính xác hơn tên.'],
        [cInvoiceDate, 'Định dạng YYYY-MM-DD, vd 2026-08-30. Dùng để xác định '
            'giá vốn GẦN NHẤT.'],
        [cKey, 'KHÔNG SỬA CỘT NÀY. App dùng để nhận diện mặt hàng — sửa sẽ '
            'tạo bản ghi trùng.'],
        ['Nhập lại cùng file', 'An toàn. Dòng hoá đơn đã ghi nhận sẽ bị bỏ '
            'qua, không cộng trùng vào giá bình quân.'],
        ['Cùng mặt hàng nhiều hoá đơn', 'App tự lưu giá vốn gần nhất, thấp '
            'nhất, cao nhất và bình quân gia quyền.'],
      ];

  // ── Đọc file Excel ───────────────────────────────────────────────────────
  /// Đọc giá trị 1 ô về dạng chuỗi.
  ///
  /// Đọc THEO KIỂU `CellValue` chứ không `toString()` thẳng: ô số thực trong
  /// Excel cho ra "310000.5", mà [MoneyUtils.parseCurrency] lại bỏ hết ký tự
  /// không phải số ⇒ thành 3100005 (sai gấp 10 lần).
  static String _cellText(List<Data?> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return '';
    final v = row[idx]?.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text?.trim() ?? '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is DateCellValue) {
      return '${v.year.toString().padLeft(4, '0')}-'
          '${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
    }
    if (v is DateTimeCellValue) {
      return '${v.year.toString().padLeft(4, '0')}-'
          '${v.month.toString().padLeft(2, '0')}-'
          '${v.day.toString().padLeft(2, '0')}';
    }
    return v.toString().trim();
  }

  /// Đọc 1 ô TIỀN về số nguyên. Xử lý được cả ô số thật lẫn ô chữ có "đ",
  /// dấu chấm/phẩy ngăn nghìn ("1.250.000 đ", "1,250,000").
  static int _cellMoney(List<Data?> row, int? idx) {
    if (idx == null || idx < 0 || idx >= row.length) return 0;
    final v = row[idx]?.value;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value.round();
    return _parseMoneyText(_cellText(row, idx));
  }

  /// Tiền dạng chữ → số nguyên.
  ///
  /// Phần thập phân bị **cắt bỏ đúng cách** (làm tròn) thay vì bị nối vào
  /// chuỗi số như [MoneyUtils.parseCurrency] — "310.000,5" phải ra 310001,
  /// không phải 3100005.
  static int _parseMoneyText(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return 0;
    // Bỏ ký hiệu tiền tệ và khoảng trắng.
    s = s.replaceAll(RegExp(r'[đĐdD]\b|VND|vnd|₫|\s'), '');
    final neg = s.startsWith('-');
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return 0;

    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    final sepIdx = lastDot > lastComma ? lastDot : lastComma;
    // Dấu phân cách CUỐI CÙNG chỉ là dấu thập phân khi sau nó có 1–2 chữ số
    // (vd "310.000,75"); có đúng 3 chữ số thì là dấu ngăn nghìn ("310.000").
    if (sepIdx >= 0) {
      final tail = s.substring(sepIdx + 1);
      if (tail.isNotEmpty && tail.length <= 2 && !tail.contains(RegExp('[.,]'))) {
        final intPart = s.substring(0, sepIdx).replaceAll(RegExp('[.,]'), '');
        final value = double.tryParse('${intPart.isEmpty ? '0' : intPart}.$tail');
        if (value != null) return (neg ? -value : value).round();
      }
    }
    final digits = s.replaceAll(RegExp('[^0-9]'), '');
    final v = int.tryParse(digits) ?? 0;
    return neg ? -v : v;
  }

  /// Chuẩn hoá ngày về YYYY-MM-DD. Nhận cả "30/08/2026" và "2026-08-30".
  /// Không hiểu được thì trả nguyên chuỗi (để người dùng còn thấy mà sửa).
  static String normalizeDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      return '${iso.group(1)}-${iso.group(2)!.padLeft(2, '0')}'
          '-${iso.group(3)!.padLeft(2, '0')}';
    }
    final dmy = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})').firstMatch(s);
    if (dmy != null) {
      return '${dmy.group(3)}-${dmy.group(2)!.padLeft(2, '0')}'
          '-${dmy.group(1)!.padLeft(2, '0')}';
    }
    return s;
  }

  /// Giải mã file .xlsx, tự sửa loại file do Python/openpyxl tạo (AI hay
  /// dùng) trước khi báo lỗi — xem [_normalizeOoxmlRelTargets].
  static Excel? _decode(Uint8List bytes, List<String> errors) {
    try {
      return Excel.decodeBytes(bytes);
    } catch (_) {
      try {
        return Excel.decodeBytes(_repairOpenpyxlWorkbook(bytes));
      } catch (e) {
        errors.add(
          'File Excel không đọc được: $e\n'
          'Hãy mở file bằng Google Sheets hoặc Excel rồi Lưu (Save As) lại '
          'thành .xlsx, sau đó nhập lại.',
        );
        return null;
      }
    }
  }

  /// Bản đồ "tiêu đề (thường, bỏ khoảng trắng thừa)" → chỉ số cột.
  static Map<String, int> _headerMap(List<Data?> headerRow) {
    final map = <String, int>{};
    for (var c = 0; c < headerRow.length; c++) {
      final raw = headerRow[c]?.value;
      final text = raw is TextCellValue
          ? (raw.value.text ?? '')
          : (raw?.toString() ?? '');
      final key = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (key.isNotEmpty && !map.containsKey(key)) map[key] = c;
    }
    return map;
  }

  static int? _col(Map<String, int> head, String name) =>
      head[name.trim().toLowerCase()];

  /// Đọc 1 sheet dữ liệu (chi tiết hoặc tổng hợp) thành các dòng hoá đơn.
  static List<InvoiceCostLine> _readSheet(
    Sheet sheet,
    List<String> errors, {
    required bool required,
  }) {
    final out = <InvoiceCostLine>[];
    if (sheet.maxRows < 2) return out;

    final head = _headerMap(sheet.row(0));
    final missing = requiredHeaders
        .where((h) => _col(head, h) == null)
        .toList();
    if (missing.isNotEmpty) {
      final msg = 'Sheet "${sheet.sheetName}": thiếu cột '
          '${missing.map((e) => '"$e"').join(', ')} — đã bỏ qua sheet này.';
      if (required) {
        errors.add(msg);
      }
      return out;
    }

    final iName = _col(head, cName);
    final iCost = _col(head, cCost);
    final iUnitPrice = _col(head, cUnitPrice);
    final iQty = _col(head, cQty);
    final iKey = _col(head, cKey);

    for (var r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      final name = _cellText(row, iName);
      final cost = _cellMoney(row, iCost);
      final unitPrice = _cellMoney(row, iUnitPrice);
      final rawQty = _cellText(row, iQty);

      // Dòng trống hoàn toàn → bỏ qua êm, không tính là lỗi.
      if (name.isEmpty && cost <= 0 && unitPrice <= 0 && rawQty.isEmpty) {
        continue;
      }

      final brand = _cellText(row, _col(head, cBrand));
      final model = _cellText(row, _col(head, cModels));
      final partType = _cellText(row, _col(head, cPartType));
      final sku = _cellText(row, _col(head, cSku));
      final customerRaw = _cellText(row, _col(head, cCustomerPrice));
      final customerPrice = customerRaw.trim().isEmpty
          ? null
          : _cellMoney(row, _col(head, cCustomerPrice));

      var key = iKey == null ? '' : _cellText(row, iKey).trim();
      if (key.isEmpty) {
        // AI quên cột khoá / người dùng xoá nhầm → tự dựng lại theo đúng
        // công thức, để dòng vẫn nhập được thay vì mất dữ liệu.
        key = PriceCatalogService.buildImportKey(
          name: name,
          sku: sku,
          brand: brand,
          model: model,
          partType: partType,
        );
      }

      out.add(InvoiceCostLine(
        dataType: _cellText(row, _col(head, cDataType)),
        group: _cellText(row, _col(head, cGroup)),
        brand: brand,
        name: name,
        compatibleModels: model,
        partType: partType,
        sku: sku,
        unit: _cellText(row, _col(head, cUnit)),
        qty: int.tryParse(rawQty.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0,
        unitPrice: unitPrice,
        discount: _cellMoney(row, _col(head, cDiscount)),
        tax: _cellMoney(row, _col(head, cTax)),
        lineTotal: _cellMoney(row, _col(head, cLineTotal)),
        // Thiếu cột/ô "Giá vốn" thì lấy "Đơn giá nhập" — cùng ý nghĩa.
        cost: cost > 0 ? cost : unitPrice,
        customerPrice: customerPrice,
        supplier: _cellText(row, _col(head, cSupplier)),
        invoiceNo: _cellText(row, _col(head, cInvoiceNo)),
        invoiceDate: normalizeDate(_cellText(row, _col(head, cInvoiceDate))),
        note: _cellText(row, _col(head, cNote)),
        imageSource: _cellText(row, _col(head, cImageSource)),
        confidence: _cellText(row, _col(head, cConfidence)),
        errorNote: _cellText(row, _col(head, cErrorNote)),
        importKey: key,
        sheetName: sheet.sheetName,
        rowNumber: r + 1,
      ));
    }
    return out;
  }

  /// Chỉ dùng cho unit test: chạy đúng bước giải mã file của app.
  @visibleForTesting
  static Excel? debugDecode(Uint8List bytes) => _decode(bytes, <String>[]);

  /// Chỉ dùng cho unit test: đọc 1 sheet mà không cần Firebase/SQLite
  /// (`preview` phải truy vấn danh mục hiện có nên không test thuần được).
  @visibleForTesting
  static List<InvoiceCostLine> debugReadSheet(
    Sheet sheet, {
    List<String>? errors,
  }) =>
      _readSheet(sheet, errors ?? <String>[], required: true);

  // ── Xem trước ────────────────────────────────────────────────────────────
  /// Đọc file + đối chiếu danh mục hiện có → [CatalogImportPreview].
  /// CHƯA ghi bất cứ gì vào DB.
  static Future<CatalogImportPreview> preview(Uint8List bytes) async {
    final errors = <String>[];
    final warnings = <String>[];

    final excel = _decode(bytes, errors);
    if (excel == null) return CatalogImportPreview(errors: errors);

    final tables = excel.tables;
    final detail = tables[sheetDetail];
    final summary = tables[sheetSummary];

    if (detail == null && summary == null) {
      // File không đúng mẫu → thử mọi sheet có đủ cột bắt buộc, để người
      // dùng đổi tên sheet vẫn nhập được thay vì bị chặn cứng.
      final fallback = <InvoiceCostLine>[];
      for (final s in tables.values) {
        if (s.sheetName == sheetGuide || s.sheetName == sheetErrors) continue;
        fallback.addAll(_readSheet(s, errors, required: false));
      }
      if (fallback.isEmpty) {
        errors.add(
          'Không tìm thấy sheet "$sheetDetail" hoặc "$sheetSummary", và không '
          'sheet nào có đủ 2 cột bắt buộc "$cName" + "$cCost". '
          'Hãy tải file mẫu và dùng đúng cấu trúc.',
        );
        return CatalogImportPreview(errors: errors);
      }
      warnings.add(
        'File không có sheet đúng tên chuẩn — đã đọc tạm theo các sheet có đủ '
        'cột bắt buộc. Nên dùng file mẫu để chắc chắn.',
      );
      return _build(fallback, const [], errors, warnings);
    }

    final detailLines = detail != null
        ? _readSheet(detail, errors, required: true)
        : const <InvoiceCostLine>[];
    final summaryLines = summary != null
        ? _readSheet(summary, errors, required: true)
        : const <InvoiceCostLine>[];

    if (detail == null) {
      warnings.add(
        'Không có sheet "$sheetDetail" — đã tính giá vốn từ sheet '
        '"$sheetSummary".',
      );
    }
    if (summary == null) {
      warnings.add(
        'Không có sheet "$sheetSummary" — Giá thu khách sẽ lấy từ sheet '
        '"$sheetDetail" (nếu có điền).',
      );
    }

    return _build(detailLines, summaryLines, errors, warnings);
  }

  /// Gộp các dòng hoá đơn theo `_khóa_import` thành mặt hàng + đếm thống kê.
  static Future<CatalogImportPreview> _build(
    List<InvoiceCostLine> detailLines,
    List<InvoiceCostLine> summaryLines,
    List<String> errors,
    List<String> warnings,
  ) async {
    // Giá thu khách ưu tiên lấy từ sheet "Tổng hợp giá vốn" — đó là nơi
    // hướng dẫn người dùng điền.
    final customerPriceByKey = <String, int>{};
    final summaryMetaByKey = <String, InvoiceCostLine>{};
    for (final l in summaryLines) {
      if (l.importKey.isEmpty) continue;
      summaryMetaByKey.putIfAbsent(l.importKey, () => l);
      final p = l.customerPrice;
      if (p != null && p > 0) customerPriceByKey[l.importKey] = p;
    }

    // Không có sheet chi tiết → dùng luôn sheet tổng hợp làm nguồn giá vốn.
    final sourceLines = detailLines.isNotEmpty ? detailLines : summaryLines;
    for (final l in detailLines) {
      final p = l.customerPrice;
      if (p != null && p > 0) {
        customerPriceByKey.putIfAbsent(l.importKey, () => p);
      }
    }

    var validRows = 0;
    var missingName = 0;
    var missingCost = 0;
    var invalidQty = 0;

    // khoá → các dòng lịch sử mới + thông tin mô tả mặt hàng
    final historyByKey = <String, List<CostHistoryEntry>>{};
    final metaByKey = <String, InvoiceCostLine>{};
    final reviewByKey = <String, String>{};
    // Vân tay đã dùng trong CHÍNH file này — 2 dòng giống hệt trong cùng file
    // là hợp lệ (hoá đơn có 2 dòng thật), nên được đánh số để không tự loại
    // nhau; trùng với lần nhập TRƯỚC mới là trùng thật.
    final fpSeenInFile = <String, int>{};

    for (final l in sourceLines) {
      if (l.name.trim().isEmpty) {
        missingName++;
        errors.add(
          'Sheet "${l.sheetName}" dòng ${l.rowNumber}: thiếu "$cName" — bỏ qua.',
        );
        continue;
      }
      if (l.cost <= 0) {
        missingCost++;
        errors.add(
          'Sheet "${l.sheetName}" dòng ${l.rowNumber}: thiếu/sai "$cCost" — '
          'bỏ qua.',
        );
        continue;
      }
      var qty = l.qty;
      if (qty <= 0) {
        invalidQty++;
        errors.add(
          'Sheet "${l.sheetName}" dòng ${l.rowNumber}: "$cQty" không hợp lệ '
          '(${l.qty}) — tạm tính là 1.',
        );
        qty = 1;
      }
      validRows++;

      final key = l.importKey;
      metaByKey.putIfAbsent(key, () => l);
      if (l.needsReview && !reviewByKey.containsKey(key)) {
        reviewByKey[key] = l.errorNote.trim().isNotEmpty
            ? l.errorNote.trim()
            : (l.hasMultipleModels
                ? 'Nhiều model tương thích — cần kiểm tra'
                : 'Mức độ tin cậy thấp — cần kiểm tra');
      }

      var fp = PriceCatalogService.lineFingerprint(
        importKey: key,
        invoiceNo: l.invoiceNo,
        invoiceDate: l.invoiceDate,
        unitCost: l.cost,
        qty: qty,
      );
      final n = (fpSeenInFile[fp] ?? 0) + 1;
      fpSeenInFile[fp] = n;
      if (n > 1) fp = '$fp#$n';

      historyByKey.putIfAbsent(key, () => []).add(CostHistoryEntry(
            fingerprint: fp,
            invoiceNo: l.invoiceNo,
            invoiceDate: l.invoiceDate,
            unitCost: l.cost,
            qty: qty,
            supplier: l.supplier,
          ));
    }

    final existing = await PriceCatalogService.keyedMap();
    final newItems = <PriceCatalogItem>[];
    final updatedItems = <PriceCatalogItem>[];
    var duplicateRows = 0;
    var emptyCustomerPrice = 0;
    var needsReview = 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in historyByKey.entries) {
      final key = entry.key;
      final meta = metaByKey[key]!;
      final summaryMeta = summaryMetaByKey[key];
      final prev = existing[key];
      final review = reviewByKey[key] ?? '';

      final base = prev ??
          PriceCatalogItem(
            importKey: key,
            itemName: meta.name,
            createdAt: now,
          );

      final merged = PriceCatalogService.mergeHistory(
        base.copyWith(
          // Thông tin mô tả: file mới ghi đè khi có, giữ giá trị cũ khi trống.
          itemName: meta.name.isNotEmpty ? meta.name : base.itemName,
          brand: meta.brand.isNotEmpty ? meta.brand : base.brand,
          model: meta.compatibleModels.isNotEmpty
              ? meta.compatibleModels
              : base.model,
          partType:
              meta.partType.isNotEmpty ? meta.partType : base.partType,
          sku: meta.sku.isNotEmpty ? meta.sku : base.sku,
          unit: meta.unit.isNotEmpty ? meta.unit : base.unit,
          note: (summaryMeta?.note ?? meta.note).isNotEmpty
              ? (summaryMeta?.note ?? meta.note)
              : base.note,
          confidence:
              meta.confidence.isNotEmpty ? meta.confidence : base.confidence,
          needsReview: review.isNotEmpty ? true : base.needsReview,
          reviewNote: review.isNotEmpty ? review : base.reviewNote,
          sourceType: 'supplier_invoice_excel',
          updatedAt: now,
        ),
        entry.value,
      );
      duplicateRows += merged.duplicates;

      // Giá thu khách: chỉ ghi đè khi file CÓ điền. File để trống ⇒ giữ
      // nguyên giá đã đặt trong app (không xoá công sức của chủ shop).
      final fromFile = customerPriceByKey[key];
      final item = merged.item.copyWith(
        customerPrice: fromFile ?? base.customerPrice,
      );

      if (item.customerPrice <= 0) emptyCustomerPrice++;
      if (item.needsReview) needsReview++;

      if (prev == null) {
        newItems.add(item);
      } else {
        updatedItems.add(item);
      }
    }

    return CatalogImportPreview(
      lines: sourceLines,
      newItems: newItems,
      updatedItems: updatedItems,
      existing: existing,
      validRows: validRows,
      duplicateRows: duplicateRows,
      missingNameRows: missingName,
      missingCostRows: missingCost,
      emptyCustomerPriceItems: emptyCustomerPrice,
      needsReviewItems: needsReview,
      invalidQtyRows: invalidQty,
      errors: errors,
      warnings: warnings,
    );
  }

  // ── Ghi vào danh mục ─────────────────────────────────────────────────────
  /// Ghi bản xem trước vào danh mục giá + ghi audit log.
  ///
  /// [policy] quyết định mặt hàng ĐÃ CÓ: cập nhật hay bỏ qua. Mặt hàng mới
  /// luôn được tạo.
  static Future<CatalogImportResult> commit(
    CatalogImportPreview preview, {
    CatalogExistingPolicy policy = CatalogExistingPolicy.update,
    String fileName = '',
  }) async {
    if (!await PriceCatalogService.canImport()) {
      return const CatalogImportResult(
        errors: ['Bạn không có quyền nhập bảng giá (cần quyền xem giá vốn).'],
      );
    }

    var created = 0, updated = 0, skipped = 0, failed = 0;
    final errors = <String>[];

    for (final item in preview.newItems) {
      final id = await PriceCatalogService.save(item);
      if (id != null) {
        created++;
      } else {
        failed++;
        errors.add('Không lưu được "${item.itemName}".');
      }
    }

    if (policy == CatalogExistingPolicy.skip) {
      skipped = preview.updatedItems.length;
    } else {
      for (final item in preview.updatedItems) {
        final id = await PriceCatalogService.save(item);
        if (id != null) {
          updated++;
        } else {
          failed++;
          errors.add('Không cập nhật được "${item.itemName}".');
        }
      }
    }

    try {
      final user = await UserService.getCurrentShopId();
      await AuditService.logAction(
        action: 'PRICE_CATALOG_IMPORT',
        entityType: 'price_catalog',
        entityId: user ?? 'unknown',
        summary: 'Nhập bảng giá từ hoá đơn NCC'
            '${fileName.isEmpty ? '' : ' ($fileName)'}: '
            'tạo mới $created, cập nhật $updated, bỏ qua $skipped, '
            'lỗi $failed. Dòng hợp lệ ${preview.validRows}, '
            'trùng ${preview.duplicateRows}, '
            'cần kiểm tra ${preview.needsReviewItems}.',
        payload: {
          'fileName': fileName,
          'policy': policy.name,
          'created': created,
          'updated': updated,
          'skipped': skipped,
          'failed': failed,
          'validRows': preview.validRows,
          'duplicateRows': preview.duplicateRows,
          'missingNameRows': preview.missingNameRows,
          'missingCostRows': preview.missingCostRows,
          'emptyCustomerPriceItems': preview.emptyCustomerPriceItems,
          'needsReviewItems': preview.needsReviewItems,
        },
      );
    } catch (e) {
      debugPrint('PriceCatalogImport audit: $e');
    }

    return CatalogImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      failed: failed,
      errors: errors,
    );
  }

  /// Vá lại file .xlsx do **Python/openpyxl** sinh ra để gói `excel` đọc được.
  ///
  /// Đây KHÔNG phải trường hợp biên: ChatGPT Code Interpreter dùng openpyxl,
  /// nên gần như mọi file người dùng nhờ AI tạo đều rơi vào đây. Cả hai lỗi
  /// dưới đây đều làm `Excel.decodeBytes` ném thẳng, không có cách bắt riêng.
  ///
  /// **Lỗi 1 — Target tuyệt đối.** openpyxl ghi
  /// `Target="/xl/worksheets/sheet1.xml"` trong `xl/_rels/workbook.xml.rels`,
  /// mà gói `excel` luôn tự ghép tiền tố `xl/` nên tìm sai đường dẫn ⇒
  /// *"Null check operator used on a null value"*.
  ///
  /// **Lỗi 2 — ô inline string RỖNG.** openpyxl ghi ô chuỗi rỗng thành thẻ tự
  /// đóng `<c r="M2" t="inlineStr"/>` (không có `<is>`, không có `<t>`), còn
  /// `excel` thì làm `node.findAllElements('t').first` ⇒ *"Bad state: No
  /// element"* (parse.dart:630). Ô rỗng là chuyện BẮT BUỘC XẢY RA với tính
  /// năng này — prompt của app yêu cầu để trống cột "Giá thu khách".
  /// Cách vá: bỏ thuộc tính `t="inlineStr"` ở đúng những ô không có `<t>`, để
  /// nhánh mặc định của gói xử lý (nhánh đó đã kiểm tra null đàng hoàng).
  static Uint8List _repairOpenpyxlWorkbook(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final patched = <String, List<int>>{};

      // Lỗi 1 — chỉ ở file rels của workbook.
      final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
      if (relsFile != null) {
        final xmlStr = utf8.decode(relsFile.content as List<int>);
        final fixed = xmlStr
            .replaceAll('Target="/xl/', 'Target="')
            .replaceAll('Target="/', 'Target="');
        if (fixed != xmlStr) {
          patched['xl/_rels/workbook.xml.rels'] = utf8.encode(fixed);
        }
      }

      // Lỗi 2 — mọi worksheet.
      for (final f in archive.files) {
        if (!f.name.startsWith('xl/worksheets/') ||
            !f.name.endsWith('.xml')) {
          continue;
        }
        final xmlStr = utf8.decode(f.content as List<int>);
        final fixed = _stripEmptyInlineStrCells(xmlStr);
        if (fixed != xmlStr) patched[f.name] = utf8.encode(fixed);
      }

      if (patched.isEmpty) return bytes;

      final newArchive = Archive();
      for (final f in archive.files) {
        final data = patched[f.name];
        if (data != null) {
          newArchive.addFile(ArchiveFile(f.name, data.length, data));
        } else {
          newArchive.addFile(f);
        }
      }
      final out = ZipEncoder().encode(newArchive);
      return out != null ? Uint8List.fromList(out) : bytes;
    } catch (_) {
      return bytes;
    }
  }

  /// Bỏ `t="inlineStr"` khỏi các ô KHÔNG có `<t>` (ô chuỗi rỗng). Giữ nguyên
  /// mọi ô inline string có nội dung thật.
  @visibleForTesting
  static String stripEmptyInlineStrCellsForTest(String xml) =>
      _stripEmptyInlineStrCells(xml);

  static String _stripEmptyInlineStrCells(String xml) {
    // Dạng 1: thẻ tự đóng — `<c r="M2" t="inlineStr"/>`
    var out = xml.replaceAllMapped(
      RegExp(r'<c\b([^>]*?)\st="inlineStr"([^>]*?)/>'),
      (m) => '<c${m.group(1)}${m.group(2)}/>',
    );
    // Dạng 2: có cặp đóng/mở nhưng bên trong không hề có `<t`
    out = out.replaceAllMapped(
      RegExp(r'<c\b([^>]*?)\st="inlineStr"([^>]*?)>(.*?)</c>', dotAll: true),
      (m) {
        final inner = m.group(3) ?? '';
        if (inner.contains('<t')) return m.group(0)!;
        return '<c${m.group(1)}${m.group(2)}>$inner</c>';
      },
    );
    return out;
  }
}
