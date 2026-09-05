import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kiểm thử trên **SQLite thật** (sqflite ffi) hai truy vấn mới của
/// `db_helper.dart`: `getPendingRepairCounts` và `getPendingRepairs`.
///
/// Cố tình KHÔNG đi qua `DBHelper`: mọi hàm ở đó gọi
/// `UserService.getCurrentShopId()` → FirebaseAuth, mà môi trường test không có
/// Firebase. Thay vào đó chạy ĐÚNG câu SQL mà hai hàm dùng — lệch nhau là test
/// này phải đỏ, đó là mục đích.
///
/// Lỗi đang chặn: "đơn sửa đang chờ" trước đây tính bằng
/// `getRepairsByCreatedAtRange(dayStart, dayEnd)` nên **bỏ sót toàn bộ đơn tồn
/// của những hôm trước** — hỏi lúc 9h sáng có thể ra 0 dù còn hàng chục máy
/// chưa trả.

/// Bản sao 1:1 câu SQL trong `DBHelper.getPendingRepairCounts` (nhánh có shopId).
const _countsSql =
    'SELECT COUNT(*) AS total, '
    'SUM(CASE WHEN createdAt < ? THEN 1 ELSE 0 END) AS overdue '
    'FROM repairs WHERE status < 4 AND (deleted = 0 OR deleted IS NULL) '
    'AND (shopId = ? OR shopId IS NULL)';

/// Bản sao 1:1 mệnh đề WHERE trong `DBHelper.getPendingRepairs` (nhánh có shopId).
const _pendingWhere =
    'status < 4 AND (deleted = 0 OR deleted IS NULL) AND (shopId = ? OR shopId IS NULL)';

/// Chỉ giữ các cột mà hai truy vấn thật sự đụng tới — mục tiêu của test là
/// **logic lọc**, không phải toàn bộ schema `repairs` (v110).
const _ddl = '''
      CREATE TABLE IF NOT EXISTS repairs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestoreId TEXT UNIQUE,
        customerName TEXT,
        model TEXT,
        issue TEXT,
        price INTEGER,
        status INTEGER,
        createdAt INTEGER,
        deleted INTEGER DEFAULT 0,
        shopId TEXT
      )
''';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late int dayStart;

  // Mốc thời gian cố định để test không phụ thuộc giờ chạy.
  final now = DateTime(2026, 9, 6, 9, 30);

  int daysAgo(int n) =>
      DateTime(now.year, now.month, now.day - n, 14, 0).millisecondsSinceEpoch;

  setUp(() async {
    dayStart = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(_ddl);

    Future<void> add(
      String id, {
      required int status,
      required int createdAt,
      String? shopId = 'shopA',
      int deleted = 0,
    }) =>
        db.insert('repairs', {
          'firestoreId': id,
          'customerName': 'Khách $id',
          'model': 'iPhone $id',
          'issue': 'thay màn',
          'price': 1500000,
          'status': status,
          'createdAt': createdAt,
          'deleted': deleted,
          'shopId': shopId,
        });

    // Đơn tạo HÔM NAY, chưa giao → tính, không phải đơn tồn.
    await add('r1', status: 1, createdAt: now.millisecondsSinceEpoch);
    // Đơn tồn từ những hôm trước, chưa giao → tính, VÀ là đơn tồn.
    await add('r2', status: 2, createdAt: daysAgo(3));
    await add('r3', status: 3, createdAt: daysAgo(10));
    // Đã giao → không tính.
    await add('r4', status: 4, createdAt: daysAgo(2));
    // Đã xoá mềm → không tính.
    await add('r5', status: 1, createdAt: daysAgo(5), deleted: 1);
    // Shop khác → không tính.
    await add('r6', status: 1, createdAt: daysAgo(1), shopId: 'shopB');
    // Bản ghi cũ chưa gắn shopId → vẫn tính (đúng như các truy vấn khác).
    await add('r7', status: 1, createdAt: daysAgo(2), shopId: null);
  });

  tearDown(() async => db.close());

  test('đếm ĐỦ đơn chưa giao của mọi ngày, không chỉ đơn tạo hôm nay', () async {
    final rows = await db.rawQuery(_countsSql, [dayStart, 'shopA']);
    final row = rows.first;

    // r1 + r2 + r3 + r7 (loại r4 đã giao, r5 đã xoá, r6 shop khác)
    expect((row['total'] as num).toInt(), 4);
    // r2 + r3 + r7 tạo trước 00:00 hôm nay
    expect((row['overdue'] as num).toInt(), 3);
  });

  test('CHỨNG MINH lỗi cũ: lọc theo ngày tạo chỉ thấy 1/4 đơn đang chờ', () async {
    final dayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    // Đúng cách `getRepairsByCreatedAtRange` làm — nguồn của con số cũ.
    final todayOnly = await db.query(
      'repairs',
      where:
          '(shopId = ? OR shopId IS NULL) AND createdAt >= ? AND createdAt <= ? '
          'AND (deleted = 0 OR deleted IS NULL)',
      whereArgs: ['shopA', dayStart, dayEnd],
    );
    final oldPending =
        todayOnly.where((r) => (r['status'] as int) < 4).length;

    expect(oldPending, 1, reason: 'cách cũ bỏ sót 3 đơn tồn của hôm trước');
  });

  test('danh sách đơn chưa giao sắp xếp mới nhất trước và tôn trọng limit',
      () async {
    final maps = await db.query(
      'repairs',
      where: _pendingWhere,
      whereArgs: ['shopA'],
      orderBy: 'createdAt DESC',
      limit: 8,
    );

    expect(maps.length, 4);
    expect(maps.first['firestoreId'], 'r1');
    expect(maps.last['firestoreId'], 'r3');
    expect(maps.map((m) => m['firestoreId']), isNot(contains('r6')));

    final limited = await db.query(
      'repairs',
      where: _pendingWhere,
      whereArgs: ['shopA'],
      orderBy: 'createdAt DESC',
      limit: 2,
    );
    expect(limited.length, 2);
  });

  test('shop không có đơn chờ trả về 0 chứ không phải null', () async {
    await db.delete('repairs');
    final rows = await db.rawQuery(_countsSql, [dayStart, 'shopA']);
    final row = rows.first;

    // SUM() trên bảng rỗng trả NULL — hàm thật ép về 0 bằng `?? 0`.
    expect((row['total'] as num?)?.toInt() ?? 0, 0);
    expect((row['overdue'] as num?)?.toInt() ?? 0, 0);
  });
}
