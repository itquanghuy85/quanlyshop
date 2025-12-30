import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/debt_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../services/event_bus.dart';
import '../utils/money_utils.dart';
import '../utils/sku_generator.dart';

// Formatter to force uppercase input without triggering controller loops
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final upper = newValue.text.toUpperCase();
    return newValue.copyWith(text: upper, selection: newValue.selection);
  }
}

class FastStockInView extends StatefulWidget {
  const FastStockInView({super.key});

  @override
  State<FastStockInView> createState() => _FastStockInViewState();
}

class _FastStockInViewState extends State<FastStockInView> {
  final db = DBHelper();
  bool _saving = false;
  bool _isLoading = true;
  String? _loadingError;

  // Selected values
  String? selectedBrand;
  String? selectedCapacity;
  String? selectedColor;
  String? selectedCondition;
  String? selectedSupplier;
  String? selectedPaymentMethod;

  final TextEditingController modelCtrl = TextEditingController();
  final TextEditingController imeiCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController(text: '1');
  final TextEditingController costCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();

  List<Map<String, dynamic>> suppliers = [];

  // Options
  final List<String> brands = ['IPHONE', 'SAMSUNG', 'OPPO', 'REDMI'];
  final List<String> capacities = ['64GB', '128GB', '256GB', '512GB', '1TB'];
  final List<String> colors = ['ĐEN', 'TRẮNG', 'XANH', 'ĐỎ', 'VÀNG', 'TÍM'];
  final List<String> conditions = ['MỚI', '99', 'KHÁC'];
  final List<String> paymentMethods = ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'CÔNG NỢ'];

  // Model suggestions based on brand
  final Map<String, List<String>> modelSuggestions = {
    'IPHONE': ['15', '14', '13', '12', '11', 'X', '8', 'SE'],
    'SAMSUNG': ['S24', 'S23', 'S22', 'S21', 'A54', 'A34', 'A14'],
    'OPPO': ['A18', 'A17', 'A16', 'A15', 'F11', 'F9'],
    'REDMI': ['13C', '12C', '11', '10', '9', 'Note 12'],
  };

  @override
  void initState() {
    super.initState();
    _initData();
    imeiCtrl.addListener(_updateConfirmButton);
    modelCtrl.addListener(_updateConfirmButton);
  }

  int _parseMoneyWithK(String text) {
    final value = MoneyUtils.parseMoney(text);
    return (value > 0 && value < 100000) ? value * 1000 : value;
  }

  Future<void> _initData() async {
    setState(() { _isLoading = true; _loadingError = null; });
    try {
      // Timeout to prevent permanent loading state
      await _loadSuppliers().timeout(const Duration(seconds: 5));
    } catch (e) {
      // Handle timeout or other errors
      debugPrint('FastStockIn: load suppliers error: $e');
      _loadingError = 'Lỗi tải dữ liệu, thử lại.';
      if (mounted) NotificationService.showSnackBar('Lỗi tải nhà cung cấp: $e', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    imeiCtrl.removeListener(_updateConfirmButton);
    modelCtrl.removeListener(_updateConfirmButton);
    modelCtrl.dispose();
    imeiCtrl.dispose();
    quantityCtrl.dispose();
    costCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  void _updateConfirmButton() {
    setState(() {});
  }

  Future<void> _loadSuppliers() async {
    debugPrint('FastStockIn: start loading suppliers');
    try {
      final sups = await db.getSuppliers();
      if (mounted) {
        setState(() {
          suppliers = sups.where((s) => s['name'] != null && s['name'].toString().isNotEmpty).toList();
        });
        debugPrint('FastStockIn: loaded suppliers count=${suppliers.length}');
      }
    } catch (e) {
      debugPrint('FastStockIn: loadSuppliers error: $e');
      if (mounted) {
        NotificationService.showSnackBar("Lỗi tải nhà cung cấp: $e", color: Colors.red);
      }
    }
  }

  Future<void> _addNewSupplier() async {
    final nameCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thêm nhà cung cấp mới', style: TextStyle(fontSize: 14)),
        content: TextField(
          controller: nameCtrl,
          inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(60)],
          decoration: const InputDecoration(labelText: 'Tên nhà cung cấp'),
          style: const TextStyle(fontSize: 11),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(onPressed: () async {
            if (nameCtrl.text.trim().isNotEmpty) {
              try {
                await db.insertSupplier({'name': nameCtrl.text.trim().toUpperCase(), 'createdAt': DateTime.now().millisecondsSinceEpoch});
                await _loadSuppliers();
                setState(() => selectedSupplier = nameCtrl.text.trim().toUpperCase());
                Navigator.pop(ctx, true);
              } catch (e) {
                NotificationService.showSnackBar("Lỗi thêm nhà cung cấp: $e", color: Colors.red);
              }
            }
          }, child: const Text('Thêm')),
        ],
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (selectedBrand == null || selectedCapacity == null || selectedColor == null || selectedCondition == null || selectedSupplier == null || selectedPaymentMethod == null) {
      NotificationService.showSnackBar("Vui lòng chọn đầy đủ thông tin!", color: Colors.red);
      return;
    }
    if (modelCtrl.text.trim().isEmpty || imeiCtrl.text.trim().isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập model và IMEI!", color: Colors.red);
      return;
    }

    // Check if IMEI already exists
    final existingProduct = await db.getProductByImei(imeiCtrl.text.trim());
    if (existingProduct != null) {
      NotificationService.showSnackBar("IMEI đã tồn tại trong kho! Vui lòng nhập IMEI mới.", color: Colors.red);
      return;
    }

    final cost = _parseMoneyWithK(costCtrl.text);
    if (cost <= 0) {
      NotificationService.showSnackBar("Vui lòng nhập giá nhập hợp lệ!", color: Colors.red);
      return;
    }

    final price = _parseMoneyWithK(priceCtrl.text);
    if (price < 0) {
      NotificationService.showSnackBar("Vui lòng nhập giá bán hợp lệ!", color: Colors.red);
      return;
    }

    final quantity = int.tryParse(quantityCtrl.text) ?? 1;
    if (quantity <= 0) {
      NotificationService.showSnackBar("Số lượng phải lớn hơn 0!", color: Colors.red);
      return;
    }

    setState(() => _saving = true);

    try {
      // Generate SKU
      final sku = await SKUGenerator.generateSKU(
        nhom: _getNhomFromBrand(selectedBrand!),
        model: modelCtrl.text.trim(),
        thongtin: null,
        dbHelper: db,
        firestoreService: null,
      );

      final ts = DateTime.now().millisecondsSinceEpoch;
      final imei = imeiCtrl.text.trim();
      final fId = "prod_${ts}_${imei}";

      final product = Product(
        firestoreId: fId,
        name: '$selectedBrand ${modelCtrl.text.trim()} $selectedCapacity $selectedColor $selectedCondition'.toUpperCase(),
        brand: selectedBrand!,
        imei: imei,
        cost: cost,
        price: price,
        condition: selectedCondition!,
        status: 1,
        description: 'Nhập nhanh',
        createdAt: ts,
        supplier: selectedSupplier,
        type: 'PHONE',
        quantity: quantity,
        color: selectedColor!,
        capacity: selectedCapacity!,
        paymentMethod: selectedPaymentMethod,
      );

      await db.upsertProduct(product);
      await FirestoreService.addProduct(product);

      // If payment method is "Công nợ", create debt for supplier
      if (selectedPaymentMethod == 'CÔNG NỢ') {
        // Find supplier phone gracefully
        final sup = suppliers.firstWhere((s) => s['name'] == selectedSupplier, orElse: () => {});
        final supPhone = (sup.isNotEmpty ? (sup['phone'] ?? '').toString() : '');

        final debt = Debt(
          personName: selectedSupplier!,
          phone: supPhone,
          totalAmount: cost * quantity,
          paidAmount: 0,
          type: 'SHOP_OWES', // mark as shop owes (supplier debt)
          status: 'unpaid',
          createdAt: ts,
          note: 'Công nợ nhập hàng ${product.name}',
          linkedId: product.firestoreId,
        );

        // Ensure a deterministic firestoreId so local insert and cloud doc use same id and avoid duplicates
        debt.firestoreId = "debt_${ts}_${supPhone.isNotEmpty ? supPhone : 'ncc'}";

        try {
          // Defensive: check if a similar debt already exists for this linked product to avoid duplicates
          final existingDebts = await db.getAllDebts();
          final dup = existingDebts.firstWhere((d) => d['linkedId'] == product.firestoreId && (d['totalAmount'] ?? 0) == (cost * quantity), orElse: () => {});
          if (dup.isNotEmpty) {
            debugPrint('FastStockIn: duplicate debt detected, skipping create for linkedId=${product.firestoreId}');
            EventBus().emit('debts_changed');
            NotificationService.showSnackBar("Khoản nợ đã tồn tại, bỏ qua tạo mới.", color: Colors.orange);
            if (mounted) { Navigator.pop(context, true); return; }
          }

          debugPrint('FastStockIn: creating local debt with firestoreId=${debt.firestoreId}');
          await db.upsertDebt(debt);
          // Send full map including firestoreId to Firestore so server doc uses same id
          try {
            debugPrint('FastStockIn: pushing debt to cloud id=${debt.firestoreId}');
            await FirestoreService.addDebtCloud(debt.toMap());
          } catch (e) {
            debugPrint('FastStockIn: addDebtCloud failed: $e');
            // Don't block user; debt is saved locally and will sync later
          }

          // Notify other UI that debts changed (DebtView listens and will refresh)
          EventBus().emit('debts_changed');

          // Inform user and close
          NotificationService.showSnackBar("Đã tạo công nợ cho nhà cung cấp", color: Colors.green);
          if (mounted) {
            Navigator.pop(context, true);
            return;
          }
        } catch (e) {
          debugPrint('FastStockIn: upsertDebt error: $e');
          NotificationService.showSnackBar("Không thể tạo công nợ: $e", color: Colors.red);
          // continue so product was already saved; user can retry debt creation separately
        }
      } else if (selectedPaymentMethod == 'TIỀN MẶT' || selectedPaymentMethod == 'CHUYỂN KHOẢN') {
        // Create an expense record for cash/transfer payments so costs are tracked
        final exp = {
          'title': 'Nhập hàng - $selectedSupplier',
          'amount': cost * quantity,
          'category': 'PURCHASE',
          'date': ts,
          'note': 'Chi phí nhập hàng ${product.name}',
          'paymentMethod': selectedPaymentMethod,
          'createdAt': ts,
        };
        try {
          await db.insertExpense(exp);
          await FirestoreService.addExpenseCloud(exp);
        } catch (_) {}
      }

      // Log action
      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";
      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: "NHẬP KHO NHANH",
        type: "PRODUCT",
        targetId: product.imei,
        desc: "Nhập nhanh ${product.name}",
      );

      NotificationService.showSnackBar("Nhập kho nhanh thành công!", color: Colors.green);

      // Send chat notification
      await FirestoreService.sendChat(
        message: "📦 Đã nhập kho: ${product.name} (${product.imei}) - SL: $quantity - NCC: $selectedSupplier",
        senderId: user?.uid ?? "system",
        senderName: userName,
        linkedType: "PRODUCT",
        linkedKey: product.imei,
        linkedSummary: product.name,
      );

      // Reset form
      _resetForm();
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
    } finally {
      setState(() => _saving = false);
    }
  }

  String _getNhomFromBrand(String brand) {
    switch (brand) {
      case 'IPHONE': return 'IP';
      case 'SAMSUNG': return 'SS';
      case 'OPPO': return 'OP';
      case 'REDMI': return 'RD';
      default: return 'OT';
    }
  }

  void _resetForm() {
    setState(() {
      selectedBrand = null;
      selectedCapacity = null;
      selectedColor = null;
      selectedCondition = null;
      selectedSupplier = null;
      selectedPaymentMethod = null;
    });
    modelCtrl.clear();
    imeiCtrl.clear();
    quantityCtrl.text = '1';
    costCtrl.clear();
    priceCtrl.clear();
  }

  Widget _buildSupplierField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nhà cung cấp', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: selectedSupplier,
                items: suppliers.map((sup) => DropdownMenuItem<String>(
                  value: sup['name'] as String,
                  child: Text(sup['name'] as String, style: const TextStyle(fontSize: 11)),
                )).toList(),
                onChanged: (val) => setState(() => selectedSupplier = val),
                decoration: InputDecoration(
                  hintText: 'Chọn nhà cung cấp',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                ),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addNewSupplier,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(32, 32),
              ),
              child: const Text('+', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildModelField() {
    final suggestions = selectedBrand != null ? modelSuggestions[selectedBrand!] ?? [] : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Model', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: modelCtrl,
          inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(64)],
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            hintText: 'Nhập model',
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: suggestions.take(5).map((model) => GestureDetector(
              onTap: () => setState(() => modelCtrl.text = model),
              child: Chip(
                label: Text(model.toUpperCase(), style: const TextStyle(fontSize: 10)),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              ),
            )).toList(),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChipRow(String title, List<String> options, String? selected, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: options.map((option) => ChoiceChip(
            label: Text(option, style: const TextStyle(fontSize: 10, color: Colors.black)),
            selected: selected == option,
            selectedColor: Colors.blue[100],
            onSelected: (sel) => setState(() => onSelect(option)),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          )).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPresetRow(String title, TextEditingController controller, {String? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 11),
          decoration: InputDecoration(
            hintText: 'Nhập giá',
            suffixText: suffix,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập Kho Nhanh'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      // Avoid complex nested ternary in the widget tree — build the body explicitly
      body: Builder(
        builder: (ctx) {
          Widget bodyContent;
          try {
            if (_isLoading) {
              bodyContent = Center(child: CircularProgressIndicator(color: Theme.of(ctx).primaryColor));
            } else if (_loadingError != null) {
              bodyContent = Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_loadingError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _initData, child: const Text('Thử lại'))
                  ]),
                ),
              );
            } else {
              bodyContent = SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            _buildChipRow('Loại hàng', brands, selectedBrand, (v) => selectedBrand = v),
            _buildChipRow('Dung lượng', capacities, selectedCapacity, (v) => selectedCapacity = v),
            _buildChipRow('Màu sắc', colors, selectedColor, (v) => selectedColor = v),
            _buildChipRow('Tình trạng', conditions, selectedCondition, (v) => selectedCondition = v),

            _buildModelField(),
            _buildSupplierField(),
            // Thanh toán đặt dưới nhà cung cấp để người dùng thấy rõ liên quan tới thanh toán
            const SizedBox(height: 6),
            _buildChipRow('Thanh toán', paymentMethods, selectedPaymentMethod, (v) => setState(() => selectedPaymentMethod = v)),


            Text('IMEI/Serial *', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            TextField(
              controller: imeiCtrl,
              inputFormatters: [UpperCaseTextFormatter(), LengthLimitingTextInputFormatter(64)],
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Nhập IMEI (bắt buộc)',
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 8),

            Text('Số lượng', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            TextField(
              controller: quantityCtrl,
              keyboardType: TextInputType.number,
              enabled: imeiCtrl.text.isEmpty,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Số lượng',
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 8),

            _buildPresetRow('Giá nhập (VNĐ)', costCtrl, suffix: 'x1k'),
            _buildPresetRow('Giá bán (VNĐ)', priceCtrl, suffix: 'x1k'),

            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('XÁC NHẬN NHẬP KHO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }
    } catch (e, st) {
      debugPrint('FastStockIn: build exception: $e\n$st');
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Lỗi hiển thị, thử lại sau.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _initData, child: const Text('Thử lại'))
          ]),
        ),
      );
    }
    return bodyContent;
  },
),
    );
  }
}
