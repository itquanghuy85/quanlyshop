import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Công nợ — 2 lỗi user báo 2026-08-30:
///  1. Thanh toán xong không trừ nợ (echo cũ của `debts` reset paidAmount).
///  2. Mỗi tài khoản một số công nợ khác nhau (nhận `debt_payments` từ cloud
///     nhưng không tính lại `debts.paidAmount`).
///
/// Gốc chung: `debts.paidAmount` phải là giá trị SUY RA từ sổ cái
/// `debt_payments`, tự khớp lại trên mọi máy. Test này dựng in-memory schema
/// tối thiểu và chạy đúng truy vấn SUM của `DBHelper.updateDebtPaid` +
/// logic trích `debtId`/`debtFirestoreId` của
/// `SyncService._reconcileDebtFromPaymentRow`.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  /// Bản sao truy vấn trong `updateDebtPaid`: tổng phiếu chưa xóa khớp công nợ
  /// theo firestoreId (ưu tiên) hoặc debtId local.
  Future<int> ledgerSum(
    dynamic db, {
    required String? debtFid,
    required int debtLocalId,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS s
      FROM debt_payments
      WHERE COALESCE(deleted, 0) != 1
        AND (
          (debtFirestoreId IS NOT NULL AND debtFirestoreId != '' AND debtFirestoreId = ?)
          OR ((debtFirestoreId IS NULL OR debtFirestoreId = '') AND debtId = ?)
        )
      ''',
      [debtFid ?? '', debtLocalId],
    );
    return (rows.first['s'] as num).toInt();
  }

  /// Bản sao `updateDebtPaid`: định vị theo fid trước, tính lại paidAmount,
  /// no-op nếu không đổi, chỉ set isSynced=0 khi [markUnsynced].
  Future<void> updateDebtPaid(
    dynamic db,
    int? id, {
    String? firestoreId,
    bool markUnsynced = true,
  }) async {
    final useFid = firestoreId != null && firestoreId.isNotEmpty;
    final rows = await db.query(
      'debts',
      columns: ['id', 'firestoreId', 'totalAmount', 'paidAmount'],
      where: useFid ? 'firestoreId = ?' : 'id = ?',
      whereArgs: [useFid ? firestoreId : id],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final debtLocalId = rows.first['id'] as int?;
    final debtFid = rows.first['firestoreId'] as String?;
    final currentPaid = (rows.first['paidAmount'] as int?) ?? 0;
    if (debtLocalId == null) return;

    final newPaid = await ledgerSum(db, debtFid: debtFid, debtLocalId: debtLocalId);
    if (newPaid == currentPaid) return; // no-op

    await db.rawUpdate(
      'UPDATE debts SET paidAmount = ?, '
      'status = CASE WHEN ? >= totalAmount THEN ? ELSE ? END, '
      'updatedAt = ?${markUnsynced ? ', isSynced = 0' : ''} WHERE id = ?',
      [newPaid, newPaid, 'PAID', 'UNPAID', 999, debtLocalId],
    );
  }

  /// Bản sao trích khoá của `_reconcileDebtFromPaymentRow`.
  ({int? debtId, String? fid}) extractKey(Map<String, dynamic> paymentRow) {
    final fidRaw = paymentRow['debtFirestoreId'];
    final fid = fidRaw is String ? fidRaw.trim() : null;
    final rawId = paymentRow['debtId'];
    int? debtId;
    if (rawId is int) {
      debtId = rawId;
    } else if (rawId is num) {
      debtId = rawId.toInt();
    } else if (rawId is String) {
      debtId = int.tryParse(rawId.trim());
    }
    return (debtId: debtId, fid: (fid != null && fid.isNotEmpty) ? fid : null);
  }

  late dynamic db;

  setUp(() async {
    db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE debts(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT, '
      'personName TEXT, type TEXT, totalAmount INTEGER, paidAmount INTEGER, '
      'status TEXT, updatedAt INTEGER, isSynced INTEGER, deleted INTEGER DEFAULT 0)',
    );
    await db.execute(
      'CREATE TABLE debt_payments(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT, '
      'debtId INTEGER, debtFirestoreId TEXT, amount INTEGER, deleted INTEGER DEFAULT 0)',
    );
  });

  tearDown(() async => db.close());

  test('nhận debt_payments từ cloud → paidAmount tự khớp (Lỗi 2)', () async {
    // Máy B: có công nợ NCC, chưa có phiếu nào, paidAmount = 0.
    await db.insert('debts', {
      'id': 152,
      'firestoreId': 'debt_stock_ABC_1',
      'type': 'SHOP_OWES',
      'totalAmount': 12000000,
      'paidAmount': 0,
      'status': 'ACTIVE',
      'isSynced': 1,
    });

    // Phiếu trả 100k do máy A tạo, về qua realtime listener.
    final cloudRow = <String, dynamic>{
      'firestoreId': 'dp_x',
      'debtId': 97, // id local CŨ của máy A — không khớp máy B
      'debtFirestoreId': 'debt_stock_ABC_1',
      'amount': 100000,
    };
    await db.insert('debt_payments', cloudRow);

    final k = extractKey(cloudRow);
    await updateDebtPaid(db, k.debtId, firestoreId: k.fid, markUnsynced: false);

    final d = (await db.query('debts', where: 'id = 152')).first;
    expect(d['paidAmount'], 100000, reason: 'phải khớp sổ cái dù debtId local lệch');
    expect(d['status'], 'UNPAID');
    expect(d['isSynced'], 1, reason: 'reconcile từ sync KHÔNG được đánh dấu cần push');
  });

  test('echo cũ cố ghi paidAmount về 0 → reconcile từ sổ cái khôi phục (Lỗi 1)', () async {
    await db.insert('debts', {
      'id': 10,
      'firestoreId': 'debt_stock_XYZ',
      'type': 'SHOP_OWES',
      'totalAmount': 19900000,
      'paidAmount': 19900000,
      'status': 'PAID',
      'isSynced': 1,
    });
    await db.insert('debt_payments', {
      'firestoreId': 'dp_1',
      'debtId': 10,
      'debtFirestoreId': 'debt_stock_XYZ',
      'amount': 19900000,
    });

    // Echo cũ ghi đè paidAmount về 0 (mô phỏng _shouldAcceptCloudData cho lọt).
    await db.update('debts', {'paidAmount': 0, 'status': 'ACTIVE'}, where: 'id = 10');

    // Sau đó 1 phiếu debt_payments bất kỳ về → reconcile.
    await updateDebtPaid(db, 10, firestoreId: 'debt_stock_XYZ', markUnsynced: false);

    final d = (await db.query('debts', where: 'id = 10')).first;
    expect(d['paidAmount'], 19900000, reason: 'khôi phục từ sổ cái');
    expect(d['status'], 'PAID');
  });

  test('gọi lặp (retry / nhiều echo) không cộng đôi', () async {
    await db.insert('debts', {
      'id': 1,
      'firestoreId': 'd1',
      'type': 'SHOP_OWES',
      'totalAmount': 5000000,
      'paidAmount': 0,
      'status': 'ACTIVE',
      'isSynced': 1,
    });
    await db.insert('debt_payments',
        {'firestoreId': 'p1', 'debtId': 1, 'debtFirestoreId': 'd1', 'amount': 2000000});

    for (var i = 0; i < 5; i++) {
      await updateDebtPaid(db, 1, firestoreId: 'd1', markUnsynced: false);
    }
    final d = (await db.query('debts', where: 'id = 1')).first;
    expect(d['paidAmount'], 2000000);
  });

  test('phiếu bị soft-delete trên cloud → paidAmount giảm lại', () async {
    await db.insert('debts', {
      'id': 3,
      'firestoreId': 'd3',
      'type': 'SHOP_OWES',
      'totalAmount': 1000000,
      'paidAmount': 1000000,
      'status': 'PAID',
      'isSynced': 1,
    });
    await db.insert('debt_payments', {
      'id': 50,
      'firestoreId': 'p3',
      'debtId': 3,
      'debtFirestoreId': 'd3',
      'amount': 1000000,
      'deleted': 0,
    });

    await db.update('debt_payments', {'deleted': 1}, where: 'id = 50');
    await updateDebtPaid(db, 3, firestoreId: 'd3', markUnsynced: false);

    final d = (await db.query('debts', where: 'id = 3')).first;
    expect(d['paidAmount'], 0);
    expect(d['status'], 'UNPAID');
  });

  test('thao tác cục bộ (markUnsynced mặc định) đánh dấu cần push', () async {
    await db.insert('debts', {
      'id': 7,
      'firestoreId': 'd7',
      'type': 'CUSTOMER_OWES',
      'totalAmount': 800000,
      'paidAmount': 0,
      'status': 'ACTIVE',
      'isSynced': 1,
    });
    await db.insert('debt_payments',
        {'firestoreId': 'p7', 'debtId': 7, 'debtFirestoreId': 'd7', 'amount': 800000});

    await updateDebtPaid(db, 7, firestoreId: 'd7'); // markUnsynced: true

    final d = (await db.query('debts', where: 'id = 7')).first;
    expect(d['paidAmount'], 800000);
    expect(d['status'], 'PAID');
    expect(d['isSynced'], 0, reason: 'thao tác cục bộ phải sync lên cloud');
  });

  test('extractKey: fid rỗng thì trả null để fallback debtId', () {
    expect(extractKey({'debtId': 5, 'debtFirestoreId': ''}).fid, isNull);
    expect(extractKey({'debtId': 5, 'debtFirestoreId': ''}).debtId, 5);
    expect(extractKey({'debtId': null, 'debtFirestoreId': 'abc'}).fid, 'abc');
    expect(extractKey({'debtId': '9', 'debtFirestoreId': null}).debtId, 9);
  });
}
