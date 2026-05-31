import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/user_service.dart';

class FirestoreBackupSet {
  final String id;
  final String storagePath;
  final DateTime createdAt;
  final List<String> collections;

  const FirestoreBackupSet({
    required this.id,
    required this.storagePath,
    required this.createdAt,
    required this.collections,
  });
}

class LocalSqliteBackup {
  final String name;
  final String path;
  final DateTime modifiedAt;
  final int sizeBytes;

  const LocalSqliteBackup({
    required this.name,
    required this.path,
    required this.modifiedAt,
    required this.sizeBytes,
  });
}

class BackupService {
  static const String _dbName = 'repair_shop_v22.db';

  static const Map<String, List<String>> _sqliteCollectionTables = {
    'repairs': ['repairs'],
    'repair_parts': ['repair_parts'],
    'repair_partners': ['repair_partners'],
    'partner_repair_history': ['partner_repair_history'],
    'sales': ['sales', 'sales_returns', 'sales_return_items'],
    'products': [
      'products',
      'product_categories',
      'product_variants',
      'supplier_product_prices',
    ],
    'salvage_phones': ['salvage_phones'],
    'storage_locations': ['storage_locations'],
    'customers': ['customers'],
    'suppliers': ['suppliers'],
    'supplier_import_history': ['supplier_import_history'],
    'debts': ['debts'],
    'debt_payments': ['debt_payments'],
    'expenses': ['expenses', 'financial_activity_log', 'adjustment_entries'],
    'payment_intents': ['payment_intents'],
    'payment_requests': ['payment_requests'],
    'supplier_payments': ['supplier_payments'],
    'repair_partner_payments': ['repair_partner_payments'],
    'attendance': ['attendance'],
    'payroll_settings': [
      'payroll_settings',
      'employee_salary_settings',
      'payroll_locks',
    ],
    'work_schedules': ['work_schedules'],
    'leave_requests': ['leave_requests'],
    'audit_logs': ['audit_logs'],
    'inventory_checks': ['inventory_checks'],
    'cash_closings': ['cash_closings'],
    'shop_settings': ['shop_settings'],
    'purchase_orders': ['purchase_orders'],
    'import_orders': ['import_orders', 'import_order_items'],
    'quick_input_codes': ['quick_input_codes'],
  };

  static const Map<String, String> _firestoreCollectionNames = {
    'repairs': 'repairs',
    'repair_parts': 'repair_parts',
    'repair_partners': 'repair_partners',
    'partner_repair_history': 'partner_repair_history',
    'sales': 'sales',
    'products': 'products',
    'salvage_phones': 'salvage_phones',
    'storage_locations': 'storage_locations',
    'customers': 'customers',
    'suppliers': 'suppliers',
    'supplier_import_history': 'supplier_import_history',
    'debts': 'debts',
    'debt_payments': 'debt_payments',
    'expenses': 'expenses',
    'payment_intents': 'payment_intents',
    'payment_requests': 'payment_requests',
    'supplier_payments': 'supplier_payments',
    'repair_partner_payments': 'repair_partner_payments',
    'attendance': 'attendance',
    'payroll_settings': 'payroll_settings',
    'work_schedules': 'work_schedules',
    'leave_requests': 'leave_requests',
    'audit_logs': 'audit_logs',
    'inventory_checks': 'inventory_checks',
    'cash_closings': 'cash_closings',
    'purchase_orders': 'purchase_orders',
    'import_orders': 'import_orders',
    'quick_input_codes': 'quick_input_codes',
  };

  static Future<Directory> _getLocalBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'quanlyshop', 'sqlite_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory?> _getLegacyLocalBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'sqlite_backups'));
    if (await dir.exists()) {
      return dir;
    }
    return null;
  }

  /// Lấy đường dẫn file database
  static Future<String> _getDbPath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, _dbName);
  }

  /// Xuất file DB ra thư mục temp rồi share
  static Future<void> exportToLocal(BuildContext? context) async {
    final savedPath = await saveSqliteToLocal();
    await shareSqliteFile(savedPath);
  }

  /// Lưu một bản sao SQLite vào thư mục backup cục bộ của ứng dụng.
  static Future<String> saveSqliteToLocal() async {
    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('Không tìm thấy file database');
    }

    final backupDir = await _getLocalBackupDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'quanlyshop_backup_$timestamp.db';
    final targetPath = p.join(backupDir.path, fileName);

    await dbFile.copy(targetPath);
    return targetPath;
  }

  /// Chia sẻ một file backup SQLite cụ thể.
  static Future<void> shareSqliteFile(String filePath) async {
    final f = File(filePath);
    if (!await f.exists()) {
      throw Exception('Không tìm thấy file backup để chia sẻ');
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'QuanLyShop Backup',
      ),
    );
  }

  /// Xóa một file backup SQLite cục bộ theo đường dẫn tuyệt đối.
  static Future<void> deleteLocalSqliteBackup(String filePath) async {
    final normalizedPath = filePath.trim();
    if (!normalizedPath.toLowerCase().endsWith('.db')) {
      throw Exception('File backup không hợp lệ');
    }

    final backupFile = File(normalizedPath);
    if (!await backupFile.exists()) {
      throw Exception('Không tìm thấy file backup cần xóa');
    }

    await backupFile.delete();
  }

  /// Danh sách các bản backup SQLite cục bộ (mới nhất trước).
  static Future<List<LocalSqliteBackup>> listLocalSqliteBackups() async {
    final dirs = <Directory>[
      await _getLocalBackupDir(),
    ];
    final legacyDir = await _getLegacyLocalBackupDir();
    if (legacyDir != null) {
      dirs.add(legacyDir);
    }

    final files = <LocalSqliteBackup>[];
    final seenPaths = <String>{};

    for (final dir in dirs) {
      final entities = await dir.list().toList();
      for (final e in entities) {
        if (e is! File) continue;
        if (!e.path.toLowerCase().endsWith('.db')) continue;
        if (!seenPaths.add(e.path)) continue;
        try {
          final stat = await e.stat();
          files.add(
            LocalSqliteBackup(
              name: p.basename(e.path),
              path: e.path,
              modifiedAt: stat.modified,
              sizeBytes: stat.size,
            ),
          );
        } catch (_) {
          // Skip unreadable file.
        }
      }
    }

    files.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return files;
  }

  /// Upload file DB lên Firebase Storage, trả về download URL
  static Future<String> backupToFirebase() async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) {
      throw Exception('Chưa đăng nhập');
    }

    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('Không tìm thấy file database');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'backup_$timestamp.db';
    final ref = FirebaseStorage.instance
        .ref('db_backups/$shopId/$fileName');

    final uploadTask = await ref.putFile(
      dbFile,
      SettableMetadata(contentType: 'application/octet-stream'),
    );

    final downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Liệt kê các bản backup trên Firebase Storage
  static Future<List<Map<String, String>>> listFirebaseBackups() async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) {
      throw Exception('Chưa đăng nhập');
    }

    final ref = FirebaseStorage.instance.ref('db_backups/$shopId');
    final result = await ref.listAll();

    final List<Map<String, String>> backups = [];
    for (final item in result.items) {
      try {
        final metadata = await item.getMetadata();
        final timeCreated = metadata.timeCreated;
        final timestamp = timeCreated != null
            ? timeCreated.toLocal().toString().substring(0, 19)
            : '';
        backups.add({
          'name': item.name,
          'timestamp': timestamp,
        });
      } catch (_) {
        // Bỏ qua file lỗi metadata
      }
    }

    // Sắp xếp mới nhất lên đầu
    backups.sort((a, b) => b['timestamp']!.compareTo(a['timestamp']!));
    return backups;
  }

  /// Xóa số liệu chọn lọc trong SQLite hiện tại. Trả về tổng số hàng đã xóa.
  static Future<int> deleteSelectedData(List<String> collections) async {
    if (collections.isEmpty) return 0;
    final dbPath = await _getDbPath();
    int rowsDeleted = 0;
    final db = await openDatabase(dbPath, singleInstance: false);
    try {
      final existingTablesRows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final existingTables = existingTablesRows
          .map((row) => row['name']?.toString() ?? '')
          .where((name) => name.isNotEmpty)
          .toSet();

      await db.transaction((txn) async {
        for (final key in collections) {
          final tables = _sqliteCollectionTables[key] ?? const <String>[];
          for (final table in tables) {
            if (!existingTables.contains(table)) continue;
            try {
              final n = await txn.rawDelete('DELETE FROM $table');
              rowsDeleted += n;
            } catch (_) {}
          }
        }
      });
    } finally {
      await db.close();
    }
    return rowsDeleted;
  }

  /// Xóa dữ liệu cloud theo nhóm đã chọn của shop hiện tại.
  /// Trả về tổng số document đã xóa.
  static Future<int> deleteSelectedDataFromCloud({
    required List<String> collections,
    String? shopIdOverride,
  }) async {
    if (collections.isEmpty) return 0;

    final shopId = shopIdOverride ?? await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }

    final firestore = FirebaseFirestore.instance;
    int totalDeleted = 0;

    Future<void> deleteByQuery(Query<Map<String, dynamic>> query) async {
      while (true) {
        final snapshot = await query.limit(400).get();
        if (snapshot.docs.isEmpty) {
          break;
        }

        final batch = firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        totalDeleted += snapshot.docs.length;

        if (snapshot.docs.length < 400) {
          break;
        }
      }
    }

    final List<String> skipped = [];
    for (final key in collections) {
      final collection = _firestoreCollectionNames[key];
      if (collection == null || collection.isEmpty) continue;
      try {
        await deleteByQuery(
          firestore.collection(collection).where('shopId', isEqualTo: shopId),
        );
      } catch (e) {
        skipped.add(collection);
        debugPrint('⚠️ deleteSelectedDataFromCloud: skip $collection ($e)');
      }
    }
    if (skipped.isNotEmpty) {
      debugPrint('⚠️ Skipped ${skipped.length} collections (permission denied): $skipped');
    }

    return totalDeleted;
  }

  /// Xóa file backup SQLite cục bộ cũ hơn [keepDays] ngày. Trả về số file đã xóa.
  static Future<int> cleanOldLocalBackups({required int keepDays}) async {
    final backups = await listLocalSqliteBackups();
    final cutoff = DateTime.now().subtract(Duration(days: keepDays));
    int count = 0;
    for (final backup in backups) {
      if (backup.modifiedAt.isBefore(cutoff)) {
        try {
          await File(backup.path).delete();
          count++;
        } catch (_) {}
      }
    }
    return count;
  }

  /// Xóa một bản backup SQLite trên Firebase Storage.
  static Future<void> deleteSqliteBackupFromFirebase({
    required String fileName,
  }) async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }
    if (!fileName.toLowerCase().endsWith('.db')) {
      throw Exception('Tên file backup không hợp lệ: $fileName');
    }

    final ref = FirebaseStorage.instance.ref('db_backups/$shopId/$fileName');
    await ref.delete();
  }

  /// Khôi phục database từ file local
  static Future<void> restoreFromLocalFile(
    String filePath, {
    bool remapShopIdToCurrentShop = false,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Không tìm thấy file: $filePath');
    }

    final dbPath = await _getDbPath();
    await sourceFile.copy(dbPath);

    await _ensureRestoredDbCompatibility(dbPath);

    if (remapShopIdToCurrentShop) {
      final currentShopId = await UserService.getCurrentShopId();
      if (currentShopId == null || currentShopId.isEmpty) {
        throw Exception(
          'Không tìm thấy shopId hiện tại để chuyển dữ liệu vào shop mới',
        );
      }
      await _remapRestoredShopId(dbPath, currentShopId);
    }
  }

  /// Khôi phục chọn lọc từ file SQLite (.db) theo từng nhóm dữ liệu.
  static Future<void> restoreSelectedFromLocalFile({
    required String filePath,
    required List<String> collections,
    bool remapShopIdToCurrentShop = false,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Không tìm thấy file: $filePath');
    }
    if (collections.isEmpty) {
      throw Exception('Vui lòng chọn ít nhất 1 mục để khôi phục');
    }

    final dbPath = await _getDbPath();
    final sourceDb = await openDatabase(
      sourceFile.path,
      readOnly: true,
      singleInstance: false,
    );
    final targetDb = await openDatabase(
      dbPath,
      singleInstance: false,
    );

    final targetShopId = await UserService.getCurrentShopId();
    if (remapShopIdToCurrentShop && (targetShopId == null || targetShopId.isEmpty)) {
      await sourceDb.close();
      await targetDb.close();
      throw Exception('Không tìm thấy shop hiện tại để chuyển dữ liệu');
    }

    try {
      await _ensureRestoredDbCompatibility(dbPath);

      final srcTables = await _existingTables(sourceDb);
      final dstTables = await _existingTables(targetDb);

      for (final key in collections) {
        final mappedTables = _sqliteCollectionTables[key] ?? const <String>[];
        for (final table in mappedTables) {
          if (!srcTables.contains(table) || !dstTables.contains(table)) {
            continue;
          }

          final targetCols = await _tableColumns(targetDb, table);
          final sourceRows = await sourceDb.query(table);

          // Always replace selected scope for predictable restore result.
          if (targetCols.contains('shopId') && targetShopId != null && targetShopId.isNotEmpty) {
            await targetDb.delete(
              table,
              where: 'shopId = ? OR shopId IS NULL',
              whereArgs: [targetShopId],
            );
          } else {
            await targetDb.delete(table);
          }

          for (final row in sourceRows) {
            final item = Map<String, dynamic>.from(row);
            if (targetCols.contains('shopId') && remapShopIdToCurrentShop) {
              item['shopId'] = targetShopId;
            }
            if (remapShopIdToCurrentShop && targetCols.contains('isSynced')) {
              item['isSynced'] = 0;
            }
            if (remapShopIdToCurrentShop && targetCols.contains('firestoreId')) {
              item['firestoreId'] = null;
            }

            // Keep only columns existing in target table.
            item.removeWhere((k, _) => !targetCols.contains(k));
            await targetDb.insert(
              table,
              item,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    } finally {
      await sourceDb.close();
      await targetDb.close();
    }
  }

  static Future<void> _remapRestoredShopId(
    String dbPath,
    String currentShopId,
  ) async {
    final db = await openDatabase(
      dbPath,
      version: 1,
      singleInstance: false,
    );

    try {
      final tables = await db.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
      ''');

      for (final row in tables) {
        final tableName = row['name']?.toString();
        if (tableName == null || tableName.isEmpty) continue;

        final columns = await db.rawQuery('PRAGMA table_info($tableName)');
        final hasShopId = columns.any(
          (col) => (col['name'] ?? '').toString() == 'shopId',
        );
        final hasIsSynced = columns.any(
          (col) => (col['name'] ?? '').toString() == 'isSynced',
        );
        final hasFirestoreId = columns.any(
          (col) => (col['name'] ?? '').toString() == 'firestoreId',
        );

        if (!hasShopId && !hasIsSynced && !hasFirestoreId) continue;

        if (hasShopId) {
          await db.update(
            tableName,
            {'shopId': currentShopId},
            where: 'shopId IS NULL OR shopId != ?',
            whereArgs: [currentShopId],
          );
        }

        // Migrate-to-new-shop mode: force local rows to be re-uploaded to cloud.
        if (hasIsSynced) {
          await db.update(tableName, {'isSynced': 0});
        }
        if (hasFirestoreId) {
          await db.update(
            tableName,
            {'firestoreId': null},
            where: 'firestoreId IS NOT NULL AND firestoreId != ""',
          );
        }
      }
    } finally {
      await db.close();
    }
  }

  /// Khôi phục database SQLite từ Firebase Storage theo tên file backup.
  static Future<void> restoreSqliteFromFirebase({
    required String fileName,
  }) async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }
    if (!fileName.toLowerCase().endsWith('.db')) {
      throw Exception('File backup không hợp lệ: $fileName');
    }

    final ref = FirebaseStorage.instance.ref('db_backups/$shopId/$fileName');
    final bytes = await ref.getData(200 * 1024 * 1024); // 200MB
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Không tải được file backup từ Cloud');
    }

    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);

    // Lưu một bản tạm để giảm rủi ro khi ghi trực tiếp lỗi.
    final tempDir = await getTemporaryDirectory();
    final tempRestorePath =
        p.join(tempDir.path, 'restore_${DateTime.now().millisecondsSinceEpoch}.db');
    final tempFile = File(tempRestorePath);
    await tempFile.writeAsBytes(bytes, flush: true);

    await tempFile.copy(dbFile.path);
    await _ensureRestoredDbCompatibility(dbPath);
  }

  /// Khôi phục chọn lọc SQLite từ Cloud theo từng nhóm dữ liệu.
  static Future<void> restoreSelectedSqliteFromFirebase({
    required String fileName,
    required List<String> collections,
    bool remapShopIdToCurrentShop = false,
  }) async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) {
      throw Exception('Chưa đăng nhập');
    }
    if (!fileName.toLowerCase().endsWith('.db')) {
      throw Exception('File backup không hợp lệ: $fileName');
    }

    final ref = FirebaseStorage.instance.ref('db_backups/$shopId/$fileName');
    final bytes = await ref.getData(200 * 1024 * 1024);
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Không tải được file backup từ Cloud');
    }

    final tempDir = await getTemporaryDirectory();
    final tempRestorePath = p.join(
      tempDir.path,
      'restore_selective_${DateTime.now().millisecondsSinceEpoch}.db',
    );
    final tempFile = File(tempRestorePath);
    await tempFile.writeAsBytes(bytes, flush: true);

    await restoreSelectedFromLocalFile(
      filePath: tempFile.path,
      collections: collections,
      remapShopIdToCurrentShop: remapShopIdToCurrentShop,
    );
  }

  static Future<void> _ensureRestoredDbCompatibility(String dbPath) async {
    final db = await openDatabase(dbPath, singleInstance: false);
    try {
      await _ensureColumn(db, 'products', 'shopId', 'TEXT');
      await _ensureColumn(db, 'products', 'deleted', 'INTEGER DEFAULT 0');
      await _ensureColumn(db, 'products', 'status', 'INTEGER DEFAULT 1');
      await _ensureColumn(db, 'products', 'type', 'TEXT DEFAULT "DIEN_THOAI"');
      await _ensureColumn(db, 'products', 'quantity', 'INTEGER DEFAULT 1');
      await _ensureColumn(db, 'products', 'isSynced', 'INTEGER DEFAULT 0');
    } finally {
      await db.close();
    }
  }

  static Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final tables = await _existingTables(db);
    if (!tables.contains(table)) return;
    final columns = await _tableColumns(db, table);
    if (columns.contains(column)) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }

  static Future<Set<String>> _existingTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    return rows
        .map((r) => (r['name'] ?? '').toString())
        .where((n) => n.isNotEmpty && !n.startsWith('sqlite_'))
        .toSet();
  }

  static Future<Set<String>> _tableColumns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => (r['name'] ?? '').toString()).toSet();
  }

  // ─── Firestore selective backup / restore ───────────────────────────────

  static const Map<String, String> kCollectionLabels = {
    'repairs': 'Đơn sửa chữa',
    'repair_parts': 'Kho linh kiện sửa chữa',
    'repair_partners': 'Đối tác sửa chữa',
    'partner_repair_history': 'Lịch sử gửi đối tác',
    'sales': 'Đơn bán hàng',
    'products': 'Sản phẩm / Kho',
    'salvage_phones': 'Kho máy xác',
    'storage_locations': 'Kho vị trí',
    'customers': 'Khách hàng',
    'suppliers': 'Nhà cung cấp',
    'supplier_import_history': 'Lịch sử nhập NCC',
    'debts': 'Công nợ',
    'debt_payments': 'Thanh toán nợ',
    'expenses': 'Chi phí',
    'payment_intents': 'Yêu cầu thanh toán',
    'payment_requests': 'Yêu cầu đóng tiền',
    'supplier_payments': 'Chi NCC',
    'repair_partner_payments': 'Chi đối tác sửa chữa',
    'attendance': 'Chấm công',
    'payroll_settings': 'Cài đặt lương',
    'work_schedules': 'Lịch làm việc',
    'chats': 'Tin nhắn',
    'audit_logs': 'Nhật ký thao tác',
    'inventory_checks': 'Kiểm kê kho',
    'cash_closings': 'Chốt ca',
    'purchase_orders': 'Đơn nhập hàng',
    'import_orders': 'Phiếu nhập kho',
    'quick_input_codes': 'Mã nhập nhanh',
  };

  /// Backup selected Firestore collections to Storage as JSON files.
  /// Returns the backup set ID (e.g. "fs_1716654321000").
  static Future<String> backupFirestoreToCloud({
    required List<String> collections,
    String? shopIdOverride,
    void Function(String collection, int done, int total)? onProgress,
  }) async {
    final shopId = shopIdOverride ?? await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) throw Exception('Chưa đăng nhập');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final setId = 'fs_$timestamp';
    final storage = FirebaseStorage.instance;
    final db = FirebaseFirestore.instance;

    for (int i = 0; i < collections.length; i++) {
      final colName = collections[i];
      onProgress?.call(colName, i, collections.length);

      final snap = await db
          .collection(colName)
          .where('shopId', isEqualTo: shopId)
          .get();

      final docs = snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['__docId__'] = d.id;
        return data;
      }).toList();

      final bytes = Uint8List.fromList(
        utf8.encode(jsonEncode(_encodeFirestoreTypes(docs))),
      );

      await storage
          .ref('db_backups/$shopId/$setId/$colName.json')
          .putData(bytes, SettableMetadata(contentType: 'application/json'));
    }

    return setId;
  }

  /// List all Firestore backup sets for this shop.
  static Future<List<FirestoreBackupSet>> listFirestoreBackupSets({
    String? shopIdOverride,
  }) async {
    final shopId = shopIdOverride ?? await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) throw Exception('Chưa đăng nhập');

    final storage = FirebaseStorage.instance;
    final rootResult = await storage.ref('db_backups/$shopId').listAll();

    final sets = <FirestoreBackupSet>[];
    for (final prefix in rootResult.prefixes) {
      if (!prefix.name.startsWith('fs_')) continue;

      final tsStr = prefix.name.substring(3);
      final ts = int.tryParse(tsStr);
      final createdAt =
          ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : DateTime.now();

      final setResult = await prefix.listAll();
      final cols = setResult.items
          .where((f) => f.name.endsWith('.json'))
          .map((f) => f.name.replaceAll('.json', ''))
          .toList();

      sets.add(FirestoreBackupSet(
        id: prefix.name,
        storagePath: prefix.fullPath,
        createdAt: createdAt,
        collections: cols,
      ));
    }

    sets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sets;
  }

  /// Restore selected collections from a Firestore backup set.
  static Future<void> restoreFirestoreFromCloud({
    required FirestoreBackupSet backupSet,
    required List<String> collections,
    String? shopIdOverride,
  }) async {
    final shopId = shopIdOverride ?? await UserService.getCurrentShopId();
    if (shopId == null || shopId.isEmpty) throw Exception('Chưa đăng nhập');

    final storage = FirebaseStorage.instance;
    final db = FirebaseFirestore.instance;

    for (final colName in collections) {
      final ref = storage.ref('${backupSet.storagePath}/$colName.json');
      final data = await ref.getData(20 * 1024 * 1024); // 20 MB max
      if (data == null) continue;

      final List<dynamic> docs = jsonDecode(utf8.decode(data));

      const batchSize = 400;
      for (int i = 0; i < docs.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
        for (int j = i; j < end; j++) {
          final raw = Map<String, dynamic>.from(docs[j] as Map);
          final docId = raw.remove('__docId__') as String?;
          if (docId == null || docId.isEmpty) continue;
          if (raw['shopId'] != shopId) continue;
          final decoded = _decodeFirestoreTypes(raw);
          batch.set(db.collection(colName).doc(docId), decoded);
        }
        await batch.commit();
      }
    }
  }

  /// Delete a Firestore backup set from Storage.
  static Future<void> deleteFirestoreBackupSet(FirestoreBackupSet set) async {
    final storage = FirebaseStorage.instance;
    final ref = storage.ref(set.storagePath);
    final result = await ref.listAll();
    for (final item in result.items) {
      await item.delete();
    }
  }

  // Convert Timestamp / special Firestore types to JSON-safe maps
  static dynamic _encodeFirestoreTypes(dynamic value) {
    if (value is List) return value.map(_encodeFirestoreTypes).toList();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _encodeFirestoreTypes(v)));
    }
    if (value is Timestamp) {
      return {'__type__': 'Timestamp', 'seconds': value.seconds, 'nanoseconds': value.nanoseconds};
    }
    if (value is GeoPoint) {
      return {'__type__': 'GeoPoint', 'lat': value.latitude, 'lng': value.longitude};
    }
    return value;
  }

  static dynamic _decodeFirestoreTypes(dynamic value) {
    if (value is List) return value.map(_decodeFirestoreTypes).toList();
    if (value is Map) {
      final m = Map<String, dynamic>.from(value);
      if (m['__type__'] == 'Timestamp') {
        return Timestamp(m['seconds'] as int, m['nanoseconds'] as int);
      }
      if (m['__type__'] == 'GeoPoint') {
        return GeoPoint((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble());
      }
      return m.map((k, v) => MapEntry(k, _decodeFirestoreTypes(v)));
    }
    return value;
  }
}
