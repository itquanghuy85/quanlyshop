import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../services/user_service.dart';

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
    final data = await db.getAllExpenses();
    setState(() {
      _expenses = data;
      _isLoading = false;
    });
  }

  void _confirmDeleteExpense(int id) {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ tài khoản quản lý mới được xóa chi phí')));
      return;
    }
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC NHẬN XÓA CHI PHÍ"),
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
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không xác định được tài khoản hiện tại')));
                return;
              }
              try {
                final cred = EmailAuthProvider.credential(email: user.email!, password: passCtrl.text);
                await user.reauthenticateWithCredential(cred);
                await db.deleteExpense(id);
                if (!mounted) return;
                Navigator.pop(ctx);
                _refresh();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ĐÃ XÓA CHI PHÍ')));
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu không đúng')));
              }
            },
            child: const Text("XÓA"),
          ),
        ],
      ),
    );
  }

  void _addExpense() {
    final titleC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String category = "KHÁC";
    String payMethod = "TIỀN MẶT";

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSB) => AlertDialog(
            title: const Text("THÊM CHI PHÍ MỚI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleC, decoration: const InputDecoration(labelText: "Nội dung chi (VD: Tiền điện)")),
                TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Số tiền", suffixText: ".000 đ")),
                TextField(controller: noteC, decoration: const InputDecoration(labelText: "Ghi chú")),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _payChip("TIỀN MẶT", payMethod, (v) => setStateSB(() => payMethod = v)),
                      _payChip("CHUYỂN KHOẢN", payMethod, (v) => setStateSB(() => payMethod = v)),
                      _payChip("CÔNG NỢ", payMethod, (v) => setStateSB(() => payMethod = v)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
              ElevatedButton(onPressed: () async {
                if (titleC.text.isEmpty || amountC.text.isEmpty) return;
                await db.insertExpense({
                  'title': titleC.text.toUpperCase(),
                  'amount': (int.tryParse(amountC.text) ?? 0) * 1000,
                  'category': category,
                  'date': DateTime.now().millisecondsSinceEpoch,
                  'note': noteC.text,
                  'paymentMethod': payMethod,
                });
                Navigator.pop(ctx);
                _refresh();
              }, child: const Text("LƯU")),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int total = _expenses.fold(0, (sum, e) => sum + (e['amount'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("CHI PHÍ CỬA HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.red.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TỔNG CHI THÁNG NÀY:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("${NumberFormat('#,###').format(total)} đ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _expenses.length,
                  itemBuilder: (ctx, i) {
                    final e = _expenses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(e['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          "${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(e['date']))} | ${e['paymentMethod'] ?? 'TIỀN MẶT'}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text("- ${NumberFormat('#,###').format(e['amount'])} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        onLongPress: () => _confirmDeleteExpense(e['id']),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpense,
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

Widget _payChip(String label, String current, ValueChanged<String> onSelect) {
  final isSelected = current == label;
  return ChoiceChip(
    label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
    selected: isSelected,
    selectedColor: Colors.blueAccent,
    backgroundColor: Colors.grey.shade200,
    onSelected: (_) => onSelect(label),
  );
}
