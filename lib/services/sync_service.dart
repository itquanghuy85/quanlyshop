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

  static Future<void> initRealTimeSync(VoidCallback onDataChanged) async {
    await cancelAllSubscriptions();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String? shopId = await UserService.getCurrentShopId();

    // 1. REPAIRS - Dùng upsert để chống trùng
    _subscribe('repairs', shopId, (data, docId) async {
      final db = DBHelper();
      if (data['deleted'] == true) await db.deleteRepairByFirestoreId(docId);
      else { data['firestoreId'] = docId; await db.upsertRepair(Repair.fromMap(data)); }
    }, onDataChanged);

    // 2. SALES
    _subscribe('sales', shopId, (data, docId) async {
      final db = DBHelper();
      if (data['deleted'] == true) await db.deleteSaleByFirestoreId(docId);
      else { data['firestoreId'] = docId; await db.upsertSale(SaleOrder.fromMap(data)); }
    }, onDataChanged);

    // 3. PRODUCTS
    _subscribe('products', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertProduct(Product.fromMap(data));
    }, onDataChanged);

    // 4. EXPENSES
    _subscribe('expenses', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertExpense(Expense.fromMap(data));
    }, onDataChanged);

    // 5. DEBTS
    _subscribe('debts', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertDebt(Debt.fromMap(data));
    }, onDataChanged);
  }

  static void _subscribe(String col, String? shopId, Function(Map<String, dynamic>, String) action, VoidCallback onDone) {
    Query<Map<String, dynamic>> q = _db.collection(col);
    if (shopId != null) q = q.where('shopId', isEqualTo: shopId);
    _subscriptions.add(q.snapshots().listen((snap) async {
      for (var change in snap.docChanges) {
        if (change.doc.data() != null) await action(change.doc.data()!, change.doc.id);
      }
      onDone();
    }));
  }

  static Future<void> cancelAllSubscriptions() async {
    for (var s in _subscriptions) await s.cancel();
    _subscriptions.clear();
  }

  static Future<void> syncAllToCloud() async {
    final shopId = await UserService.getCurrentShopId();
    final db = DBHelper();

    // Đồng bộ đồng loạt Repairs, Sales, Products
    final repairs = await db.getAllRepairs();
    for (var r in repairs) {
      if (r.isSynced) continue;
      final docId = r.firestoreId ?? "rep_${r.createdAt}_${r.phone}";
      Map<String, dynamic> data = r.toMap();
      data['shopId'] = shopId;
      await _db.collection('repairs').doc(docId).set(data, SetOptions(merge: true));
      r.isSynced = true; r.firestoreId = docId; await db.updateRepair(r);
    }

    final sales = await db.getAllSales();
    for (var s in sales) {
      if (s.isSynced) continue;
      final docId = s.firestoreId ?? "sale_${s.soldAt}_${s.phone}";
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      await _db.collection('sales').doc(docId).set(data, SetOptions(merge: true));
      s.isSynced = true; s.firestoreId = docId; await db.updateSale(s);
    }
  }

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
