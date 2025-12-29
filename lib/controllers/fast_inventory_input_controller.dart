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
      );
    }
  }

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
  }
}