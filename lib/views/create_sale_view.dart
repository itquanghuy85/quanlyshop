import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../services/notification_service.dart';
import '../services/audit_service.dart';
import '../services/user_service.dart';
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
  final settlementNoteCtrl = TextEditingController();
  final settlementCodeCtrl = TextEditingController();
  int? _settlementPlannedAt;
  String _paymentMethod = "TIỀN MẶT";
  final List<String> warrantyOptions = ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"];
  String _saleWarranty = "KO BH";
  bool _autoCalcTotal = true;

  List<Product> _allInStock = [];
  List<Product> _filteredInStock = []; 
  List<Map<String, dynamic>> _selectedItems = []; 
  List<Map<String, dynamic>> _suggestCustomers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Theme colors cho màn hình tạo đơn bán hàng
  final Color _primaryColor = Colors.indigo; // Màu chính cho đơn bán hàng
  final Color _accentColor = Colors.indigo.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _loadData();
    downPaymentCtrl.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
    priceCtrl.dispose();
    noteCtrl.dispose();
    searchProdCtrl.dispose();
    downPaymentCtrl.dispose();
    loanAmountCtrl.dispose();
    bankCtrl.dispose();
    settlementNoteCtrl.dispose();
    settlementCodeCtrl.dispose();
    super.dispose();
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
      priceCtrl.text = _formatCurrency(total);
    }
    int down = _parseCurrency(downPaymentCtrl.text);
    int base = _autoCalcTotal ? total : _parseCurrency(priceCtrl.text);
    int loan = base - down;
    loanAmountCtrl.text = (loan > 0 ? _formatCurrency(loan) : '0');
  }

  int _parseCurrency(String text) {
    final cleaned = text.replaceAll('.', '');
    return int.tryParse(cleaned) ?? 0;
  }

  String _formatCurrency(int number) {
    if (number == 0) return '0';

    final String numberStr = number.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = numberStr.length - 1, count = 0; i >= 0; i--, count++) {
      buffer.write(numberStr[i]);
      if (count % 3 == 2 && i > 0) {
        buffer.write('.');
      }
    }

    return buffer.toString().split('').reversed.join('');
  }

  Future<void> _processSale() async {
    // Validate required fields
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("VUI LÒNG CHỌN ÍT NHẤT MỘT SẢN PHẨM!")));
      return;
    }

    final nameError = UserService.validateName(nameCtrl.text);
    final phoneError = UserService.validatePhone(phoneCtrl.text);
    final addressError = UserService.validateAddress(addressCtrl.text);

    if (nameError != null || phoneError != null || addressError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(nameError ?? phoneError ?? addressError!),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate price
    final priceText = priceCtrl.text.replaceAll('.', '');
    final price = int.tryParse(priceText);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GIÁ BÁN PHẢI LỚN HƠN 0!")));
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
      totalPrice: price,
      totalCost: _selectedItems.fold(0, (sum, item) => sum + (item['product'] as Product).cost),
      paymentMethod: _paymentMethod,
      sellerName: seller,
      soldAt: DateTime.now().millisecondsSinceEpoch,
      isInstallment: _paymentMethod == "TRẢ GÓP (NH)" ? true : _isInstallment,
      downPayment: _parseCurrency(downPaymentCtrl.text),
      loanAmount: _parseCurrency(loanAmountCtrl.text) * 1000,
      bankName: bankCtrl.text,
      settlementPlannedAt: _paymentMethod == "TRẢ GÓP (NH)" ? _settlementPlannedAt : null,
      settlementAmount: _paymentMethod == "TRẢ GÓP (NH)" ? _parseCurrency(loanAmountCtrl.text) : 0,
      settlementNote: _paymentMethod == "TRẢ GÓP (NH)" ? settlementNoteCtrl.text : null,
      settlementCode: _paymentMethod == "TRẢ GÓP (NH)" ? settlementCodeCtrl.text : null,
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
    AuditService.logAction(
      action: 'CREATE_SALE',
      entityType: 'sale',
      entityId: sale.firestoreId ?? "sale_${sale.soldAt}",
      summary: "${sale.customerName} - ${NumberFormat('#,###').format(sale.totalPrice)}",
      payload: {
        'paymentMethod': sale.paymentMethod,
        'installment': sale.isInstallment,
        'downPayment': sale.downPayment,
      },
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("TẠO ĐƠN BÁN HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
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
                          child: DebouncedSearchField(
                            controller: searchProdCtrl,
                            hint: "Gõ tên máy, màu hoặc IMEI để tìm...",
                            onSearch: (value) => _filterProducts(value),
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
                    ValidatedTextField(
                      controller: nameCtrl,
                      label: "TÊN KHÁCH HÀNG",
                      icon: Icons.person,
                      required: true,
                      inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
                    ),
                    _buildCustomerSuggestions(),
                    ValidatedTextField(
                      controller: phoneCtrl,
                      label: "SỐ ĐIỆN THOẠI",
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                      required: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                    ),
                    ValidatedTextField(
                      controller: addressCtrl,
                      label: "ĐỊA CHỈ",
                      icon: Icons.location_on,
                      required: true,
                      inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
                    ),
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
                    ValidatedTextField(
                      controller: noteCtrl,
                      label: "GHI CHÚ ĐƠN HÀNG",
                      hint: "Nhập ghi chú nếu có...",
                      maxLength: 200,
                    ),
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
              Text("${_formatCurrency(_parseCurrency(priceCtrl.text))} Đ", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _payChip("TIỀN MẶT"),
                _payChip("CHUYỂN KHOẢN"),
                _payChip("CÔNG NỢ"),
                _payChip("TRẢ GÓP (NH)"),
              ],
            ),
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
          ValidatedTextField(
            controller: priceCtrl,
            label: _autoCalcTotal ? "TỔNG TIỀN (TỰ TÍNH)" : "TỔNG TIỀN (NHẬP TAY)",
            keyboardType: TextInputType.number,
            enabled: !_autoCalcTotal,
            inputFormatters: [CurrencyInputFormatter()],
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
            ValidatedTextField(
              controller: bankCtrl,
              label: "TÊN NGÂN HÀNG",
              icon: Icons.account_balance,
              inputFormatters: [TextInputFormatter.withFunction((oldValue, newValue) => TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection))],
            ),
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
                  _bankChip("F83", Colors.teal),
                  _bankChip("F88", Colors.purple),
                ],
              ),
            ),
            if (_paymentMethod == "TRẢ GÓP (NH)") ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.04), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("LỊCH TẤT TOÁN NGÂN HÀNG", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ElevatedButton.icon(onPressed: _pickSettlementDate, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), icon: const Icon(Icons.event_available, size: 18), label: Text(_settlementPlannedAt == null ? "Chọn ngày dự kiến" : DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(_settlementPlannedAt!))))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: settlementCodeCtrl, decoration: const InputDecoration(labelText: "Mã hồ sơ NH", border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: settlementNoteCtrl, decoration: const InputDecoration(labelText: "Ghi chú tất toán", border: OutlineInputBorder()), maxLines: 2),
                  const SizedBox(height: 6),
                  const Text("Down payment được tính vào tiền mặt hôm nay, phần còn lại sẽ vào quỹ khi bấm \"Nhận tiền từ NH\".", style: TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
              ),
            ],
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
            subtitle: Text(
              item['isGift']
                  ? "TẶNG KÈM MIỄN PHÍ"
                  : "Giá: ${NumberFormat('#,###').format(item['sellPrice'])} đ",
              style: TextStyle(color: item['isGift'] ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Tặng", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Switch(value: item['isGift'], activeColor: Colors.green, onChanged: (v) { setState(() { item['isGift'] = v; _calculateTotal(); }); }),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  tooltip: "Đổi giá bán",
                  onPressed: item['isGift'] ? null : () => _editItemPrice(item),
                ),
                IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () { setState(() { _selectedItems.remove(item); _calculateTotal(); }); }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _editItemPrice(Map<String, dynamic> item) async {
    final ctrl = TextEditingController(text: ((item['sellPrice'] as int) / 1000).toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("NHẬP GIÁ BÁN (Đơn vị: .000đ)"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: "Đ ", suffixText: ".000"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("LƯU")),
        ],
      ),
    );

    if (ok == true) {
      final entered = int.tryParse(ctrl.text) ?? 0;
      setState(() {
        item['sellPrice'] = entered * 1000;
        _calculateTotal();
      });
    }
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
      inputFormatters: [CurrencyInputFormatter()],
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), 
      decoration: InputDecoration(
        labelText: hint, 
        suffixText: " đ", 
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

  Future<void> _pickSettlementDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _settlementPlannedAt != null ? DateTime.fromMillisecondsSinceEpoch(_settlementPlannedAt!) : now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _settlementPlannedAt = picked.millisecondsSinceEpoch);
    }
  }

  Widget _payChip(String label) {
    final isSelected = _paymentMethod == label;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey.shade200,
      onSelected: (_) => setState(() {
        _paymentMethod = label;
        if (label == "TRẢ GÓP (NH)") {
          _isInstallment = true;
        }
      }),
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
    if (!mounted) return;
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

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Allow only numbers
    final regEx = RegExp(r'^\d+$');
    if (!regEx.hasMatch(newValue.text)) {
      return oldValue;
    }

    // Format with dots every 3 digits
    final number = int.tryParse(newValue.text) ?? 0;
    final formatted = _formatCurrency(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCurrency(int number) {
    if (number == 0) return '0';

    final String numberStr = number.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = numberStr.length - 1, count = 0; i >= 0; i--, count++) {
      buffer.write(numberStr[i]);
      if ((count + 1) % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }

    return buffer.toString().split('').reversed.join('');
  }
}
