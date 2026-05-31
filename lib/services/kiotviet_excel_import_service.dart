import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xml/xml.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';

// ─── XLSX parser (top-level for compute()) ────────────────────────────────────
//
// Reads XLSX by unzipping + parsing XML directly.
// Avoids the excel package's null-check bugs with certain KiotViet files.

List<List<String>>? _kvParseXlsx(Uint8List bytes) {
  // Detect XLS (old binary format) — not supported, only XLSX
  if (bytes.length >= 8 &&
      bytes[0] == 0xD0 && bytes[1] == 0xCF &&
      bytes[2] == 0x11 && bytes[3] == 0xE0) {
    throw Exception(
        'File định dạng .xls cũ không được hỗ trợ. '
        'Vui lòng vào KiotViet → Xuất file → chọn Excel (.xlsx) và thử lại.');
  }
  // Detect non-ZIP (not XLSX at all)
  if (bytes.length < 4 ||
      bytes[0] != 0x50 || bytes[1] != 0x4B) {
    throw Exception(
        'File không phải định dạng Excel (.xlsx). '
        'Vui lòng xuất lại từ KiotViet theo định dạng .xlsx');
  }
  // Note: do NOT wrap in try/catch here — let exceptions propagate with full detail
  {
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. Shared strings table
    final sharedStrings = <String>[];
    final ssFile = archive.findFile('xl/sharedStrings.xml');
    if (ssFile != null) {
      ssFile.decompress();
      final doc = XmlDocument.parse(utf8.decode(ssFile.content as List<int>));
      for (final si in doc.findAllElements('si')) {
        final buf = StringBuffer();
        for (final t in si.findAllElements('t')) {
          final parent = t.parentElement;
          if (parent == null || parent.localName != 'rPh') {
            buf.write(t.innerText);
          }
        }
        sharedStrings.add(buf.toString());
      }
    }

    // 2. Find first sheet path via workbook relations
    String sheetPath = 'xl/worksheets/sheet1.xml';
    final relsFile = archive.findFile('xl/_rels/workbook.xml.rels');
    if (relsFile != null) {
      relsFile.decompress();
      final doc =
          XmlDocument.parse(utf8.decode(relsFile.content as List<int>));
      for (final rel in doc.findAllElements('Relationship')) {
        final type = rel.getAttribute('Type') ?? '';
        if (type.endsWith('/worksheet')) {
          var target = rel.getAttribute('Target') ?? '';
          if (target.isNotEmpty) {
            // Normalize: remove leading '/', then ensure 'xl/' prefix
            if (target.startsWith('/')) target = target.substring(1);
            if (!target.startsWith('xl/')) target = 'xl/$target';
            sheetPath = target;
          }
          break;
        }
      }
    }

    // 3. Parse sheet XML
    final sheetFile = archive.findFile(sheetPath);
    if (sheetFile == null) return null;

    sheetFile.decompress();
    final doc =
        XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));

    final rows = <List<String>>[];

    for (final rowEl in doc.findAllElements('row')) {
      final cells = <int, String>{};
      int maxCol = -1;

      for (final cell in rowEl.findElements('c')) {
        final ref = cell.getAttribute('r') ?? '';
        final colIdx = _kvColIndex(ref);
        if (colIdx < 0) continue;

        final type = cell.getAttribute('t') ?? '';
        final raw = cell.findElements('v').firstOrNull?.innerText ?? '';

        final String value;
        switch (type) {
          case 's': // shared string
            final idx = int.tryParse(raw) ?? -1;
            value = (idx >= 0 && idx < sharedStrings.length)
                ? sharedStrings[idx]
                : '';
          case 'inlineStr': // inline string
            value = cell.findAllElements('t').map((t) => t.innerText).join();
          case 'b': // boolean
            value = raw == '1' ? 'true' : 'false';
          default: // number / date / formula result
            value = raw;
        }

        cells[colIdx] = value;
        if (colIdx > maxCol) maxCol = colIdx;
      }

      if (maxCol >= 0) {
        rows.add(List.generate(maxCol + 1, (i) => cells[i] ?? ''));
      }
    }

    return rows.isEmpty ? null : rows;
  }
}

/// Convert Excel column letters to 0-based index: A→0, B→1, Z→25, AA→26
int _kvColIndex(String ref) {
  int col = 0;
  for (final ch in ref.runes) {
    if (ch < 65 || ch > 90) break; // stop at first non A-Z char
    col = col * 26 + (ch - 64);
  }
  return col - 1;
}

// ─── Result ───────────────────────────────────────────────────────────────────

class KvImportResult {
  final int inserted;
  final int updated;
  final int skipped;
  final List<String> errors;

  const KvImportResult({
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.errors = const [],
  });

  KvImportResult operator +(KvImportResult other) => KvImportResult(
        inserted: inserted + other.inserted,
        updated: updated + other.updated,
        skipped: skipped + other.skipped,
        errors: [...errors, ...other.errors],
      );

  bool get hasErrors => errors.isNotEmpty;
}

// ─── Service ──────────────────────────────────────────────────────────────────

class KiotVietExcelImportService {
  static final _db = DBHelper();

  // ── Auto-detect ──────────────────────────────────────────────────────────

  static Future<String?> detectFileType(Uint8List bytes) async {
    try {
      final rows = await _parseRows(bytes);
      if (rows == null || rows.isEmpty) return null;
      final header = rows.first.map(_str).join(' ');
      if (header.contains('Mã nhập hàng') || header.contains('Giá nhập')) {
        return 'purchase_orders';
      }
      if (header.contains('Mã hóa đơn') || header.contains('Tổng tiền hàng')) {
        return 'sales';
      }
      if (header.contains('Tên hàng') || header.contains('Giá bán')) {
        return 'products';
      }
      if (header.contains('Tên khách hàng') || header.contains('Tổng bán')) {
        return 'customers';
      }
      if (header.contains('Tên nhà cung cấp') ||
          header.contains('Nợ cần trả')) {
        return 'suppliers';
      }
    } catch (e) {
      debugPrint('KvImport detectFileType: $e');
    }
    return null;
  }

  // ── Products ─────────────────────────────────────────────────────────────

  static Future<KvImportResult> importProducts(
    Uint8List bytes, {
    bool overwriteExisting = false,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) {
        return const KvImportResult(errors: ['Chưa đăng nhập']);
      }

      final rows = await _parseRows(bytes);
      if (rows == null) {
        return const KvImportResult(errors: ['Không đọc được file Excel']);
      }
      if (rows.length < 2) {
        return const KvImportResult(errors: ['File trống']);
      }

      final header = rows.first.map(_str).join(' ');
      if (!header.contains('Tên hàng')) {
        return const KvImportResult(
            errors: ['File không đúng định dạng — thiếu cột "Tên hàng"']);
      }

      final db = await _db.database;
      int inserted = 0, updated = 0, skipped = 0;
      final errors = <String>[];
      final data = rows.skip(1).toList();
      final total = data.length;

      for (int i = 0; i < total; i++) {
        try { onProgress?.call(i, total); } catch (_) {}

        try {
          final row = data[i];
          final name = _at(row, 4);
          if (name.isEmpty) { skipped++; continue; }

          final dup = await db.query('products',
              where:
                  'UPPER(name) = UPPER(?) AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [name, shopId],
              limit: 1);

          if (dup.isNotEmpty && !overwriteExisting) { skipped++; continue; }

          final now = DateTime.now().millisecondsSinceEpoch;
          final brand = _at(row, 5);
          final price = _int(row, 6);
          final cost = _int(row, 7);
          final qty = _int(row, 8);
          final unit = _at(row, 13);
          final imei = _at(row, 21);
          final useImei = _int(row, 19) == 1;
          final active = _int(row, 22);
          final desc = _at(row, 24);
          final warranty = _at(row, 28);
          final createdAt = _dateMs(row, 30);
          final group = _at(row, 1);
          final sku = _at(row, 2);

          final condition = _guessCondition(group, name);
          final type = _guessType(group, useImei);
          final details = _parseProductNameDetails(name);

          final map = <String, dynamic>{
            'shopId': shopId,
            'name': name.toUpperCase(),
            'brand':
                brand.isNotEmpty ? brand.toUpperCase() : _guessBrand(name),
            'imei': (useImei && imei.isNotEmpty) ? imei : null,
            'cost': cost,
            'price': price,
            'condition': condition,
            'status': active == 1 ? 1 : 0,
            'description': desc.isNotEmpty ? desc : null,
            'warranty': warranty.isNotEmpty ? warranty : null,
            'createdAt': createdAt > 0 ? createdAt : now,
            'updatedAt': now,
            'quantity': qty,
            'isSynced': 0,
            'sku': sku.isNotEmpty ? sku : null,
            'unit': unit.isNotEmpty ? unit : null,
            'type': type,
            'isPending': 0,
            'deleted': 0,
            'images': null,
            'model': details['model'],
            'color': details['color'],
            'capacity': details['capacity'],
            'size': null,
            'paymentMethod': null,
            'labelInfo': null,
            'labelNote': null,
            'categoryId': null,
            'expiryDate': null,
            'batchNumber': null,
            'variantParentId': null,
            'customData': null,
            'supplier': null,
          };

          if (dup.isNotEmpty && overwriteExisting) {
            final id = dup.first['id'];
            map.remove('createdAt');
            await db.update('products', map, where: 'id = ?', whereArgs: [id]);
            updated++;
          } else {
            await db.insert('products', map);
            inserted++;
          }
        } catch (e, st) {
          final msg = 'Hàng ${i + 2}: $e';
          errors.add(msg);
          debugPrint('KvImport product $msg\n$st');
        }
      }

      try { onProgress?.call(total, total); } catch (_) {}
      return KvImportResult(
          inserted: inserted,
          updated: updated,
          skipped: skipped,
          errors: errors);
    } catch (e) {
      return KvImportResult(errors: ['Lỗi nhập sản phẩm: $e']);
    }
  }

  // ── Sales (Invoices) ──────────────────────────────────────────────────────

  static Future<KvImportResult> importSales(
    Uint8List bytes, {
    bool overwriteExisting = false,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return const KvImportResult(errors: ['Chưa đăng nhập']);

      final rows = await _parseRows(bytes);
      if (rows == null) return const KvImportResult(errors: ['Không đọc được file Excel']);
      if (rows.length < 2) return const KvImportResult(errors: ['File trống']);

      final header = rows.first.map(_str).join(' ');
      if (!header.contains('Mã hóa đơn')) {
        return const KvImportResult(
            errors: ['File không đúng định dạng — thiếu cột "Mã hóa đơn"']);
      }

      // "DanhSachChiTietHoaDon": col 0 = "Chi nhánh", invoice at col 1
      if (_at(rows.first, 0).contains('Chi nhánh')) {
        return await _importSalesDetailed(rows, shopId,
            overwriteExisting: overwriteExisting, onProgress: onProgress);
      }

      final db = await _db.database;
      int inserted = 0, updated = 0, skipped = 0;
      final errors = <String>[];
      final dataRows = rows.skip(1).toList();
      final totalRows = dataRows.length;

      // Detect product-name column from header (KiotViet exports one row per
      // product item — find "Tên hàng" in header to aggregate product names).
      final headerRow = rows.first;
      int productNameCol = -1;
      int productQtyCol = -1;
      int productPriceCol = -1;
      for (int c = 8; c < headerRow.length; c++) {
        final h = _str(headerRow[c]);
        if (productNameCol == -1 && h.contains('Tên hàng')) productNameCol = c;
        if (productQtyCol == -1 && (h.contains('Số lượng') || h == 'SL')) productQtyCol = c;
        if (productPriceCol == -1 && (h.contains('Đơn giá') || h.contains('Giá bán'))) productPriceCol = c;
      }

      // Group data rows by invoice code (KiotViet may have multiple rows per invoice).
      final invoiceGroups = <String, List<List<String>>>{};
      final invoiceOrder = <String>[];
      for (final row in dataRows) {
        final code = _at(row, 0).trim();
        if (code.isEmpty) { skipped++; continue; }
        if (!invoiceGroups.containsKey(code)) {
          invoiceGroups[code] = [];
          invoiceOrder.add(code);
        }
        invoiceGroups[code]!.add(row);
      }

      final total = invoiceOrder.length;

      for (int i = 0; i < total; i++) {
        try { onProgress?.call(i, total); } catch (_) {}

        final invoiceCode = invoiceOrder[i];
        final group = invoiceGroups[invoiceCode]!;
        final firstRow = group.first;

        try {
          // col 0=Mã HĐ, 1=Thời gian, 3=Mã KH, 4=Khách hàng
          // col 5=Tổng tiền hàng, 6=Giảm giá, 7=Khách đã trả
          final noteKey = 'KV:$invoiceCode';
          final soldAt = _datetimeMs(firstRow, 1);
          final rawCustomer = _at(firstRow, 3).trim();
          final customerName = _at(firstRow, 4).trim();
          final isWalkIn = (rawCustomer.isEmpty || rawCustomer == 'KHÁCH LẺ' ||
              customerName == 'KHÁCH LẺ') ? 1 : 0;
          final phone = isWalkIn == 1 ? '' : _cleanPhone(rawCustomer);
          final totalPrice = _intFromString(_at(firstRow, 5));
          final discount = _intFromString(_at(firstRow, 6));
          final cashAmount = _intFromString(_at(firstRow, 7));
          final now = DateTime.now().millisecondsSinceEpoch;

          // Collect product names/snapshots from all rows in this invoice group.
          final itemSnapshots = <Map<String, dynamic>>[];
          final collectedNames = <String>[];
          for (final row in group) {
            final pName = productNameCol >= 0 ? _at(row, productNameCol) : '';
            if (pName.isNotEmpty) {
              collectedNames.add(pName);
              final qty = productQtyCol >= 0 ? _int(row, productQtyCol) : 1;
              final price = productPriceCol >= 0 ? _int(row, productPriceCol) : 0;
              itemSnapshots.add({
                'name': pName,
                'quantity': qty,
                'price': price,
                'totalPrice': price * (qty > 0 ? qty : 1),
                'source': 'kv',
              });
            }
          }

          final productNamesStr = collectedNames.isNotEmpty
              ? collectedNames.join(', ')
              : null;
          final itemSnapshotsStr = itemSnapshots.isNotEmpty
              ? jsonEncode(itemSnapshots)
              : null;

          // Dedup by invoice code stored in notes
          final dup = await db.query('sales',
              where: 'notes = ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [noteKey],
              limit: 1);

          if (dup.isNotEmpty && !overwriteExisting) { skipped++; continue; }

          final map = <String, dynamic>{
            'customerName': customerName.isNotEmpty ? customerName : 'Khách lẻ',
            'phone': phone.isNotEmpty ? phone : null,
            'isWalkIn': isWalkIn,
            'walkInName': isWalkIn == 1 ? 'Khách lẻ' : null,
            'walkInPhone': null,
            'address': null,
            'productNames': productNamesStr,
            'productImeis': null,
            'itemSnapshotsJson': itemSnapshotsStr,
            'totalPrice': totalPrice,
            'totalCost': 0,
            'discount': discount,
            'paymentMethod': 'TIỀN MẶT',
            'sellerName': null,
            'sellerUid': null,
            'soldAt': soldAt > 0 ? soldAt : now,
            'notes': noteKey,
            'gifts': null,
            'isInstallment': 0,
            'downPayment': 0,
            'downPaymentMethod': null,
            'loanAmount': 0,
            'cashAmount': cashAmount,
            'transferAmount': 0,
            'isSynced': 0,
            'deleted': 0,
          };

          // Include shopId if column exists (added via migration)
          try {
            map['shopId'] = shopId;
            if (dup.isNotEmpty && overwriteExisting) {
              final id = dup.first['id'];
              await db.update('sales', map, where: 'id = ?', whereArgs: [id]);
              updated++;
            } else {
              await db.insert('sales', map);
              inserted++;
            }
          } catch (_) {
            // Retry without shopId if column doesn't exist
            map.remove('shopId');
            if (dup.isNotEmpty && overwriteExisting) {
              final id = dup.first['id'];
              await db.update('sales', map, where: 'id = ?', whereArgs: [id]);
              updated++;
            } else {
              await db.insert('sales', map);
              inserted++;
            }
          }
        } catch (e, st) {
          final msg = 'HĐ $invoiceCode: $e';
          errors.add(msg);
          debugPrint('KvImport sale $msg\n$st');
        }
      }

      try { onProgress?.call(totalRows, totalRows); } catch (_) {}
      return KvImportResult(
          inserted: inserted, updated: updated, skipped: skipped, errors: errors);
    } catch (e) {
      return KvImportResult(errors: ['Lỗi nhập hóa đơn: $e']);
    }
  }

  // ── Sales (Detailed — DanhSachChiTietHoaDon) ─────────────────────────────

  static Future<KvImportResult> _importSalesDetailed(
    List<List<String>> rows,
    String shopId, {
    bool overwriteExisting = false,
    void Function(int done, int total)? onProgress,
  }) async {
    final db = await _db.database;
    int inserted = 0, updated = 0, skipped = 0;
    final errors = <String>[];
    final dataRows = rows.skip(1).toList();
    final totalRows = dataRows.length;

    // Group rows by invoice code (col 1 = Mã hóa đơn)
    final invoiceGroups = <String, List<List<String>>>{};
    final invoiceOrder = <String>[];
    for (final row in dataRows) {
      final code = _at(row, 1).trim();
      if (code.isEmpty) { skipped++; continue; }
      if (!invoiceGroups.containsKey(code)) {
        invoiceGroups[code] = [];
        invoiceOrder.add(code);
      }
      invoiceGroups[code]!.add(row);
    }

    final total = invoiceOrder.length;

    for (int i = 0; i < total; i++) {
      try { onProgress?.call(i, total); } catch (_) {}

      final invoiceCode = invoiceOrder[i];
      final group = invoiceGroups[invoiceCode]!;
      final firstRow = group.first;

      try {
        // Skip non-completed invoices (col 48 = Trạng thái)
        final status = _at(firstRow, 48);
        if (status.isNotEmpty && status != 'Hoàn thành') { skipped++; continue; }

        final noteKey = 'KV:$invoiceCode';
        final soldAt = _datetimeMs(firstRow, 6);        // col 6 = Thời gian
        final customerCode = _at(firstRow, 12).trim();  // col 12 = Mã KH
        final customerName = _at(firstRow, 13).trim();  // col 13 = Tên KH
        final rawPhone = _at(firstRow, 15).trim();      // col 15 = Điện thoại
        final phone = _cleanPhone(rawPhone);
        final sellerName = _at(firstRow, 21).trim();    // col 21 = Người bán
        final noteText = _at(firstRow, 37).trim();      // col 37 = Ghi chú
        final totalPrice = _intFromString(_at(firstRow, 38)); // col 38 = Tổng tiền hàng
        final discount = _intFromString(_at(firstRow, 39));   // col 39 = Giảm giá HĐ
        final cashAmount = _intFromString(_at(firstRow, 42)); // col 42 = Tiền mặt
        final cardAmount = _intFromString(_at(firstRow, 43)); // col 43 = Thẻ
        final transferAmount = _intFromString(_at(firstRow, 45)); // col 45 = Chuyển khoản

        final isWalkIn = (customerCode.isEmpty ||
            customerCode.toUpperCase() == 'KL' ||
            customerName.isEmpty ||
            customerName == 'Khách lẻ' ||
            customerName == 'KHÁCH LẺ') ? 1 : 0;

        // Determine payment method
        final hasCash = cashAmount > 0;
        final hasCard = cardAmount > 0;
        final hasTransfer = transferAmount > 0;
        final paymentCount = (hasCash ? 1 : 0) + (hasCard ? 1 : 0) + (hasTransfer ? 1 : 0);
        final String paymentMethod;
        if (paymentCount > 1) {
          paymentMethod = 'KẾT HỢP';
        } else if (hasTransfer) {
          paymentMethod = 'CHUYỂN KHOẢN';
        } else if (hasCard) {
          paymentMethod = 'THẺ';
        } else {
          paymentMethod = 'TIỀN MẶT';
        }

        // Collect product snapshots (cols 50-63)
        final itemSnapshots = <Map<String, dynamic>>[];
        final collectedNames = <String>[];
        String? firstWarranty;

        for (final row in group) {
          final pName = _at(row, 52); // col 52 = Tên hàng
          if (pName.isEmpty) continue;

          collectedNames.add(pName);
          final sku = _at(row, 50);       // col 50 = Mã hàng
          final brand = _at(row, 53);     // col 53 = Thương hiệu
          final imei = _at(row, 55);      // col 55 = IMEI
          final qty = _int(row, 57);      // col 57 = Số lượng
          final unitPrice = _int(row, 58);// col 58 = Đơn giá
          final itemDiscount = _intFromString(_at(row, 60)); // col 60 = Giảm giá item
          final lineTotal = _intFromString(_at(row, 62));    // col 62 = Thành tiền
          final warranty = _at(row, 63); // col 63 = Bảo hành

          firstWarranty ??= warranty.isNotEmpty ? warranty : null;

          final snapshot = <String, dynamic>{
            'name': pName,
            'quantity': qty > 0 ? qty : 1,
            'price': unitPrice,
            'totalPrice': lineTotal > 0 ? lineTotal : unitPrice * (qty > 0 ? qty : 1),
            'source': 'kv',
          };
          if (sku.isNotEmpty) snapshot['sku'] = sku;
          if (brand.isNotEmpty) snapshot['brand'] = brand;
          if (imei.isNotEmpty) snapshot['imei'] = imei;
          if (itemDiscount > 0) snapshot['discount'] = itemDiscount;
          if (warranty.isNotEmpty) snapshot['warranty'] = warranty;
          itemSnapshots.add(snapshot);

          // Update matching product record with IMEI and price if currently missing
          if (imei.isNotEmpty || unitPrice > 0) {
            try {
              final prods = await db.query(
                'products',
                where: 'UPPER(name) = UPPER(?) AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
                whereArgs: [pName.toUpperCase(), shopId],
                orderBy: 'id ASC',
                limit: 1,
              );
              if (prods.isNotEmpty) {
                final prod = prods.first;
                final upd = <String, dynamic>{};
                final curImei = (prod['imei'] as String?) ?? '';
                if (imei.isNotEmpty && curImei.isEmpty) upd['imei'] = imei;
                final curPrice = (prod['price'] as num?)?.toInt() ?? 0;
                if (unitPrice > 0 && curPrice == 0) upd['price'] = unitPrice;
                if (upd.isNotEmpty) {
                  upd['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
                  upd['isSynced'] = 0;
                  await db.update('products', upd,
                      where: 'id = ?', whereArgs: [prod['id']]);
                }
              }
            } catch (_) {}
          }
        }

        final productNamesStr = collectedNames.isNotEmpty ? collectedNames.join(', ') : null;
        final itemSnapshotsStr = itemSnapshots.isNotEmpty ? jsonEncode(itemSnapshots) : null;

        final dup = await db.query('sales',
            where: 'notes = ? AND (deleted IS NULL OR deleted != 1)',
            whereArgs: [noteKey],
            limit: 1);

        if (dup.isNotEmpty && !overwriteExisting) { skipped++; continue; }

        final now = DateTime.now().millisecondsSinceEpoch;
        final map = <String, dynamic>{
          'customerName': isWalkIn == 1 ? 'Khách lẻ' : (customerName.isNotEmpty ? customerName : 'Khách lẻ'),
          'phone': phone.isNotEmpty ? phone : null,
          'isWalkIn': isWalkIn,
          'walkInName': isWalkIn == 1 ? 'Khách lẻ' : null,
          'walkInPhone': null,
          'address': null,
          'productNames': productNamesStr,
          'productImeis': null,
          'itemSnapshotsJson': itemSnapshotsStr,
          'totalPrice': totalPrice,
          'totalCost': 0,
          'discount': discount,
          'paymentMethod': paymentMethod,
          'sellerName': sellerName.isNotEmpty ? sellerName : null,
          'sellerUid': null,
          'soldAt': soldAt > 0 ? soldAt : now,
          'notes': noteKey,
          'gifts': noteText.isNotEmpty ? noteText : null,
          'isInstallment': 0,
          'downPayment': 0,
          'downPaymentMethod': null,
          'loanAmount': 0,
          'cashAmount': cashAmount,
          'transferAmount': transferAmount,
          'isSynced': 0,
          'deleted': 0,
        };

        try {
          map['shopId'] = shopId;
          if (dup.isNotEmpty && overwriteExisting) {
            final id = dup.first['id'];
            await db.update('sales', map, where: 'id = ?', whereArgs: [id]);
            updated++;
          } else {
            await db.insert('sales', map);
            inserted++;
          }
        } catch (_) {
          map.remove('shopId');
          if (dup.isNotEmpty && overwriteExisting) {
            final id = dup.first['id'];
            await db.update('sales', map, where: 'id = ?', whereArgs: [id]);
            updated++;
          } else {
            await db.insert('sales', map);
            inserted++;
          }
        }
      } catch (e, st) {
        final msg = 'HĐ $invoiceCode: $e';
        errors.add(msg);
        debugPrint('KvImport sale(chi tiết) $msg\n$st');
      }
    }

    try { onProgress?.call(totalRows, totalRows); } catch (_) {}
    return KvImportResult(inserted: inserted, updated: updated, skipped: skipped, errors: errors);
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  static Future<KvImportResult> importCustomers(
    Uint8List bytes, {
    bool overwriteExisting = false,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) {
        return const KvImportResult(errors: ['Chưa đăng nhập']);
      }

      final rows = await _parseRows(bytes);
      if (rows == null) {
        return const KvImportResult(errors: ['Không đọc được file Excel']);
      }
      if (rows.length < 2) {
        return const KvImportResult(errors: ['File trống']);
      }

      final header = rows.first.map(_str).join(' ');
      if (!header.contains('Tên khách hàng')) {
        return const KvImportResult(
            errors: [
              'File không đúng định dạng — thiếu cột "Tên khách hàng"'
            ]);
      }

      final db = await _db.database;
      int inserted = 0, updated = 0, skipped = 0;
      final errors = <String>[];
      final data = rows.skip(1).toList();
      final total = data.length;

      for (int i = 0; i < total; i++) {
        try { onProgress?.call(i, total); } catch (_) {}

        try {
          final row = data[i];
          // col 3=Tên, 4=SĐT, 5=Địa chỉ, 13=Email, 16=Ghi chú, 18=Ngày tạo, 21=Tổng bán
          final name = _at(row, 3);
          final phone = _cleanPhone(_at(row, 4));
          if (name.isEmpty && phone.isEmpty) { skipped++; continue; }

          final address = _at(row, 5);
          final email = _at(row, 13);
          final rawNotes = _at(row, 16);
          final notes = rawNotes.contains('@')
              ? null
              : (rawNotes.isNotEmpty ? rawNotes : null);
          final createdAt = _dateMs(row, 18);
          final totalSpent = _int(row, 21);
          final now = DateTime.now().millisecondsSinceEpoch;

          List<Map<String, dynamic>> dup = const [];
          if (phone.isNotEmpty) {
            dup = await db.query('customers',
                where:
                    'phone = ? AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
                whereArgs: [phone, shopId],
                limit: 1);
          }

          if (dup.isNotEmpty && !overwriteExisting) { skipped++; continue; }

          if (dup.isNotEmpty && overwriteExisting) {
            final id = dup.first['id'];
            final updateMap = <String, dynamic>{
              'address': address.isNotEmpty ? address : null,
              'email': email.isNotEmpty ? email : null,
              'notes': notes,
              'totalSpent': totalSpent,
              'updatedAt': now,
              'isSynced': 0,
            };
            if (name.isNotEmpty) updateMap['name'] = name.toUpperCase();
            await db.update('customers', updateMap, where: 'id = ?', whereArgs: [id]);
            updated++;
          } else {
            await db.insert('customers', {
              'name': name.isNotEmpty ? name.toUpperCase() : phone,
              'phone': phone,
              'email': email.isNotEmpty ? email : null,
              'address': address.isNotEmpty ? address : null,
              'notes': notes,
              'createdAt': createdAt > 0 ? createdAt : now,
              'lastVisitAt': createdAt > 0 ? createdAt : now,
              'updatedAt': now,
              'totalSpent': totalSpent,
              'totalRepairs': 0,
              'totalRepairCost': 0,
              'shopId': shopId,
              'isSynced': 0,
              'deleted': 0,
              'coverAlignX': 0.0,
              'coverAlignY': 0.0,
            });
            inserted++;
          }
        } catch (e, st) {
          final msg = 'Hàng ${i + 2}: $e';
          errors.add(msg);
          debugPrint('KvImport customer $msg\n$st');
        }
      }

      try { onProgress?.call(total, total); } catch (_) {}
      return KvImportResult(
          inserted: inserted,
          updated: updated,
          skipped: skipped,
          errors: errors);
    } catch (e) {
      return KvImportResult(errors: ['Lỗi nhập khách hàng: $e']);
    }
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  static Future<KvImportResult> importSuppliers(
    Uint8List bytes, {
    bool overwriteExisting = false,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) {
        return const KvImportResult(errors: ['Chưa đăng nhập']);
      }

      final rows = await _parseRows(bytes);
      if (rows == null) {
        return const KvImportResult(errors: ['Không đọc được file Excel']);
      }
      if (rows.length < 2) {
        return const KvImportResult(errors: ['File trống']);
      }

      final header = rows.first.map(_str).join(' ');
      if (!header.contains('Tên nhà cung cấp')) {
        return const KvImportResult(
            errors: [
              'File không đúng định dạng — thiếu cột "Tên nhà cung cấp"'
            ]);
      }

      final db = await _db.database;
      int inserted = 0, updated = 0, skipped = 0;
      final errors = <String>[];
      final data = rows.skip(1).toList();
      final total = data.length;

      for (int i = 0; i < total; i++) {
        try { onProgress?.call(i, total); } catch (_) {}

        try {
          final row = data[i];
          // col 0=Mã, 1=Tên, 2=Email, 3=SĐT, 4=Địa chỉ, 11=Ghi chú, 17=Ngày tạo
          // col 0=Mã NCC, 1=Tên, 2=Email, 3=SĐT, 4=Địa chỉ, 7=Tổng mua,
          // col 8=Nợ hiện tại, 11=Ghi chú, 13=Trạng thái, 17=Ngày tạo
          final kvCode = _at(row, 0);
          final name = _at(row, 1);
          if (name.isEmpty) { skipped++; continue; }

          final email = _at(row, 2);
          final phone = _cleanPhone(_at(row, 3));
          final addr = _at(row, 4);
          final totalBuy = _int(row, 7);
          final currentDebt = _int(row, 8);
          final rawNote = _at(row, 11);
          final statusRaw = _at(row, 13);
          final activeVal = statusRaw == '1' || statusRaw.toLowerCase() == 'active' ? 1 : 1;
          final createdAt = _datetimeMs(row, 17);
          final now = DateTime.now().millisecondsSinceEpoch;
          // Compose note: preserve existing + append KV code and debt info
          final noteExtra = [
            if (kvCode.isNotEmpty) 'KV:$kvCode',
            if (currentDebt > 0) 'Nợ KV: ${currentDebt}đ',
          ].join(' | ');
          final finalNote = [
            if (rawNote.isNotEmpty) rawNote,
            if (noteExtra.isNotEmpty) noteExtra,
          ].join(' — ');

          final dup = await db.query('suppliers',
              where:
                  'UPPER(name) = UPPER(?) AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [name, shopId],
              limit: 1);

          if (dup.isNotEmpty && !overwriteExisting) { skipped++; continue; }

          if (dup.isNotEmpty && overwriteExisting) {
            final id = dup.first['id'];
            final upd = <String, dynamic>{
              'phone': phone.isNotEmpty ? phone : null,
              'email': email.isNotEmpty ? email : null,
              'address': addr.isNotEmpty ? addr : null,
              'note': finalNote.isNotEmpty ? finalNote : null,
              'updatedAt': now,
              'isSynced': 0,
            };
            if (totalBuy > 0) upd['totalAmount'] = totalBuy;
            await db.update('suppliers', upd, where: 'id = ?', whereArgs: [id]);
            updated++;
          } else {
            await db.insert('suppliers', {
              'name': name.toUpperCase(),
              'phone': phone.isNotEmpty ? phone : null,
              'email': email.isNotEmpty ? email : null,
              'address': addr.isNotEmpty ? addr : null,
              'note': finalNote.isNotEmpty ? finalNote : null,
              'shopId': shopId,
              'active': activeVal,
              'favorite': 0,
              'createdAt': createdAt > 0 ? createdAt : now,
              'updatedAt': now,
              'isSynced': 0,
              'importCount': 0,
              'totalAmount': totalBuy,
              'deleted': 0,
            });
            inserted++;
          }
        } catch (e, st) {
          final msg = 'Hàng ${i + 2}: $e';
          errors.add(msg);
          debugPrint('KvImport supplier $msg\n$st');
        }
      }

      try { onProgress?.call(total, total); } catch (_) {}
      return KvImportResult(
          inserted: inserted,
          updated: updated,
          skipped: skipped,
          errors: errors);
    } catch (e) {
      return KvImportResult(errors: ['Lỗi nhập nhà cung cấp: $e']);
    }
  }

  // ── Purchase Orders (DanhSachChiTietNhapHang) ─────────────────────────────

  static Future<KvImportResult> importPurchaseOrders(
    Uint8List bytes, {
    bool overwriteExisting = false,
    void Function(int done, int total)? onProgress,
  }) async {
    try {
      final shopId = await UserService.getCurrentShopId();
      if (shopId == null) return const KvImportResult(errors: ['Chưa đăng nhập']);

      final rows = await _parseRows(bytes);
      if (rows == null) return const KvImportResult(errors: ['Không đọc được file Excel']);
      if (rows.length < 2) return const KvImportResult(errors: ['File trống']);

      final header = rows.first.map(_str).join(' ');
      if (!header.contains('Mã nhập hàng')) {
        return const KvImportResult(
            errors: ['File không đúng định dạng — cần file DanhSachChiTietNhapHang từ KiotViet']);
      }

      // col 0=Chi nhánh, 1=Mã nhập hàng, 2=Thời gian, 3=Thời gian tạo,
      // col 5=Mã NCC, 6=Tên NCC, 7=SĐT NCC, 8=Địa chỉ NCC,
      // col 9=Người nhập, 10=Người tạo, 11=Tổng tiền hàng,
      // col 12=Giảm giá phiếu, 13=Cần trả NCC, 14=Tiền đã trả NCC,
      // col 15=Ghi chú, 17=Tổng SL, 18=Tổng mặt hàng, 19=Trạng thái,
      // col 20=Mã hàng, 21=Mã vạch, 22=Tên hàng, 23=Thương hiệu,
      // col 24=ĐVT, 25=Serial/IMEI, 26=Ghi chú hàng,
      // col 27=Đơn giá, 28=Giảm giá%, 29=Giảm giá, 30=Giá nhập,
      // col 31=Thành tiền, 32=Số lượng

      // Group rows by order code
      final orderGroups = <String, List<List<String>>>{};
      final orderSeq = <String>[];
      for (final row in rows.skip(1)) {
        final code = _at(row, 1).trim();
        if (code.isEmpty) continue;
        if (!orderGroups.containsKey(code)) {
          orderGroups[code] = [];
          orderSeq.add(code);
        }
        orderGroups[code]!.add(row);
      }

      final db = await _db.database;
      int inserted = 0, updated = 0, skipped = 0;
      final errors = <String>[];
      final total = orderSeq.length;
      final supplierTotals = <String, int>{}; // supplierName → totalAmount delta

      for (int i = 0; i < total; i++) {
        try { onProgress?.call(i, total); } catch (_) {}

        final code = orderSeq[i];
        final group = orderGroups[code]!;
        final first = group.first;

        try {
          final firestoreId = 'KV:$code';
          final supplierName = _at(first, 6).trim();
          // supplierPhone available but not stored separately (in supplier record)
          _cleanPhone(_at(first, 7));
          final importedBy = _at(first, 9).trim();
          final totalAmount = _intFromString(_at(first, 11));
          final paidAmount = _intFromString(_at(first, 14));
          final notes = _at(first, 15).trim();
          final statusRaw = _at(first, 19).trim();
          final importDate = _datetimeMs(first, 2);
          final now = DateTime.now().millisecondsSinceEpoch;

          final paymentStatus = paidAmount >= totalAmount ? 'PAID' : (paidAmount > 0 ? 'PARTIAL' : 'UNPAID');

          // Dedup by firestoreId (= KV:orderCode)
          final dup = await db.query('import_orders',
              where: 'firestoreId = ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [firestoreId],
              limit: 1);

          if (dup.isNotEmpty && !overwriteExisting) { skipped++; continue; }

          // Find or resolve supplier id
          String? supplierId;
          if (supplierName.isNotEmpty) {
            final sRows = await db.query('suppliers',
                where: 'UPPER(name) = UPPER(?) AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
                whereArgs: [supplierName, shopId],
                limit: 1);
            if (sRows.isNotEmpty) supplierId = sRows.first['id']?.toString();
          }

          // Build items
          final itemMaps = <Map<String, dynamic>>[];
          int totalQty = 0;
          for (int j = 0; j < group.length; j++) {
            final row = group[j];
            final pName = _at(row, 22);
            if (pName.isEmpty) continue;
            final brand = _at(row, 23);
            final sku = _at(row, 20);
            final imei = _at(row, 25);
            final unit = _at(row, 24);
            final qty = _int(row, 32);
            final costPrice = _intFromString(_at(row, 30));
            final lineTotal = _intFromString(_at(row, 31));
            final itemNote = _at(row, 26);
            totalQty += qty > 0 ? qty : 1;

            final details = _parseProductNameDetails(pName);

            itemMaps.add({
              'firestoreId': '$firestoreId#$j',
              'importOrderFirestoreId': firestoreId,
              'productName': pName.toUpperCase(),
              'productBrand': brand.isNotEmpty ? brand.toUpperCase() : null,
              'productModel': details['model'],
              'imei': imei.isNotEmpty ? imei : null,
              'sku': sku.isNotEmpty ? sku : null,
              'quantity': qty > 0 ? qty : 1,
              'unit': unit.isNotEmpty ? unit : null,
              'costPrice': costPrice,
              'totalAmount': lineTotal > 0 ? lineTotal : costPrice * (qty > 0 ? qty : 1),
              'color': details['color'],
              'capacity': details['capacity'],
              'productType': _guessType('', imei.isNotEmpty),
              'notes': itemNote.isNotEmpty ? itemNote : null,
              'shopId': shopId,
              'isSynced': 0,
              'deleted': 0,
            });
          }

          final orderMap = <String, dynamic>{
            'firestoreId': firestoreId,
            'shopId': shopId,
            'orderCode': code,
            'supplierId': supplierId,
            'supplierName': supplierName.isNotEmpty ? supplierName.toUpperCase() : null,
            'totalQuantity': totalQty,
            'totalAmount': totalAmount,
            'paymentMethod': 'TIỀN MẶT',
            'paymentStatus': paymentStatus,
            'paidAmount': paidAmount,
            'status': statusRaw.isNotEmpty ? statusRaw.toUpperCase() : 'CONFIRMED',
            'importDate': importDate > 0 ? importDate : now,
            'importedBy': importedBy.isNotEmpty ? importedBy : null,
            'notes': notes.isNotEmpty ? notes : null,
            'createdAt': importDate > 0 ? importDate : now,
            'updatedAt': now,
            'isSynced': 0,
            'deleted': 0,
          };

          if (dup.isNotEmpty && overwriteExisting) {
            final orderId = dup.first['id'];
            await db.update('import_orders', orderMap..remove('firestoreId'),
                where: 'id = ?', whereArgs: [orderId]);
            // Delete old items before re-inserting
            await db.delete('import_order_items',
                where: 'importOrderFirestoreId = ?', whereArgs: [firestoreId]);
            updated++;
          } else {
            await db.insert('import_orders', orderMap);
            inserted++;
          }

          // Insert items
          for (final item in itemMaps) {
            try {
              await db.insert('import_order_items', item,
                  conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (_) {}

            // Update matching product: set supplier + cost if missing
            final imei = item['imei'] as String?;
            final costPrice = item['costPrice'] as int;
            if (imei != null && imei.isNotEmpty) {
              try {
                final prods = await db.query('products',
                    where: 'imei = ? AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
                    whereArgs: [imei, shopId], limit: 1);
                if (prods.isNotEmpty) {
                  final prod = prods.first;
                  final upd = <String, dynamic>{};
                  if (supplierName.isNotEmpty && (prod['supplier'] == null || (prod['supplier'] as String).isEmpty)) {
                    upd['supplier'] = supplierName.toUpperCase();
                  }
                  if (costPrice > 0 && ((prod['cost'] as int?) ?? 0) == 0) {
                    upd['cost'] = costPrice;
                  }
                  if (upd.isNotEmpty) {
                    upd['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
                    upd['isSynced'] = 0;
                    await db.update('products', upd,
                        where: 'id = ?', whereArgs: [prod['id']]);
                  }
                }
              } catch (_) {}
            }
          }

          // Track supplier totals for batch update
          if (supplierName.isNotEmpty) {
            supplierTotals[supplierName] =
                (supplierTotals[supplierName] ?? 0) + totalAmount;
          }
        } catch (e, st) {
          errors.add('PN $code: $e');
          debugPrint('KvImport purchaseOrder $code: $e\n$st');
        }
      }

      // Batch update supplier importCount + totalAmount
      for (final entry in supplierTotals.entries) {
        try {
          final sRows = await db.query('suppliers',
              where: 'UPPER(name) = UPPER(?) AND shopId = ? AND (deleted IS NULL OR deleted != 1)',
              whereArgs: [entry.key, shopId], limit: 1);
          if (sRows.isNotEmpty) {
            final sid = sRows.first['id'];
            final currentCount = await db.rawQuery(
                'SELECT COUNT(*) as c FROM import_orders WHERE supplierId = ? AND (deleted IS NULL OR deleted != 1)',
                [sid.toString()]);
            final count = (currentCount.first['c'] as int?) ?? 0;
            await db.update('suppliers', {
              'importCount': count,
              'totalAmount': entry.value,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
              'isSynced': 0,
            }, where: 'id = ?', whereArgs: [sid]);
          }
        } catch (_) {}
      }

      try { onProgress?.call(total, total); } catch (_) {}
      return KvImportResult(inserted: inserted, updated: updated, skipped: skipped, errors: errors);
    } catch (e) {
      return KvImportResult(errors: ['Lỗi nhập phiếu nhập hàng: $e']);
    }
  }

  // ── Core parser ───────────────────────────────────────────────────────────

  static Future<List<List<String>>?> _parseRows(Uint8List bytes) async {
    try {
      return await compute(_kvParseXlsx, bytes);
    } catch (e, st) {
      debugPrint('KvImport _parseRows error: $e\n$st');
      // Rethrow so the import functions show the actual error message in UI
      rethrow;
    }
  }

  // ── Row helpers ───────────────────────────────────────────────────────────

  static String _at(List<String> row, int col) {
    if (col >= row.length) return '';
    return row[col].trim();
  }

  static int _int(List<String> row, int col) {
    if (col >= row.length) return 0;
    final s = row[col].trim().replaceAll(RegExp(r'[,\s]'), '');
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? (double.tryParse(s)?.round() ?? 0);
  }

  /// Excel stores dates as serial numbers (days since 1899-12-30). Date only.
  static int _dateMs(List<String> row, int col) {
    if (col >= row.length) return 0;
    final s = row[col].trim();
    if (s.isEmpty) return 0;
    final n = double.tryParse(s);
    if (n != null && n >= 1 && n < 2958466) {
      return DateTime(1899, 12, 30)
          .add(Duration(days: n.toInt()))
          .millisecondsSinceEpoch;
    }
    return 0;
  }

  /// Excel datetime serial → milliseconds, preserving time-of-day fraction.
  static int _datetimeMs(List<String> row, int col) {
    if (col >= row.length) return 0;
    final s = row[col].trim();
    if (s.isEmpty) return 0;
    final n = double.tryParse(s);
    if (n != null && n >= 1 && n < 2958466) {
      final days = n.toInt();
      final ms = ((n - days) * 24 * 3600 * 1000).round();
      return DateTime(1899, 12, 30)
          .add(Duration(days: days, milliseconds: ms))
          .millisecondsSinceEpoch;
    }
    return 0;
  }

  /// Parse a number string that may contain decimal (e.g. "18390000.0000") → int.
  static int _intFromString(String s) {
    final cleaned = s.trim().replaceAll(RegExp(r'[,\s]'), '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? (double.tryParse(cleaned)?.round() ?? 0);
  }

  static String _str(String cell) => cell.trim();

  // ── Business logic helpers ────────────────────────────────────────────────

  static String _cleanPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('84') && digits.length == 11) {
      return '0${digits.substring(2)}';
    }
    if (digits.length >= 9 && digits.length <= 12) return digits;
    return '';
  }

  static String _guessCondition(String group, String name) {
    final g = group.toLowerCase();
    final n = name.toLowerCase();
    if (g.contains('99') || n.contains('99%')) return '99%';
    if (g.contains('98') || n.contains('98%')) return '98%';
    if (g.contains('97') || n.contains('97%')) return '97%';
    if (g.contains('cũ') || g.contains('cu') || n.contains('cũ')) return 'Cũ';
    return 'Mới';
  }

  static String _guessType(String group, bool useImei) {
    final g = group.toLowerCase();
    if (g.contains('linh kiện') || g.contains('linh kien')) return 'LINH_KIEN';
    if (g.contains('pk ') || g.contains('phụ kiện') ||
        g.contains('phu kien')) { return 'PHU_KIEN'; }
    return 'DIEN_THOAI';
  }

  static String _guessBrand(String name) {
    final n = name.toUpperCase();
    for (final b in [
      'APPLE', 'IPHONE', 'SAMSUNG', 'OPPO', 'XIAOMI', 'VIVO',
      'REALME', 'TECNO', 'INFINIX', 'NOKIA', 'HUAWEI',
      'LG', 'SONY', 'MOTOROLA', 'ASUS', 'ONEPLUS',
    ]) {
      if (n.contains(b)) return b == 'IPHONE' ? 'APPLE' : b;
    }
    return '';
  }

  static Map<String, String?> _parseProductNameDetails(String name) {
    final n = name.toUpperCase();
    String? model;
    String? capacity;
    String? color;

    // Capacity: RAM/Storage (8G/128G) → take storage; or standard values
    final ramStorage = RegExp(r'\b\d+G(?:B)?/(\d+G(?:B)?)\b').firstMatch(n);
    if (ramStorage != null) {
      capacity = ramStorage.group(1)!.replaceAll('GB', 'G');
    } else {
      final storage = RegExp(r'\b(16G|32G|64G|128G|256G|512G|1T(?:B)?|2T(?:B)?)\b').firstMatch(n);
      if (storage != null) capacity = storage.group(1)!.replaceAll('TB', 'T');
    }

    // iPhone models — longer keys checked first to avoid partial matches
    if (n.contains('IPHONE')) {
      const modelMap = {
        'IPHONE 16PROMAX': '16 Pro Max', 'IPHONE16PROMAX': '16 Pro Max',
        'IPHONE 16PRO': '16 Pro',       'IPHONE16PRO': '16 Pro',
        'IPHONE 16PLUS': '16 Plus',     'IPHONE16PLUS': '16 Plus',
        'IPHONE 16': '16',
        'IPHONE 15PROMAX': '15 Pro Max','IPHONE15PROMAX': '15 Pro Max',
        'IPHONE 15PRO': '15 Pro',       'IPHONE15PRO': '15 Pro',
        'IPHONE 15PLUS': '15 Plus',     'IPHONE15PLUS': '15 Plus',
        'IPHONE 15': '15',
        'IPHONE 14PROMAX': '14 Pro Max','IPHONE14PROMAX': '14 Pro Max',
        'IPHONE 14PRO': '14 Pro',       'IPHONE14PRO': '14 Pro',
        'IPHONE 14PLUS': '14 Plus',     'IPHONE14PLUS': '14 Plus',
        'IPHONE 14': '14',
        'IPHONE 13PROMAX': '13 Pro Max','IPHONE13PROMAX': '13 Pro Max',
        'IPHONE 13PRO': '13 Pro',       'IPHONE13PRO': '13 Pro',
        'IPHONE 13MINI': '13 Mini',     'IPHONE13MINI': '13 Mini',
        'IPHONE 13': '13',
        'IPHONE 12PROMAX': '12 Pro Max','IPHONE12PROMAX': '12 Pro Max',
        'IPHONE 12PRO': '12 Pro',       'IPHONE12PRO': '12 Pro',
        'IPHONE 12MINI': '12 Mini',     'IPHONE12MINI': '12 Mini',
        'IPHONE 12': '12',
        'IPHONE 11PROMAX': '11 Pro Max','IPHONE11PROMAX': '11 Pro Max',
        'IPHONE 11PRO': '11 Pro',       'IPHONE11PRO': '11 Pro',
        'IPHONE 11': '11',
        'IPHONE XSMAX': 'XS Max',       'IPHONE XSM': 'XS Max',
        'IPHONE XS': 'XS',
        'IPHONE XR': 'XR',
        'IPHONE 8PLUS': '8 Plus',       'IPHONE8PLUS': '8 Plus',
        'IPHONE 8': '8',
        'IPHONE 7PLUS': '7 Plus',       'IPHONE7PLUS': '7 Plus',
        'IPHONE 7': '7',
        'IPHONE SE': 'SE',
        'IPHONE X': 'X',
      };
      final sorted = modelMap.keys.toList()..sort((a, b) => b.length - a.length);
      for (final key in sorted) {
        if (n.contains(key)) { model = modelMap[key]; break; }
      }
    } else if (n.contains('IPAD')) {
      for (final m in ['IPAD PRO', 'IPAD AIR', 'IPAD MINI']) {
        if (n.contains(m)) {
          model = m[0] + m.substring(1).toLowerCase();
          break;
        }
      }
      model ??= 'iPad';
    } else if (n.contains('SAMSUNG')) {
      final sm = RegExp(r'SAMSUNG\s+([A-Z]\d+\S*)').firstMatch(n);
      if (sm != null) model = 'Samsung ${sm.group(1)!.trim()}';
    } else if (n.contains('OPPO')) {
      final om = RegExp(r'OPPO\s+(\S+)').firstMatch(n);
      if (om != null) model = 'Oppo ${om.group(1)!.trim()}';
    } else if (n.contains('XIAOMI')) {
      final xm = RegExp(r'XIAOMI\s+(\S+(?:\s+\S+)?)').firstMatch(n);
      if (xm != null) model = 'Xiaomi ${xm.group(1)!.trim()}';
    }

    // Color — longer names first (XANH RÊU before XANH)
    const colorMap = {
      'XANH RÊU': 'Xanh Rêu', 'XANH LÁ': 'Xanh Lá',
      'VÀNG': 'Vàng',    'GOLD': 'Vàng',       'YELLOW': 'Vàng',
      'ĐEN': 'Đen',      'BLACK': 'Đen',        'MIDNIGHT': 'Đen',
      'TRẮNG': 'Trắng',  'WHITE': 'Trắng',      'STARLIGHT': 'Trắng',
      'XANH': 'Xanh',    'BLUE': 'Xanh',        'GREEN': 'Xanh',
      'ĐỎ': 'Đỏ',        'RED': 'Đỏ',
      'TÍM': 'Tím',      'PURPLE': 'Tím',
      'HỒNG': 'Hồng',    'PINK': 'Hồng',
      'XÁM': 'Xám',      'GRAY': 'Xám',         'SILVER': 'Xám',
      'CAM': 'Cam',      'ORANGE': 'Cam',
      'NÂU': 'Nâu',
      'NATURAL': 'Natural', 'DESERT': 'Desert', 'TITANIUM': 'Titanium',
    };
    final sortedColors = colorMap.keys.toList()..sort((a, b) => b.length - a.length);
    for (final c in sortedColors) {
      if (n.contains(c)) { color = colorMap[c]; break; }
    }

    return {'model': model, 'capacity': capacity, 'color': color};
  }
}
