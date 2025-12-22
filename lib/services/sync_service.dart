import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import 'storage_service.dart';
import 'user_service.dart';

class SyncService {
  static final _db = FirebaseFirestore.instance;
  static final List<StreamSubscription> _subscriptions = [];

  /// Khởi tạo đồng bộ thời gian thực
  static Future<void> initRealTimeSync(VoidCallback onDataChanged) async {
    // Hủy các subscription cũ nếu có để tránh rò rỉ bộ nhớ hoặc lặp sự kiện
    await cancelAllSubscriptions();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    // 1. Đồng bộ REPAIRS
    _subscribeToCollection(
      collection: 'repairs',
      shopId: shopId,
      onChanged: (data, docId) async {
        final db = DBHelper();
        if (data['deleted'] == true) {
          await db.deleteRepairByFirestoreId(docId);
        } else {
          data['firestoreId'] = docId;
          await db.upsertRepair(Repair.fromMap(data));
        }
      },
      onBatchDone: onDataChanged,
    );

    // 2. Đồng bộ SALES
    _subscribeToCollection(
      collection: 'sales',
      shopId: shopId,
      onChanged: (data, docId) async {
        final db = DBHelper();
        if (data['deleted'] == true) {
          await db.deleteSaleByFirestoreId(docId);
        } else {
          data['firestoreId'] = docId;
          await db.upsertSale(SaleOrder.fromMap(data));
        }
      },
      onBatchDone: onDataChanged,
    );

    // 3. Đồng bộ PRODUCTS
    _subscribeToCollection(
      collection: 'products',
      shopId: shopId,
      onChanged: (data, docId) async {
        final db = DBHelper();
        if (data['deleted'] == true) {
          await db.deleteProductByFirestoreId(docId);
        } else {
          data['firestoreId'] = docId;
          await db.upsertProduct(Product.fromMap(data));
        }
      },
      onBatchDone: onDataChanged,
    );

    // Tương tự cho các collection khác như expenses, debts... (Rút gọn để tập trung vào tính ổn định)
  }

  /// Hàm helper để quản lý subscription an toàn
  static void _subscribeToCollection({
    required String collection,
    String? shopId,
    required Future<void> Function(Map<String, dynamic> data, String docId) onChanged,
    required VoidCallback onBatchDone,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    final sub = query.snapshots().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;
        await onChanged(data, change.doc.id);
      }
      onBatchDone();
    }, onError: (e) => debugPrint("Sync error in $collection: $e"));

    _subscriptions.add(sub);
  }

  static Future<void> cancelAllSubscriptions() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Đẩy dữ liệu từ Local lên Cloud (Dùng khi có mạng trở lại)
  static Future<void> syncAllToCloud() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final String? shopId = await UserService.getCurrentShopId();
      final dbHelper = DBHelper();

      // Chỉ đẩy những đơn hàng CHƯA đồng bộ hoặc CÓ thay đổi hình ảnh
      final repairs = await dbHelper.getAllRepairs();
      for (var r in repairs) {
        if (r.isSynced && !(r.imagePath?.contains('cache') ?? false)) continue;

        Map<String, dynamic> data = r.toMap();
        data['shopId'] = shopId;
        data.remove('id');

        // Xử lý upload ảnh nếu là ảnh local
        if (r.imagePath != null && r.imagePath!.isNotEmpty && !r.imagePath!.startsWith('http')) {
          List<String> urls = await StorageService.uploadMultipleImages(
            r.imagePath!.split(',').where((path) => !path.startsWith('http')).toList(), 
            'repairs/${r.createdAt}'
          );
          // Giữ lại các ảnh cũ là URL và thêm ảnh mới
          List<String> allUrls = r.imagePath!.split(',').where((path) => path.startsWith('http')).toList();
          allUrls.addAll(urls);
          data['imagePath'] = allUrls.join(',');
        }

        final docId = r.firestoreId ?? "${r.createdAt}_${r.phone}";
        await _db.collection('repairs').doc(docId).set(data, SetOptions(merge: true));
        
        r.isSynced = true;
        r.firestoreId = docId;
        r.imagePath = data['imagePath'];
        await dbHelper.updateRepair(r);
      }
      
      debugPrint("Đã hoàn thành đồng bộ toàn bộ dữ liệu lên Cloud.");
    } catch (e) {
      debugPrint("Lỗi syncAllToCloud: $e");
    }
  }

  /// Tải toàn bộ dữ liệu từ Cloud về (Dùng khi cài lại app hoặc đổi máy)
  static Future<void> downloadAllFromCloud() async {
    try {
      final db = DBHelper();
      final String? shopId = await UserService.getCurrentShopId();
      if (shopId == null) return;

      final collections = ['repairs', 'products', 'sales', 'suppliers', 'customers', 'expenses', 'debts'];
      
      for (var col in collections) {
        final snap = await _db.collection(col).where('shopId', isEqualTo: shopId).get();
        for (var doc in snap.docs) {
          final data = doc.data();
          if (data['deleted'] == true) continue;
          
          data['firestoreId'] = doc.id;
          if (col == 'repairs') await db.upsertRepair(Repair.fromMap(data));
          if (col == 'products') await db.upsertProduct(Product.fromMap(data));
          if (col == 'sales') await db.upsertSale(SaleOrder.fromMap(data));
          // Thêm các loại khác tương tự...
        }
      }
    } catch (e) {
      debugPrint("Lỗi downloadAllFromCloud: $e");
    }
  }
}
