import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/product_model.dart';
import '../models/sale_order_model.dart';
import '../services/notification_service.dart';
import '../services/user_service.dart';
import '../services/firestore_service.dart';
import '../widgets/currency_text_field.dart';
import 'debt_view.dart';
import 'warranty_view.dart'; // Import trang bảo hành

class RevenueView extends StatefulWidget {
  const RevenueView({super.key});
  @override
  State<RevenueView> createState() => _RevenueViewState();
}

class _RevenueViewState extends State<RevenueView> with SingleTickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;
  
  List<Repair> _repairs = [];
  List<SaleOrder> _sales = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _closings = [];
  bool _hasRevenueAccess = false;
  bool _isLoading = true;
  String _selectedPeriod = 'Tháng này';

  final cashEndCtrl = TextEditingController();
  final bankEndCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this); // Nâng lên 7 tab
    _loadPermissions();
    _loadAllData();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() { _hasRevenueAccess = perms['allowViewRevenue'] ?? false; });
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final expenses = await db.getAllExpenses();
    
    final dbRaw = await db.database;
    final closings = await dbRaw.query('cash_closings', orderBy: 'createdAt DESC', limit: 10);
    
    if (!mounted) return;
    setState(() {
      _repairs = repairs; _sales = sales; _expenses = expenses; _closings = closings;
      _isLoading = false;
    });
  }

  bool _isSameDay(int ms, DateTime day) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return dt.day == day.day && dt.month == day.month && dt.year == day.year;
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasRevenueAccess) return const Scaffold(body: Center(child: Text("Bạn không có quyền truy cập")));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("QUẢN LÝ TÀI CHÍNH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController, isScrollable: true,
          labelColor: const Color(0xFF2962FF), indicatorColor: const Color(0xFF2962FF),
          tabs: const [
            Tab(text: "TỔNG QUAN"), 
            Tab(text: "CHỐT QUỸ"), 
            Tab(text: "BÁN HÀNG"), 
            Tab(text: "SỬA CHỮA"), 
            Tab(text: "BẢO HÀNH"), // Khôi phục Tab Bảo hành
            Tab(text: "CHI TIÊU"), 
            Tab(text: "CÔNG NỢ")
          ],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [
          _buildOverview(),
          _buildCashClosingTab(),
          _buildSaleDetail(),
          _buildRepairDetail(),
          const WarrantyView(), // View Bảo hành
          _buildExpenseDetail(),
          const DebtView()
        ],
      ),
    );
  }

  Widget _buildCashClosingTab() {
    final now = DateTime.now();
    List<_TransactionItem> todayTrans = [];
    
    for (var s in _sales.where((s) => _isSameDay(s.soldAt, now))) {
      todayTrans.add(_TransactionItem(title: "Bán: ${s.productNames}", amount: s.totalPrice, method: s.paymentMethod, time: s.soldAt, type: "IN", isDebt: s.paymentMethod == "CÔNG NỢ"));
    }
    for (var r in _repairs.where((r) => r.status >= 3 && _isSameDay(r.deliveredAt ?? r.createdAt, now))) {
      todayTrans.add(_TransactionItem(title: "Sửa: ${r.model}", amount: r.price, method: r.paymentMethod, time: r.deliveredAt ?? r.createdAt, type: "IN", isDebt: r.paymentMethod == "CÔNG NỢ"));
    }
    for (var e in _expenses.where((e) => _isSameDay(e['date'] as int, now))) {
      todayTrans.add(_TransactionItem(title: "Chi: ${e['title']}", amount: e['amount'], method: e['paymentMethod'] ?? 'TIỀN MẶT', time: e['date'], type: "OUT", isDebt: false));
    }
    todayTrans.sort((a, b) => b.time.compareTo(a.time));

    int cashExp = todayTrans.where((t) => t.type == "IN" && !t.isDebt && t.method == "TIỀN MẶT").fold(0, (sum, t) => sum + t.amount) - 
                 todayTrans.where((t) => t.type == "OUT" && t.method == "TIỀN MẶT").fold(0, (sum, t) => sum + t.amount);
    int bankExp = todayTrans.where((t) => t.type == "IN" && !t.isDebt && t.method == "CHUYỂN KHOẢN").fold(0, (sum, t) => sum + t.amount) - 
                 todayTrans.where((t) => t.type == "OUT" && t.method == "CHUYỂN KHOẢN").fold(0, (sum, t) => sum + t.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [_balanceCard("TIỀN MẶT DỰ TÍNH", cashExp, Colors.orange), const SizedBox(width: 12), _balanceCard("NGÂN HÀNG DỰ TÍNH", bankExp, Colors.blue)]),
        const SizedBox(height: 24),
        _inputClosingSection(),
        const SizedBox(height: 30),
        const Text("LỊCH SỬ CHỐT QUỸ GẦN ĐÂY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        ..._closings.map((c) => _buildClosingHistoryRow(c)).toList(),
      ],
    );
  }

  Widget _inputClosingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(children: [
        const Text("ĐỐI SOÁT THỰC TẾ", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        CurrencyTextField(controller: cashEndCtrl, label: "TIỀN MẶT ĐẾM ĐƯỢC", icon: Icons.payments),
        const SizedBox(height: 12),
        CurrencyTextField(controller: bankEndCtrl, label: "SỐ DƯ NGÂN HÀNG THỰC TẾ", icon: Icons.account_balance),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _saveClosing, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF)), child: const Text("XÁC NHẬN CHỐT QUỸ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
      ]),
    );
  }

  Future<void> _saveClosing() async {
    final cash = int.tryParse(cashEndCtrl.text.replaceAll('.', '')) ?? 0;
    final bank = int.tryParse(bankEndCtrl.text.replaceAll('.', '')) ?? 0;
    
    if (cash == 0 && bank == 0) {
      NotificationService.showSnackBar("Vui lòng nhập số tiền thực tế", color: Colors.orange);
      return;
    }

    final data = {
      'dateKey': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'cashEnd': cash,
      'bankEnd': bank,
      'createdAt': DateTime.now().millisecondsSinceEpoch
    };

    await db.upsertClosing(data);
    
    final user = FirebaseAuth.instance.currentUser;
    await db.logAction(
      userId: user?.uid ?? "0",
      userName: user?.email?.split('@').first.toUpperCase() ?? "ADMIN",
      action: "CHỐT QUỸ",
      type: "FINANCE",
      desc: "Chốt quỹ ngày: Tiền mặt ${NumberFormat('#,###').format(cash)}đ, Ngân hàng ${NumberFormat('#,###').format(bank)}đ"
    );

    NotificationService.showSnackBar("Đã chốt quỹ thành công!", color: Colors.green);
    HapticFeedback.mediumImpact(); 
    _loadAllData();
    cashEndCtrl.clear(); bankEndCtrl.clear();
  }

  Widget _buildClosingHistoryRow(Map<String, dynamic> c) {
    final fmt = NumberFormat('#,###');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text("Ngày: ${c['dateKey']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("TM: ${fmt.format(c['cashEnd'])}đ | NH: ${fmt.format(c['bankEnd'])}đ", style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.check_circle, color: Colors.green, size: 18),
      ),
    );
  }

  Widget _balanceCard(String l, int v, Color c) => Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.bold)), Text(NumberFormat('#,###').format(v), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c))])));

  Widget _buildOverview() {
    final now = DateTime.now();
    final fSales = _sales.where((s) => _isSameDay(s.soldAt, now)).toList();
    final fRepairs = _repairs.where((r) => r.status >= 3 && _isSameDay(r.deliveredAt ?? r.createdAt, now)).toList();
    final fExpenses = _expenses.where((e) => _isSameDay(e['date'] as int, now)).toList();
    int totalIn = fSales.fold(0, (sum, s) => sum + s.totalPrice) + fRepairs.fold(0, (sum, r) => sum + r.price);
    int totalOut = fExpenses.fold(0, (sum, e) => sum + (e['amount'] as int));
    
    int profit = totalIn - totalOut - fSales.fold<int>(0, (sum, s) => sum + s.totalCost) - fRepairs.fold<int>(0, (sum, r) => sum + r.cost);
    
    return ListView(padding: const EdgeInsets.all(16), children: [Row(children: [_miniCard("THU HÔM NAY", totalIn, Colors.green), const SizedBox(width: 12), _miniCard("CHI HÔM NAY", totalOut, Colors.redAccent)]), const SizedBox(height: 16), _mainProfitCard(profit)]);
  }
  Widget _miniCard(String l, int v, Color c) => Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(NumberFormat('#,###').format(v), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c))])));
  Widget _mainProfitCard(int p) => Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF00B0FF)]), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Text("LỢI NHUẬN RÒNG HÔM NAY", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("${NumberFormat('#,###').format(p)} đ", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))]));
  Widget _buildSaleDetail() { final list = _sales.where((s) => _isSameDay(s.soldAt, DateTime.now())).toList(); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) => Card(child: ListTile(title: Text(list[i].productNames), subtitle: Text("Khách: ${list[i].customerName}"), trailing: Text("+${NumberFormat('#,###').format(list[i].totalPrice)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))))); }
  Widget _buildRepairDetail() { final list = _repairs.where((r) => r.status >= 3 && _isSameDay(r.deliveredAt ?? r.createdAt, DateTime.now())).toList(); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) => Card(child: ListTile(title: Text(list[i].model), subtitle: Text("Khách: ${list[i].customerName}"), trailing: Text("+${NumberFormat('#,###').format(list[i].price)}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))))); }
  Widget _buildExpenseDetail() { final list = _expenses.where((e) => _isSameDay(e['date'] as int, DateTime.now())).toList(); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) => Card(child: ListTile(title: Text(list[i]['title'] ?? 'Chi phí'), subtitle: Text(list[i]['category'] ?? 'Khác'), trailing: Text("-${NumberFormat('#,###').format(list[i]['amount'])}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))))); }
}

class _TransactionItem {
  final String title; final int amount; final String method; final int time; final String type; final bool isDebt;
  _TransactionItem({required this.title, required this.amount, required this.method, required this.time, required this.type, required this.isDebt});
}
