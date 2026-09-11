import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/finance_v2/finance_v2_excel_export.dart';

void main() {
  test('numeric Excel cells stay numbers with #,##0 format after round-trip',
      () {
    final excel = xl.Excel.createExcel();
    final sheet = excel['T'];
    final cell = sheet.cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    cell.value = xl.IntCellValue(1234567);
    cell.cellStyle = FinanceV2ExcelExport.numericStyle(xl.CellStyle());

    final bytes = excel.save()!;
    final back = xl.Excel.decodeBytes(bytes);
    final c = back['T'].cell(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
    );
    expect(c.value, isA<xl.IntCellValue>());
    expect((c.value as xl.IntCellValue).value, 1234567);
    expect(c.cellStyle?.numberFormat.formatCode, '#,##0');
  });
}
