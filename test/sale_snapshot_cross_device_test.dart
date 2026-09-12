import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/constants/product_constants.dart';
import 'package:quanlyshop/data/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Sự cố 2026-09-12: đơn bán "CÓC SẠC / ỐP LƯNG / CƯỜNG LỰC" tạo trên máy
/// KIMHUE205A, snapshot ghi `productId` 517/512/514 (số thứ tự SQLite của máy
/// đó). Trên Oppo chủ shop, id 517 = "IPAD GEN 10", 512/514 = "IPHONE 14PRO"
/// → bấm vào món đã bán mở ra sản phẩm khác; iPhone lại ra món khác nữa.
/// `productFirestoreId` mới là khoá dùng chung giữa các máy.
///
/// Snapshot dưới đây chép nguyên từ SQLite máy thật.
const _realSnapshot = <String, dynamic>{
  'productId': 517,
  'productFirestoreId': 'yZMMPgRX5n68DRm0kJBa',
  'productName': 'CÓC SẠC ANKER 30W',
  'productImei': 'PKx1',
  'quantity': 1,
  'unitPrice': 380000,
  'salePrice': 380000,
  'unitCost': 115000,
  'lineAmount': 380000,
  'lineCostTotal': 115000,
  'exactPricing': true,
};

void main() {
  group('ProductConstants.isSameProductName', () {
    test('cùng tên, khác hoa/thường/dấu/khoảng trắng ⇒ true', () {
      expect(
        ProductConstants.isSameProductName('CÓC SẠC ANKER 30W', 'coc sac anker 30w'),
        isTrue,
      );
      expect(
        ProductConstants.isSameProductName('Ốp lưng  Magatic', 'ỐP LƯNG MAGATIC'),
        isTrue,
      );
    });

    test('bỏ hậu tố số lượng " x2" từ productNames của đơn bán', () {
      expect(
        ProductConstants.isSameProductName('ỐP LƯNG MAGATIC', 'ỐP LƯNG MAGATIC X2'),
        isTrue,
      );
    });

    test('khác tên ⇒ false; rỗng không bảo chứng ⇒ false', () {
      expect(
        ProductConstants.isSameProductName('IPAD GEN 10 HỒNG 99%', 'CÓC SẠC ANKER 30W'),
        isFalse,
      );
      expect(ProductConstants.isSameProductName('', ''), isFalse);
      expect(ProductConstants.isSameProductName('CÓC SẠC', ''), isFalse);
    });
  });

  group('DBHelper.snapshotLineIsProduct — vá giá vốn vào đơn cũ', () {
    test('sản phẩm có cloud id: chỉ khớp khi cloud id trùng, KHÔNG tin id cục bộ', () {
      // Máy chủ shop: id 517 là IPAD, cloud id khác → không phải món này.
      expect(
        DBHelper.snapshotLineIsProduct(
          _realSnapshot,
          productId: 517,
          productFirestoreId: 'product_1736528400000_RQQX126CT4_1243',
          productName: 'IPAD GEN 10 HỒNG 99%',
        ),
        isFalse,
      );
      // Cùng máy đó, CÓC SẠC thật có id 863 nhưng cloud id trùng → đúng món.
      expect(
        DBHelper.snapshotLineIsProduct(
          _realSnapshot,
          productId: 863,
          productFirestoreId: 'yZMMPgRX5n68DRm0kJBa',
          productName: 'CÓC SẠC ANKER 30W',
        ),
        isTrue,
      );
    });

    test('dòng snapshot cũ không có cloud id: id cục bộ + tên phải cùng khớp', () {
      final legacy = Map<String, dynamic>.from(_realSnapshot)
        ..remove('productFirestoreId');
      expect(
        DBHelper.snapshotLineIsProduct(
          legacy,
          productId: 517,
          productFirestoreId: '',
          productName: 'CÓC SẠC ANKER 30W',
        ),
        isTrue,
      );
      // Cùng id 517 nhưng là IPAD trên máy khác → không được vá nhầm.
      expect(
        DBHelper.snapshotLineIsProduct(
          legacy,
          productId: 517,
          productFirestoreId: '',
          productName: 'IPAD GEN 10 HỒNG 99%',
        ),
        isFalse,
      );
      // Sản phẩm CÓ cloud id nhưng dòng cũ không có → không thể khẳng định.
      expect(
        DBHelper.snapshotLineIsProduct(
          legacy,
          productId: 517,
          productFirestoreId: 'yZMMPgRX5n68DRm0kJBa',
          productName: 'CÓC SẠC ANKER 30W',
        ),
        isFalse,
      );
    });
  });

  group('getSalesByProductId — mẫu LIKE khớp JSON jsonEncode sinh ra', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE sales (id INTEGER PRIMARY KEY, itemSnapshotsJson TEXT)',
      );
      await db.insert('sales', {
        'id': 4296,
        'itemSnapshotsJson': jsonEncode([_realSnapshot]),
      });
      // Đơn của máy khác, cùng số 517 nhưng là IPAD.
      await db.insert('sales', {
        'id': 4297,
        'itemSnapshotsJson': jsonEncode([
          {
            'productId': 517,
            'productFirestoreId': 'product_1736528400000_RQQX126CT4_1243',
            'productName': 'IPAD GEN 10 HỒNG 99%',
            'quantity': 1,
            'unitCost': 0,
          },
        ]),
      });
    });

    tearDown(() => db.close());

    test('tìm theo cloud id chỉ ra đúng đơn có món đó', () async {
      final rows = await db.query(
        'sales',
        where: 'itemSnapshotsJson LIKE ?',
        whereArgs: ['%"productFirestoreId":"yZMMPgRX5n68DRm0kJBa"%'],
      );
      expect(rows.map((r) => r['id']), [4296]);
    });

    test('tìm theo id cục bộ (cách cũ) ra CẢ HAI đơn — chính là lỗi', () async {
      final rows = await db.query(
        'sales',
        where: 'itemSnapshotsJson LIKE ?',
        whereArgs: ['%"productId":517%'],
      );
      expect(rows.length, 2);
    });
  });
}
