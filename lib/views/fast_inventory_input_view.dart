import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
<<<<<<< HEAD
import '../controllers/fast_inventory_input_controller.dart';
import '../models/product_model.dart';
import '../services/notification_service.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/validated_text_field.dart';
import 'stock_in_view.dart';
=======
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/sku_generator.dart';
import '../widgets/currency_text_field.dart';
import '../widgets/validated_text_field.dart';
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

class FastInventoryInputView extends StatefulWidget {
  const FastInventoryInputView({super.key});

  @override
  State<FastInventoryInputView> createState() => _FastInventoryInputViewState();
}

class _FastInventoryInputViewState extends State<FastInventoryInputView> with TickerProviderStateMixin {
<<<<<<< HEAD
  final FastInventoryInputController _controller = FastInventoryInputController();
=======
  final db = DBHelper();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  late TabController _tabController;

  // Scanner
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = false;

  // Product data
  final TextEditingController _imeiController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
<<<<<<< HEAD
=======
  final TextEditingController _kpkController = TextEditingController();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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

<<<<<<< HEAD
  // Manual input variables from StockInView
  final TextEditingController typeCtrl = TextEditingController();
  final TextEditingController brandCtrl = TextEditingController();
  final TextEditingController modelCtrl = TextEditingController();
  final TextEditingController capacityCtrl = TextEditingController();
  final TextEditingController colorCtrl = TextEditingController();
  final TextEditingController conditionCtrl = TextEditingController();
  final TextEditingController imeiCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController(text: '1');
  final TextEditingController costCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController supplierCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  final FocusNode brandF = FocusNode();
  final FocusNode modelF = FocusNode();
  final FocusNode capacityF = FocusNode();
  final FocusNode colorF = FocusNode();
  final FocusNode imeiF = FocusNode();
  final FocusNode quantityF = FocusNode();
  final FocusNode costF = FocusNode();
  final FocusNode priceF = FocusNode();
  final FocusNode notesF = FocusNode();

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

  final List<String> types = ['PHONE', 'ACCESSORY', 'LINHKIEN'];
  final List<String> conditions = ['Mới 100%', 'Mới 99%', 'Mới 95%', 'Mới 90%', 'Đã sử dụng'];
  List<Map<String, dynamic>> suppliers = [];
  String selectedPaymentMethod = 'Tiền mặt';
  DateTime selectedDate = DateTime.now();
  bool _saving = false;

  bool get _isAccessoryOrLinhKien => typeCtrl.text == 'ACCESSORY' || typeCtrl.text == 'LINHKIEN';

=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
<<<<<<< HEAD
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final suppliers = await _controller.getSuppliers();
      final recentProducts = await _controller.loadRecentProducts();

      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          if (_suppliers.isNotEmpty) {
            _selectedSupplier = _suppliers.first['name'] as String;
          }
          _recentProducts = recentProducts;
        });
      }
    } catch (e) {
      NotificationService.showSnackBar("Lỗi tải dữ liệu: $e", color: Colors.red);
    }
=======
    _loadSuppliers();
    _loadSettings();
    _loadRecentProducts();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scannerController.dispose();
    _imeiController.dispose();
    _nameController.dispose();
    _costController.dispose();
<<<<<<< HEAD
=======
    _kpkController.dispose();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    _retailController.dispose();
    _detailController.dispose();
    _quantityController.dispose();
    _modelController.dispose();
    _infoController.dispose();
    _skuController.dispose();
<<<<<<< HEAD

    // Dispose manual input controllers
    typeCtrl.dispose();
    brandCtrl.dispose();
    modelCtrl.dispose();
    capacityCtrl.dispose();
    colorCtrl.dispose();
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
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
<<<<<<< HEAD
    try {
      suppliers = await _controller.getSuppliers();
      setState(() {});
    } catch (e) {
      NotificationService.showSnackBar("Lỗi tải nhà cung cấp: $e", color: Colors.red);
    }
  }

  bool _validateForm() {
    if (typeCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng chọn loại hàng!", color: Colors.red);
      return false;
    }
    if (brandCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập loại!", color: Colors.red);
      return false;
    }
    if (!_isAccessoryOrLinhKien && modelCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập model!", color: Colors.red);
      return false;
    }
    if (!_isAccessoryOrLinhKien && capacityCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập dung lượng!", color: Colors.red);
      return false;
    }
    if (colorCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng nhập màu/thông tin!", color: Colors.red);
      return false;
    }
    if (quantityCtrl.text.isEmpty || int.tryParse(quantityCtrl.text) == null || int.parse(quantityCtrl.text) <= 0) {
      NotificationService.showSnackBar("Vui lòng nhập số lượng hợp lệ!", color: Colors.red);
      return false;
    }
    if (costCtrl.text.isEmpty || int.tryParse(costCtrl.text) == null) {
      NotificationService.showSnackBar("Vui lòng nhập giá nhập hợp lệ!", color: Colors.red);
      return false;
    }
    if (supplierCtrl.text.isEmpty) {
      NotificationService.showSnackBar("Vui lòng chọn nhà cung cấp!", color: Colors.red);
      return false;
    }
    return true;
  }

  Future<void> _saveProduct() async {
    if (!_validateForm()) return;

    setState(() => _saving = true);

    try {
      final productData = {
        'type': typeCtrl.text,
        'brand': brandCtrl.text,
        'model': modelCtrl.text,
        'capacity': capacityCtrl.text,
        'color': colorCtrl.text,
        'condition': conditionCtrl.text,
        'imei': imeiCtrl.text,
        'quantity': int.parse(quantityCtrl.text),
        'cost': int.parse(costCtrl.text) * 1000,
        'price': priceCtrl.text.isNotEmpty ? int.parse(priceCtrl.text) * 1000 : null,
        'supplier': supplierCtrl.text,
        'paymentMethod': selectedPaymentMethod,
        'notes': notesCtrl.text,
        'importDate': selectedDate,
        'importedBy': FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV",
      };

      await _controller.saveProductBatch(productData);

      // Reset form
      _resetForm();

      NotificationService.showSnackBar("Đã lưu sản phẩm thành công!", color: Colors.green);
      HapticFeedback.lightImpact();

      // Refresh recent products
      await _refreshRecentProducts();
    } catch (e) {
      NotificationService.showSnackBar("Lỗi lưu sản phẩm: $e", color: Colors.red);
    } finally {
      setState(() => _saving = false);
    }
  }



  void _resetForm() {
    typeCtrl.clear();
    brandCtrl.clear();
    modelCtrl.clear();
    capacityCtrl.clear();
    colorCtrl.clear();
    conditionCtrl.clear();
    imeiCtrl.clear();
    quantityCtrl.text = '1';
    costCtrl.clear();
    priceCtrl.clear();
    supplierCtrl.clear();
    notesCtrl.clear();
    selectedDate = DateTime.now();
    selectedPaymentMethod = 'Tiền mặt';

    // Reset change tracking
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
=======
    final suppliers = await db.getSuppliers();
    if (mounted) {
      setState(() {
        _suppliers = suppliers;
        if (_suppliers.isNotEmpty) {
          _selectedSupplier = _suppliers.first['name'] as String;
        }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
      });
    }
  }

<<<<<<< HEAD
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
=======
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
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _selectedGroup = template['group'];
      _selectedType = template['type'];
      _costController.text = (template['cost'] ~/ 1000).toString();
<<<<<<< HEAD
=======
      _kpkController.text = (template['kpk'] ~/ 1000).toString();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
      final generatedSKU = await _controller.generateSKU(
        group: _selectedGroup,
        model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
        info: _infoController.text.trim().isNotEmpty ? _infoController.text.trim() : null,
=======
      final generatedSKU = await SKUGenerator.generateSKU(
        nhom: _selectedGroup,
        model: _modelController.text.trim().isNotEmpty ? _modelController.text.trim() : null,
        thongtin: _infoController.text.trim().isNotEmpty ? _infoController.text.trim() : null,
        dbHelper: db,
        firestoreService: null,
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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

<<<<<<< HEAD



=======
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
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

  Future<void> _saveBatch() async {
    if (_batchItems.isEmpty) return;

    setState(() => _isSaving = true);

    try {
<<<<<<< HEAD
      // Parallel processing for better performance
      await _controller.saveBatchProducts(_batchItems);

      setState(() => _batchItems.clear());
      NotificationService.showSnackBar("Đã nhập kho ${_batchItems.length} sản phẩm thành công!", color: Colors.green);
      HapticFeedback.lightImpact();

      // Parallel refresh
      await _refreshRecentProducts();

      if (mounted) Navigator.of(context).pop();
=======
      for (final productData in _batchItems) {
        await _saveSingleProduct(productData);
      }

      setState(() => _batchItems.clear());
      NotificationService.showSnackBar("Đã nhập kho ${_batchItems.length} sản phẩm thành công!", color: Colors.green);
      if (mounted) Navigator.of(context).pop();

      // Refresh recent products
      _loadRecentProducts();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    } catch (e) {
      NotificationService.showSnackBar("Lỗi khi nhập batch: $e", color: Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

<<<<<<< HEAD
  Future<void> _refreshRecentProducts() async {
    try {
      final recentProducts = await _controller.loadRecentProducts();
      if (mounted) {
        setState(() => _recentProducts = recentProducts);
      }
    } catch (e) {
      // Silent fail for refresh
    }
  }

=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  int _parsePrice(String text) {
    final cleaned = text.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), '');
    final value = int.tryParse(cleaned) ?? 0;
    return (value > 0 && value < 100000) ? value * 1000 : value;
  }

  void _clearForm() {
    _imeiController.clear();
    _nameController.clear();
    _costController.clear();
<<<<<<< HEAD
=======
    _kpkController.clear();
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
        automaticallyImplyLeading: true,
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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
<<<<<<< HEAD
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
=======
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
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
                    ),
                  ),
                ],
              ),
<<<<<<< HEAD
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
=======
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
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
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