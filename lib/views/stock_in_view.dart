import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../utils/money_utils.dart';
import '../widgets/validated_text_field.dart';

class StockInView extends StatefulWidget {
  final Map<String, dynamic>? prefilledData;

  const StockInView({super.key, this.prefilledData});

  @override
  State<StockInView> createState() => _StockInViewState();
}

class _StockInViewState extends State<StockInView> {
  final db = DBHelper();
  bool _saving = false;

  // Controllers
  final typeCtrl = TextEditingController(text: 'PHONE');
  final brandCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final capacityCtrl = TextEditingController();
  final colorCtrl = TextEditingController();
  final conditionCtrl = TextEditingController(text: 'Mới');
  final imeiCtrl = TextEditingController();
  final quantityCtrl = TextEditingController(text: '1');
  final costCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final supplierCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now();

  // Payment method
  String selectedPaymentMethod = 'Công nợ';

  // Focus nodes
  final brandF = FocusNode();
  final modelF = FocusNode();
  final capacityF = FocusNode();
  final colorF = FocusNode();
  final imeiF = FocusNode();
  final quantityF = FocusNode();
  final costF = FocusNode();
  final priceF = FocusNode();
  final notesF = FocusNode();

  // Track field changes for visual feedback
  bool _brandChanged = false;
  bool _modelChanged = false;
  bool _capacityChanged = false;
  bool _colorChanged = false;
  bool _conditionChanged = false;
  bool _imeiChanged = false;
  bool _quantityChanged = false;
  bool _costChanged = false;
  bool _priceChanged = false;
  bool _supplierChanged = false;
  bool _notesChanged = false;

  // Dropdown options
  final List<String> types = ['PHONE', 'ACCESSORY', 'LINH KIỆN'];
  final List<String> conditions = ['Mới', '99', '98', 'Khác'];
  List<Map<String, dynamic>> suppliers = [];

  // Computed property to check if current type is accessory or linh kiện
  bool get _isAccessoryOrLinhKien => typeCtrl.text == 'ACCESSORY' || typeCtrl.text == 'LINH KIỆN';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    imeiCtrl.addListener(_onImeiChanged);

    // Add listeners to track field changes
    brandCtrl.addListener(() => _onFieldChanged(brandCtrl, (changed) => _brandChanged = changed));
    modelCtrl.addListener(() => _onFieldChanged(modelCtrl, (changed) => _modelChanged = changed));
    capacityCtrl.addListener(() => _onFieldChanged(capacityCtrl, (changed) => _capacityChanged = changed));
    colorCtrl.addListener(() => _onFieldChanged(colorCtrl, (changed) => _colorChanged = changed));
    conditionCtrl.addListener(() => _onFieldChanged(conditionCtrl, (changed) => _conditionChanged = changed));
    imeiCtrl.addListener(() => _onFieldChanged(imeiCtrl, (changed) => _imeiChanged = changed));
    quantityCtrl.addListener(() => _onFieldChanged(quantityCtrl, (changed) => _quantityChanged = changed));
    costCtrl.addListener(() => _onFieldChanged(costCtrl, (changed) => _costChanged = changed));
    priceCtrl.addListener(() => _onFieldChanged(priceCtrl, (changed) => _priceChanged = changed));
    supplierCtrl.addListener(() => _onFieldChanged(supplierCtrl, (changed) => _supplierChanged = changed));
    notesCtrl.addListener(() => _onFieldChanged(notesCtrl, (changed) => _notesChanged = changed));

    // Fill data from prefilledData if available
    if (widget.prefilledData != null) {
      _fillPrefilledData();
    }
  }

  void _fillPrefilledData() {
    final data = widget.prefilledData!;
    setState(() {
      typeCtrl.text = data['type'] ?? 'PHONE';
      brandCtrl.text = data['brand'] ?? '';
      modelCtrl.text = data['model'] ?? '';
      capacityCtrl.text = data['capacity'] ?? '';
      colorCtrl.text = data['color'] ?? '';
      conditionCtrl.text = data['condition'] ?? 'Mới';
      imeiCtrl.text = data['imei'] ?? '';
      quantityCtrl.text = data['quantity']?.toString() ?? '1';
      costCtrl.text = data['cost'] != null ? (data['cost'] ~/ 1000).toString() : '';
      priceCtrl.text = data['price'] != null ? (data['price'] ~/ 1000).toString() : '';
      supplierCtrl.text = data['supplier'] ?? '';
      selectedPaymentMethod = data['paymentMethod'] ?? 'Công nợ';
      notesCtrl.text = data['notes'] ?? '';
      // Set brand from SKU if available and brand is empty
      if (brandCtrl.text.isEmpty && data['name'] != null && data['name'].toString().isNotEmpty) {
        brandCtrl.text = _extractBrandFromSKU(data['name']);
      }

      // Set changed flags for prefilled data
      _brandChanged = brandCtrl.text.isNotEmpty;
      _modelChanged = modelCtrl.text.isNotEmpty;
      _capacityChanged = capacityCtrl.text.isNotEmpty;
      _colorChanged = colorCtrl.text.isNotEmpty;
      _conditionChanged = conditionCtrl.text != 'Mới';
      _imeiChanged = imeiCtrl.text.isNotEmpty;
      _quantityChanged = quantityCtrl.text != '1';
      _costChanged = costCtrl.text.isNotEmpty;
      _priceChanged = priceCtrl.text.isNotEmpty;
      _supplierChanged = supplierCtrl.text.isNotEmpty;
      _notesChanged = notesCtrl.text.isNotEmpty;
    });
  }

  String _extractBrandFromSKU(String sku) {
    // Extract brand from SKU (e.g., "IP15PM" -> "iPhone")
    if (sku.startsWith('IP')) return 'iPhone';
    if (sku.startsWith('SS')) return 'Samsung';
    if (sku.startsWith('PK')) return 'Phụ kiện';
    return '';
  }

  int _parseMoneyWithK(String text) {
    final value = MoneyUtils.parseMoney(text);
    return (value > 0 && value < 100000) ? value * 1000 : value;
  }

  void _onFieldChanged(TextEditingController controller, Function(bool) setChanged) {
    final hasText = controller.text.trim().isNotEmpty;
    if (hasText != setChanged) { // Only update if state actually changed
      setState(() => setChanged(hasText));
    }
  }

  @override
  void dispose() {
    imeiCtrl.removeListener(_onImeiChanged);
    // Remove field change listeners
    brandCtrl.removeListener(() => _onFieldChanged(brandCtrl, (changed) => _brandChanged = changed));
    modelCtrl.removeListener(() => _onFieldChanged(modelCtrl, (changed) => _modelChanged = changed));
    capacityCtrl.removeListener(() => _onFieldChanged(capacityCtrl, (changed) => _capacityChanged = changed));
    colorCtrl.removeListener(() => _onFieldChanged(colorCtrl, (changed) => _colorChanged = changed));
    conditionCtrl.removeListener(() => _onFieldChanged(conditionCtrl, (changed) => _conditionChanged = changed));
    imeiCtrl.removeListener(() => _onFieldChanged(imeiCtrl, (changed) => _imeiChanged = changed));
    quantityCtrl.removeListener(() => _onFieldChanged(quantityCtrl, (changed) => _quantityChanged = changed));
    costCtrl.removeListener(() => _onFieldChanged(costCtrl, (changed) => _costChanged = changed));
    priceCtrl.removeListener(() => _onFieldChanged(priceCtrl, (changed) => _priceChanged = changed));
    supplierCtrl.removeListener(() => _onFieldChanged(supplierCtrl, (changed) => _supplierChanged = changed));
    notesCtrl.removeListener(() => _onFieldChanged(notesCtrl, (changed) => _notesChanged = changed));
    // Dispose controllers and focus nodes
    typeCtrl.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    capacityCtrl.dispose();
    colorCtrl.dispose();
    conditionCtrl.dispose();
    imeiCtrl.dispose();
    quantityCtrl.dispose();
    costCtrl.dispose();
    priceCtrl.dispose();
    supplierCtrl.dispose();
    notesCtrl.dispose();
    brandF.dispose();
    modelF.dispose();
    capacityF.dispose();
    colorF.dispose();
    imeiF.dispose();
    quantityF.dispose();
    costF.dispose();
    priceF.dispose();
    notesF.dispose();
    super.dispose();
  }

  void _onImeiChanged() {
    if (imeiCtrl.text.isNotEmpty) {
      quantityCtrl.text = '1';
    }
  }

  Future<void> _loadSuppliers() async {
    final sups = await db.getSuppliers();
    setState(() {
      suppliers = sups;
      if (suppliers.isNotEmpty && suppliers.first['name'] != null) {
        supplierCtrl.text = suppliers.first['name'] as String;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<bool> _validateForm() async {
    if (brandCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập loại!", color: Colors.red);
      return false;
    }

    // Chỉ validate model và capacity cho phone
    if (!_isAccessoryOrLinhKien) {
      if (modelCtrl.text.isEmpty) {
        NotificationService.showSnackBar("Vui lòng nhập model!", color: Colors.red);
        return false;
      }
      if (capacityCtrl.text.isEmpty) {
        NotificationService.showSnackBar("Vui lòng nhập dung lượng!", color: Colors.red);
        return false;
      }
    }

    if (colorCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập màu sắc!", color: Colors.red);
      return false;
    }

    // Chỉ validate IMEI cho phone
    if (!_isAccessoryOrLinhKien && imeiCtrl.text.isNotEmpty) {
      // Check for duplicate IMEI
      final dbInstance = await db.database;
      final result = await dbInstance.query('products', where: 'imei = ?', whereArgs: [imeiCtrl.text.trim()]);
      if (result.isNotEmpty) {
        NotificationService.showSnackBar("IMEI đã tồn tại trong kho!", color: Colors.red);
        return false;
      }
    }

    final quantity = int.tryParse(quantityCtrl.text);
    if (quantity == null || quantity <= 0) {
      NotificationService.showSnackBar("Số lượng phải là số dương!", color: Colors.red);
      return false;
    }
    final cost = _parseMoneyWithK(costCtrl.text);
    if (cost <= 0) {
      NotificationService.showSnackBar("Giá nhập phải lớn hơn 0!", color: Colors.red);
      return false;
    }
    final price = _parseMoneyWithK(priceCtrl.text);
    if (price < 0) {
      NotificationService.showSnackBar("Giá bán không được âm!", color: Colors.red);
      return false;
    }

    if (supplierCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng chọn nhà cung cấp!", color: Colors.red);
      return false;
    }
    return true;
  }

  Future<void> _saveProduct() async {
    if (!(await _validateForm())) return;

    setState(() => _saving = true);

    try {
      final ts = selectedDate.millisecondsSinceEpoch;
      final imei = imeiCtrl.text.trim();
      final fId = "prod_${ts}_${imei.isNotEmpty ? imei : ts}";

      final quantity = int.tryParse(quantityCtrl.text) ?? 0;

      final product = Product(
        firestoreId: fId,
        name: _isAccessoryOrLinhKien
            ? '${brandCtrl.text} ${colorCtrl.text}'.toUpperCase()
            : '${brandCtrl.text} ${modelCtrl.text}'.toUpperCase(),
        brand: brandCtrl.text.toUpperCase(),        model: modelCtrl.text.trim().isNotEmpty ? modelCtrl.text.trim() : null,        imei: (!_isAccessoryOrLinhKien && imei.isNotEmpty) ? imei : null,
        cost: _parseMoneyWithK(costCtrl.text),
        price: _parseMoneyWithK(priceCtrl.text),
        condition: conditionCtrl.text,
        status: 1,
        description: notesCtrl.text.trim(),
        createdAt: ts,
        supplier: supplierCtrl.text,
        type: typeCtrl.text,
        quantity: quantity,
        color: colorCtrl.text.trim().toUpperCase(),
        capacity: !_isAccessoryOrLinhKien ? capacityCtrl.text.trim().toUpperCase() : null,
        paymentMethod: selectedPaymentMethod,
      );

      await db.upsertProduct(product);
      await FirestoreService.addProduct(product);

      // Lưu lịch sử nhập hàng từ nhà cung cấp
      if (supplierCtrl.text.isNotEmpty) {
        final suppliers = await db.getSuppliers();
        final supplierData = suppliers.firstWhere((s) => s['name'] == supplierCtrl.text, orElse: () => {});
        final supplierId = supplierData['id'];
        if (supplierId != null) {
          // Log action
          final user = FirebaseAuth.instance.currentUser;
          final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";

          final importHistory = {
            'firestoreId': "import_${ts}_${product.imei ?? ts}",
            'supplierId': supplierId,
            'supplierName': supplierCtrl.text,
            'productName': product.name,
            'productBrand': product.brand ?? '',
            'productModel': product.model,
            'imei': product.imei,
            'quantity': quantity,
            'costPrice': product.cost,
            'totalAmount': product.cost * quantity,
            'paymentMethod': selectedPaymentMethod,
            'importDate': ts,
            'importedBy': userName,
            'notes': notesCtrl.text.trim(),
            'isSynced': 0,
          };
          await db.insertSupplierImportHistory(importHistory);

          // Cập nhật giá nhà cung cấp
          await db.deactivateSupplierProductPrice(supplierId, product.name, product.brand ?? '', product.model);
          final supplierPrice = {
            'supplierId': supplierId,
            'productName': product.name,
            'productBrand': product.brand ?? '',
            'productModel': product.model,
            'costPrice': product.cost,
            'lastUpdated': ts,
            'createdAt': ts,
            'isActive': 1,
          };
          await db.insertSupplierProductPrice(supplierPrice);

          // Cập nhật thống kê nhà cung cấp
          await db.updateSupplierStats(supplierId);
        }
      }

      // Log action
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";
      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: "NHẬP KHO",
        type: "PRODUCT",
        targetId: product.imei ?? product.firestoreId,
        desc: "Đã nhập ${product.name}",
      );

      NotificationService.showSnackBar("Nhập kho thành công!", color: Colors.green);

      // Send chat notification
      await FirestoreService.sendChat(
        message: "📦 Đã nhập kho: ${product.name} (${product.imei ?? 'No IMEI'}) - SL: ${quantityCtrl.text} - NCC: ${supplierCtrl.text.isNotEmpty ? supplierCtrl.text : 'N/A'}",
        senderId: user?.uid ?? "system",
        senderName: userName,
        linkedType: "PRODUCT",
        linkedKey: product.imei ?? product.firestoreId,
        linkedSummary: product.name,
      );

      Navigator.of(context).pop();
    } catch (e) {
      NotificationService.showSnackBar("Lỗi khi nhập kho: $e", color: Colors.red);
    } finally {
      setState(() => _saving = false);
    }
  }

  void _resetForm() {
    // Không reset type để giữ loại sản phẩm hiện tại
    brandCtrl.clear();
    if (!_isAccessoryOrLinhKien) {
      modelCtrl.clear();
      capacityCtrl.clear();
    }
    colorCtrl.clear();
    if (!_isAccessoryOrLinhKien) {
      imeiCtrl.clear();
    }
    quantityCtrl.text = '1';
    costCtrl.clear();
    priceCtrl.clear();
    notesCtrl.clear();
    selectedDate = DateTime.now();

    // Reset changed flags
    _brandChanged = false;
    _modelChanged = false;
    _capacityChanged = false;
    _colorChanged = false;
    _conditionChanged = false;
    _imeiChanged = false;
    _quantityChanged = false;
    _costChanged = false;
    _priceChanged = false;
    _supplierChanged = false;
    _notesChanged = false;

    setState(() {});
  }

  Widget _buildDropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    FocusNode? nextFocus,
    IconData? icon,
    bool hasChanged = false,
  }) {
    return DropdownButtonFormField<String>(
      value: controller.text.isNotEmpty ? controller.text : null,
      style: TextStyle(
        fontSize: 12,
        color: hasChanged ? const Color(0xFF1976D2) : Colors.black87,
        fontWeight: hasChanged ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: hasChanged ? const Color(0xFF1976D2) : Colors.black87,
          fontWeight: hasChanged ? FontWeight.bold : FontWeight.normal,
        ),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: hasChanged ? const Color(0xFF1976D2) : Colors.black54) : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: false, // Override theme to not fill background
        fillColor: hasChanged ? const Color(0xFFE3F2FD).withAlpha(50) : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: hasChanged ? const Color(0xFF1976D2) : Colors.grey.shade400,
            width: hasChanged ? 1.5 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: hasChanged ? const Color(0xFF1976D2) : Colors.blue,
            width: hasChanged ? 2.0 : 1.0,
          ),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      )).toList(),
      onChanged: (value) {
        setState(() {
          controller.text = value!;
        });
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
    bool required = false,
    String? suffix,
    List<TextInputFormatter>? inputFormatters,
    bool hasChanged = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 12,
        color: hasChanged ? const Color(0xFF1976D2) : Colors.black87, // Blue color when changed
        fontWeight: hasChanged ? FontWeight.bold : FontWeight.normal,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: hasChanged ? const Color(0xFF1976D2) : Colors.black87,
          fontWeight: hasChanged ? FontWeight.bold : FontWeight.normal,
        ),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: hasChanged ? const Color(0xFF1976D2) : Colors.black54) : null,
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: false, // Override theme to not fill background
        // Add subtle background color when changed
        fillColor: hasChanged ? const Color(0xFFE3F2FD).withAlpha(50) : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: hasChanged ? const Color(0xFF1976D2) : Colors.grey.shade400,
            width: hasChanged ? 1.5 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: hasChanged ? const Color(0xFF1976D2) : Colors.blue,
            width: hasChanged ? 2.0 : 1.0,
          ),
        ),
      ),
      onChanged: (value) {
        controller.value = controller.value.copyWith(
          text: value.toUpperCase(),
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
      onFieldSubmitted: (_) {
        if (nextFocus != null) {
          FocusScope.of(context).requestFocus(nextFocus);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập Kho'),
      ),
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Loại hàng
            _buildDropdownField(
              label: 'Loại hàng *',
              controller: typeCtrl,
              items: types,
              icon: Icons.category,
            ),
            const SizedBox(height: 8),

            // Loại (thay cho Hãng, nhập tay được)
            _buildTextField(
              controller: brandCtrl,
              label: 'Loại *',
              focusNode: brandF,
              nextFocus: _isAccessoryOrLinhKien ? colorF : modelF,
              icon: Icons.business,
              hasChanged: _brandChanged,
            ),
            const SizedBox(height: 8),

            // Model (ẩn với accessory/linh kiện)
            if (!_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: modelCtrl,
                label: 'Model *',
                focusNode: modelF,
                nextFocus: capacityF,
                icon: Icons.smartphone,
                hasChanged: _modelChanged,
              ),
              const SizedBox(height: 8),
            ],

            // Dung lượng (ẩn với accessory/linh kiện)
            if (!_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: capacityCtrl,
                label: 'Dung lượng *',
                focusNode: capacityF,
                nextFocus: colorF,
                icon: Icons.memory,
                hasChanged: _capacityChanged,
              ),
              const SizedBox(height: 8),
            ],

            // Thông tin (thay cho Màu sắc)
            _buildTextField(
              controller: colorCtrl,
              label: 'Màu (Thông tin) *',
              focusNode: colorF,
              nextFocus: _isAccessoryOrLinhKien ? quantityF : imeiF,
              icon: Icons.info,
              hasChanged: _colorChanged,
            ),
            const SizedBox(height: 8),

            // Tình trạng máy
            _buildDropdownField(
              label: 'Tình trạng',
              controller: conditionCtrl,
              items: conditions,
              icon: Icons.check_circle,
              hasChanged: _conditionChanged,
            ),
            const SizedBox(height: 8),

            // IMEI/Serial (chỉ cho phone)
            if (!_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: imeiCtrl,
                label: 'IMEI/Serial (5 số cuối)',
                focusNode: imeiF,
                nextFocus: quantityF,
                keyboardType: TextInputType.number,
                icon: Icons.qr_code,
                inputFormatters: [LengthLimitingTextInputFormatter(5)],
                hasChanged: _imeiChanged,
              ),
              const SizedBox(height: 8),
            ],

            // Số lượng (cho tất cả loại sản phẩm)
            _buildTextField(
              controller: quantityCtrl,
              label: 'Số lượng *',
              focusNode: quantityF,
              nextFocus: costF,
              keyboardType: TextInputType.number,
              icon: Icons.add_box,
              hasChanged: _quantityChanged,
            ),
            const SizedBox(height: 8),

            // Giá nhập
            _buildTextField(
              controller: costCtrl,
              label: 'Giá nhập (VNĐ) *',
              focusNode: costF,
              nextFocus: priceF,
              keyboardType: TextInputType.number,
              icon: Icons.attach_money,
              suffix: 'x1k',
              hasChanged: _costChanged,
            ),
            const SizedBox(height: 8),

            // Giá bán (cho accessory) hoặc Giá thay (cho linh kiện)
            if (_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: priceCtrl,
                label: typeCtrl.text == 'ACCESSORY' ? 'Giá (VNĐ)' : 'Giá thay (VNĐ)',
                focusNode: priceF,
                nextFocus: notesF,
                keyboardType: TextInputType.number,
                icon: Icons.sell,
                suffix: 'x1k',
                hasChanged: _priceChanged,
              ),
              const SizedBox(height: 8),
            ] else ...[
              // Giá bán không phụ kiện (cho phone)
              _buildTextField(
                controller: priceCtrl,
                label: 'Giá bán (VNĐ)',
                focusNode: priceF,
                nextFocus: notesF,
                keyboardType: TextInputType.number,
                icon: Icons.sell,
                suffix: 'x1k',
                hasChanged: _priceChanged,
              ),
              const SizedBox(height: 8),
            ],

            // Nhà cung cấp
            DropdownButtonFormField<String>(
              value: supplierCtrl.text.isNotEmpty ? supplierCtrl.text : null,
              style: TextStyle(
                fontSize: 12,
                color: _supplierChanged ? const Color(0xFF1976D2) : Colors.black87,
                fontWeight: _supplierChanged ? FontWeight.bold : FontWeight.normal,
              ),
              dropdownColor: Colors.white,
              decoration: InputDecoration(
                labelText: 'Nhà cung cấp *',
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _supplierChanged ? const Color(0xFF1976D2) : Colors.black87,
                  fontWeight: _supplierChanged ? FontWeight.bold : FontWeight.normal,
                ),
                prefixIcon: Icon(
                  Icons.business_center,
                  size: 16,
                  color: _supplierChanged ? const Color(0xFF1976D2) : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: false,
                fillColor: _supplierChanged ? const Color(0xFFE3F2FD).withAlpha(50) : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: _supplierChanged ? const Color(0xFF1976D2) : Colors.grey.shade400,
                    width: _supplierChanged ? 1.5 : 1.0,
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blue, width: 1.0),
                ),
              ),
              items: suppliers.map((supplier) => DropdownMenuItem<String>(
                value: supplier['name'] as String,
                child: Text(
                  supplier['name'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: _supplierChanged ? const Color(0xFF1976D2) : Colors.black87,
                    fontWeight: _supplierChanged ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  supplierCtrl.text = value!;
                });
              },
            ),
            const SizedBox(height: 8),

            // Payment method
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Phương thức thanh toán', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Công nợ', style: TextStyle(fontSize: 12)),
                        value: 'Công nợ',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) => setState(() => selectedPaymentMethod = value!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Tiền mặt', style: TextStyle(fontSize: 12)),
                        value: 'Tiền mặt',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) => setState(() => selectedPaymentMethod = value!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Chuyển khoản', style: TextStyle(fontSize: 12)),
                        value: 'Chuyển khoản',
                        groupValue: selectedPaymentMethod,
                        onChanged: (value) => setState(() => selectedPaymentMethod = value!),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ngày nhập
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày nhập',
                  labelStyle: TextStyle(fontSize: 12),
                  prefixIcon: Icon(Icons.calendar_today, size: 16),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                child: Text(
                  '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Ghi chú
            _buildTextField(
              controller: notesCtrl,
              label: 'Ghi chú',
              focusNode: notesF,
              icon: Icons.note,
              hasChanged: _notesChanged,
            ),
            const SizedBox(height: 16),

            // Save button
            ElevatedButton(
              onPressed: _saving ? null : _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('LƯU', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}