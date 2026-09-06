import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/utils/money_utils.dart';
import 'package:quanlyshop/utils/transaction_sort.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kiểm thử các bản vá của đợt audit trang Chốt quỹ (2026-09-06f).
///
/// Phần SQLite chạy trên **CSDL thật** (sqflite ffi) và cố tình KHÔNG đi qua
/// `DBHelper` — mọi hàm ở đó gọi `UserService.getCurrentShopId()` → FirebaseAuth
/// mà môi trường test không có Firebase. Thay vào đó chạy ĐÚNG câu DDL của
/// schema cũ rồi ĐÚNG lệnh ALTER của migration v111.

/// Schema `cash_closings` TRƯỚC v111 (bản v49 sau khi đã thêm đủ cột).
const _ddlBeforeV111 = '''
  CREATE TABLE cash_closings(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    dateKey TEXT UNIQUE,
    cashStart INTEGER DEFAULT 0,
    bankStart INTEGER DEFAULT 0,
    cashEnd INTEGER DEFAULT 0,
    bankEnd INTEGER DEFAULT 0,
    expectedCashDelta INTEGER DEFAULT 0,
    expectedBankDelta INTEGER DEFAULT 0,
    note TEXT,
    createdAt INTEGER,
    isLocked INTEGER DEFAULT 0,
    lockedBy TEXT,
    lockedAt INTEGER,
    shopId TEXT,
    firestoreId TEXT UNIQUE,
    isSynced INTEGER DEFAULT 0,
    closedBy TEXT,
    closedAt INTEGER
  )
''';

/// Bản sao 1:1 lệnh ALTER trong `db_helper.dart` khối `oldV < 111`.
/// Lệch nhau là test này phải đỏ — đó là mục đích.
const _v111Columns = ['cashDiff', 'bankDiff'];

Future<void> _upgradeToV111(Database db) async {
  for (final col in _v111Columns) {
    final cols = await db.rawQuery('PRAGMA table_info(cash_closings)');
    final exists = cols.any((c) => (c['name'] as String?) == col);
    if (!exists) {
      await db.execute('ALTER TABLE cash_closings ADD COLUMN $col INTEGER');
    }
  }
}

void main() {
  sqfliteFfiInit();

  group('DB v111 — lưu lệch quỹ', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await db.execute(_ddlBeforeV111);
    });

    tearDown(() async => db.close());

    test('migration chạy được và thêm đúng 2 cột', () async {
      await _upgradeToV111(db);
      final cols = await db.rawQuery('PRAGMA table_info(cash_closings)');
      final names = cols.map((c) => c['name'] as String).toSet();
      expect(names.contains('cashDiff'), isTrue);
      expect(names.contains('bankDiff'), isTrue);
    });

    test('migration chạy 2 lần không nổ (máy nâng cấp nhiều bước)', () async {
      await _upgradeToV111(db);
      await _upgradeToV111(db);
      final cols = await db.rawQuery('PRAGMA table_info(cash_closings)');
      expect(cols.where((c) => c['name'] == 'cashDiff').length, 1);
    });

    test('bản ghi CŨ giữ NULL, không bị mặc định 0', () async {
      // Đây là điểm mấu chốt: 0 nghĩa là "đã chốt và khớp quỹ". Nếu migration
      // đặt DEFAULT 0 thì mọi lần chốt quỹ từ trước sẽ hiện "Khớp quỹ" — nói
      // dối về số liệu tài chính.
      await db.insert('cash_closings', {
        'dateKey': '2026-09-01',
        'cashEnd': 5000000,
        'bankEnd': 2000000,
      });
      await _upgradeToV111(db);

      final row = (await db.query(
        'cash_closings',
        where: 'dateKey = ?',
        whereArgs: ['2026-09-01'],
      )).single;
      expect(row['cashDiff'], isNull);
      expect(row['bankDiff'], isNull);
    });

    test('bản ghi MỚI lưu và đọc lại đúng lệch quỹ (kể cả số âm)', () async {
      await _upgradeToV111(db);
      await db.insert('cash_closings', {
        'dateKey': '2026-09-06',
        'cashStart': 2000000,
        'bankStart': 1000000,
        'expectedCashDelta': 5000000,
        'expectedBankDelta': -300000,
        'cashEnd': 6950000,
        'bankEnd': 700000,
        'cashDiff': -50000, // đếm thiếu 50k
        'bankDiff': 0,
        'note': 'Thiếu 50k tiền lẻ',
      });

      final row = (await db.query(
        'cash_closings',
        where: 'dateKey = ?',
        whereArgs: ['2026-09-06'],
      )).single;
      expect(row['cashDiff'], -50000);
      expect(row['bankDiff'], 0);
      // Kỳ vọng phải dựng lại được từ số đã lưu.
      final expectedCash =
          (row['cashStart'] as int) + (row['expectedCashDelta'] as int);
      expect((row['cashEnd'] as int) - expectedCash, row['cashDiff']);
    });
  });

  group('Sắp xếp giao dịch Sổ quỹ theo thời gian thật', () {
    Map<String, dynamic> tx(String time, int? ts) => {
      'time': time,
      if (ts != null) 'timestamp': ts,
    };

    int ms(int day, int hour, int minute) =>
        DateTime(2026, 9, day, hour, minute).millisecondsSinceEpoch;

    test('gộp nhiều ngày: hôm nay lên trước hôm kia dù giờ nhỏ hơn', () {
      // Đây chính là lỗi cũ: sắp theo chuỗi "HH:mm" thì "09:00" của mùng 4
      // đứng trên "08:00" của mùng 6.
      final list = [
        tx('09:00', ms(4, 9, 0)),
        tx('08:00', ms(6, 8, 0)),
        tx('23:30', ms(5, 23, 30)),
      ]..sort(byTimeDesc);

      expect(list.map((t) => t['timestamp']).toList(), [
        ms(6, 8, 0),
        ms(5, 23, 30),
        ms(4, 9, 0),
      ]);
    });

    test('trong cùng 1 ngày vẫn giảm dần theo giờ', () {
      final list = [
        tx('08:00', ms(6, 8, 0)),
        tx('17:45', ms(6, 17, 45)),
        tx('12:10', ms(6, 12, 10)),
      ]..sort(byTimeDesc);

      expect(
        list.map((t) => t['time']).toList(),
        ['17:45', '12:10', '08:00'],
      );
    });

    test('thiếu timestamp cả hai bên → lùi về so chuỗi giờ', () {
      final list = [tx('08:00', null), tx('17:45', null)]..sort(byTimeDesc);
      expect(list.first['time'], '17:45');
    });

    test('txTimestamp trả 0 khi thiếu, không ném', () {
      expect(txTimestamp(<String, dynamic>{}), 0);
    });
  });

  group('Ô nhập tiền khi chốt quỹ', () {
    test('chuỗi có dấu phân cách nghìn phải đọc ra đúng số', () {
      // Lỗi cũ: `int.tryParse("6.000.000")` = null → 0 → chốt quỹ số 0.
      expect(MoneyUtils.parseCurrency('6.000.000'), 6000000);
      expect(MoneyUtils.parseCurrency('6,000,000'), 6000000);
      expect(MoneyUtils.parseCurrency('6 000 000'), 6000000);
      expect(MoneyUtils.parseCurrency('6000000'), 6000000);
    });

    test('chuỗi rỗng / rác ra 0 chứ không ném', () {
      expect(MoneyUtils.parseCurrency(''), 0);
      expect(MoneyUtils.parseCurrency('abc'), 0);
    });

    test('điền sẵn rồi đọc lại phải ra đúng số ban đầu', () {
      for (final v in [0, 1000, 6000000, 123456789]) {
        expect(MoneyUtils.parseCurrency(MoneyUtils.formatCurrency(v)), v);
      }
    });
  });
}
