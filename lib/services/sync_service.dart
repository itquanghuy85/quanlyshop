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
    if (shopId == null) return;

    print("SYNC_SERVICE: Đang lắng nghe Shop: $shopId");

    // LẮNG NGHE ĐƠN SỬA
    _subscribe('repairs', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      if (data['deleted'] == true) await DBHelper().deleteRepairByFirestoreId(docId);
      else await DBHelper().upsertRepair(Repair.fromMap(data));
    }, onDataChanged);

    // LẮNG NGHE ĐƠN BÁN
    _subscribe('sales', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertSale(SaleOrder.fromMap(data));
    }, onDataChanged);

    // LẮNG NGHE KHO
    _subscribe('products', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertProduct(Product.fromMap(data));
    }, onDataChanged);

    // LẮNG NGHE CÔNG NỢ & CHI PHÍ
    _subscribe('expenses', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertExpense(Expense.fromMap(data));
    }, onDataChanged);

    _subscribe('debts', shopId, (data, docId) async {
      data['firestoreId'] = docId;
      await DBHelper().upsertDebt(Debt.fromMap(data));
    }, onDataChanged);

    // LẮNG NGHE NHẬT KÝ (CHỐNG TRÙNG LẶP)
    _subscribe('audit_logs', shopId, (data, docId) async {
      await DBHelper().logAction(
        userId: data['userId'] ?? "",
        userName: data['userName'] ?? "",
        action: data['action'] ?? "",
        type: data['targetType'] ?? "",
        targetId: data['targetId'],
        desc: data['description'],
        fId: docId, // Dùng ID từ Cloud để chống trùng
      );
    }, onDataChanged);
  }

  static void _subscribe(String col, String shopId, Function(Map<String, dynamic>, String) action, VoidCallback onDone) {
    _subscriptions.add(_db.collection(col).where('shopId', isEqualTo: shopId).snapshots().listen((snap) async {
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

  // ĐẨY TOÀN BỘ DỮ LIỆU LÊN CLOUD (GỒM CẢ NHẬT KÝ)
  static Future<void> syncAllToCloud() async {
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return;
    final db = DBHelper();

    // 1. ĐỒNG BỘ NHẬT KÝ HOẠT ĐỘNG
    final logs = await db.getAuditLogs();
    for (var log in logs) {
      final String docId = log['firestoreId'] ?? "log_${log['createdAt']}_${log['userId']}";
      Map<String, dynamic> data = Map<String, dynamic>.from(log);
      data['shopId'] = shopId;
      data['firestoreId'] = docId;
      await _db.collection('audit_logs').doc(docId).set(data, SetOptions(merge: true));
    }

    // 2. ĐỒNG BỘ KHO HÀNG
    final products = await db.getAllProducts();
    for (var p in products) {
      if (p.isSynced && p.firestoreId != null) continue;
      final docId = p.firestoreId ?? "prod_${p.createdAt}_${p.imei ?? p.createdAt}";
      Map<String, dynamic> data = p.toMap();
      data['shopId'] = shopId;
      await _db.collection('products').doc(docId).set(data, SetOptions(merge: true));
      await (await db.database).update('products', {'isSynced': 1, 'firestoreId': docId}, where: 'id = ?', whereArgs: [p.id]);
    }

    // 3. ĐỒNG BỘ ĐƠN BÁN
    final sales = await db.getAllSales();
    for (var s in sales) {
      if (s.isSynced && s.firestoreId != null) continue;
      final docId = s.firestoreId ?? "sale_${s.soldAt}_${s.phone}";
      Map<String, dynamic> data = s.toMap();
      data['shopId'] = shopId;
      await _db.collection('sales').doc(docId).set(data, SetOptions(merge: true));
      await (await db.database).update('sales', {'isSynced': 1, 'firestoreId': docId}, where: 'id = ?', whereArgs: [s.id]);
    }
  }

  static Future<void> downloadAllFromCloud() async {
    final db = DBHelper();
    final shopId = await UserService.getCurrentShopId();
    if (shopId == null) return;

    final cols = ['repairs', 'products', 'sales', 'expenses', 'debts', 'audit_logs'];
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
        else if (col == 'audit_logs') {
          await db.logAction(userId: data['userId']??"", userName: data['userName']??"", action: data['action']??"", type: data['targetType']??"", targetId: data['targetId'], desc: data['description'], fId: doc.id);
        }
      }
    }
  }
}
