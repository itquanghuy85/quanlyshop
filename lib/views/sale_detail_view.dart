import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sale_order_model.dart';
import '../data/db_helper.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/audit_service.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../models/printer_types.dart';
import '../widgets/printer_selection_dialog.dart';

class SaleDetailView extends StatefulWidget {
  final SaleOrder sale;
  const SaleDetailView({super.key, required this.sale});

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  final db = DBHelper();
  late SaleOrder s;
  final ScreenshotController screenshotController = ScreenshotController();
  
  String _shopName = ""; String _shopAddr = ""; String _shopPhone = ""; String _logoPath = "";
  bool get _hasLogo => _logoPath.isNotEmpty && File(_logoPath).existsSync();
  bool get _isInstallmentNH => s.paymentMethod.toUpperCase() == "TRẢ GÓP (NH)";
  bool _managerUnlocked = false;
  bool _checkingManager = false;

  // Theme colors cho màn hình chi tiết đơn bán hàng
  final Color _primaryColor = Colors.indigo; // Đồng bộ với create_sale_view
  final Color _accentColor = Colors.indigo.shade600;
  final Color _backgroundColor = const Color(0xFFF8FAFF);

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
  String _fmtShort(int? ms) => ms == null ? "---" : DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));

  Future<void> _unlockManager() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("CẦN ĐĂNG NHẬP TÀI KHOẢN QUẢN LÝ")));
      return;
    }
    final perms = await UserService.getCurrentUserPermissions();
    final isSuper = UserService.isCurrentUserSuperAdmin();
    if (!(perms['allowViewSales'] ?? false) && !isSuper) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chỉ tài khoản quản lý mới được sửa/xóa")));
      return;
    }

    final passCtrl = TextEditingController();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÁC THỰC QUẢN LÝ"),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Mật khẩu quản lý"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÁC NHẬN")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      setState(() => _checkingManager = true);
      final cred = EmailAuthProvider.credential(email: user.email ?? '', password: passCtrl.text);
      await user.reauthenticateWithCredential(cred);
      if (mounted) {
        setState(() {
          _managerUnlocked = true;
          _checkingManager = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ MỞ KHÓA CHỈNH SỬA")));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _checkingManager = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sai mật khẩu quản lý")));
      }
    }
  }

  String _toNoSign(String str) {
    var withDia = 'àáâãèéêìíòóôõùúýỳỹỷỵửữừứựửữừứựàáâãèéêìíòóôõùúýỳỹỷỵửữừứựửữừứự';
    var withoutDia = 'aaaaeeeeiioooouuyyyyyuuuuuuuuuuuaaaaeeeeiioooouuyyyyyuuuuuuuuuuu';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str.toUpperCase();
  }

  Future<void> _printWifi() async {
    // Show printer selection dialog
    final messenger = ScaffoldMessenger.of(context);
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return; // User cancelled

    // Extract printer configuration
    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter = printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    try {
      final saleData = {
        'customerName': s.customerName,
        'customerPhone': s.phone,
        'customerAddress': s.address,
        'productNames': s.productNames,
        'productImeis': s.productImeis,
        'warranty': s.warranty ?? 'KO BH',
        'sellerName': s.sellerName,
        'soldAt': s.soldAt,
        'totalPrice': s.totalPrice,
        'firestoreId': s.firestoreId ?? s.id.toString(),
        'shopName': _shopName,
        'shopAddr': _shopAddr,
        'shopPhone': _shopPhone,
      };

      final success = await UnifiedPrinterService.printSaleReceipt(
        saleData,
        PaperSize.mm58,
        printerType: printerType,
        bluetoothPrinter: bluetoothPrinter,
        wifiIp: wifiIp,
      );

      if (success) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã in hóa đơn thành công!')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('In thất bại! Vui lòng kiểm tra cài đặt máy in.')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lỗi khi in: $e')),
      );
    }
  }

  Future<void> _openSettlementDialog() async {
    final amountCtrl = TextEditingController(text: ((s.settlementAmount > 0 ? s.settlementAmount : s.loanAmount) / 1000).toStringAsFixed(0));
    final feeCtrl = TextEditingController(text: (s.settlementFee > 0 ? (s.settlementFee / 1000).toStringAsFixed(0) : "0"));
    final noteCtrl = TextEditingController(text: s.settlementNote ?? "");

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("NHẬN TIỀN TỪ NGÂN HÀNG"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Số tiền nhận (.000đ)", prefixText: "Đ ", suffixText: ".000")),
            const SizedBox(height: 8),
            TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Phí NH giữ lại (.000đ)", prefixText: "Đ ", suffixText: ".000")),
            const SizedBox(height: 8),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: "Ghi chú")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÁC NHẬN")),
        ],
      ),
    );

    if (ok != true) return;

    final received = (int.tryParse(amountCtrl.text) ?? 0) * 1000;
    final fee = (int.tryParse(feeCtrl.text) ?? 0) * 1000;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    setState(() {
      s.settlementAmount = received;
      s.settlementFee = fee;
      s.settlementNote = noteCtrl.text;
      s.settlementReceivedAt = nowMs;
      s.isSynced = false;
    });

    await db.updateSale(s);

    if (fee > 0) {
      await db.insertExpense({
        'title': "Phí NH trả góp ${s.bankName ?? ''}",
        'amount': fee,
        'category': 'Phí NH',
        'date': nowMs,
        'note': s.settlementNote ?? '',
        'paymentMethod': 'CHUYỂN KHOẢN',
      });
    }

    if (!mounted) return;
    AuditService.logAction(
      action: 'SETTLEMENT_RECEIVED',
      entityType: 'sale',
      entityId: s.firestoreId ?? "sale_${s.soldAt}",
      summary: "Nhận ${NumberFormat('#,###').format(received)} đ từ NH",
      payload: {'fee': fee, 'bank': s.bankName},
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ GHI NHẬN TIỀN NGÂN HÀNG CHUYỂN")));
    setState(() {});
  }

  Future<void> _openEditSaleDialog() async {
    final name = TextEditingController(text: s.customerName);
    final phone = TextEditingController(text: s.phone);
    final address = TextEditingController(text: s.address);
    final products = TextEditingController(text: s.productNames);
    final imeis = TextEditingController(text: s.productImeis);
    final totalPrice = TextEditingController(text: (s.totalPrice / 1000).toStringAsFixed(0));
    final totalCost = TextEditingController(text: (s.totalCost / 1000).toStringAsFixed(0));
    final notes = TextEditingController(text: s.notes ?? "");
    final warranties = ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"];
    String warranty = s.warranty ?? "KO BH";
    String payment = s.paymentMethod;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("SỬA ĐƠN BÁN"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: "Tên khách")),
              TextField(controller: phone, decoration: const InputDecoration(labelText: "SĐT")),
              TextField(controller: address, decoration: const InputDecoration(labelText: "Địa chỉ")),
              TextField(controller: products, decoration: const InputDecoration(labelText: "Sản phẩm")),
              TextField(controller: imeis, decoration: const InputDecoration(labelText: "IMEI/Serial")),
              TextField(controller: totalPrice, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tổng tiền (.000)")),
              TextField(controller: totalCost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Giá vốn (.000)")),
              DropdownButtonFormField<String>(initialValue: warranty, decoration: const InputDecoration(labelText: "Bảo hành"), items: warranties.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => warranty = v ?? warranty),
              DropdownButtonFormField<String>(
                initialValue: payment,
                decoration: const InputDecoration(labelText: "Hình thức"),
                items: const ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ", "TRẢ GÓP (NH)"]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => payment = v ?? payment,
              ),
              TextField(controller: notes, decoration: const InputDecoration(labelText: "Ghi chú")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("LƯU")),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      s.customerName = name.text.trim().toUpperCase();
      s.phone = phone.text.trim();
      s.address = address.text.trim().toUpperCase();
      s.productNames = products.text.trim().toUpperCase();
      s.productImeis = imeis.text.trim().toUpperCase();
      s.totalPrice = (int.tryParse(totalPrice.text) ?? 0) * 1000;
      s.totalCost = (int.tryParse(totalCost.text) ?? 0) * 1000;
      s.warranty = warranty;
      s.paymentMethod = payment;
      if (payment != 'TRẢ GÓP (NH)') {
        s.isInstallment = false;
        s.settlementPlannedAt = null;
        s.settlementReceivedAt = null;
        s.settlementAmount = 0;
        s.settlementFee = 0;
        s.settlementNote = null;
        s.settlementCode = null;
      }
      s.notes = notes.text;
      s.isSynced = false;
    });

    await db.updateSale(s);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ĐÃ CẬP NHẬT ĐƠN BÁN")));
      AuditService.logAction(
        action: 'UPDATE_SALE',
        entityType: 'sale',
        entityId: s.firestoreId ?? "sale_${s.soldAt}",
        summary: s.customerName,
        payload: {'paymentMethod': s.paymentMethod, 'totalPrice': s.totalPrice},
      );
    }
  }

  Future<void> _deleteSale() async {
    if (s.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("XÓA ĐƠN BÁN"),
        content: const Text("Bạn chắc chắn muốn xóa đơn này?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("XÓA")),
        ],
      ),
    );

    if (ok == true) {
      await db.deleteSale(s.id!);
      AuditService.logAction(
        action: 'DELETE_SALE',
        entityType: 'sale',
        entityId: s.firestoreId ?? "sale_${s.soldAt}",
        summary: s.customerName,
        payload: {'totalPrice': s.totalPrice},
      );
      if (mounted) {
        Navigator.pop(context, true);
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
      final imagePath = '$directory/$fileName';
      await File(imagePath).writeAsBytes(image);
      await Share.shareXFiles([XFile(imagePath)], text: 'HÓA ĐƠN SHOP $_shopName');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        title: const Text("CHI TIẾT ĐƠN BÁN", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_checkingManager)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          if (!_managerUnlocked)
            IconButton(onPressed: _unlockManager, icon: const Icon(Icons.edit, color: Colors.white)),
          IconButton(onPressed: _sendSmsToCustomer, icon: const Icon(Icons.sms_outlined, color: Colors.white)),
          IconButton(onPressed: _sendToChat, icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white)),
          IconButton(onPressed: _printWifi, icon: const Icon(Icons.print_rounded, color: Colors.white)),
          IconButton(onPressed: _shareInvoice, icon: const Icon(Icons.share_rounded, color: Colors.white)),
          if (_managerUnlocked)
            IconButton(onPressed: _deleteSale, icon: const Icon(Icons.delete_forever, color: Colors.white)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_isInstallmentNH && s.settlementReceivedAt == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openSettlementDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text("NHẬN TIỀN TỪ NGÂN HÀNG"),
                ),
              ),
            if (_isInstallmentNH) const SizedBox(height: 10),
            if (_managerUnlocked)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openEditSaleDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: _accentColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text("SỬA THÔNG TIN ĐƠN"),
                ),
              ),
            if (_managerUnlocked) const SizedBox(height: 10),
            _card("GIAO DỊCH", [
              _item("Khách hàng", s.customerName),
              _item("Số điện thoại", s.phone),
              _item("Địa chỉ", s.address.isEmpty ? "---" : s.address),
              _item("Sản phẩm", s.productNames),
              _item("IMEI", s.productImeis),
              _item("Bảo hành", s.warranty ?? "KO BH"),
              _item("Nhân viên", s.sellerName),
              _item("Thời gian", _fmtDate(s.soldAt)),
              _item("Hình thức", s.paymentMethod),
              _item("Tổng tiền", "${NumberFormat('#,###').format(s.totalPrice)} Đ", color: Colors.red),
            ]),
            if (_isInstallmentNH)
              _card("TRẢ GÓP - NGÂN HÀNG", [
                _item("Down payment", "${NumberFormat('#,###').format(s.downPayment)} đ"),
                _item("Ngân hàng giải ngân", s.bankName ?? "---"),
                _item("Số tiền NH sẽ chuyển", "${NumberFormat('#,###').format(s.settlementAmount > 0 ? s.settlementAmount : s.loanAmount)} đ"),
                _item("Ngày dự kiến", _fmtShort(s.settlementPlannedAt)),
                _item("Mã hồ sơ", s.settlementCode ?? "---"),
                _item("Ghi chú", s.settlementNote ?? "---"),
                _item("Tất toán", s.settlementReceivedAt == null ? "Chưa nhận" : "Đã nhận ${_fmtShort(s.settlementReceivedAt)}"),
                if (s.settlementFee > 0) _item("Phí NH", "${NumberFormat('#,###').format(s.settlementFee)} đ", color: Colors.orange),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _card(String t, List<Widget> c) => Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)), const Divider(), ...c]));
  Widget _item(String l, String v, {Color? color}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color))]));
  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]));

  Future<void> _sendToChat() async {
    final user = FirebaseAuth.instance.currentUser;
    final senderId = user?.uid ?? 'guest';
    final senderName = user?.email?.split('@').first.toUpperCase() ?? 'KHACH';
    final key = s.firestoreId ?? "sale_${s.soldAt}";
    final summary = "ĐƠN BÁN - ${s.customerName} - ${s.phone} - ${NumberFormat('#,###').format(s.totalPrice)} đ";
    final msg = "Trao đổi về $summary";

    final messenger = ScaffoldMessenger.of(context);
    await FirestoreService.sendChat(
      message: msg,
      senderId: senderId,
      senderName: senderName,
      linkedType: 'sale',
      linkedKey: key,
      linkedSummary: summary,
    );

    messenger.showSnackBar(
      const SnackBar(content: Text("ĐÃ GIM ĐƠN BÁN VÀO CHAT NỘI BỘ")),
    );
  }

  Future<void> _sendSmsToCustomer() async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = s.phone.trim();
    if (phone.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text("KHÔNG CÓ SỐ ĐIỆN THOẠI KHÁCH")),
      );
      return;
    }

    final customer = s.customerName.isNotEmpty ? s.customerName : phone;
    final body = "SHOP $_shopName xin chào $customer, cảm ơn anh/chị đã mua ${s.productNames}. Tổng thanh toán ${NumberFormat('#,###').format(s.totalPrice)}đ. Khi cần bảo hành vui lòng liên hệ $_shopPhone.";

    await Clipboard.setData(ClipboardData(text: body));

    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': body},
    );

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        messenger.showSnackBar(
          const SnackBar(content: Text("ĐÃ MỞ ỨNG DỤNG NHẮN TIN (nội dung đã copy sẵn).")),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text("KHÔNG MỞ ĐƯỢC ỨNG DỤNG NHẮN TIN, anh/chị dán nội dung vào Zalo/SMS giúp em.")),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text("LỖI KHI GỬI TIN NHẮN, nhưng nội dung đã được copy sẵn.")),
      );
    }
  }
}
