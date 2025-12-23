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
      version: 13,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE IF NOT EXISTS repairs(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, model TEXT, issue TEXT, accessories TEXT, address TEXT, imagePath TEXT, deliveredImage TEXT, warranty TEXT, partsUsed TEXT, status INTEGER, price INTEGER, cost INTEGER, paymentMethod TEXT, createdAt INTEGER, startedAt INTEGER, finishedAt INTEGER, deliveredAt INTEGER, createdBy TEXT, repairedBy TEXT, deliveredBy TEXT, lastCaredAt INTEGER, isSynced INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, color TEXT, imei TEXT, condition TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, brand TEXT, imei TEXT, cost INTEGER, price INTEGER, condition TEXT, status INTEGER DEFAULT 1, description TEXT, images TEXT, warranty TEXT, createdAt INTEGER, supplier TEXT, type TEXT DEFAULT "PHONE", quantity INTEGER DEFAULT 1, color TEXT, isSynced INTEGER DEFAULT 0)');
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

  // REPAIRS - Dùng phone_createdAt làm khóa đồng bộ mặc định nếu chưa có firestoreId
  Future<void> upsertRepair(Repair r) async => _upsert('repairs', r.toMap(), r.firestoreId ?? "${r.createdAt}_${r.phone}");
  Future<int> insertRepair(Repair r) async { await upsertRepair(r); return 1; }
  Future<int> updateRepair(Repair r) async => (await database).update('repairs', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  Future<int> deleteRepair(int id) async => (await database).delete('repairs', where: 'id = ?', whereArgs: [id]);
  Future<List<Repair>> getAllRepairs() async {
    final maps = await (await database).query('repairs', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) => Repair.fromMap(maps[i]));
  }
  Future<List<Repair>> getRepairsPaged(int limit, int offset) async {
    final maps = await (await database).query('repairs', orderBy: 'createdAt DESC', limit: limit, offset: offset);
    return List.generate(maps.length, (i) => Repair.fromMap(maps[i]));
  }
  Future<Repair?> getRepairByFirestoreId(String firestoreId) async {
    final res = await (await database).query('repairs', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    return res.isNotEmpty ? Repair.fromMap(res.first) : null;
  }
  Future<Repair?> getRepairById(int id) async {
    final res = await (await database).query('repairs', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? Repair.fromMap(res.first) : null;
  }

  // SALES
  Future<void> upsertSale(SaleOrder s) async => _upsert('sales', s.toMap(), s.firestoreId ?? "sale_${s.soldAt}");
  Future<int> insertSale(SaleOrder s) async { await upsertSale(s); return 1; }
  Future<int> updateSale(SaleOrder s) async => (await database).update('sales', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  Future<int> deleteSale(int id) async => (await database).delete('sales', where: 'id = ?', whereArgs: [id]);
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

  // ATTENDANCE
  Future<int> upsertAttendance(Map<String, dynamic> data) async {
    final db = await database;
    return await db.transaction((txn) async {
      final existing = await txn.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [data['dateKey'], data['userId']], limit: 1);
      if (existing.isNotEmpty) {
        if ((existing.first['locked'] ?? 0) == 1) return 0;
        return await txn.update('attendance', data, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
      return await txn.insert('attendance', data);
    });
  }
  Future<Map<String, dynamic>?> getAttendance(String dateKey, String userId) async {
    final res = await (await database).query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  Future<List<Map<String, dynamic>>> getAttendanceRange(DateTime from, DateTime to, {String? userId}) async {
    final fromK = DateFormat('yyyy-MM-dd').format(from);
    final toK = DateFormat('yyyy-MM-dd').format(to);
    String w = 'dateKey BETWEEN ? AND ?'; List<Object> a = [fromK, toK];
    if (userId != null) { w += ' AND userId = ?'; a.add(userId); }
    return await (await database).query('attendance', where: w, whereArgs: a, orderBy: 'dateKey DESC');
  }
  Future<List<Map<String, dynamic>>> getPendingAttendance({int daysBack = 14}) async {
    final f = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysBack)));
    return await (await database).query('attendance', where: 'dateKey >= ? AND (status IS NULL OR status != ?)', whereArgs: [f, 'approved'], orderBy: 'dateKey DESC');
  }
  Future<int> approveAttendance(int id, {required String approver}) async => await (await database).update('attendance', {'status': 'approved', 'approvedBy': approver, 'approvedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  Future<int> rejectAttendance(int id, {required String approver, String? reason}) async => await (await database).update('attendance', {'status': 'rejected', 'approvedBy': approver, 'approvedAt': DateTime.now().millisecondsSinceEpoch, 'rejectReason': reason}, where: 'id = ?', whereArgs: [id]);
  Future<bool> isPayrollMonthLocked(String m) async => (await (await database).query('payroll_locks', where: 'monthKey = ? AND locked = 1', whereArgs: [m], limit: 1)).isNotEmpty;
  Future<void> setPayrollMonthLock(String m, {required bool locked, required String lockedBy, String? note}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('payroll_locks', {'monthKey': m, 'locked': locked ? 1 : 0, 'lockedBy': lockedBy, 'note': note, 'lockedAt': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.rawUpdate('UPDATE attendance SET locked = ? WHERE dateKey LIKE ?', [locked ? 1 : 0, '$m%']);
    });
  }

  // FINANCE
  Future<int> insertExpense(Map<String, dynamic> e) async => (await database).insert('expenses', e);
  Future<void> upsertExpense(Expense e) async => _upsert('expenses', e.toMap(), e.firestoreId ?? "exp_${e.date}");
  Future<List<Map<String, dynamic>>> getAllExpenses() async => (await database).query('expenses', orderBy: 'date DESC');
  Future<int> deleteExpense(int id) async => (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  Future<int> insertDebt(Map<String, dynamic> d) async => (await database).insert('debts', d);
  Future<void> upsertDebt(Debt d) async => _upsert('debts', d.toMap(), d.firestoreId ?? "debt_${d.createdAt}");
  Future<List<Map<String, dynamic>>> getAllDebts() async => (await database).query('debts', orderBy: 'status ASC, createdAt DESC');
  Future<int> deleteDebt(int id) async => (await database).delete('debts', where: 'id = ?', whereArgs: [id]);
  Future<int> updateDebtPaid(int id, int paid) async {
    final db = await database;
    return await db.transaction((txn) async {
      final List<Map<String, dynamic>> res = await txn.query('debts', where: 'id = ?', whereArgs: [id]);
      if (res.isEmpty) return 0;
      final current = res.first['paidAmount'] as int; final total = res.first['totalAmount'] as int;
      int n = current + paid; if (n > total) n = total;
      return await txn.update('debts', {'paidAmount': n, 'status': n >= total ? "ĐÃ TRẢ" : "NỢ"}, where: 'id = ?', whereArgs: [id]);
    });
  }

  // CLOSINGS
  Future<Map<String, dynamic>?> getClosingByDate(String dateKey) async {
    final res = await (await database).query('cash_closings', where: 'dateKey = ?', whereArgs: [dateKey], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  Future<int> upsertClosing(Map<String, dynamic> closing) async => await (await database).insert('cash_closings', closing, conflictAlgorithm: ConflictAlgorithm.replace);

  // SUPPLIERS
  Future<List<Map<String, dynamic>>> getSuppliers() async => (await database).query('suppliers', orderBy: 'name ASC');
  Future<int> insertSupplier(Map<String, dynamic> s) async => (await database).insert('suppliers', s, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<int> deleteSupplier(int id) async => (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);
  Future<void> incrementSupplierStats(String name, int amount) async {
    final db = await database;
    await db.rawUpdate('UPDATE suppliers SET importCount = importCount + 1, totalAmount = totalAmount + ? WHERE name = ?', [amount, name]);
  }

  // CUSTOMERS
  Future<List<Map<String, dynamic>>> getCustomerSuggestions() async => (await database).rawQuery('SELECT DISTINCT customerName, phone, address FROM (SELECT customerName, phone, address FROM repairs UNION SELECT customerName, phone, address FROM sales UNION SELECT name as customerName, phone, address FROM customers) ORDER BY customerName ASC');
  Future<List<Map<String, dynamic>>> getUniqueCustomersAll() async => (await database).rawQuery('SELECT phone, customerName, address FROM (SELECT phone, customerName, address FROM repairs UNION SELECT phone, customerName, address FROM sales UNION SELECT phone, name as customerName, address FROM customers) as t WHERE phone IS NOT NULL AND phone != "" GROUP BY phone ORDER BY customerName ASC');
  Future<List<Map<String, dynamic>>> getCustomersWithoutShop() async => (await database).query('customers', where: 'shopId IS NULL OR shopId = ""');
  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async { final res = await (await database).query('customers', where: 'phone = ?', whereArgs: [phone], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> insertCustomer(Map<String, dynamic> c) async => (await database).insert('customers', c, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<int> deleteCustomerByPhone(String phone) async => (await database).delete('customers', where: 'phone = ?', whereArgs: [phone]);
  Future<void> deleteCustomerData(String name, String phone) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('repairs', where: 'customerName = ? AND phone = ?', whereArgs: [name, phone]);
      await txn.delete('sales', where: 'customerName = ? AND phone = ?', whereArgs: [name, phone]);
      await txn.delete('customers', where: 'name = ? AND phone = ?', whereArgs: [name, phone]);
    });
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

  // SYNC UTILS
  Future<int> deleteRepairByFirestoreId(String fId) async => (await database).delete('repairs', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<int> deleteSaleByFirestoreId(String fId) async => (await database).delete('sales', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<int> deleteProductByFirestoreId(String fId) async => (await database).delete('products', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<int> deleteDebtByFirestoreId(String fId) async => (await database).delete('debts', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<int> deleteExpenseByFirestoreId(String fId) async => (await database).delete('expenses', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<int> deleteCustomerByFirestoreId(String fId) async => (await database).delete('customers', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<void> cleanDuplicateData() async {
    final db = await database;
    await db.execute('DELETE FROM repairs WHERE id NOT IN (SELECT MAX(id) FROM repairs GROUP BY firestoreId)');
    await db.execute('DELETE FROM sales WHERE id NOT IN (SELECT MAX(id) FROM sales GROUP BY firestoreId)');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = ['repairs', 'products', 'sales', 'suppliers', 'expenses', 'debts', 'customers', 'attendance', 'payroll_locks', 'cash_closings', 'inventory_checks'];
      for (var t in tables) await txn.delete(t);
    });
  }
}
