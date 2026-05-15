import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../services/user_service.dart';

class BackupService {
  static const String _dbName = 'repair_shop_v22.db';

  /// Lấy đường dẫn file database
  static Future<String> _getDbPath() async {
    final dbDir = await getDatabasesPath();
    return p.join(dbDir, _dbName);
  }

  /// Xuất file DB ra thư mục temp rồi share
  static Future<void> exportToLocal(BuildContext? context) async {
    final dbPath = await _getDbPath();
    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      throw Exception('Không tìm thấy file database');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempPath = p.join(tempDir.path, 'quanlyshop_backup_$timestamp.db');

    await dbFile.copy(tempPath);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(tempPath)],
        subject: 'QuanLyShop Backup',
      ),
    );
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
}
