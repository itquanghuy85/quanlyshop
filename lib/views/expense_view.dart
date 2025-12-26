import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../widgets/validated_text_field.dart';
import '../widgets/currency_text_field.dart';

class ExpenseView extends StatefulWidget {
  const ExpenseView({super.key});
  @override
  State<ExpenseView> createState() => _ExpenseViewState();
}

class _ExpenseViewState extends State<ExpenseView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  String _selectedFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getAllExpenses();
    if (!mounted) return;
    setState(() { _expenses = data; _isLoading = false; });
  }

  void _showAddExpenseDialog() {
    final titleC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String category = "PHÁT SINH";
    String payMethod = "TIỀN MẶT";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("GHI CHÉP CHI PHÍ", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("PHÂN LOẠI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ["CỐ ĐỊNH", "PHÁT SINH", "KHÁC"].map((c) => ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 10)),
                    selected: category == c,
                    onSelected: (v) => setS(() => category = c),
                    selectedColor: Colors.red.shade100,
                  )).toList(),
                ),
                const SizedBox(height: 15),
                _input(titleC, "Nội dung chi *", Icons.edit_note, caps: true),
                _input(amountC, "Số tiền (x1k) *", Icons.payments, type: TextInputType.number, suffix: "k"),
                _input(noteC, "Ghi chú thêm", Icons.description),
                const Text("THANH TOÁN BẰNG", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: ["TIỀN MẶT", "CHUYỂN KHOẢN"].map((m) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: ChoiceChip(
                        label: Text(m, style: const TextStyle(fontSize: 9)),
                        selected: payMethod == m,
                        onSelected: (v) => setS(() => payMethod = m),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (titleC.text.isEmpty || amountC.text.isEmpty) return;
                int amount = int.tryParse(amountC.text.replaceAll('.', '')) ?? 0;
                if (amount > 0 && amount < 100000) amount *= 1000;

                final expData = {
                  'title': titleC.text.toUpperCase(),
                  'amount': amount,
                  'category': category,
                  'date': DateTime.now().millisecondsSinceEpoch,
                  'note': noteC.text,
                  'paymentMethod': payMethod,
                };

                // 1. Lưu local
                await db.insertExpense(expData);
                // 2. Đồng bộ Firebase
                await FirestoreService.addExpenseCloud(expData);
                // 3. Nhật ký
                final user = FirebaseAuth.instance.currentUser;
                await db.logAction(userId: user?.uid ?? "0", userName: user?.email?.split('@').first.toUpperCase() ?? "NV", action: "CHI PHÍ", type: "FINANCE", desc: "Đã chi ${NumberFormat('#,###').format(amount)} đ cho $category");

                Navigator.pop(ctx);
                _refresh();
                NotificationService.showSnackBar("Đã lưu và đồng bộ chi phí!", color: Colors.green);
              }, 
              child: const Text("LƯU CHI PHÍ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {TextInputType type = TextInputType.text, String? suffix, bool caps = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: type == TextInputType.number 
        ? CurrencyTextField(controller: c, label: l, icon: i)
        : ValidatedTextField(controller: c, label: l, icon: i, uppercase: caps),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayExpenses = _expenses.where((e) {
      final d = DateTime.fromMillisecondsSinceEpoch(e['date']);
      return d.day == now.day && d.month == now.month && d.year == now.year;
    }).toList();

    int totalToday = todayExpenses.fold(0, (sum, e) => sum + (e['amount'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("QUẢN LÝ CHI PHÍ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white, elevation: 0,
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh, color: Colors.blue))],
      ),
      body: Column(
        children: [
          _buildProfessionalHeader(totalToday, todayExpenses),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _expenses.isEmpty 
              ? _buildEmpty() 
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) => _expenseProfessionalCard(_expenses[i]),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        label: const Text("CHI PHÍ MỚI", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_circle_outline),
        backgroundColor: const Color(0xFFD32F2F),
      ),
    );
  }

  Widget _buildProfessionalHeader(int total, List<Map<String, dynamic>> list) {
    // Tính toán tỷ lệ cho biểu đồ
    int coDinh = list.where((e) => e['category'] == 'CỐ ĐỊNH').fold(0, (sum, e) => sum + (e['amount'] as int));
    int phatSinh = list.where((e) => e['category'] == 'PHÁT SINH').fold(0, (sum, e) => sum + (e['amount'] as int));
    int khac = list.where((e) => e['category'] == 'KHÁC').fold(0, (sum, e) => sum + (e['amount'] as int));

    return Container(
      width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFFEF5350)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("TỔNG CHI HÔM NAY", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                const SizedBox(height: 5),
                Text("${NumberFormat('#,###').format(total)} đ", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _miniStat("Cố định", coDinh),
                    const SizedBox(width: 10),
                    _miniStat("Phát sinh", phatSinh),
                  ],
                )
              ],
            ),
          ),
          // BIỂU ĐỒ TRÒN NHỎ
          SizedBox(
            width: 80, height: 80,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2, centerSpaceRadius: 20,
                sections: [
                  PieChartSectionData(value: coDinh.toDouble() == 0 ? 1 : coDinh.toDouble(), color: Colors.white, radius: 10, showTitle: false),
                  PieChartSectionData(value: phatSinh.toDouble() == 0 ? 1 : phatSinh.toDouble(), color: Colors.white60, radius: 10, showTitle: false),
                  PieChartSectionData(value: khac.toDouble() == 0 ? 1 : khac.toDouble(), color: Colors.white24, radius: 10, showTitle: false),
                ]
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _miniStat(String label, int val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
        Text(NumberFormat('#,###').format(val), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _expenseProfessionalCard(Map<String, dynamic> e) {
    final cat = e['category'] ?? 'KHÁC';
    final color = cat == 'CỐ ĐỊNH' ? Colors.blue : (cat == 'PHÁT SINH' ? Colors.orange : Colors.grey);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Icon(cat == 'CỐ ĐỊNH' ? Icons.home_work : Icons.shopping_cart, color: color, size: 24),
        ),
        title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("${DateFormat('HH:mm - dd/MM').format(DateTime.fromMillisecondsSinceEpoch(e['date']))} | ${e['paymentMethod']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
              child: Text(cat, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
            )
          ],
        ),
        trailing: Text("-${NumberFormat('#,###').format(e['amount'])}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 15)),
      ),
    );
  }

  Widget _buildEmpty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.money_off_rounded, size: 80, color: Colors.grey[200]), const Text("Chưa ghi nhận chi phí nào", style: TextStyle(color: Colors.grey))]));
}

class _TransactionItem {
  final String title; final int amount; final String method; final int time; final String type; final bool isDebt;
  _TransactionItem({required this.title, required this.amount, required this.method, required this.time, required this.type, required this.isDebt});
}
