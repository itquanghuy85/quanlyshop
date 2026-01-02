<<<<<<< HEAD
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../utils/sku_generator.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FastInventoryInputController {
  final DBHelper db = DBHelper();

  // Cached data
  static List<Map<String, dynamic>>? _cachedSuppliers;
  static Map<String, dynamic>? _cachedSettings;

  // Get cached suppliers
  Future<List<Map<String, dynamic>>> getSuppliers() async {
    _cachedSuppliers ??= await db.getSuppliers();
    return _cachedSuppliers!;
  }

  // Get cached settings
  Future<Map<String, dynamic>> getSettings() async {
    _cachedSettings ??= await _loadSettings();
    return _cachedSettings!;
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    // TODO: Load from SharedPreferences if needed
    return {};
  }

  // Pre-validation
  String? validateProductData({
    required String sku,
    required String supplier,
    required String cost,
    required String retail,
  }) {
    if (sku.isEmpty) return "Vui lòng tạo mã hàng trước!";
    if (supplier.isEmpty) return "Vui lòng chọn Nhà cung cấp!";
    if (cost.isEmpty || int.tryParse(cost.replaceAll('.', '')) == null) {
      return "Giá nhập không hợp lệ!";
    }
    if (retail.isEmpty || int.tryParse(retail.replaceAll('.', '')) == null) {
      return "Giá bán không hợp lệ!";
    }
    return null; // Valid
  }

  // Generate SKU
  Future<String> generateSKU({
    required String group,
    String? model,
    String? info,
  }) async {
    return await SKUGenerator.generateSKU(
      nhom: group,
      model: model,
      thongtin: info,
      dbHelper: db,
      firestoreService: null,
    );
  }

  // Batch save with transaction
  Future<void> saveProductBatch(Map<String, dynamic> productData) async {
    final database = await db.database;

    await database.transaction((txn) async {
      // 1. Create and upsert product
      final product = _createProductFromData(productData);
      await _upsertInTxn(txn, 'products', product.toMap(), product.firestoreId!);

      // 2. Handle finance operations
      await _handleFinanceInTxn(txn, productData, product);

      // 3. Handle supplier operations
      await _handleSupplierOperationsInTxn(txn, productData, product);
    });

    // 4. Log action (outside transaction)
    final product = _createProductFromData(productData);
    await _logAction(productData, product);

    // 5. Sync to Firestore (outside transaction as it's network)
    await FirestoreService.addProduct(product);
  }

  // Save multiple products in parallel
  Future<void> saveBatchProducts(List<Map<String, dynamic>> batchItems) async {
    final futures = batchItems.map((item) => saveProductBatch(item));
    await Future.wait(futures);
  }

  Product _createProductFromData(Map<String, dynamic> data) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final imei = data['imei'] ?? '';
    final fId = "prod_${ts}_${imei.isNotEmpty ? imei : ts}";

    return Product(
      firestoreId: fId,
      name: data['name'],
      model: data['model'],
      imei: imei,
      cost: data['cost'],
      price: data['price'],
      capacity: data['capacity'],
      quantity: data['quantity'] ?? 1,
      type: data['type'],
      createdAt: ts,
      supplier: data['supplier'],
      status: 1,
    );
  }

  Future<void> _upsertInTxn(dynamic txn, String table, Map<String, dynamic> map, String firestoreId) async {
    final List<Map<String, dynamic>> existing = await txn.query(
      table,
      where: 'firestoreId = ?',
      whereArgs: [firestoreId],
      limit: 1
    );

    Map<String, dynamic> data = Map<String, dynamic>.from(map);
    data.remove('id');

    if (existing.isNotEmpty) {
      await txn.update(table, data, where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await txn.insert(table, data);
    }
  }

  Future<void> _handleFinanceInTxn(dynamic txn, Map<String, dynamic> data, Product product) async {
    if (data['paymentMethod'] != "CÔNG NỢ") {
      // Insert expense
      final expense = {
        'firestoreId': "exp_${DateTime.now().millisecondsSinceEpoch}",
        'title': "NHẬP HÀNG: ${product.name}",
        'amount': product.cost * product.quantity,
        'category': "NHẬP HÀNG",
        'date': product.createdAt,
        'paymentMethod': data['paymentMethod'],
        'note': "Nhập từ ${data['supplier']}",
        'isSynced': 0,
      };
      await txn.insert('expenses', expense);
    } else {
      // Insert debt
      final debt = {
        'firestoreId': "debt_${product.createdAt}",
        'personName': data['supplier'],
        'totalAmount': product.cost * product.quantity,
        'paidAmount': 0,
        'type': "SHOP_OWES",
        'status': "unpaid",
        'createdAt': product.createdAt,
        'note': "Nợ tiền máy ${product.name}",
        'isSynced': 0,
      };
      await txn.insert('debts', debt);
    }
  }

  Future<void> _logAction(Map<String, dynamic> data, Product product) async {
    // Log action outside transaction since it might need special handling
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";

    await db.logAction(
      userId: user?.uid ?? "0",
      userName: userName,
      action: "NHẬP KHO",
      type: "PRODUCT",
      targetId: product.imei,
      desc: "Đã nhập máy ${product.name}",
    );
  }



  Future<void> _handleSupplierOperationsInTxn(dynamic txn, Map<String, dynamic> data, Product product) async {
    final suppliers = await getSuppliers();
    final supplierData = suppliers.firstWhere(
      (s) => s['name'] == data['supplier'],
      orElse: () => {},
    );
    final shopId = await UserService.getCurrentShopId();

    if (supplierData.isNotEmpty) {
      final supplierId = supplierData['id'];

      // Insert import history
      final importHistory = {
        'supplierId': supplierId,
        'supplierName': data['supplier'],
        'productName': product.name,
        'productBrand': product.brand ?? '',
        'productModel': product.model,
        'imei': product.imei,
        'quantity': product.quantity,
        'costPrice': product.cost,
        'totalAmount': product.cost * product.quantity,
        'paymentMethod': data['paymentMethod'],
        'importDate': product.createdAt,
        'importedBy': data['importedBy'] ?? "NV",
        'notes': 'Nhập từ Fast Inventory Input',
        'shopId': shopId,
        'isSynced': 0,
      };
      await txn.insert('supplier_import_history', importHistory);

      // Update supplier product price
      await txn.rawUpdate(
        'UPDATE supplier_product_prices SET isActive = 0 WHERE supplierId = ? AND productName = ? AND productBrand = ? AND (productModel = ? OR productModel IS NULL)',
        [supplierId, product.name, product.brand ?? '', product.model]
      );

      final supplierPrice = {
        'supplierId': supplierId,
        'productName': product.name,
        'productBrand': product.brand ?? '',
        'productModel': product.model,
        'costPrice': product.cost,
        'lastUpdated': product.createdAt,
        'createdAt': product.createdAt,
        'isActive': 1,
        'shopId': shopId,
      };
      await txn.insert('supplier_product_prices', supplierPrice);

      // Update supplier stats
      await _updateSupplierStatsInTxn(txn, supplierId);
    }
  }

  Future<void> _updateSupplierStatsInTxn(dynamic txn, int supplierId) async {
    final stats = await txn.rawQuery('''
      SELECT
        COUNT(*) as totalImports,
        SUM(totalAmount) as totalAmount
      FROM supplier_import_history
      WHERE supplierId = ?
    ''', [supplierId]);

    if (stats.isNotEmpty) {
      final totalImports = stats.first['totalImports'] ?? 0;
      final totalAmount = stats.first['totalAmount'] ?? 0;

      await txn.update(
        'suppliers',
        {
          'importCount': totalImports,
          'totalAmount': totalAmount,
        },
        where: 'id = ?',
        whereArgs: [supplierId],
=======
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/sku_generator.dart';

/// Controller xử lý toàn bộ logic nhập kho nhanh
class FastInventoryInputController {
  final DBHelper db;
  final FirestoreService firestoreService;

  FastInventoryInputController({
    required this.db,
    required this.firestoreService,
  });

  // Form data
  final imeiController = TextEditingController();
  final costController = TextEditingController();
  final kpkController = TextEditingController();
  final retailController = TextEditingController();
  final modelController = TextEditingController();
  final infoController = TextEditingController();
  final skuController = TextEditingController();
  final qtyController = TextEditingController(text: "1");

  String selectedGroup = 'IP';
  String selectedType = 'PHONE';
  String selectedSupplier = 'KHO TỔNG';
  String selectedPayment = 'TIỀN MẶT';

  bool isSaving = false;
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> batchItems = [];

  // Validation errors
  String? imeiError;
  String? costError;
  String? modelError;
  String? skuError;

  /// Khởi tạo controller
  Future<void> initialize() async {
    await _loadSuppliers();
  }

  /// Load danh sách nhà cung cấp
  Future<void> _loadSuppliers() async {
    try {
      suppliers = await db.getSuppliers();
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi tải danh sách nhà cung cấp: $e',
        color: Colors.red,
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      );
    }
  }

<<<<<<< HEAD
  // Load recent products
  Future<List<Product>> loadRecentProducts() async {
    final products = await db.getInStockProducts();
    products.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    return products.take(10).toList();
  }

  // Clear cache when needed
  static void clearCache() {
    _cachedSuppliers = null;
    _cachedSettings = null;
=======
  /// Validate form data
  bool validateForm() {
    bool isValid = true;

    // Reset errors
    imeiError = null;
    costError = null;
    modelError = null;
    skuError = null;

    // Validate SKU
    if (skuController.text.trim().isEmpty) {
      skuError = 'Vui lòng tạo mã hàng';
      isValid = false;
    }

    // Validate model
    if (modelController.text.trim().isEmpty) {
      modelError = 'Vui lòng nhập model';
      isValid = false;
    }

    // Validate cost
    final cost = _parsePrice(costController.text);
    if (cost <= 0) {
      costError = 'Giá vốn phải lớn hơn 0';
      isValid = false;
    }

    // Validate IMEI (optional but if provided, check format)
    final imei = imeiController.text.trim();
    if (imei.isNotEmpty && imei.length < 10) {
      imeiError = 'IMEI phải có ít nhất 10 ký tự';
      isValid = false;
    }

    return isValid;
  }

  /// Tạo SKU tự động
  Future<void> generateSKU() async {
    if (modelController.text.trim().isEmpty) {
      NotificationService.showSnackBar(
        'Vui lòng nhập model trước',
        color: Colors.orange,
      );
      return;
    }

    try {
      final sku = await SKUGenerator.generateSKU(
        nhom: selectedGroup,
        model: modelController.text.trim(),
        thongtin: infoController.text.trim(),
        dbHelper: db,
      );
      skuController.text = sku;
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi tạo mã hàng: $e',
        color: Colors.red,
      );
    }
  }

  /// Thêm item vào batch
  Future<bool> addToBatch() async {
    if (!validateForm()) {
      NotificationService.showSnackBar(
        'Vui lòng kiểm tra lại thông tin',
        color: Colors.orange,
      );
      return false;
    }

    final item = _createItemData();
    batchItems.add(item);
    imeiController.clear(); // Clear IMEI for next scan
    HapticFeedback.lightImpact();

    NotificationService.showSnackBar(
      'Đã thêm ${item['name']} vào lô',
      color: Colors.blue,
    );

    return true;
  }

  /// Lưu đơn lẻ
  Future<bool> saveSingle() async {
    if (!validateForm()) {
      NotificationService.showSnackBar(
        'Vui lòng kiểm tra lại thông tin',
        color: Colors.orange,
      );
      return false;
    }

    isSaving = true;
    try {
      final item = _createItemData();
      await _saveItems([item]);

      NotificationService.showSnackBar(
        'Đã nhập kho thành công',
        color: Colors.green,
      );

      return true;
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi nhập kho: $e',
        color: Colors.red,
      );
      return false;
    } finally {
      isSaving = false;
    }
  }

  /// Lưu batch
  Future<bool> saveBatch() async {
    if (batchItems.isEmpty) {
      NotificationService.showSnackBar(
        'Không có hàng để nhập',
        color: Colors.orange,
      );
      return false;
    }

    isSaving = true;
    try {
      await _saveItems(batchItems);
      final count = batchItems.length;
      batchItems.clear();

      NotificationService.showSnackBar(
        'Đã nhập kho thành công $count mặt hàng',
        color: Colors.green,
      );

      return true;
    } catch (e) {
      NotificationService.showSnackBar(
        'Lỗi nhập kho: $e',
        color: Colors.red,
      );
      return false;
    } finally {
      isSaving = false;
    }
  }

  /// Tạo item data từ form
  Map<String, dynamic> _createItemData() {
    return {
      'name': skuController.text.toUpperCase(),
      'imei': imeiController.text.trim(),
      'cost': _parsePrice(costController.text),
      'kpkPrice': _parsePrice(kpkController.text),
      'price': _parsePrice(retailController.text),
      'quantity': int.tryParse(qtyController.text) ?? 1,
      'type': selectedType,
      'supplier': selectedSupplier,
      'paymentMethod': selectedPayment,
      'capacity': infoController.text.toUpperCase(),
    };
  }

  /// Lưu items vào database
  Future<void> _saveItems(List<Map<String, dynamic>> items) async {
    for (var data in items) {
      final product = Product(
        firestoreId: "prod_${DateTime.now().millisecondsSinceEpoch}_${data['imei']}",
        name: data['name'],
        imei: data['imei'],
        cost: data['cost'],
        kpkPrice: data['kpkPrice'],
        price: data['price'],
        quantity: data['quantity'],
        type: data['type'],
        supplier: data['supplier'],
        createdAt: DateTime.now().millisecondsSinceEpoch,
        status: 1,
      );

      // Save to local DB
      await db.upsertProduct(product);

      // Save to Firestore
      await FirestoreService.addProduct(product);

      // Handle payment
      if (data['paymentMethod'] == "CÔNG NỢ") {
        await db.insertDebt({
          'personName': data['supplier'],
          'totalAmount': data['cost'] * data['quantity'],
          'paidAmount': 0,
          'type': 'SHOP_OWES',
          'status': 'unpaid',
          'createdAt': product.createdAt,
          'note': "Nhập hàng: ${product.name}",
        });
      } else {
        await db.insertExpense({
          'title': "NHẬP HÀNG: ${product.name}",
          'amount': data['cost'] * data['quantity'],
          'category': 'NHẬP HÀNG',
          'date': product.createdAt,
          'paymentMethod': data['paymentMethod'],
        });
      }
    }
  }

  /// Reset form về trạng thái ban đầu
  void resetForm() {
    imeiController.clear();
    costController.clear();
    kpkController.clear();
    retailController.clear();
    modelController.clear();
    infoController.clear();
    skuController.clear();
    qtyController.text = "1";

    selectedGroup = 'IP';
    selectedType = 'PHONE';
    selectedSupplier = 'KHO TỔNG';
    selectedPayment = 'TIỀN MẶT';

    batchItems.clear();

    imeiError = null;
    costError = null;
    modelError = null;
    skuError = null;
  }

  /// Cập nhật nhóm và loại sản phẩm
  void updateGroup(String group) {
    selectedGroup = group;
    selectedType = (group == "PK" || group == "PIN") ? "ACCESSORY" : "PHONE";
  }

  /// Parse price từ string
  int _parsePrice(String text) {
    final cleaned = text.replaceAll('.', '').replaceAll(',', '');
    final value = int.tryParse(cleaned) ?? 0;
    // Nếu giá < 100000 thì nhân 1000 (đơn vị nghìn)
    return (value > 0 && value < 100000) ? value * 1000 : value;
  }

  /// Dispose controllers
  void dispose() {
    imeiController.dispose();
    costController.dispose();
    kpkController.dispose();
    retailController.dispose();
    modelController.dispose();
    infoController.dispose();
    skuController.dispose();
    qtyController.dispose();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }
}