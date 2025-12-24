import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';
import '../services/firestore_service.dart';
import '../services/unified_printer_service.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';

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
        content: Text("Bạn có chắc chắn muốn xóa ${_selectedIds.length} máy đã chọn không?"),
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
          
          // GHI NHẬT KÝ HÀNH ĐỘNG XÓA
          await db.logAction(
            userId: user?.uid ?? "0",
            userName: userName,
            action: "XÓA KHO",
            type: "PRODUCT",
            targetId: p.imei,
            desc: "Đã xóa máy ${p.name} (IMEI: ${p.imei}) khỏi kho hàng",
          );

          await db.deleteProduct(id);
          if (p.firestoreId != null) await FirestoreService.deleteProduct(p.firestoreId!);
        }
        NotificationService.showSnackBar("ĐÃ XÓA ${_selectedIds.length} MÁY & GHI NHẬT KÝ", color: Colors.green);
        _refresh();
      } catch (e) {
        setState(() => _isLoading = false);
        NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
      }
    }
  }

  void _toggleSelection(int id) {
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

  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final imeiC = TextEditingController();
    final costC = TextEditingController();
    final kpkPriceC = TextEditingController();
    final pkPriceC = TextEditingController(); 
    final detailC = TextEditingController(); 
    final qtyC = TextEditingController(text: "1");
    
    final nameF = FocusNode(); final imeiF = FocusNode(); final costF = FocusNode();
    final kpkF = FocusNode(); final pkF = FocusNode(); final qtyF = FocusNode();

    String type = "PHONE";
    String payMethod = "TIỀN MẶT";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> saveProcess({bool next = false}) async {
            if (nameC.text.isEmpty || supplier == null) {
              NotificationService.showSnackBar("Vui lòng nhập Tên và Nhà cung cấp!", color: Colors.red);
              return;
            }
            setS(() => isSaving = true);
            try {
              int parseK(String t) {
                final c = t.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), '');
                int v = int.tryParse(c) ?? 0;
                return (v > 0 && v < 100000) ? v * 1000 : v;
              }

              final int timestamp = DateTime.now().millisecondsSinceEpoch;
              final String imei = imeiC.text.trim();
              final String fixedFirestoreId = "prod_${timestamp}_${imei.isNotEmpty ? imei : timestamp}";

              final p = Product(
                firestoreId: fixedFirestoreId,
                name: nameC.text.toUpperCase(),
                imei: imei,
                cost: parseK(costC.text),
                kpkPrice: parseK(kpkPriceC.text),
                price: parseK(pkPriceC.text), 
                capacity: detailC.text.toUpperCase(),
                quantity: int.tryParse(qtyC.text) ?? 1,
                type: type,
                createdAt: timestamp,
                supplier: supplier,
                status: 1,
              );

              final user = FirebaseAuth.instance.currentUser;
              final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";

              // GHI NHẬT KÝ NHẬP KHO
              await db.logAction(
                userId: user?.uid ?? "0",
                userName: userName,
                action: "NHẬP KHO",
                type: "PRODUCT",
                targetId: p.imei,
                desc: "Đã nhập máy ${p.name} (IMEI: ${p.imei}) từ $supplier. Thanh toán: $payMethod",
              );

              if (payMethod != "CÔNG NỢ") {
                await db.insertExpense({
                  'title': "NHẬP HÀNG: ${p.name}",
                  'amount': p.cost * p.quantity,
                  'category': "NHẬP HÀNG",
                  'date': timestamp,
                  'paymentMethod': payMethod,
                  'note': "Nhập từ $supplier",
                });
              } else {
                await db.insertDebt({
                  'personName': supplier,
                  'totalAmount': p.cost * p.quantity,
                  'paidAmount': 0,
                  'type': "SHOP_OWES",
                  'status': "unpaid",
                  'createdAt': timestamp,
                  'note': "Nợ tiền máy ${p.name}",
                });
              }

              await db.upsertProduct(p);
              await FirestoreService.addProduct(p);

              if (next) {
                imeiC.clear(); setS(() => isSaving = false);
                FocusScope.of(context).requestFocus(imeiF);
                NotificationService.showSnackBar("ĐÃ THÊM MÁY & GHI NHẬT KÝ", color: Colors.blue);
              } else {
                Navigator.pop(ctx); _refresh();
                NotificationService.showSnackBar("NHẬP KHO THÀNH CÔNG", color: Colors.green);
              }
            } catch (e) {
              setS(() => isSaving = false);
              NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
            }
          }

          return AlertDialog(
            title: const Text("NHẬP KHO SIÊU TỐC", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: type,
                      items: const [DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")), DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN"))],
                      onChanged: (v) => setS(() => type = v!),
                      decoration: const InputDecoration(labelText: "Loại hàng", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    _input(nameC, "Tên máy *", Icons.phone_android, f: nameF, next: imeiF, caps: true),
                    _input(detailC, "Chi tiết (Dung lượng - Màu...)", Icons.info_outline, caps: true),
                    _input(imeiC, "Số IMEI / Serial", Icons.fingerprint, f: imeiF, next: costF, type: TextInputType.number),
                    Row(children: [
                      Expanded(child: _input(costC, "Giá vốn (k)", Icons.money, f: costF, next: kpkF, type: TextInputType.number, suffix: "k")),
                      const SizedBox(width: 8),
                      Expanded(child: _input(kpkPriceC, "Giá KPK (k)", Icons.card_giftcard, f: kpkF, next: pkF, type: TextInputType.number, suffix: "k")),
                    ]),
                    _input(pkPriceC, "GIÁ CPK - LẺ (k)", Icons.sell, f: pkF, next: qtyF, type: TextInputType.number, suffix: "k"),
                    Row(children: [
                      Expanded(child: _input(qtyC, "SL", Icons.add_box, f: qtyF)),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: DropdownButtonFormField<String>(
                        value: supplier, isExpanded: true,
                        decoration: const InputDecoration(labelText: "Nhà cung cấp *", border: OutlineInputBorder()),
                        items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                        onChanged: (v) => setS(() => supplier = v),
                      )),
                    ]),
                    const SizedBox(height: 15),
                    const Align(alignment: Alignment.centerLeft, child: Text("THANH TOÁN CHO NHÀ CC", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((m) => ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 11)),
                        selected: payMethod == m,
                        onSelected: (v) => setS(() => payMethod = m),
                        selectedColor: Colors.blueAccent,
                        labelStyle: TextStyle(color: payMethod == m ? Colors.white : Colors.black87),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
              OutlinedButton(onPressed: isSaving ? null : () => saveProcess(next: true), child: const Text("NHẬP TIẾP")),
              ElevatedButton(onPressed: isSaving ? null : () => saveProcess(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)), child: const Text("HOÀN TẤT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          );
        },
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix, bool caps = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textInputAction: next != null ? TextInputAction.next : TextInputAction.done,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        inputFormatters: type == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : [],
        style: const TextStyle(fontSize: 14),
        onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); },
        decoration: InputDecoration(
          labelText: l, prefixIcon: Icon(i, size: 18), suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || (p.imei ?? "").contains(_searchQuery)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text("ĐÃ CHỌN ${_selectedIds.length}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            : const Text("QUẢN LÝ KHO", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); }))
            : null,
        actions: [
          if (!_isSelectionMode) TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())).then((_) => _refresh()), icon: const Icon(Icons.business_center, size: 20), label: const Text("NCC", style: TextStyle(fontWeight: FontWeight.bold))),
          if (_isSelectionMode) IconButton(onPressed: _deleteSelected, icon: const Icon(Icons.delete_forever, color: Colors.red, size: 28))
          else IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(hintText: "Tìm máy hoặc IMEI...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: const Color(0xFFF8FAFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
            ),
          ),
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildProductCard(list[i]),
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(onPressed: _showAddProductDialog, label: const Text("NHẬP KHO"), icon: const Icon(Icons.add_business_rounded), backgroundColor: const Color(0xFF2962FF)),
    );
  }

  Widget _buildProductCard(Product p) {
    final bool isSelected = _selectedIds.contains(p.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: isSelected ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none),
      elevation: isSelected ? 5 : 2,
      child: ListTile(
        onLongPress: () { HapticFeedback.heavyImpact(); _toggleSelection(p.id!); },
        onTap: () { if (_isSelectionMode) _toggleSelection(p.id!); else _showProductDetail(p); },
        leading: Stack(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isSelected ? Colors.red : const Color(0xFF2962FF)).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: isSelected ? Colors.red : const Color(0xFF2962FF))),
          if (isSelected) const Positioned(right: -2, bottom: -2, child: CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Icon(Icons.check, size: 10, color: Colors.white))),
        ]),
        title: Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.red : Colors.black)),
        subtitle: Text("${p.capacity ?? ''}\nIMEI: ${p.imei}"),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${NumberFormat('#,###').format(p.price)} d", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), Text("Tồn: ${p.quantity}", style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  void _showProductDetail(Product p) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (ctx) => Container(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20), Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2962FF))), const SizedBox(height: 15), _detailItem("Chi tiết máy", p.capacity ?? ""), _detailItem("IMEI/Serial", p.imei ?? "N/A"), _detailItem("Nhà cung cấp", p.supplier ?? "N/A"), _detailItem("Giá CPK (Lẻ)", "${NumberFormat('#,###').format(p.price)} đ", color: Colors.red), _detailItem("Giá KPK", "${NumberFormat('#,###').format(p.kpkPrice ?? 0)} đ", color: Colors.blue), const Divider(height: 30), Row(children: [Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(ctx); UnifiedPrinterService.printProductQRLabel(p.toMap()); }, icon: const Icon(Icons.qr_code_2, color: Colors.white), label: const Text("IN TEM QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)))), const SizedBox(width: 12), Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), label: const Text("ĐÓNG"), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15))))])])));
  }

  Widget _detailItem(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color))]));
}
