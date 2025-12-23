import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';

class ExpenseView extends StatefulWidget {
  const ExpenseView({super.key});
  @override
  State<ExpenseView> createState() => _ExpenseViewState();
}

class _ExpenseViewState extends State<ExpenseView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _refresh();
  }

  Future<void> _loadRole() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _isAdmin = perms['allowViewExpenses'] ?? false);
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
    final titleF = FocusNode();
    final amountF = FocusNode();
    final noteF = FocusNode();
    String payMethod = "TIỀN MẶT";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("THÊM CHI TIÊU MỚI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _input(titleC, "Nội dung chi (VD: Linh kiện)", Icons.shopping_basket, f: titleF, next: amountF, caps: true),
                _input(amountC, "Số tiền", Icons.money, type: TextInputType.number, f: amountF, next: noteF, suffix: "k", hint: "Ví dụ: 50 = 50.000"),
                _input(noteC, "Ghi chú thêm", Icons.edit_note, f: noteF),
                const SizedBox(height: 10),
                const Align(alignment: Alignment.centerLeft, child: Text("PHƯƠNG THỨC THANH TOÁN", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((e) => ChoiceChip(
                    label: Text(e, style: const TextStyle(fontSize: 11)),
                    selected: payMethod == e,
                    onSelected: (v) => setModalState(() => payMethod = e),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (titleC.text.isEmpty || amountC.text.isEmpty) return;
                
                // Quy ước K: Nếu nhập dưới 100.000 thì nhân với 1000
                int amount = int.tryParse(amountC.text.replaceAll('.', '')) ?? 0;
                if (amount > 0 && amount < 100000) amount *= 1000;

                await db.insertExpense({
                  'title': titleC.text.toUpperCase(),
                  'amount': amount,
                  'category': 'KHÁC',
                  'date': DateTime.now().millisecondsSinceEpoch,
                  'note': noteC.text,
                  'paymentMethod': payMethod,
                });
                Navigator.pop(ctx);
                _refresh();
                NotificationService.showSnackBar("Đã lưu chi phí mới", color: Colors.green);
              }, 
              child: const Text("LƯU CHI PHÍ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, {FocusNode? f, FocusNode? next, TextInputType type = TextInputType.text, String? suffix, String? hint, bool caps = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, focusNode: f, keyboardType: type,
        textCapitalization: caps ? TextCapitalization.characters : TextCapitalization.none,
        onSubmitted: (_) { if (next != null) FocusScope.of(context).requestFocus(next); },
        decoration: InputDecoration(
          labelText: l, prefixIcon: Icon(i, size: 20), suffixText: suffix, hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int total = _expenses.fold(0, (sum, e) => sum + (e['amount'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("DANH SÁCH CHI TIÊU", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
      ),
      body: Column(
        children: [
          _summaryHeader(total),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _expenses.length,
              itemBuilder: (ctx, i) => _expenseCard(_expenses[i]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        label: const Text("THÊM CHI PHÍ"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _summaryHeader(int total) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF5252), Color(0xFFFF8A80)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        const Text("TỔNG CHI TIÊU HÔM NAY", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("${NumberFormat('#,###').format(total)} đ", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _expenseCard(Map<String, dynamic> e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.outbox_rounded, color: Colors.redAccent)),
        title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text("${DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(e['date']))} | ${e['paymentMethod'] ?? 'TIỀN MẶT'}", style: const TextStyle(fontSize: 11)),
        trailing: Text("-${NumberFormat('#,###').format(e['amount'])}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }
}
