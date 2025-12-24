import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/debounced_search_field.dart';

class CreateSaleView extends StatefulWidget {
  const CreateSaleView({super.key});
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

  List<Product> _allInStock = [];
  List<Product> _filteredInStock = []; 
  List<Map<String, dynamic>> _selectedItems = []; 
  List<Map<String, dynamic>> _suggestCustomers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    downPaymentCtrl.addListener(_calculateInstallment);
  }

  @override
  void dispose() {
    nameCtrl.dispose(); phoneCtrl.dispose(); addressCtrl.dispose();
    priceCtrl.dispose(); noteCtrl.dispose(); searchProdCtrl.dispose();
    downPaymentCtrl.dispose(); loanAmountCtrl.dispose(); bankCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prods = await db.getInStockProducts();
    final suggests = await db.getCustomerSuggestions();
    if (!mounted) return;
    setState(() { _allInStock = prods; _filteredInStock = prods; _suggestCustomers = suggests; _isLoading = false; });
  }

  void _calculateInstallment() {
    int total = _parseCurrency(priceCtrl.text);
    int down = _parseCurrency(downPaymentCtrl.text);
    if (down > 0 && down < 100000) down *= 1000;
    int loan = total - down;
    loanAmountCtrl.text = _formatCurrency(loan > 0 ? loan : 0);
  }

  void _calculateTotal() {
    int total = _selectedItems.fold(0, (sum, item) => sum + (item['isGift'] ? 0 : (item['sellPrice'] as int)));
    if (_autoCalcTotal) {
      priceCtrl.text = _formatCurrency(total);
      _calculateInstallment();
    }
  }

  int _parseCurrency(String text) => int.tryParse(text.replaceAll('.', '')) ?? 0;
  String _formatCurrency(int n) => NumberFormat('#,###').format(n).replaceAll(',', '.');

  void _addItem(Product p) {
    if (_selectedItems.any((item) => item['product'].id == p.id)) return;
    setState(() { 
      _selectedItems.add({'product': p, 'isGift': false, 'sellPrice': p.price}); 
      _calculateTotal(); 
      searchProdCtrl.clear(); 
      _filteredInStock = _allInStock;
    });
  }

  Future<void> _processSale() async {
    if (_isSaving) return;
    if (_selectedItems.isEmpty) { NotificationService.showSnackBar("VUI LÒNG CHỌN SẢN PHẨM", color: Colors.red); return; }
    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) { NotificationService.showSnackBar("NHẬP ĐỦ THÔNG TIN KHÁCH", color: Colors.red); return; }

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final String uniqueId = "sale_${now}_${phoneCtrl.text}";
      String seller = FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NHÂN VIÊN";

      final sale = SaleOrder(
        firestoreId: uniqueId,
        customerName: nameCtrl.text.trim().toUpperCase(),
        phone: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim().toUpperCase(),
        productNames: _selectedItems.map((e) => (e['product'] as Product).name).join(', '),
        productImeis: _selectedItems.map((e) => (e['product'] as Product).imei ?? "PK").join(', '),
        totalPrice: _parseCurrency(priceCtrl.text),
        totalCost: _selectedItems.fold(0, (sum, item) => sum + (item['product'] as Product).cost),
        paymentMethod: _paymentMethod,
        sellerName: seller,
        soldAt: now,
        isInstallment: _isInstallment,
        downPayment: _parseCurrency(downPaymentCtrl.text) < 100000 ? _parseCurrency(downPaymentCtrl.text) * 1000 : _parseCurrency(downPaymentCtrl.text),
        loanAmount: _parseCurrency(loanAmountCtrl.text),
        bankName: bankCtrl.text.toUpperCase(),
        notes: noteCtrl.text,
        warranty: _saleWarranty,
      );

      for (var item in _selectedItems) {
        final p = item['product'] as Product;
        await db.updateProductStatus(p.id!, 0); 
        await db.deductProductQuantity(p.id!, 1);
        p.status = 0;
        p.quantity = 0;
        await FirestoreService.updateProductCloud(p);
      }

      await db.upsertSale(sale); 
      await FirestoreService.addSale(sale);

      NotificationService.showSnackBar("ĐÃ BÁN HÀNG & TRỪ KHO THÀNH CÔNG!", color: Colors.green);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("TẠO ĐƠN BÁN HÀNG", style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("1. CHỌN SẢN PHẨM TRONG KHO"),
            DebouncedSearchField(controller: searchProdCtrl, hint: "Tìm máy hoặc IMEI...", onSearch: (v) => setState(() => _filteredInStock = _allInStock.where((p) => p.name.contains(v.toUpperCase()) || (p.imei ?? "").contains(v)).toList())),
            if (searchProdCtrl.text.isNotEmpty) _buildSearchResults(),
            _buildSelectedItemsList(),
            const SizedBox(height: 20),
            _sectionTitle("2. THÔNG TIN KHÁCH HÀNG"),
            ValidatedTextField(controller: nameCtrl, label: "TÊN KHÁCH HÀNG", icon: Icons.person),
            _buildCustomerSuggestions(),
            ValidatedTextField(controller: phoneCtrl, label: "SỐ ĐIỆN THOẠI", icon: Icons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _sectionTitle("3. THANH TOÁN & TRẢ GÓP"),
            _buildPaymentSection(),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isSaving ? null : _processSale, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("HOÀN TẤT & TRỪ KHO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("TỔNG TIỀN:", style: TextStyle(fontWeight: FontWeight.bold)), Text("${priceCtrl.text} Đ", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red))]),
          const SizedBox(height: 15),
          Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ", "TRẢ GÓP (NH)"].map((e) => ChoiceChip(label: Text(e), selected: _paymentMethod == e, onSelected: (v) => setState(() { _paymentMethod = e; _isInstallment = (e == "TRẢ GÓP (NH)"); }))).toList()),
          if (_isInstallment) ...[
            const Divider(height: 30),
            _moneyInput(downPaymentCtrl, "KHÁCH TRẢ TRƯỚC (k)", Colors.orange),
            const SizedBox(height: 10),
            _moneyInput(loanAmountCtrl, "NGÂN HÀNG CHO VAY", Colors.blueGrey, enabled: false),
            const SizedBox(height: 10),
            TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: "TÊN NGÂN HÀNG / CÔNG TY TC", border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: ["FE", "HOME", "MIRAE", "HD", "F83", "T86"].map((b) => ActionChip(label: Text(b), onPressed: () => setState(() => bankCtrl.text = b))).toList()),
          ],
          const Divider(height: 30),
          DropdownButtonFormField<String>(value: _saleWarranty, decoration: const InputDecoration(labelText: "CHỌN THỜI GIAN BẢO HÀNH"), items: ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _saleWarranty = v ?? "KO BH"))
        ],
      ),
    );
  }

  Widget _moneyInput(TextEditingController ctrl, String label, Color color, {bool enabled = true}) {
    return TextField(controller: ctrl, enabled: enabled, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: label, border: OutlineInputBorder(), prefixIcon: Icon(Icons.money, color: color), filled: !enabled, fillColor: enabled ? null : Colors.grey.shade50), onChanged: (_) => _calculateInstallment());
  }

  Widget _sectionTitle(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)));

  Widget _buildSearchResults() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ListView.builder(shrinkWrap: true, itemCount: _filteredInStock.length, itemBuilder: (ctx, i) {
        final p = _filteredInStock[i];
        return ListTile(
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("IMEI: ${p.imei ?? 'PK'}"),
              Text("${p.capacity ?? ''} - Tồn: ${p.quantity}", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
              Text("Giá: ${NumberFormat('#,###').format(p.price)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.add_circle, color: Colors.green, size: 30), 
          onTap: () => _addItem(p)
        );
      }),
    );
  }

  Widget _buildSelectedItemsList() {
    return Column(children: _selectedItems.map((item) {
      final p = item['product'] as Product;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text("IMEI: ${p.imei ?? 'PK'}\nGiá bán: ${NumberFormat('#,###').format(item['sellPrice'])}"), 
          trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { _selectedItems.remove(item); _calculateTotal(); }); }),
        )
      );
    }).toList());
  }

  Widget _buildCustomerSuggestions() {
    if (_suggestCustomers.isEmpty) return const SizedBox();
    return SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _suggestCustomers.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(_suggestCustomers[i]['customerName']), onPressed: () { nameCtrl.text = _suggestCustomers[i]['customerName']; phoneCtrl.text = _suggestCustomers[i]['phone']; setState(() => _suggestCustomers = []); }))));
  }
}
