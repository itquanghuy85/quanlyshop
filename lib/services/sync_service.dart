import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  static Future<void> initRealTimeSync(Function onDataChanged) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bool isSuperAdmin = UserService.isCurrentUserSuperAdmin();
    final String? shopId = isSuperAdmin ? null : await UserService.getCurrentShopId();

    Query<Map<String, dynamic>> repairsQuery = _db.collection('repairs');
    Query<Map<String, dynamic>> salesQuery = _db.collection('sales');
    Query<Map<String, dynamic>> productsQuery = _db.collection('products');
    Query<Map<String, dynamic>> suppliersQuery = _db.collection('suppliers');
    Query<Map<String, dynamic>> customersQuery = _db.collection('customers');
    Query<Map<String, dynamic>> expensesQuery = _db.collection('expenses');
    Query<Map<String, dynamic>> debtsQuery = _db.collection('debts');

    if (shopId != null) {
      repairsQuery = repairsQuery.where('shopId', isEqualTo: shopId);
      salesQuery = salesQuery.where('shopId', isEqualTo: shopId);
      productsQuery = productsQuery.where('shopId', isEqualTo: shopId);
      suppliersQuery = suppliersQuery.where('shopId', isEqualTo: shopId);
      customersQuery = customersQuery.where('shopId', isEqualTo: shopId);
      expensesQuery = expensesQuery.where('shopId', isEqualTo: shopId);
      debtsQuery = debtsQuery.where('shopId', isEqualTo: shopId);
    }

    repairsQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Repair ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteRepairByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          data['firestoreId'] = change.doc.id; // đảm bảo khóa đồng bộ ổn định
          final r = Repair.fromMap(data);
          print('[sync] Applying repair ${r.firestoreId ?? change.doc.id} to local DB');
          await db.upsertRepair(r);
        }
      }
      onDataChanged();
    });

    salesQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Sale ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteSaleByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
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
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Product ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteProductByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
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
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Supplier ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteSupplierByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          data['firestoreId'] = change.doc.id;
          await db.upsertSupplier(data);
        }
      }
      onDataChanged();
    });

    customersQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Customer ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteCustomerByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          data['firestoreId'] = change.doc.id;
          await db.upsertCustomer(data);
        }
      }
      onDataChanged();
    });

    expensesQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Expense ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteExpenseByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          data['firestoreId'] = change.doc.id;
          await db.upsertExpense(Expense.fromFirestore(data, change.doc.id));
        }
      }
      onDataChanged();
    });

    debtsQuery.snapshots().listen((snapshot) async {
      final db = DBHelper();
      for (var change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        // Nếu Firestore đã đánh dấu là deleted => xóa local theo firestoreId
        if (data['deleted'] == true) {
          print('[sync] Debt ${change.doc.id} marked deleted on Firestore. Deleting local copy.');
          await db.deleteDebtByFirestoreId(change.doc.id);
          continue;
        }

        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          data['firestoreId'] = change.doc.id;
          await db.upsertDebt(Debt.fromFirestore(data, change.doc.id));
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

    final customers = await dbHelper.getCustomers();
    for (var c in customers) {
      final data = Map<String, dynamic>.from(c);
      data.remove('id');
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      final docId = shopId != null ? "${shopId}_${c['phone']}" : (c['phone'] as String);
      await _db.collection('customers').doc(docId).set(data, SetOptions(merge: true));
    }

    final expenses = await dbHelper.getAllExpenses();
    for (var e in expenses) {
      final data = Map<String, dynamic>.from(e);
      data.remove('id');
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      final docId = shopId != null ? "${shopId}_${e['date']}_${e['name']}" : "${e['date']}_${e['name']}";
      await _db.collection('expenses').doc(docId).set(data, SetOptions(merge: true));
    }

    final debts = await dbHelper.getAllDebts();
    for (var d in debts) {
      final data = Map<String, dynamic>.from(d);
      data.remove('id');
      if (shopId != null) {
        data['shopId'] = shopId;
      }
      final docId = shopId != null ? "${shopId}_${d['createdAt']}_${d['name']}" : "${d['createdAt']}_${d['name']}";
      await _db.collection('debts').doc(docId).set(data, SetOptions(merge: true));
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
    Query<Map<String, dynamic>> customersQuery = _db.collection('customers');
    Query<Map<String, dynamic>> expensesQuery = _db.collection('expenses');
    Query<Map<String, dynamic>> debtsQuery = _db.collection('debts');

    if (shopId != null) {
      repairsQuery = repairsQuery.where('shopId', isEqualTo: shopId);
      productsQuery = productsQuery.where('shopId', isEqualTo: shopId);
      salesQuery = salesQuery.where('shopId', isEqualTo: shopId);
      suppliersQuery = suppliersQuery.where('shopId', isEqualTo: shopId);
      customersQuery = customersQuery.where('shopId', isEqualTo: shopId);
      expensesQuery = expensesQuery.where('shopId', isEqualTo: shopId);
      debtsQuery = debtsQuery.where('shopId', isEqualTo: shopId);
    }

    final snaps = await Future.wait([
      repairsQuery.get(),
      productsQuery.get(),
      salesQuery.get(),
      suppliersQuery.get(),
      customersQuery.get(),
      expensesQuery.get(),
      debtsQuery.get(),
    ]);

    for (var doc in snaps[0].docs) {
      final data = doc.data();
      // Nếu Firestore đã đánh dấu deleted thì xóa local nếu có
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted repair ${doc.id} during bulk download');
        await db.deleteRepairByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertRepair(Repair.fromMap(data));
    }
    for (var doc in snaps[1].docs) {
      final data = doc.data();
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted product ${doc.id} during bulk download');
        await db.deleteProductByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertProduct(Product.fromMap(data));
    }
    for (var doc in snaps[2].docs) {
      final data = doc.data();
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted sale ${doc.id} during bulk download');
        await db.deleteSaleByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertSale(SaleOrder.fromMap(data));
    }

    for (var doc in snaps[3].docs) {
      final data = doc.data();
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted supplier ${doc.id} during bulk download');
        await db.deleteSupplierByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertSupplier(data);
    }

    for (var doc in snaps[4].docs) {
      final data = doc.data();
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted customer ${doc.id} during bulk download');
        await db.deleteCustomerByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertCustomer(data);
    }

    for (var doc in snaps[5].docs) {
      final data = doc.data();
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted expense ${doc.id} during bulk download');
        await db.deleteExpenseByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertExpense(Expense.fromFirestore(data, doc.id));
    }

    for (var doc in snaps[6].docs) {
      final data = doc.data();
      if (data['deleted'] == true) {
        print('[sync] Skipping deleted debt ${doc.id} during bulk download');
        await db.deleteDebtByFirestoreId(doc.id);
        continue;
      }
      data['firestoreId'] = doc.id;
      await db.upsertDebt(Debt.fromFirestore(data, doc.id));
    }
  }
}
