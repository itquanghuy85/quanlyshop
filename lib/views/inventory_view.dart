import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
    setState(() => _isLoading = true);
    final data = await db.getInStockProducts();
    final suppliers = await db.getSuppliers();
    if (!mounted) return;
    setState(() {
      _products = data;
      _suppliers = suppliers;
      _isLoading = false;
    });
  }

  // 1. XEM CHI TIẾT VÀ NÚT IN TÙY CHỈNH (THAY THẾ CHO BẤM GIỮ)
  void _showProductDetail(Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
            const SizedBox(height: 15),
            _detailItem("IMEI/Serial", p.imei ?? "Không có"),
            _detailItem("Màu sắc", p.color ?? "Không có"),
            _detailItem("Dung lượng", p.capacity ?? "Không có"),
            _detailItem("Nhà cung cấp", p.supplier ?? "Chưa rõ"),
            _detailItem("Giá lẻ (PK)", "${NumberFormat('#,###').format(p.price)} đ", color: Colors.red),
            _detailItem("Giá KPK", "${NumberFormat('#,###').format(p.kpkPrice ?? 0)} đ"),
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _printLabel(p);
                    },
                    icon: const Icon(Icons.qr_code_2, color: Colors.white),
                    label: const Text("IN TEM QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text("ĐÓNG"),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        ],
      ),
    );
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController(); final imeiC = TextEditingController();
    final costC = TextEditingController(); final pkPriceC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    final nameF = FocusNode(); final imeiF = FocusNode(); final costF = FocusNode(); final pkF = FocusNode(); final qtyF = FocusNode();
    String type = "PHONE"; String payMethod = "TIỀN MẶT";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> saveProcess({bool next = false}) async {
            if (nameC.text.isEmpty || supplier == null) return;
            setS(() => isSaving = true);
            try {
              int parseK(String t) {
                final c = t.replaceAll('.', '').replaceAll(RegExp(r'[^\d]'), '');
                int v = int.tryParse(c) ?? 0;
                return (v > 0 && v < 100000) ? v * 1000 : v;
              }
              final p = Product(name: nameC.text.toUpperCase(), imei: imeiC.text.trim(), cost: parseK(costC.text), price: parseK(pkPriceC.text), quantity: int.tryParse(qtyC.text) ?? 1, type: type, createdAt: DateTime.now().millisecondsSinceEpoch, supplier: supplier, status: 1);
              await db.upsertProduct(p); await FirestoreService.addProduct(p);
              if (next) { imeiC.clear(); qtyC.text = "1"; setS(() => isSaving = false); FocusScope.of(context).requestFocus(imeiF); }
              else { Navigator.pop(ctx); _refresh(); }
            } catch (_) { setS(() => isSaving = false); }
          }
          return AlertDialog(
            title: const Text("NHẬP KHO SIÊU TỐC"),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(value: type, items: const [DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")), DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN"))], onChanged: (v) => setS(() => type = v!), decoration: const InputDecoration(labelText: "Loại")),
              _input(nameC, "Tên *", Icons.phone_android, f: nameF, next: imeiF),
              _input(imeiC, "IMEI", Icons.fingerprint, f: imeiF, next: costF, type: TextInputType.number),
              _input(costC, "Giá vốn (k)", Icons.money, f: costF, next: pkF, type: TextInputType.number, suffix: "k"),
              _input(pkPriceC, "Giá lẻ (k)", Icons.sell, f: pkF, next: qtyF, type: TextInputType.number, suffix: "k"),
              Row(children: [Expanded(child: _input(qtyC, "SL", Icons.add_box, f: qtyF)), const SizedBox(width: 8), Expanded(flex: 2, child: DropdownButtonFormField<String>(value: supplier, isExpanded: true, items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(), onChanged: (v) => setS(() => supplier = v)))]),
              const SizedBox(height: 10), Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((m) => ChoiceChip(label: Text(m, style: const TextStyle(fontSize: 10)), selected: payMethod == m, onSelected: (v) => setS(() => payMethod = m))).toList()),
            ])),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")), OutlinedButton(onPressed: isSaving ? null : () => saveProcess(next: true), child: const Text("TIẾP")), ElevatedButton(onPressed: isSaving ? null : () => saveProcess(), child: const Text("LƯU"))],
          );
        },
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: c, focusNode: f, keyboardType: type, textCapitalization: TextCapitalization.characters, onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); }, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 18), suffixText: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12))));
  }

  @override
  Widget build(BuildContext context) {
    final list = _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || (p.imei ?? "").contains(_searchQuery)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("QUẢN LÝ KHO"),
        actions: [
          // 2. THÊM NÚT NHÀ CUNG CẤP TRÊN THANH CÔNG CỤ
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())).then((_) => _refresh()),
            icon: const Icon(Icons.business_center, size: 20),
            label: const Text("NCC", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Tìm máy nhanh...",
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final p = list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              onTap: () => _showProductDetail(p), // BẤM VÀO ĐỂ XEM CHI TIẾT
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF2962FF).withOpacity(0.1),
                child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: const Color(0xFF2962FF)),
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("IMEI: ${p.imei}\nTồn: ${p.quantity}"),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        label: const Text("NHẬP KHO"),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF2962FF),
      ),
    );
  }

  Future<void> _printLabel(Product p) async {
    try {
      final success = await UnifiedPrinterService.printProductQRLabel({
        'id': p.id, 'firestoreId': p.firestoreId, 'name': p.name, 'imei': p.imei, 'price': p.price
      });
      if (success) {
        NotificationService.showSnackBar("Đang in tem: ${p.name}", color: Colors.green);
      } else {
        NotificationService.showSnackBar("Lỗi máy in!", color: Colors.red);
      }
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
    }
  }
}
