import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import '../models/purchase_order_model.dart';

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
      version: 17, 
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE IF NOT EXISTS repairs(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, model TEXT, issue TEXT, accessories TEXT, address TEXT, imagePath TEXT, deliveredImage TEXT, warranty TEXT, partsUsed TEXT, status INTEGER, price INTEGER, cost INTEGER, paymentMethod TEXT, createdAt INTEGER, startedAt INTEGER, finishedAt INTEGER, deliveredAt INTEGER, createdBy TEXT, repairedBy TEXT, deliveredBy TEXT, lastCaredAt INTEGER, isSynced INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, color TEXT, imei TEXT, condition TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, brand TEXT, imei TEXT, cost INTEGER, price INTEGER, condition TEXT, status INTEGER DEFAULT 1, description TEXT, images TEXT, warranty TEXT, createdAt INTEGER, supplier TEXT, type TEXT DEFAULT "PHONE", quantity INTEGER DEFAULT 1, color TEXT, isSynced INTEGER DEFAULT 0, capacity TEXT, kpkPrice INTEGER, pkPrice INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, address TEXT, productNames TEXT, productImeis TEXT, totalPrice INTEGER, totalCost INTEGER, paymentMethod TEXT, sellerName TEXT, soldAt INTEGER, notes TEXT, gifts TEXT, isInstallment INTEGER DEFAULT 0, downPayment INTEGER DEFAULT 0, loanAmount INTEGER DEFAULT 0, installmentTerm TEXT, bankName TEXT, warranty TEXT, settlementPlannedAt INTEGER, settlementReceivedAt INTEGER, settlementAmount INTEGER DEFAULT 0, settlementFee INTEGER DEFAULT 0, settlementNote TEXT, settlementCode TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, phone TEXT UNIQUE, address TEXT, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, contactPerson TEXT, phone TEXT, address TEXT, items TEXT, importCount INTEGER DEFAULT 0, totalAmount INTEGER DEFAULT 0, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, title TEXT, amount INTEGER, category TEXT, date INTEGER, note TEXT, paymentMethod TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS debts(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, personName TEXT, phone TEXT, totalAmount INTEGER, paidAmount INTEGER DEFAULT 0, type TEXT, status TEXT, createdAt INTEGER, note TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, email TEXT, name TEXT, dateKey TEXT, checkInAt INTEGER, checkOutAt INTEGER, overtimeOn INTEGER DEFAULT 0, photoIn TEXT, photoOut TEXT, note TEXT, status TEXT DEFAULT "pending", approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT, locked INTEGER DEFAULT 0, createdAt INTEGER, location TEXT, isLate INTEGER DEFAULT 0, isEarlyLeave INTEGER DEFAULT 0, workSchedule TEXT, updatedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS work_schedules(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT UNIQUE, startTime TEXT DEFAULT "08:00", endTime TEXT DEFAULT "17:00", breakTime INTEGER DEFAULT 1, maxOtHours INTEGER DEFAULT 4, workDays TEXT DEFAULT "[1,2,3,4,5,6]", updatedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS attendance_violations(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, date TEXT, type TEXT, timestamp INTEGER, scheduleTime TEXT, actualTime TEXT, status TEXT DEFAULT "active")');
        await db.execute('CREATE TABLE IF NOT EXISTS leave_requests(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, startDate TEXT, endDate TEXT, reason TEXT, status TEXT DEFAULT "pending", submittedAt INTEGER, approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS overtime_requests(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, date TEXT, hours REAL, reason TEXT, status TEXT DEFAULT "pending", submittedAt INTEGER, approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS performance_stats(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, month TEXT, attendanceRate REAL DEFAULT 0, punctualityRate REAL DEFAULT 0, avgHours REAL DEFAULT 0, totalOvertime REAL DEFAULT 0, updatedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS audit_logs(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, userId TEXT, userName TEXT, action TEXT, targetType TEXT, targetId TEXT, description TEXT, createdAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS inventory_checks(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, type TEXT, checkDate INTEGER, itemsJson TEXT, status TEXT, createdBy TEXT, isSynced INTEGER DEFAULT 0, isCompleted INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS cash_closings(id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT UNIQUE, cashStart INTEGER DEFAULT 0, bankStart INTEGER DEFAULT 0, cashEnd INTEGER DEFAULT 0, bankEnd INTEGER DEFAULT 0, expectedCashDelta INTEGER DEFAULT 0, expectedBankDelta INTEGER DEFAULT 0, note TEXT, createdAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS payroll_settings(id INTEGER PRIMARY KEY AUTOINCREMENT, baseSalary INTEGER DEFAULT 0, saleCommPercent REAL DEFAULT 1.0, repairProfitPercent REAL DEFAULT 10.0, updatedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS purchase_orders(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, orderCode TEXT UNIQUE, supplierName TEXT, supplierPhone TEXT, supplierAddress TEXT, itemsJson TEXT, totalAmount INTEGER, totalCost INTEGER, createdAt INTEGER, createdBy TEXT, status TEXT DEFAULT "PENDING", notes TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS repair_parts(id INTEGER PRIMARY KEY AUTOINCREMENT, partName TEXT, compatibleModels TEXT, cost INTEGER, price INTEGER, quantity INTEGER, updatedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS payroll_locks(id INTEGER PRIMARY KEY AUTOINCREMENT, monthKey TEXT UNIQUE, locked INTEGER DEFAULT 0, lockedBy TEXT, lockedAt INTEGER, note TEXT)');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 17) {
          try { await db.execute('ALTER TABLE audit_logs ADD COLUMN firestoreId TEXT'); } catch(_) {}
          try { await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_audit_firestore ON audit_logs(firestoreId)'); } catch(_) {}
        }
      }
    );
  }

  // --- HÀM HỖ TRỢ CHUNG (UPSERT) ---
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

  // --- REPAIRS ---
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

  // --- SALES ---
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

  // --- PRODUCTS ---
  Future<void> upsertProduct(Product p) async => _upsert('products', p.toMap(), p.firestoreId ?? "prod_${p.createdAt}");
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

  // --- CUSTOMERS & SUPPLIERS ---
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
  
  Future<int> insertSupplier(Map<String, dynamic> map) async => (await database).insert('suppliers', map);
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;
    final res = await db.query('suppliers', orderBy: 'name ASC');
    if (res.isEmpty) {
      await db.insert('suppliers', {'name': 'KHO TỔNG', 'contactPerson': 'QUANG HUY', 'phone': '0964095979', 'address': 'HÀ NỘI', 'items': 'ĐIỆN THOẠI, PHỤ KIỆN', 'createdAt': DateTime.now().millisecondsSinceEpoch});
      return await db.query('suppliers', orderBy: 'name ASC');
    }
    return res;
  }
  Future<int> deleteSupplier(int id) async => (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);

  // --- FINANCE ---
  Future<void> upsertExpense(Expense e) async => _upsert('expenses', e.toMap(), e.firestoreId ?? "exp_${e.date}");
  Future<int> insertExpense(Map<String, dynamic> e) async => (await database).insert('expenses', e);
  Future<List<Map<String, dynamic>>> getAllExpenses() async => (await database).query('expenses', orderBy: 'date DESC');
  Future<int> deleteExpenseByFirestoreId(String fId) async => (await database).delete('expenses', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<void> upsertDebt(Debt d) async => _upsert('debts', d.toMap(), d.firestoreId ?? "debt_${d.createdAt}");
  Future<int> insertDebt(Map<String, dynamic> d) async => (await database).insert('debts', d);
  Future<List<Map<String, dynamic>>> getAllDebts() async => (await database).query('debts', orderBy: 'status ASC, createdAt DESC');
  Future<int> updateDebtPaid(int id, int pay) async => await (await database).rawUpdate('UPDATE debts SET paidAmount = paidAmount + ?, status = CASE WHEN (paidAmount + ?) >= totalAmount THEN "paid" ELSE "unpaid" END WHERE id = ?', [pay, pay, id]);
  Future<int> deleteDebtByFirestoreId(String fId) async => (await database).delete('debts', where: 'firestoreId = ?', whereArgs: [fId]);
  
  Future<void> upsertClosing(Map<String, dynamic> map) async {
    final db = await database;
    final dateKey = map['dateKey'];
    final existing = await db.query('cash_closings', where: 'dateKey = ?', whereArgs: [dateKey], limit: 1);
    if (existing.isNotEmpty) await db.update('cash_closings', map, where: 'id = ?', whereArgs: [existing.first['id']]);
    else await db.insert('cash_closings', map);
  }

  // --- ATTENDANCE ---
  Future<void> upsertAttendance(Map<String, dynamic> map) async {
    final db = await database; final dateKey = map['dateKey']; final userId = map['userId'];
    final existing = await db.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    if (existing.isNotEmpty) await db.update('attendance', map, where: 'id = ?', whereArgs: [existing.first['id']]);
    else await db.insert('attendance', map);
  }
  Future<Map<String, dynamic>?> getAttendance(String dateKey, String userId) async {
    final db = await database;
    final res = await db.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
  Future<List<Map<String, dynamic>>> getAttendanceRange(DateTime start, DateTime end) async {
    final db = await database;
    return await db.query('attendance',
      where: 'createdAt >= ? AND createdAt <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'createdAt DESC');
  }
  Future<List<Map<String, dynamic>>> getAttendanceByUser(String userId) async {
    final db = await database; return await db.query('attendance', where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC');
  }

  // --- INVENTORY CHECKS ---
  Future<List<Map<String, dynamic>>> getInventoryChecks({String? checkType, bool? isCompleted}) async {
    final db = await database; String where = '1=1'; List<Object> args = [];
    if (checkType != null) { where += ' AND type = ?'; args.add(checkType); }
    if (isCompleted != null) { where += ' AND isCompleted = ?'; args.add(isCompleted ? 1 : 0); }
    return await db.query('inventory_checks', where: where, whereArgs: args, orderBy: 'checkDate DESC');
  }
  Future<int> insertInventoryCheck(dynamic data) async {
    final db = await database; final map = (data is Map<String, dynamic>) ? data : (data as dynamic).toMap();
    return await db.insert('inventory_checks', map);
  }
  Future<int> updateInventoryCheck(dynamic data) async {
    final db = await database; final map = (data is Map<String, dynamic>) ? data : (data as dynamic).toMap();
    return await db.update('inventory_checks', map, where: 'id = ?', whereArgs: [map['id']]);
  }
  Future<List<Map<String, dynamic>>> getItemsForInventoryCheck(String type) async {
    final db = await database;
    if (type == 'PHONE') return await db.query('products', where: 'status = 1');
    return await db.query('repair_parts');
  }

  // --- PAYROLL & AUDIT LOGS ---
  Future<Map<String, dynamic>> getPayrollSettings() async {
    final db = await database; final res = await db.query('payroll_settings', limit: 1);
    if (res.isEmpty) return {'baseSalary': 0, 'saleCommPercent': 1.0, 'repairProfitPercent': 10.0};
    return res.first;
  }
  Future<void> savePayrollSettings(Map<String, dynamic> data) async {
    final db = await database; await db.delete('payroll_settings'); await db.insert('payroll_settings', data);
  }
  
  Future<void> logAction({required String userId, required String userName, required String action, required String type, String? targetId, String? desc, String? fId}) async {
    final db = await database;
    final String firestoreId = fId ?? "log_${DateTime.now().millisecondsSinceEpoch}_$userId";
    await _upsert('audit_logs', {'userId': userId, 'userName': userName, 'action': action, 'targetType': type, 'targetId': targetId, 'description': desc, 'createdAt': DateTime.now().millisecondsSinceEpoch, 'firestoreId': firestoreId}, firestoreId);
  }
  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final db = await database; return await db.query('audit_logs', orderBy: 'createdAt DESC', limit: 100);
  }

  // --- SYSTEM ---
  Future<void> cleanDuplicateData() async {
    final db = await database;
    await db.execute('DELETE FROM repairs WHERE id NOT IN (SELECT MIN(id) FROM repairs GROUP BY firestoreId)');
    await db.execute('DELETE FROM products WHERE id NOT IN (SELECT MIN(id) FROM products GROUP BY firestoreId)');
    await db.execute('DELETE FROM sales WHERE id NOT IN (SELECT MIN(id) FROM sales GROUP BY firestoreId)');
  }
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = ['repairs', 'products', 'sales', 'suppliers', 'expenses', 'debts', 'customers', 'attendance', 'audit_logs', 'inventory_checks', 'cash_closings', 'payroll_settings', 'purchase_orders'];
      for (var t in tables) await txn.delete(t);
    });
  }

<<<<<<< HEAD
  // --- PARTS INVENTORY (missing methods) ---
  Future<List<Map<String, dynamic>>> getAllParts() async {
    final db = await database;
    return await db.query('products', where: 'type = ?', whereArgs: ['PART'], orderBy: 'name ASC');
  }

  Future<int> insertPart(Map<String, dynamic> part) async {
    final db = await database;
    return await db.insert('products', part);
  }

  // --- PAYROLL LOCKING (missing methods) ---
  Future<bool> isPayrollMonthLocked(String monthKey) async {
    final db = await database;
    final res = await db.query('cash_closings', where: 'dateKey = ? AND locked = 1', whereArgs: [monthKey], limit: 1);
    return res.isNotEmpty;
=======
  // --- PURCHASE ORDERS ---
  Future<String> generateNextOrderCode() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM purchase_orders');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return 'PO${(count + 1).toString().padLeft(3, '0')}';
  }

  Future<void> insertPurchaseOrder(PurchaseOrder order) async {
    final db = await database;
    await db.insert('purchase_orders', {
      'firestoreId': order.firestoreId,
      'orderCode': order.orderCode,
      'supplierName': order.supplierName,
      'supplierPhone': order.supplierPhone,
      'supplierAddress': order.supplierAddress,
      'itemsJson': order.items.map((item) => item.toMap()).toList().toString(),
      'totalAmount': order.totalAmount,
      'totalCost': order.totalCost,
      'createdAt': order.createdAt,
      'createdBy': order.createdBy,
      'status': order.status,
      'notes': order.notes,
      'isSynced': 0,
    });
  }

  Future<void> updatePurchaseOrder(PurchaseOrder order) async {
    final db = await database;
    await db.update('purchase_orders', {
      'firestoreId': order.firestoreId,
      'status': order.status,
      'isSynced': 1,
    }, where: 'orderCode = ?', whereArgs: [order.orderCode]);
  }

  Future<List<PurchaseOrder>> getAllPurchaseOrders() async {
    final db = await database;
    final results = await db.query('purchase_orders', orderBy: 'createdAt DESC');
    return results.map((row) {
      final map = Map<String, dynamic>.from(row);
      if (map['itemsJson'] != null) {
        try {
          final itemsList = jsonDecode(map['itemsJson']) as List;
          map['items'] = itemsList.map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>)).toList();
        } catch (e) {
          map['items'] = [];
        }
      } else {
        map['items'] = [];
      }
      return PurchaseOrder.fromMap(map);
    }).toList();
  }

  // --- REPAIR PARTS ---
  Future<List<Map<String, dynamic>>> getAllParts() async {
    final db = await database;
    return await db.query('repair_parts', orderBy: 'partName ASC');
  }

  Future<int> insertPart(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('repair_parts', data);
  }

  // --- PAYROLL LOCKS ---
  Future<bool> isPayrollMonthLocked(String monthKey) async {
    final db = await database;
    final result = await db.query('payroll_locks', where: 'monthKey = ?', whereArgs: [monthKey], limit: 1);
    return result.isNotEmpty && (result.first['locked'] as int) == 1;
>>>>>>> e7fff18 (TINH CHINH GIAO DIEN HOME CHINH TINH LUONG)
  }

  Future<void> setPayrollMonthLock(String monthKey, {required bool locked, String? lockedBy, String? note}) async {
    final db = await database;
<<<<<<< HEAD
    final existing = await db.query('cash_closings', where: 'dateKey = ?', whereArgs: [monthKey], limit: 1);
    if (existing.isNotEmpty) {
      await db.update('cash_closings', {
        'locked': locked ? 1 : 0,
        'lockedBy': lockedBy,
        'lockNote': note,
        'lockedAt': DateTime.now().millisecondsSinceEpoch,
      }, where: 'dateKey = ?', whereArgs: [monthKey]);
    } else {
      await db.insert('cash_closings', {
        'dateKey': monthKey,
        'locked': locked ? 1 : 0,
        'lockedBy': lockedBy,
        'lockNote': note,
        'lockedAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }
=======
    final data = {
      'monthKey': monthKey,
      'locked': locked ? 1 : 0,
      'lockedBy': lockedBy,
      'lockedAt': DateTime.now().millisecondsSinceEpoch,
      'note': note,
    };
    await _upsert('payroll_locks', data, monthKey);
  }

  // --- ADVANCED ATTENDANCE FEATURES ---

  // Work Schedule Management
  Future<Map<String, dynamic>?> getWorkSchedule(String userId) async {
    final db = await database;
    final res = await db.query('work_schedules', where: 'userId = ?', whereArgs: [userId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> updateWorkSchedule(Map<String, dynamic> schedule) async {
    final db = await database;
    final userId = schedule['userId'];
    final existing = await db.query('work_schedules', where: 'userId = ?', whereArgs: [userId], limit: 1);
    if (existing.isNotEmpty) {
      await db.update('work_schedules', schedule, where: 'userId = ?', whereArgs: [userId]);
    } else {
      await db.insert('work_schedules', schedule);
    }
  }

  // Attendance Violations
  Future<void> logAttendanceViolation(Map<String, dynamic> violation) async {
    final db = await database;
    await db.insert('attendance_violations', violation);
  }

  Future<List<Map<String, dynamic>>> getAttendanceViolations(String userId, DateTime start, DateTime end) async {
    final db = await database;
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);
    return await db.query(
      'attendance_violations',
      where: 'userId = ? AND date BETWEEN ? AND ?',
      whereArgs: [userId, startStr, endStr],
      orderBy: 'timestamp DESC',
    );
  }

  // Leave Requests
  Future<void> submitLeaveRequest(Map<String, dynamic> request) async {
    final db = await database;
    await db.insert('leave_requests', request);
  }

  Future<List<Map<String, dynamic>>> getLeaveRequests(String userId, {String? status}) async {
    final db = await database;
    String where = 'userId = ?';
    List<String> args = [userId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    return await db.query('leave_requests', where: where, whereArgs: args, orderBy: 'submittedAt DESC');
  }

  Future<void> updateLeaveRequestStatus(int id, String status, {String? approvedBy, String? rejectReason}) async {
    final db = await database;
    final data = {
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': DateTime.now().millisecondsSinceEpoch,
      'rejectReason': rejectReason,
    };
    await db.update('leave_requests', data, where: 'id = ?', whereArgs: [id]);
  }

  // Overtime Requests
  Future<void> submitOvertimeRequest(Map<String, dynamic> request) async {
    final db = await database;
    await db.insert('overtime_requests', request);
  }

  Future<List<Map<String, dynamic>>> getOvertimeRequests(String userId, {String? status}) async {
    final db = await database;
    String where = 'userId = ?';
    List<String> args = [userId];
    if (status != null) {
      where += ' AND status = ?';
      args.add(status);
    }
    return await db.query('overtime_requests', where: where, whereArgs: args, orderBy: 'submittedAt DESC');
  }

  Future<void> updateOvertimeRequestStatus(int id, String status, {String? approvedBy, String? rejectReason}) async {
    final db = await database;
    final data = {
      'status': status,
      'approvedBy': approvedBy,
      'approvedAt': DateTime.now().millisecondsSinceEpoch,
      'rejectReason': rejectReason,
    };
    await db.update('overtime_requests', data, where: 'id = ?', whereArgs: [id]);
  }

  // Performance Statistics
  Future<Map<String, dynamic>?> getPerformanceStats(String userId, DateTime start, DateTime end) async {
    final db = await database;
    final month = DateFormat('yyyy-MM').format(start);
    final existing = await db.query('performance_stats', where: 'userId = ? AND month = ?', whereArgs: [userId, month], limit: 1);

    if (existing.isNotEmpty) {
      return existing.first;
    }

    // Calculate performance stats
    final attendanceData = await getAttendanceByUser(userId);
    final monthData = attendanceData.where((a) {
      final date = DateTime.parse(a['dateKey']);
      return date.isAfter(start.subtract(const Duration(days: 1))) && date.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    if (monthData.isEmpty) {
      return {
        'attendanceRate': 0.0,
        'punctualityRate': 0.0,
        'avgHours': 0.0,
        'totalOvertime': 0.0,
      };
    }

    final totalDays = monthData.length;
    final presentDays = monthData.where((a) => a['checkInAt'] != null).length;
    final onTimeDays = monthData.where((a) => a['isLate'] == 0 || a['isLate'] == null).length;
    final totalHours = monthData.fold<double>(0, (sum, a) {
      final inMs = a['checkInAt'] as int?;
      final outMs = a['checkOutAt'] as int?;
      if (inMs != null && outMs != null) {
        return sum + (outMs - inMs) / (1000 * 60 * 60);
      }
      return sum;
    });

    final stats = {
      'userId': userId,
      'month': month,
      'attendanceRate': totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0,
      'punctualityRate': presentDays > 0 ? (onTimeDays / presentDays) * 100 : 0.0,
      'avgHours': totalDays > 0 ? totalHours / totalDays : 0.0,
      'totalOvertime': monthData.fold<double>(0, (sum, a) => sum + ((a['overtimeOn'] ?? 0) == 1 ? 1 : 0)),
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    await db.insert('performance_stats', stats);
    return stats;
  }

  // Enhanced Attendance Queries
  Future<List<Map<String, dynamic>>> getAttendanceWithViolations(String userId, DateTime start, DateTime end) async {
    final db = await database;
    final attendance = await getAttendanceByUser(userId);
    final violations = await getAttendanceViolations(userId, start, end);

    // Merge attendance with violations
    final result = attendance.map((a) {
      final date = a['dateKey'];
      final dayViolations = violations.where((v) => v['date'] == date).toList();
      return {
        ...a,
        'violations': dayViolations,
        'hasViolations': dayViolations.isNotEmpty,
      };
    }).toList();

    return result;
  }

  // Admin Functions for Attendance Management
  Future<List<Map<String, dynamic>>> getAllPendingLeaveRequests() async {
    final db = await database;
    return await db.query('leave_requests', where: 'status = ?', whereArgs: ['pending'], orderBy: 'submittedAt ASC');
  }

  Future<List<Map<String, dynamic>>> getAllPendingOvertimeRequests() async {
    final db = await database;
    return await db.query('overtime_requests', where: 'status = ?', whereArgs: ['pending'], orderBy: 'submittedAt ASC');
  }

  Future<Map<String, dynamic>> getTeamAttendanceStats(DateTime start, DateTime end) async {
    final db = await database;
    final attendance = await getAttendanceRange(start, end);

    final totalUsers = <String>{};
    final presentUsers = <String>{};
    int totalLate = 0;
    int totalEarlyLeave = 0;
    double totalHours = 0;
    int totalRecords = attendance.length;

    for (final record in attendance) {
      final userId = record['userId'] as String;
      totalUsers.add(userId);

      if (record['checkInAt'] != null) {
        presentUsers.add(userId);
      }

      if (record['isLate'] == 1) totalLate++;
      if (record['isEarlyLeave'] == 1) totalEarlyLeave++;

      final inMs = record['checkInAt'] as int?;
      final outMs = record['checkOutAt'] as int?;
      if (inMs != null && outMs != null) {
        totalHours += (outMs - inMs) / (1000 * 60 * 60);
      }
    }

    return {
      'totalUsers': totalUsers.length,
      'presentUsers': presentUsers.length,
      'absentUsers': totalUsers.length - presentUsers.length,
      'attendanceRate': totalUsers.isNotEmpty ? (presentUsers.length / totalUsers.length) * 100 : 0,
      'totalLate': totalLate,
      'totalEarlyLeave': totalEarlyLeave,
      'avgHoursPerDay': totalRecords > 0 ? totalHours / totalRecords : 0,
      'totalRecords': totalRecords,
    };
  }
>>>>>>> e7fff18 (TINH CHINH GIAO DIEN HOME CHINH TINH LUONG)
}
