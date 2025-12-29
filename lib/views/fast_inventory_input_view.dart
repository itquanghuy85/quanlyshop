import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
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
      if (mounted) Navigator.of(context).pop();

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
          // Header with batch mode indicator
          if (_isBatchMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(77)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.batch_prediction, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    "Chế độ Batch: ${_batchItems.length} sản phẩm",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // Expandable Sections
          ExpansionPanelList(
            expansionCallback: (int index, bool isExpanded) {
              setState(() {
                // We can add state to control expansion if needed
              });
            },
            children: [
              // Templates Section
              ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return const ListTile(
                    leading: Icon(Icons.inventory, color: Color(0xFF2962FF)),
                    title: Text(
                      "CHỌN TEMPLATE SẢN PHẨM",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                    subtitle: Text("Áp dụng mẫu sản phẩm nhanh"),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _productTemplates.length,
                      itemBuilder: (context, index) {
                        final template = _productTemplates[index];
                        return Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 12),
                          child: ElevatedButton(
                            onPressed: () => _applyTemplate(template),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF2962FF),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  template['group'] == 'IP' ? Icons.phone_iphone :
                                  template['group'] == 'SS' ? Icons.phone_android :
                                  Icons.devices_other,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  template['name'].split(' ')[0], // Short name
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                isExpanded: true, // Keep templates expanded by default
              ),

              // Product Type & SKU Section
              ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return ListTile(
                    leading: const Icon(Icons.qr_code, color: Color(0xFF2962FF)),
                    title: const Text(
                      "LOẠI SẢN PHẨM & MÃ HÀNG",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                    subtitle: Text(_skuController.text.isEmpty ? "Chưa tạo mã hàng" : "Mã: ${_skuController.text}"),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Type
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        decoration: InputDecoration(
                          labelText: "Loại sản phẩm",
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: "PHONE", child: Text("📱 Điện thoại")),
                          DropdownMenuItem(value: "ACCESSORY", child: Text("🔧 Phụ kiện")),
                        ],
                        onChanged: (value) => setState(() => _selectedType = value!),
                      ),

                      const SizedBox(height: 16),

                      // SKU Generation Card
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "TẠO MÃ HÀNG TỰ ĐỘNG",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2962FF),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Group selection
                              DropdownButtonFormField<String>(
                                initialValue: _selectedGroup,
                                decoration: InputDecoration(
                                  labelText: "Nhóm sản phẩm",
                                  prefixIcon: const Icon(Icons.group_work, size: 18),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "IP", child: Text("🍎 IP - iPhone")),
                                  DropdownMenuItem(value: "SS", child: Text("🤖 SS - Samsung")),
                                  DropdownMenuItem(value: "PIN", child: Text("🔌 PIN - Pin sạc")),
                                  DropdownMenuItem(value: "MH", child: Text("📺 MH - Màn hình")),
                                  DropdownMenuItem(value: "PK", child: Text("🔧 PK - Phụ kiện")),
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
                                      label: "Thông tin bổ sung",
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
                                    flex: 3,
                                    child: ValidatedTextField(
                                      controller: _skuController,
                                      label: "Mã hàng được tạo",
                                      icon: Icons.qr_code,
                                      uppercase: true,
                                      enabled: false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: _generateSKU,
                                      icon: const Icon(Icons.auto_fix_high, size: 18),
                                      label: const Text("TẠO MÃ"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2962FF),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                isExpanded: true,
              ),

              // Product Details Section
              ExpansionPanel(
                headerBuilder: (BuildContext context, bool isExpanded) {
                  return const ListTile(
                    leading: Icon(Icons.inventory, color: Color(0xFF2962FF)),
                    title: Text(
                      "THÔNG TIN CHI TIẾT",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2962FF),
                      ),
                    ),
                    subtitle: Text("IMEI, giá cả, nhà cung cấp"),
                  );
                },
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                              label: "Chi tiết (dung lượng, màu...)",
                              icon: Icons.info_outline,
                              uppercase: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Prices
                      Text(
                        "THÔNG TIN GIÁ BÁN",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CurrencyTextField(
                              controller: _costController,
                              label: "Giá vốn (VNĐ)",
                              icon: Icons.money,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CurrencyTextField(
                              controller: _kpkController,
                              label: "Giá KPK (VNĐ)",
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
                              label: "Giá lẻ (VNĐ)",
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

                      const SizedBox(height: 16),

                      // Supplier
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSupplier,
                        decoration: InputDecoration(
                          labelText: "Nhà cung cấp",
                          prefixIcon: const Icon(Icons.business),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: _suppliers.map((supplier) => DropdownMenuItem(
                          value: supplier['name'] as String,
                          child: Text(supplier['name']),
                        )).toList(),
                        onChanged: (value) => setState(() => _selectedSupplier = value!),
                      ),

                      const SizedBox(height: 16),

                      // Payment Method
                      Text(
                        "PHƯƠNG THỨC THANH TOÁN",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((method) {
                          final isSelected = _selectedPayment == method;
                          return ChoiceChip(
                            label: Text(
                              method,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (selected) => setState(() => _selectedPayment = method),
                            selectedColor: const Color(0xFF2962FF),
                            backgroundColor: Colors.grey[200],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                isExpanded: true,
              ),

              // Recent Products Section
              if (_showRecent && _recentProducts.isNotEmpty)
                ExpansionPanel(
                  headerBuilder: (BuildContext context, bool isExpanded) {
                    return ListTile(
                      leading: const Icon(Icons.history, color: Color(0xFF2962FF)),
                      title: const Text(
                        "SẢN PHẨM ĐÃ NHẬP GẦN ĐÂY",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2962FF),
                        ),
                      ),
                      subtitle: Text("${_recentProducts.length} sản phẩm"),
                    );
                  },
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _recentProducts.length,
                        itemBuilder: (context, index) {
                          final product = _recentProducts[index];
                          return Container(
                            width: 220,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(13),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      product.type == 'PHONE' ? Icons.phone_iphone : Icons.devices_other,
                                      size: 16,
                                      color: const Color(0xFF2962FF),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "IMEI: ${product.imei ?? 'N/A'}",
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "${NumberFormat('#,###').format(product.price)}đ",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  isExpanded: false,
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        onPressed: _clearForm,
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        tooltip: "Xóa tất cả thông tin",
                      ),
                    ),
                  ],
                ),
                if (_isBatchMode && _batchItems.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Batch hiện tại: ${_batchItems.length} sản phẩm",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
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