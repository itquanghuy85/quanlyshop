import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import 'storage_service.dart';
import 'user_service.dart';

class SyncService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> initRealTimeSync(Function onDataChanged) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    Query<Map<String, dynamic>> repairsQuery = _db.collection('repairs');
    Query<Map<String, dynamic>> salesQuery = _db.collection('sales');
    Query<Map<String, dynamic>> productsQuery = _db.collection('products');
    Query<Map<String, dynamic>> suppliersQuery = _db.collection('suppliers');

    if (shopId != null) {
      repairsQuery = repairsQuery.where('shopId', isEqualTo: shopId);
      salesQuery = salesQuery.where('shopId', isEqualTo: shopId);
      productsQuery = productsQuery.where('shopId', isEqualTo: shopId);
      suppliersQuery = suppliersQuery.where('shopId', isEqualTo: shopId);
    }

    repairsQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null && (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified)) {
          data['firestoreId'] = change.doc.id; // đảm bảo khóa đồng bộ ổn định
          final r = Repair.fromMap(data);
          await db.upsertRepair(r);
        }
      }
      onDataChanged();
    });

    salesQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null && (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified)) {
          data['firestoreId'] = change.doc.id;
          final s = SaleOrder.fromMap(data);
          await db.upsertSale(s);
        }
      }
      onDataChanged();
    });

    productsQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null && (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified)) {
          data['firestoreId'] = change.doc.id;
          final p = Product.fromMap(data);
          await db.upsertProduct(p);
        }
      }
      onDataChanged();
    });

    suppliersQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data != null && (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified)) {
          await db.upsertSupplier(data);
        }
      }
      onDataChanged();
    });
  }

  static Future<void> syncAllToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();
    final dbHelper = DBHelper();

    final repairs = await dbHelper.getAllRepairs();
    for (var r in repairs) {
      Map<String, dynamic> data = r.toMap();
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      if (r.imagePath != null && r.imagePath!.isNotEmpty && !r.imagePath!.startsWith('http')) {
        List<String> urls = await StorageService.uploadMultipleImages(r.imagePath!.split(','), 'repairs/${r.createdAt}');
        data['imagePath'] = urls.join(',');
      }
      await _db.collection('repairs').doc(r.firestoreId ?? "${r.createdAt}_${r.phone}").set(data, SetOptions(merge: true));
      r.isSynced = true; r.imagePath = data['imagePath'];
      await dbHelper.updateRepair(r);
    }

    final sales = await dbHelper.getAllSales();
    for (var s in sales) {
      final data = s.toMap();
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      await _db.collection('sales').doc(s.firestoreId ?? "sale_${s.soldAt}").set(data, SetOptions(merge: true));
      s.isSynced = true; await dbHelper.updateSale(s);
    }

    final prods = await dbHelper.getAllProducts();
    for (var p in prods) {
      final data = p.toMap();
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      await _db.collection('products').doc(p.firestoreId ?? "prod_${p.createdAt}").set(data, SetOptions(merge: true));
    }

    final suppliers = await dbHelper.getSuppliers();
    for (var s in suppliers) {
      final data = Map<String, dynamic>.from(s);
      data.remove('id');
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      final docId = shopId != null ? "${shopId}_${s['name']}" : (s['name'] as String);
      await _db.collection('suppliers').doc(docId).set(data, SetOptions(merge: true));
    }
  }

  static Future<void> downloadAllFromCloud() async {
    final db = DBHelper();
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    Query<Map<String, dynamic>> repairsQuery = _db.collection('repairs');
    Query<Map<String, dynamic>> productsQuery = _db.collection('products');
    Query<Map<String, dynamic>> salesQuery = _db.collection('sales');
    Query<Map<String, dynamic>> suppliersQuery = _db.collection('suppliers');

    if (shopId != null) {
      repairsQuery = repairsQuery.where('shopId', isEqualTo: shopId);
      productsQuery = productsQuery.where('shopId', isEqualTo: shopId);
      salesQuery = salesQuery.where('shopId', isEqualTo: shopId);
      suppliersQuery = suppliersQuery.where('shopId', isEqualTo: shopId);
    }

    final snaps = await Future.wait([
      repairsQuery.get(),
      productsQuery.get(),
      salesQuery.get(),
      suppliersQuery.get(),
    ]);

    for (var doc in snaps[0].docs) {
      final data = doc.data();
      data['firestoreId'] = doc.id;
      await db.upsertRepair(Repair.fromMap(data));
    }
    for (var doc in snaps[1].docs) {
      final data = doc.data();
      data['firestoreId'] = doc.id;
      await db.upsertProduct(Product.fromMap(data));
    }
    for (var doc in snaps[2].docs) {
      final data = doc.data();
      data['firestoreId'] = doc.id;
      await db.upsertSale(SaleOrder.fromMap(data));
    }

    for (var doc in snaps[3].docs) {
      final data = doc.data();
      await db.upsertSupplier(data);
    }
  }
}
