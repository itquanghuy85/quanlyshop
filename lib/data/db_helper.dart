import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../models/expense_model.dart';
import '../models/debt_model.dart';
import '../models/inventory_check_model.dart';

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
        // ... (Cấu hình CREATE TABLE giữ nguyên như bản gốc để không mất dữ liệu)
        await db.execute('CREATE TABLE IF NOT EXISTS repairs(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, model TEXT, issue TEXT, accessories TEXT, address TEXT, imagePath TEXT, deliveredImage TEXT, warranty TEXT, partsUsed TEXT, status INTEGER, price INTEGER, cost INTEGER, paymentMethod TEXT, createdAt INTEGER, startedAt INTEGER, finishedAt INTEGER, deliveredAt INTEGER, createdBy TEXT, repairedBy TEXT, deliveredBy TEXT, lastCaredAt INTEGER, isSynced INTEGER DEFAULT 0, deleted INTEGER DEFAULT 0, color TEXT, imei TEXT, condition TEXT)');
        await db.execute('CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, brand TEXT, imei TEXT, cost INTEGER, price INTEGER, condition TEXT, status INTEGER DEFAULT 1, description TEXT, images TEXT, warranty TEXT, createdAt INTEGER, supplier TEXT, type TEXT DEFAULT "PHONE", quantity INTEGER DEFAULT 1, color TEXT, capacity TEXT, kpkPrice INTEGER, pkPrice INTEGER, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS sales(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, customerName TEXT, phone TEXT, address TEXT, productNames TEXT, productImeis TEXT, totalPrice INTEGER, totalCost INTEGER, paymentMethod TEXT, sellerName TEXT, soldAt INTEGER, notes TEXT, gifts TEXT, isInstallment INTEGER DEFAULT 0, downPayment INTEGER DEFAULT 0, loanAmount INTEGER DEFAULT 0, installmentTerm TEXT, bankName TEXT, warranty TEXT, settlementPlannedAt INTEGER, settlementReceivedAt INTEGER, settlementAmount INTEGER DEFAULT 0, settlementFee INTEGER DEFAULT 0, settlementNote TEXT, settlementCode TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS customers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, phone TEXT UNIQUE, address TEXT, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS suppliers(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, name TEXT, contactPerson TEXT, phone TEXT, address TEXT, items TEXT, importCount INTEGER DEFAULT 0, totalAmount INTEGER DEFAULT 0, createdAt INTEGER, shopId TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS expenses(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, title TEXT, amount INTEGER, category TEXT, date INTEGER, note TEXT, paymentMethod TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS debts(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, personName TEXT, phone TEXT, totalAmount INTEGER, paidAmount INTEGER DEFAULT 0, type TEXT, status TEXT, createdAt INTEGER, note TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS repair_parts(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, partName TEXT, compatibleModels TEXT, cost INTEGER, price INTEGER, quantity INTEGER DEFAULT 0, createdAt INTEGER, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE IF NOT EXISTS attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, userId TEXT, email TEXT, name TEXT, dateKey TEXT, checkInAt INTEGER, checkOutAt INTEGER, overtimeOn INTEGER DEFAULT 0, photoIn TEXT, photoOut TEXT, note TEXT, status TEXT DEFAULT "pending", approvedBy TEXT, approvedAt INTEGER, rejectReason TEXT, locked INTEGER DEFAULT 0, createdAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS payroll_locks(id INTEGER PRIMARY KEY AUTOINCREMENT, monthKey TEXT UNIQUE, locked INTEGER DEFAULT 1, lockedBy TEXT, note TEXT, lockedAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS cash_closings(id INTEGER PRIMARY KEY AUTOINCREMENT, dateKey TEXT UNIQUE, cashStart INTEGER DEFAULT 0, bankStart INTEGER DEFAULT 0, cashEnd INTEGER DEFAULT 0, bankEnd INTEGER DEFAULT 0, expectedCashDelta INTEGER DEFAULT 0, expectedBankDelta INTEGER DEFAULT 0, note TEXT, createdAt INTEGER)');
        await db.execute('CREATE TABLE IF NOT EXISTS inventory_checks(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, checkType TEXT, checkDate INTEGER, checkedBy TEXT, items TEXT, isCompleted INTEGER DEFAULT 0, isSynced INTEGER DEFAULT 0, createdAt INTEGER)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 14) {
          // Thêm các cột mới cho bảng repairs
          await db.execute('ALTER TABLE repairs ADD COLUMN color TEXT');
          await db.execute('ALTER TABLE repairs ADD COLUMN imei TEXT');
          await db.execute('ALTER TABLE repairs ADD COLUMN condition TEXT');
        }
        if (oldVersion < 15) {
          // Thêm bảng inventory_checks
          await db.execute('CREATE TABLE IF NOT EXISTS inventory_checks(id INTEGER PRIMARY KEY AUTOINCREMENT, firestoreId TEXT UNIQUE, checkType TEXT, checkDate INTEGER, checkedBy TEXT, items TEXT, isCompleted INTEGER DEFAULT 0, isSynced INTEGER DEFAULT 0, createdAt INTEGER)');
        }
        if (oldVersion < 16) {
          // Thêm các cột mới cho bảng products
          await db.execute('ALTER TABLE products ADD COLUMN capacity TEXT');
          await db.execute('ALTER TABLE products ADD COLUMN kpkPrice INTEGER');
          await db.execute('ALTER TABLE products ADD COLUMN pkPrice INTEGER');
        }
        if (oldVersion < 17) {
          // Dọn dẹp các bản ghi trùng firestoreId
          await cleanupDuplicateRepairs();
          await cleanupDuplicateProducts();
          await cleanupDuplicateSales();
        }
      },
    );
  }

  // --- UPSERT LOGIC (TỐI ƯU) ---
  Future<void> _upsert(String table, Map<String, dynamic> map, String firestoreId) async {
    final db = await database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(table, where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
      Map<String, dynamic> data = Map<String, dynamic>.from(map);
      data.remove('id');
      if (existing.isNotEmpty) {
        await txn.update(table, data, where: 'id = ?', whereArgs: [existing.first['id']]);
      } else {
        // Kiểm tra và xóa các record trùng firestoreId trước khi insert
        await txn.delete(table, where: 'firestoreId = ?', whereArgs: [firestoreId]);
        await txn.insert(table, data);
      }
    });
  }

  Future<void> cleanupDuplicateRepairs() async {
    final db = await database;
    await db.transaction((txn) async {
      // Tìm các firestoreId bị trùng
      final duplicates = await txn.rawQuery('''
        SELECT firestoreId, COUNT(*) as count
        FROM repairs 
        WHERE firestoreId IS NOT NULL 
        GROUP BY firestoreId 
        HAVING COUNT(*) > 1
      ''');

      for (var dup in duplicates) {
        final firestoreId = dup['firestoreId'];
        // Giữ lại record có id nhỏ nhất, xóa các record khác
        final records = await txn.query('repairs', 
          where: 'firestoreId = ?', 
          whereArgs: [firestoreId],
          orderBy: 'id ASC'
        );
        
        if (records.length > 1) {
          // Xóa tất cả trừ record đầu tiên
          for (int i = 1; i < records.length; i++) {
            await txn.delete('repairs', where: 'id = ?', whereArgs: [records[i]['id']]);
          }
        }
      }
    });
  }

  Future<void> cleanupDuplicateProducts() async {
    final db = await database;
    await db.transaction((txn) async {
      final duplicates = await txn.rawQuery('''
        SELECT firestoreId, COUNT(*) as count
        FROM products 
        WHERE firestoreId IS NOT NULL 
        GROUP BY firestoreId 
        HAVING COUNT(*) > 1
      ''');

      for (var dup in duplicates) {
        final firestoreId = dup['firestoreId'];
        final records = await txn.query('products', 
          where: 'firestoreId = ?', 
          whereArgs: [firestoreId],
          orderBy: 'id ASC'
        );
        
        if (records.length > 1) {
          for (int i = 1; i < records.length; i++) {
            await txn.delete('products', where: 'id = ?', whereArgs: [records[i]['id']]);
          }
        }
      }
    });
  }

  Future<void> cleanupDuplicateSales() async {
    final db = await database;
    await db.transaction((txn) async {
      final duplicates = await txn.rawQuery('''
        SELECT firestoreId, COUNT(*) as count
        FROM sales 
        WHERE firestoreId IS NOT NULL 
        GROUP BY firestoreId 
        HAVING COUNT(*) > 1
      ''');

      for (var dup in duplicates) {
        final firestoreId = dup['firestoreId'];
        final records = await txn.query('sales', 
          where: 'firestoreId = ?', 
          whereArgs: [firestoreId],
          orderBy: 'id ASC'
        );
        
        if (records.length > 1) {
          for (int i = 1; i < records.length; i++) {
            await txn.delete('sales', where: 'id = ?', whereArgs: [records[i]['id']]);
          }
        }
      }
    });
  }
  Future<void> upsertRepair(Repair r) async => _upsert('repairs', r.toMap(), r.firestoreId ?? "repair_${r.createdAt}_${r.phone}_${r.id ?? 0}");
  Future<void> upsertProduct(Product p) async => _upsert('products', p.toMap(), p.firestoreId ?? "product_${p.createdAt}_${p.imei ?? 'noimei'}_${p.id ?? 0}");
  Future<void> upsertSale(SaleOrder s) async => _upsert('sales', s.toMap(), s.firestoreId ?? "sale_${s.soldAt}_${s.phone}_${s.id ?? 0}");
  Future<void> upsertExpense(Expense e) async => _upsert('expenses', e.toMap(), e.firestoreId ?? "exp_${e.date}");
  Future<void> upsertDebt(Debt d) async => _upsert('debts', d.toMap(), d.firestoreId ?? "debt_${d.createdAt}");

  // --- HÀM BỔ SUNG CHO CHẤM CÔNG (KHÔI PHỤC) ---
  Future<int> upsertAttendance(Map<String, dynamic> data) async {
    final db = await database;
    final dateKey = data['dateKey'];
    final userId = data['userId'];
    return await db.transaction((txn) async {
      final existing = await txn.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
      if (existing.isNotEmpty) {
        if ((existing.first['locked'] ?? 0) == 1) return 0;
        return await txn.update('attendance', data, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
      return await txn.insert('attendance', data);
    });
  }

  Future<Map<String, dynamic>?> getAttendance(String dateKey, String userId) async {
    final db = await database;
    final res = await db.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAttendanceRange(DateTime from, DateTime to, {String? userId}) async {
    final db = await database;
    final fromKey = DateFormat('yyyy-MM-dd').format(from);
    final toKey = DateFormat('yyyy-MM-dd').format(to);
    String where = 'dateKey BETWEEN ? AND ?';
    List<Object> args = [fromKey, toKey];
    if (userId != null) { where += ' AND userId = ?'; args.add(userId); }
    return await db.query('attendance', where: where, whereArgs: args, orderBy: 'dateKey DESC');
  }

  Future<List<Map<String, dynamic>>> getPendingAttendance({int daysBack = 14}) async {
    final db = await database;
    final fromKey = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysBack)));
    return await db.query('attendance', where: 'dateKey >= ? AND (status IS NULL OR status != ?)', whereArgs: [fromKey, 'approved'], orderBy: 'dateKey DESC');
  }

  Future<int> approveAttendance(int id, {required String approver}) async {
    return await (await database).update('attendance', {'status': 'approved', 'approvedBy': approver, 'approvedAt': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> rejectAttendance(int id, {required String approver, String? reason}) async {
    return await (await database).update('attendance', {'status': 'rejected', 'approvedBy': approver, 'approvedAt': DateTime.now().millisecondsSinceEpoch, 'rejectReason': reason}, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isPayrollMonthLocked(String monthKey) async {
    final res = await (await database).query('payroll_locks', where: 'monthKey = ? AND locked = 1', whereArgs: [monthKey], limit: 1);
    return res.isNotEmpty;
  }

  Future<void> setPayrollMonthLock(String monthKey, {required bool locked, required String lockedBy, String? note}) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('payroll_locks', {'monthKey': monthKey, 'locked': locked ? 1 : 0, 'lockedBy': lockedBy, 'note': note, 'lockedAt': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.rawUpdate('UPDATE attendance SET locked = ? WHERE dateKey LIKE ?', [locked ? 1 : 0, '$monthKey%']);
    });
  }

  // --- HÀM BỔ SUNG CHO BÁN HÀNG & KHO (KHÔI PHỤC) ---
  Future<List<Map<String, dynamic>>> getCustomerSuggestions() async {
    final db = await database;
    return await db.rawQuery('SELECT DISTINCT customerName, phone, address FROM (SELECT customerName, phone, address FROM repairs UNION SELECT customerName, phone, address FROM sales UNION SELECT name as customerName, phone, address FROM customers) ORDER BY customerName ASC');
  }

  Future<int> updateProductStatus(int id, int status) async {
    return await (await database).rawUpdate('UPDATE products SET status = ? WHERE id = ?', [status, id]);
  }

  Future<void> deductProductQuantity(int id, int amount) async {
    final db = await database;
    await db.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?', [amount, id]);
    await db.rawUpdate('UPDATE products SET status = 0 WHERE id = ? AND quantity <= 0', [id]);
  }

  // --- TRUY VẤN TỔNG HỢP ---
  Future<List<Map<String, dynamic>>> getUniqueCustomersAll() async {
    final db = await database;
    return await db.rawQuery('SELECT phone, customerName, address FROM (SELECT phone, customerName, address FROM repairs UNION SELECT phone, customerName, address FROM sales UNION SELECT phone, name as customerName, address FROM customers) as t WHERE phone IS NOT NULL AND phone != "" GROUP BY phone ORDER BY customerName ASC');
  }

  // --- CÁC HÀM CƠ BẢN KHÁC ---
  Future<List<Repair>> getAllRepairs() async {
    final rows = await (await database).query('repairs', orderBy: 'createdAt DESC');
    return rows.map((r) => Repair.fromMap(r)).toList();
  }

  Future<List<Product>> getInStockProducts() async {
    final rows = await (await database).query('products', where: 'status = 1 AND quantity > 0');
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  Future<List<SaleOrder>> getAllSales() async {
    final rows = await (await database).query('sales', orderBy: 'soldAt DESC');
    return rows.map((r) => SaleOrder.fromMap(r)).toList();
  }
  Future<List<Map<String, dynamic>>> getCustomers() async => (await database).query('customers', orderBy: 'name ASC');
  Future<List<Map<String, dynamic>>> getCustomersWithoutShop() async => (await database).query('customers', where: 'shopId IS NULL OR shopId = ?', whereArgs: [''], orderBy: 'name ASC');
  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async { final res = await (await database).query('customers', where: 'phone = ?', whereArgs: [phone], limit: 1); return res.isNotEmpty ? res.first : null; }
  Future<int> insertCustomer(Map<String, dynamic> c) async => (await database).insert('customers', c, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<int> updateRepair(Repair r) async {
    final data = r.toMap()..removeWhere((key, value) => value == null);
    return (await database).update('repairs', data, where: 'id = ?', whereArgs: [r.id]);
  }
  Future<int> updateProduct(Product p) async {
    final data = p.toMap()..removeWhere((key, value) => value == null);
    return (await database).update('products', data, where: 'id = ?', whereArgs: [p.id]);
  }
  Future<int> deleteRepairByFirestoreId(String firestoreId) async => (await database).delete('repairs', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  Future<int> deleteSaleByFirestoreId(String firestoreId) async => (await database).delete('sales', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  Future<int> deleteProductByFirestoreId(String firestoreId) async => (await database).delete('products', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  Future<int> deleteDebtByFirestoreId(String firestoreId) async => (await database).delete('debts', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  Future<int> deleteExpenseByFirestoreId(String firestoreId) async => (await database).delete('expenses', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  Future<int> deleteCustomerByFirestoreId(String firestoreId) async => (await database).delete('customers', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  
  Future<void> deleteCustomerData(String customerName, String phone) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('repairs', where: 'customerName = ? AND phone = ?', whereArgs: [customerName, phone]);
      await txn.delete('sales', where: 'customerName = ? AND phone = ?', whereArgs: [customerName, phone]);
      await txn.delete('customers', where: 'name = ? AND phone = ?', whereArgs: [customerName, phone]);
    });
  }

  // --- COMPATIBILITY WRAPPERS FOR LEGACY CALLS ---
  Future<int> insertSale(SaleOrder s) async => (await database).insert('sales', s.toMap());
  Future<int> updateSale(SaleOrder s) async => (await database).update('sales', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  Future<int> deleteSale(int id) async => (await database).delete('sales', where: 'id = ?', whereArgs: [id]);
  Future<SaleOrder?> getSaleByFirestoreId(String firestoreId) async {
    final res = await (await database).query('sales', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    return res.isNotEmpty ? SaleOrder.fromMap(res.first) : null;
  }

  Future<Repair?> getRepairByFirestoreId(String firestoreId) async {
    final res = await (await database).query('repairs', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    return res.isNotEmpty ? Repair.fromMap(res.first) : null;
  }

  Future<Repair?> getRepairById(int id) async {
    final res = await (await database).query('repairs', where: 'id = ?', whereArgs: [id], limit: 1);
    return res.isNotEmpty ? Repair.fromMap(res.first) : null;
  }

  Future<int> insertExpense(Map<String, dynamic> e) async => (await database).insert('expenses', e);

  Future<int> deleteExpense(int id) async => (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  Future<List<Map<String, dynamic>>> getAllExpenses() async => (await database).query('expenses', orderBy: 'date DESC');

  Future<List<Map<String, dynamic>>> getAllDebts() async => (await database).query('debts', orderBy: 'createdAt DESC');
  Future<int> insertDebt(Map<String, dynamic> d) async => (await database).insert('debts', d);
  Future<int> updateDebtPaid(int id, int paid) async => (await database).update('debts', {'paidAmount': paid}, where: 'id = ?', whereArgs: [id]);
  Future<int> deleteDebt(int id) async => (await database).delete('debts', where: 'id = ?', whereArgs: [id]);

  Future<int> insertRepair(Repair r) async => (await database).insert('repairs', r.toMap());
  Future<int> deleteRepair(int id) async => (await database).delete('repairs', where: 'id = ?', whereArgs: [id]);

  Future<int> insertProduct(Product p) async => (await database).insert('products', p.toMap());
  Future<int> deleteProduct(int id) async => (await database).delete('products', where: 'id = ?', whereArgs: [id]);
  Future<List<Product>> getAllProducts() async {
    final rows = await (await database).query('products', orderBy: 'createdAt DESC');
    return rows.map((r) => Product.fromMap(r)).toList();
  }

  // Deletes customer and related records by phone
  Future<int> deleteCustomerByPhone(String phone) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.delete('repairs', where: 'phone = ?', whereArgs: [phone]);
      await txn.delete('sales', where: 'phone = ?', whereArgs: [phone]);
      return await txn.delete('customers', where: 'phone = ?', whereArgs: [phone]);
    });
  }

  // Cleans obvious duplicate records across key tables (safe, id-based keep)
  Future<void> cleanDuplicateData() async {
    final db = await database;
    await db.transaction((txn) async {
      // Keep max(id) per phone for customers
      await txn.rawDelete('DELETE FROM customers WHERE id NOT IN (SELECT MAX(id) FROM customers GROUP BY phone)');
      // Keep latest product by imei or name
      await txn.rawDelete('DELETE FROM products WHERE id NOT IN (SELECT MAX(id) FROM products GROUP BY COALESCE(imei, name))');
      // Keep latest repair/sale by firestoreId or createdAt
      await txn.rawDelete('DELETE FROM repairs WHERE id NOT IN (SELECT MAX(id) FROM repairs GROUP BY COALESCE(firestoreId, createdAt))');
      await txn.rawDelete('DELETE FROM sales WHERE id NOT IN (SELECT MAX(id) FROM sales GROUP BY COALESCE(firestoreId, soldAt))');
    });
  }

  Future<List<Map<String, dynamic>>> getSuppliers() async => (await database).query('suppliers', orderBy: 'name ASC');
  Future<int> insertSupplier(Map<String, dynamic> s) async => (await database).insert('suppliers', s);
  Future<int> deleteSupplier(int id) async => (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);
  Future<void> incrementSupplierStats(String name, int amount) async {
    await (await database).rawUpdate('UPDATE suppliers SET importCount = importCount + 1, totalAmount = totalAmount + ? WHERE name = ?', [amount, name]);
  }

  Future<Map<String, dynamic>?> getClosingByDate(String dateKey) async {
    final res = await (await database).query('cash_closings', where: 'dateKey = ?', whereArgs: [dateKey], limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<int> upsertClosing(Map<String, dynamic> closing) async {
    final db = await database;
    return await db.insert('cash_closings', closing, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Repair>> getRepairsPaged(int pageSize, int offset) async {
    final rows = await (await database).rawQuery('SELECT * FROM repairs ORDER BY createdAt DESC LIMIT ? OFFSET ?', [pageSize, offset]);
    return rows.map((r) => Repair.fromMap(r)).toList();
  }

  // Parts methods
  Future<List<Map<String, dynamic>>> getAllParts() async => (await database).query('repair_parts', orderBy: 'partName ASC');
  Future<int> insertPart(Map<String, dynamic> part) async => (await database).insert('repair_parts', part);
  Future<int> updatePart(int id, Map<String, dynamic> part) async => (await database).update('repair_parts', part, where: 'id = ?', whereArgs: [id]);
  Future<int> deletePart(int id) async => (await database).delete('repair_parts', where: 'id = ?', whereArgs: [id]);

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      final tables = ['repairs', 'products', 'sales', 'suppliers', 'expenses', 'debts', 'customers', 'repair_parts', 'attendance', 'payroll_locks', 'cash_closings'];
      for (var t in tables) {
        try {
          await txn.delete(t);
        } catch (e) {
          // Table might not exist, continue with others
          debugPrint('Table $t does not exist, skipping: $e');
        }
      }
    });
  }

  // --- INVENTORY CHECK METHODS ---
  Future<int> insertInventoryCheck(InventoryCheck check) async {
    final db = await database;
    final map = check.toMap();
    map['items'] = check.items.map((item) => item.toMap()).toList().toString();
    return await db.insert('inventory_checks', map);
  }

  Future<int> updateInventoryCheck(InventoryCheck check) async {
    final db = await database;
    final map = check.toMap();
    map['items'] = check.items.map((item) => item.toMap()).toList().toString();
    return await db.update('inventory_checks', map, where: 'id = ?', whereArgs: [check.id]);
  }

  Future<List<InventoryCheck>> getInventoryChecks({String? checkType, bool? isCompleted}) async {
    final db = await database;
    String where = '';
    List<Object> args = [];

    if (checkType != null) {
      where += 'checkType = ?';
      args.add(checkType);
    }

    if (isCompleted != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'isCompleted = ?';
      args.add(isCompleted ? 1 : 0);
    }

    final rows = await db.query('inventory_checks',
      where: where.isNotEmpty ? where : null,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'createdAt DESC'
    );

    return rows.map((row) => InventoryCheck.fromMap(row)).toList();
  }

  Future<InventoryCheck?> getInventoryCheckById(int id) async {
    final db = await database;
    final rows = await db.query('inventory_checks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return InventoryCheck.fromMap(rows.first);
  }

  Future<int> deleteInventoryCheck(int id) async {
    final db = await database;
    return await db.delete('inventory_checks', where: 'id = ?', whereArgs: [id]);
  }

  // Get items for inventory check based on type
  Future<List<Map<String, dynamic>>> getItemsForInventoryCheck(String type) async {
    final db = await database;
    if (type == 'PHONE') {
      return await db.query('products', where: 'status = 1 AND quantity > 0', orderBy: 'name ASC');
    } else if (type == 'ACCESSORY') {
      return await db.query('repair_parts', where: 'quantity > 0', orderBy: 'partName ASC');
    }
    return [];
  }
}
