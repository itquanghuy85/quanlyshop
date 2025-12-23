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
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          
          Future<void> saveProcess({bool continueAdding = false}) async {
            if (nameC.text.isEmpty || supplier == null) {
              NotificationService.showSnackBar("Vui lòng nhập Tên và chọn Nhà cung cấp!", color: Colors.red);
              return;
            }
            setModalState(() => isSaving = true);
            try {
              int parsePrice(String text) {
                final clean = text.replaceAll('.', '');
                return int.tryParse(clean) ?? 0;
              }

              final p = Product(
                name: nameC.text.toUpperCase(),
                imei: imeiC.text.toUpperCase(),
                cost: parsePrice(costC.text),
                price: parsePrice(pkPriceC.text),
                kpkPrice: parsePrice(kpkPriceC.text),
                pkPrice: parsePrice(pkPriceC.text),
                quantity: int.tryParse(qtyC.text) ?? 1,
                type: type,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                supplier: supplier,
                status: 1,
              );
              
              await db.upsertProduct(p);
              await FirestoreService.addProduct(p);
              await db.incrementSupplierStats(supplier!, p.cost * p.quantity);
              
              if (continueAdding) {
                imeiC.clear();
                qtyC.text = "1";
                setModalState(() => isSaving = false);
                FocusScope.of(context).requestFocus(imeiF);
                NotificationService.showSnackBar("✅ Đã nhập: ${p.name}");
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
            insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20), // Mở rộng chiều ngang dialog
            title: const Text("NHẬP KHO SIÊU TỐC", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9, // Tăng chiều ngang content
              child: SingleChildScrollView(
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
                    _input(imeiC, "Số IMEI / Serial", Icons.fingerprint, f: imeiF, next: costF),
                    
                    // KHUNG NHẬP GIÁ ĐƯỢC THIẾT KẾ LẠI TO VÀ RÕ
                    _input(costC, "GIÁ VỐN (VNĐ)", Icons.account_balance_wallet, type: TextInputType.number, formatters: [CurrencyInputFormatter()], f: costF, next: kpkF, isBig: true),
                    _input(kpkPriceC, "GIÁ BÁN KÈM PHỤ KIỆN (KPK)", Icons.sell, type: TextInputType.number, formatters: [CurrencyInputFormatter()], f: kpkF, next: pkF, isBig: true),
                    _input(pkPriceC, "GIÁ BÁN LẺ PHỤ KIỆN (PK)", Icons.shopping_bag, type: TextInputType.number, formatters: [CurrencyInputFormatter()], f: pkF, next: qtyF, isBig: true),
                    
                    Row(
                      children: [
                        Expanded(child: _input(qtyC, "Số lượng", Icons.add_box, type: TextInputType.number, f: qtyF, onDone: () => saveProcess())),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: supplier,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: "Nhà cung cấp *", border: OutlineInputBorder()),
                            items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                            onChanged: (v) => setModalState(() => supplier = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(onPressed: isSaving ? null : () => saveProcess(continueAdding: true), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text("NHẬP TIẾP")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30)),
                onPressed: isSaving ? null : () => saveProcess(), 
                child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text("XÁC NHẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, List<TextInputFormatter>? formatters, VoidCallback? onDone, bool isBig = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: formatters,
        style: TextStyle(
          fontSize: isBig ? 18 : 14, 
          fontWeight: isBig ? FontWeight.bold : FontWeight.normal,
          color: isBig ? const Color(0xFF2962FF) : Colors.black87
        ),
        onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); else if (onDone != null) onDone(); },
        decoration: InputDecoration(
          labelText: l, 
          labelStyle: const TextStyle(fontSize: 12),
          prefixIcon: Icon(i, size: 20), 
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: isBig ? const Color(0xFFF0F4F8) : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(title: const Text("KHO HÀNG", style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))]),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (ctx, i) {
          final p = _products[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: const Color(0xFF2962FF).withOpacity(0.1), child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset, color: const Color(0xFF2962FF))),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("IMEI: ${p.imei ?? 'N/A'}\nNCC: ${p.supplier ?? '---'}"),
              trailing: Text("${NumberFormat('#,###').format(p.price)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showAddProductDialog, label: const Text("NHẬP KHO"), icon: const Icon(Icons.add), backgroundColor: const Color(0xFF2962FF)),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final String cleanedText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanedText.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    final number = int.tryParse(cleanedText) ?? 0;
    int finalNumber = number;
    if (number > 0 && number < 10000) finalNumber = number * 1000;
    
    final formatted = _formatCurrency(finalNumber);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
  String _formatCurrency(int number) {
    final String numberStr = number.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = numberStr.length - 1, count = 0; i >= 0; i--, count++) {
      buffer.write(numberStr[i]);
      if ((count + 1) % 3 == 0 && i > 0) buffer.write('.');
    }
    return buffer.toString().split('').reversed.join('');
  }
}
