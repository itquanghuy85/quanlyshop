import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';

class ExpenseView extends StatefulWidget {
  const ExpenseView({super.key});

  @override
  State<ExpenseView> createState() => _ExpenseViewState();
}

class _ExpenseViewState extends State<ExpenseView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final data = await db.getAllExpenses();
    setState(() {
      _expenses = data;
      _isLoading = false;
    });
  }

  void _addExpense() {
    final titleC = TextEditingController();
    final amountC = TextEditingController();
    final noteC = TextEditingController();
    String category = "KHÁC";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("THÊM CHI PHÍ MỚI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleC, decoration: const InputDecoration(labelText: "Nội dung chi (VD: Tiền điện)")),
            TextField(controller: amountC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Số tiền", suffixText: ".000 đ")),
            TextField(controller: noteC, decoration: const InputDecoration(labelText: "Ghi chú")),
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
            });
            Navigator.pop(ctx);
            _refresh();
          }, child: const Text("LƯU")),
        ],
      ),
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
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(e['date']))),
                        trailing: Text("- ${NumberFormat('#,###').format(e['amount'])} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        onLongPress: () async {
                          await db.deleteExpense(e['id']);
                          _refresh();
                        },
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
