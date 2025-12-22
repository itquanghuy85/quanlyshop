import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';

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
    String path = join(await getDatabasesPath(), 'repair_shop_v19.db'); 
    return await openDatabase(
      path,
      version: 9,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE repairs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firestoreId TEXT UNIQUE,
          customerName TEXT, phone TEXT, model TEXT, issue TEXT, 
          accessories TEXT, address TEXT, imagePath TEXT, 
          deliveredImage TEXT, warranty TEXT, partsUsed TEXT,
          status INTEGER, price INTEGER, cost INTEGER,
          paymentMethod TEXT,
          createdAt INTEGER, startedAt INTEGER, finishedAt INTEGER, deliveredAt INTEGER,
          createdBy TEXT, repairedBy TEXT, deliveredBy TEXT,
          lastCaredAt INTEGER, isSynced INTEGER DEFAULT 0
        )
      ''');

        await db.execute('''
        CREATE TABLE products(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firestoreId TEXT UNIQUE,
          name TEXT, brand TEXT, imei TEXT, 
          cost INTEGER, price INTEGER, condition TEXT,
          status INTEGER DEFAULT 1, description TEXT, images TEXT,
          warranty TEXT, createdAt INTEGER, supplier TEXT,
          type TEXT DEFAULT 'PHONE', quantity INTEGER DEFAULT 1,
          color TEXT, isSynced INTEGER DEFAULT 0
        )
      ''');

        await db.execute('''
        CREATE TABLE repair_parts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          partName TEXT, compatibleModels TEXT, 
          cost INTEGER, price INTEGER, quantity INTEGER DEFAULT 0,
          updatedAt INTEGER
        )
      ''');

        await db.execute('''
        CREATE TABLE sales(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          firestoreId TEXT UNIQUE,
          customerName TEXT, phone TEXT, address TEXT,
          productNames TEXT, productImeis TEXT,
          totalPrice INTEGER, totalCost INTEGER, paymentMethod TEXT,
          sellerName TEXT, soldAt INTEGER, notes TEXT, gifts TEXT,
          isInstallment INTEGER DEFAULT 0, downPayment INTEGER DEFAULT 0,
           loanAmount INTEGER DEFAULT 0, installmentTerm TEXT, bankName TEXT,
           warranty TEXT,
           settlementPlannedAt INTEGER,
           settlementReceivedAt INTEGER,
           settlementAmount INTEGER DEFAULT 0,
           settlementFee INTEGER DEFAULT 0,
           settlementNote TEXT,
           settlementCode TEXT,
          isSynced INTEGER DEFAULT 0
        )
      ''');

        await db.execute('''
        CREATE TABLE suppliers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT UNIQUE, contactPerson TEXT, phone TEXT, address TEXT,
          items TEXT, importCount INTEGER DEFAULT 0, totalAmount INTEGER DEFAULT 0,
          createdAt INTEGER, shopId TEXT
        )
      ''');

        await db.execute('''
        CREATE TABLE expenses(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT, amount INTEGER, category TEXT, date INTEGER, note TEXT, paymentMethod TEXT
        )
      ''');

        await db.execute('''
        CREATE TABLE cash_closings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          dateKey TEXT UNIQUE,
          cashStart INTEGER DEFAULT 0,
          bankStart INTEGER DEFAULT 0,
          cashEnd INTEGER DEFAULT 0,
          bankEnd INTEGER DEFAULT 0,
          expectedCashDelta INTEGER DEFAULT 0,
          expectedBankDelta INTEGER DEFAULT 0,
          note TEXT,
          createdAt INTEGER
        )
      ''');

        await db.execute('''
        CREATE TABLE debts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          personName TEXT, phone TEXT, totalAmount INTEGER, 
          paidAmount INTEGER DEFAULT 0, type TEXT, status TEXT,
          createdAt INTEGER, note TEXT
        )
      ''');

        await db.execute('''
        CREATE TABLE customers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          phone TEXT UNIQUE,
          address TEXT,
          createdAt INTEGER
        )
      ''');

        await db.execute('''
        CREATE TABLE attendance(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT,
          email TEXT,
          name TEXT,
          dateKey TEXT,
          checkInAt INTEGER,
          checkOutAt INTEGER,
          overtimeOn INTEGER DEFAULT 0,
          photoIn TEXT,
          photoOut TEXT,
          note TEXT,
          status TEXT DEFAULT 'pending',
          approvedBy TEXT,
          approvedAt INTEGER,
          rejectReason TEXT,
          locked INTEGER DEFAULT 0,
          createdAt INTEGER
        )
      ''');

        await db.execute('''
        CREATE TABLE payroll_locks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          monthKey TEXT UNIQUE,
          locked INTEGER DEFAULT 1,
          lockedBy TEXT,
          note TEXT,
          lockedAt INTEGER
        )
      ''');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          // Thêm cột bảo hành cho bảng sales (đơn bán)
          await db.execute("ALTER TABLE sales ADD COLUMN warranty TEXT");
        }
        if (oldV < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS customers(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              phone TEXT UNIQUE,
              address TEXT,
              createdAt INTEGER
            )
          ''');
        }
        if (oldV < 4) {
          // Thêm cột shopId cho bảng suppliers để gắn dữ liệu theo cửa hàng
          try {
            await db.execute("ALTER TABLE suppliers ADD COLUMN shopId TEXT");
          } catch (_) {
            // bỏ qua nếu cột đã tồn tại
          }
        }
        if (oldV < 5) {
          try {
            await db.execute("ALTER TABLE repairs ADD COLUMN paymentMethod TEXT");
          } catch (_) {}
        }
        if (oldV < 6) {
          try {
            await db.execute("ALTER TABLE expenses ADD COLUMN paymentMethod TEXT");
          } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS cash_closings(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                dateKey TEXT UNIQUE,
                cashStart INTEGER DEFAULT 0,
                bankStart INTEGER DEFAULT 0,
                cashEnd INTEGER DEFAULT 0,
                bankEnd INTEGER DEFAULT 0,
                expectedCashDelta INTEGER DEFAULT 0,
                expectedBankDelta INTEGER DEFAULT 0,
                note TEXT,
                createdAt INTEGER
              )
             ''');
          } catch (_) {}
        }
        if (oldV < 7) {
          try { await db.execute("ALTER TABLE sales ADD COLUMN settlementPlannedAt INTEGER"); } catch (_) {}
          try { await db.execute("ALTER TABLE sales ADD COLUMN settlementReceivedAt INTEGER"); } catch (_) {}
          try { await db.execute("ALTER TABLE sales ADD COLUMN settlementAmount INTEGER DEFAULT 0"); } catch (_) {}
          try { await db.execute("ALTER TABLE sales ADD COLUMN settlementFee INTEGER DEFAULT 0"); } catch (_) {}
          try { await db.execute("ALTER TABLE sales ADD COLUMN settlementNote TEXT"); } catch (_) {}
          try { await db.execute("ALTER TABLE sales ADD COLUMN settlementCode TEXT"); } catch (_) {}
        }
        if (oldV < 8) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS attendance(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                userId TEXT,
                email TEXT,
                name TEXT,
                dateKey TEXT,
                checkInAt INTEGER,
                checkOutAt INTEGER,
                overtimeOn INTEGER DEFAULT 0,
                photoIn TEXT,
                photoOut TEXT,
                note TEXT,
                createdAt INTEGER
              )
             ''');
          } catch (_) {}
        }
        if (oldV < 9) {
          try { await db.execute("ALTER TABLE attendance ADD COLUMN status TEXT DEFAULT 'pending'"); } catch (_) {}
          try { await db.execute("ALTER TABLE attendance ADD COLUMN approvedBy TEXT"); } catch (_) {}
          try { await db.execute("ALTER TABLE attendance ADD COLUMN approvedAt INTEGER"); } catch (_) {}
          try { await db.execute("ALTER TABLE attendance ADD COLUMN rejectReason TEXT"); } catch (_) {}
          try { await db.execute("ALTER TABLE attendance ADD COLUMN locked INTEGER DEFAULT 0"); } catch (_) {}
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS payroll_locks(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                monthKey TEXT UNIQUE,
                locked INTEGER DEFAULT 1,
                lockedBy TEXT,
                note TEXT,
                lockedAt INTEGER
              )
            ''');
          } catch (_) {}
        }
      },
    );
  }

  // --- UPSERT LOGIC (CHỐNG TRÙNG) ---
  Future<void> upsertRepair(Repair r) async {
    final db = await database;
    final fId = r.firestoreId ?? "${r.createdAt}_${r.phone}";
    final List<Map<String, dynamic>> existing = await db.query('repairs', where: 'firestoreId = ?', whereArgs: [fId]);
    if (existing.isNotEmpty) {
      await db.update('repairs', r.toMap(), where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      Map<String, dynamic> data = r.toMap(); data.remove('id');
      await db.insert('repairs', data);
    }
  }

  Future<void> upsertProduct(Product p) async {
    final db = await database;
    final fId = p.firestoreId ?? "prod_${p.createdAt}";
    final List<Map<String, dynamic>> existing = await db.query('products', where: 'firestoreId = ?', whereArgs: [fId]);
    if (existing.isNotEmpty) {
      await db.update('products', p.toMap(), where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      Map<String, dynamic> data = p.toMap(); data.remove('id');
      await db.insert('products', data);
    }
  }

  Future<void> upsertSale(SaleOrder s) async {
    final db = await database;
    final fId = s.firestoreId ?? "sale_${s.soldAt}";
    final List<Map<String, dynamic>> existing = await db.query('sales', where: 'firestoreId = ?', whereArgs: [fId]);
    if (existing.isNotEmpty) {
      await db.update('sales', s.toMap(), where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      Map<String, dynamic> data = s.toMap(); data.remove('id');
      await db.insert('sales', data);
    }
  }

  // --- TRUY VẤN DỮ LIỆU ---
  Future<List<Repair>> getAllRepairs() async {
    final db = await database;
    final maps = await db.query('repairs', orderBy: 'createdAt DESC');
    return List.generate(maps.length, (i) => Repair.fromMap(maps[i]));
  }
  Future<List<Repair>> getRepairsPaged(int limit, int offset) async {
    final db = await database;
    final maps = await db.query('repairs', orderBy: 'createdAt DESC', limit: limit, offset: offset);
    return List.generate(maps.length, (i) => Repair.fromMap(maps[i]));
  }
  Future<List<Product>> getInStockProducts() async {
    final db = await database;
     final maps = await db.query('products', where: 'status = 1');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products');
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }
  Future<List<SaleOrder>> getAllSales() async {
    final db = await database;
    final maps = await db.query('sales', orderBy: 'soldAt DESC');
    return List.generate(maps.length, (i) => SaleOrder.fromMap(maps[i]));
  }

  Future<Repair?> getRepairByFirestoreId(String firestoreId) async {
    final db = await database;
    final maps = await db.query('repairs', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    if (maps.isEmpty) return null;
    return Repair.fromMap(maps.first);
  }

  Future<SaleOrder?> getSaleByFirestoreId(String firestoreId) async {
    final db = await database;
    final maps = await db.query('sales', where: 'firestoreId = ?', whereArgs: [firestoreId], limit: 1);
    if (maps.isEmpty) return null;
    return SaleOrder.fromMap(maps.first);
  }

  // --- CẬP NHẬT & XÓA ---
  Future<int> updateRepair(Repair r) async => (await database).update('repairs', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  Future<int> updateProduct(Product p) async => (await database).update('products', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  Future<int> updateSale(SaleOrder s) async => (await database).update('sales', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
  Future<int> deleteProduct(int id) async => (await database).delete('products', where: 'id = ?', whereArgs: [id]);
  Future<int> deleteRepair(int id) async => (await database).delete('repairs', where: 'id = ?', whereArgs: [id]);

  /// Xóa repair theo firestoreId (dùng khi Firestore đánh dấu deleted=true)
  Future<int> deleteRepairByFirestoreId(String firestoreId) async {
    final db = await database;
    return await db.delete('repairs', where: 'firestoreId = ?', whereArgs: [firestoreId]);
  }
  Future<int> deleteSale(int id) async => (await database).delete('sales', where: 'id = ?', whereArgs: [id]);
  
  Future<int> updateProductStatus(int id, int status) async {
    final db = await database;
    return await db.rawUpdate('UPDATE products SET status = ?, quantity = CASE WHEN ? = 0 THEN 0 ELSE quantity END WHERE id = ?', [status, status, id]);
  }
  
  Future<void> deductProductQuantity(int id, int amount) async {
    final db = await database;
    await db.rawUpdate('UPDATE products SET quantity = quantity - ? WHERE id = ?', [amount, id]);
    await db.rawUpdate('UPDATE products SET status = 0 WHERE id = ? AND quantity <= 0', [id]);
  }

  // --- FINANICAL & PARTS ---
  Future<int> insertPart(Map<String, dynamic> p) async => (await database).insert('repair_parts', p);
  Future<List<Map<String, dynamic>>> getAllParts() async => (await database).query('repair_parts', orderBy: 'partName ASC');
  Future<int> insertExpense(Map<String, dynamic> e) async => (await database).insert('expenses', e);
  Future<List<Map<String, dynamic>>> getAllExpenses() async => (await database).query('expenses', orderBy: 'date DESC');
  Future<int> deleteExpense(int id) async => (await database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  Future<int> insertDebt(Map<String, dynamic> d) async => (await database).insert('debts', d);
  Future<List<Map<String, dynamic>>> getAllDebts() async => (await database).query('debts', orderBy: 'status ASC, createdAt DESC');
  Future<int> deleteDebt(int id) async => (await database).delete('debts', where: 'id = ?', whereArgs: [id]);
  Future<int> updateDebtPaid(int id, int paid) async => (await database).rawUpdate('UPDATE debts SET paidAmount = paidAmount + ?, status = CASE WHEN (paidAmount + ?) >= totalAmount THEN "ĐÃ TRẢ" ELSE "NỢ" END WHERE id = ?', [paid, paid, id]);
  Future<int> insertSupplier(Map<String, dynamic> s) async => (await database).insert('suppliers', s, conflictAlgorithm: ConflictAlgorithm.ignore);
  Future<List<Map<String, dynamic>>> getSuppliers() async => (await (await database).query('suppliers', orderBy: 'name ASC'));
  Future<int> deleteSupplier(int id) async => (await database).delete('suppliers', where: 'id = ?', whereArgs: [id]);
  Future<void> incrementSupplierStats(String supplierName, int importAmount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE suppliers SET importCount = importCount + 1, totalAmount = totalAmount + ? WHERE name = ?',
      [importAmount, supplierName],
    );
  }

  // --- CUSTOMERS / CONTACTS ---
  Future<int> insertCustomer(Map<String, dynamic> c) async {
    final db = await database;
    return await db.insert('customers', c, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // --- CASH CLOSINGS ---
  Future<int> upsertClosing(Map<String, dynamic> closing) async {
    final db = await database;
    return await db.insert('cash_closings', closing, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getClosingByDate(String dateKey) async {
    final db = await database;
    final res = await db.query('cash_closings', where: 'dateKey = ?', whereArgs: [dateKey], limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<List<Map<String, dynamic>>> getClosings({int limit = 30}) async {
    final db = await database;
    return await db.query('cash_closings', orderBy: 'dateKey DESC', limit: limit);
  }

  Future<Map<String, dynamic>?> getCustomerByPhone(String phone) async {
    final db = await database;
    final res = await db.query('customers', where: 'phone = ?', whereArgs: [phone], limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<int> deleteCustomerByPhone(String phone) async {
    final db = await database;
    return await db.delete('customers', where: 'phone = ?', whereArgs: [phone]);
  }

  // --- ATTENDANCE ---
  Future<int> upsertAttendance(Map<String, dynamic> data) async {
    final db = await database;
    final dateKey = data['dateKey'] as String?;
    final userId = data['userId'] as String?;
    if (dateKey == null || userId == null) return 0;
    final existing = await db.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    if (existing.isNotEmpty) {
      final row = existing.first;
      if ((row['locked'] ?? 0) == 1) return 0; // không cho sửa khi đã khóa
      final updateData = Map<String, dynamic>.from(data);
      updateData['status'] = data['status'] ?? row['status'] ?? 'pending';
      updateData['locked'] = data['locked'] ?? row['locked'] ?? 0;
      updateData['approvedBy'] = data['approvedBy'] ?? row['approvedBy'];
      updateData['approvedAt'] = data['approvedAt'] ?? row['approvedAt'];
      updateData['rejectReason'] = data['rejectReason'] ?? row['rejectReason'];
      return await db.update('attendance', updateData, where: 'id = ?', whereArgs: [row['id']]);
    }

    final insertData = Map<String, dynamic>.from(data);
    insertData['status'] = data['status'] ?? 'pending';
    insertData['locked'] = data['locked'] ?? 0;
    return await db.insert('attendance', insertData);
  }

  Future<Map<String, dynamic>?> getAttendance(String dateKey, String userId) async {
    final db = await database;
    final res = await db.query('attendance', where: 'dateKey = ? AND userId = ?', whereArgs: [dateKey, userId], limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  Future<List<Map<String, dynamic>>> getAttendanceRange(DateTime from, DateTime to, {String? userId}) async {
    final db = await database;
    final fromKey = DateFormat('yyyy-MM-dd').format(from);
    final toKey = DateFormat('yyyy-MM-dd').format(to);
    final where = StringBuffer('dateKey BETWEEN ? AND ?');
    final args = <Object>[fromKey, toKey];
    if (userId != null) {
      where.write(' AND userId = ?');
      args.add(userId);
    }
    return await db.query('attendance', where: where.toString(), whereArgs: args, orderBy: 'dateKey DESC');
  }

  Future<List<Map<String, dynamic>>> getPendingAttendance({int daysBack = 14}) async {
    final db = await database;
    final fromKey = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(Duration(days: daysBack)));
    return await db.query(
      'attendance',
      where: 'dateKey >= ? AND (status IS NULL OR status != ?)',
      whereArgs: [fromKey, 'approved'],
      orderBy: 'dateKey DESC',
    );
  }

  Future<int> approveAttendance(int id, {required String approver}) async {
    final db = await database;
    return await db.update(
      'attendance',
      {
        'status': 'approved',
        'approvedBy': approver,
        'approvedAt': DateTime.now().millisecondsSinceEpoch,
        'rejectReason': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> rejectAttendance(int id, {required String approver, String? reason}) async {
    final db = await database;
    return await db.update(
      'attendance',
      {
        'status': 'rejected',
        'approvedBy': approver,
        'approvedAt': DateTime.now().millisecondsSinceEpoch,
        'rejectReason': reason,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> isPayrollMonthLocked(String monthKey) async {
    final db = await database;
    final res = await db.query('payroll_locks', where: 'monthKey = ? AND locked = 1', whereArgs: [monthKey], limit: 1);
    return res.isNotEmpty;
  }

  Future<void> setPayrollMonthLock(String monthKey, {required bool locked, required String lockedBy, String? note}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'payroll_locks',
      {
        'monthKey': monthKey,
        'locked': locked ? 1 : 0,
        'lockedBy': lockedBy,
        'note': note,
        'lockedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await db.rawUpdate('UPDATE attendance SET locked = ? WHERE dateKey LIKE ?', [locked ? 1 : 0, '$monthKey%']);
  }

  // --- ANALYTICS & UTILS ---
  Future<List<Map<String, dynamic>>> getUniqueCustomersAll() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT phone, customerName, address, 
      (SELECT COUNT(*) FROM repairs WHERE phone = t.phone) as repairCount,
      (SELECT COUNT(*) FROM sales WHERE phone = t.phone) as saleCount,
      ((SELECT IFNULL(SUM(price), 0) FROM repairs WHERE phone = t.phone AND status >= 3) + 
       (SELECT IFNULL(SUM(totalPrice), 0) FROM sales WHERE phone = t.phone)) as totalSpent
      FROM (
        SELECT phone, customerName, address FROM repairs
        UNION
        SELECT phone, customerName, address FROM sales
        UNION
        SELECT phone, name as customerName, address FROM customers
      ) as t
      GROUP BY phone ORDER BY customerName ASC
    ''');
  }
  Future<List<Map<String, dynamic>>> getCustomerSuggestions() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT DISTINCT customerName, phone, address FROM (
        SELECT customerName, phone, address FROM repairs
        UNION
        SELECT customerName, phone, address FROM sales
        UNION
        SELECT name as customerName, phone, address FROM customers
      )
      ORDER BY customerName ASC
    ''');
  }
  Future<void> cleanDuplicateData() async {
    final db = await database;
    await db.execute('DELETE FROM repairs WHERE id NOT IN (SELECT MAX(id) FROM repairs GROUP BY firestoreId)');
    await db.execute('DELETE FROM sales WHERE id NOT IN (SELECT MAX(id) FROM sales GROUP BY firestoreId)');
  }

  Future<void> clearAllData() async {
    final db = await database;
    final tables = [
      'repairs',
      'products',
      'sales',
      'suppliers',
      'expenses',
      'debts',
      'customers',
      'repair_parts',
    ];
    final batch = db.batch();
    for (final t in tables) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  // --- TƯƠNG THÍCH NGƯỢC ---
  Future<void> insertRepair(Repair r) async => upsertRepair(r);
  Future<void> insertProduct(Product p) async => upsertProduct(p);
  Future<void> insertSale(SaleOrder s) async => upsertSale(s);
  Future<void> upsertSupplier(Map<String, dynamic> s) async {
    final db = await database;
    final name = s['name'];
    if (name == null) return;
    final existing = await db.query('suppliers', where: 'name = ?', whereArgs: [name], limit: 1);
    if (existing.isNotEmpty) {
      await db.update('suppliers', s, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await db.insert('suppliers', s);
    }
  }

  // Xóa tất cả dữ liệu của một khách hàng (repairs và sales)
  Future<void> deleteCustomerData(String customerName, String phone) async {
    final db = await database;
    
    // Xóa repairs của customer
    await db.delete(
      'repairs', 
      where: 'customerName = ? AND phone = ?', 
      whereArgs: [customerName, phone]
    );
    
    // Xóa sales của customer  
    await db.delete(
      'sales',
      where: 'customerName = ? AND phone = ?',
      whereArgs: [customerName, phone]
    );
  }
}
