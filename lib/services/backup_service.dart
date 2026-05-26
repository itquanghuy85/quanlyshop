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

  static Future<Directory> _getLocalBackupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'sqlite_backups'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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

  /// Danh sách các bản backup SQLite cục bộ (mới nhất trước).
  static Future<List<LocalSqliteBackup>> listLocalSqliteBackups() async {
    final dir = await _getLocalBackupDir();
    if (!await dir.exists()) return const [];

    final entities = await dir.list().toList();
    final files = <LocalSqliteBackup>[];

    for (final e in entities) {
      if (e is! File) continue;
      if (!e.path.toLowerCase().endsWith('.db')) continue;
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
        final url = await item.getDownloadURL();
        final timeCreated = metadata.timeCreated;
        final timestamp = timeCreated != null
            ? timeCreated.toLocal().toString().substring(0, 19)
            : '';
        backups.add({
          'name': item.name,
          'url': url,
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

  /// Khôi phục database từ file local
  static Future<void> restoreFromLocalFile(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Không tìm thấy file: $filePath');
    }

    final dbPath = await _getDbPath();
    await sourceFile.copy(dbPath);
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
  }

  // ─── Firestore selective backup / restore ───────────────────────────────

  static const Map<String, String> kCollectionLabels = {
    'repairs': 'Đơn sửa chữa',
    'sales': 'Đơn bán hàng',
    'products': 'Sản phẩm / Kho',
    'customers': 'Khách hàng',
    'suppliers': 'Nhà cung cấp',
    'debts': 'Công nợ',
    'debt_payments': 'Thanh toán nợ',
    'expenses': 'Chi phí',
    'attendance': 'Chấm công',
    'payroll_settings': 'Cài đặt lương',
    'work_schedules': 'Lịch làm việc',
    'chats': 'Tin nhắn',
    'audit_logs': 'Nhật ký thao tác',
    'inventory_checks': 'Kiểm kê kho',
    'cash_closings': 'Chốt ca',
    'purchase_orders': 'Đơn nhập hàng',
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
