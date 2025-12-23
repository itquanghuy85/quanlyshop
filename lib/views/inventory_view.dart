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
import '../services/notification_service.dart';
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
    
    final nameF = FocusNode();
    final imeiF = FocusNode();
    final costF = FocusNode();
    final kpkF = FocusNode();
    final pkF = FocusNode();
    final qtyF = FocusNode();

    String type = "PHONE";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Tránh bấm nhầm ra ngoài làm mất data
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          
          Future<void> saveProcess({bool continueAdding = false}) async {
            if (nameC.text.isEmpty || supplier == null) {
              NotificationService.showSnackBar("Vui lòng nhập Tên và chọn Nhà cung cấp!", color: Colors.red);
              return;
            }
            setModalState(() => isSaving = true);
            try {
              final p = Product(
                name: nameC.text.toUpperCase(),
                imei: imeiC.text.toUpperCase(),
                cost: (int.tryParse(costC.text.replaceAll('.', '')) ?? 0) * 1000,
                price: (int.tryParse(pkPriceC.text.replaceAll('.', '')) ?? 0) * 1000,
                kpkPrice: (int.tryParse(kpkPriceC.text.replaceAll('.', '')) ?? 0) * 1000,
                pkPrice: (int.tryParse(pkPriceC.text.replaceAll('.', '')) ?? 0) * 1000,
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
              
              if (continueAdding) {
                // Nhập tiếp: Chỉ xóa IMEI và focus lại
                imeiC.clear();
                qtyC.text = "1";
                setModalState(() => isSaving = false);
                FocusScope.of(context).requestFocus(imeiF);
                NotificationService.showSnackBar("Đã nhập thành công: ${p.name}. Hãy nhập IMEI tiếp theo.");
              } else {
                Navigator.pop(ctx);
                _refresh();
                NotificationService.showSnackBar("ĐÃ NHẬP KHO THÀNH CÔNG", color: Colors.green);
              }
            } catch (e) {
              setModalState(() => isSaving = false);
              NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
            }
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.add_business, color: Colors.blueAccent),
                const SizedBox(width: 10),
                const Text("NHẬP KHO SIÊU TỐC", style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () { Navigator.pop(ctx); _refresh(); }, icon: const Icon(Icons.close))
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    items: const [DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")), DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN"))],
                    onChanged: (v) => setModalState(() => type = v!),
                    decoration: const InputDecoration(labelText: "Loại hàng", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  _input(nameC, "Tên sản phẩm *", Icons.phone_android, f: nameF, next: imeiF),
                  _input(imeiC, "Số IMEI / Serial", Icons.fingerprint, f: imeiF, next: costF, hint: "Quét hoặc gõ IMEI"),
                  Row(children: [
                    Expanded(child: _input(costC, "Giá vốn", Icons.money, type: TextInputType.number, suffix: ".000", f: costF, next: kpkF)),
                    const SizedBox(width: 10),
                    Expanded(child: _input(kpkPriceC, "Giá KPK", Icons.sell, type: TextInputType.number, suffix: ".000", f: kpkF, next: pkF)),
                  ]),
                  _input(pkPriceC, "Giá lẻ (PK)", Icons.shopping_bag, type: TextInputType.number, suffix: ".000", f: pkF, next: qtyF),
                  _input(qtyC, "Số lượng", Icons.add_box, type: TextInputType.number, f: qtyF, onDone: () => saveProcess()),
                  
                  DropdownButtonFormField<String>(
                    value: supplier,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Nhà cung cấp *", prefixIcon: Icon(Icons.business, size: 20), border: OutlineInputBorder()),
                    items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                    onChanged: (v) => setModalState(() => supplier = v),
                  ),
                  if (_suppliers.isEmpty) 
                    TextButton.icon(
                      onPressed: () async {
                        final created = await _showQuickAddSupplier();
                        if (created != null) {
                          final list = await db.getSuppliers();
                          setModalState(() { _suppliers = list; supplier = created; });
                        }
                      },
                      icon: const Icon(Icons.add_circle),
                      label: const Text("Thêm Nhà cung cấp ngay"),
                    ),
                ],
              ),
            ),
            actions: [
              // NÚT NHẬP TIẾP: Cực kỳ hữu dụng khi nhập lô hàng cùng model
              OutlinedButton(
                onPressed: isSaving ? null : () => saveProcess(continueAdding: true),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orange), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10)),
                child: const Text("LƯU & NHẬP TIẾP", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20)),
                onPressed: isSaving ? null : () => saveProcess(), 
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("XÁC NHẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix, String? hint, VoidCallback? onDone}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) { 
          if (next != null) {
            FocusScope.of(context).requestFocus(next);
          } else if (onDone != null) {
            onDone();
          }
        },
        decoration: InputDecoration(
          labelText: l, hintText: hint, prefixIcon: Icon(i, size: 20, color: Colors.blueAccent), suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.white,
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
        content: TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên nhà cung cấp", border: OutlineInputBorder()), textCapitalization: TextCapitalization.characters),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("QUẢN LÝ KHO HÀNG", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: Colors.blueAccent))],
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _products.isEmpty 
        ? const Center(child: Text("Kho hàng đang trống. Hãy nhập hàng mới!"))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _products.length,
            itemBuilder: (ctx, i) {
              final p = _products[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: Colors.blueAccent)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Text("IMEI: ${p.imei ?? 'N/A'}\nNCC: ${p.supplier ?? '---'}"),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${NumberFormat('#,###').format(p.price)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      Text("SL: ${p.quantity}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        label: const Text("NHẬP KHO SIÊU TỐC"),
        icon: const Icon(Icons.bolt, color: Colors.white),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
