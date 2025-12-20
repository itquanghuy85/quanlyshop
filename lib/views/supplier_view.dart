import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';

class SupplierView extends StatefulWidget {
  const SupplierView({super.key});

  @override
  State<SupplierView> createState() => _SupplierViewState();
}

class _SupplierViewState extends State<SupplierView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getSuppliers();
    setState(() {
      _suppliers = data;
      _isLoading = false;
    });
  }

  void _showAddSupplier() {
    final nameC = TextEditingController();
    final contactC = TextEditingController();
    final phoneC = TextEditingController();
    final addressC = TextEditingController();
    final itemsC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("THÊM NHÀ CUNG CẤP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(nameC, "Tên nhà cung cấp (VD: Kho Hà Nội)", true),
              const SizedBox(height: 10),
              _input(contactC, "Người liên hệ / Bán hàng", false),
              const SizedBox(height: 10),
              _input(phoneC, "Số điện thoại", false, TextInputType.phone),
              const SizedBox(height: 10),
              _input(addressC, "Địa chỉ", false),
              const SizedBox(height: 10),
              _input(itemsC, "Các mặt hàng cung cấp", false),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              await db.insertSupplier({
                'name': nameC.text.toUpperCase(),
                'contactPerson': contactC.text.toUpperCase(),
                'phone': phoneC.text,
                'address': addressC.text.toUpperCase(),
                'items': itemsC.text.toUpperCase(),
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              });
              Navigator.pop(ctx);
              _refresh();
            },
            child: const Text("LƯU"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("NHÀ CUNG CẤP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _suppliers.isEmpty
          ? const Center(child: Text("Chưa có nhà cung cấp nào"))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _suppliers.length,
              itemBuilder: (ctx, i) {
                final s = _suppliers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ExpansionTile(
                    title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    subtitle: Text("Số lần nhập: ${s['importCount']}", style: const TextStyle(fontSize: 12)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _infoRowSimple("Người bán", s['contactPerson']),
                            _infoRowSimple("SĐT", s['phone']),
                            _infoRowSimple("Địa chỉ", s['address']),
                            _infoRowSimple("Mặt hàng", s['items']),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("TỔNG TIỀN NHẬP:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text("${NumberFormat('#,###').format(s['totalAmount'])} đ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSupplier,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, bool caps, [TextInputType type = TextInputType.text]) => TextField(controller: ctrl, keyboardType: type, textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()));

  Widget _infoRowSimple(String label, String? val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label: ", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(val ?? "Trống", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
