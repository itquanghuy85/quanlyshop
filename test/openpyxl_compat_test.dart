import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/supplier_invoice_price_book_service.dart';

/// File .xlsx do **Python/openpyxl** tạo — đúng loại file ChatGPT Code
/// Interpreter sinh ra khi người dùng nhờ nó đọc ảnh hoá đơn. Cả tính năng
/// "Bảng giá từ hoá đơn NCC" dựng trên tiền đề đó, nên đọc được file kiểu này
/// là yêu cầu sống còn chứ không phải trường hợp biên.
///
/// Trước khi có [SupplierInvoicePriceBookService] vá lại, gói `excel` ném:
///   • "Null check operator used on a null value" — do openpyxl ghi Target
///     tuyệt đối `/xl/worksheets/sheet1.xml` trong workbook.xml.rels;
///   • "Bad state: No element" — do openpyxl ghi ô chuỗi RỖNG thành thẻ tự
///     đóng `<c t="inlineStr"/>`, còn `excel` gọi `findAllElements('t').first`
///     (parse.dart:630). Ô rỗng là chuyện bắt buộc xảy ra vì chính prompt của
///     app yêu cầu để trống cột "Giá thu khách".
void main() {
  final fixture = File('test/fixtures_openpyxl.xlsx');

  group('Tương thích file openpyxl (ChatGPT hay tạo)', () {
    test('đọc được, ra đúng số dòng', () {
      expect(fixture.existsSync(), isTrue, reason: 'thiếu fixture');
      final excel = SupplierInvoicePriceBookService.debugDecode(
        fixture.readAsBytesSync(),
      );
      expect(excel, isNotNull, reason: 'không giải mã được file openpyxl');

      final sheet = excel!.tables[SupplierInvoicePriceBookService.sheetDetail];
      expect(sheet, isNotNull, reason: 'thiếu sheet "Chi tiết nhập hàng"');

      final lines = SupplierInvoicePriceBookService.debugReadSheet(sheet!);
      expect(lines.length, 11, reason: 'file mẫu có 11 dòng dữ liệu');
    });

    test('ô "Giá thu khách" ĐỂ TRỐNG đọc ra null, không phải 0', () {
      final excel = SupplierInvoicePriceBookService.debugDecode(
        fixture.readAsBytesSync(),
      )!;
      final lines = SupplierInvoicePriceBookService.debugReadSheet(
        excel.tables[SupplierInvoicePriceBookService.sheetDetail]!,
      );
      expect(
        lines.every((l) => l.customerPrice == null),
        isTrue,
        reason: 'để trống phải ra null để app hiện "chưa thiết lập"',
      );
    });

    test('tiền dạng chuỗi có dấu chấm/phẩy/đ đều ra số nguyên đúng', () {
      final excel = SupplierInvoicePriceBookService.debugDecode(
        fixture.readAsBytesSync(),
      )!;
      final lines = SupplierInvoicePriceBookService.debugReadSheet(
        excel.tables[SupplierInvoicePriceBookService.sheetDetail]!,
      );
      int costOf(String name) =>
          lines.firstWhere((l) => l.name == name).cost;

      expect(costOf('Tiền dấu chấm'), 310000);
      expect(costOf('Tiền dấu phẩy'), 310000);
      expect(costOf('Tiền có chữ đ'), 310000);
      expect(costOf('Tiền triệu'), 1250000);
    });

    test('dòng hỏng vẫn đọc ra được để tầng trên còn đếm và báo', () {
      final excel = SupplierInvoicePriceBookService.debugDecode(
        fixture.readAsBytesSync(),
      )!;
      final lines = SupplierInvoicePriceBookService.debugReadSheet(
        excel.tables[SupplierInvoicePriceBookService.sheetDetail]!,
      );
      expect(lines.where((l) => l.name.trim().isEmpty).length, 1,
          reason: 'thiếu tên');
      expect(lines.where((l) => l.cost <= 0).length, 1,
          reason: 'thiếu giá vốn');
      expect(lines.where((l) => l.qty <= 0).length, 1,
          reason: 'số lượng không hợp lệ');
    });
  });

  group('Vá ô inline string rỗng', () {
    test('bỏ t="inlineStr" ở ô tự đóng, giữ nguyên ô có nội dung', () {
      const xml = '<row>'
          '<c r="A1" t="inlineStr"><is><t>Có chữ</t></is></c>'
          '<c r="B1" t="inlineStr"/>'
          '<c r="C1" t="n"><v>5</v></c>'
          '</row>';
      final out =
          SupplierInvoicePriceBookService.stripEmptyInlineStrCellsForTest(xml);

      expect(out, contains('<c r="A1" t="inlineStr"><is><t>Có chữ</t></is></c>'),
          reason: 'ô có nội dung phải giữ nguyên');
      expect(out, contains('<c r="B1"/>'),
          reason: 'ô rỗng phải bị bỏ t="inlineStr"');
      expect(out, contains('<c r="C1" t="n"><v>5</v></c>'),
          reason: 'ô số không bị đụng');
    });

    test('ô có cặp mở/đóng nhưng rỗng ruột cũng được vá', () {
      const xml = '<c r="D1" t="inlineStr"></c>';
      final out =
          SupplierInvoicePriceBookService.stripEmptyInlineStrCellsForTest(xml);
      expect(out.contains('inlineStr'), isFalse);
    });
  });
}
