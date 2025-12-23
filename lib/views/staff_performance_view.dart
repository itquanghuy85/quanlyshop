import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _isLoading = true;
  List<StaffStat> _staffStats = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final sales = await db.getAllSales();
    final repairs = await db.getAllRepairs();
    
    Map<String, StaffStat> statsMap = {};

    for (var s in sales) {
      final name = s.sellerName.toUpperCase();
      statsMap[name] = statsMap[name] ?? StaffStat(name: name);
      statsMap[name]!.saleCount++;
      statsMap[name]!.totalRevenue += s.totalPrice;
    }

    for (var r in repairs) {
      if (r.status >= 3) {
        final name = (r.repairedBy ?? r.createdBy ?? "NV").toUpperCase();
        statsMap[name] = statsMap[name] ?? StaffStat(name: name);
        statsMap[name]!.repairCount++;
        statsMap[name]!.totalRevenue += r.price;
      }
    }

    List<StaffStat> list = statsMap.values.toList();
    list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    if (mounted) setState(() { _staffStats = list; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("BẢNG VÀNG DOANH SỐ", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, elevation: 0,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_staffStats.isNotEmpty) _buildTopThree(),
          const SizedBox(height: 30),
          const Text("CHI TIẾT HIỆU SUẤT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
          const SizedBox(height: 15),
          ..._staffStats.map((s) => _buildStaffCard(s)).toList(),
        ],
      ),
    );
  }

  Widget _buildTopThree() {
    return Container(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_staffStats.length > 1) _topPodium(_staffStats[1], "🥈", 140, Colors.grey.shade400),
          _topPodium(_staffStats[0], "👑", 170, const Color(0xFFFFD700)),
          if (_staffStats.length > 2) _topPodium(_staffStats[2], "🥉", 120, Colors.orange.shade300),
        ],
      ),
    );
  }

  Widget _topPodium(StaffStat s, String icon, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Container(
          width: 80, height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withOpacity(0.6)]),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(s.name.split(' ').last, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text("${NumberFormat('#,###').format(s.totalRevenue / 1000)}k", style: const TextStyle(color: Colors.white, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStaffCard(StaffStat s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: const Color(0xFF2962FF).withOpacity(0.1), child: Text(s.name[0], style: const TextStyle(color: Color(0xFF2962FF), fontWeight: FontWeight.bold))),
                const SizedBox(width: 15),
                Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                Text("${NumberFormat('#,###').format(s.totalRevenue)} Đ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                _miniInfo("BÁN MÁY", s.saleCount, Colors.pink),
                _miniInfo("SỬA CHỮA", s.repairCount, Colors.blue),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: 0.7, minHeight: 6, backgroundColor: Colors.grey.shade100, color: const Color(0xFF2962FF))),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, int value, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)), Text("$value đơn", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14))]));
  }
}

class StaffStat {
  final String name;
  int saleCount = 0;
  int repairCount = 0;
  int totalRevenue = 0;
  StaffStat({required this.name});
}
