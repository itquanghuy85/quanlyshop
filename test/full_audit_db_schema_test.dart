// FULL AUDIT 2026-09-19 — Bước 3: kiểm schema/constraint SQLite thật (FFI).
// Không sửa code app. Chỉ đọc DBHelper và mô tả hiện trạng.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quanlyshop/data/db_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const expectedTables = [
  'adjustment_entries', 'attendance', 'audit_logs', 'bank_notifications',
  'cash_closings', 'customers', 'debt_payments', 'debts',
  'employee_salary_settings', 'expenses', 'financial_activity_log',
  'import_order_items', 'import_orders', 'inventory_checks', 'leave_requests',
  'partner_repair_history', 'payment_intents', 'payment_requests',
  'payroll_locks', 'payroll_settings', 'price_catalog_items',
  'product_categories', 'products', 'purchase_orders', 'quick_input_codes',
  'repair_partner_payments', 'repair_partners', 'repair_parts', 'repairs',
  'sales', 'sales_return_items', 'sales_returns', 'salvage_phones',
  'shop_settings', 'storage_locations', 'supplier_import_history',
  'supplier_payments', 'supplier_product_prices', 'suppliers', 'sync_queue',
  'work_schedules',
];

// Bảng nghiệp vụ phải có shopId + isSynced + firestoreId UNIQUE để sync an toàn.
const syncedBusinessTables = [
  'repairs', 'repair_parts', 'repair_partners', 'repair_partner_payments',
  'partner_repair_history', 'salvage_phones', 'sales', 'sales_returns',
  'sales_return_items', 'products', 'import_orders', 'import_order_items',
  'purchase_orders', 'supplier_import_history', 'price_catalog_items',
  'storage_locations', 'quick_input_codes', 'customers', 'suppliers',
  'supplier_payments', 'expenses', 'debts', 'debt_payments',
  'payment_intents', 'payment_requests', 'cash_closings',
  'financial_activity_log', 'attendance', 'work_schedules', 'audit_logs',
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  final report = StringBuffer();

  setUpAll(() async {
    final dir = await databaseFactory.getDatabasesPath();
    final path = p.join(dir, 'repair_shop_v22.db');
    for (final f in [path, '$path-wal', '$path-shm', '$path-journal']) {
      final file = File(f);
      if (file.existsSync()) file.deleteSync();
    }
    db = await DBHelper().database;
  });

  tearDownAll(() {
    final out = File('build/full_audit_db_schema_report.txt');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(report.toString());
    // ignore: avoid_print
    print(report);
  });

  test('DB-01 version = 111 và đủ bảng onCreate', () async {
    final v = await db.getVersion();
    expect(v, 111);
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    final names = rows.map((r) => r['name'] as String).toSet();
    report.writeln('TABLES(${names.length}): ${(names.toList()..sort()).join(', ')}');
    final missing = expectedTables.where((t) => !names.contains(t)).toList();
    final extra = names.where((t) => !expectedTables.contains(t)).toList();
    report.writeln('MISSING: $missing');
    report.writeln('EXTRA (legacy/tạm): $extra');
    expect(missing, isEmpty, reason: 'bảng mong đợi thiếu');
  });

  test('DB-02 cột shopId / isSynced / deleted / firestoreId UNIQUE trên bảng sync', () async {
    final problems = <String>[];
    for (final t in syncedBusinessTables) {
      final cols = await db.rawQuery('PRAGMA table_info($t)');
      final colNames = cols.map((c) => c['name'] as String).toSet();
      for (final need in ['shopId', 'isSynced', 'firestoreId']) {
        if (!colNames.contains(need)) problems.add('$t thiếu cột $need');
      }
      if (!colNames.contains('deleted')) {
        report.writeln('NOTE $t: không có cột deleted');
      }
      // UNIQUE index trên firestoreId?
      final idx = await db.rawQuery('PRAGMA index_list($t)');
      bool uniqueFid = false;
      for (final i in idx) {
        if ((i['unique'] as int? ?? 0) == 1) {
          final info = await db.rawQuery("PRAGMA index_info('${i['name']}')");
          if (info.length == 1 && info.first['name'] == 'firestoreId') {
            uniqueFid = true;
          }
        }
      }
      if (!uniqueFid) problems.add('$t: firestoreId KHÔNG UNIQUE');
    }
    report.writeln('DB-02 problems: $problems');
    // Không fail cứng — ghi nhận để báo cáo.
    expect(problems.where((p) => p.contains('thiếu cột')), isEmpty);
  });

  test('DB-03 foreign_keys pragma', () async {
    final fk = await db.rawQuery('PRAGMA foreign_keys');
    report.writeln('foreign_keys=${fk.first.values.first}');
    final fkTables = <String>[];
    for (final t in expectedTables) {
      final r = await db.rawQuery('PRAGMA foreign_key_list($t)');
      if (r.isNotEmpty) fkTables.add('$t→${r.map((e) => e['table']).join(',')}');
    }
    report.writeln('FK declared: ${fkTables.isEmpty ? 'KHÔNG CÓ bảng nào khai FK' : fkTables}');
  });

  test('DB-04 insert trùng firestoreId trên debts / payment_intents / sales', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // debts: insertDebt là insert thuần
    final d = {
      'firestoreId': 'debt_audit_dup', 'type': 'CUSTOMER_OWES', 'personName': 'A',
      'totalAmount': 100, 'paidAmount': 0, 'status': 'ACTIVE', 'createdAt': now,
      'shopId': 'S', 'isSynced': 0, 'deleted': 0,
    };
    await DBHelper().insertDebt(d);
    Object? err;
    try {
      await DBHelper().insertDebt(d);
    } catch (e) {
      err = e;
    }
    final cnt = (await db.rawQuery("SELECT COUNT(*) c FROM debts WHERE firestoreId='debt_audit_dup'")).first['c'];
    report.writeln('DB-04 debts insert trùng: rows=$cnt, error=${err == null ? 'KHÔNG (trùng được!)' : 'UNIQUE chặn'}');

    // payment_intents
    final pi = {
      'intentId': 'pi_audit_dup', 'type': 'X', 'amount': 1, 'status': 'COMPLETED',
      'createdAt': now, 'shopId': 'S', 'isSynced': 0,
    };
    Object? err2;
    try {
      await DBHelper().insertPaymentIntent(pi);
      await DBHelper().insertPaymentIntent(pi);
    } catch (e) {
      err2 = e;
    }
    final cnt2 = (await db.rawQuery("SELECT COUNT(*) c FROM payment_intents WHERE intentId='pi_audit_dup'")).first['c'];
    report.writeln('DB-04 payment_intents insert trùng intentId: rows=$cnt2, error=${err2 == null ? 'KHÔNG' : 'chặn/replace'}');
    expect(cnt2, 1, reason: 'payment_intents phải chống trùng intentId');
  });

  test('DB-05 sync_queue schema', () async {
    final cols = await db.rawQuery('PRAGMA table_info(sync_queue)');
    report.writeln('sync_queue cols: ${cols.map((c) => c['name']).join(',')}');
    expect(cols.map((c) => c['name']), containsAll(['status', 'retryCount']));
  });

  test('DB-06 NULL shopId lọt qua getAllDebts (shopId = ? OR shopId IS NULL)', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('debts', {
      'firestoreId': 'debt_null_shop', 'type': 'CUSTOMER_OWES', 'personName': 'N',
      'totalAmount': 5, 'paidAmount': 0, 'status': 'ACTIVE', 'createdAt': now,
      'shopId': null, 'isSynced': 0, 'deleted': 0,
    });
    final rows = await db.rawQuery(
      "SELECT COUNT(*) c FROM debts WHERE (shopId = 'OTHER' OR shopId IS NULL) AND (deleted = 0 OR deleted IS NULL)",
    );
    report.writeln('DB-06 debts shopId NULL nhìn thấy từ shop OTHER: ${rows.first['c']} row');
  });

  test('DB-07 default values quan trọng', () async {
    for (final t in ['repairs', 'sales', 'products', 'debts']) {
      final cols = await db.rawQuery('PRAGMA table_info($t)');
      final defaults = cols
          .where((c) => ['isSynced', 'deleted', 'status', 'quantity', 'paidAmount'].contains(c['name']))
          .map((c) => '${c['name']}=${c['dflt_value']}')
          .join(' ');
      report.writeln('DEFAULT $t: $defaults');
    }
  });
}
