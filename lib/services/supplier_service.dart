import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/supplier_model.dart';
import '../models/supplier_import_history_model.dart';
import '../models/supplier_product_prices_model.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';

class SupplierService {
  final db = DBHelper();

  // Supplier CRUD
  Future<List<Supplier>> getSuppliers() async {
    final shopId = await UserService.getCurrentShopId();
    final data = await db.getSuppliers();
    return data
        .where((s) => s['shopId'] == shopId)
        .map((s) => Supplier.fromMap(s))
        .toList();
  }

  Future<Supplier?> addSupplier(Supplier supplier) async {
    final supplierMap = supplier.toMap();
    supplierMap['shopId'] = await UserService.getCurrentShopId();
    supplierMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    supplierMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insertSupplier(supplierMap);
    if (id > 0) {
      final firestoreId = await FirestoreService.addSupplier(supplierMap);
      if (firestoreId != null) {
        await db.updateSupplier(id, {'firestoreId': firestoreId});
        return supplier.copyWith(id: id);
      }
    }
    return null;
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    final supplierMap = supplier.toMap();
    supplierMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    final result = await db.updateSupplier(supplier.id!, supplierMap);
    if (result > 0) {
      await FirestoreService.updateSupplier(supplierMap);
      return true;
    }
    return false;
  }

  Future<bool> deleteSupplier(int supplierId) async {
    final result = await db.deleteSupplier(supplierId);
    if (result > 0) {
      await FirestoreService.deleteSupplier(supplierId.toString());
      return true;
    }
    return false;
  }

  // Supplier Import History
  Future<List<SupplierImportHistory>> getSupplierImportHistory(String supplierId) async {
    final shopId = await UserService.getCurrentShopId();
    final data = await db.getSupplierImportHistory(int.parse(supplierId));
    return data
        .where((h) => h['shopId'] == shopId)
        .map((h) => SupplierImportHistory.fromMap(h))
        .toList();
  }

  Future<SupplierImportHistory?> addSupplierImportHistory(SupplierImportHistory history) async {
    final historyMap = history.toMap();
    historyMap['shopId'] = await UserService.getCurrentShopId();
    historyMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    historyMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insertSupplierImportHistory(historyMap);
    if (id > 0) {
      final firestoreId = await FirestoreService.addSupplierImportHistory(historyMap);
      if (firestoreId != null) {
        await db.updateSupplierImportHistory(id, {'firestoreId': firestoreId});
        return history.copyWith(id: id);
      }
    }
    return null;
  }

  // Supplier Product Prices
  Future<List<SupplierProductPrices>> getSupplierProductPrices(String supplierId) async {
    final shopId = await UserService.getCurrentShopId();
    final data = await db.getSupplierProductPrices(int.parse(supplierId));
    return data
        .where((p) => p['shopId'] == shopId)
        .map((p) => SupplierProductPrices.fromMap(p))
        .toList();
  }

  Future<SupplierProductPrices?> addSupplierProductPrices(SupplierProductPrices prices) async {
    final pricesMap = prices.toMap();
    pricesMap['shopId'] = await UserService.getCurrentShopId();
    pricesMap['createdAt'] = DateTime.now().millisecondsSinceEpoch;
    pricesMap['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insertSupplierProductPrices(pricesMap);
    if (id > 0) {
      final firestoreId = await FirestoreService.addSupplierProductPrices(pricesMap);
      if (firestoreId != null) {
        await db.updateSupplierProductPrices(id, {'firestoreId': firestoreId});
        return prices.copyWith(id: id);
      }
    }
    return null;
  }

  // Statistics
  Future<Map<String, dynamic>> getSupplierStatistics(String supplierId) async {
    final shopId = await UserService.getCurrentShopId();
    final data = await db.getSupplierStatistics(supplierId, shopId!);

    double totalPaid = 0;
    double totalOwed = 0;
    int totalImports = 0;
    double totalImportValue = 0;

    // Calculate from payments
    final payments = await db.getSupplierPayments(int.parse(supplierId));
    for (var payment in payments.where((p) => p['shopId'] == shopId)) {
      totalPaid += payment['amount'] ?? 0;
    }

    // Calculate from import history
    final imports = await db.getSupplierImportHistory(int.parse(supplierId));
    for (var import in imports.where((i) => i['shopId'] == shopId)) {
      totalImports++;
      totalImportValue += import['totalCost'] ?? 0;
    }

    totalOwed = totalImportValue - totalPaid;

    return {
      'totalPaid': totalPaid,
      'totalOwed': totalOwed,
      'totalImports': totalImports,
      'totalImportValue': totalImportValue,
    };
  }
}