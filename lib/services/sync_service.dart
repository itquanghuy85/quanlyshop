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
import 'user_service.dart';

class SyncService {
  static final _db = FirebaseFirestore.instance;
  static final List<StreamSubscription> _subscriptions = [];

  // KHỞI TẠO ĐỒNG BỘ THỜI GIAN THỰC
  static Future<void> initRealTimeSync(VoidCallback onDataChanged) async {
    await cancelAllSubscriptions();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Đợi lấy ShopId chính xác
    final String? shopId = await UserService.getCurrentShopId();
    if (shopId == null) return;

    print("SYNC_SERVICE: Đang lắng nghe dữ liệu cho Shop: $shopId");

    // 1. REPAIRS
    _subscribe('repairs', shopId, (data, docId) async {
      final db = DBHelper();
      data['firestoreId'] = docId;
      if (data['deleted'] == true) {
        await db.deleteRepairByFirestoreId(docId);
      } else {
        await db.upsertRepair(Repair.fromMap(data));
      }
    }, onDataChanged);

    // 2. SALES
    _subscribe('sales', shopId, (data, docId) async {
      final db = DBHelper();
      data['firestoreId'] = docId;
      await db.upsertSale(SaleOrder.fromMap(data));
    }, onDataChanged);

    // 3. PRODUCTS (KHO HÀNG)
    _subscribe('products', shopId, (data, docId) async {
      final db = DBHelper();
      data['firestoreId'] = docId;
      await db.upsertProduct(Product.fromMap(data));
    }, onDataChanged);

    // 4. EXPENSES (CHI PHÍ)
    _subscribe('expenses', shopId, (data, docId) async {
      final db = DBHelper();
      data['firestoreId'] = docId;
      await db.upsertExpense(Expense.fromMap(data));
    }, onDataChanged);

    // 5. DEBTS (CÔNG NỢ)
    _subscribe('debts', shopId, (data, docId) async {
      final db = DBHelper();
      data['firestoreId'] = docId;
      await db.upsertDebt(Debt.fromMap(data));
    }, onDataChanged);
  }

  static void _subscribe(String col, String shopId, Function(Map<String, dynamic>, String) action, VoidCallback onDone) {
    // Luôn luôn lọc theo shopId để tránh lộ dữ liệu hoặc nhận sai dữ liệu
    _subscriptions.add(_db.collection(col).where('shopId', isEqualTo: shopId).snapshots().listen((snap) async {
      for (var change in snap.docChanges) {
        if (change.doc.data() != null) {
          await action(change.doc.data()!, change.doc.id);
        }
      }
      onDone(); // Cập nhật lại giao diện máy người dùng
    }));
  }

  static Future<void> cancelAllSubscriptions() async {
    for (var s in _subscriptions) await s.cancel();
    _subscriptions.clear();
  }

  // ĐẨY DỮ LIỆU LOCAL LÊN MÂY (CHỐNG MẤT DỮ LIỆU)
  static Future<void> syncAllToCloud() async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return;
    final db = DBHelper();

    // Đồng bộ Kho hàng
    final products = await db.getAllProducts();
    for (var p in products) {
      if (p.isSynced && p.firestoreId != null) continue;
      final docId = p.firestoreId ?? "prod_${p.createdAt}_${p.imei ?? p.createdAt}";
      Map<String, dynamic> data = p.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      await _db.collection('products').doc(docId).set(data, SetOptions(merge: true));
      p.isSynced = true; p.firestoreId = docId; await db.updateProduct(p);
    }

    // Đồng bộ Đơn bán
    final sales = await db.getAllSales();
    for (var s in sales) {
      if (s.isSynced && s.firestoreId != null) continue;
      final docId = s.firestoreId ?? "sale_${s.soldAt}_${s.phone}";
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      await _db.collection('sales').doc(docId).set(data, SetOptions(merge: true));
      s.isSynced = true; s.firestoreId = docId; await db.updateSale(s);
    }
  }

  // TẢI TOÀN BỘ DỮ LIỆU VỀ MÁY (DÙNG KHI MỚI ĐĂNG NHẬP)
  static Future<void> downloadAllFromCloud() async {
    final db = DBHelper();
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return;

    final cols = ['repairs', 'products', 'sales', 'expenses', 'debts'];
    for (var col in cols) {
      final snap = await _db.collection(col).where('shopId', isEqualTo: shopId).get();
      for (var doc in snap.docs) {
        final data = doc.data();
        data['firestoreId'] = doc.id;
        if (col == 'repairs') await db.upsertRepair(Repair.fromMap(data));
        else if (col == 'products') await db.upsertProduct(Product.fromMap(data));
        else if (col == 'sales') await db.upsertSale(SaleOrder.fromMap(data));
        else if (col == 'expenses') await db.upsertExpense(Expense.fromMap(data));
        else if (col == 'debts') await db.upsertDebt(Debt.fromMap(data));
      }
    }
  }
}
