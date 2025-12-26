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
import '../models/attendance_model.dart';

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
      version: 23, 
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE IF NOT EXISTS repairs(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, model TEXT, issue TEXT, accessories TEXT, address TEXT, imagePath TEXT, deliveredImage TEXT, warranty TEXT, partsUsed TEXT, status INTEGER, price INTEGER, cost INTEGER, paymentMethod TEXT, createdAt INTEGER, startedAt INTEGER, finishedAt INTEGER, deliveredAt INTEGER, createdBy TEXT, repairedBy TEXT, deliveredBy TEXT, lastCaredAt INTEGER, isSynced INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, color TEXT, imei TEXT, condition TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, brand TEXT, imei TEXT, cost INTEGER, price INTEGER, condition TEXT, status INTEGER DEFAULT 1, description TEXT, images TEXT, warranty TEXT, createdAt INTEGER, supplier TEXT, type TEXT DEFAULT "PHONE", quantity INTEGER DEFAULT 1, color TEXT, isSynced INTEGER DEFAULT 0, capacity TEXT, kpkPrice INTEGER, pkPrice INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, address TEXT, productNames TEXT, productImeis TEXT, totalPrice INTEGER, totalCost INTEGER, paymentMethod TEXT, sellerName TEXT, soldAt INTEGER, notes TEXT, gifts TEXT, isInstallment INTEGER DEFAULT 0, downPayment INTEGER DEFAULT 0, loanAmount INTEGER DEFAULT 0, installmentTerm TEXT, bankName TEXT, warranty TEXT, settlementPlannedAt INTEGER, settlementReceivedAt INTEGER, settlementAmount INTEGER DEFAULT 0, settlementFee INTEGER DEFAULT 0, settlementNote TEXT, settlementCode TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, phone TEXT UNIQUE, address TEXT, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, contactPerson TEXT, phone TEXT, address TEXT, items TEXT, importCount INTEGER DEFAULT 0, totalAmount INTEGER DEFAULT 0, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, title TEXT, amount INTEGER, category TEXT, date INTEGER, note TEXT, paymentMethod TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS debts(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, personName TEXT, phone TEXT, totalAmount INTEGER, paidAmount INTEGER DEFAULT 0, type TEXT, status TEXT, createdAt INTEGER, note TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, userId TEXT, email TEXT, name TEXT, dateKey TEXT, checkInAt INTEGER, checkOutAt INTEGER, overtimeOn INTEGER DEFAULT 0, photoIn TEXT, photoOut TEXT, note TEXT, status TEXT DEFAULT "pending", approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT, locked INTEGER DEFAULT 0, createdAt INTEGER, location TEXT, isLate INTEGER DEFAULT 0, isEarlyLeave INTEGER DEFAULT 0, workSchedule TEXT, updatedAt INTEGER)');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_firestore ON attendance(firestoreId)');
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
        if (oldV < 18) {
          try { 
            await db.execute('DROP TABLE IF EXISTS attendance');
            await db.execute('CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, userId TEXT, email TEXT, name TEXT, dateKey TEXT, checkInAt INTEGER, checkOutAt INTEGER, overtimeOn INTEGER DEFAULT 0, photoIn TEXT, photoOut TEXT, note TEXT, status TEXT DEFAULT "pending", approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT, locked INTEGER DEFAULT 0, createdAt INTEGER, location TEXT, isLate INTEGER DEFAULT 0, isEarlyLeave INTEGER DEFAULT 0, workSchedule TEXT, updatedAt INTEGER)');
            await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_firestore ON attendance(firestoreId)'); 
          } catch(_) {}
        }
        if (oldV < 19) {
          try { 
            await db.execute('ALTER TABLE attendance ADD COLUMN firestoreId TEXT UNIQUE'); 
            await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_firestore ON attendance(firestoreId)'); 
          } catch(_) {}
        }
        if (oldV < 22) {
          try { 
            await db.execute('DROP TABLE IF EXISTS attendance');
            await db.execute('CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, userId TEXT, email TEXT, name TEXT, dateKey TEXT, checkInAt INTEGER, checkOutAt INTEGER, overtimeOn INTEGER DEFAULT 0, photoIn TEXT, photoOut TEXT, note TEXT, status TEXT DEFAULT "pending", approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT, locked INTEGER DEFAULT 0, createdAt INTEGER, location TEXT, isLate INTEGER DEFAULT 0, isEarlyLeave INTEGER DEFAULT 0, workSchedule TEXT, updatedAt INTEGER)');
            await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_firestore ON attendance(firestoreId)'); 
          } catch(_) {}
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
  }

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

  // --- ATTENDANCE ---
  Future<void> upsertAttendance(Attendance a) async {
    final db = await database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [a.dateKey, a.userId], limit: 1);
      Map<String, dynamic> data = Map<String, dynamic>.from(a.toMap());
      data.remove('id');
      if (existing.isNotEmpty) {
        await txn.update('attendance', data, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        await txn.insert('attendance', data);
      }
    });
  }
  Future<int> insertAttendance(Attendance a) async { await upsertAttendance(a); return 1; }
  Future<int> updateAttendance(Attendance a) async => (await database).update('attendance', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  Future<int> deleteAttendance(int id) async => (await database).delete('attendance', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteAttendanceByFirestoreId(String fId) async => (await database).delete('attendance', where: 'firestoreId = ?', whereArgs: [fId]);
  Future<List<Attendance>> getAllAttendance() async {
    final maps = await (await database).query('attendance', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }
  Future<Attendance?> getAttendance(String dateKey, String userId) async {
    final res = await (await database).query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    return res.isNotEmpty ? Attendance.fromMap(res.first) : null;
  }
  Future<List<Attendance>> getAttendanceByUser(String userId, {int? limit}) async {
    final maps = await (await database).query('attendance', where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC', limit: limit);
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }
  Future<List<Attendance>> getAttendanceByDateRange(String startDate, String endDate, {String? userId}) async {
    String whereClause = 'dateKey BETWEEN ? AND ?';
    List<String> whereArgs = [startDate, endDate];
    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }
    final maps = await (await database).query('attendance', where: whereClause, whereArgs: whereArgs, orderBy: 'dateKey DESC');
    return List.generate(maps.length, (i) => Attendance.fromMap(maps[i]));
  }

  // --- WORK SCHEDULES ---
  Future<Map<String, dynamic>?> getWorkSchedule(String userId) async {
    final res = await (await database).query('work_schedules', where: 'userId = ?', whereArgs: [userId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> upsertWorkSchedule(String userId, Map<String, dynamic> schedule) async {
    final db = await database;
    await db.insert('work_schedules', {
      'userId': userId,
      'startTime': schedule['startTime'] ?? '08:00',
      'endTime': schedule['endTime'] ?? '17:00',
      'breakTime': schedule['breakTime'] ?? 1,
      'maxOtHours': schedule['maxOtHours'] ?? 4,
      'workDays': schedule['workDays'] ?? '[1,2,3,4,5,6]',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- ATTENDANCE VIOLATIONS ---
  Future<List<Map<String, dynamic>>> getAttendanceViolations(String userId, DateTime startDate, DateTime endDate) async {
    final maps = await (await database).query(
      'attendance_violations',
      where: 'userId = ? AND timestamp BETWEEN ? AND ?',
      whereArgs: [userId, startDate.millisecondsSinceEpoch, endDate.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC'
    );
    return maps;
  }

  // --- PERFORMANCE STATS ---
  Future<Map<String, dynamic>?> getPerformanceStats(String userId, String month) async {
    final res = await (await database).query('performance_stats', where: 'userId = ? AND month = ?', whereArgs: [userId, month], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }
}
