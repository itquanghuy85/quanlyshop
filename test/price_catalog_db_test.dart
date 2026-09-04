import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/price_catalog_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kiểm thử tầng SQLite của danh mục giá trên **CSDL thật** (sqflite ffi).
///
/// Cố tình KHÔNG đi qua `DBHelper`: mọi hàm ở đó gọi
/// `UserService.getCurrentShopId()` → FirebaseAuth, mà môi trường test không
/// có Firebase (xem các test khác đang đỏ vì lý do này). Thay vào đó ta chạy
/// ĐÚNG câu DDL + ĐÚNG logic upsert mà `db_helper.dart` dùng, để chắc chắn:
///   • DDL bảng `price_catalog_items` (v110) thực sự hợp lệ và chạy được;
///   • ràng buộc/chỉ mục không làm kẹt đường sync (khoá trùng KHÔNG nổ);
///   • upsert nhận diện đúng bản ghi cũ ⇒ nhập lại không đẻ dòng trùng.

/// Bản sao 1:1 của `DBHelper._createPriceCatalogTable`.
/// Lệch nhau là test này phải đỏ — đó là mục đích.
const _ddl = '''
      CREATE TABLE IF NOT EXISTS price_catalog_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestoreId TEXT UNIQUE,
        importKey TEXT,
        itemName TEXT,
        brand TEXT,
        model TEXT,
        partType TEXT,
        sku TEXT,
        unit TEXT,
        supplier TEXT,
        lastCost INTEGER DEFAULT 0,
        avgCost INTEGER DEFAULT 0,
        minCost INTEGER DEFAULT 0,
        maxCost INTEGER DEFAULT 0,
        customerPrice INTEGER DEFAULT 0,
        lastInvoiceNo TEXT,
        lastInvoiceDate TEXT,
        note TEXT,
        sourceType TEXT DEFAULT 'supplier_invoice_excel',
        needsReview INTEGER DEFAULT 0,
        reviewNote TEXT,
        confidence TEXT,
        costHistoryJson TEXT,
        createdAt INTEGER,
        updatedAt INTEGER,
        deleted INTEGER DEFAULT 0,
        shopId TEXT,
        isSynced INTEGER DEFAULT 0
      )
    ''';

Future<Database> _openDb() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(_ddl);
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_price_catalog_shop_key ON price_catalog_items(shopId, importKey)',
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_price_catalog_updatedAt ON price_catalog_items(updatedAt)',
  );
  return db;
}

/// Bản sao logic ghi của `DBHelper.savePriceCatalogItem` (khớp firestoreId →
/// khớp (shopId, importKey) → insert).
Future<int> _save(Database db, PriceCatalogItem item, String shopId) async {
  final data = item.copyWith(shopId: shopId).toMap()..remove('id');

  final fid = item.firestoreId;
  if (fid != null && fid.isNotEmpty) {
    final hit = await db.query(
      'price_catalog_items',
      columns: ['id'],
      where: 'firestoreId = ?',
      whereArgs: [fid],
      limit: 1,
    );
    if (hit.isNotEmpty) {
      final id = hit.first['id'] as int;
      await db.update(
        'price_catalog_items',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
  }

  final byKey = await db.query(
    'price_catalog_items',
    columns: ['id'],
    where: 'shopId = ? AND importKey = ?',
    whereArgs: [shopId, item.importKey],
    limit: 1,
  );
  if (byKey.isNotEmpty) {
    final id = byKey.first['id'] as int;
    await db.update(
      'price_catalog_items',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }
  return db.insert('price_catalog_items', data);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  TestWidgetsFlutterBinding.ensureInitialized();

  group('price_catalog_items — schema v110 chạy thật', () {
    test('DDL hợp lệ và tạo đủ 28 cột đúng tên', () async {
      final db = await _openDb();
      final cols = await db.rawQuery('PRAGMA table_info(price_catalog_items)');
      final names = cols.map((c) => c['name'] as String).toSet();

      // Đủ các trường yêu cầu của tính năng.
      for (final required in [
        'id', 'firestoreId', 'importKey', 'itemName', 'brand', 'model',
        'partType', 'sku', 'unit', 'supplier', 'lastCost', 'avgCost',
        'minCost', 'maxCost', 'customerPrice', 'lastInvoiceNo',
        'lastInvoiceDate', 'note', 'sourceType', 'needsReview', 'reviewNote',
        'confidence', 'costHistoryJson', 'createdAt', 'updatedAt', 'deleted',
        'shopId', 'isSynced',
      ]) {
        expect(names, contains(required), reason: 'thiếu cột $required');
      }
      await db.close();
    });

    test('toMap() khớp 100% cột của bảng — không rơi field khi ghi', () async {
      final db = await _openDb();
      final cols = (await db.rawQuery('PRAGMA table_info(price_catalog_items)'))
          .map((c) => c['name'] as String)
          .toSet();

      const item = PriceCatalogItem(importKey: 'pc|k', itemName: 'X');
      final mapKeys = item.toMap().keys.toSet()..remove('id');
      // Mọi khoá của toMap phải là cột thật, nếu không `_filterToTableColumns`
      // sẽ âm thầm cắt mất dữ liệu khi lưu.
      expect(mapKeys.difference(cols), isEmpty,
          reason: 'toMap có khoá không phải cột: ${mapKeys.difference(cols)}');
      await db.close();
    });
  });

  group('Ghi / đọc / chống trùng trên CSDL thật', () {
    test('lưu rồi đọc lại nguyên vẹn, kể cả lịch sử giá', () async {
      final db = await _openDb();
      const item = PriceCatalogItem(
        importKey: 'pc|iphone|pin iphone 13||pin',
        itemName: 'Pin iPhone 13',
        brand: 'iPhone',
        partType: 'Pin',
        lastCost: 310000,
        avgCost: 305000,
        minCost: 300000,
        maxCost: 320000,
        customerPrice: 550000,
        lastInvoiceNo: 'HD014650',
        lastInvoiceDate: '2026-08-30',
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
      await _save(db, item, 'shopA');

      final rows = await db.query('price_catalog_items');
      expect(rows.length, 1);
      final back = PriceCatalogItem.fromMap(rows.first);
      expect(back.itemName, 'Pin iPhone 13');
      expect(back.lastCost, 310000);
      expect(back.customerPrice, 550000);
      expect(back.needsReview, isTrue);
      expect(back.lastInvoiceNo, 'HD014650');
      expect(back.costHistory.single.qty, 3);
      await db.close();
    });

    test('NHẬP LẠI cùng khoá ⇒ cập nhật, KHÔNG đẻ dòng thứ hai', () async {
      final db = await _openDb();
      const a = PriceCatalogItem(
        importKey: 'pc|k',
        itemName: 'Pin',
        lastCost: 300000,
      );
      final id1 = await _save(db, a, 'shopA');
      final id2 = await _save(
        db,
        a.copyWith(lastCost: 350000, customerPrice: 600000),
        'shopA',
      );

      expect(id1, id2, reason: 'phải ghi đè đúng bản ghi cũ');
      final rows = await db.query('price_catalog_items');
      expect(rows.length, 1, reason: 'không được tạo bản ghi trùng');
      expect(rows.first['lastCost'], 350000);
      expect(rows.first['customerPrice'], 600000);
      await db.close();
    });

    test('cùng khoá nhưng KHÁC shop ⇒ 2 bản ghi riêng (cách ly tenant)',
        () async {
      final db = await _openDb();
      const item = PriceCatalogItem(importKey: 'pc|k', itemName: 'Pin');
      await _save(db, item, 'shopA');
      await _save(db, item, 'shopB');

      final rows = await db.query('price_catalog_items');
      expect(rows.length, 2);
      final shops =
          rows.map((r) => r['shopId'] as String?).whereType<String>().toSet();
      expect(shops, {'shopA', 'shopB'});
      await db.close();
    });

    test('KHOÁ TRÙNG khác firestoreId KHÔNG nổ ràng buộc (không kẹt sync)',
        () async {
      // Đây là lý do `importKey` cố ý KHÔNG đặt UNIQUE: bản ghi từ cloud có
      // thể trùng khoá với bản tạo offline. Nếu UNIQUE, insert sẽ ném và hàng
      // đợi đồng bộ kẹt vĩnh viễn.
      final db = await _openDb();
      await db.insert('price_catalog_items', {
        'firestoreId': 'pcat_local',
        'importKey': 'pc|k',
        'itemName': 'Pin (offline)',
        'shopId': 'shopA',
      });
      await db.insert('price_catalog_items', {
        'firestoreId': 'pcat_cloud',
        'importKey': 'pc|k',
        'itemName': 'Pin (cloud)',
        'shopId': 'shopA',
      });
      expect((await db.query('price_catalog_items')).length, 2);
      await db.close();
    });

    test('firestoreId trùng ⇒ CHẶN bằng UNIQUE (không nhân đôi 1 doc)',
        () async {
      final db = await _openDb();
      await db.insert('price_catalog_items', {
        'firestoreId': 'pcat_same',
        'importKey': 'pc|a',
        'itemName': 'A',
        'shopId': 'shopA',
      });
      await expectLater(
        db.insert('price_catalog_items', {
          'firestoreId': 'pcat_same',
          'importKey': 'pc|b',
          'itemName': 'B',
          'shopId': 'shopA',
        }),
        throwsA(isA<DatabaseException>()),
      );
      await db.close();
    });

    test('xoá mềm: bản ghi còn nguyên, truy vấn thường lọc bỏ', () async {
      final db = await _openDb();
      await _save(
        db,
        const PriceCatalogItem(importKey: 'pc|k', itemName: 'Pin'),
        'shopA',
      );
      await db.update(
        'price_catalog_items',
        {'deleted': 1, 'isSynced': 0},
        where: 'importKey = ?',
        whereArgs: ['pc|k'],
      );

      final alive = await db.query(
        'price_catalog_items',
        where: 'shopId = ? AND (deleted = 0 OR deleted IS NULL)',
        whereArgs: ['shopA'],
      );
      expect(alive, isEmpty, reason: 'đã xoá mềm thì không hiện ở bảng giá');
      expect((await db.query('price_catalog_items')).length, 1,
          reason: 'bản ghi phải còn để đồng bộ trạng thái xoá sang máy khác');
      await db.close();
    });

    test('costHistory dạng List (Firestore array) chuẩn hoá được về JSON',
        () async {
      final db = await _openDb();
      // Firestore trả array, SQLite chỉ nhận TEXT — đúng nhánh chuẩn hoá của
      // `upsertPriceCatalogItem`.
      final raw = [
        {'fp': 'a', 'p': 310000, 'q': 3, 'no': 'HD014650', 'd': '2026-08-30'},
      ];
      await db.insert('price_catalog_items', {
        'firestoreId': 'pcat_x',
        'importKey': 'pc|k',
        'itemName': 'Pin',
        'shopId': 'shopA',
        'costHistoryJson': jsonEncode(raw),
        'needsReview': 1,
      });
      final back = PriceCatalogItem.fromMap(
        (await db.query('price_catalog_items')).first,
      );
      expect(back.costHistory.single.unitCost, 310000);
      expect(back.costHistory.single.qty, 3);
      await db.close();
    });
  });
}
