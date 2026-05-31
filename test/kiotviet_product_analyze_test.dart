import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

List<List<String>>? kvParseXlsx(Uint8List bytes) {
  if (bytes.length >= 8 && bytes[0] == 0xD0 && bytes[1] == 0xCF) throw Exception('XLS');
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B) throw Exception('Not XLSX');
  final archive = ZipDecoder().decodeBytes(bytes);
  final sharedStrings = <String>[];
  final ssFile = archive.findFile('xl/sharedStrings.xml');
  if (ssFile != null) {
    ssFile.decompress();
    final doc = XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
    for (final si in doc.findAllElements('si')) {
      final buf = StringBuffer();
      for (final t in si.findAllElements('t')) {
        final p = t.parentElement;
        if (p == null || p.localName != 'rPh') buf.write(t.innerText);
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
      if ((rel.getAttribute('Type') ?? '').endsWith('/worksheet')) {
        var target = rel.getAttribute('Target') ?? '';
        if (target.startsWith('/')) target = target.substring(1);
        if (!target.startsWith('xl/')) target = 'xl/$target';
        sheetPath = target;
        break;
      }
    }
  }
  final sheetFile = archive.findFile(sheetPath);
  if (sheetFile == null) throw Exception('Sheet not found: $sheetPath');
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
        case 's': final idx = int.tryParse(raw) ?? -1; value = (idx >= 0 && idx < sharedStrings.length) ? sharedStrings[idx] : '';
        case 'inlineStr': value = cell.findAllElements('t').map((t) => t.innerText).join();
        case 'b': value = raw == '1' ? 'true' : 'false';
        default: value = raw;
      }
      cells[col] = value;
      if (col > maxCol) maxCol = col;
    }
    if (maxCol >= 0) rows.add(List.generate(maxCol + 1, (i) => cells[i] ?? ''));
  }
  return rows.isEmpty ? null : rows;
}

void main() {
  test('analyze product file columns', () {
    final file = File('D:/ảnh claude/DanhSachSanPham_KV30052026-112134-441.xlsx');
    final rows = kvParseXlsx(file.readAsBytesSync())!;
    print('Total rows: ${rows.length}');
    print('\n=== ALL HEADER COLUMNS ===');
    final header = rows.first;
    for (int i = 0; i < header.length; i++) {
      print('  col $i: ${header[i]}');
    }
    print('\n=== DATA ROW 1 ===');
    if (rows.length > 1) {
      final row = rows[1];
      for (int i = 0; i < row.length && i < header.length; i++) {
        if (row[i].isNotEmpty) print('  col $i [${header[i]}]: ${row[i]}');
      }
    }
    print('\n=== DATA ROW 2 ===');
    if (rows.length > 2) {
      final row = rows[2];
      for (int i = 0; i < row.length && i < header.length; i++) {
        if (row[i].isNotEmpty) print('  col $i [${header[i]}]: ${row[i]}');
      }
    }
  });
}
