import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_order_model.dart';
import '../data/db_helper.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/unified_printer_service.dart';

class SaleDetailView extends StatefulWidget {
  final SaleOrder sale;
  const SaleDetailView({super.key, required this.sale});

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  final db = DBHelper();
  late SaleOrder s;
  
  String _shopName = ""; String _shopAddr = ""; String _shopPhone = "";
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    s = widget.sale;
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shop_name') ?? "SHOP NEW";
      _shopAddr = prefs.getString('shop_address') ?? "";
      _shopPhone = prefs.getString('shop_phone') ?? "";
    });
  }

  Future<void> _printReceipt() async {
    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    HapticFeedback.mediumImpact(); // Rung phản hồi khi bấm
    
    NotificationService.showSnackBar("Đang chuẩn bị lệnh in...", color: Colors.blue);

    try {
      final shopInfo = {'shopName': _shopName, 'shopAddr': _shopAddr, 'shopPhone': _shopPhone};
      final success = await UnifiedPrinterService.printSaleReceiptFromOrder(s, shopInfo);
      
      if (success) {
        NotificationService.showSnackBar("Đã gửi lệnh in thành công!", color: Colors.green);
      } else {
        NotificationService.showSnackBar("Lỗi kết nối máy in!", color: Colors.red);
      }
    } catch (e) {
      NotificationService.showSnackBar("Lỗi: $e", color: Colors.red);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _shareInvoice() async {
    final String content = """🌟 HÓA ĐƠN BÁN HÀNG 🌟\n----------------------------\nShop: $_shopName\nKhách: ${s.customerName}\nSản phẩm: ${s.productNames}\nBảo hành: ${s.warranty ?? "12 THÁNG"}\nTỔNG: ${NumberFormat('#,###').format(s.totalPrice)} Đ\n----------------------------""";
    await Share.share(content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Text("CHI TIẾT ĐƠN BÁN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), actions: [IconButton(onPressed: _shareInvoice, icon: const Icon(Icons.share_rounded, color: Colors.green)), IconButton(onPressed: _printReceipt, icon: const Icon(Icons.print_rounded, color: Color(0xFF2962FF)))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _buildHeaderCard(),
          const SizedBox(height: 20),
          _buildInfoCard(),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: ElevatedButton.icon(onPressed: _isPrinting ? null : _printReceipt, icon: _isPrinting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print, color: Colors.white), label: const Text("IN HÓA ĐƠN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(onPressed: _shareInvoice, icon: const Icon(Icons.send_rounded, color: Colors.white), label: const Text("ZALO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2962FF), Color(0xFF00B0FF)]), borderRadius: BorderRadius.circular(25)), child: Column(children: [const Text("TỔNG THANH TOÁN", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("${NumberFormat('#,###').format(s.totalPrice)} Đ", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("Hình thức: ${s.paymentMethod}", style: const TextStyle(color: Colors.white, fontSize: 13))]));
  }

  Widget _buildInfoCard() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [_row("Khách hàng", s.customerName), _row("Điện thoại", s.phone), const Divider(), _row("Sản phẩm", s.productNames), _row("IMEI", s.productImeis), _row("Bảo hành", s.warranty ?? "12 THÁNG"), const Divider(), _row("Ngày bán", DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(s.soldAt))), _row("Nhân viên", s.sellerName)]));
  }

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 12)), Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))]));
}
