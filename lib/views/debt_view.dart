import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';

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

  void _showAddDebtDialog() {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String type = 'CUSTOMER';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("TẠO SỔ NỢ MỚI", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2962FF))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: "Loại đối tượng"),
                items: const [DropdownMenuItem(value: 'CUSTOMER', child: Text("KHÁCH NỢ SHOP")), DropdownMenuItem(value: 'SUPPLIER', child: Text("SHOP NỢ NCC"))],
                onChanged: (v) => type = v!,
              ),
              const SizedBox(height: 12),
              _input(nameC, "Họ tên", Icons.person, caps: true),
              _input(phoneC, "Số điện thoại", Icons.phone, type: TextInputType.phone),
              _input(amountC, "Số tiền nợ (VNĐ)", Icons.money, type: TextInputType.number, isMoney: true),
              _input(noteC, "Lý do / Ghi chú", Icons.note),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty || amountC.text.isEmpty) return;
              int amount = int.tryParse(amountC.text.replaceAll('.', '')) ?? 0;
              if (amount < 10000) amount *= 1000;

              await db.insertDebt({
                'personName': nameC.text.toUpperCase(),
                'phone': phoneC.text,
                'totalAmount': amount,
                'paidAmount': 0,
                'type': type,
                'status': 'NỢ',
                'createdAt': DateTime.now().millisecondsSinceEpoch,
                'note': noteC.text,
              });
              Navigator.pop(ctx);
              _refresh();
              NotificationService.showSnackBar("Đã thêm vào sổ nợ", color: Colors.green);
            },
            child: const Text("LƯU SỔ"),
          ),
        ],
      ),
    );
  }

  void _payDebt(Map<String, dynamic> debt) {
    final payC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("CẬP NHẬT TRẢ NỢ"),
        content: TextField(controller: payC, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: "Nhập số tiền trả thêm", suffixText: ".000 đ")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(onPressed: () async {
            int pay = (int.tryParse(payC.text) ?? 0) * 1000;
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
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("QUẢN LÝ CÔNG NỢ", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2962FF),
          indicatorColor: const Color(0xFF2962FF),
          tabs: const [Tab(text: "KHÁCH NỢ"), Tab(text: "NỢ NCC")],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [_buildDebtList('CUSTOMER'), _buildDebtList('SUPPLIER')],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDebtDialog,
        label: const Text("THÊM NỢ"),
        icon: const Icon(Icons.add_card),
        backgroundColor: const Color(0xFF2962FF),
      ),
    );
  }

  Widget _buildDebtList(String type) {
    final list = _debts.where((d) => d['type'] == type).toList();
    if (list.isEmpty) return const Center(child: Text("Không có dữ liệu công nợ"));

    int total = list.fold(0, (sum, d) => sum + (d['totalAmount'] as int) - (d['paidAmount'] as int? ?? 0));

    return Column(
      children: [
        _summaryHeader(type == 'CUSTOMER' ? "TỔNG KHÁCH ĐANG NỢ" : "TỔNG SHOP ĐANG NỢ", total, type == 'CUSTOMER' ? Colors.redAccent : Colors.blueAccent),
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
      child: Column(children: [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 4), Text("${NumberFormat('#,###').format(amount)} đ", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 24))]),
    );
  }

  Widget _debtCard(Map<String, dynamic> d) {
    final int total = d['totalAmount'];
    final int paid = d['paidAmount'] ?? 0;
    final int remain = total - paid;
    final double progress = total > 0 ? paid / total : 0;
    final bool isPaid = d['status'] == 'ĐÃ TRẢ' || remain <= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(d['personName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: isPaid ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(isPaid ? "ĐÃ TRẢ" : "CÒN NỢ", style: TextStyle(color: isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text("Lý do: ${d['note'] ?? 'Không có ghi chú'}", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Đã trả: ${NumberFormat('#,###').format(paid)}", style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                Text("Còn lại: ${NumberFormat('#,###').format(remain)}", style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey.shade200, color: Colors.green)),
            if (!isPaid) Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _payDebt(d), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text("CẬP NHẬT TRẢ TIỀN", style: TextStyle(fontWeight: FontWeight.bold)))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {bool caps = false, TextInputType type = TextInputType.text, bool isMoney = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, keyboardType: type, textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        decoration: InputDecoration(labelText: l, prefixIcon: Icon(i, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}
