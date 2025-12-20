import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../models/sale_order_model.dart';
import '../data/db_helper.dart';

class SaleDetailView extends StatefulWidget {
  final SaleOrder sale;
  final String role;
  const SaleDetailView({super.key, required this.sale, this.role = 'user'});

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  final db = DBHelper();
  late SaleOrder s;
  final ScreenshotController screenshotController = ScreenshotController();
  
  String _shopName = ""; String _shopAddr = ""; String _shopPhone = ""; String _logoPath = "";
  bool get _hasLogo => _logoPath.isNotEmpty && File(_logoPath).existsSync();

  @override
  void initState() {
    super.initState();
    s = widget.sale;
    _loadShopInfo();
  }

  Future<void> _loadShopInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shop_name') ?? "TEN SHOP";
      _shopAddr = prefs.getString('shop_address') ?? "DIA CHI";
      _shopPhone = prefs.getString('shop_phone') ?? "SDT";
      _logoPath = prefs.getString('shop_logo_path') ?? "";
    });
  }

  String _fmtDate(int ms) => DateFormat('HH:mm dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));

  String _toNoSign(String str) {
    var withDia = 'àáâãèéêìíòóôõùúýỳỹỷỵửữừứựửữừứựàáâãèéêìíòóôõùúýỳỹỷỵửữừứựửữừứự';
    var withoutDia = 'aaaaeeeeiioooouuyyyyyuuuuuuuuuuuaaaaeeeeiioooouuyyyyyuuuuuuuuuuu';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str.toUpperCase();
  }

  Future<void> _printWifi() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('printer_ip')?.trim();
    if (ip == null || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CHƯA CÀI ĐẶT IP MÁY IN!")));
      return;
    }
    try {
      const PaperSize paper = PaperSize.mm58;
      final profile = await CapabilityProfile.load();
      final printer = NetworkPrinter(paper, profile);

      final PosPrintResult res = await printer.connect(ip, port: 9100);
      if (res == PosPrintResult.success) {
        printer.text(_toNoSign(_shopName), styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.text(_toNoSign(_shopAddr), styles: const PosStyles(align: PosAlign.center));
        printer.text("SDT: ${_toNoSign(_shopPhone)}", styles: const PosStyles(align: PosAlign.center));
        printer.hr();
        printer.text("HOA DON BAN LE", styles: const PosStyles(align: PosAlign.center, bold: true));
        printer.text("Khach: ${_toNoSign(s.customerName)}");
        printer.text("Sdt: ${_toNoSign(s.phone)}");
        printer.text("Dia chi: ${_toNoSign(s.address)}");
        printer.text("Hang: ${_toNoSign(s.productNames)}");
        printer.text("IMEI: ${_toNoSign(s.productImeis)}");
        printer.text("BH: ${_toNoSign((s.warranty ?? 'KO BH'))}");
        printer.text("Nhan vien: ${_toNoSign(s.sellerName)}");
        printer.text("Thoi gian: ${_fmtDate(s.soldAt)}");
        printer.hr();
        printer.text("TONG: ${NumberFormat('#,###').format(s.totalPrice)} VND", styles: const PosStyles(bold: true));
        printer.qrcode(s.firestoreId ?? s.id.toString(), size: QRSize.Size4, cor: QRCorrection.L);
        printer.feed(3);
        printer.cut();
        printer.disconnect();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ GỬI LỆNH IN HÓA ĐƠN TỚI MÁY IN")));
        }
      } else {
        printer.disconnect();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("IN HÓA ĐƠN THẤT BẠI: ${res.msg}. Vui lòng kiểm tra lại IP và kết nối mạng.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("LỖI KHI IN HÓA ĐƠN: $e")),
        );
      }
    }
  }

  Future<void> _shareInvoice() async {
    final directory = (await getApplicationDocumentsDirectory()).path;
    String fileName = 'HOA_DON_${s.customerName.replaceAll(' ', '_')}.png';
    
    final invoiceWidget = Container(
      width: 480, padding: const EdgeInsets.all(22), color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_hasLogo) ...[
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_logoPath), width: 60, height: 60, fit: BoxFit.cover)),
                const SizedBox(width: 12),
              ],
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
                Text("ĐC: $_shopAddr", style: const TextStyle(fontSize: 12)),
                Text("SĐT: $_shopPhone", style: const TextStyle(fontSize: 12)),
              ])
            ],
          ),
          const SizedBox(height: 12),
          const Divider(thickness: 2),
          const Center(child: Text("HÓA ĐƠN BÁN LẺ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
          const SizedBox(height: 14),
          _row("KHÁCH HÀNG", s.customerName),
          _row("SĐT", s.phone),
          _row("ĐỊA CHỈ", s.address),
          _row("SẢN PHẨM", s.productNames),
          _row("IMEI", s.productImeis),
          _row("BẢO HÀNH", s.warranty ?? "KO BH"),
          _row("NHÂN VIÊN", s.sellerName),
          _row("THỜI GIAN", _fmtDate(s.soldAt)),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("TỔNG THANH TOÁN:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("${NumberFormat('#,###').format(s.totalPrice)} Đ", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
          ]),
          const SizedBox(height: 16),
          Center(child: QrImageView(data: s.firestoreId ?? s.id.toString(), size: 110)),
          const SizedBox(height: 10),
          const Center(child: Text("CẢM ƠN QUÝ KHÁCH!", style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
        ],
      ),
    );

    await screenshotController.captureFromWidget(invoiceWidget).then((image) async {
      final imagePath = '${directory}/$fileName';
      await File(imagePath).writeAsBytes(image);
      await Share.shareXFiles([XFile(imagePath)], text: 'HÓA ĐƠN SHOP $_shopName');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("CHI TIẾT ĐƠN BÁN"),
        actions: [
          IconButton(onPressed: _printWifi, icon: const Icon(Icons.print_rounded, color: Colors.blueAccent)),
          IconButton(onPressed: _shareInvoice, icon: const Icon(Icons.share_rounded, color: Colors.pink)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _card("GIAO DỊCH", [
              _item("Khách hàng", s.customerName),
              _item("Số điện thoại", s.phone),
              _item("Địa chỉ", s.address.isEmpty ? "---" : s.address),
              _item("Sản phẩm", s.productNames),
              _item("IMEI", s.productImeis),
              _item("Bảo hành", s.warranty ?? "KO BH"),
              _item("Nhân viên", s.sellerName),
              _item("Thời gian", _fmtDate(s.soldAt)),
              _item("Tổng tiền", "${NumberFormat('#,###').format(s.totalPrice)} Đ", color: Colors.red),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _card(String t, List<Widget> c) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)), const Divider(), ...c]));
  Widget _item(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color))]));
  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]));
}
