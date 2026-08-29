import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// L-3 regression: repair_partner_payments must stay linked to the right partner
/// through a rename / reinstall / local-id remap, and must NOT over-match a
/// different partner that happens to share a name.
///
/// This test seeds an in-memory copy of the v108 `repair_partner_payments`
/// schema and runs the exact WHERE clause that
/// `RepairPartnerService.getPartnerRepairStats` builds.
void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  // Mirror of the clause built in getPartnerRepairStats (L-3).
  ({String where, List<Object?> args}) buildPaymentWhere({
    required String shopId,
    required int partnerId,
    String? partnerFirestoreId,
    String? partnerName,
  }) {
    final hasStableKey =
        partnerFirestoreId != null && partnerFirestoreId.isNotEmpty;
    final legacyOr = <String>['partnerId = ?'];
    final legacyArgs = <Object?>[partnerId];
    if (partnerName != null && partnerName.isNotEmpty) {
      legacyOr.add('UPPER(partnerName) = ?');
      legacyArgs.add(partnerName.toUpperCase());
    }
    final legacyClause = legacyOr.join(' OR ');
    if (hasStableKey) {
      return (
        where:
            "shopId = ? AND deleted = 0 AND (partnerFirestoreId = ? OR "
            "((partnerFirestoreId IS NULL OR partnerFirestoreId = '') AND ($legacyClause)))",
        args: <Object?>[shopId, partnerFirestoreId, ...legacyArgs],
      );
    }
    return (
      where: 'shopId = ? AND deleted = 0 AND ($legacyClause)',
      args: <Object?>[shopId, ...legacyArgs],
    );
  }

  Future<int> sumPaid(
    dynamic db, {
    required String shopId,
    required int partnerId,
    String? partnerFirestoreId,
    String? partnerName,
  }) async {
    final q = buildPaymentWhere(
      shopId: shopId,
      partnerId: partnerId,
      partnerFirestoreId: partnerFirestoreId,
      partnerName: partnerName,
    );
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS s FROM repair_partner_payments WHERE ${q.where}',
      q.args,
    );
    return (rows.first['s'] as num).toInt();
  }

  late dynamic db;

  setUp(() async {
    db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE repair_partner_payments(id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'firestoreId TEXT UNIQUE, partnerId INTEGER, partnerFirestoreId TEXT, '
      'partnerName TEXT, amount INTEGER, paidAt INTEGER, paymentMethod TEXT, '
      'note TEXT, shopId TEXT, isSynced INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, '
      'updatedAt INTEGER)',
    );
  });

  tearDown(() async => db.close());

  test('stable key survives local-id remap (delete + recreate partner)',
      () async {
    // Partner "SC" originally local id 30, now recreated as id 52.
    // Payment was written when id was 30 but carries the stable key.
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_1',
      'partnerId': 30, // stale
      'partnerFirestoreId': 'partner_1786245140527',
      'partnerName': 'SC',
      'amount': 12000000,
      'shopId': 'M',
    });

    final total = await sumPaid(
      db,
      shopId: 'M',
      partnerId: 52, // current local id
      partnerFirestoreId: 'partner_1786245140527',
      partnerName: 'SC',
    );
    expect(total, 12000000);
  });

  test('rename does not lose the link (query with the new name)', () async {
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_1',
      'partnerId': 52,
      'partnerFirestoreId': 'partner_1786245140527',
      'partnerName': 'SC', // historical name on the row
      'amount': 500000,
      'shopId': 'M',
    });

    // Partner later renamed to "SC MOBILE".
    final total = await sumPaid(
      db,
      shopId: 'M',
      partnerId: 52,
      partnerFirestoreId: 'partner_1786245140527',
      partnerName: 'SC MOBILE',
    );
    expect(total, 500000, reason: 'matched by stable key, not by name');
  });

  test('name collision: stable key does NOT pull in another partner', () async {
    // Two different partners both named "SC".
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_A',
      'partnerId': 52,
      'partnerFirestoreId': 'partner_AAA',
      'partnerName': 'SC',
      'amount': 1000000,
      'shopId': 'M',
    });
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_B',
      'partnerId': 77,
      'partnerFirestoreId': 'partner_BBB',
      'partnerName': 'SC',
      'amount': 9999999,
      'shopId': 'M',
    });

    final totalA = await sumPaid(
      db,
      shopId: 'M',
      partnerId: 52,
      partnerFirestoreId: 'partner_AAA',
      partnerName: 'SC',
    );
    expect(totalA, 1000000, reason: 'partner_BBB must be excluded');
  });

  test('legacy keyless row still matched by id or name fallback', () async {
    // Old payment written before v108 — no stable key.
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_legacy',
      'partnerId': 52,
      'partnerFirestoreId': null,
      'partnerName': 'SC',
      'amount': 300000,
      'shopId': 'M',
    });
    // New payment with stable key.
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_new',
      'partnerId': 52,
      'partnerFirestoreId': 'partner_AAA',
      'partnerName': 'SC',
      'amount': 700000,
      'shopId': 'M',
    });

    final total = await sumPaid(
      db,
      shopId: 'M',
      partnerId: 52,
      partnerFirestoreId: 'partner_AAA',
      partnerName: 'SC',
    );
    expect(total, 1000000, reason: 'legacy row via id/name + new row via key');
  });

  test('deleted / other-shop rows are excluded', () async {
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_del',
      'partnerId': 52,
      'partnerFirestoreId': 'partner_AAA',
      'partnerName': 'SC',
      'amount': 111,
      'shopId': 'M',
      'deleted': 1,
    });
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_other_shop',
      'partnerId': 52,
      'partnerFirestoreId': 'partner_AAA',
      'partnerName': 'SC',
      'amount': 222,
      'shopId': 'OTHER',
    });
    await db.insert('repair_partner_payments', {
      'firestoreId': 'rpp_ok',
      'partnerId': 52,
      'partnerFirestoreId': 'partner_AAA',
      'partnerName': 'SC',
      'amount': 333,
      'shopId': 'M',
    });

    final total = await sumPaid(
      db,
      shopId: 'M',
      partnerId: 52,
      partnerFirestoreId: 'partner_AAA',
      partnerName: 'SC',
    );
    expect(total, 333);
  });
}
