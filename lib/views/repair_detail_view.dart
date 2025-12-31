import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/repair_model.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../models/printer_types.dart';
import '../widgets/printer_selection_dialog.dart';
import '../services/notification_service.dart';
import '../services/firestore_service.dart';
import '../data/db_helper.dart';
import '../widgets/validated_text_field.dart';

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
  bool _isPrinting = false;
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

  Widget _buildSmartImage(String path) {
    if (path.startsWith('http')) {
      return Image.network(
        path, fit: BoxFit.cover,
        loadingBuilder: (ctx, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.red),
      );
    }
    File file = File(path);
    if (file.existsSync()) return Image.file(file, fit: BoxFit.cover);
    return const Icon(Icons.cloud_download, color: Colors.blueAccent);
  }

  Future<void> _updateStatus(int newStatus) async {
    if (newStatus <= r.status) {
      NotificationService.showSnackBar("Không thể quay lại trạng thái trước!", color: Colors.red);
      return;
    }
    if (newStatus == 4) { // GIAO MÁY
      String payMethod = "TIỀN MẶT";
      String selectedWarranty = r.warranty.isEmpty ? "1 THÁNG" : r.warranty;
      final List<String> warrantyOptions = ["KO BH", "1 THÁNG", "3 THÁNG", "6 THÁNG", "12 THÁNG"];
      
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text("XÁC NHẬN GIAO MÁY & THANH TOÁN"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Chọn thời gian bảo hành:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: warrantyOptions.map((opt) => ChoiceChip(
                    label: Text(opt, style: const TextStyle(fontSize: 11)),
                    selected: selectedWarranty == opt,
                    onSelected: (v) => setS(() => selectedWarranty = opt),
                    selectedColor: Colors.blue.shade100,
                  )).toList(),
                ),
                const SizedBox(height: 20),
                const Text("Hình thức thanh toán:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: ["TIỀN MẶT", "CHUYỂN KHOẢN", "CÔNG NỢ"].map((m) => ChoiceChip(
                  label: Text(m, style: const TextStyle(fontSize: 11)), 
                  selected: payMethod == m, 
                  onSelected: (v) => setS(() => payMethod = m),
                  selectedColor: Colors.orange.shade100,
                )).toList()),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text("HOÀN TẤT GIAO MÁY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      );

      if (confirm != true) return;
      r.warranty = selectedWarranty;
      r.paymentMethod = payMethod;
      r.deliveredAt = DateTime.now().millisecondsSinceEpoch;

      final user = FirebaseAuth.instance.currentUser;
      final userName = user?.email?.split('@').first.toUpperCase() ?? "NV";

      // GHI NHẬT KÝ GIAO MÁY
      await db.logAction(
        userId: user?.uid ?? "0",
        userName: userName,
        action: "GIAO MÁY",
        type: "REPAIR",
        targetId: r.firestoreId,
        desc: "Đã giao máy ${r.model} cho khách ${r.customerName}. Bảo hành: $selectedWarranty",
      );

      if (payMethod == "CÔNG NỢ") {
        await db.insertDebt({
          'personName': r.customerName,
          'phone': r.phone,
          'totalAmount': r.price,
          'paidAmount': 0,
          'type': "CUSTOMER_OWES",
          'status': "unpaid",
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'note': "Nợ tiền sửa máy: ${r.model}",
        });
      }
    }

    if (newStatus == 3) r.finishedAt = DateTime.now().millisecondsSinceEpoch;

    setState(() { r.status = newStatus; _isUpdating = true; });
    try {
      await db.upsertRepair(r);
      await FirestoreService.upsertRepair(r);
      NotificationService.showSnackBar("ĐÃ CẬP NHẬT: ${_getStatusText(newStatus)}", color: Colors.green);
    } catch (_) {}
    setState(() => _isUpdating = false);
  }

  String _getStatusText(int s) {
    if (s == 1) return "MÁY CHỜ"; if (s == 2) return "ĐANG SỬA"; if (s == 3) return "ĐÃ XONG"; if (s == 4) return "ĐÃ GIAO"; return "KHÁC";
  }

  Future<void> _saveData() async {
    setState(() => _isUpdating = true);
    HapticFeedback.mediumImpact();
    try {
      await db.upsertRepair(r);
      await FirestoreService.upsertRepair(r);

      // Update debt if payment method is debt and repair is delivered
      if (r.paymentMethod == 'CÔNG NỢ' && r.status == 4) {
        final existingDebts = await db.getAllDebts();
        final linkedDebt = existingDebts.where((d) => d['linkedId'] == r.firestoreId).firstOrNull;
        final debtAmount = r.price - r.cost; // Profit amount
        if (linkedDebt != null) {
          // Update existing debt
          linkedDebt['amount'] = debtAmount;
          linkedDebt['remainingAmount'] = debtAmount - (linkedDebt['paidAmount'] ?? 0);
          linkedDebt['status'] = linkedDebt['remainingAmount'] > 0 ? 'UNPAID' : 'PAID';
          await db.updateDebt(linkedDebt);
          await FirestoreService.addDebtCloud(linkedDebt);
        } else {
          // Create new debt if not exists
          final newDebt = {
            'personName': r.customerName,
            'personPhone': r.phone,
            'amount': debtAmount,
            'remainingAmount': debtAmount,
            'status': 'UNPAID',
            'createdAt': r.deliveredAt ?? r.createdAt,
            'createdBy': r.createdBy,
            'linkedId': r.firestoreId,
            'note': 'Đơn sửa ${r.firestoreId}',
          };
          await db.insertDebt(newDebt);
          await FirestoreService.addDebtCloud(newDebt);
        }
      }

      NotificationService.showSnackBar("ĐÃ LƯU THAY ĐỔI ĐƠN HÀNG", color: Colors.green);
    } catch (e) {
      NotificationService.showSnackBar("Lỗi khi lưu: $e", color: Colors.red);
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  bool _isValidFinancialInput(String price, String cost) {
    final priceVal = int.tryParse(price);
    final costVal = int.tryParse(cost);
    return (priceVal != null && priceVal >= 0) && (costVal != null && costVal >= 0);
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
            ValidatedTextField(controller: priceC, label: "Giá thu khách (k)", icon: Icons.attach_money, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            ValidatedTextField(controller: costC, label: "Giá vốn linh kiện (k)", icon: Icons.inventory, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("HỦY")),
          ElevatedButton(onPressed: _isValidFinancialInput(priceC.text, costC.text) ? () => Navigator.pop(ctx, true) : null, child: const Text("LƯU")),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(title: const Tooltip(message: "Theo dõi tiến độ sửa chữa và cập nhật trạng thái.", child: Text("CHI TIẾT ĐƠN SỬA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), actions: [IconButton(onPressed: _shareToZalo, icon: const Icon(Icons.share_rounded, color: Colors.green)), IconButton(onPressed: _printReceipt, icon: const Icon(Icons.print_rounded, color: Color(0xFF2962FF)))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [_buildStatusCard(), const SizedBox(height: 15), _buildActionButtons(), const SizedBox(height: 20), _buildFinancialSummary(), const SizedBox(height: 20), _buildImageGallery(), const SizedBox(height: 20), _buildCustomerCard(), const SizedBox(height: 100)]),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildStatusCard() {
    Color color = r.status == 4 ? Colors.blue : (r.status == 3 ? Colors.green : Colors.orange);
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withAlpha(51))), child: Row(children: [Icon(r.status == 4 ? Icons.verified : (r.status == 3 ? Icons.check_circle : Icons.pending_actions), color: color, size: 40), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.model.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(_getStatusText(r.status), style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1.2))]))]));
  }

  Widget _buildActionButtons() {
    if (r.status == 4) return const SizedBox();
    return Row(children: [if (r.status < 3) Expanded(child: ElevatedButton(onPressed: () => _updateStatus(3), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("ĐÃ XONG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))), if (r.status < 3) const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: () => _updateStatus(4), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent), child: const Text("GIAO MÁY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))]);
  }

  Widget _buildFinancialSummary() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Lợi nhuận dự kiến", style: TextStyle(fontWeight: FontWeight.bold)), Text("${NumberFormat('#,###').format(r.price - r.cost)} đ", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18))]), const Divider(height: 25), Row(children: [_miniFin("GIÁ THU", r.price, Colors.blue), _miniFin("GIÁ VỐN", r.cost, Colors.orange)]), const SizedBox(height: 10), TextButton.icon(onPressed: _editFinancials, icon: const Icon(Icons.edit, size: 14), label: const Text("Thay đổi giá & vốn linh kiện", style: TextStyle(fontSize: 12)))]));
  }

  Widget _miniFin(String l, int v, Color c) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(NumberFormat('#,###').format(v), style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 15))]));

  Widget _buildImageGallery() {
    final images = r.receiveImages;
    if (images.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("HÌNH ẢNH LÚC NHẬN MÁY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)),
      const SizedBox(height: 10),
      SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: images.length, itemBuilder: (ctx, i) => GestureDetector(onTap: () => _showFullImage(images, i), child: Container(margin: const EdgeInsets.only(right: 10), width: 120, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildSmartImage(images[i]))))))
    ]);
  }

  void _showFullImage(List<String> images, int initialIndex) {
    showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: Colors.black, insetPadding: EdgeInsets.zero, child: Stack(children: [PhotoViewGallery.builder(itemCount: images.length, builder: (context, index) { final path = images[index]; return PhotoViewGalleryPageOptions(imageProvider: path.startsWith('http') ? NetworkImage(path) as ImageProvider : FileImage(File(path)), initialScale: PhotoViewComputedScale.contained, minScale: PhotoViewComputedScale.contained, maxScale: PhotoViewComputedScale.covered * 3); }, pageController: PageController(initialPage: initialIndex), scrollPhysics: const BouncingScrollPhysics(), backgroundDecoration: const BoxDecoration(color: Colors.black)), Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx)))])));
  }

  Widget _buildCustomerCard() {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [_infoRow("Khách hàng", r.customerName), _phoneRow("Số điện thoại", r.phone), _infoRow("Tình trạng lỗi", r.issue), _infoRow("Phụ kiện kèm", r.accessories.isEmpty ? "Không có" : r.accessories), _infoRow("Bảo hành", r.warranty.isEmpty ? "Chưa có" : r.warranty), if (r.deliveredAt != null) _infoRow("Ngày giao", DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(r.deliveredAt!)))]));
  }

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]));

  Widget _phoneRow(String label, String phone) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Row(
          children: [
            Text(phone, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _callCustomer(phone),
              icon: const Icon(Icons.call, color: Colors.green, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Gọi điện',
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _callCustomer(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      NotificationService.showSnackBar('Không thể gọi điện: $phone', color: Colors.red);
    }
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)]),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : _saveData,
                icon: _isUpdating ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: const Text("LƯU ĐƠN", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isPrinting ? null : _printReceipt,
                icon: _isPrinting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print, color: Colors.white),
                label: const Text("IN PHIẾU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2962FF), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _shareToZalo,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                label: const Text("ZALO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToZalo() async {
    final String content = "🌟 PHIẾU SỬA CHỮA/BẢO HÀNH 🌟\n----------------------------\nShop: $_shopName\nModel: ${r.model.toUpperCase()}\nKhách: ${r.customerName} - ${r.phone}\nLỗi: ${r.issue}\nBảo hành: ${r.warranty}\nTổng cộng: ${NumberFormat('#,###').format(r.price)} đ\n----------------------------\nCảm ơn quý khách đã tin tưởng!";
    await Share.share(content);
  }

  Future<void> _printReceipt() async {
    // Show printer selection dialog giống như in hóa đơn bán hàng
    final messenger = ScaffoldMessenger.of(context);
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return; // User cancelled

    // Extract printer configuration
    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter = printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    if (_isPrinting) return;
    setState(() => _isPrinting = true);
    HapticFeedback.mediumImpact();
    NotificationService.showSnackBar("Đang chuẩn bị lệnh in...", color: Colors.blue);

    try {
      final success = await UnifiedPrinterService.printRepairReceiptFromRepair(
        r,
        {
          'shopName': _shopName,
          'shopAddr': _shopAddr,
          'shopPhone': _shopPhone
        },
        printerType: printerType,
        bluetoothPrinter: bluetoothPrinter,
        wifiIp: wifiIp,
      );

      if (success) {
        NotificationService.showSnackBar("Đã in phiếu thành công!", color: Colors.green);
      } else {
        NotificationService.showSnackBar("In thất bại! Vui lòng kiểm tra cài đặt máy in.", color: Colors.red);
      }
    } catch (e) {
      NotificationService.showSnackBar("Lỗi khi in: $e", color: Colors.red);
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }
}
