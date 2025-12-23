import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _refresh();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _isAdmin = perms['allowViewInventory'] ?? false);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getInStockProducts();
    final suppliers = await db.getSuppliers();
    setState(() { _products = data; _suppliers = suppliers; _isLoading = false; });
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final imeiC = TextEditingController();
    final costC = TextEditingController();
    final kpkPriceC = TextEditingController();
    final pkPriceC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    
    // Hệ thống FocusNodes để tự nhảy dòng
    final nameF = FocusNode();
    final imeiF = FocusNode();
    final costF = FocusNode();
    final kpkF = FocusNode();
    final pkF = FocusNode();
    final qtyF = FocusNode();

    String type = "PHONE";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("NHẬP HÀNG VÀO KHO", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")), DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN"))],
                  onChanged: (v) => setModalState(() => type = v!),
                  decoration: const InputDecoration(labelText: "Loại hàng"),
                ),
                const SizedBox(height: 10),
                _input(nameC, "Tên sản phẩm *", Icons.phone_android, f: nameF, next: imeiF),
                _input(imeiC, "Số IMEI (Nếu có)", Icons.fingerprint, f: imeiF, next: costF),
                Row(children: [
                  Expanded(child: _input(costC, "Giá vốn", Icons.money, type: TextInputType.number, suffix: ".000", f: costF, next: kpkF)),
                  const SizedBox(width: 10),
                  Expanded(child: _input(kpkPriceC, "Giá KPK", Icons.sell, type: TextInputType.number, suffix: ".000", f: kpkF, next: pkF)),
                ]),
                _input(pkPriceC, "Giá bán lẻ (PK)", Icons.shopping_bag, type: TextInputType.number, suffix: ".000", f: pkF, next: qtyF),
                _input(qtyC, "Số lượng", Icons.add_box, type: TextInputType.number, f: qtyF),
                
                DropdownButtonFormField<String>(
                  value: supplier,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: "Nhà cung cấp *", prefixIcon: Icon(Icons.business, size: 20)),
                  items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                  onChanged: (v) => setModalState(() => supplier = v),
                ),
                if (_suppliers.isEmpty) 
                  const Padding(padding: EdgeInsets.only(top: 8), child: Text("Lưu ý: Bạn chưa có Nhà cung cấp. Hãy thêm nhanh phía dưới.", style: TextStyle(color: Colors.red, fontSize: 11))),
                
                TextButton.icon(
                  onPressed: () async {
                    final created = await _showQuickAddSupplier();
                    if (created != null) {
                      final list = await db.getSuppliers();
                      setModalState(() { _suppliers = list; supplier = created; });
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Thêm nhanh Nhà cung cấp"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              onPressed: () async {
                if (nameC.text.isEmpty || supplier == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("VUI LÒNG NHẬP TÊN VÀ CHỌN NHÀ CUNG CẤP!"), backgroundColor: Colors.red));
                  return;
                }
                final p = Product(
                  name: nameC.text.toUpperCase(),
                  imei: imeiC.text.toUpperCase(),
                  cost: (int.tryParse(costC.text) ?? 0) * 1000,
                  price: (int.tryParse(pkPriceC.text) ?? 0) * 1000,
                  kpkPrice: (int.tryParse(kpkPriceC.text) ?? 0) * 1000,
                  pkPrice: (int.tryParse(pkPriceC.text) ?? 0) * 1000,
                  quantity: int.tryParse(qtyC.text) ?? 1,
                  type: type,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  supplier: supplier,
                  status: 1,
                );
                
                final fId = await FirestoreService.addProduct(p);
                if (fId != null) p.firestoreId = fId;
                
                await db.upsertProduct(p);
                await db.incrementSupplierStats(supplier!, p.cost * p.quantity);
                Navigator.pop(ctx);
                _refresh();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ NHẬP KHO THÀNH CÔNG"), backgroundColor: Colors.green));
              }, 
              child: const Text("XÁC NHẬN NHẬP KHO", style: TextStyle(color: Colors.white))
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); },
        decoration: InputDecoration(
          labelText: l, prefixIcon: Icon(i, size: 20), suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        ),
      ),
    );
  }

  Future<String?> _showQuickAddSupplier() async {
    final nameC = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("THÊM NHÀ CUNG CẤP"),
        content: TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên nhà cung cấp"), textCapitalization: TextCapitalization.characters),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(onPressed: () async {
            if (nameC.text.isEmpty) return;
            await db.insertSupplier({'name': nameC.text.toUpperCase(), 'createdAt': DateTime.now().millisecondsSinceEpoch});
            Navigator.pop(ctx, nameC.text.toUpperCase());
          }, child: const Text("LƯU")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: Text(l10n.inventory, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, foregroundColor: Colors.white),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          final p = _products[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.green.withOpacity(0.1), child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: Colors.green)),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("IMEI: ${p.imei ?? 'N/A'}\nNCC: ${p.supplier ?? '---'} | SL: ${p.quantity}"),
              trailing: Text("${NumberFormat('#,###').format(p.price)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        label: const Text("NHẬP KHO MỚI"),
        icon: const Icon(Icons.add_business),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
