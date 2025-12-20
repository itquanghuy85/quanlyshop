import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import 'supplier_view.dart';
import 'staff_list_view.dart';
import 'expense_view.dart';
import 'debt_view.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final repairs = await db.getAllRepairs();
    final sales = await db.getAllSales();
    final expenses = await db.getAllExpenses();
    setState(() {
      _repairs = repairs;
      _sales = sales;
      _expenses = expenses;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("TRUNG TÂM TÀI CHÍNH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffListView())), 
            icon: const Icon(Icons.badge_outlined, color: Colors.blueAccent),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: "DASHBOARD"),
            Tab(text: "BÁN HÀNG"),
            Tab(text: "NHÂN VIÊN"),
            Tab(text: "SỬA CHỮA"),
            Tab(text: "CHI PHÍ NHẬP"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    _quickActionButton("CHI PHÍ", Icons.payments_outlined, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseView()))),
                    const SizedBox(width: 12),
                    _quickActionButton("SỔ CÔNG NỢ", Icons.menu_book_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtView()))),
                    const SizedBox(width: 12),
                    _quickActionButton("NHÀ CC", Icons.business_rounded, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierView()))),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboard(),
                    _buildSalesReport(),
                    _buildStaffReport(), 
                    _buildRepairReport(),
                    _buildImportReport(),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  // --- DASHBOARD VỚI BIỂU ĐỒ ---
  Widget _buildDashboard() {
    int totalSaleRev = _sales.fold(0, (sum, s) => sum + s.totalPrice);
    int totalRepairRev = _repairs.where((r) => r.status >= 3).fold(0, (sum, r) => sum + r.price);
    int totalExpense = _expenses.fold(0, (sum, e) => sum + (e['amount'] as int));
    
    int profitS = _sales.fold(0, (sum, s) => sum + (s.totalPrice - s.totalCost));
    int profitR = _repairs.where((r) => r.status >= 3).fold(0, (sum, r) => sum + (r.price - r.cost));
    int netProfit = profitS + profitR - totalExpense;

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        _reportCard("LỢI NHUẬN RÒNG (ĐÃ TRỪ CHI PHÍ)", "${NumberFormat('#,###').format(netProfit)} Đ", Colors.indigo, Icons.auto_graph_rounded),
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

  Widget _quickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(child: InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))), child: Column(children: [Icon(icon, color: color, size: 22), const SizedBox(height: 5), Text(title, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))]))));
  }

  Widget _reportCard(String title, String value, Color color, IconData icon) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)]), child: Column(children: [Icon(icon, color: Colors.white, size: 30), const SizedBox(height: 10), Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)), Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))]));
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
    return ListView.builder(padding: const EdgeInsets.all(15), itemCount: _sales.length, itemBuilder: (context, index) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(title: Text(_sales[index].productNames, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text("Ngày: ${DateFormat('dd/MM').format(DateTime.fromMillisecondsSinceEpoch(_sales[index].soldAt))}"), trailing: Text("${NumberFormat('#,###').format(_sales[index].totalPrice)} Đ", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))));
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
}
