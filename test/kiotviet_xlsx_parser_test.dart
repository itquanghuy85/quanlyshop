import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

// ─── Inline copy of parser (must match service exactly) ───────────────────────

List<List<String>>? kvParseXlsx(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0xD0 && bytes[1] == 0xCF &&
      bytes[2] == 0x11 && bytes[3] == 0xE0) {
    throw Exception('File .xls cũ không được hỗ trợ');
  }
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw Exception('Không phải file Excel .xlsx');
  }

  final archive = ZipDecoder().decodeBytes(bytes);

  final sharedStrings = <String>[];
  final ssFile = archive.findFile('xl/sharedStrings.xml');
  if (ssFile != null) {
    ssFile.decompress();
    final doc = XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
    for (final si in doc.findAllElements('si')) {
      final buf = StringBuffer();
      for (final t in si.findAllElements('t')) {
        final parent = t.parentElement;
        if (parent == null || parent.localName != 'rPh') buf.write(t.innerText);
      }
      sharedStrings.add(buf.toString());
    }
  }

  String sheetPath = 'xl/worksheets/sheet1.xml';
  final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
  if (relsFile != null) {
    relsFile.decompress();
    final doc = XmlDocument.parse(utf8.decode(relsFile.content as List<int>));
    for (final rel in doc.findAllElements('Relationship')) {
      final type = rel.getAttribute('Type') ?? '';
      if (type.endsWith('/worksheet')) {
        final target = rel.getAttribute('Target') ?? '';
        if (target.isNotEmpty) {
          sheetPath = target.startsWith('xl/') ? target : 'xl/$target';
        }
        break;
      }
    }
  }

  final sheetFile = archive.findFile(sheetPath);
  if (sheetFile == null) return null;

  sheetFile.decompress();
  final doc = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));

  final rows = <List<String>>[];
  for (final rowEl in doc.findAllElements('row')) {
    final cells = <int, String>{};
    int maxCol = -1;
    for (final cell in rowEl.findElements('c')) {
      final ref = cell.getAttribute('r') ?? '';
      int col = 0;
      for (final ch in ref.runes) {
        if (ch < 65 || ch > 90) break;
        col = col * 26 + (ch - 64);
      }
      col--;
      if (col < 0) continue;
      final type = cell.getAttribute('t') ?? '';
      final raw = cell.findElements('v').firstOrNull?.innerText ?? '';
      String value;
      switch (type) {
        case 's':
          final idx = int.tryParse(raw) ?? -1;
          value = (idx >= 0 && idx < sharedStrings.length) ? sharedStrings[idx] : '';
        case 'inlineStr':
          value = cell.findAllElements('t').map((t) => t.innerText).join();
        case 'b':
          value = raw == '1' ? 'true' : 'false';
        default:
          value = raw;
      }
      cells[col] = value;
      if (col > maxCol) maxCol = col;
    }
    if (maxCol >= 0) rows.add(List.generate(maxCol + 1, (i) => cells[i] ?? ''));
  }
  return rows.isEmpty ? null : rows;
}

// ─── XLSX builder for tests ───────────────────────────────────────────────────

Uint8List buildTestXlsx(List<List<String>> data) {
  // sharedStrings.xml
  final allStrings = <String>[];
  for (final row in data) {
    for (final cell in row) {
      if (!allStrings.contains(cell)) allStrings.add(cell);
    }
  }

  final ssXml = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'count="${allStrings.length}" uniqueCount="${allStrings.length}">');
  for (final s in allStrings) {
    final escaped = s.replaceAll('&', '&amp;').replaceAll('<', '&lt;');
    ssXml.write('<si><t>$escaped</t></si>');
  }
  ssXml.write('</sst>');

  // sheet1.xml
  final sheetXml = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>');
  for (int r = 0; r < data.length; r++) {
    sheetXml.write('<row r="${r + 1}">');
    for (int c = 0; c < data[r].length; c++) {
      final colLetter = _colLetter(c);
      final cellRef = '$colLetter${r + 1}';
      final sIdx = allStrings.indexOf(data[r][c]);
      sheetXml.write('<c r="$cellRef" t="s"><v>$sIdx</v></c>');
    }
    sheetXml.write('</row>');
  }
  sheetXml.write('</sheetData></worksheet>');

  // workbook.xml
  const workbookXml =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"'
      ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  // workbook.xml.rels
  const relsXml =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" '
      'Target="sharedStrings.xml"/>'
      '</Relationships>';

  const contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
      '</Types>';

  final archive = Archive();
  void add(String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  add('[Content_Types].xml', contentTypesXml);
  add('xl/workbook.xml', workbookXml);
  add('xl/_rels/workbook.xml.rels', relsXml);
  add('xl/sharedStrings.xml', ssXml.toString());
  add('xl/worksheets/sheet1.xml', sheetXml.toString());

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

String _colLetter(int col) {
  String result = '';
  col++;
  while (col > 0) {
    col--;
    result = String.fromCharCode(65 + (col % 26)) + result;
    col ~/= 26;
  }
  return result;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  test('parse basic xlsx with shared strings', () {
    final data = [
      ['Tên khách hàng', 'Điện thoại', 'Địa chỉ', 'Email'],
      ['Nguyễn Văn A', '0901234567', 'Hà Nội', 'a@test.com'],
      ['Trần Thị B', '0912345678', 'TP HCM', 'b@test.com'],
    ];
    final bytes = buildTestXlsx(data);
    expect(bytes[0], 0x50); // PK magic
    expect(bytes[1], 0x4B);

    final rows = kvParseXlsx(bytes);
    expect(rows, isNotNull);
    expect(rows!.length, 3);
    expect(rows[0][0], 'Tên khách hàng');
    expect(rows[1][0], 'Nguyễn Văn A');
    expect(rows[1][1], '0901234567');
    expect(rows[2][0], 'Trần Thị B');
  });

  test('detect xls format and throw', () {
    final xls = Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]);
    expect(() => kvParseXlsx(xls), throwsException);
  });

  test('detect non-xlsx and throw', () {
    final csv = Uint8List.fromList(utf8.encode('Name,Phone\nAlice,123'));
    expect(() => kvParseXlsx(csv), throwsException);
  });

  test('parse supplier header detection', () {
    final data = [
      ['Mã NCC', 'Tên nhà cung cấp', 'Email', 'Điện thoại'],
      ['NCC001', 'Công ty ABC', 'abc@company.com', '0901111111'],
    ];
    final bytes = buildTestXlsx(data);
    final rows = kvParseXlsx(bytes);
    expect(rows, isNotNull);
    final header = rows!.first.join(' ');
    expect(header.contains('Tên nhà cung cấp'), isTrue);
  });

  test('column index calculation', () {
    // A=0, B=1, Z=25, AA=26, AZ=51
    int colIndex(String ref) {
      int col = 0;
      for (final ch in ref.runes) {
        if (ch < 65 || ch > 90) break;
        col = col * 26 + (ch - 64);
      }
      return col - 1;
    }
    expect(colIndex('A1'), 0);
    expect(colIndex('B2'), 1);
    expect(colIndex('Z5'), 25);
    expect(colIndex('AA3'), 26);
    expect(colIndex('AZ1'), 51);
  });
}
