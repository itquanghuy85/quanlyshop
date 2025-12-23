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

  // HÀM NHẬP CHI PHÍ (GIÁ VỐN) ĐỂ TÍNH LỢI NHUẬN
  Future<void> _editFinancials() async {
    final priceC = TextEditingController(text: (r.price / 1000).toStringAsFixed(0));
    final costC = TextEditingController(text: (r.cost / 1000).toStringAsFixed(0));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("CẬP NHẬT TÀI CHÍNH"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: priceC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Giá thu khách (k)", suffixText: ".000 đ")),
            const SizedBox(height: 12),
            TextField(controller: costC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Giá vốn linh kiện (k)", suffixText: ".000 đ")),
            const SizedBox(height: 15),
            const Text("Lưu ý: Hệ thống sẽ tự động tính lợi nhuận dựa trên hai con số này.", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("CẬP NHẬT")),
        ],
      ),
    );

    if (result == true) {
      setState(() {
        r.price = (int.tryParse(priceC.text) ?? 0) * 1000;
        r.cost = (int.tryParse(costC.text) ?? 0) * 1000;
      });
      await _saveData();
    }
  }

  Future<void> _saveData() async {
    setState(() => _isUpdating = true);
    await db.upsertRepair(r);
    await FirestoreService.upsertRepair(r);
    setState(() => _isUpdating = false);
    NotificationService.showSnackBar("Đã lưu thay đổi tài chính", color: Colors.green);
  }

  Future<void> _showDeliveryDialog() async {
    String selectedWarranty = "3 THÁNG";
    final List<String> options = ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"];
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text("XÁC NHẬN GIAO MÁY"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Chọn thời gian bảo hành cho khách:"),
              const SizedBox(height: 15),
              Wrap(spacing: 8, children: options.map((o) => ChoiceChip(label: Text(o), selected: selectedWarranty == o, onSelected: (v) => setS(() => selectedWarranty = o))).toList()),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, selectedWarranty), child: const Text("XÁC NHẬN GIAO")),
          ],
        ),
      ),
    );
    if (result != null) { setState(() => r.warranty = result); _updateStatus(4); }
  }

  Future<void> _updateStatus(int newStatus) async {
    setState(() => _isUpdating = true);
    try {
      r.status = newStatus;
      if (newStatus == 3) r.finishedAt = DateTime.now().millisecondsSinceEpoch;
      if (newStatus == 4) { r.deliveredAt = DateTime.now().millisecondsSinceEpoch; r.deliveredBy = FirebaseAuth.instance.currentUser?.email?.split('@').first.toUpperCase(); }
      await _saveData();
    } catch (e) { NotificationService.showSnackBar("Lỗi: $e", color: Colors.red); setState(() => _isUpdating = false); }
  }

  @override
  Widget build(BuildContext context) {
    int profit = r.price - r.cost;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text("CHI TIẾT ĐƠN SỬA", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _editFinancials, icon: const Icon(Icons.monetization_on_outlined, color: Colors.blueAccent))],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildStatusHeader(),
                const SizedBox(height: 25),
                _buildFinancialCard(profit),
                const SizedBox(height: 25),
                _buildActionGrid(),
                const SizedBox(height: 25),
                _buildInfoCard(),
                const SizedBox(height: 100),
              ],
            ),
          ),
          if (_isUpdating) Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildFinancialCard(int profit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.shade50)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lợi nhuận ròng:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text("${NumberFormat('#,###').format(profit)} đ", style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18))]),
          const Divider(height: 25),
          Row(
            children: [
              _miniFin("GIÁ THU", r.price, Colors.blue),
              _miniFin("GIÁ VỐN", r.cost, Colors.orange),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(width: double.infinity, child: TextButton.icon(onPressed: _editFinancials, icon: const Icon(Icons.edit, size: 14), label: const Text("CHỈNH SỬA CHI PHÍ & GIÁ", style: TextStyle(fontSize: 12))))
        ],
      ),
    );
  }

  Widget _miniFin(String label, int val, Color color) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text("${NumberFormat('#,###').format(val)}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15))]));
  }

  Widget _buildStatusHeader() {
    Color statusColor = r.status >= 4 ? Colors.blue : (r.status == 3 ? Colors.green : Colors.orange);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(radius: 25, backgroundColor: statusColor.withOpacity(0.1), child: Icon(r.status >= 3 ? Icons.check_circle : Icons.build_circle, color: statusColor)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(r.status == 4 ? "ĐÃ GIAO" : (r.status == 3 ? "SỬA XONG" : "ĐANG SỬA"), style: TextStyle(color: statusColor, fontWeight: FontWeight.w900))])),
        ],
      ),
    );
  }

  Widget _buildActionGrid() {
    return Row(
      children: [
        _statusBtn("ĐANG SỬA", 2, Colors.orange, Icons.settings_suggest),
        const SizedBox(width: 10),
        _statusBtn("SỬA XONG", 3, Colors.green, Icons.task_alt),
        const SizedBox(width: 10),
        Expanded(child: InkWell(onTap: _showDeliveryDialog, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: r.status == 4 ? Colors.blue : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.5))), child: Column(children: [Icon(Icons.person_pin_circle, color: r.status == 4 ? Colors.white : Colors.blue, size: 20), const SizedBox(height: 4), Text("ĐÃ GIAO", style: TextStyle(color: r.status == 4 ? Colors.white : Colors.blue, fontSize: 9, fontWeight: FontWeight.bold))])))),
      ],
    );
  }

  Widget _statusBtn(String label, int status, Color color, IconData icon) {
    bool active = r.status == status;
    return Expanded(child: InkWell(onTap: () => _updateStatus(status), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: active ? color : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))), child: Column(children: [Icon(icon, color: active ? Colors.white : color, size: 20), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? Colors.white : color, fontSize: 9, fontWeight: FontWeight.bold))]))));
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _infoRow("Khách hàng", r.customerName),
          _infoRow("Điện thoại", r.phone),
          const Divider(),
          _infoRow("Lỗi máy", r.issue),
          if (r.status == 4) _infoRow("Bảo hành", r.warranty, isBold: true, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), const Spacer(), Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color, fontSize: 13))]));
  }

  Widget _buildBottomActions() {
    return SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: ElevatedButton.icon(onPressed: () => UnifiedPrinterService.printRepairReceiptFromRepair(r, {'shopName': 'SHOP NEW', 'shopAddr': 'Chuyên Smartphone', 'shopPhone': '0123.456.789'}), icon: const Icon(Icons.print_rounded), label: const Text("IN PHIẾU", style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), padding: const EdgeInsets.symmetric(vertical: 15)))));
  }
}
