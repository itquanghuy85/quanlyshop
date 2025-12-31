import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import 'fast_stock_in_view.dart';
import 'supplier_details_dialog.dart';

class SupplierView extends StatefulWidget {
  const SupplierView({super.key});

  @override
  State<SupplierView> createState() => _SupplierViewState();
}

class _SupplierViewState extends State<SupplierView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  // Theme colors cho màn hình nhà cung cấp
  final Color _primaryColor = Colors.orange; // Màu chính cho đơn nhập hàng
  final Color _accentColor = Colors.orange.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refresh();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _isAdmin = perms['allowViewSuppliers'] ?? false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getSuppliers();
    setState(() {
      _suppliers = data;
      _isLoading = false;
    });
  }

  Future<void> _confirmDeleteSupplier(Map<String, dynamic> s) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!_isAdmin) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chỉ tài khoản QUẢN LÝ mới được xóa nhà cung cấp')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA NHÀ CUNG CẤP"),
        content: Text(
          "Bạn chắc chắn muốn xóa nhà cung cấp \"${s['name']}\" khỏi danh sách? Các sản phẩm cũ vẫn giữ nguyên thông tin NCC dạng chữ.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      final firestoreId = s['firestoreId'] as String?;
      if (firestoreId != null) {
        await FirestoreService.deleteSupplier(firestoreId);
      }
      await db.deleteSupplier(s['id'] as int);
      messenger.showSnackBar(
        const SnackBar(content: Text('ĐÃ XÓA NHÀ CUNG CẤP')), 
      );
      _refresh();
    }
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
              final navigator = Navigator.of(ctx);
              await db.insertSupplier({
                'name': nameC.text.toUpperCase(),
                'contactPerson': contactC.text.toUpperCase(),
                'phone': phoneC.text,
                'address': addressC.text.toUpperCase(),
                'items': itemsC.text.toUpperCase(),
                'createdAt': DateTime.now().millisecondsSinceEpoch,
              });
              navigator.pop();
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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("NHÀ CUNG CẤP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FastStockInView(
                                            preselectedSupplier: s['name'],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.inventory, size: 16),
                                    label: const Text("NHẬP KHO", style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showSupplierDetails(s),
                                    icon: const Icon(Icons.history, size: 16),
                                    label: const Text("LỊCH SỬ", style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                  ),
                                ),
                                if (_isAdmin) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () => _confirmDeleteSupplier(s),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text(
                                      "XÓA",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ],
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

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (ctx) => SupplierDetailsDialog(supplier: supplier),
    );
  }

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
