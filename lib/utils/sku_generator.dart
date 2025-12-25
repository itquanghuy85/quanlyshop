import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db_helper.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';

class SKUGenerator {
  /// Tạo mã hàng (SKU) duy nhất theo format: [NHOM]-[MODEL]-[THONGTIN]-[STT]
  /// - NHOM: IP, SS, PIN, MH, PK (bắt buộc)
  /// - MODEL: IP11, IP12PM, SS-A21... (tùy chọn)
  /// - THONGTIN: dung lượng/loại linh kiện/màu (tùy chọn)
  /// - STT: số tự tăng 4 chữ số (0001, 0002...)
  ///
  /// Nếu thiếu MODEL hoặc THONGTIN thì bỏ phần đó, không tạo dấu gạch thừa.
  /// Kiểm tra trùng lặp trong SQLite và Firestore trước khi tạo.
  static Future<String> generateSKU({
    required String nhom,
    String? model,
    String? thongtin,
    required DBHelper dbHelper,
    FirestoreService? firestoreService,
  }) async {
    // Validate input
    if (!['IP', 'SS', 'PIN', 'MH', 'PK'].contains(nhom.toUpperCase())) {
      throw ArgumentError('NHOM phải là một trong: IP, SS, PIN, MH, PK');
    }

    // Tạo base SKU (không có STT)
    String baseSKU = nhom.toUpperCase();
    if (model != null && model.trim().isNotEmpty) {
      baseSKU += '-${model.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '')}';
    }
    if (thongtin != null && thongtin.trim().isNotEmpty) {
      baseSKU += '-${thongtin.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '')}';
    }

    // Tìm STT cao nhất hiện tại cho base này
    int maxSTT = await _findMaxSTT(baseSKU, dbHelper, firestoreService);

    // Tăng STT lên 1
    int nextSTT = maxSTT + 1;

    // Format STT thành 4 chữ số
    String sttFormatted = nextSTT.toString().padLeft(4, '0');

    // Tạo SKU hoàn chỉnh
    String finalSKU = '$baseSKU-$sttFormatted';

    // Double-check trùng lặp (mặc dù logic trên đảm bảo không trùng)
    bool isDuplicate = await _checkDuplicateSKU(finalSKU, dbHelper, firestoreService);
    if (isDuplicate) {
      // Nếu vẫn trùng (hiếm), tăng STT và thử lại
      return generateSKU(
        nhom: nhom,
        model: model,
        thongtin: thongtin,
        dbHelper: dbHelper,
        firestoreService: firestoreService,
      );
    }

    return finalSKU;
  }

  /// Tìm STT cao nhất cho base SKU trong cả SQLite và Firestore
  static Future<int> _findMaxSTT(String baseSKU, DBHelper dbHelper, FirestoreService? firestoreService) async {
    int maxSTT = 0;

    // Query SQLite - giả định SKU lưu trong trường 'name' của products
    final db = await dbHelper.database;
    final sqliteResults = await db.rawQuery(
      "SELECT name FROM products WHERE name LIKE ? AND deleted = 0",
      ['$baseSKU-%']
    );

    for (var row in sqliteResults) {
      String sku = row['name'] as String;
      if (sku.startsWith('$baseSKU-')) {
        String sttPart = sku.substring(baseSKU.length + 1);
        int? stt = int.tryParse(sttPart);
        if (stt != null && stt > maxSTT) {
          maxSTT = stt;
        }
      }
    }

    // Query Firestore (nếu có)
    if (firestoreService != null) {
      try {
        final shopId = await UserService.getCurrentShopId();
        Query query = FirebaseFirestore.instance.collection('products');
        if (shopId != null) {
          query = query.where('shopId', isEqualTo: shopId);
        }
        query = query.where('name', isGreaterThanOrEqualTo: '$baseSKU-')
                  .where('name', isLessThan: '$baseSKU-~');

        final snapshot = await query.get();
        for (var doc in snapshot.docs) {
          String sku = doc['name'] as String;
          if (sku.startsWith('$baseSKU-')) {
            String sttPart = sku.substring(baseSKU.length + 1);
            int? stt = int.tryParse(sttPart);
            if (stt != null && stt > maxSTT) {
              maxSTT = stt;
            }
          }
        }
      } catch (_) {
        // Bỏ qua lỗi Firestore
      }
    }

    return maxSTT;
  }

  /// Kiểm tra SKU có bị trùng không
  static Future<bool> _checkDuplicateSKU(String sku, DBHelper dbHelper, FirestoreService? firestoreService) async {
    // Check SQLite
    final db = await dbHelper.database;
    final sqliteCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM products WHERE name = ? AND deleted = 0",
      [sku]
    )) ?? 0;

    if (sqliteCount > 0) return true;

    // Check Firestore
    if (firestoreService != null) {
      try {
        final shopId = await UserService.getCurrentShopId();
        Query query = FirebaseFirestore.instance.collection('products').where('name', isEqualTo: sku);
        if (shopId != null) {
          query = query.where('shopId', isEqualTo: shopId);
        }
        final snapshot = await query.get();
        if (snapshot.docs.isNotEmpty) return true;
      } catch (_) {
        // Bỏ qua lỗi Firestore
      }
    }

    return false;
  }
}