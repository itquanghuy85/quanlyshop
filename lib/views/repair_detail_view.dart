import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/repair_model.dart';
import '../services/unified_printer_service.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../data/db_helper.dart';

class RepairDetailView extends StatefulWidget {
  final Repair repair;
  const RepairDetailView({super.key, required this.repair});

  @override
  State<RepairDetailView> createState() => _RepairDetailViewState();
}

class _RepairDetailViewState extends State<RepairDetailView> {
  final db = DBHelper();
  late Repair r;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    r = widget.repair;
  }

  // CẬP NHẬT TÀI CHÍNH (GIÁ VỐN/LÃI)
  Future<void> _editFinancials() async {
    final priceC = TextEditingController(text: (r.price / 1000).toStringAsFixed(0));
    final costC = TextEditingController(text: (r.cost / 1000).toStringAsFixed(0));
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("TÀI CHÍNH ĐƠN SỬA"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Giá thu khách (k)", suffixText: "k")),
            const SizedBox(height: 12),
            TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Giá vốn linh kiện (k)", suffixText: "k")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("LƯU")),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        r.price = (int.tryParse(priceC.text) ?? 0) * 1000;
        r.cost = (int.tryParse(costC.text) ?? 0) * 1000;
      });
      _saveData();
    }
  }

  Future<void> _saveData() async {
    setState(() => _isUpdating = true);
    try {
      await db.upsertRepair(r);
      await FirestoreService.upsertRepair(r);
      NotificationService.showSnackBar("Đã cập nhật dữ liệu", color: Colors.green);
    } catch (_) {}
    if (mounted) setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("CHI TIẾT ĐƠN SỬA", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _editFinancials, icon: const Icon(Icons.monetization_on, color: Colors.blueAccent))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 25),
            
            // 3. HIỂN THỊ HÌNH ẢNH (TỐI ƯU CHỐNG CRASH)
            const Text("HÌNH ẢNH NHẬN MÁY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 13)),
            const SizedBox(height: 12),
            _buildImageGallery(),
            
            const SizedBox(height: 25),
            _buildFinancialSummary(),
            const SizedBox(height: 25),
            _buildCustomerCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(onPressed: () => UnifiedPrinterService.printRepairReceiptFromRepair(r, {'shopName': 'SHOP NEW', 'shopAddr': 'Smartphone Service'}), icon: const Icon(Icons.print), label: const Text("IN PHIẾU BẢO HÀNH"), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), padding: const EdgeInsets.symmetric(vertical: 15))))),
    );
  }

  Widget _buildImageGallery() {
    final images = r.receiveImages;
    if (images.isEmpty) {
      return Container(width: double.infinity, height: 100, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)), child: const Center(child: Text("Không có ảnh", style: TextStyle(color: Colors.grey))));
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        itemBuilder: (ctx, i) => Container(
          margin: const EdgeInsets.only(right: 12),
          width: 150,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              File(images[i]),
              fit: BoxFit.cover,
              cacheWidth: 300, // Tối ưu bộ nhớ, chống crash
              errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(children: [
        Icon(r.status >= 3 ? Icons.check_circle : Icons.pending_actions, color: r.status >= 3 ? Colors.green : Colors.orange, size: 40),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(r.status == 4 ? "ĐÃ GIAO" : "ĐANG XỬ LÝ", style: TextStyle(color: r.status >= 3 ? Colors.green : Colors.orange, fontWeight: FontWeight.bold))])),
      ]),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lợi nhuận dự kiến", style: TextStyle(fontWeight: FontWeight.bold)), Text("${NumberFormat('#,###').format(r.price - r.cost)} đ", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))]),
        const Divider(height: 30),
        Row(children: [
          _miniFin("GIÁ THU", r.price, Colors.blue),
          _miniFin("GIÁ VỐN", r.cost, Colors.orange),
        ]),
      ]),
    );
  }

  Widget _miniFin(String l, int v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(NumberFormat('#,###').format(v), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 15))]));

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        _infoRow("Khách hàng", r.customerName),
        _infoRow("Điện thoại", r.phone),
        _infoRow("Lỗi máy", r.issue),
        _infoRow("Bảo hành", r.warranty),
      ]),
    );
  }

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]));
}
