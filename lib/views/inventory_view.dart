import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../data/db_helper.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';

class InventoryView extends StatefulWidget {
  final String role;
  const InventoryView({super.key, required this.role});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final db = DBHelper();
  List<Product> _products = [];
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
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
    final priceC = TextEditingController();
    final qtyC = TextEditingController(text: "1");
    String type = "PHONE";
    String? supplier = _suppliers.isNotEmpty ? _suppliers.first['name'] as String : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("NHẬP HÀNG VÀO KHO"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: "PHONE", child: Text("ĐIỆN THOẠI")),
                    DropdownMenuItem(value: "ACCESSORY", child: Text("PHỤ KIỆN")),
                  ],
                  onChanged: (v) => setModalState(() => type = v!),
                  decoration: const InputDecoration(labelText: "Loại hàng"),
                ),
                TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên máy/Linh kiện"), textCapitalization: TextCapitalization.characters),
                TextField(controller: imeiC, decoration: const InputDecoration(labelText: "Số IMEI (Nếu có)"), textCapitalization: TextCapitalization.characters),
                Row(children: [
                  Expanded(child: TextField(controller: costC, decoration: const InputDecoration(labelText: "Giá vốn", suffixText: ".000"), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: priceC, decoration: const InputDecoration(labelText: "Giá bán", suffixText: ".000"), keyboardType: TextInputType.number)),
                ]),
                TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Số lượng"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: supplier,
                  decoration: const InputDecoration(labelText: "Nhà cung cấp (bắt buộc)"),
                  items: _suppliers.map((s) => DropdownMenuItem(value: s['name'] as String, child: Text(s['name']))).toList(),
                  onChanged: (v) => setModalState(() => supplier = v),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final created = await _showQuickAddSupplier();
                      if (created != null) {
                        setModalState(() => supplier = created);
                      }
                    },
                    icon: const Icon(Icons.add_business, size: 18),
                    label: const Text("Thêm NCC nhanh"),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(onPressed: () async {
              if (nameC.text.isEmpty || supplier == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("VUI LÒNG NHẬP TÊN HÀNG VÀ CHỌN NHÀ CUNG CẤP")));
                return;
              }
              final qty = int.tryParse(qtyC.text) ?? 1;
              final p = Product(
                name: nameC.text.toUpperCase(),
                imei: imeiC.text.toUpperCase(),
                cost: (int.tryParse(costC.text) ?? 0) * 1000,
                price: (int.tryParse(priceC.text) ?? 0) * 1000,
                quantity: qty,
                type: type,
                createdAt: DateTime.now().millisecondsSinceEpoch,
                status: 1,
                supplier: supplier,
              );
              await db.insertProduct(p);
              await db.incrementSupplierStats(supplier!, p.cost * qty);
              Navigator.pop(ctx);
              _refresh();
            }, child: const Text("NHẬP KHO")),
          ],
        ),
      ),
    );
  }

  Future<String?> _showQuickAddSupplier() async {
    final nameC = TextEditingController();
    final contactC = TextEditingController();
    final phoneC = TextEditingController();
    final addressC = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("THÊM NHÀ CUNG CẤP"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameC, decoration: const InputDecoration(labelText: "Tên NCC"), textCapitalization: TextCapitalization.characters),
              TextField(controller: contactC, decoration: const InputDecoration(labelText: "Người bán"), textCapitalization: TextCapitalization.characters),
              TextField(controller: phoneC, decoration: const InputDecoration(labelText: "SĐT"), keyboardType: TextInputType.phone),
              TextField(controller: addressC, decoration: const InputDecoration(labelText: "Địa chỉ"), textCapitalization: TextCapitalization.characters),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              final supplierName = nameC.text.toUpperCase();
              await db.insertSupplier({
                'name': supplierName,
                'contactPerson': contactC.text.toUpperCase(),
                'phone': phoneC.text,
                'address': addressC.text.toUpperCase(),
                'items': "",
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              });
              final list = await db.getSuppliers();
              setState(() => _suppliers = list);
              Navigator.pop(ctx, supplierName);
            },
            child: const Text("LƯU"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("KHO MÁY & PHỤ KIỆN"),
        actions: [
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView())), icon: const Icon(Icons.business)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: _products.length,
            itemBuilder: (ctx, i) {
              final p = _products[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(p.type == 'PHONE' ? Icons.phone_android : Icons.headset)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("NCC: ${p.supplier ?? '---'}\nIMEI: ${p.imei ?? 'N/A'} | SL: ${p.quantity}"),
                  trailing: Text("${NumberFormat('#,###').format(p.price)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        label: const Text("NHẬP HÀNG MỚI"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}
