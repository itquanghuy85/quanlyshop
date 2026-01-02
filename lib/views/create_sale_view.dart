import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
<<<<<<< HEAD
import '../services/user_service.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/debounced_search_field.dart';
import '../widgets/currency_text_field.dart';
import 'supplier_view.dart';
import 'stock_in_view.dart'; 
=======
import '../widgets/validated_text_field.dart';
import '../widgets/debounced_search_field.dart';
import '../widgets/currency_text_field.dart';
import 'supplier_view.dart'; 
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

class CreateSaleView extends StatefulWidget {
  final Product? preSelectedProduct; 
  
  const CreateSaleView({super.key, this.preSelectedProduct});
  @override
  State<CreateSaleView> createState() => _CreateSaleViewState();
}

class _CreateSaleViewState extends State<CreateSaleView> {
  final db = DBHelper();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final priceCtrl = TextEditingController(text: "0"); 
  final noteCtrl = TextEditingController();
  final searchProdCtrl = TextEditingController();
  
  bool _isInstallment = false;
  final downPaymentCtrl = TextEditingController(text: "0");
  final loanAmountCtrl = TextEditingController(text: "0");
  final bankCtrl = TextEditingController();
  
  String _paymentMethod = "TIỀN MẶT";
  String _saleWarranty = "12 THÁNG";
  bool _autoCalcTotal = true; 

<<<<<<< HEAD
  List<Map<String, dynamic>> _selectedItems = []; 
  List<Map<String, dynamic>> _suggestCustomers = [];
  List<Product> _allInStock = [];
  List<Product> _filteredInStock = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasPermission = false;

  // Focus management cho IMEI fields
  final Map<String, FocusNode> _imeiFocusNodes = {};
  final Map<String, TextEditingController> _imeiControllers = {};
=======
  List<Product> _allInStock = [];
  List<Product> _filteredInStock = []; 
  final List<Map<String, dynamic>> _selectedItems = []; 
  List<Map<String, dynamic>> _suggestCustomers = [];
  bool _isLoading = true;
  bool _isSaving = false;
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _checkPermission();
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    _loadData();
    downPaymentCtrl.addListener(_calculateInstallment);
  }

<<<<<<< HEAD
  Future<void> _checkPermission() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _hasPermission = perms['allowViewSales'] ?? false);
  }

=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  @override
  void dispose() {
    nameCtrl.dispose(); phoneCtrl.dispose(); addressCtrl.dispose();
    priceCtrl.dispose(); noteCtrl.dispose(); searchProdCtrl.dispose();
    downPaymentCtrl.dispose(); loanAmountCtrl.dispose(); bankCtrl.dispose();
<<<<<<< HEAD
    
    // Dispose IMEI controllers và focus nodes
    _imeiControllers.forEach((_, controller) => controller.dispose());
    _imeiFocusNodes.forEach((_, focusNode) => focusNode.dispose());
    
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    super.dispose();
  }

  Future<void> _loadData() async {
    final prods = await db.getInStockProducts();
    final suggests = await db.getCustomerSuggestions();
    if (!mounted) return;
    setState(() { _allInStock = prods; _filteredInStock = prods; _suggestCustomers = suggests; _isLoading = false; });
<<<<<<< HEAD
    if (widget.preSelectedProduct != null) { 
      _addProductToSale(widget.preSelectedProduct!); 
    }
=======
    if (widget.preSelectedProduct != null) { _addProductToSale(widget.preSelectedProduct!); }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  void _calculateInstallment() {
    int total = _parseCurrency(priceCtrl.text);
    int down = _parseCurrency(downPaymentCtrl.text);
    if (down > 0 && down < 100000) down *= 1000;
    int loan = total - down;
    loanAmountCtrl.text = _formatCurrency(loan > 0 ? loan : 0);
  }

  void _calculateTotal() {
    if (!_autoCalcTotal) return;
<<<<<<< HEAD
    int total = _selectedItems.fold(0, (sum, item) => sum + (item['isGift'] ? 0 : ((item['sellPrice'] as int) * (item['quantity'] as int))));
=======
    int total = _selectedItems.fold(0, (sum, item) => sum + (item['isGift'] ? 0 : (item['sellPrice'] as int)));
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    priceCtrl.text = _formatCurrency(total);
    _calculateInstallment();
  }

  int _parseCurrency(String s) {
    String digitsOnly = s.replaceAll(RegExp(r'[^0-9]'), '');
    int amount = int.tryParse(digitsOnly) ?? 0;
    if (amount > 0 && amount < 100000) amount *= 1000;
    return amount;
  }

  String _formatCurrency(int amount) => amount == 0 ? '0' : NumberFormat('#,###').format(amount);

  void _addItem(Product p) {
    if (_selectedItems.any((item) => item['product'].id == p.id)) return;
<<<<<<< HEAD
    
    final productId = p.id;
    final imeiController = TextEditingController(text: p.imei ?? '');
    final imeiFocusNode = FocusNode();
    
    setState(() { 
      _selectedItems.add({
        'product': p, 
        'isGift': false, 
        'sellPrice': p.price,
        'quantity': 1,
        'imei': p.imei ?? '',
      }); 
      
      _imeiControllers[productId.toString()] = imeiController;
      _imeiFocusNodes[productId.toString()] = imeiFocusNode;
      
      _calculateTotal(); 
      searchProdCtrl.clear(); 
      _filteredInStock = _allInStock; 
    });
    
    // Tự động focus vào IMEI field sau khi thêm sản phẩm
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _imeiFocusNodes[productId.toString()]?.context != null) {
        FocusScope.of(context).requestFocus(_imeiFocusNodes[productId.toString()]);
      }
    });
=======
    setState(() { _selectedItems.add({'product': p, 'isGift': false, 'sellPrice': p.price}); _calculateTotal(); searchProdCtrl.clear(); _filteredInStock = _allInStock; });
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  void _addProductToSale(Product p) {
    if (_selectedItems.any((item) => item['product'].id == p.id)) return;
<<<<<<< HEAD
    
    final productId = p.id;
    final imeiController = TextEditingController(text: p.imei ?? '');
    final imeiFocusNode = FocusNode();
    
    setState(() { 
      _selectedItems.add({
        'product': p, 
        'isGift': false, 
        'sellPrice': p.price,
        'quantity': 1,
        'imei': p.imei ?? '',
      }); 
      
      _imeiControllers[productId.toString()] = imeiController;
      _imeiFocusNodes[productId.toString()] = imeiFocusNode;
      
      _calculateTotal(); 
    });
    
    // Tự động focus vào IMEI field
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _imeiFocusNodes[productId.toString()]?.context != null) {
        FocusScope.of(context).requestFocus(_imeiFocusNodes[productId.toString()]);
      }
    });
=======
    setState(() { _selectedItems.add({'product': p, 'isGift': false, 'sellPrice': p.price}); _calculateTotal(); });
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  Future<void> _processSale() async {
    if (_isSaving) return;
    if (_selectedItems.isEmpty) { NotificationService.showSnackBar("VUI LÒNG CHỌN SẢN PHẨM", color: Colors.red); return; }
    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) { NotificationService.showSnackBar("NHẬP ĐỦ THÔNG TIN KHÁCH", color: Colors.red); return; }
<<<<<<< HEAD
    
    // Validate phone format
    final phoneError = UserService.validatePhone(phoneCtrl.text.trim());
    if (phoneError != null) { NotificationService.showSnackBar(phoneError, color: Colors.red); return; }
    
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final String uniqueId = "sale_${now}_${phoneCtrl.text}";
      String seller = FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NV";
      int totalPrice = _parseCurrency(priceCtrl.text);
      int paidAmount = _parseCurrency(downPaymentCtrl.text);
      if (paidAmount > 0 && paidAmount < 100000) paidAmount *= 1000;
      if (_paymentMethod != "CÔNG NỢ" && _paymentMethod != "TRẢ GÓP (NH)" && paidAmount == 0) paidAmount = totalPrice;
      
<<<<<<< HEAD
      int totalCost = _selectedItems.fold(0, (sum, item) => sum + ((item['product'] as Product).cost * (item['quantity'] as int)));
      
      // Debug logging
      debugPrint("Sale debug - totalPrice: $totalPrice, totalCost: $totalCost, selectedItems: ${_selectedItems.length}");
      
      // Validate totals
      if (totalPrice <= 0) {
        NotificationService.showSnackBar("TỔNG TIỀN PHẢI LỚN HƠN 0", color: Colors.red);
        setState(() => _isSaving = false);
        return;
      }
      if (totalCost < 0) {
        NotificationService.showSnackBar("TỔNG GIÁ VỐN KHÔNG ĐƯỢC ÂM", color: Colors.red);
        setState(() => _isSaving = false);
        return;
      }
      
      final sale = SaleOrder(
        firestoreId: uniqueId, 
        customerName: nameCtrl.text.trim().toUpperCase(), 
        phone: phoneCtrl.text.trim(), 
        address: addressCtrl.text.trim().toUpperCase(), 
        productNames: _selectedItems.map((e) => "${(e['product'] as Product).name} x${e['quantity']}").join(', '), 
        productImeis: _selectedItems.map((e) {
          final product = e['product'] as Product;
          final quantity = e['quantity'] as int;
          final customImei = e['imei'] as String?;
          if (customImei != null && customImei.isNotEmpty) {
            return customImei;
          }
          // Logic cũ nếu không nhập IMEI tùy chọn
          if (product.type == 'PHONE') {
            return product.imei ?? "NO_IMEI";
          } else {
            return "PKx${quantity}";
          }
        }).join(', '), 
        totalPrice: totalPrice, 
        totalCost: _selectedItems.fold(0, (sum, item) => sum + ((item['product'] as Product).cost * (item['quantity'] as int))), 
        paymentMethod: _paymentMethod, 
        sellerName: seller, 
        soldAt: now, 
        isInstallment: _isInstallment, 
        downPayment: paidAmount, 
        loanAmount: _isInstallment ? _parseCurrency(loanAmountCtrl.text) : 0, 
        bankName: bankCtrl.text.toUpperCase(), 
        notes: noteCtrl.text, 
        warranty: _saleWarranty
      );
      
      if (_paymentMethod == "CÔNG NỢ" || (_paymentMethod != "TRẢ GÓP (NH)" && paidAmount < totalPrice)) {
        await db.insertDebt({'personName': nameCtrl.text.trim().toUpperCase(), 'phone': phoneCtrl.text.trim(), 'totalAmount': totalPrice, 'paidAmount': paidAmount, 'type': "CUSTOMER_OWES", 'status': "ACTIVE", 'createdAt': now, 'note': "Nợ mua máy: ${sale.productNames}", 'linkedId': uniqueId});
      }
      for (var item in _selectedItems) {
        final p = item['product'] as Product;
        final quantity = item['quantity'] as int;
        
        // Chỉ kiểm tra IMEI cho sản phẩm PHONE nếu không nhập IMEI tùy chọn
        final customImei = item['imei'] as String?;
        if (p.type == 'PHONE' && (customImei == null || customImei.isEmpty) && (p.imei == null || p.imei!.isEmpty)) {
          NotificationService.showSnackBar("Không thể bán máy chưa có IMEI: ${p.name}", color: Colors.red);
          setState(() => _isSaving = false);
          return;
        }
        
        // Kiểm tra số lượng tồn kho
        if (p.quantity < quantity) {
          NotificationService.showSnackBar("Không đủ hàng trong kho: ${p.name} (còn ${p.quantity}, cần ${quantity})", color: Colors.red);
          setState(() => _isSaving = false);
          return;
        }
        
        // Cập nhật trạng thái và số lượng
        if (p.type == 'PHONE') {
          // Phone: đánh dấu đã bán (status = 0)
          await db.updateProductStatus(p.id!, 0);
        }
        // Giảm số lượng cho cả PHONE và ACCESSORY
        await db.deductProductQuantity(p.id!, quantity);
        
        // Cập nhật local object
        p.quantity -= quantity;
        if (p.type == 'PHONE') {
          p.status = 0;
        }
        
        // Check for low inventory after stock reduction
        try {
          await NotificationService.checkAndNotifyLowInventory(p.firestoreId ?? p.id.toString(), p.name, p.quantity, 5);
        } catch (e) {
          debugPrint('Failed to check low inventory: $e');
        }
        
        // Sync lên cloud
        await FirestoreService.updateProductCloud(p);
      }
      await db.upsertSale(sale); await FirestoreService.addSale(sale);
      
      // Trigger payment notification if payment is completed
      if (_paymentMethod != "CÔNG NỢ" && !_isInstallment) {
        try {
          await NotificationService.notifyPaymentCompleted(
            sale.firestoreId ?? 'SALE_${sale.soldAt}_${sale.sellerName}',
            totalPrice.toDouble(),
            _paymentMethod
          );
        } catch (e) {
          debugPrint('Failed to send payment notification: $e');
          // Don't fail the sale if notification fails
        }
      }
      
      NotificationService.showSnackBar("ĐÃ BÁN HÀNG THÀNH CÔNG!", color: Colors.green);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { 
      setState(() => _isSaving = false); 
      NotificationService.showSnackBar("LỖI KHI LƯU ĐƠN BÁN: ${e.toString()}", color: Colors.red);
      debugPrint("Sale save error: $e");
    }
=======
      final sale = SaleOrder(firestoreId: uniqueId, customerName: nameCtrl.text.trim().toUpperCase(), phone: phoneCtrl.text.trim(), address: addressCtrl.text.trim().toUpperCase(), productNames: _selectedItems.map((e) => (e['product'] as Product).name).join(', '), productImeis: _selectedItems.map((e) => (e['product'] as Product).imei ?? "PK").join(', '), totalPrice: totalPrice, totalCost: _selectedItems.fold(0, (sum, item) => sum + (item['product'] as Product).cost), paymentMethod: _paymentMethod, sellerName: seller, soldAt: now, isInstallment: _isInstallment, downPayment: paidAmount, loanAmount: _isInstallment ? _parseCurrency(loanAmountCtrl.text) : 0, bankName: bankCtrl.text.toUpperCase(), notes: noteCtrl.text, warranty: _saleWarranty);
      
      if (_paymentMethod == "CÔNG NỢ" || (_paymentMethod != "TRẢ GÓP (NH)" && paidAmount < totalPrice)) {
        await db.insertDebt({'personName': nameCtrl.text.trim().toUpperCase(), 'phone': phoneCtrl.text.trim(), 'totalAmount': totalPrice, 'paidAmount': paidAmount, 'type': "CUSTOMER_OWES", 'status': "unpaid", 'createdAt': now, 'note': "Nợ mua máy: ${sale.productNames}", 'linkedId': uniqueId});
      }
      for (var item in _selectedItems) {
        final p = item['product'] as Product;
        await db.updateProductStatus(p.id!, 0); await db.deductProductQuantity(p.id!, 1);
        p.status = 0; p.quantity = 0; await FirestoreService.updateProductCloud(p);
      }
      await db.upsertSale(sale); await FirestoreService.addSale(sale);
      NotificationService.showSnackBar("ĐÃ BÁN HÀNG THÀNH CÔNG!", color: Colors.green);
      if (mounted) Navigator.pop(context, true);
    } catch (e) { setState(() => _isSaving = false); }
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("TẠO ĐƠN BÁN HÀNG"),
          backgroundColor: Colors.pinkAccent,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            "Bạn không có quyền truy cập tính năng này",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Tooltip(message: "Chọn sản phẩm, nhập thông tin khách và hoàn tất đơn bán.", child: Text("TẠO ĐƠN BÁN HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), 
        backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
=======
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("TẠO ĐƠN BÁN HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
        backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white,
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
        actions: [
          IconButton(onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())); }, icon: const Icon(Icons.business_center_rounded)),
        ],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle("1. CHỌN SẢN PHẨM TRONG KHO"),
          DebouncedSearchField(controller: searchProdCtrl, hint: "Tìm máy hoặc IMEI...", onSearch: (v) => setState(() => _filteredInStock = _allInStock.where((p) => p.name.contains(v.toUpperCase()) || (p.imei ?? "").contains(v)).toList())),
<<<<<<< HEAD
          
          // Hiển thị hướng dẫn nếu kho trống
          if (_allInStock.isEmpty) _buildEmptyStockGuidance(),
          
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
          if (searchProdCtrl.text.isNotEmpty) _buildSearchResults(),
          _buildSelectedItemsList(),
          const SizedBox(height: 20),
          _sectionTitle("2. THÔNG TIN KHÁCH HÀNG"),
          ValidatedTextField(controller: nameCtrl, label: "TÊN KHÁCH HÀNG", icon: Icons.person, uppercase: true),
          _buildCustomerSuggestions(),
          ValidatedTextField(controller: phoneCtrl, label: "SỐ ĐIỆN THOẠI", icon: Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          _sectionTitle("3. THANH TOÁN & BẢO HÀNH"),
          _buildPaymentSection(),
          const SizedBox(height: 30),
<<<<<<< HEAD
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: (_isSaving || _selectedItems.isEmpty) ? null : _processSale, style: ElevatedButton.styleFrom(backgroundColor: _selectedItems.isEmpty ? Colors.grey : Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(_selectedItems.isEmpty ? "CHƯA CHỌN SẢN PHẨM" : "HOÀN TẤT ĐƠN HÀNG", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
=======
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isSaving ? null : _processSale, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("HOÀN TẤT ĐƠN HÀNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
        ]),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TỔNG TIỀN:", style: TextStyle(fontWeight: FontWeight.bold)), Row(children: [IconButton(icon: Icon(_autoCalcTotal ? Icons.lock_outline : Icons.edit, size: 18, color: Colors.blue), onPressed: () => setState(() => _autoCalcTotal = !_autoCalcTotal)), SizedBox(width: 150, child: CurrencyTextField(controller: priceCtrl, label: "", enabled: !_autoCalcTotal, onChanged: (_) { _calculateInstallment(); })), const Text(" Đ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))])]),
        const SizedBox(height: 15),
        Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ", "TRẢ GÓP (NH)"].map((e) => ChoiceChip(label: Text(e, style: const TextStyle(fontSize: 11)), selected: _paymentMethod == e, onSelected: (v) => setState(() { _paymentMethod = e; _isInstallment = (e == "TRẢ GÓP (NH)"); }))).toList()),
        const Divider(height: 30),
        _moneyInput(downPaymentCtrl, _isInstallment ? "KHÁCH TRẢ TRƯỚC (k)" : "SỐ TIỀN THU THỰC TẾ (k)", Colors.orange),
        if (_isInstallment) ...[const SizedBox(height: 10), _moneyInput(loanAmountCtrl, "NGÂN HÀNG CHO VAY", Colors.blueGrey, enabled: false), const SizedBox(height: 10), ValidatedTextField(controller: bankCtrl, label: "TÊN CÔNG TY TÀI CHÍNH", icon: Icons.account_balance, uppercase: true), const SizedBox(height: 8), Wrap(spacing: 8, children: ["FE", "HOME", "MIRAE", "HD", "F83", "T86"].map((b) => ActionChip(label: Text(b, style: const TextStyle(fontSize: 11)), onPressed: () => setState(() => bankCtrl.text = b))).toList())],
        const Divider(height: 30),
        // KHÔI PHỤC TAB BẢO HÀNH: Cho phép chọn bảo hành bất kể trạng thái nợ
        DropdownButtonFormField<String>(
          initialValue: _saleWarranty, 
          decoration: const InputDecoration(labelText: "CHỌN THỜI GIAN BẢO HÀNH", prefixIcon: Icon(Icons.verified_user)), 
          items: ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), 
          onChanged: (v) => setState(() => _saleWarranty = v ?? "KO BH")
        )
      ]),
    );
  }

  Widget _moneyInput(TextEditingController ctrl, String label, Color color, {bool enabled = true, Function()? onChanged}) {
    return CurrencyTextField(controller: ctrl, label: label, icon: Icons.money, enabled: enabled, onChanged: (_) { _calculateInstallment(); if (onChanged != null) onChanged(); });
  }

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)));

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]), 
      child: ListView.builder(shrinkWrap: true, itemCount: _filteredInStock.length, itemBuilder: (ctx, i) { 
        final p = _filteredInStock[i]; 
        return ListTile(
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text("IMEI: ${p.imei ?? 'PK'} - Giá: ${NumberFormat('#,###').format(p.price)}"), 
          // HIỂN THỊ SỐ LƯỢNG TỒN TRONG LIST CHỌN
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
<<<<<<< HEAD
              Icon(p.quantity > 0 ? Icons.add_circle : Icons.warning, color: p.quantity > 0 ? Colors.green : Colors.red),
              Text("Tồn: ${p.quantity}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: p.quantity > 0 ? Colors.orange : Colors.red)),
            ],
          ),
          onTap: () {
            if (p.quantity == 0) {
              NotificationService.showSnackBar(
                "Sản phẩm '${p.name}' chưa có trong kho!\nVui lòng tạo nhà cung cấp và nhập kho trước khi bán.",
                color: Colors.red
              );
              return;
            }
            _addItem(p);
          }
=======
              const Icon(Icons.add_circle, color: Colors.green),
              Text("Tồn: ${p.quantity}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          onTap: () => _addItem(p)
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
        ); 
      })
    );
  }

  Widget _buildSelectedItemsList() {
<<<<<<< HEAD
    return Column(
      children: _selectedItems.map((item) {
        final product = item['product'] as Product;
        final quantity = item['quantity'] as int? ?? 1;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _selectedItems.remove(item);
                          // Dispose IMEI controller và focus node khi xóa sản phẩm
                          final productId = product.id;
                          _imeiControllers[productId.toString()]?.dispose();
                          _imeiFocusNodes[productId.toString()]?.dispose();
                          _imeiControllers.remove(productId.toString());
                          _imeiFocusNodes.remove(productId.toString());
                          _calculateTotal();
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Giá bán: ${NumberFormat('#,###').format(item['sellPrice'])}"),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text("Số lượng: "),
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20),
                      onPressed: () {
                        if (quantity > 1) {
                          setState(() {
                            item['quantity'] = quantity - 1;
                            _calculateTotal();
                          });
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(
                      width: 50,
                      child: TextFormField(
                        initialValue: quantity.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        onChanged: (value) {
                          final newQuantity = int.tryParse(value) ?? 1;
                          setState(() {
                            item['quantity'] = newQuantity;
                            _calculateTotal();
                          });
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      onPressed: () {
                        setState(() {
                          item['quantity'] = quantity + 1;
                          _calculateTotal();
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text("IMEI: "),
                    Expanded(
                      child: TextField(
                        controller: _imeiControllers[product.id.toString()] ?? TextEditingController(text: item['imei'] ?? ''),
                        focusNode: _imeiFocusNodes[product.id.toString()],
                        onChanged: (value) {
                          setState(() {
                            item['imei'] = value.trim();
                          });
                        },
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          hintText: "Nhập IMEI (tùy chọn)",
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
=======
    return Column(children: _selectedItems.map((item) => Card(margin: const EdgeInsets.symmetric(vertical: 4), child: ListTile(title: Text((item['product'] as Product).name), subtitle: Text("Giá bán: ${NumberFormat('#,###').format(item['sellPrice'])}"), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { _selectedItems.remove(item); _calculateTotal(); }); })))).toList());
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
  }

  Widget _buildCustomerSuggestions() {
    if (_suggestCustomers.isEmpty) return const SizedBox();
    return SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _suggestCustomers.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(_suggestCustomers[i]['customerName']), onPressed: () { nameCtrl.text = _suggestCustomers[i]['customerName']; phoneCtrl.text = _suggestCustomers[i]['phone']; setState(() => _suggestCustomers = []); }))));
  }
<<<<<<< HEAD

  Widget _buildEmptyStockGuidance() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'KHO HÀNG TRỐNG',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Shop của bạn chưa có hàng trong kho. Để bán hàng, vui lòng:',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupplierView()),
                    );
                  },
                  icon: const Icon(Icons.business_center, size: 18),
                  label: const Text('TẠO NHÀ CUNG CẤP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StockInView()),
                    );
                  },
                  icon: const Icon(Icons.add_box, size: 18),
                  label: const Text('NHẬP KHO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
=======
>>>>>>> b5bd6ff7fc4a5fad82eac68e9a8c1a891e5415b6
}
