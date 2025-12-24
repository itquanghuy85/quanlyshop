import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _shopName = ""; String _shopAddr = ""; String _shopPhone = "";

  @override
  void initState() {
    super.initState();
    r = widget.repair;
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shop_name') ?? "SHOP NEW";
      _shopAddr = prefs.getString('shop_address') ?? "Chuyên Smartphone";
      _shopPhone = prefs.getString('shop_phone') ?? "0123.456.789";
    });
  }

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

  // CHIA SẺ QUA ZALO
  Future<void> _shareToZalo() async {
    final String content = """
🌟 PHIẾU SỬA CHỮA/BẢO HÀNH 🌟
----------------------------
Shop: $_shopName
Mã đơn: ${r.firestoreId?.substring(0,8).toUpperCase() ?? r.createdAt}
Khách hàng: ${r.customerName}
Model: ${r.model}
Lỗi: ${r.issue}
Bảo hành: ${r.warranty}
TỔNG CỘNG: ${NumberFormat('#,###').format(r.price)} đ
----------------------------
Cảm ơn quý khách đã tin tưởng!
""";
    await Share.share(content);
  }

  // IN PHIẾU NHIỆT
  Future<void> _printReceipt() async {
    final success = await UnifiedPrinterService.printRepairReceiptFromRepair(r, {
      'shopName': _shopName,
      'shopAddr': _shopAddr,
      'shopPhone': _shopPhone
    });
    if (success) {
      NotificationService.showSnackBar("Đã gửi lệnh in thành công", color: Colors.green);
    } else {
      NotificationService.showSnackBar("Lỗi máy in hoặc chưa kết nối!", color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("CHI TIẾT ĐƠN SỬA", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _shareToZalo, icon: const Icon(Icons.share_rounded, color: Colors.green)),
          IconButton(onPressed: _printReceipt, icon: const Icon(Icons.print_rounded, color: Color(0xFF2962FF))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildFinancialSummary(),
            const SizedBox(height: 20),
            _buildImageGallery(),
            const SizedBox(height: 20),
            _buildCustomerCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _printReceipt,
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text("IN PHIẾU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareToZalo,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text("GỬI ZALO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color color = r.status >= 3 ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(r.status >= 3 ? Icons.check_circle : Icons.pending_actions, color: color, size: 40),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(r.status == 4 ? "ĐÃ GIAO KHÁCH" : "ĐANG XỬ LÝ", style: TextStyle(color: color, fontWeight: FontWeight.bold))])),
      ]),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lợi nhuận dự kiến", style: TextStyle(fontWeight: FontWeight.bold)), Text("${NumberFormat('#,###').format(r.price - r.cost)} đ", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))]),
        const Divider(height: 25),
        Row(children: [
          _miniFin("GIÁ THU", r.price, Colors.blue),
          _miniFin("GIÁ VỐN", r.cost, Colors.orange),
        ]),
        const SizedBox(height: 10),
        TextButton.icon(onPressed: _editFinancials, icon: const Icon(Icons.edit, size: 14), label: const Text("Sửa chi phí/giá", style: TextStyle(fontSize: 12)))
      ]),
    );
  }

  Widget _miniFin(String l, int v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(NumberFormat('#,###').format(v), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 15))]));

  Widget _buildImageGallery() {
    final images = r.receiveImages;
    if (images.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HÌNH ẢNH NHẬN MÁY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)),
        const SizedBox(height: 10),
        SizedBox(height: 100, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: images.length, itemBuilder: (ctx, i) => Container(margin: const EdgeInsets.only(right: 10), width: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(images[i]), fit: BoxFit.cover, cacheWidth: 200))))),
      ],
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        _infoRow("Khách hàng", r.customerName),
        _infoRow("Điện thoại", r.phone),
        _infoRow("Lỗi máy", r.issue),
        _infoRow("Phụ kiện", r.accessories),
        if (r.warranty.isNotEmpty) _infoRow("Bảo hành", r.warranty),
      ]),
    );
  }

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]));
}
