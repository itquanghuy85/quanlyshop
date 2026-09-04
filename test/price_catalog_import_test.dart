import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/price_catalog_models.dart';
import 'package:quanlyshop/services/price_catalog_service.dart';
import 'package:quanlyshop/services/supplier_invoice_price_book_service.dart';

/// Kiểm thử "Bảng giá từ hoá đơn NCC" — phần chạy được không cần Firebase/
/// SQLite: khoá ổn định, gộp giá vốn, và bộ đọc file Excel 4 sheet.
///
/// Phần cần DB/quyền (`preview`/`commit` gọi Firestore + SQLite) được kiểm
/// trên máy thật, xem docs/HANDOVER.md.

typedef Row = List<dynamic>;

const _headers = SupplierInvoicePriceBookService.headers;

/// Dựng 1 dòng đúng thứ tự 23 cột của file chuẩn.
Row _row({
  String dataType = 'Phụ tùng',
  String group = '',
  String brand = '',
  required String name,
  String models = '',
  String partType = '',
  String sku = '',
  String unit = 'Cái',
  dynamic qty = 1,
  dynamic unitPrice = 0,
  dynamic discount = 0,
  dynamic tax = 0,
  dynamic lineTotal = 0,
  dynamic cost = 0,
  dynamic customerPrice = '',
  String supplier = '',
  String invoiceNo = '',
  String invoiceDate = '',
  String note = '',
  String imageSource = '',
  String confidence = 'Cao',
  String errorNote = '',
  String? key,
}) {
  return [
    dataType,
    group,
    brand,
    name,
    models,
    partType,
    sku,
    unit,
    qty,
    unitPrice,
    discount,
    tax,
    lineTotal,
    cost,
    customerPrice,
    supplier,
    invoiceNo,
    invoiceDate,
    note,
    imageSource,
    confidence,
    errorNote,
    key ??
        PriceCatalogService.buildImportKey(
          name: name,
          sku: sku,
          brand: brand,
          model: models,
          partType: partType,
        ),
  ];
}

void _writeSheet(Sheet sheet, List<String> headers, List<Row> rows) {
  for (var c = 0; c < headers.length; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .value = TextCellValue(headers[c]);
  }
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      final cell = sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
      if (v is int) {
        cell.value = IntCellValue(v);
      } else if (v is double) {
        cell.value = DoubleCellValue(v);
      } else {
        cell.value = TextCellValue('$v');
      }
    }
  }
}

/// Tạo file .xlsx trong bộ nhớ theo cấu trúc chuẩn.
Uint8List _buildFile({
  List<Row>? detail,
  List<Row>? summary,
  List<String>? detailHeaders,
  bool includeGuide = true,
  String? renameDetailTo,
}) {
  final excel = Excel.createExcel();
  if (detail != null) {
    _writeSheet(
      excel[renameDetailTo ?? SupplierInvoicePriceBookService.sheetDetail],
      detailHeaders ?? _headers,
      detail,
    );
  }
  if (summary != null) {
    _writeSheet(
      excel[SupplierInvoicePriceBookService.sheetSummary],
      _headers,
      summary,
    );
  }
  if (includeGuide) {
    _writeSheet(
      excel[SupplierInvoicePriceBookService.sheetGuide],
      ['Mục', 'Nội dung'],
      [
        ['Ghi chú', 'Sheet hướng dẫn — app không nhập sheet này.'],
      ],
    );
  }
  final def = excel.getDefaultSheet();
  if (def != null &&
      def != SupplierInvoicePriceBookService.sheetDetail &&
      def != SupplierInvoicePriceBookService.sheetSummary &&
      def != SupplierInvoicePriceBookService.sheetGuide &&
      def != renameDetailTo) {
    excel.delete(def);
  }
  return Uint8List.fromList(excel.save()!);
}

/// Đọc file bằng đúng bộ đọc của service (qua sheet "Chi tiết nhập hàng").
List<InvoiceCostLine> _read(Uint8List bytes, {String? sheetName}) {
  final excel = Excel.decodeBytes(bytes);
  final sheet =
      excel.tables[sheetName ?? SupplierInvoicePriceBookService.sheetDetail]!;
  return SupplierInvoicePriceBookService.debugReadSheet(sheet);
}

void main() {
  // ── Khoá ổn định ─────────────────────────────────────────────────────────
  group('_khóa_import — khoá ổn định', () {
    test('có SKU thì dùng SKU, KHÔNG dùng tên hàng', () {
      final a = PriceCatalogService.buildImportKey(
        name: 'Màn hình iPhone 13 OLED dẻo JAV',
        sku: 'MH-IP13-JAV',
      );
      final b = PriceCatalogService.buildImportKey(
        name: 'Man hinh ip13 (tên NCC ghi khác)',
        sku: 'mh-ip13-jav',
      );
      expect(a, b, reason: 'Cùng SKU ⇒ cùng mặt hàng dù tên khác');
      expect(a.startsWith('pc|sku|'), isTrue);
    });

    test('không SKU: chuẩn hoá dấu/hoa thường/khoảng trắng', () {
      final a = PriceCatalogService.buildImportKey(
        name: 'Pin  DLC   Korsnow iPhone 11 Pro Max',
        brand: 'iPhone',
        partType: 'Pin',
      );
      final b = PriceCatalogService.buildImportKey(
        name: 'PIN DLC KORSNOW IPHONE 11 PRO MAX',
        brand: 'IPHONE',
        partType: 'PIN',
      );
      expect(a, b);
    });

    test('KHÁC model ⇒ KHÁC khoá (không gộp nhầm)', () {
      final c53 = PriceCatalogService.buildImportKey(
        name: 'Màn hình Korsnow Realme C53',
        brand: 'Realme',
        model: 'Realme C53, C51, C60, Narzo N53',
        partType: 'Màn hình',
      );
      final a58 = PriceCatalogService.buildImportKey(
        name: 'Màn hình Korsnow cho Oppo A58 4G',
        brand: 'Oppo',
        model: 'Oppo A58 4G, A98 5G',
        partType: 'Màn hình',
      );
      expect(c53, isNot(a58));
    });

    test('KHÁC chất lượng cùng model ⇒ KHÁC khoá', () {
      final oled = PriceCatalogService.buildImportKey(
        name: 'Màn hình iPhone 13 OLED dẻo JAV',
        brand: 'iPhone',
        partType: 'Màn hình',
      );
      final lcd = PriceCatalogService.buildImportKey(
        name: 'Màn hình iPhone 13 LCD',
        brand: 'iPhone',
        partType: 'Màn hình',
      );
      expect(oled, isNot(lcd));
    });

    test('firestoreId tất định theo (shopId, khoá) — 2 máy ra cùng doc', () {
      const key = 'pc|iphone|pin iphone 13||pin';
      expect(
        PriceCatalogService.firestoreIdFor('shopA', key),
        PriceCatalogService.firestoreIdFor('shopA', key),
      );
      expect(
        PriceCatalogService.firestoreIdFor('shopA', key),
        isNot(PriceCatalogService.firestoreIdFor('shopB', key)),
      );
    });
  });

  // ── Tổng hợp giá vốn ─────────────────────────────────────────────────────
  group('Tổng hợp giá vốn nhiều hoá đơn', () {
    test('gần nhất / thấp nhất / cao nhất / bình quân gia quyền', () {
      final agg = PriceCatalogService.aggregate(const [
        CostHistoryEntry(
          fingerprint: 'a',
          invoiceNo: 'HD001',
          invoiceDate: '2026-08-01',
          unitCost: 300000,
          qty: 10,
        ),
        CostHistoryEntry(
          fingerprint: 'b',
          invoiceNo: 'HD002',
          invoiceDate: '2026-08-30',
          unitCost: 350000,
          qty: 2,
        ),
        CostHistoryEntry(
          fingerprint: 'c',
          invoiceNo: 'HD003',
          invoiceDate: '2026-07-15',
          unitCost: 280000,
          qty: 1,
        ),
      ]);
      expect(agg.last, 350000, reason: 'ngày hoá đơn mới nhất');
      expect(agg.invoiceNo, 'HD002');
      expect(agg.min, 280000);
      expect(agg.max, 350000);
      // (300000*10 + 350000*2 + 280000*1) / 13 = 3980000/13 = 306153.8 → 306154
      expect(agg.avg, 306154);
    });

    test('bình quân là GIA QUYỀN theo số lượng, không phải trung bình cộng',
        () {
      final agg = PriceCatalogService.aggregate(const [
        CostHistoryEntry(fingerprint: 'a', unitCost: 100000, qty: 99),
        CostHistoryEntry(fingerprint: 'b', unitCost: 900000, qty: 1),
      ]);
      expect(agg.avg, 108000);
      expect(agg.avg, isNot(500000));
    });

    test('lịch sử rỗng ⇒ tất cả bằng 0, không nổ', () {
      final agg = PriceCatalogService.aggregate(const []);
      expect(agg.last, 0);
      expect(agg.avg, 0);
    });
  });

  group('Nhập lại cùng file — chống trùng', () {
    CostHistoryEntry entry(String no, int cost, int qty) => CostHistoryEntry(
          fingerprint: PriceCatalogService.lineFingerprint(
            importKey: 'pc|k',
            invoiceNo: no,
            invoiceDate: '2026-08-30',
            unitCost: cost,
            qty: qty,
          ),
          invoiceNo: no,
          invoiceDate: '2026-08-30',
          unitCost: cost,
          qty: qty,
        );

    test('gộp lần 2 cùng dòng ⇒ bị coi là trùng, bình quân KHÔNG đổi', () {
      const base = PriceCatalogItem(importKey: 'pc|k', itemName: 'X');
      final first = PriceCatalogService.mergeHistory(base, [
        entry('HD01', 310000, 3),
      ]);
      expect(first.duplicates, 0);
      expect(first.item.costHistory.length, 1);
      expect(first.item.avgCost, 310000);

      final second = PriceCatalogService.mergeHistory(first.item, [
        entry('HD01', 310000, 3),
      ]);
      expect(second.duplicates, 1);
      expect(second.item.costHistory.length, 1, reason: 'không thêm dòng mới');
      expect(second.item.avgCost, 310000, reason: 'không cộng trùng');
    });

    test('hoá đơn KHÁC cùng mặt hàng ⇒ được cộng thêm', () {
      const base = PriceCatalogItem(importKey: 'pc|k', itemName: 'X');
      final r1 = PriceCatalogService.mergeHistory(base, [
        entry('HD01', 300000, 1),
      ]);
      final r2 = PriceCatalogService.mergeHistory(r1.item, [
        entry('HD02', 400000, 1),
      ]);
      expect(r2.duplicates, 0);
      expect(r2.item.costHistory.length, 2);
      expect(r2.item.avgCost, 350000);
      expect(r2.item.minCost, 300000);
      expect(r2.item.maxCost, 400000);
    });

    test('lịch sử bị cắt ở mức trần, giữ các dòng mới nhất', () {
      var item = const PriceCatalogItem(importKey: 'pc|k', itemName: 'X');
      for (var i = 0; i < PriceCatalogService.maxHistoryEntries + 20; i++) {
        item = PriceCatalogService.mergeHistory(item, [
          CostHistoryEntry(fingerprint: 'fp$i', unitCost: 1000 + i, qty: 1),
        ]).item;
      }
      expect(
        item.costHistory.length,
        PriceCatalogService.maxHistoryEntries,
      );
      expect(item.costHistory.last.fingerprint, 'fp219');
    });
  });

  // ── Đọc file Excel ───────────────────────────────────────────────────────
  group('Đọc file Excel', () {
    test('file nhiều sheet — đọc đúng sheet chi tiết, bỏ sheet hướng dẫn', () {
      final bytes = _buildFile(
        detail: [
          _row(name: 'Pin iPhone 13', cost: 310000, qty: 3),
          _row(name: 'Màn hình Oppo A74', cost: 260000, qty: 1),
        ],
        summary: [_row(name: 'Pin iPhone 13', cost: 310000, qty: 3)],
      );
      final lines = _read(bytes);
      expect(lines.length, 2);
      expect(lines.first.name, 'Pin iPhone 13');
      expect(lines.first.cost, 310000);
      expect(lines.first.qty, 3);
    });

    test('Giá thu khách để TRỐNG ⇒ null (không tự đoán từ giá vốn)', () {
      final bytes = _buildFile(
        detail: [_row(name: 'Pin iPhone 13', cost: 310000, customerPrice: '')],
      );
      final l = _read(bytes).single;
      expect(l.customerPrice, isNull);
      expect(l.cost, 310000);
    });

    test('Giá thu khách CÓ điền ⇒ đọc đúng', () {
      final bytes = _buildFile(
        detail: [
          _row(name: 'Pin iPhone 13', cost: 310000, customerPrice: 550000),
        ],
      );
      expect(_read(bytes).single.customerPrice, 550000);
    });

    test('tiền có dấu chấm / phẩy / ký hiệu đ đều ra số nguyên đúng', () {
      final bytes = _buildFile(
        detail: [
          _row(name: 'A', cost: '310.000'),
          _row(name: 'B', cost: '310,000'),
          _row(name: 'C', cost: '310.000 đ'),
          _row(name: 'D', cost: '1.250.000đ'),
          _row(name: 'E', cost: 310000),
        ],
      );
      final costs = _read(bytes).map((e) => e.cost).toList();
      expect(costs, [310000, 310000, 310000, 1250000, 310000]);
    });

    test('ô số THỰC không bị nhân 10 lần (bẫy của parseCurrency)', () {
      // 310000.5 nếu strip ký tự sẽ thành 3100005 — phải làm tròn 310001.
      final bytes = _buildFile(detail: [_row(name: 'A', cost: 310000.5)]);
      expect(_read(bytes).single.cost, 310001);

      final bytes2 = _buildFile(detail: [_row(name: 'A', cost: '310.000,75')]);
      expect(_read(bytes2).single.cost, 310001);
    });

    test('thiếu "Giá vốn" thì lấy "Đơn giá nhập"', () {
      final bytes = _buildFile(
        detail: [_row(name: 'A', cost: 0, unitPrice: 275000)],
      );
      expect(_read(bytes).single.cost, 275000);
    });

    test('ngày 30/08/2026 chuẩn hoá về 2026-08-30', () {
      final bytes = _buildFile(
        detail: [
          _row(name: 'A', cost: 1, invoiceDate: '30/08/2026'),
          _row(name: 'B', cost: 1, invoiceDate: '2026-8-3'),
        ],
      );
      final lines = _read(bytes);
      expect(lines[0].invoiceDate, '2026-08-30');
      expect(lines[1].invoiceDate, '2026-08-03');
    });

    test('mất cột _khóa_import ⇒ tự dựng lại, dòng không bị mất', () {
      final headersNoKey = _headers.sublist(0, _headers.length - 1);
      final rowsNoKey = [
        _row(name: 'Pin iPhone 13', brand: 'iPhone', partType: 'Pin', cost: 1)
            .sublist(0, _headers.length - 1),
      ];
      final bytes = _buildFile(
        detail: rowsNoKey,
        detailHeaders: headersNoKey,
      );
      final l = _read(bytes).single;
      expect(l.importKey, isNotEmpty);
      expect(
        l.importKey,
        PriceCatalogService.buildImportKey(
          name: 'Pin iPhone 13',
          brand: 'iPhone',
          partType: 'Pin',
        ),
      );
    });

    test('dòng thiếu tên / thiếu giá vốn / số lượng sai vẫn đọc ra để đếm', () {
      final bytes = _buildFile(
        detail: [
          _row(name: '', cost: 100000),
          _row(name: 'B', cost: 0, unitPrice: 0),
          _row(name: 'C', cost: 100000, qty: -3),
          _row(name: 'D', cost: 100000, qty: 'hai'),
        ],
      );
      final lines = _read(bytes);
      expect(lines.length, 4);
      expect(lines[0].name, isEmpty);
      expect(lines[1].cost, 0);
      expect(lines[2].qty, -3);
      expect(lines[3].qty, 0, reason: '"hai" không phải số ⇒ 0 (không hợp lệ)');
    });

    test('dòng trống hoàn toàn bị bỏ qua êm', () {
      final bytes = _buildFile(
        detail: [
          _row(name: 'A', cost: 100000),
          _row(name: '', cost: '', unitPrice: '', qty: ''),
        ],
      );
      expect(_read(bytes).length, 1);
    });

    test('một dòng nhiều model tương thích ⇒ bị đánh dấu cần kiểm tra', () {
      final bytes = _buildFile(
        detail: [
          _row(
            name: 'Màn hình Korsnow cho Oppo A58 4G',
            models: 'Oppo A58 4G, A98 5G, A79 5G, Realme C55',
            cost: 260000,
          ),
          _row(name: 'Pin iPhone 13', cost: 310000),
        ],
      );
      final lines = _read(bytes);
      expect(lines[0].hasMultipleModels, isTrue);
      expect(lines[0].needsReview, isTrue);
      expect(lines[1].needsReview, isFalse);
    });

    test('cột "Lỗi cần kiểm tra" hoặc tin cậy Thấp ⇒ cần kiểm tra', () {
      final bytes = _buildFile(
        detail: [
          _row(name: 'A', cost: 1, errorNote: 'Ảnh mờ'),
          _row(name: 'B', cost: 1, confidence: 'Thấp'),
          _row(name: 'C', cost: 1, confidence: 'Cao'),
        ],
      );
      final lines = _read(bytes);
      expect(lines[0].needsReview, isTrue);
      expect(lines[1].needsReview, isTrue);
      expect(lines[2].needsReview, isFalse);
    });

    test('file THIẾU cột bắt buộc ⇒ báo lỗi, không đọc bừa', () {
      // Bỏ cột "Tên mặt hàng" và "Giá vốn".
      final bytes = _buildFile(
        detail: [
          ['Phụ tùng', 'Nhóm X'],
        ],
        detailHeaders: const ['Loại dữ liệu', 'Nhóm'],
      );
      final excel = Excel.decodeBytes(bytes);
      final errors = <String>[];
      final lines = SupplierInvoicePriceBookService.debugReadSheet(
        excel.tables[SupplierInvoicePriceBookService.sheetDetail]!,
        errors: errors,
      );
      expect(lines, isEmpty);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('thiếu cột'));
    });

    test('hoá đơn mẫu HD014650 — file mẫu đọc lại đủ 5 dòng, giá đúng', () {
      final excel = SupplierInvoicePriceBookService.buildTemplateExcel();
      final bytes = Uint8List.fromList(excel.save()!);
      final lines = _read(bytes);

      expect(lines.length, 5);
      expect(lines.every((l) => l.invoiceNo == 'HD014650'), isTrue);
      expect(lines.every((l) => l.invoiceDate == '2026-08-30'), isTrue);
      // Giá thu khách BẮT BUỘC trống trong dữ liệu mẫu.
      expect(lines.every((l) => l.customerPrice == null), isTrue);

      expect(lines[0].cost, 310000);
      expect(lines[0].qty, 3);
      expect(lines[1].cost, 260000);
      expect(lines[1].needsReview, isTrue, reason: 'nhiều model tương thích');
      expect(lines[2].cost, 270000);
      expect(lines[3].cost, 220000);
      expect(lines[4].cost, 900000);

      // Tổng tiền hoá đơn: 310k*3 + 260k + 270k*3 + 220k + 900k = 3.120.000
      final total = lines.fold<int>(0, (s, l) => s + l.cost * l.qty);
      expect(total, 3120000);

      // 5 dòng ⇒ 5 mặt hàng khác nhau (không gộp nhầm).
      expect(lines.map((l) => l.importKey).toSet().length, 5);
    });

    test('file mẫu có đủ 4 sheet đúng tên', () {
      final excel = SupplierInvoicePriceBookService.buildTemplateExcel();
      final names = excel.tables.keys.toSet();
      expect(names, contains(SupplierInvoicePriceBookService.sheetDetail));
      expect(names, contains(SupplierInvoicePriceBookService.sheetSummary));
      expect(names, contains(SupplierInvoicePriceBookService.sheetErrors));
      expect(names, contains(SupplierInvoicePriceBookService.sheetGuide));
    });
  });

  // ── Che giá vốn ──────────────────────────────────────────────────────────
  group('Che giá vốn với người không có quyền', () {
    test('copyWith xoá sạch mọi trường giá vốn', () {
      const item = PriceCatalogItem(
        importKey: 'pc|k',
        itemName: 'Pin iPhone 13',
        lastCost: 310000,
        avgCost: 305000,
        minCost: 300000,
        maxCost: 320000,
        customerPrice: 550000,
        supplier: 'NCC A',
        lastInvoiceDate: '2026-08-30',
      );
      final masked = item.copyWith(
        lastCost: 0,
        avgCost: 0,
        minCost: 0,
        maxCost: 0,
        costHistory: const [],
        supplier: '',
        lastInvoiceNo: '',
        lastInvoiceDate: '',
      );
      expect(masked.lastCost, 0);
      expect(masked.avgCost, 0);
      expect(masked.supplier, isEmpty);
      // Giá THU KHÁCH phải còn — nhân viên cần để báo giá.
      expect(masked.customerPrice, 550000);
      expect(masked.hasCustomerPrice, isTrue);
    });

    test('chưa có giá thu khách ⇒ hasCustomerPrice false, lãi 0', () {
      const item = PriceCatalogItem(
        importKey: 'pc|k',
        itemName: 'X',
        lastCost: 310000,
      );
      expect(item.hasCustomerPrice, isFalse);
      expect(item.referenceProfit, 0,
          reason: 'không suy lãi khi chưa có giá thu');
    });
  });

  // ── Model ────────────────────────────────────────────────────────────────
  group('PriceCatalogItem — lưu/đọc', () {
    test('toMap/fromMap giữ nguyên dữ liệu, kể cả lịch sử giá', () {
      const item = PriceCatalogItem(
        importKey: 'pc|iphone|pin iphone 13||pin',
        itemName: 'Pin iPhone 13',
        brand: 'iPhone',
        partType: 'Pin',
        lastCost: 310000,
        avgCost: 305000,
        customerPrice: 550000,
        needsReview: true,
        reviewNote: 'Nhiều model',
        costHistory: [
          CostHistoryEntry(
            fingerprint: 'fp1',
            invoiceNo: 'HD014650',
            invoiceDate: '2026-08-30',
            unitCost: 310000,
            qty: 3,
          ),
        ],
      );
      final back = PriceCatalogItem.fromMap(item.toMap());
      expect(back.importKey, item.importKey);
      expect(back.itemName, item.itemName);
      expect(back.lastCost, 310000);
      expect(back.customerPrice, 550000);
      expect(back.needsReview, isTrue);
      expect(back.costHistory.length, 1);
      expect(back.costHistory.first.invoiceNo, 'HD014650');
      expect(back.costHistory.first.qty, 3);
    });

    test('SQLite trả 0/1 thay cho bool vẫn đọc đúng', () {
      final back = PriceCatalogItem.fromMap(const {
        'importKey': 'pc|k',
        'itemName': 'X',
        'needsReview': 1,
        'deleted': 0,
        'isSynced': 1,
      });
      expect(back.needsReview, isTrue);
      expect(back.deleted, isFalse);
      expect(back.isSynced, isTrue);
    });

    test('costHistoryJson hỏng ⇒ trả list rỗng, không nổ', () {
      final back = PriceCatalogItem.fromMap(const {
        'importKey': 'pc|k',
        'itemName': 'X',
        'costHistoryJson': 'không-phải-json',
      });
      expect(back.costHistory, isEmpty);
    });
  });
}
