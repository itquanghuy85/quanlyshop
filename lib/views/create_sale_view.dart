import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../services/notification_service.dart';

class CreateSaleView extends StatefulWidget {
  final String role;
  const CreateSaleView({super.key, this.role = 'user'});

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
  final List<String> warrantyOptions = ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"];
  String _saleWarranty = "KO BH";
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
    downPaymentCtrl.addListener(_calculateTotal);
  }

  Future<void> _loadData() async {
    final prods = await db.getInStockProducts();
    final suggests = await db.getCustomerSuggestions();
    setState(() {
      _allInStock = prods;
      _filteredInStock = prods;
      _suggestCustomers = suggests;
      _isLoading = false;
    });
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredInStock = _allInStock.where((p) {
        return p.name.toLowerCase().contains(query.toLowerCase()) || 
               (p.imei ?? "").toLowerCase().contains(query.toLowerCase()) ||
               (p.color ?? "").toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _addItem(Product p) {
    if (_selectedItems.any((item) => item['product'].id == p.id)) return;
    setState(() {
      _selectedItems.add({
        'product': p,
        'isGift': false,
        'sellPrice': p.price,
      });
      _calculateTotal();
      searchProdCtrl.clear();
      _filterProducts("");
    });
  }

  void _calculateTotal() {
    int total = _selectedItems.fold(0, (sum, item) => sum + (item['isGift'] ? 0 : (item['sellPrice'] as int)));
    if (_autoCalcTotal) {
      priceCtrl.text = (total / 1000).toStringAsFixed(0);
    }
    int down = (int.tryParse(downPaymentCtrl.text) ?? 0) * 1000;
    int base = _autoCalcTotal ? total : (int.tryParse(priceCtrl.text) ?? 0) * 1000;
    int loan = base - down;
    loanAmountCtrl.text = (loan > 0 ? loan / 1000 : 0).toStringAsFixed(0);
  }

  Future<void> _processSale() async {
    if (_selectedItems.isEmpty || nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("VUI LÒNG NHẬP ĐỦ THÔNG TIN KHÁCH VÀ CHỌN HÀNG!")));
      return;
    }

    setState(() => _isSaving = true);
    String seller = FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase() ?? "NHÂN VIÊN";

    final sale = SaleOrder(
      customerName: nameCtrl.text.trim().toUpperCase(),
      phone: phoneCtrl.text.trim(),
      address: addressCtrl.text.trim().toUpperCase(),
      productNames: _selectedItems.map((e) => (e['product'] as Product).name).join(', '),
      productImeis: _selectedItems.map((e) => (e['product'] as Product).imei ?? "PK").join(', '),
      totalPrice: (int.tryParse(priceCtrl.text) ?? 0) * 1000,
      totalCost: _selectedItems.fold(0, (sum, item) => sum + (item['product'] as Product).cost),
      sellerName: seller,
      soldAt: DateTime.now().millisecondsSinceEpoch,
      isInstallment: _isInstallment,
      downPayment: (int.tryParse(downPaymentCtrl.text) ?? 0) * 1000,
      loanAmount: (int.tryParse(loanAmountCtrl.text) ?? 0) * 1000,
      bankName: bankCtrl.text,
      notes: noteCtrl.text,
      warranty: _saleWarranty,
    );

    // 1. Lưu đơn bán hàng
    await db.insertSale(sale);

    // 2. LOGIC TRỪ KHO QUAN TRỌNG
    for (var item in _selectedItems) {
      final p = item['product'] as Product;
      if (p.type == 'PHONE') {
        // Đối với điện thoại: Đánh dấu ĐÃ BÁN (status = 0) và trừ hết số lượng
        await db.updateProductStatus(p.id!, 0); 
      } else {
        // Đối với phụ kiện: Trừ đi 1 món trong kho
        await db.deductProductQuantity(p.id!, 1);
      }
    }

    await NotificationService.sendCloudNotification(title: "BÁN HÀNG THÀNH CÔNG", body: "NHÂN VIÊN $seller ĐÃ BÁN CHO ${sale.customerName}");
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("TẠO ĐƠN BÁN HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _sectionTitle("1. TÌM & CHỌN SẢN PHẨM"),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchProdCtrl,
                            onChanged: _filterProducts,
                            style: const TextStyle(fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "Gõ tên máy, màu hoặc IMEI để tìm...",
                              prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                              filled: true, fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (searchProdCtrl.text.isNotEmpty)
                      _buildSearchResults(),
                    const SizedBox(height: 15),
                    _buildSelectedItemsList(),
                    
                    const SizedBox(height: 25),
                    _sectionTitle("2. THÔNG TIN KHÁCH HÀNG"),
                    _input(nameCtrl, "TÊN KHÁCH HÀNG", icon: Icons.person, caps: true),
                    _buildCustomerSuggestions(),
                    _input(phoneCtrl, "SỐ ĐIỆN THOẠI", icon: Icons.phone, type: TextInputType.phone),
                    _input(addressCtrl, "ĐỊA CHỈ", icon: Icons.location_on, caps: true),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _addCustomerToContactsFromSale,
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text("THÊM VÀO DANH BẠ", style: TextStyle(fontSize: 12)),
                      ),
                    ),

                    const SizedBox(height: 25),
                    _sectionTitle("3. THANH TOÁN (TỰ TÍNH)"),
                    _buildPaymentSection(),
                    
                    const SizedBox(height: 10),
                    _input(noteCtrl, "GHI CHÚ ĐƠN HÀNG"),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              _buildBottomButton(),
            ],
          ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredInStock.length,
        itemBuilder: (ctx, i) {
          final p = _filteredInStock[i];
          return ListTile(
            leading: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: Colors.blueAccent),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text("Màu: ${p.color ?? 'N/A'} | IMEI: ${p.imei ?? 'PK'}\nGiá: ${NumberFormat('#,###').format(p.price)} đ | SL còn: ${p.quantity}"),
            trailing: Icon(p.quantity > 0 ? Icons.add_circle : Icons.remove_circle, color: p.quantity > 0 ? Colors.green : Colors.grey),
            onTap: p.quantity > 0 ? () => _addItem(p) : null,
          );
        },
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blueAccent.withOpacity(0.1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TỔNG THANH TOÁN:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text("${NumberFormat('#,###').format((int.tryParse(priceCtrl.text) ?? 0) * 1000)} Đ", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("TỰ TÍNH TỔNG", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Switch(value: _autoCalcTotal, activeColor: Colors.blueAccent, onChanged: (v) { setState(() { _autoCalcTotal = v; }); _calculateTotal(); }),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: priceCtrl,
            enabled: !_autoCalcTotal,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(prefixText: "Đ ", suffixText: ".000", labelText: _autoCalcTotal ? "Tổng tiền (tự tính)" : "Tổng tiền (nhập tay)"),
            onChanged: (_) => _calculateTotal(),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text("BÁN MÁY TRẢ GÓP", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            value: _isInstallment,
            activeColor: Colors.blueAccent,
            onChanged: (v) => setState(() => _isInstallment = v),
          ),
          if (_isInstallment) ...[
            _moneyInput(downPaymentCtrl, "KHÁCH TRẢ TRƯỚC"),
            const SizedBox(height: 10),
            _moneyInput(loanAmountCtrl, "NGÂN HÀNG CHO VAY", enabled: false),
            const SizedBox(height: 10),
            _input(bankCtrl, "TÊN NGÂN HÀNG", icon: Icons.account_balance, caps: true),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _bankChip("FE CREDIT", Colors.redAccent),
                  _bankChip("HOME CREDIT", Colors.deepOrange),
                  _bankChip("MIRAE", Colors.blueAccent),
                  _bankChip("HD SAISON", Colors.amber[800] ?? Colors.amber),
                  _bankChip("MBBANK", Colors.indigo),
                  _bankChip("VPBANK", Colors.green),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _saleWarranty,
            decoration: const InputDecoration(labelText: "Bảo hành"),
            items: warrantyOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _saleWarranty = v ?? "KO BH"),
          )
        ],
      ),
    );
  }

  Widget _buildSelectedItemsList() {
    return Column(
      children: _selectedItems.map((item) {
        final p = item['product'] as Product;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.black12)),
          child: ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(item['isGift'] ? "TẶNG KÈM MIỄN PHÍ" : "Giá: ${NumberFormat('#,###').format(item['sellPrice'])} đ", style: TextStyle(color: item['isGift'] ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Tặng", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Switch(value: item['isGift'], activeColor: Colors.green, onChanged: (v) { setState(() { item['isGift'] = v; _calculateTotal(); }); }),
                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () { setState(() { _selectedItems.remove(item); _calculateTotal(); }); }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(height: 60, width: double.infinity, child: ElevatedButton.icon(onPressed: _isSaving ? null : _processSale, icon: const Icon(Icons.check_circle, size: 28), label: Text(_isSaving ? "ĐANG LƯU..." : "HOÀN TẤT GIAO DỊCH", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
    );
  }

  Widget _buildCustomerSuggestions() {
    if (_suggestCustomers.isEmpty) return const SizedBox();
    return SizedBox(height: 45, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _suggestCustomers.length, itemBuilder: (ctx, i) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(_suggestCustomers[i]['customerName'], style: const TextStyle(fontSize: 14)), onPressed: () { nameCtrl.text = _suggestCustomers[i]['customerName']; phoneCtrl.text = _suggestCustomers[i]['phone']; addressCtrl.text = _suggestCustomers[i]['address'] ?? ""; setState(() => _suggestCustomers = []); } ))));
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)));
  
  Widget _input(TextEditingController ctrl, String hint, {IconData? icon, TextInputType type = TextInputType.text, bool caps = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: TextField(
      controller: ctrl, 
      keyboardType: type, 
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500), 
      textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none, 
      decoration: InputDecoration(
        labelText: hint, 
        prefixIcon: icon != null ? Icon(icon, size: 24) : null, 
        border: const OutlineInputBorder(), 
        contentPadding: const EdgeInsets.all(15)
      )
    ),
  );

  Widget _moneyInput(TextEditingController ctrl, String hint, {bool enabled = true}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: TextField(
      controller: ctrl, 
      enabled: enabled, 
      keyboardType: TextInputType.number, 
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), 
      decoration: InputDecoration(
        labelText: hint, 
        suffixText: " .000 Đ", 
        border: const OutlineInputBorder(), 
        filled: !enabled, 
        fillColor: !enabled ? Colors.grey[100] : null
      )
    ),
  );

  Widget _bankChip(String name, Color color) {
    return ActionChip(
      avatar: CircleAvatar(backgroundColor: color, child: const Icon(Icons.account_balance, size: 14, color: Colors.white)),
      label: Text(name, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        bankCtrl.text = name;
      },
    );
  }

  Future<void> _addCustomerToContactsFromSale() async {
    final name = nameCtrl.text.trim().toUpperCase();
    final phone = phoneCtrl.text.trim();
    final address = addressCtrl.text.trim().toUpperCase();

    if (phone.isEmpty || name.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("NHẬP ĐỦ TÊN, SĐT VÀ ĐỊA CHỈ TRƯỚC KHI LƯU DANH BẠ")),
      );
      return;
    }

    final existing = await db.getCustomerByPhone(phone);
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("KHÁCH HÀNG NÀY ĐÃ CÓ TRONG DANH BẠ")),
      );
      return;
    }

    await db.insertCustomer({
      'name': name,
      'phone': phone,
      'address': address,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ĐÃ THÊM KHÁCH HÀNG VÀO DANH BẠ")),
    );
  }
}
