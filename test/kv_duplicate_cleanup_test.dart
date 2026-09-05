import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/kiotviet_excel_import_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kiểm thử bản vá sự cố 2026-09-05: 2.245 hoá đơn KiotViet bị nhập TRÙNG,
/// thổi doanh thu 35,6 tỷ.
///
/// Gốc rễ: `sync_service` sinh doc id `sale_<soldAt>_<phone>_<s.id>` với `s.id`
/// là số thứ tự SQLite **của riêng từng máy** ⇒ cùng hoá đơn import ở 2 máy ra
/// 2 doc id ⇒ 2 document trên cloud.
///
/// Test này KHÔNG đi qua `DBHelper`/`KvDuplicateCleanupService.apply()` vì cả
/// hai đều cần Firebase (xem ghi chú cùng kiểu ở `price_catalog_db_test.dart`).
/// Thay vào đó chạy ĐÚNG câu truy vấn gom nhóm + ĐÚNG quy tắc chọn bản giữ lại
/// mà service dùng, trên SQLite thật.
void main() {
  group('kvSaleDocId — doc id tất định (vá gốc rễ)', () {
    test('cùng shop + cùng mã hoá đơn ⇒ luôn ra cùng id', () {
      final a = KiotVietExcelImportService.kvSaleDocId('shopA', 'HD006758');
      final b = KiotVietExcelImportService.kvSaleDocId('shopA', 'HD006758');
      expect(a, b);
      expect(a, 'kv_shopA_HD006758');
    });

    test('hai máy khác nhau vẫn ra CÙNG id — đây chính là lỗi cũ', () {
      // Trước bản vá, id là sale_<soldAt>_<phone>_<localId>; localId khác nhau
      // giữa 2 máy nên sinh ra 2 document. Nay id không còn phụ thuộc máy.
      const shop = 'iXJOFySNBjPoJkszstVQWzmEzip2';
      final mayA = KiotVietExcelImportService.kvSaleDocId(shop, 'HD006758');
      final mayB = KiotVietExcelImportService.kvSaleDocId(shop, 'HD006758');
      expect(mayA, mayB);
    });

    test('hai shop khác nhau KHÔNG đụng id (sales là collection dùng chung)', () {
      final a = KiotVietExcelImportService.kvSaleDocId('shopA', 'HD001');
      final b = KiotVietExcelImportService.kvSaleDocId('shopB', 'HD001');
      expect(a, isNot(b));
    });

    test('giữ dấu chấm trong mã thật (HD007168.02) và bỏ ký tự lạ', () {
      expect(
        KiotVietExcelImportService.kvSaleDocId('s', 'HD007168.02'),
        'kv_s_HD007168.02',
      );
      // Firestore không cho '/' trong doc id.
      expect(
        KiotVietExcelImportService.kvSaleDocId('s', 'HD/01 A'),
        'kv_s_HD_01_A',
      );
      expect(
        KiotVietExcelImportService.kvSaleDocId('s', 'HD001'),
        isNot(contains('/')),
      );
    });

    test('cắt khoảng trắng thừa hai đầu mã', () {
      expect(
        KiotVietExcelImportService.kvSaleDocId('s', '  HD001  '),
        'kv_s_HD001',
      );
    });
  });

  group('Chọn bản trùng cần dọn (SQLite thật)', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute('''
        CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firestoreId TEXT,
          notes TEXT,
          totalPrice INTEGER,
          soldAt INTEGER,
          deleted INTEGER DEFAULT 0
        )
      ''');
    });

    tearDown(() async => db.close());

    Future<void> add(
      String? notes,
      String? fid,
      int price, {
      int deleted = 0,
    }) async {
      await db.insert('sales', {
        'firestoreId': fid,
        'notes': notes,
        'totalPrice': price,
        'soldAt': 1767627673970,
        'deleted': deleted,
      });
    }

    /// Bản sao 1:1 truy vấn của `KvDuplicateCleanupService._loadGroups`.
    Future<Map<String, List<Map<String, Object?>>>> loadGroups() async {
      final rows = await db.query(
        'sales',
        columns: ['id', 'firestoreId', 'notes', 'totalPrice', 'soldAt'],
        where: 'notes LIKE ? AND (deleted IS NULL OR deleted = 0)',
        whereArgs: ['KV:%'],
        orderBy: 'id ASC',
      );
      final groups = <String, List<Map<String, Object?>>>{};
      for (final r in rows) {
        final code = (r['notes'] as String?) ?? '';
        if (!code.startsWith('KV:')) continue;
        groups.putIfAbsent(code, () => []).add(r);
      }
      return groups;
    }

    List<Map<String, Object?>> victims(
      Map<String, List<Map<String, Object?>>> g,
    ) {
      final out = <Map<String, Object?>>[];
      for (final rows in g.values) {
        if (rows.length < 2) continue;
        out.addAll(rows.skip(1));
      }
      return out;
    }

    test('đúng hình dạng dữ liệu thật: 2 bản, khác firestoreId, giống hệt', () async {
      // Chính là cặp đo được trên máy chủ shop ngày 05/09/2026.
      await add('KV:HD006758', 'sale_1767627673970_0968704453_1745', 75340000);
      await add('KV:HD006758', 'sale_1767627673970_0968704453_8463', 75340000);

      final g = await loadGroups();
      expect(g.length, 1, reason: 'chỉ có 1 hoá đơn thật');
      final v = victims(g);
      expect(v.length, 1, reason: 'thừa đúng 1 bản');
      expect(v.first['id'], 2, reason: 'giữ bản id nhỏ nhất, xoá bản sau');
      expect(v.first['totalPrice'], 75340000);
    });

    test('hoá đơn không trùng thì KHÔNG bị đụng tới', () async {
      await add('KV:HD001', 'a', 1000);
      await add('KV:HD002', 'b', 2000);
      expect(victims(await loadGroups()), isEmpty);
    });

    test('bỏ qua bản đã xoá mềm — dọn lại lần 2 không xoá nhầm', () async {
      await add('KV:HD001', 'a', 1000);
      await add('KV:HD001', 'b', 1000, deleted: 1);
      expect(
        victims(await loadGroups()),
        isEmpty,
        reason: 'bản đã xoá không được tính là trùng nữa',
      );
    });

    test('đơn app tự tạo (không có mã KV) không lọt vào diện dọn', () async {
      await add(null, 'x1', 500);
      await add('Ghi chú thường', 'x2', 700);
      await add('', 'x3', 900);
      expect(await loadGroups(), isEmpty);
    });

    test('nhóm 3 bản thì xoá 2, giữ 1', () async {
      await add('KV:HD009', 'a', 100);
      await add('KV:HD009', 'b', 100);
      await add('KV:HD009', 'c', 100);
      final v = victims(await loadGroups());
      expect(v.map((e) => e['id']), [2, 3]);
    });

    test('tiền thổi phồng = tổng các bản thừa', () async {
      await add('KV:HD001', 'a', 75340000);
      await add('KV:HD001', 'b', 75340000);
      await add('KV:HD002', 'c', 65980000);
      await add('KV:HD002', 'd', 65980000);
      final inflated = victims(await loadGroups())
          .fold<int>(0, (s, r) => s + (r['totalPrice'] as int));
      expect(inflated, 75340000 + 65980000);
    });
  });
}
