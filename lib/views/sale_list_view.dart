import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/sale_order_model.dart';
import 'create_sale_view.dart';
import 'sale_detail_view.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';

class SaleListView extends StatefulWidget {
  final bool todayOnly;
  const SaleListView({super.key, this.todayOnly = false});

  @override
  State<SaleListView> createState() => _SaleListViewState();
}

class _SaleListViewState extends State<SaleListView> {
  final db = DBHelper();
  List<SaleOrder> _sales = [];
  bool _isLoading = true;
  bool _canDelete = false;

  // Theme colors cho màn hình danh sách bán hàng
  final Color _primaryColor = Colors.cyan; // Màu chính cho danh sách bán hàng
  final Color _accentColor = Colors.cyan.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _refresh();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _canDelete = perms['allowViewSales'] ?? false; // Assuming delete requires sales permission
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getAllSales();
    setState(() {
      _sales = widget.todayOnly ? data.where((s) {
        final d = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
        final now = DateTime.now();
        return d.year == now.year && d.month == now.month && d.day == now.day;
      }).toList() : data;
      _isLoading = false;
    });
  }

  void _confirmDelete(SaleOrder s) {
    if (!_canDelete) return;
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA ĐƠN BÁN"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Nhập lại mật khẩu tài khoản quản lý"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user == null || user.email == null) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không xác định được tài khoản hiện tại')));
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(email: user.email!, password: passCtrl.text);
                await user.reauthenticateWithCredential(cred);
                // Xóa trên Firestore nếu có firestoreId
                if (s.firestoreId != null) {
                  await FirestoreService.deleteSale(s.firestoreId!);
                }
                await db.deleteSale(s.id!);
                Navigator.pop(ctx);
                _refresh();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ XÓA ĐƠN BÁN')));
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không đúng')));
              }
            },
            child: const Text("XÓA"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        title: const Text("DANH SÁCH ĐƠN BÁN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 2,
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(color: _primaryColor))
        : _sales.isEmpty
          ? const Center(child: Text("Chưa có đơn bán hàng nào"))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _sales.length,
              itemBuilder: (ctx, i) {
                final s = _sales[i];
                return Card(
                  elevation: 2,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    onTap: () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: s)));
                      if (res == true) _refresh();
                    },
                    onLongPress: () => _confirmDelete(s),
                    leading: CircleAvatar(
                      backgroundColor: _primaryColor.withOpacity(0.1),
                      child: Icon(Icons.phone_iphone, color: _primaryColor, size: 20),
                    ),
                    title: Text(s.productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Khách: ${s.customerName}"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${NumberFormat('#,###').format(s.totalPrice)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        if (s.isInstallment) Icon(Icons.account_balance_rounded, color: _primaryColor, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateSaleView()));
          if (res == true) _refresh();
        },
        label: const Text("BÁN MÁY MỚI"),
        icon: const Icon(Icons.add_shopping_cart),
        backgroundColor: _primaryColor,
      ),
    );
  }
}
