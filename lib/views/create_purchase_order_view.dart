import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/purchase_order_model.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/logging_service.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/currency_text_field.dart';

class CreatePurchaseOrderView extends StatefulWidget {
  const CreatePurchaseOrderView({super.key});

  @override
  State<CreatePurchaseOrderView> createState() => _CreatePurchaseOrderViewState();
}

class _CreatePurchaseOrderViewState extends State<CreatePurchaseOrderView> {
  final db = DBHelper();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final supplierNameCtrl = TextEditingController();
  final supplierPhoneCtrl = TextEditingController();
  final supplierAddressCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  // Data
  List<Map<String, dynamic>> _suppliers = [];
  List<PurchaseItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _currentUserName = '';

  // Item form
  final itemNameCtrl = TextEditingController();
  final itemImeiCtrl = TextEditingController();
  final itemQuantityCtrl = TextEditingController();
  final itemCostCtrl = TextEditingController();
  final itemPriceCtrl = TextEditingController();
  final itemColorCtrl = TextEditingController();
  final itemCapacityCtrl = TextEditingController();
  String itemCondition = 'Mới';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final suppliers = await db.getSuppliers();
      final user = FirebaseAuth.instance.currentUser;
      final userData = await UserService.getUserInfo(user?.uid ?? '');

      setState(() {
        _suppliers = suppliers;
        _currentUserName = userData?['name'] ?? 'Unknown';
        _isLoading = false;
      });
    } catch (e) {
      LoggingService.logError("Lỗi load data: $e", null);
      setState(() => _isLoading = false);
    }
  }

  void _addItem() {
    if (itemNameCtrl.text.isEmpty || itemQuantityCtrl.text.isEmpty ||
        itemCostCtrl.text.isEmpty || itemPriceCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập đầy đủ thông tin sản phẩm!", color: Colors.red);
      return;
    }

    final item = PurchaseItem(
      productName: itemNameCtrl.text.trim(),
      imei: itemImeiCtrl.text.isNotEmpty ? itemImeiCtrl.text.trim() : null,
      quantity: int.tryParse(itemQuantityCtrl.text) ?? 0,
      unitCost: int.tryParse(itemCostCtrl.text) ?? 0,
      unitPrice: int.tryParse(itemPriceCtrl.text) ?? 0,
      color: itemColorCtrl.text.isNotEmpty ? itemColorCtrl.text.trim() : null,
      capacity: itemCapacityCtrl.text.isNotEmpty ? itemCapacityCtrl.text.trim() : null,
      condition: itemCondition,
    );

    setState(() {
      _items.add(item);
      _clearItemForm();
    });
  }

  void _clearItemForm() {
    itemNameCtrl.clear();
    itemImeiCtrl.clear();
    itemQuantityCtrl.clear();
    itemCostCtrl.clear();
    itemPriceCtrl.clear();
    itemColorCtrl.clear();
    itemCapacityCtrl.clear();
    itemCondition = 'Mới';
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _savePurchaseOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      NotificationService.showSnackBar("Vui lòng thêm ít nhất 1 sản phẩm!", color: Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final orderCode = await db.generateNextOrderCode();
      final order = PurchaseOrder(
        orderCode: orderCode,
        supplierName: supplierNameCtrl.text.trim(),
        supplierPhone: supplierPhoneCtrl.text.trim(),
        supplierAddress: supplierAddressCtrl.text.isNotEmpty ? supplierAddressCtrl.text.trim() : null,
        items: _items,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        createdBy: _currentUserName,
        notes: notesCtrl.text.isNotEmpty ? notesCtrl.text.trim() : null,
      );

      order.calculateTotals();

      // Save to local DB
      await db.insertPurchaseOrder(order);

      // Save to Firestore
      final firestoreId = await FirestoreService.addPurchaseOrder(order);
      if (firestoreId != null) {
        order.firestoreId = firestoreId;
        await db.updatePurchaseOrder(order);
      }

      if (mounted) {
        Navigator.pop(context);
        NotificationService.showSnackBar("Đã tạo đơn nhập hàng: ${order.orderCode}", color: Colors.green);
      }
    } catch (e) {
      LoggingService.logError("Lỗi tạo đơn nhập: $e", null);
      NotificationService.showSnackBar("Lỗi tạo đơn nhập hàng!", color: Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildItemForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("THÊM SẢN PHẨM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ValidatedTextField(
              controller: itemNameCtrl,
              label: "TÊN SẢN PHẨM",
              icon: Icons.inventory,
              required: true,
              uppercase: true,
            ),
            const SizedBox(height: 8),
            ValidatedTextField(
              controller: itemImeiCtrl,
              label: "IMEI/SERIAL",
              icon: Icons.qr_code,
              uppercase: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: itemQuantityCtrl,
                    decoration: const InputDecoration(labelText: "Số lượng *", border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v?.isEmpty ?? true ? "Bắt buộc" : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CurrencyTextField(
                    controller: itemCostCtrl,
                    label: "ĐƠN GIÁ NHẬP",
                    icon: Icons.attach_money,
                    required: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CurrencyTextField(
                    controller: itemPriceCtrl,
                    label: "ĐƠN GIÁ BÁN",
                    icon: Icons.sell,
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: itemCondition,
                    decoration: const InputDecoration(labelText: "Tình trạng", border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: "Mới", child: Text("Mới")),
                      DropdownMenuItem(value: "Cũ", child: Text("Cũ")),
                      DropdownMenuItem(value: "Hỏng", child: Text("Hỏng")),
                    ],
                    onChanged: (v) => setState(() => itemCondition = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ValidatedTextField(
                    controller: itemColorCtrl,
                    label: "MÀU SẮC",
                    icon: Icons.color_lens,
                    uppercase: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValidatedTextField(
                    controller: itemCapacityCtrl,
                    label: "DUNG LƯỢNG",
                    icon: Icons.memory,
                    uppercase: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text("THÊM SẢN PHẨM"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    if (_items.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text("DANH SÁCH SẢN PHẨM", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return ListTile(
              title: Text(item.productName ?? ''),
              subtitle: Text("${item.quantity} x ${NumberFormat('#,###').format(item.unitCost)}đ = ${NumberFormat('#,###').format(item.quantity * item.unitCost)}đ"),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeItem(index),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Tổng: ${_items.fold(0, (sum, item) => sum + item.quantity)} sản phẩm - ${NumberFormat('#,###').format(_items.fold(0, (sum, item) => sum + (item.unitCost * item.quantity)))}đ",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("TẠO ĐƠN NHẬP HÀNG"),
        backgroundColor: Colors.orange,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("THÔNG TIN NHÀ CUNG CẤP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ValidatedTextField(
                      controller: supplierNameCtrl,
                      label: "TÊN NHÀ CUNG CẤP",
                      icon: Icons.business,
                      required: true,
                      uppercase: true,
                    ),
                    const SizedBox(height: 8),
                    ValidatedTextField(
                      controller: supplierPhoneCtrl,
                      label: "SỐ ĐIỆN THOẠI",
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      uppercase: true,
                    ),
                    const SizedBox(height: 8),
                    ValidatedTextField(
                      controller: supplierAddressCtrl,
                      label: "ĐỊA CHỈ",
                      icon: Icons.location_on,
                      uppercase: true,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: "Ghi chú", border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            _buildItemForm(),
            _buildItemsList(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _savePurchaseOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("LƯU ĐƠN NHẬP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}