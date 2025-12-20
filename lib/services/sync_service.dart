import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import 'storage_service.dart';

class SyncService {
  static final _db = FirebaseFirestore.instance;

  static void initRealTimeSync(Function onDataChanged) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _db.collection('repairs').snapshots().listen((snapshot) async {
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

    _db.collection('sales').snapshots().listen((snapshot) async {
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

    _db.collection('products').snapshots().listen((snapshot) async {
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
  }

  static Future<void> syncAllToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final dbHelper = DBHelper();

    final repairs = await dbHelper.getAllRepairs();
    for (var r in repairs) {
      Map<String, dynamic> data = r.toMap();
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
      await _db.collection('sales').doc(s.firestoreId ?? "sale_${s.soldAt}").set(s.toMap(), SetOptions(merge: true));
      s.isSynced = true; await dbHelper.updateSale(s);
    }

    final prods = await dbHelper.getAllProducts();
    for (var p in prods) {
      await _db.collection('products').doc(p.firestoreId ?? "prod_${p.createdAt}").set(p.toMap(), SetOptions(merge: true));
    }
  }

  static Future<void> downloadAllFromCloud() async {
    final db = DBHelper();
    final snaps = await Future.wait([
      _db.collection('repairs').get(),
      _db.collection('products').get(),
      _db.collection('sales').get(),
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
  }
}
