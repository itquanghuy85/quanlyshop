import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';
import 'inventory_check_view.dart';
import 'create_sale_view.dart';
import '../services/firestore_service.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../utils/sku_generator.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});
  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final db = DBHelper();
  List<Product> _products = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  String _searchQuery = "";
  
  final Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _isAdmin = perms['allowViewInventory'] ?? false);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    final data = await db.getInStockProducts();
    final suppliers = await db.getSuppliers();
    if (!mounted) return;
    setState(() { _products = data; _suppliers = suppliers; _isLoading = false; });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA"),
        content: Text("Bạn có chắc chắn muốn xóa ${_selectedIds.length} mặt hàng đã chọn không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("XÓA NGAY", style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        final userName = user?.email?.split('@').first.toUpperCase() ?? "ADMIN";
        for (int id in _selectedIds) {
          final p = _products.firstWhere((element) => element.id == id);
          await db.logAction(userId: user?.uid ?? "0", userName: userName, action: "XÓA KHO", type: "PRODUCT", targetId: p.imei, desc: "Đã xóa ${p.name} (IMEI: ${p.imei})");
          await db.deleteProduct(id);
          if (p.firestoreId != null) await FirestoreService.deleteProduct(p.firestoreId!);
        }
        HapticFeedback.mediumImpact();
        _refresh();
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSelection(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || (p.imei ?? "").contains(_searchQuery)).toList();
    int totalQty = filteredList.length;
    int totalCapital = filteredList.fold(0, (sum, item) => sum + item.cost);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: _isSelectionMode ? Text("ĐÃ CHỌN ${_selectedIds.length}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)) : const Text("QUẢN LÝ KHO TỔNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _isSelectionMode ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); })) : null,
        actions: [
          if (!_isSelectionMode) ...[
            // NÚT BÁN HÀNG NHANH
            IconButton(onPressed: () { HapticFeedback.mediumImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView())).then((_) => _refresh()); }, icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.pinkAccent), tooltip: "Bán hàng nhanh"),
            IconButton(onPressed: () { HapticFeedback.lightImpact(); Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryCheckView())); }, icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2962FF)), tooltip: "Kiểm kho QR"),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())).then((_) => _refresh()), icon: const Icon(Icons.business_center, size: 20), label: const Text("NCC", style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          if (_isSelectionMode) IconButton(onPressed: _deleteSelected, icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28)) else IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: Colors.blue)),
        ],
      ),
      body: Column(
        children: [
          if (!_isSelectionMode) _buildInventorySummary(totalQty, totalCapital),
          _buildSearchBox(),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : filteredList.isEmpty ? _buildEmptyState() : RefreshIndicator(onRefresh: _refresh, child: ListView.builder(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), itemCount: filteredList.length, itemBuilder: (ctx, i) => _buildProfessionalCard(filteredList[i])))),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(onPressed: _showAddProductDialog, label: const Text("NHẬP KHO MỚI", style: TextStyle(fontWeight: FontWeight.bold)), icon: const Icon(Icons.add_box_rounded), backgroundColor: const Color(0xFF2962FF)),
    );
  }

  Widget _buildInventorySummary(int qty, int capital) {
    final fmt = NumberFormat('#,###');
    return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF2962FF)]), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_summaryItem("TỔNG KHO", "$qty", Icons.inventory), Container(width: 1, height: 40, color: Colors.white24), _summaryItem("VỐN TỒN KHO", "${fmt.format(capital)} đ", Icons.account_balance_wallet)]));
  }

  Widget _summaryItem(String label, String val, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Colors.white70, size: 14), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))]);
  }

  Widget _buildSearchBox() {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: "Tìm máy, phụ kiện hoặc IMEI...", prefixIcon: const Icon(Icons.search, color: Color(0xFF2962FF)), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0))));
  }

  Widget _buildProfessionalCard(Product p) {
    final bool isSelected = _selectedIds.contains(p.id);
    final fmt = NumberFormat('#,###');
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? Colors.red : Colors.transparent, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))]), child: ClipRRect(borderRadius: BorderRadius.circular(20), child: InkWell(onLongPress: () { HapticFeedback.heavyImpact(); _toggleSelection(p.id!); }, onTap: () => _isSelectionMode ? _toggleSelection(p.id!) : _showProductDetail(p), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _getBrandColor(p.name).withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(p.type == 'PHONE' ? Icons.phone_iphone : Icons.headset_mic, color: _getBrandColor(p.name), size: 28)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A237E))), const SizedBox(height: 4), Text(p.capacity ?? "Chi tiết trống", style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Row(children: [const Icon(Icons.fingerprint, size: 12, color: Colors.grey), const SizedBox(width: 4), Text(p.imei ?? "N/A", style: const TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 0.5))])])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${fmt.format(p.price)} đ", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text("TỒN: ${p.quantity}", style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)))])])))));
  }

  Color _getBrandColor(String name) {
    String n = name.toUpperCase();
    if (n.startsWith("IP-")) return Colors.blueGrey; // iPhone
    if (n.startsWith("SS-")) return Colors.blue; // Samsung
    if (n.startsWith("PIN-")) return Colors.green; // Pin/Linh kiện
    if (n.startsWith("MH-")) return Colors.orange; // Máy khác
    if (n.startsWith("PK-")) return Colors.purple; // Phụ kiện
    // Fallback cho tên cũ
    if (n.contains("IPHONE")) return Colors.blueGrey;
    if (n.contains("SAMSUNG")) return Colors.blue;
    if (n.contains("OPPO")) return Colors.green;
    if (n.contains("XIAOMI") || n.contains("REDMI")) return Colors.orange;
    return const Color(0xFF2962FF);
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("KHO HÀNG ĐANG TRỐNG", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))]));
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController(); final imeiC = TextEditingController();
    final costC = TextEditingController(); final kpkPriceC = TextEditingController();
    final pkPriceC = TextEditingController(); final detailC = TextEditingController(); 
    final qtyC = TextEditingController(text: "1");
    final nameF = FocusNode(); final imeiF = FocusNode(); final costF = FocusNode();
    final kpkF = FocusNode(); final pkF = FocusNode(); final qtyF = FocusNode();
    
    // SKU fields
    String selectedNhom = 'IP'; // Default nhóm
    final modelC = TextEditingController();
    final thongtinC = TextEditingController();
    final skuC = TextEditingController(); // Generated SKU display/edit
    final skuF = FocusNode();
    
    String type = "PHONE"; String payMethod = "TIỀN MẶT";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;
    bool isSaving = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      Future<void> generateSKU() async {
        if (selectedNhom.isEmpty) {
          NotificationService.showSnackBar("Vui lòng chọn nhóm sản phẩm!", color: Colors.red);
          return;
        }
        
        try {
          final generatedSKU = await SKUGenerator.generateSKU(
            nhom: selectedNhom,
            model: modelC.text.trim().isNotEmpty ? modelC.text.trim() : null,
            thongtin: thongtinC.text.trim().isNotEmpty ? thongtinC.text.trim() : null,
            dbHelper: db,
            firestoreService: null,
          );
          
          setS(() => skuC.text = generatedSKU);
          NotificationService.showSnackBar("Đã tạo mã hàng: $generatedSKU", color: Colors.blue);
        } catch (e) {
          NotificationService.showSnackBar("Lỗi tạo mã hàng: $e", color: Colors.red);
        }
      }

      Future<void> saveProcess({bool next = false}) async {
        if (skuC.text.isEmpty) { 
          NotificationService.showSnackBar("Vui lòng tạo mã hàng trước!", color: Colors.red); 
          return; 
        }
        if (supplier == null) { 
          NotificationService.showSnackBar("Vui lòng chọn Nhà cung cấp!", color: Colors.red); 
          return; 
        }
        if (isSaving) return; setS(() => isSaving = true);
        try {
          int parseK(String t) { final c = t.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), ''); int v = int.tryParse(c) ?? 0; return (v > 0 && v < 100000) ? v * 1000 : v; }
          final int ts = DateTime.now().millisecondsSinceEpoch;
          final String imei = imeiC.text.trim();
          final String fId = "prod_${ts}_${imei.isNotEmpty ? imei : ts}";
          final p = Product(firestoreId: fId, name: skuC.text.toUpperCase(), imei: imei, cost: parseK(costC.text), kpkPrice: parseK(kpkPriceC.text), price: parseK(pkPriceC.text), capacity: detailC.text.toUpperCase(), quantity: int.tryParse(qtyC.text) ?? 1, type: type, createdAt: ts, supplier: supplier, status: 1);
          final user = FirebaseAuth.instance.currentUser;
          final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";
          await db.logAction(userId: user?.uid ?? "0", userName: userName, action: "NHẬP KHO", type: "PRODUCT", targetId: p.imei, desc: "Đã nhập máy ${p.name}");
          if (payMethod != "CÔNG NỢ") await db.insertExpense({'title': "NHẬP HÀNG: ${p.name}", 'amount': p.cost * p.quantity, 'category': "NHẬP HÀNG", 'date': ts, 'paymentMethod': payMethod, 'note': "Nhập từ $supplier"});
          else await db.insertDebt({'personName': supplier, 'totalAmount': p.cost * p.quantity, 'paidAmount': 0, 'type': "SHOP_OWES", 'status': "unpaid", 'createdAt': ts, 'note': "Nợ tiền máy ${p.name}"});
          await db.upsertProduct(p); await FirestoreService.addProduct(p);
          HapticFeedback.lightImpact();
          if (next) { imeiC.clear(); setS(() => isSaving = false); FocusScope.of(context).requestFocus(imeiF); NotificationService.showSnackBar("ĐÃ THÊM MÁY", color: Colors.blue); }
          else { Navigator.pop(ctx); _refresh(); NotificationService.showSnackBar("NHẬP KHO THÀNH CÔNG", color: Colors.green); }
        } catch (e) { setS(() => isSaving = false); }
      }
      return AlertDialog(
        title: const Text("NHẬP KHO SIÊU TỐC", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(value: type, items: const [DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")), DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN"))], onChanged: (v) => setS(() => type = v!), decoration: const InputDecoration(labelText: "Loại hàng")),
          _input(nameC, "Tên máy *", Icons.phone_android, f: nameF, next: imeiF, caps: true),
          _input(detailC, "Chi tiết (Dung lượng - Màu...)", Icons.info_outline, caps: true),
          _input(imeiC, "Số IMEI / Serial", Icons.fingerprint, f: imeiF, next: costF, type: TextInputType.number),
          Row(children: [Expanded(child: _input(costC, "Giá vốn (k)", Icons.money, f: costF, next: kpkF, type: TextInputType.number, suffix: "k")), const SizedBox(width: 8), Expanded(child: _input(kpkPriceC, "Giá KPK (k)", Icons.card_giftcard, f: kpkF, next: pkF, type: TextInputType.number, suffix: "k"))]),
          _input(pkPriceC, "GIÁ CPK - LẺ (k)", Icons.sell, f: pkF, next: qtyF, type: TextInputType.number, suffix: "k"),
          Row(children: [Expanded(flex: 1, child: _input(qtyC, "SL", Icons.add_box, f: qtyF, isBig: true)), const SizedBox(width: 8), Expanded(flex: 2, child: DropdownButtonFormField<String>(value: supplier, isExpanded: true, decoration: const InputDecoration(labelText: "Nhà cung cấp *"), items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(), onChanged: (v) => setS(() => supplier = v)))]),
          
          // SKU Section
          const Divider(height: 30, thickness: 1),
          const Text("MÃ HÀNG", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedNhom,
            decoration: const InputDecoration(labelText: "Nhóm *", prefixIcon: Icon(Icons.category, size: 18)),
            items: const [
              DropdownMenuItem(value: "IP", child: Text("IP - iPhone")),
              DropdownMenuItem(value: "SS", child: Text("SS - Samsung")),
              DropdownMenuItem(value: "PIN", child: Text("PIN - Pin sạc")),
              DropdownMenuItem(value: "MH", child: Text("MH - Màn hình")),
              DropdownMenuItem(value: "PK", child: Text("PK - Phụ kiện")),
            ],
            onChanged: (v) => setS(() => selectedNhom = v!),
          ),
          Row(children: [
            Expanded(child: _input(modelC, "Model (vd: IP12PM)", Icons.smartphone, caps: true)),
            const SizedBox(width: 8),
            Expanded(child: _input(thongtinC, "Thông tin (vd: 256GB)", Icons.info, caps: true)),
          ]),
          Row(children: [
            Expanded(flex: 2, child: _input(skuC, "Mã hàng được tạo", Icons.qr_code, f: skuF, caps: true, readOnly: true)),
            const SizedBox(width: 8),
            Expanded(flex: 1, child: ElevatedButton.icon(
              onPressed: () => generateSKU(),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text("TẠO MÃ"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2962FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )),
          ]),
          
          const SizedBox(height: 15), Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((m) => ChoiceChip(label: Text(m, style: const TextStyle(fontSize: 11)), selected: payMethod == m, onSelected: (v) => setS(() => payMethod = m), selectedColor: Colors.blueAccent)).toList()),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")), OutlinedButton(onPressed: isSaving ? null : () => saveProcess(next: true), child: const Text("NHẬP TIẾP")), ElevatedButton(onPressed: isSaving ? null : () => saveProcess(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)), child: const Text("HOÀN TẤT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))],
      );
    }));
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix, bool caps = false, bool isBig = false, bool readOnly = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c, focusNode: f, keyboardType: type, textInputAction: next != null ? TextInputAction.next : TextInputAction.done, textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none, inputFormatters: type == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : [], style: TextStyle(fontSize: isBig ? 20 : 14, fontWeight: isBig ? FontWeight.bold : FontWeight.normal), readOnly: readOnly, onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); }, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 18), suffixText: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: readOnly ? Colors.grey[100] : Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12))));
  }

  void _showProductDetail(Product p) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20), Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2962FF))), const SizedBox(height: 15), _detailItem("Chi tiết máy", p.capacity ?? ""), _detailItem("IMEI/Serial", p.imei ?? "N/A"), _detailItem("Nhà cung cấp", p.supplier ?? "N/A"), _detailItem("Giá CPK (Lẻ)", "${NumberFormat('#,###').format(p.price)} đ", color: Colors.red), _detailItem("Giá KPK", "${NumberFormat('#,###').format(p.kpkPrice ?? 0)} đ", color: Colors.blue), const Divider(height: 30), Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); _printOptions(p); }, icon: const Icon(Icons.qr_code_2, color: Colors.white), label: const Text("IN TEM QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), label: const Text("ĐÓNG"), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15))))])])));
  }

  void _printOptions(Product p) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.print, color: Colors.blue), title: const Text("In bằng máy in mặc định"), onTap: () { HapticFeedback.mediumImpact(); Navigator.pop(ctx); UnifiedPrinterService.printProductQRLabel(p.toMap()); }), ListTile(leading: const Icon(Icons.bluetooth_searching, color: Colors.orange), title: const Text("Chọn máy in khác"), onTap: () async { HapticFeedback.mediumImpact(); Navigator.pop(ctx); final list = await BluetoothPrinterService.getPairedPrinters(); if (list.isNotEmpty && mounted) { showModalBottomSheet(context: context, builder: (c) => ListView.builder(itemCount: list.length, itemBuilder: (cc, i) => ListTile(title: Text(list[i].name), subtitle: Text(list[i].macAdress), onTap: () { Navigator.pop(c); UnifiedPrinterService.printProductQRLabel(p.toMap(), customMac: list[i].macAdress); }))); } })])));
  }

  Widget _detailItem(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))]));
}
