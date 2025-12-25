import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../widgets/currency_text_field.dart';

class DebtView extends StatefulWidget {
  const DebtView({super.key});
  @override
  State<DebtView> createState() => _DebtViewState();
}

class _DebtViewState extends State<DebtView> with SingleTickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;
  List<Map<String, dynamic>> _debts = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRole();
    _refresh();
  }

  Future<void> _loadRole() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _isAdmin = perms['allowViewDebts'] ?? false);
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getAllDebts();
    if (!mounted) return;
    setState(() { _debts = data; _isLoading = false; });
  }

  void _payDebt(Map<String, dynamic> debt) {
    final payC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("CẬP NHẬT TRẢ NỢ"),
        content: CurrencyTextField(
          controller: payC,
          label: "SỐ TIỀN KHÁCH TRẢ THÊM",
          onSubmitted: () {
            // Handle submission if needed
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(onPressed: () async {
            int pay = int.tryParse(payC.text.replaceAll('.', '')) ?? 0;
            await db.updateDebtPaid(debt['id'], pay);
            Navigator.pop(ctx);
            _refresh();
            NotificationService.showSnackBar("Đã cập nhật tiền nợ", color: Colors.blue);
          }, child: const Text("XÁC NHẬN")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("QUẢN LÝ CÔNG NỢ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2962FF),
          indicatorColor: const Color(0xFF2962FF),
          tabs: const [Tab(text: "KHÁCH NỢ"), Tab(text: "SHOP NỢ NCC")],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [_buildDebtList('CUSTOMER_OWES'), _buildDebtList('SHOP_OWES')],
      ),
    );
  }

  Widget _buildDebtList(String type) {
    // LỌC DỮ LIỆU THEO CHUẨN MỚI
    final list = _debts.where((d) => d['type'] == type).toList();
    if (list.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]), const SizedBox(height: 10), const Text("Hiện tại không có khoản nợ nào", style: TextStyle(color: Colors.grey))]));

    int total = list.fold(0, (sum, d) => sum + (d['totalAmount'] as int) - (d['paidAmount'] as int? ?? 0));

    return Column(
      children: [
        _summaryHeader(type == 'CUSTOMER_OWES' ? "TỔNG KHÁCH ĐANG NỢ" : "TỔNG SHOP ĐANG NỢ NCC", total, type == 'CUSTOMER_OWES' ? Colors.redAccent : Colors.blueAccent),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _debtCard(list[i]),
          ),
        ),
      ],
    );
  }

  Widget _summaryHeader(String label, int amount, Color color) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(children: [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)), const SizedBox(height: 4), Text("${NumberFormat('#,###').format(amount)} đ", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24))]),
    );
  }

  Widget _debtCard(Map<String, dynamic> d) {
    final int total = d['totalAmount'];
    final int paid = d['paidAmount'] ?? 0;
    final int remain = total - paid;
    final bool isPaid = remain <= 0;
    final date = DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(d['createdAt']));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(d['personName'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Text(date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d['phone'] != null) Text("SĐT: ${d['phone']}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
            Text("Nội dung: ${d['note'] ?? ''}", style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Đã trả: ${NumberFormat('#,###').format(paid)}", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                Text("Còn nợ: ${NumberFormat('#,###').format(remain)}", style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        trailing: isPaid ? const Icon(Icons.check_circle, color: Colors.green) : ElevatedButton(
          onPressed: () => _payDebt(d),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text("TRẢ NỢ", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
