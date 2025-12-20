import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../data/db_helper.dart';
import '../models/sale_order_model.dart';
import '../models/repair_model.dart';

class StaffPerformanceView extends StatefulWidget {
  const StaffPerformanceView({super.key});

  @override
  State<StaffPerformanceView> createState() => _StaffPerformanceViewState();
}

class _StaffPerformanceViewState extends State<StaffPerformanceView> {
  final db = DBHelper();
  List<SaleOrder> _sales = [];
  List<Repair> _repairs = [];
  bool _loading = true;
  bool _includeRepairs = false;

  Map<String, double> _commissionSale = {}; // staff -> %
  Map<String, double> _commissionRepair = {};

  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  String? _selectedStaff;
  final TextEditingController _customStaffCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadPrefs();
  }

  @override
  void dispose() {
    _customStaffCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sales = await db.getAllSales();
    final repairs = await db.getAllRepairs();
    setState(() {
      _sales = sales;
      _repairs = repairs;
      _loading = false;
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _includeRepairs = prefs.getBool('staff_perf_include_repairs') ?? false;
      final cSale = prefs.getString('staff_perf_comm_sale');
      final cRep = prefs.getString('staff_perf_comm_rep');
      if (cSale != null) {
        _commissionSale = Map<String, double>.from(jsonDecode(cSale).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
      }
      if (cRep != null) {
        _commissionRepair = Map<String, double>.from(jsonDecode(cRep).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
      }
    });
  }

  bool _inRange(int millis) {
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return !d.isBefore(_from) && !d.isAfter(_to);
  }

  List<String> get _staffList {
    final names = <String>{};
    for (final s in _sales) {
      if (s.sellerName.isNotEmpty) names.add(s.sellerName);
    }
    for (final r in _repairs) {
      final who = (r.deliveredBy ?? r.createdBy ?? '').trim();
      if (who.isNotEmpty) names.add(who);
    }
    final list = names.toList()..sort();
    return list;
  }

  Iterable<SaleOrder> get _filteredSales {
    return _sales.where((s) {
      if (!_inRange(s.soldAt)) return false;
      final staffName = s.sellerName.trim();
      final filter = _selectedStaff ?? _customStaffCtrl.text.trim();
      if (filter.isEmpty) return true;
      return staffName.toUpperCase().contains(filter.toUpperCase());
    });
  }

  Iterable<Repair> get _filteredRepairs {
    return _repairs.where((r) {
      final date = r.deliveredAt ?? r.finishedAt ?? r.createdAt;
      if (!_inRange(date)) return false;
      final who = (r.deliveredBy ?? r.createdBy ?? '').trim();
      final filter = _selectedStaff ?? _customStaffCtrl.text.trim();
      if (filter.isEmpty) return true;
      return who.toUpperCase().contains(filter.toUpperCase());
    });
  }

  int get _saleRevenue => _filteredSales.fold(0, (sum, s) => sum + s.totalPrice);
  int get _repairRevenue => _includeRepairs ? _filteredRepairs.fold(0, (sum, r) => sum + r.price) : 0;

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(context: context, initialDate: _from, firstDate: DateTime(2022), lastDate: DateTime.now());
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(context: context, initialDate: _to, firstDate: DateTime(2022), lastDate: DateTime.now());
    if (picked != null) setState(() => _to = picked);
  }

  double _getCommSale(String staff) => _commissionSale[staff.toUpperCase()] ?? 0;
  double _getCommRepair(String staff) => _commissionRepair[staff.toUpperCase()] ?? 0;

  void _openCommissionDialog() async {
    final staff = (_selectedStaff ?? _customStaffCtrl.text).trim();
    if (staff.isEmpty) return;
    final saleCtrl = TextEditingController(text: _getCommSale(staff).toStringAsFixed(1));
    final repCtrl = TextEditingController(text: _getCommRepair(staff).toStringAsFixed(1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hoa hồng: $staff'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: saleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% bán')),
            TextField(controller: repCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '% sửa')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('LƯU')),
        ],
      ),
    );
    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _commissionSale[staff.toUpperCase()] = double.tryParse(saleCtrl.text) ?? 0;
        _commissionRepair[staff.toUpperCase()] = double.tryParse(repCtrl.text) ?? 0;
      });
      await prefs.setString('staff_perf_comm_sale', jsonEncode(_commissionSale));
      await prefs.setString('staff_perf_comm_rep', jsonEncode(_commissionRepair));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DOANH SỐ NHÂN VIÊN', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(onPressed: _pickFrom, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd/MM/yyyy').format(_from)))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton.icon(onPressed: _pickTo, icon: const Icon(Icons.calendar_today), label: Text(DateFormat('dd/MM/yyyy').format(_to)))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedStaff,
                              decoration: const InputDecoration(labelText: 'Chọn nhân viên', border: OutlineInputBorder()),
                              items: _staffList.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                              onChanged: (v) => setState(() => _selectedStaff = v),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _customStaffCtrl,
                              decoration: const InputDecoration(labelText: 'Hoặc gõ tên tự do', border: OutlineInputBorder()),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tính doanh số sửa chữa'),
                              value: _includeRepairs,
                              onChanged: (v) async {
                                final prefs = await SharedPreferences.getInstance();
                                setState(() => _includeRepairs = v);
                                await prefs.setBool('staff_perf_include_repairs', v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _openCommissionDialog,
                            icon: const Icon(Icons.percent),
                            label: const Text('Cài % hoa hồng'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TỔNG HỢP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 6),
                      _row('Đơn bán', _filteredSales.length, Colors.pink),
                      _row('Doanh số bán', _saleRevenue, Colors.pink, money: true),
                      if (_includeRepairs) _row('Đơn sửa giao', _filteredRepairs.length, Colors.indigo),
                      if (_includeRepairs) _row('Doanh số sửa', _repairRevenue, Colors.indigo, money: true),
                      const Divider(),
                      _row('Hoa hồng bán', (_saleRevenue * (_getCommSale((_selectedStaff ?? _customStaffCtrl.text).trim().toUpperCase()) / 100)).round(), Colors.pink, money: true),
                      if (_includeRepairs)
                        _row('Hoa hồng sửa', (_repairRevenue * (_getCommRepair((_selectedStaff ?? _customStaffCtrl.text).trim().toUpperCase()) / 100)).round(), Colors.indigo, money: true),
                      const Divider(),
                      _row('Tổng doanh số', _saleRevenue + _repairRevenue, Colors.green, money: true, bold: true),
                      _row(
                        'Tổng hoa hồng',
                        ((_saleRevenue * (_getCommSale((_selectedStaff ?? _customStaffCtrl.text).trim().toUpperCase()) / 100)) +
                                (_includeRepairs ? _repairRevenue * (_getCommRepair((_selectedStaff ?? _customStaffCtrl.text).trim().toUpperCase()) / 100) : 0))
                            .round(),
                        Colors.green,
                        money: true,
                        bold: true,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      if (_filteredSales.isNotEmpty)
                        _section('ĐƠN BÁN', _filteredSales.map((s) => _tile(
                              title: s.customerName,
                              subtitle: '${s.productNames}\n${DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt))} • ${s.paymentMethod}',
                              amount: s.totalPrice,
                              badge: s.sellerName,
                            ))),
                      if (_filteredRepairs.isNotEmpty)
                        _section('ĐƠN SỬA', _filteredRepairs.map((r) => _tile(
                              title: r.customerName,
                              subtitle: '${r.model}\n${DateFormat('dd/MM HH:mm').format(DateTime.fromMillisecondsSinceEpoch(r.deliveredAt ?? r.createdAt))} • ${r.paymentMethod}',
                              amount: r.price,
                              badge: (r.deliveredBy ?? r.createdBy ?? '').isEmpty ? '---' : (r.deliveredBy ?? r.createdBy ?? ''),
                            ))),
                      if (_filteredSales.isEmpty && _filteredRepairs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('Không có dữ liệu trong khoảng lọc', style: TextStyle(color: Colors.grey))),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(String label, int value, Color color, {bool money = false, bool bold = false}) {
    final txt = money ? NumberFormat('#,###').format(value) : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          Text(money ? '$txt đ' : txt, style: TextStyle(color: color, fontWeight: bold ? FontWeight.bold : FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _section(String title, Iterable<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _tile({required String title, required String subtitle, required int amount, required String badge}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(NumberFormat('#,###').format(amount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
