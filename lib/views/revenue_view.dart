import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../services/notification_service.dart';

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
  bool _isLoading = true;
  String _selectedPeriod = 'Tháng này';

  final cashEndCtrl = TextEditingController();
  final bankEndCtrl = TextEditingController();
  final closingNoteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final expenses = await db.getAllExpenses();
    final closings = await db.getInventoryChecks(); // Tạm dùng bảng này
    if (!mounted) return;
    setState(() {
      _repairs = repairs; _sales = sales; _expenses = expenses; _closings = closings;
      _isLoading = false;
    });
  }

  bool _inRange(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (_selectedPeriod == 'Hôm nay') return dt.day == now.day && dt.month == now.month && dt.year == now.year;
    if (_selectedPeriod == 'Tháng này') return dt.month == now.month && dt.year == now.year;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("QUẢN LÝ TÀI CHÍNH", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox(),
            items: ['Hôm nay', 'Tháng này', 'Tất cả'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) { if(v!=null) setState(() => _selectedPeriod = v); },
          ),
          IconButton(onPressed: _loadAllData, icon: const Icon(Icons.refresh, color: Color(0xFF2962FF))),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF2962FF),
          indicatorColor: const Color(0xFF2962FF),
          tabs: const [Tab(text: "TỔNG QUAN"), Tab(text: "CHỐT QUỸ"), Tab(text: "BÁN HÀNG"), Tab(text: "SỬA CHỮA"), Tab(text: "CHI TIÊU")],
        ),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabController,
        children: [
          _buildOverview(),
          _buildCashClosingTab(),
          _buildSaleDetail(),
          _buildRepairDetail(),
          _buildExpenseDetail(),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    final fSales = _sales.where((s) => _inRange(s.soldAt)).toList();
    final fRepairs = _repairs.where((r) => r.status >= 3 && _inRange(r.deliveredAt ?? r.createdAt)).toList();
    final fExpenses = _expenses.where((e) => _inRange(e['date'] as int)).toList();

    int totalIn = fSales.fold(0, (sum, s) => sum + s.totalPrice) + fRepairs.fold(0, (sum, r) => sum + r.price);
    int totalOut = fExpenses.fold(0, (sum, e) => sum + (e['amount'] as int));
    
    // SỬA LỖI: Sử dụng .toInt() để đảm bảo kiểu dữ liệu là int
    int profit = (totalIn - totalOut - 
                 fSales.fold(0, (sum, s) => sum + s.totalCost) - 
                 fRepairs.fold(0, (sum, r) => sum + r.cost)).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [_miniCard("TỔNG THU", totalIn, Colors.green), const SizedBox(width: 12), _miniCard("TỔNG CHI", totalOut, Colors.redAccent)]),
        const SizedBox(height: 16),
        _mainProfitCard(profit),
        const SizedBox(height: 24),
        Container(
          height: 220, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25)),
          child: PieChart(PieChartData(sections: [
            PieChartSectionData(value: fSales.length.toDouble(), title: "Bán", color: Colors.pinkAccent, radius: 50),
            PieChartSectionData(value: fRepairs.length.toDouble(), title: "Sửa", color: Colors.blueAccent, radius: 50)
          ])),
        ),
      ],
    );
  }

  Widget _buildCashClosingTab() {
    final todaySales = _sales.where((s) => _inRange(s.soldAt)).toList();
    final todayRepairs = _repairs.where((r) => r.status >= 3 && _inRange(r.deliveredAt ?? r.createdAt)).toList();
    final todayExpenses = _expenses.where((e) => _inRange(e['date'] as int)).toList();

    int cashIn = 0, bankIn = 0, cashOut = 0, bankOut = 0;
    for (var s in todaySales) {
      if (s.paymentMethod == 'CHUYỂN KHOẢN') bankIn += s.totalPrice;
      else cashIn += s.totalPrice;
    }
    for (var r in todayRepairs) {
      if (r.paymentMethod == 'CHUYỂN KHOẢN') bankIn += r.price;
      else cashIn += r.price;
    }
    for (var e in todayExpenses) {
      final method = (e['paymentMethod'] ?? 'TIỀN MẶT').toString().toUpperCase();
      if (method == 'CHUYỂN KHOẢN') bankOut += (e['amount'] as int);
      else cashOut += (e['amount'] as int);
    }

    int expectedCash = cashIn - cashOut;
    int expectedBank = bankIn - bankOut;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [_balanceCard("TIỀN MẶT", expectedCash, Colors.orange), const SizedBox(width: 12), _balanceCard("NGÂN HÀNG", expectedBank, Colors.blue)]),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)]),
          child: Column(
            children: [
              const Text("ĐỐI SOÁT THỰC TẾ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              _closingField(cashEndCtrl, "Tiền mặt đếm được", Icons.payments, Colors.orange),
              _closingField(bankEndCtrl, "Số dư ngân hàng", Icons.account_balance, Colors.blue),
              _closingField(closingNoteCtrl, "Ghi chú", Icons.edit_note, Colors.grey, isText: true),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _saveClosing, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), child: const Text("XÁC NHẬN CHỐT QUỸ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balanceCard(String label, int value, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)), Text("${NumberFormat('#,###').format(value)} đ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))])));
  }

  Widget _closingField(TextEditingController c, String label, IconData icon, Color color, {bool isText = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(controller: c, keyboardType: isText ? TextInputType.text : TextInputType.number, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: color), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: const Color(0xFFF8FAFF))));
  }

  Widget _miniCard(String label, int value, Color color) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text(NumberFormat('#,###').format(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color))])));
  }

  Widget _mainProfitCard(int profit) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF00B0FF)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]), child: Column(children: [const Text("LỢI NHUẬN RÒNG DỰ KIẾN", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("${NumberFormat('#,###').format(profit)} VND", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))]));
  }

  Future<void> _saveClosing() async {
    final cash = int.tryParse(cashEndCtrl.text.replaceAll('.', '')) ?? 0;
    final bank = int.tryParse(bankEndCtrl.text.replaceAll('.', '')) ?? 0;
    final closing = {
      'dateKey': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'cashEnd': cash < 10000 ? cash * 1000 : cash,
      'bankEnd': bank < 10000 ? bank * 1000 : bank,
      'note': closingNoteCtrl.text,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await db.upsertClosing(closing);
    NotificationService.showSnackBar("Đã chốt quỹ thành công!", color: Colors.green);
    _loadAllData();
    cashEndCtrl.clear(); bankEndCtrl.clear(); closingNoteCtrl.clear();
  }

  Widget _buildSaleDetail() {
    final list = _sales.where((s) => _inRange(s.soldAt)).toList();
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(title: Text(list[i].productNames, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Ngày: ${DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(list[i].soldAt))}"), trailing: Text("+${NumberFormat('#,###').format(list[i].totalPrice)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))));
  }

  Widget _buildRepairDetail() {
    final list = _repairs.where((r) => r.status >= 3 && _inRange(r.deliveredAt ?? r.createdAt)).toList();
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(title: Text(list[i].model, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(list[i].customerName), trailing: Text("+${NumberFormat('#,###').format(list[i].price)}", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)))));
  }

  Widget _buildExpenseDetail() {
    final list = _expenses.where((e) => _inRange(e['date'] as int)).toList();
    return ListView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(title: Text(list[i]['title'] ?? 'Chi phí', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(list[i]['category'] ?? 'Khác'), trailing: Text("-${NumberFormat('#,###').format(list[i]['amount'])}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))));
  }
}
