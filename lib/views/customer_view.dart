import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/user_service.dart';
import 'repair_detail_view.dart';

class CustomerListView extends StatefulWidget {
  final String role;
  const CustomerListView({super.key, this.role = 'user'});

  @override
  State<CustomerListView> createState() => _CustomerListViewState();
}

class _CustomerListViewState extends State<CustomerListView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refresh();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final role = await UserService.getUserRole(uid);
    if (!mounted) return;
    setState(() {
      _isAdmin = role == 'admin';
    });
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getUniqueCustomersAll();
    setState(() {
      _customers = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("HỆ THỐNG KHÁCH HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _customers.isEmpty
          ? const Center(child: Text("Chưa có dữ liệu khách hàng"))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i];
                return _customerCard(c);
              },
            ),
    );
  }

  Widget _customerCard(Map<String, dynamic> c) {
    final bool canDelete = _isAdmin && (c['repairCount'] as int? ?? 0) == 0 && (c['saleCount'] as int? ?? 0) == 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showCustomerFullHistory(c),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${c['customerName']}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: "Xóa khách khỏi danh sách",
                      onPressed: () => _confirmDeleteCustomer(c),
                    ),
                  Text(
                    "${NumberFormat('#,###').format(c['totalSpent'])} đ",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text("SĐT: ${c['phone']}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              if ((c['address'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    "Địa chỉ: ${c['address']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              const Divider(height: 20),
              Row(
                children: [
                  _miniStat(Icons.build_circle_outlined, "${c['repairCount']} lần sửa", Colors.blue),
                  const SizedBox(width: 20),
                  _miniStat(Icons.shopping_bag_outlined, "${c['saleCount']} máy đã mua", Colors.pink),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showCustomerFullHistory(Map<String, dynamic> c) async {
    final allRepairs = await db.getAllRepairs();
    final allSales = await db.getAllSales();
    
    final repairHistory = allRepairs.where((r) => r.phone == c['phone']).toList();
    final saleHistory = allSales.where((s) => s.phone == c['phone']).toList();

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(c['customerName'].toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Tổng chi tiêu: ${NumberFormat('#,###').format(c['totalSpent'])} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.blueAccent,
                      tabs: [
                        Tab(text: "LỊCH SỬ SỬA MÁY"),
                        Tab(text: "MÁY ĐÃ MUA"),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRepairHistoryList(repairHistory),
                          _buildSaleHistoryList(saleHistory),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepairHistoryList(List<Repair> list) {
    if (list.isEmpty) return const Center(child: Text("Chưa có lịch sử sửa chữa"));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final r = list[i];
        return ListTile(
          title: Text(r.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("Lỗi: ${r.issue.split('|').first}\nNgày: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt))}"),
          trailing: Text("${NumberFormat('#,###').format(r.price)} đ", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          onTap: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: r, role: widget.role)));
          },
        );
      },
    );
  }

  Widget _buildSaleHistoryList(List<SaleOrder> list) {
    if (list.isEmpty) return const Center(child: Text("Chưa có máy đã mua"));
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final s = list[i];
        return ListTile(
          leading: const Icon(Icons.phone_iphone, color: Colors.pink),
          title: Text(s.productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text("IMEI: ${s.productImeis}\nNgày mua: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt))}"),
          trailing: Text("${NumberFormat('#,###').format(s.totalPrice)} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Future<void> _confirmDeleteCustomer(Map<String, dynamic> c) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ tài khoản QUẢN LÝ mới được xóa khách hàng khỏi danh sách')),
      );
      return;
    }

    final hasHistory = (c['repairCount'] as int? ?? 0) > 0 || (c['saleCount'] as int? ?? 0) > 0;
    if (hasHistory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xóa khách đã có lịch sử sửa/bán.')), 
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA KHÁCH HÀNG"),
        content: Text(
          "Bạn chắc chắn muốn xóa khách ${c['customerName']} (${c['phone']}) khỏi danh sách? Hành động này chỉ xóa khỏi DANH BẠ, không xóa lịch sử sửa/bán.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      await db.deleteCustomerByPhone(c['phone'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ĐÃ XÓA KHÁCH KHỎI DANH BẠ')), 
      );
      _refresh();
    }
  }
}
