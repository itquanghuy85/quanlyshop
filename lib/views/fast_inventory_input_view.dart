import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../utils/sku_generator.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/validated_text_field.dart';

class FastInventoryInputView extends StatefulWidget {
  const FastInventoryInputView({super.key});

  @override
  State<FastInventoryInputView> createState() => _FastInventoryInputViewState();
}

class _FastInventoryInputViewState extends State<FastInventoryInputView> with TickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;

  // Scanner
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;

  // Product data
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _kpkController = TextEditingController();
  final TextEditingController _retailController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: "1");

  // SKU generation
  String _selectedGroup = 'IP';
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _infoController = TextEditingController();
  final TextEditingController _skuController = TextEditingController();

  // Settings
  String _selectedType = 'PHONE';
  String _selectedSupplier = '';
  String _selectedPayment = 'TIỀN MẶT';
  List<Map<String, dynamic>> _suppliers = [];
  bool _isSaving = false;

  // Templates
  final List<Map<String, dynamic>> _productTemplates = [
    {
      'name': 'iPhone Template',
      'group': 'IP',
      'type': 'PHONE',
      'cost': 15000000,
      'kpk': 18000000,
      'retail': 20000000,
    },
    {
      'name': 'Samsung Template',
      'group': 'SS',
      'type': 'PHONE',
      'cost': 8000000,
      'kpk': 10000000,
      'retail': 12000000,
    },
    {
      'name': 'Phụ kiện Template',
      'group': 'PK',
      'type': 'ACCESSORY',
      'cost': 200000,
      'kpk': 300000,
      'retail': 400000,
    },
  ];

  // Batch import
  final List<Map<String, dynamic>> _batchItems = [];
  bool _isBatchMode = false;

  // Recent products
  List<Product> _recentProducts = [];
  bool _showRecent = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSuppliers();
    _loadSettings();
    _loadRecentProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    _imeiController.dispose();
    _nameController.dispose();
    _costController.dispose();
    _kpkController.dispose();
    _retailController.dispose();
    _detailController.dispose();
    _quantityController.dispose();
    _modelController.dispose();
    _infoController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    final suppliers = await db.getSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        if (_suppliers.isNotEmpty) {
          _selectedSupplier = _suppliers.first['name'] as String;
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    // Load saved settings from SharedPreferences if needed
    // TODO: Implement settings loading
  }

  Future<void> _loadRecentProducts() async {
    final products = await db.getInStockProducts();
    // Sort by createdAt descending and take first 10
    products.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    if (mounted) {
      setState(() => _recentProducts = products.take(10).toList());
    }
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _selectedGroup = template['group'];
      _selectedType = template['type'];
      _costController.text = (template['cost'] ~/ 1000).toString();
      _kpkController.text = (template['kpk'] ~/ 1000).toString();
      _retailController.text = (template['retail'] ~/ 1000).toString();
    });
    NotificationService.showSnackBar("Đã áp dụng template: ${template['name']}", color: Colors.blue);
  }

  Future<void> _generateSKU() async {
    if (_selectedGroup.isEmpty) {
      NotificationService.showSnackBar("Vui lòng chọn nhóm sản phẩm!", color: Colors.red);
      return;
    }

    try {
      final generatedSKU = await SKUGenerator.generateSKU(
        nhom: _selectedGroup,
        model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
        thongtin: _infoController.text.trim().isNotEmpty ? _infoController.text.trim() : null,
        dbHelper: db,
        firestoreService: null,
      );

      setState(() => _skuController.text = generatedSKU);
      NotificationService.showSnackBar("Đã tạo mã hàng: $generatedSKU", color: Colors.blue);
    } catch (e) {
      NotificationService.showSnackBar("Lỗi tạo mã hàng: $e", color: Colors.red);
    }
  }

  void _onScanResult(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String code = barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        setState(() {
          _imeiController.text = code;
          _isScanning = false;
        });
        NotificationService.showSnackBar("Đã scan: $code", color: Colors.green);
        _scannerController.stop();
      }
    }
  }

  Future<void> _saveProduct({bool addToBatch = false}) async {
    if (_skuController.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng tạo mã hàng trước!", color: Colors.red);
      return;
    }
    if (_selectedSupplier.isEmpty) {
      NotificationService.showSnackBar("Vui lòng chọn Nhà cung cấp!", color: Colors.red);
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final productData = {
        'name': _skuController.text.toUpperCase(),
        'imei': _imeiController.text.trim(),
        'cost': _parsePrice(_costController.text),
        'kpkPrice': _parsePrice(_kpkController.text),
        'price': _parsePrice(_retailController.text),
        'capacity': _detailController.text.toUpperCase(),
        'quantity': int.tryParse(_quantityController.text) ?? 1,
        'type': _selectedType,
        'supplier': _selectedSupplier,
        'paymentMethod': _selectedPayment,
      };

      if (addToBatch) {
        setState(() {
          _batchItems.add(productData);
          _clearForm();
        });
        NotificationService.showSnackBar("Đã thêm vào danh sách batch (${_batchItems.length} sản phẩm)", color: Colors.blue);
      } else {
        await _saveSingleProduct(productData);
        _clearForm();
      }
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSingleProduct(Map<String, dynamic> productData) async {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final String imei = productData['imei'];
    final String fId = "prod_${ts}_${imei.isNotEmpty ? imei : ts}";

    final p = Product(
      firestoreId: fId,
      name: productData['name'],
      imei: imei,
      cost: productData['cost'],
      kpkPrice: productData['kpkPrice'],
      price: productData['price'],
      capacity: productData['capacity'],
      quantity: productData['quantity'],
      type: productData['type'],
      createdAt: ts,
      supplier: productData['supplier'],
      status: 1,
    );

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";

    await db.logAction(
      userId: user?.uid ?? "0",
      userName: userName,
      action: "NHẬP KHO",
      type: "PRODUCT",
      targetId: p.imei,
      desc: "Đã nhập máy ${p.name}",
    );

    if (productData['paymentMethod'] != "CÔNG NỢ") {
      await db.insertExpense({
        'title': "NHẬP HÀNG: ${p.name}",
        'amount': p.cost * p.quantity,
        'category': "NHẬP HÀNG",
        'date': ts,
        'paymentMethod': productData['paymentMethod'],
        'note': "Nhập từ ${productData['supplier']}",
      });
    } else {
      await db.insertDebt({
        'personName': productData['supplier'],
        'totalAmount': p.cost * p.quantity,
        'paidAmount': 0,
        'type': "SHOP_OWES",
        'status': "unpaid",
        'createdAt': ts,
        'note': "Nợ tiền máy ${p.name}",
      });
    }

    await db.upsertProduct(p);
    await FirestoreService.addProduct(p);

    HapticFeedback.lightImpact();
    NotificationService.showSnackBar("NHẬP KHO THÀNH CÔNG", color: Colors.green);

    // Refresh recent products
    _loadRecentProducts();
  }

  Future<void> _saveBatch() async {
    if (_batchItems.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      for (final productData in _batchItems) {
        await _saveSingleProduct(productData);
      }

      setState(() => _batchItems.clear());
      NotificationService.showSnackBar("Đã nhập kho ${_batchItems.length} sản phẩm thành công!", color: Colors.green);
      Navigator.of(context).pop();

      // Refresh recent products
      _loadRecentProducts();
    } catch (e) {
      NotificationService.showSnackBar("Lỗi khi nhập batch: $e", color: Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  int _parsePrice(String text) {
    final cleaned = text.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), '');
    final value = int.tryParse(cleaned) ?? 0;
    return (value > 0 && value < 100000) ? value * 1000 : value;
  }

  void _clearForm() {
    _imeiController.clear();
    _nameController.clear();
    _costController.clear();
    _kpkController.clear();
    _retailController.clear();
    _detailController.clear();
    _quantityController.text = "1";
    _modelController.clear();
    _infoController.clear();
    _skuController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          "NHẬP KHO SIÊU TỐC",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: "Nhập đơn"),
            Tab(icon: Icon(Icons.qr_code_scanner), text: "Scan QR"),
            Tab(icon: Icon(Icons.inventory), text: "Batch"),
          ],
          labelColor: const Color(0xFF2962FF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF2962FF),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showRecent = !_showRecent),
            icon: Icon(_showRecent ? Icons.history : Icons.history_outlined),
            tooltip: _showRecent ? "Ẩn sản phẩm gần đây" : "Hiện sản phẩm gần đây",
          ),
          if (_isBatchMode && _batchItems.isNotEmpty)
            IconButton(
              onPressed: _saveBatch,
              icon: const Icon(Icons.save, color: Colors.green),
              tooltip: "Lưu batch",
            ),
          IconButton(
            onPressed: () => setState(() => _isBatchMode = !_isBatchMode),
            icon: Icon(
              _isBatchMode ? Icons.batch_prediction : Icons.batch_prediction_outlined,
              color: _isBatchMode ? Colors.blue : Colors.grey,
            ),
            tooltip: _isBatchMode ? "Tắt chế độ batch" : "Bật chế độ batch",
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSingleInputTab(),
          _buildScannerTab(),
          _buildBatchTab(),
        ],
      ),
    );
  }

  Widget _buildSingleInputTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Templates
          const Text(
            "CHỌN TEMPLATE SẢN PHẨM",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2962FF)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productTemplates.length,
              itemBuilder: (context, index) {
                final template = _productTemplates[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: () => _applyTemplate(template),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2962FF),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      template['name'],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          // Product Type
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: "Loại sản phẩm",
              prefixIcon: Icon(Icons.category),
            ),
            items: const [
              DropdownMenuItem(value: "PHONE", child: Text("Điện thoại")),
              DropdownMenuItem(value: "ACCESSORY", child: Text("Phụ kiện")),
            ],
            onChanged: (value) => setState(() => _selectedType = value!),
          ),

          const SizedBox(height: 16),

          // SKU Generation Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TẠO MÃ HÀNG",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2962FF)),
                ),
                const SizedBox(height: 12),

                // Group selection
                DropdownButtonFormField<String>(
                  value: _selectedGroup,
                  decoration: const InputDecoration(
                    labelText: "Nhóm",
                    prefixIcon: Icon(Icons.group_work, size: 18),
                  ),
                  items: const [
                    DropdownMenuItem(value: "IP", child: Text("IP - iPhone")),
                    DropdownMenuItem(value: "SS", child: Text("SS - Samsung")),
                    DropdownMenuItem(value: "PIN", child: Text("PIN - Pin sạc")),
                    DropdownMenuItem(value: "MH", child: Text("MH - Màn hình")),
                    DropdownMenuItem(value: "PK", child: Text("PK - Phụ kiện")),
                  ],
                  onChanged: (value) => setState(() => _selectedGroup = value!),
                ),

                const SizedBox(height: 12),

                // Model and Info
                Row(
                  children: [
                    Expanded(
                      child: ValidatedTextField(
                        controller: _modelController,
                        label: "Model",
                        icon: Icons.smartphone,
                        uppercase: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValidatedTextField(
                        controller: _infoController,
                        label: "Thông tin",
                        icon: Icons.info,
                        uppercase: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // SKU generation
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ValidatedTextField(
                        controller: _skuController,
                        label: "Mã hàng",
                        icon: Icons.qr_code,
                        uppercase: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        onPressed: _generateSKU,
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text("TẠO MÃ"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2962FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Product Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "THÔNG TIN SẢN PHẨM",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2962FF)),
                ),
                const SizedBox(height: 12),

                // IMEI and Details
                Row(
                  children: [
                    Expanded(
                      child: ValidatedTextField(
                        controller: _imeiController,
                        label: "IMEI/Serial",
                        icon: Icons.fingerprint,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValidatedTextField(
                        controller: _detailController,
                        label: "Chi tiết",
                        icon: Icons.info_outline,
                        uppercase: true,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Prices
                Row(
                  children: [
                    Expanded(
                      child: CurrencyTextField(
                        controller: _costController,
                        label: "Giá vốn (k)",
                        icon: Icons.money,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CurrencyTextField(
                        controller: _kpkController,
                        label: "Giá KPK (k)",
                        icon: Icons.card_giftcard,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: CurrencyTextField(
                        controller: _retailController,
                        label: "Giá lẻ (k)",
                        icon: Icons.sell,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValidatedTextField(
                        controller: _quantityController,
                        label: "Số lượng",
                        icon: Icons.add_box,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Supplier
                DropdownButtonFormField<String>(
                  value: _selectedSupplier,
                  decoration: const InputDecoration(
                    labelText: "Nhà cung cấp",
                    prefixIcon: Icon(Icons.business),
                  ),
                  items: _suppliers.map((supplier) => DropdownMenuItem(
                    value: supplier['name'] as String,
                    child: Text(supplier['name']),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedSupplier = value!),
                ),

                const SizedBox(height: 16),

                // Payment Method
                const Text(
                  "PHƯƠNG THỨC THANH TOÁN",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((method) => ChoiceChip(
                    label: Text(method, style: const TextStyle(fontSize: 11)),
                    selected: _selectedPayment == method,
                    onSelected: (selected) => setState(() => _selectedPayment = method),
                    selectedColor: Colors.blueAccent.withOpacity(0.2),
                  )).toList(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Recent Products Section
          if (_showRecent && _recentProducts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SẢN PHẨM ĐÃ NHẬP GẦN ĐÂY",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2962FF)),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentProducts.length,
                      itemBuilder: (context, index) {
                        final product = _recentProducts[index];
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "IMEI: ${product.imei ?? 'N/A'}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Text(
                                "${NumberFormat('#,###').format(product.price)}đ",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          Row(
            children: [
              if (_isBatchMode)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _saveProduct(addToBatch: true),
                    icon: const Icon(Icons.add_to_queue),
                    label: const Text("THÊM VÀO BATCH"),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _saveProduct(),
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: _isSaving
                        ? const Text("ĐANG LƯU...")
                        : const Text("NHẬP KHO NGAY"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2962FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _clearForm,
                icon: const Icon(Icons.clear, color: Colors.grey),
                tooltip: "Xóa form",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScannerTab() {
    return Column(
      children: [
        Expanded(
          child: _isScanning
              ? MobileScanner(
                  controller: _scannerController,
                  onDetect: _onScanResult,
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      "Camera chưa được khởi động",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isScanning = !_isScanning);
                        if (_isScanning) {
                          _scannerController.start();
                        } else {
                          _scannerController.stop();
                        }
                      },
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                      label: Text(_isScanning ? "DỪNG SCAN" : "BẮT ĐẦU SCAN"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _scannerController.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on),
                    tooltip: "Bật/tắt đèn flash",
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValidatedTextField(
                controller: _imeiController,
                label: "IMEI/Serial (có thể nhập thủ công)",
                icon: Icons.fingerprint,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBatchTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DANH SÁCH BATCH (${_batchItems.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2962FF),
                ),
              ),
              if (_batchItems.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _saveBatch,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text("LƯU TẤT CẢ"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _batchItems.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Chưa có sản phẩm nào trong batch",
                        style: TextStyle(color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Chuyển sang tab 'Nhập đơn' và bật chế độ batch",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _batchItems.length,
                  itemBuilder: (context, index) {
                    final item = _batchItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item['name']),
                        subtitle: Text("IMEI: ${item['imei']} • Giá: ${NumberFormat('#,###').format(item['price'])}đ"),
                        trailing: IconButton(
                          onPressed: () => setState(() => _batchItems.removeAt(index)),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}