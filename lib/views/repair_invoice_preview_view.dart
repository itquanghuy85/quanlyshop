import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:screenshot/screenshot.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/repair_model.dart';
import '../models/printer_types.dart';
import '../utils/money_utils.dart';
import '../utils/vietnamese_utils.dart';
import '../utils/vietqr_builder.dart';
import '../services/unified_printer_service.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/notification_service.dart';
import '../services/debt_summary_service.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/receipt_paper_view.dart';

class RepairInvoicePreviewView extends StatefulWidget {
  final Repair repair;
  final Map<String, dynamic> shopInfo;
  final bool autoShare;

  const RepairInvoicePreviewView({
    super.key,
    required this.repair,
    required this.shopInfo,
    this.autoShare = false,
  });

  @override
  State<RepairInvoicePreviewView> createState() => _RepairInvoicePreviewViewState();
}

class _RepairInvoicePreviewViewState extends State<RepairInvoicePreviewView> {
  bool _isLoading = true;
  bool _useTemplate = false;
  String _previewText = '';
  bool _sharing = false;

  final _screenshotController = ScreenshotController();
  final _debtSummary = DebtSummaryService();

  // Thông tin QR chuyển khoản (VietQR) — cấu hình ở Cài đặt > QR chuyển khoản.
  String _bankBin = '';
  String _bankName = '';
  String _bankAccount = '';
  String _bankHolder = '';
  int _remainingDebt = 0;

  bool get _hasBankInfo => _bankBin.isNotEmpty && _bankAccount.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  String _applyTemplate(String template, Map<String, String> data) {
    var result = template;
    data.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  String _statusText(int status) {
    switch (status) {
      case 1:
        return 'Tiếp nhận';
      case 2:
        return 'Đang sửa';
      case 3:
        return 'Sửa xong';
      case 4:
        return 'Đã giao';
      default:
        return 'Không xác định';
    }
  }

  Future<void> _loadPreview() async {
    final prefs = await SharedPreferences.getInstance();
    final useTemplate = prefs.getBool('repair_invoice_use_template') ?? false;
    final header = prefs.getString('repair_invoice_header') ??
        '=== PHIẾU SỬA CHỮA ===\n{shopName}\n{shopAddr}\nHotline: {shopPhone}\n--------------------------------';
    final body = prefs.getString('repair_invoice_body') ??
      'Mã đơn: {code}\nNgày: {date} {time}\n\nKhách: {customerName}\nSĐT: {customerPhone}\n\nMáy: {model}\nIMEI: {imei}\nLỗi: {issue}\nPhụ kiện: {accessories}\nLinh kiện đã dùng: {partsUsed}\nDịch vụ: {services}\nBảo hành: {warranty}\nGhi chú: {notes}\n{warrantyPolicy}\n\nGiá: {price} đ\nThanh toán: {paymentMethod}\nTrạng thái: {status}\n[QR]{qrData}';
    final footer = prefs.getString('repair_invoice_footer') ??
        '--------------------------------\nCảm ơn quý khách!';

    final createdAt = DateTime.fromMillisecondsSinceEpoch(widget.repair.createdAt);
    final data = <String, String>{
      'shopName': widget.shopInfo['shopName']?.toString() ?? 'SHOP NEW',
      'shopAddr': widget.shopInfo['shopAddr']?.toString() ?? '',
      'shopPhone': widget.shopInfo['shopPhone']?.toString() ?? '',
      'code': widget.repair.firestoreId?.toString() ?? widget.repair.createdAt.toString(),
      'date': DateFormat('dd/MM/yyyy').format(createdAt),
      'time': DateFormat('HH:mm').format(createdAt),
      'customerName': widget.repair.customerName,
      'customerPhone': widget.repair.phone,
      'model': widget.repair.model,
      'imei': widget.repair.imei ?? '',
      'issue': widget.repair.issue,
      'accessories': widget.repair.accessories,
      'warranty': widget.repair.warranty,
      'partsUsed': widget.repair.partsUsed,
      'color': widget.repair.color ?? '',
      'condition': widget.repair.condition ?? '',
      'notes': widget.repair.notes ?? '',
      'createdBy': widget.repair.createdBy ?? '',
      'repairedBy': widget.repair.repairedBy ?? '',
      'deliveredBy': widget.repair.deliveredBy ?? '',
      'services': widget.repair.services.map((s) => s.serviceName).join(', '),
      'price': MoneyUtils.formatVND(widget.repair.price),
      'paymentMethod': widget.repair.paymentMethod,
      'status': _statusText(widget.repair.status),
      'qrData': 'repair_check:${widget.repair.firestoreId ?? widget.repair.createdAt}',
      'warrantyPolicy': prefs.getString('warranty_policy') ?? '',
      'returnPolicy': prefs.getString('return_policy') ?? '',
    };

    final templateText = [header, body, footer].where((s) => s.trim().isNotEmpty).join('\n');
    final fullText = _applyTemplate(templateText, data);
    // Bỏ dòng [QR]... khỏi bản hiển thị/ảnh chia sẻ — đó là mã tra cứu nội
    // bộ (in giấy dùng để quét lại đơn tại shop), không phải QR chuyển
    // khoản. Không đụng luồng in giấy — UnifiedPrinterService tự build text
    // riêng, không dùng biến này.
    final displayText = fullText
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('[QR]'))
        .join('\n');

    int remainingDebt = 0;
    try {
      final activeDebts = await _debtSummary.getCustomerActiveDebts(widget.repair.phone);
      final linkedDebt = activeDebts
          .where((d) => d['linkedId'] == widget.repair.firestoreId)
          .firstOrNull;
      remainingDebt = _debtSummary.remainingDebtFromLinkedDebt(linkedDebt);
    } catch (_) {}

    final bankBin = prefs.getString('bank_qr_bin') ?? '';
    final bankName = prefs.getString('bank_qr_name') ?? '';
    final bankAccount = prefs.getString('bank_qr_account') ?? '';
    final bankHolder = prefs.getString('bank_qr_holder') ?? '';

    setState(() {
      _useTemplate = useTemplate;
      _previewText = displayText;
      _remainingDebt = remainingDebt;
      _bankBin = bankBin;
      _bankName = bankName;
      _bankAccount = bankAccount;
      _bankHolder = bankHolder;
      _isLoading = false;
    });

    if (widget.autoShare && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _shareImage());
    }
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 2.5);
      if (bytes == null) throw Exception('Không chụp được ảnh phiếu sửa');

      final dir = await getTemporaryDirectory();
      final code = widget.repair.firestoreId?.toString() ?? 'don_sua';
      final file = File('${dir.path}/phieu_sua_$code.png');
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar('Không tạo được ảnh: $e', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _print() async {
    final printerConfig = await showPrinterSelectionDialog(context);
    if (printerConfig == null) return;

    final printerType = printerConfig['type'] as PrinterType?;
    final bluetoothPrinter = printerConfig['bluetoothPrinter'] as BluetoothPrinterConfig?;
    final wifiIp = printerConfig['wifiIp'] as String?;

    await UnifiedPrinterService.printRepairReceiptFromRepair(
      widget.repair,
      widget.shopInfo,
      printerType: printerType,
      bluetoothPrinter: bluetoothPrinter,
      wifiIp: wifiIp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'XEM TRƯỚC PHIẾU SỬA',
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.ios_share_rounded),
            tooltip: 'Chia sẻ ảnh',
            onPressed: (_isLoading || _sharing) ? null : _shareImage,
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _print,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              color: const Color(0xFFE7E9EC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_useTemplate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'Mẫu đang tắt, bản xem trước dùng template mặc định.',
                        style: TextStyle(color: Colors.orange.shade800),
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            color: const Color(0xFFE7E9EC),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: ReceiptPaperView(
                              text: _previewText,
                              footer: (_remainingDebt > 0 && _hasBankInfo)
                                  ? _buildPaymentQrContent()
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPaymentQrContent() {
    final code = widget.repair.firestoreId?.toString() ?? '';
    final shortCode = code.length > 12 ? code.substring(code.length - 6) : code;
    final message = VietnameseUtils.removeDiacritics('CK don $shortCode').toUpperCase();
    final payload = buildVietQrPayload(
      bankBin: _bankBin,
      accountNumber: _bankAccount,
      amountVnd: _remainingDebt,
      message: message,
    );

    return Column(
      children: [
        const Text(
          'QUÉT MÃ ĐỂ CHUYỂN KHOẢN',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        QrImageView(data: payload, size: 180, backgroundColor: Colors.white),
        const SizedBox(height: 12),
        Text(
          '$_bankName${_bankHolder.isNotEmpty ? ' • $_bankHolder' : ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(
          _bankAccount,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, letterSpacing: 1),
        ),
        const SizedBox(height: 6),
        Text(
          'Số tiền: ${MoneyUtils.formatVND(_remainingDebt)} đ',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        Text(
          'Nội dung: $message',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
