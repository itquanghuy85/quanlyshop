import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/sale_order_model.dart';
import 'create_sale_view.dart';
import 'sale_detail_view.dart';

class SaleListView extends StatefulWidget {
  final String role;
  final bool todayOnly;
  const SaleListView({super.key, required this.role, this.todayOnly = false});

  @override
  State<SaleListView> createState() => _SaleListViewState();
}

class _SaleListViewState extends State<SaleListView> {
  final db = DBHelper();
  List<SaleOrder> _sales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
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
    if (widget.role != 'admin') return;
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("DANH SÁCH ĐƠN BÁN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
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
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: s, role: widget.role)));
                      if (res == true) _refresh();
                    },
                    onLongPress: () => _confirmDelete(s),
                    leading: CircleAvatar(
                      backgroundColor: Colors.pink.withOpacity(0.1),
                      child: Icon(Icons.phone_iphone, color: Colors.pink, size: 20),
                    ),
                    title: Text(s.productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("Khách: ${s.customerName}"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text("${NumberFormat('#,###').format(s.totalPrice)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        if (s.isInstallment) const Icon(Icons.account_balance_rounded, color: Colors.blue, size: 14),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateSaleView(role: widget.role)));
          if (res == true) _refresh();
        },
        label: const Text("BÁN MÁY MỚI"),
        icon: const Icon(Icons.add_shopping_cart),
        backgroundColor: Colors.pink,
      ),
    );
  }
}
