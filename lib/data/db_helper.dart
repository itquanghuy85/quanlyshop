import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;
  DBHelper._internal();
  factory DBHelper() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'repair_shop_v22.db'); 
    return await openDatabase(
      path,
      version: 14, 
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE IF NOT EXISTS repairs(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, model TEXT, issue TEXT, accessories TEXT, address TEXT, imagePath TEXT, deliveredImage TEXT, warranty TEXT, partsUsed TEXT, status INTEGER, price INTEGER, cost INTEGER, paymentMethod TEXT, createdAt INTEGER, startedAt INTEGER, finishedAt INTEGER, deliveredAt INTEGER, createdBy TEXT, repairedBy TEXT, deliveredBy TEXT, lastCaredAt INTEGER, isSynced INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, color TEXT, imei TEXT, condition TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, brand TEXT, imei TEXT, cost INTEGER, price INTEGER, condition TEXT, status INTEGER DEFAULT 1, description TEXT, images TEXT, warranty TEXT, createdAt INTEGER, supplier TEXT, type TEXT DEFAULT "PHONE", quantity INTEGER DEFAULT 1, color TEXT, isSynced INTEGER DEFAULT 0, capacity TEXT, kpkPrice INTEGER, pkPrice INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, address TEXT, productNames TEXT, productImeis TEXT, totalPrice INTEGER, totalCost INTEGER, paymentMethod TEXT, sellerName TEXT, soldAt INTEGER, notes TEXT, gifts TEXT, isInstallment INTEGER DEFAULT 0, downPayment INTEGER DEFAULT 0, loanAmount INTEGER DEFAULT 0, installmentTerm TEXT, bankName TEXT, warranty TEXT, settlementPlannedAt INTEGER, settlementReceivedAt INTEGER, settlementAmount INTEGER DEFAULT 0, settlementFee INTEGER DEFAULT 0, settlementNote TEXT, settlementCode TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, phone TEXT UNIQUE, address TEXT, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, contactPerson TEXT, phone TEXT, address TEXT, items TEXT, importCount INTEGER DEFAULT 0, totalAmount INTEGER DEFAULT 0, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, title TEXT, amount INTEGER, category TEXT, date INTEGER, note TEXT, paymentMethod TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS debts(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, personName TEXT, phone TEXT, totalAmount INTEGER, paidAmount INTEGER DEFAULT 0, type TEXT, status TEXT, createdAt INTEGER, note TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, email TEXT, name TEXT, dateKey TEXT, checkInAt INTEGER, checkOutAt INTEGER, overtimeOn INTEGER DEFAULT 0, photoIn TEXT, photoOut TEXT, note TEXT, status TEXT DEFAULT "pending", approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT, locked INTEGER DEFAULT 0, createdAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS payroll_locks(id INTEGER PRIMARY KEY AUTOINCREMENT, monthKey TEXT UNIQUE, locked INTEGER DEFAULT 1, lockedBy TEXT, note TEXT, lockedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS cash_closings(id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT UNIQUE, cashStart INTEGER DEFAULT 0, bankStart INTEGER DEFAULT 0, cashEnd INTEGER DEFAULT 0, bankEnd INTEGER DEFAULT 0, expectedCashDelta INTEGER DEFAULT 0, expectedBankDelta INTEGER DEFAULT 0, note TEXT, createdAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS inventory_checks(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, type TEXT, checkDate INTEGER, itemsJson TEXT, status TEXT, createdBy TEXT, isSynced INTEGER DEFAULT 0, isCompleted INTEGER DEFAULT 0)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 14) {
          try { await db.execute("ALTER TABLE products ADD COLUMN capacity TEXT"); } catch(_) {}
          try { await db.execute("ALTER TABLE products ADD COLUMN kpkPrice INTEGER"); } catch(_) {}
          try { await db.execute("ALTER TABLE products ADD COLUMN pkPrice INTEGER"); } catch(_) {}
        }
      }
    );
  }

  Future<void> _upsert(String table, Map<String, dynamic> map, String firestoreId) async {
    final db = await database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(table, where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
      Map<String, dynamic> data = Map<String, dynamic>.from(map);
      data.remove('id');
      if (existing.isNotEmpty) {
        await txn.update(table, data, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        await txn.insert(table, data);
      }
    });
  }

  // REPAIRS
  Future<void> upsertRepair(Repair r) async => _upsert('repairs', r.toMap(), r.firestoreId ?? "${r.createdAt}_${r.phone}");
  Future<int> insertRepair(Repair r) async { await upsertRepair(r); return 1; }
  Future<int> updateRepair(Repair r) async => (await database).update('repairs', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  Future<int> deleteRepair(int id) async => (await database).delete('repairs', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteRepairByFirestoreId(String fId) async => (await database).delete('repairs', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<List<Repair>> getAllRepairs() async {
    final maps = await (await database).query('repairs', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) => Repair.fromMap(maps[i]));
  }
  Future<Repair?> getRepairById(int id) async {
    final res = await (await database).query('repairs', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? Repair.fromMap(res.first) : null;
  }
  Future<Repair?> getRepairByFirestoreId(String firestoreId) async {
    final res = await (await database).query('repairs', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    return res.isNotEmpty ? Repair.fromMap(res.first) : null;
  }

  // SALES
  Future<void> upsertSale(SaleOrder s) async => _upsert('sales', s.toMap(), s.firestoreId ?? "sale_${s.soldAt}");
  Future<int> insertSale(SaleOrder s) async { await upsertSale(s); return 1; }
  Future<int> updateSale(SaleOrder s) async => (await database).update('sales', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  Future<int> deleteSale(int id) async => (await database).delete('sales', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteSaleByFirestoreId(String fId) async => (await database).delete('sales', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<List<SaleOrder>> getAllSales() async {
    final maps = await (await database).query('sales', orderBy: 'soldAt DESC');
    return List.generate(maps.length, (i) => SaleOrder.fromMap(maps[i]));
  }
  Future<SaleOrder?> getSaleByFirestoreId(String firestoreId) async {
    final res = await (await database).query('sales', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    return res.isNotEmpty ? SaleOrder.fromMap(res.first) : null;
  }

  // PRODUCTS
  Future<void> upsertProduct(Product p) async => _upsert('products', p.toMap(), p.firestoreId ?? "prod_${p.createdAt}");
  Future<int> insertProduct(Product p) async { await upsertProduct(p); return 1; }
  Future<int> updateProduct(Product p) async => (await database).update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  Future<int> deleteProduct(int id) async => (await database).delete('products', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteProductByFirestoreId(String fId) async => (await database).delete('products', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<List<Product>> getInStockProducts() async {
    final maps = await (await database).query('products', where: 'status = 1 AND quantity > 0');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }
  Future<List<Product>> getAllProducts() async {
    final maps = await (await database).query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }
  Future<int> updateProductStatus(int id, int status) async => await (await database).rawUpdate('UPDATE products SET status = ? WHERE id = ?', [status, id]);
  Future<void> deductProductQuantity(int id, int amount) async {
    final db = await database;
    await db.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?', [amount, id]);
    await db.rawUpdate('UPDATE products SET status = 0 WHERE id = ? AND quantity <= 0', [id]);
  }

  // SUPPLIERS
  Future<int> insertSupplier(Map<String, dynamic> map) async => (await database).insert('suppliers', map);
  Future<List<Map<String, dynamic>>> getSuppliers() async => (await database).query('suppliers', orderBy: 'name ASC');
  Future<int> deleteSupplier(int id) async => (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);

  // FINANCE
  Future<void> upsertExpense(Expense e) async => _upsert('expenses', e.toMap(), e.firestoreId ?? "exp_${e.date}");
  Future<int> insertExpense(Map<String, dynamic> e) async => (await database).insert('expenses', e);
  Future<List<Map<String, dynamic>>> getAllExpenses() async => (await database).query('expenses', orderBy: 'date DESC');
  Future<int> deleteExpenseByFirestoreId(String fId) async => (await database).delete('expenses', where: 'firestoreId = ?', whereArgs: [fId]);

  Future<void> upsertDebt(Debt d) async => _upsert('debts', d.toMap(), d.firestoreId ?? "debt_${d.createdAt}");
  Future<int> insertDebt(Map<String, dynamic> d) async => (await database).insert('debts', d);
  Future<List<Map<String, dynamic>>> getAllDebts() async => (await database).query('debts', orderBy: 'status ASC, createdAt DESC');
  Future<int> deleteDebtByFirestoreId(String fId) async => (await database).delete('debts', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<int> updateDebtPaid(int id, int pay) async => await (await database).rawUpdate('UPDATE debts SET paidAmount = paidAmount + ?, status = CASE WHEN (paidAmount + ?) >= totalAmount THEN "paid" ELSE "unpaid" END WHERE id = ?', [pay, pay, id]);

  // CLOSINGS
  Future<void> upsertClosing(Map<String, dynamic> map) async {
    final db = await database;
    final dateKey = map['dateKey'];
    final List<Map<String, dynamic>> existing = await db.query('cash_closings', where: 'dateKey = ?', whereArgs: [dateKey], limit: 1);
    if (existing.isNotEmpty) {
      await db.update('cash_closings', map, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('cash_closings', map);
    }
  }

  // INVENTORY CHECKS
  Future<List<Map<String, dynamic>>> getItemsForInventoryCheck(String type) async {
    final db = await database;
    if (type == 'PHONE') return await db.query('products', where: 'status = 1');
    return await db.query('repair_parts');
  }
  Future<List<Map<String, dynamic>>> getInventoryChecks({String? checkType, bool? isCompleted}) async {
    final db = await database;
    String where = '1=1'; List<Object> args = [];
    if (checkType != null) { where += ' AND type = ?'; args.add(checkType); }
    if (isCompleted != null) { where += ' AND isCompleted = ?'; args.add(isCompleted ? 1 : 0); }
    return await db.query('inventory_checks', where: where, whereArgs: args, orderBy: 'checkDate DESC');
  }
  Future<int> insertInventoryCheck(dynamic data) async {
    final db = await database;
    final map = (data is Map<String, dynamic>) ? data : (data as dynamic).toMap();
    return await db.insert('inventory_checks', map);
  }
  Future<int> updateInventoryCheck(dynamic data) async {
    final db = await database;
    final map = (data is Map<String, dynamic>) ? data : (data as dynamic).toMap();
    return await db.update('inventory_checks', map, where: 'id = ?', whereArgs: [map['id']]);
  }

  // OTHERS
  Future<List<Map<String, dynamic>>> getCustomerSuggestions() async => (await database).rawQuery('SELECT DISTINCT customerName, phone, address FROM (SELECT customerName, phone, address FROM repairs UNION SELECT customerName, phone, address FROM sales UNION SELECT name as customerName, phone, address FROM customers) ORDER BY customerName ASC');
  Future<List<Map<String, dynamic>>> getUniqueCustomersAll() async => (await database).rawQuery('SELECT phone, customerName, address FROM (SELECT phone, customerName, address FROM repairs UNION SELECT phone, customerName, address FROM sales UNION SELECT phone, name as customerName, address FROM customers) as t WHERE phone IS NOT NULL AND phone != "" GROUP BY phone ORDER BY customerName ASC');
  Future<List<Map<String, dynamic>>> getCustomersWithoutShop() async => (await database).query('customers', where: 'shopId IS NULL OR shopId = ""');
  Future<void> deleteCustomerData(String name, String phone) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('repairs', where: 'customerName = ? AND phone = ?', whereArgs: [name, phone]);
      await txn.delete('sales', where: 'customerName = ? AND phone = ?', whereArgs: [name, phone]);
      await txn.delete('customers', where: 'name = ? AND phone = ?', whereArgs: [name, phone]);
    });
  }
  Future<int> deleteCustomerByPhone(String phone) async => (await database).delete('customers', where: 'phone = ?', whereArgs: [phone]);

  // SYSTEM
  Future<void> cleanDuplicateData() async {
    final db = await database;
    // Simple implementation to clean duplicates based on firestoreId
    await db.execute('DELETE FROM repairs WHERE id NOT IN (SELECT MIN(id) FROM repairs GROUP BY firestoreId)');
    await db.execute('DELETE FROM products WHERE id NOT IN (SELECT MIN(id) FROM products GROUP BY firestoreId)');
    await db.execute('DELETE FROM sales WHERE id NOT IN (SELECT MIN(id) FROM sales GROUP BY firestoreId)');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = ['repairs', 'products', 'sales', 'suppliers', 'expenses', 'debts', 'customers', 'attendance', 'payroll_locks', 'cash_closings', 'inventory_checks'];
      for (var t in tables) await txn.delete(t);
    });
  }
}
