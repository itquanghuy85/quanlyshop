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
  const StockInView({super.key});

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
  final kpkPriceCtrl = TextEditingController();
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
  final kpkPriceF = FocusNode();
  final notesF = FocusNode();

  // Dropdown options
  final List<String> types = ['PHONE', 'ACCESSORY', 'LINH KIỆN'];
  final List<String> brands = ['IPHONE', 'SAMSUNG', 'OPPO'];
  final List<String> conditions = ['Mới', '99', '98', 'Khác'];
  List<Map<String, dynamic>> suppliers = [];

  // Computed property to check if current type is accessory or linh kiện
  bool get _isAccessoryOrLinhKien => typeCtrl.text == 'ACCESSORY' || typeCtrl.text == 'LINH KIỆN';

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    imeiCtrl.addListener(_onImeiChanged);
  }

  int _parseMoneyWithK(String text) {
    final value = MoneyUtils.parseMoney(text);
    return (value > 0 && value < 100000) ? value * 1000 : value;
  }

  @override
  void dispose() {
    imeiCtrl.removeListener(_onImeiChanged);
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
    kpkPriceCtrl.dispose();
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
    kpkPriceF.dispose();
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
      NotificationService.showSnackBar("Vui lòng chọn hãng!", color: Colors.red);
      return false;
    }
    if (modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập model!", color: Colors.red);
      return false;
    }
    if (capacityCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập dung lượng!", color: Colors.red);
      return false;
    }
    if (colorCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập màu sắc!", color: Colors.red);
      return false;
    }
    if (imeiCtrl.text.isNotEmpty) {
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
      NotificationService.showSnackBar("Giá bán không phụ kiện không được âm!", color: Colors.red);
      return false;
    }
    final kpkPrice = _parseMoneyWithK(kpkPriceCtrl.text);
    if (kpkPrice < 0) {
      NotificationService.showSnackBar("Giá KPK không được âm!", color: Colors.red);
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
        name: '${brandCtrl.text} ${modelCtrl.text}'.toUpperCase(),
        brand: brandCtrl.text.toUpperCase(),
        imei: imei.isNotEmpty ? imei : null,
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
        capacity: capacityCtrl.text.trim().toUpperCase(),
        kpkPrice: _parseMoneyWithK(kpkPriceCtrl.text),
        paymentMethod: selectedPaymentMethod,
      );

      await db.upsertProduct(product);
      await FirestoreService.addProduct(product);

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
    brandCtrl.clear();
    modelCtrl.clear();
    capacityCtrl.clear();
    colorCtrl.clear();
    imeiCtrl.clear();
    quantityCtrl.text = '1';
    costCtrl.clear();
    priceCtrl.clear();
    kpkPriceCtrl.clear();
    notesCtrl.clear();
    selectedDate = DateTime.now();
    setState(() {});
  }

  Widget _buildDropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> items,
    FocusNode? nextFocus,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: controller.text.isNotEmpty ? controller.text : null,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: Colors.black54) : null,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: false, // Override theme to not fill background
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
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.characters,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black87),
        prefixIcon: icon != null ? Icon(icon, size: 16, color: Colors.black54) : null,
        suffixText: suffix,
        suffixStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        filled: false, // Override theme to not fill background
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

            // Hãng
            _buildDropdownField(
              label: 'Hãng *',
              controller: brandCtrl,
              items: brands,
              nextFocus: modelF,
              icon: Icons.business,
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
              ),
              const SizedBox(height: 8),
            ],

            // Màu sắc
            _buildTextField(
              controller: colorCtrl,
              label: 'Màu sắc *',
              focusNode: colorF,
              nextFocus: _isAccessoryOrLinhKien ? costF : imeiF,
              icon: Icons.color_lens,
            ),
            const SizedBox(height: 8),

            // Tình trạng máy
            _buildDropdownField(
              label: 'Tình trạng',
              controller: conditionCtrl,
              items: conditions,
              icon: Icons.check_circle,
            ),
            const SizedBox(height: 8),

            // IMEI/Serial (ẩn với accessory/linh kiện)
            if (!_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: imeiCtrl,
                label: 'IMEI/Serial',
                focusNode: imeiF,
                nextFocus: quantityF,
                keyboardType: TextInputType.number,
                icon: Icons.qr_code,
              ),
              const SizedBox(height: 8),
            ],

            // Số lượng (ẩn với accessory/linh kiện)
            if (!_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: quantityCtrl,
                label: 'Số lượng *',
                focusNode: quantityF,
                nextFocus: costF,
                keyboardType: TextInputType.number,
                icon: Icons.add_box,
              ),
              const SizedBox(height: 8),
            ],

            // Giá nhập
            _buildTextField(
              controller: costCtrl,
              label: 'Giá nhập (VNĐ) *',
              focusNode: costF,
              nextFocus: priceF,
              keyboardType: TextInputType.number,
              icon: Icons.attach_money,
              suffix: 'x1k',
            ),
            const SizedBox(height: 8),

            // Giá bán (cho accessory) hoặc Giá thay (cho linh kiện)
            if (_isAccessoryOrLinhKien) ...[
              _buildTextField(
                controller: priceCtrl,
                label: typeCtrl.text == 'ACCESSORY' ? 'Giá bán phụ kiện (VNĐ)' : 'Giá thay linh kiện (VNĐ)',
                focusNode: priceF,
                nextFocus: notesF,
                keyboardType: TextInputType.number,
                icon: Icons.sell,
                suffix: 'x1k',
              ),
              const SizedBox(height: 8),
            ] else ...[
              // Giá bán không phụ kiện (cho phone)
              _buildTextField(
                controller: priceCtrl,
                label: 'Giá bán không phụ kiện (VNĐ)',
                focusNode: priceF,
                nextFocus: kpkPriceF,
                keyboardType: TextInputType.number,
                icon: Icons.sell,
                suffix: 'x1k',
              ),
              const SizedBox(height: 8),

              // Giá KPK (chỉ cho phone)
              _buildTextField(
                controller: kpkPriceCtrl,
                label: 'Giá KPK (VNĐ)',
                focusNode: kpkPriceF,
                nextFocus: notesF,
                keyboardType: TextInputType.number,
                icon: Icons.card_giftcard,
                suffix: 'x1k',
              ),
              const SizedBox(height: 8),
            ],

            // Nhà cung cấp
            DropdownButtonFormField<String>(
              value: supplierCtrl.text.isNotEmpty ? supplierCtrl.text : null,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Nhà cung cấp *',
                labelStyle: TextStyle(fontSize: 12),
                prefixIcon: Icon(Icons.business_center, size: 16),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              items: suppliers.map((supplier) => DropdownMenuItem<String>(
                value: supplier['name'] as String,
                child: Text(supplier['name'] as String, style: const TextStyle(fontSize: 12)),
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