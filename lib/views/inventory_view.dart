import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
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
    setState(() { _products = data; _suppliers = suppliers; _isLoading = false; });
  }

  void _showAddProductDialog() {
    final nameC = TextEditingController();
    final imeiC = TextEditingController();
    final costC = TextEditingController();
    final pkPriceC = TextEditingController();
    final kpkPriceC = TextEditingController();
    final colorC = TextEditingController();
    final capacityC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    
    final nameF = FocusNode();
    final imeiF = FocusNode();
    final costF = FocusNode();
    final pkF = FocusNode();
    final kpkF = FocusNode();
    final qtyF = FocusNode();

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
              NotificationService.showSnackBar("Vui lòng nhập Tên và NCC!", color: Colors.red);
              return;
            }
            setS(() => isSaving = true);
            try {
              // LOGIC QUY ƯỚC K: CHỈ XỬ LÝ KHI BẤM LƯU
              int parseK(String t) {
                final clean = t.replaceAll(RegExp(r'[^\d]'), '');
                int v = int.tryParse(clean) ?? 0;
                if (v > 0 && v < 100000) return v * 1000;
                return v;
              }

              final p = Product(
                name: nameC.text.toUpperCase(),
                imei: imeiC.text.trim(),
                cost: parseK(costC.text),
                price: parseK(pkPriceC.text),
                kpkPrice: parseK(kpkPriceC.text),
                pkPrice: parseK(pkPriceC.text),
                color: colorC.text.toUpperCase(),
                capacity: capacityC.text.toUpperCase(),
                quantity: int.tryParse(qtyC.text) ?? 1,
                type: type,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                supplier: supplier,
                status: 1,
              );

              await db.upsertProduct(p);
              await FirestoreService.addProduct(p);

              if (next) {
                imeiC.clear(); qtyC.text = "1";
                setS(() => isSaving = false);
                FocusScope.of(context).requestFocus(imeiF);
              } else {
                Navigator.pop(ctx); _refresh();
                NotificationService.showSnackBar("ĐÃ NHẬP KHO THÀNH CÔNG", color: Colors.green);
              }
            } catch (e) {
              setS(() => isSaving = false);
              NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
            }
          }

          return AlertDialog(
            title: const Text("NHẬP KHO SIÊU TỐC"),
            content: SizedBox(
              width: double.maxFinite,
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
                    _input(nameC, "Tên sản phẩm *", Icons.phone_android, f: nameF, next: imeiF),
                    _input(imeiC, "Số IMEI / Serial", Icons.fingerprint, f: imeiF, next: costF, type: TextInputType.number),
                    Row(children: [
                      Expanded(child: _input(colorC, "Màu sắc", Icons.color_lens)),
                      const SizedBox(width: 8),
                      Expanded(child: _input(capacityC, "Dung lượng", Icons.storage)),
                    ]),
                    Row(children: [
                      Expanded(child: _input(costC, "Giá vốn (k)", Icons.money, f: costF, next: pkF, type: TextInputType.number, suffix: "k")),
                      const SizedBox(width: 8),
                      Expanded(child: _input(pkPriceC, "Giá lẻ (k)", Icons.sell, f: pkF, next: kpkF, type: TextInputType.number, suffix: "k")),
                    ]),
                    _input(kpkPriceC, "Giá kèm PK (k)", Icons.card_giftcard, f: kpkF, next: qtyF, type: TextInputType.number, suffix: "k"),
                    Row(children: [
                      Expanded(child: _input(qtyC, "Số lượng", Icons.add_box, f: qtyF)),
                      const SizedBox(width: 8),
                      Expanded(flex: 2, child: DropdownButtonFormField<String>(
                        value: supplier, isExpanded: true,
                        decoration: const InputDecoration(labelText: "Nhà cung cấp *", border: OutlineInputBorder()),
                        items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                        onChanged: (v) => setS(() => supplier = v),
                      )),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((m) => ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 10)),
                        selected: payMethod == m,
                        onSelected: (v) => setS(() => payMethod = m),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
              OutlinedButton(onPressed: isSaving ? null : () => saveProcess(next: true), child: const Text("NHẬP TIẾP")),
              ElevatedButton(onPressed: isSaving ? null : () => saveProcess(), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)), child: const Text("HOÀN TẤT", style: TextStyle(color: Colors.white))),
            ],
          );
        },
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textInputAction: next != null ? TextInputAction.next : TextInputAction.done,
        textCapitalization: type == TextInputType.number ? TextCapitalization.none : TextCapitalization.characters,
        inputFormatters: type == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : [],
        style: const TextStyle(fontSize: 15),
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
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("QUẢN LÝ KHO", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Tìm máy hoặc IMEI...", prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: const Color(0xFFF8FAFF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final p = list[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: const Color(0xFF2962FF)),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("IMEI: ${p.imei}\nNCC: ${p.supplier}"),
              trailing: Text("${NumberFormat('#,###').format(p.price)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () => UnifiedPrinterService.printProductQRLabel({'id': p.id, 'firestoreId': p.firestoreId, 'name': p.name, 'imei': p.imei, 'price': p.price}),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        label: const Text("NHẬP KHO"),
        icon: const Icon(Icons.add_business_rounded),
        backgroundColor: const Color(0xFF2962FF),
      ),
    );
  }
}
