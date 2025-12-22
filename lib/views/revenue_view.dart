import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../models/product_model.dart';
import 'supplier_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';
import 'audit_log_view.dart';
import 'staff_performance_view.dart';
import 'attendance_view.dart';
import 'payroll_view.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/audit_service.dart';

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
  List<Product> _products = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  // Chốt quỹ ngày
  final cashStartCtrl = TextEditingController(text: "0");
  final bankStartCtrl = TextEditingController(text: "0");
  final cashEndCtrl = TextEditingController(text: "0");
  final bankEndCtrl = TextEditingController(text: "0");
  final noteCtrl = TextEditingController();
  bool _savingClosing = false;
  final String _closingDateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final List<String> _periods = ['Hôm nay', 'Tuần này', 'Tháng này', 'Năm nay', 'Tất cả'];
  String _selectedPeriod = 'Hôm nay';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _loadRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    cashStartCtrl.dispose();
    bankStartCtrl.dispose();
    cashEndCtrl.dispose();
    bankEndCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() => _isAdmin = perms['allowViewRevenue'] ?? false);
  }

  Future<void> _openExpenseView() async {
    final perms = await UserService.getCurrentUserPermissions();
    final canView = perms['allowViewExpenses'] ?? false;
    if (!canView) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tài khoản này không được phép xem màn CHI PHÍ. Liên hệ chủ shop để phân quyền.")),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView()));
  }

  Future<void> _openAuditLogView() async {
    if (!_isAdmin) return;
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogView()));
  }

  Future<void> _openStaffPerformance() async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffPerformanceView()));
  }

  Future<void> _openAttendance() async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceView()));
  }

  Future<void> _openPayroll() async {
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollView()));
  }

  Future<void> _openDebtView() async {
    final perms = await UserService.getCurrentUserPermissions();
    final canView = perms['allowViewDebts'] ?? false;
    if (!canView) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tài khoản này không được phép xem SỔ CÔNG NỢ. Liên hệ chủ shop để phân quyền.")),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView()));
  }

  Future<void> _loadData() async {
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final expenses = await db.getAllExpenses();
    final products = await db.getAllProducts();
    setState(() {
      _repairs = repairs;
      _sales = sales;
      _expenses = expenses;
      _products = products;
      _isLoading = false;
    });
    _loadClosing();
  }

  bool _isSameDay(int millis, DateTime day) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return d.year == day.year && d.month == day.month && d.day == day.day;
  }

  Map<String, int> _computeTodayFlows() {
    final now = DateTime.now();
    final todaySales = _sales.where((s) => _isSameDay(s.soldAt, now)).toList();
    final todayRepairs = _repairs.where((r) => _isSameDay(r.createdAt, now)).toList();
    final todayExpenses = _expenses.where((e) => _isSameDay(e['date'] as int, now)).toList();
    final todaySettlements = _sales.where((s) => s.settlementReceivedAt != null && _isSameDay(s.settlementReceivedAt!, now)).toList();

    int cashIn = 0, bankIn = 0, cashOut = 0, bankOut = 0;

    for (var s in todaySales) {
      final method = (s.paymentMethod).toUpperCase();
      if (method == 'CHUYỂN KHOẢN') {
        bankIn += s.totalPrice;
      } else if (method == 'CÔNG NỢ') {
        // bỏ qua công nợ trong tính quỹ
      } else if (method == 'TRẢ GÓP (NH)') {
        // chỉ tính phần khách trả trước
        cashIn += s.downPayment;
      } else {
        cashIn += s.totalPrice;
      }
    }

    for (var r in todayRepairs) {
      final method = (r.paymentMethod).toUpperCase();
      if (method == 'CHUYỂN KHOẢN') bankIn += r.price;
      else if (method == 'CÔNG NỢ' || method == 'TRẢ GÓP (NH)') {
      } else {
        cashIn += r.price;
      }
    }

    for (var e in todayExpenses) {
      final method = (e['paymentMethod'] ?? 'TIỀN MẶT').toString().toUpperCase();
      if (method == 'CHUYỂN KHOẢN') bankOut += (e['amount'] as int);
      else if (method == 'CÔNG NỢ') {
      } else {
        cashOut += (e['amount'] as int);
      }
    }

    for (var s in todaySettlements) {
      final received = s.settlementAmount > 0 ? s.settlementAmount : s.loanAmount;
      bankIn += received;
      if (s.settlementFee > 0) {
        bankOut += s.settlementFee;
      }
    }

    return {
      'cashIn': cashIn,
      'bankIn': bankIn,
      'cashOut': cashOut,
      'bankOut': bankOut,
    };
  }

  Future<void> _loadClosing() async {
    final exist = await db.getClosingByDate(_closingDateKey);
    if (exist != null) {
      cashStartCtrl.text = ((exist['cashStart'] ?? 0) / 1000).toStringAsFixed(0);
      bankStartCtrl.text = ((exist['bankStart'] ?? 0) / 1000).toStringAsFixed(0);
      cashEndCtrl.text = ((exist['cashEnd'] ?? 0) / 1000).toStringAsFixed(0);
      bankEndCtrl.text = ((exist['bankEnd'] ?? 0) / 1000).toStringAsFixed(0);
      noteCtrl.text = exist['note'] ?? '';
    }
  }

  Future<void> _saveClosing() async {
    setState(() => _savingClosing = true);
    final flows = _computeTodayFlows();
    final closing = {
      'dateKey': _closingDateKey,
      'cashStart': (int.tryParse(cashStartCtrl.text) ?? 0) * 1000,
      'bankStart': (int.tryParse(bankStartCtrl.text) ?? 0) * 1000,
      'cashEnd': (int.tryParse(cashEndCtrl.text) ?? 0) * 1000,
      'bankEnd': (int.tryParse(bankEndCtrl.text) ?? 0) * 1000,
      'expectedCashDelta': flows['cashIn']! - flows['cashOut']!,
      'expectedBankDelta': flows['bankIn']! - flows['bankOut']!,
      'note': noteCtrl.text,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await db.upsertClosing(closing);
    if (mounted) {
      setState(() => _savingClosing = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ LƯU CHỐT QUỸ HÔM NAY")));
    }
    AuditService.logAction(
      action: 'CLOSE_CASH',
      entityType: 'cash_closing',
      entityId: _closingDateKey,
      summary: "Chốt quỹ ngày $_closingDateKey",
      payload: {'cashEnd': closing['cashEnd'], 'bankEnd': closing['bankEnd']},
    );
  }

  DateTime _startOfWeek(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  bool _inSelectedRange(int millis) {
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'Hôm nay':
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      case 'Tuần này':
        final start = _startOfWeek(now);
        final end = start.add(const Duration(days: 7));
        return dt.isAfter(start.subtract(const Duration(milliseconds: 1))) && dt.isBefore(end);
      case 'Tháng này':
        return dt.year == now.year && dt.month == now.month;
      case 'Năm nay':
        return dt.year == now.year;
      default:
        return true;
    }
  }

  List<Repair> get _filteredRepairs => _repairs.where((r) => r.status >= 3 && _inSelectedRange(r.deliveredAt ?? r.finishedAt ?? r.createdAt)).toList();
  List<SaleOrder> get _filteredSales => _sales.where((s) => _inSelectedRange(s.soldAt)).toList();
  List<Map<String, dynamic>> get _filteredExpenses => _expenses.where((e) => _inSelectedRange(e['date'] as int)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("TRUNG TÂM TÀI CHÍNH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: "DASHBOARD"),
            Tab(text: "BÁN HÀNG"),
            Tab(text: "SỬA CHỮA"),
            Tab(text: "QUẢN LÝ CHI PHÍ"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _quickActionButton("NHÀ CC", Icons.business_rounded, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView()))),
                    if (_isAdmin)
                      _quickActionButton("NHẬT KÝ", Icons.history_rounded, Colors.teal, _openAuditLogView),
                    _quickActionButton("DS NHÂN VIÊN", Icons.show_chart, Colors.indigo, _openStaffPerformance),
                    _quickActionButton("CHẤM CÔNG", Icons.fingerprint, Colors.deepPurple, _openAttendance),
                    _quickActionButton("BẢNG LƯƠNG", Icons.payments, Colors.green, _openPayroll),
                    if (_isAdmin)
                      _quickActionButton("XÓA LOCAL", Icons.delete_sweep_rounded, Colors.red.shade700, _confirmWipeLocal),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboard(),
                    _buildSalesReport(),
                    _buildRepairReport(),
                    _buildExpenseDebtTab(),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  // --- DASHBOARD VỚI BIỂU ĐỒ ---
  Widget _buildDashboard() {
    final saleList = _filteredSales;
    final repairList = _filteredRepairs;
    final expenseList = _filteredExpenses;

    int totalSaleRev = saleList.fold(0, (sum, s) => sum + s.totalPrice);
    int totalRepairRev = repairList.fold(0, (sum, r) => sum + r.price);
    int totalExpense = expenseList.fold(0, (sum, e) => sum + (e['amount'] as int));
    
    int profitS = saleList.fold(0, (sum, s) => sum + (s.totalPrice - s.totalCost));
    int profitR = repairList.fold(0, (sum, r) => sum + (r.price - r.cost));
    int netProfit = profitS + profitR - totalExpense;

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _periodPicker(),
        const SizedBox(height: 14),
        _reportCard("LỢI NHUẬN RÒNG (ĐÃ TRỪ CHI PHÍ)", "${NumberFormat('#,###').format(netProfit)} Đ", Colors.indigo, Icons.auto_graph_rounded),
        const SizedBox(height: 20),
        _inventorySnapshot(),
        const SizedBox(height: 20),
        _closingCard(),
        const SizedBox(height: 20),
        
        // BIỂU ĐỒ TRÒN PHÂN BỔ DOANH THU
        Container(
          height: 220,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              const Text("PHÂN BỔ DOANH THU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),
              Expanded(
                child: PieChart(
                  PieChartData(
                    sections: [
                      PieChartSectionData(value: totalSaleRev.toDouble(), title: 'BÁN', color: Colors.pink, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      PieChartSectionData(value: totalRepairRev.toDouble(), title: 'SỬA', color: Colors.blue, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      if (totalExpense > 0)
                        PieChartSectionData(value: totalExpense.toDouble(), title: 'CHI', color: Colors.redAccent, radius: 50, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                    centerSpaceRadius: 40,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        _summaryRow("Lãi Bán máy", profitS, Colors.pink),
        _summaryRow("Lãi Sửa chữa", profitR, Colors.blue),
        _summaryRow("Tổng Chi phí", totalExpense, Colors.redAccent),
        const Divider(),
        _summaryRow("TỔNG LỢI NHUẬN", netProfit, Colors.indigo, isBold: true),
      ],
    );
  }

  Widget _periodPicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent.withOpacity(0.15))),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.blueAccent),
          const SizedBox(width: 10),
          const Text("Khoảng thời gian", style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox(),
            items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _selectedPeriod = v!),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))), child: Column(children: [Icon(icon, color: color, size: 22), const SizedBox(height: 5), Text(title, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))]))));
  }

  Widget _reportCard(String title, String value, Color color, IconData icon) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)]), child: Column(children: [Icon(icon, color: Colors.white, size: 30), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))]));
  }

  Widget _inventorySnapshot() {
    final inStock = _products.where((p) => p.status == 1 && (p.quantity) > 0).toList();
    final totalQty = inStock.fold<int>(0, (sum, p) => sum + (p.quantity));
    final totalValue = inStock.fold<int>(0, (sum, p) => sum + (p.price * (p.quantity)));
    final topItems = inStock.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("KIỂM KÊ HÀNG NGÀY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
              Text("${NumberFormat('#,###').format(totalQty)} món", style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text("Giá trị tồn: ${NumberFormat('#,###').format(totalValue)} đ", style: const TextStyle(fontSize: 12, color: Colors.black87)),
          const Divider(height: 16),
          if (topItems.isEmpty)
            const Text("Chưa có hàng tồn", style: TextStyle(color: Colors.grey))
          else
            Column(
              children: topItems.map((p) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                      Text("SL: ${p.quantity}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 10),
                      Text(NumberFormat('#,###').format(p.price * p.quantity), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _closingCard() {
    final flows = _computeTodayFlows();
    final cashStart = (int.tryParse(cashStartCtrl.text) ?? 0) * 1000;
    final bankStart = (int.tryParse(bankStartCtrl.text) ?? 0) * 1000;
    final expectedCashEnd = cashStart + flows['cashIn']! - flows['cashOut']!;
    final expectedBankEnd = bankStart + flows['bankIn']! - flows['bankOut']!;
    final actualCashEnd = (int.tryParse(cashEndCtrl.text) ?? 0) * 1000;
    final actualBankEnd = (int.tryParse(bankEndCtrl.text) ?? 0) * 1000;
    final cashDiff = actualCashEnd - expectedCashEnd;
    final bankDiff = actualBankEnd - expectedBankEnd;

    Widget row(String label, int value, {Color color = Colors.black87}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)), Text(NumberFormat('#,###').format(value))],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.savings_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text("CHỐT QUỸ TRONG NGÀY", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          const Text("Điền số dư đầu ngày, nhập số đếm cuối ngày để so khớp chênh lệch."),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("ĐẦU NGÀY (X 1K)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 6),
                    Row(children: [Expanded(child: TextField(controller: cashStartCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tiền mặt", border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: bankStartCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Ngân hàng", border: OutlineInputBorder())))]),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("CUỐI NGÀY (X 1K)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 6),
                    Row(children: [Expanded(child: TextField(controller: cashEndCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tiền mặt", border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: bankEndCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Ngân hàng", border: OutlineInputBorder())))]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("DÒNG TIỀN HÔM NAY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 6),
                row("Thu tiền mặt", flows['cashIn']!),
                row("Thu ngân hàng", flows['bankIn']!),
                row("Chi tiền mặt", -flows['cashOut']!, color: Colors.redAccent),
                row("Chi ngân hàng", -flows['bankOut']!, color: Colors.redAccent),
                const Divider(),
                row("Dự kiến cuối ngày (TM)", expectedCashEnd, color: Colors.blueGrey),
                row("Dự kiến cuối ngày (NH)", expectedBankEnd, color: Colors.blueGrey),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("CHÊNH LỆCH", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                const SizedBox(height: 6),
                row("Tiền mặt thực tế", actualCashEnd, color: Colors.black),
                row("Ngân hàng thực tế", actualBankEnd, color: Colors.black),
                row("Chênh TM", cashDiff, color: cashDiff == 0 ? Colors.green : Colors.red),
                row("Chênh NH", bankDiff, color: bankDiff == 0 ? Colors.green : Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: "Ghi chú", border: OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingClosing ? null : _saveClosing,
              icon: _savingClosing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline),
              label: const Text("LƯU CHỐT QUỸ HÔM NAY"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, int value, Color color, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), Text("${NumberFormat('#,###').format(value)} đ", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color))]));
  }

  // --- CÁC TAB KHÁC GIỮ NGUYÊN LOGIC NHƯNG TỐI ƯU GIAO DIỆN ---
  Widget _buildStaffReport() {
    Map<String, Map<String, dynamic>> staffData = {};
    for (var s in _sales) {
      String name = s.sellerName.toUpperCase();
      staffData[name] = staffData[name] ?? {'count': 0, 'total': 0};
      staffData[name]!['count'] += 1;
      staffData[name]!['total'] += s.totalPrice;
    }
    List<String> staffNames = staffData.keys.toList();
    return staffNames.isEmpty ? const Center(child: Text("Chưa có dữ liệu")) : ListView.builder(padding: const EdgeInsets.all(15), itemCount: staffNames.length, itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(child: Text(staffNames[i][0])), title: Text(staffNames[i], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Đã bán: ${staffData[staffNames[i]]!['count']} đơn"), trailing: Text("${NumberFormat('#,###').format(staffData[staffNames[i]]!['total'])} đ", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)))));
  }

  Widget _buildSalesReport() {
    return Container(
      color: Colors.orange.shade50,
      child: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: _sales.length,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(_sales[index].productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text("Ngày: ${DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(_sales[index].soldAt))}"),
            trailing: Text("${NumberFormat('#,###').format(_sales[index].totalPrice)} Đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildRepairReport() {
    final done = _repairs.where((r) => r.status >= 3).toList();
    return ListView.builder(padding: const EdgeInsets.all(15), itemCount: done.length, itemBuilder: (context, index) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(title: Text(done[index].model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text("Khách: ${done[index].customerName}"), trailing: Text("${NumberFormat('#,###').format(done[index].price)} Đ", style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)))));
  }

  Widget _buildImportReport() {
    Map<String, int> supplierTotals = {};
    for (var r in _repairs) { if (r.status >= 3) supplierTotals['SỬA CHỮA'] = (supplierTotals['SỬA CHỮA'] ?? 0) + r.cost; }
    for (var s in _sales) { supplierTotals['NHẬP MÁY'] = (supplierTotals['NHẬP MÁY'] ?? 0) + s.totalCost; }
    List<String> keys = supplierTotals.keys.toList();
    return ListView.builder(padding: const EdgeInsets.all(15), itemCount: keys.length, itemBuilder: (ctx, i) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(title: Text(keys[i], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Text("${NumberFormat('#,###').format(supplierTotals[keys[i]])} đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))));
  }

  Future<void> _confirmWipeLocal() async {
    if (!_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("XÓA TOÀN BỘ DỮ LIỆU LOCAL?"),
        content: const Text("Thao tác này chỉ xóa dữ liệu trong máy (SQLite) để reset test. Không ảnh hưởng dữ liệu trên cloud."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok != true) return;
    await db.clearAllData();
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ĐÃ XÓA TOÀN BỘ DỮ LIỆU LOCAL (SQLite)")),
    );
  }

  Widget _buildExpenseDebtTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blueAccent,
            indicatorColor: Colors.blueAccent,
            tabs: [
              Tab(text: "CHI PHÍ"),
              Tab(text: "CÔNG NỢ"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ExpenseView(),
                DebtView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
