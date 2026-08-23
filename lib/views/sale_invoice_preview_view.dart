import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:screenshot/screenshot.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/printer_types.dart';
import '../utils/money_utils.dart';
import '../utils/vietnamese_utils.dart';
import '../utils/vietqr_builder.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/unified_printer_service.dart';
import '../services/notification_service.dart';
import '../widgets/printer_selection_dialog.dart';
import '../constants/product_constants.dart';

class SaleInvoicePreviewView extends StatefulWidget {
  final Map<String, dynamic> saleData;
  final PaperSize paper;

  const SaleInvoicePreviewView({
    super.key,
    required this.saleData,
    this.paper = PaperSize.mm58,
  });

  @override
  State<SaleInvoicePreviewView> createState() => _SaleInvoicePreviewViewState();
}

class _SaleInvoicePreviewViewState extends State<SaleInvoicePreviewView> {
  bool _isLoading = true;
  bool _useTemplate = false;
  String _previewText = '';
  bool _sharing = false;

  final _screenshotController = ScreenshotController();

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

  Future<void> _loadPreview() async {
    final prefs = await SharedPreferences.getInstance();
    final useTemplate = prefs.getBool('sale_invoice_use_template') ?? false;
    final header = prefs.getString('sale_invoice_header') ??
        '=== HÓA ĐƠN BÁN HÀNG ===\n{shopName}\n{shopAddr}\nHotline: {shopPhone}\n--------------------------------';
    final body = prefs.getString('sale_invoice_body') ??
      'Mã HD: {code}\nNgày: {date} {time}\n\nKhách: {customerName}\nSĐT: {customerPhone}\nĐ/c: {customerAddress}\nNhóm giá: {pricingTierLabel}\n\nSản phẩm: {products}\nIMEI: {imeis}\nBảo hành: {warranty}\n\nTổng: {total} đ\nGiảm: {discount} đ\nThực thu: {finalTotal} đ\nThanh toán: {paymentMethod}\nNV bán: {sellerName}\n\nTRẢ GÓP\nĐặt cọc: {downPayment} đ ({downPaymentMethod})\nVay NH1: {loanAmount} đ - {bankName}\nVay NH2: {loanAmount2} đ - {bankName2}\nKỳ hạn: {installmentTerm}\nCòn nợ đơn: {remainingDebt} đ\nCông nợ khách hiện tại: {customerTotalDebt} đ\n{warrantyPolicy}\n{returnPolicy}\n[QR]{qrData}';
    final footer = prefs.getString('sale_invoice_footer') ??
        '--------------------------------\nCảm ơn quý khách!';

    final soldAtRaw = widget.saleData['soldAt'];
    int soldAt = 0;
    if (soldAtRaw != null) {
      soldAt = soldAtRaw is int ? soldAtRaw : int.tryParse(soldAtRaw.toString()) ?? 0;
    }
    final soldAtDate = soldAt > 0 ? DateTime.fromMillisecondsSinceEpoch(soldAt) : DateTime.now();

    final productNames = widget.saleData['productNames'];
    final productImeis = widget.saleData['productImeis'];
    final names = productNames is List
      ? productNames.map((e) => e?.toString() ?? 'N/A').toList()
      : productNames is String
        ? productNames
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
        : <String>[];
    final imeis = productImeis is List
      ? productImeis.map((e) => e?.toString() ?? '').toList()
      : productImeis is String
        ? productImeis
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
        : <String>[];

    final totalPrice = widget.saleData['totalPrice'];
    final priceValue = totalPrice is num
        ? totalPrice.toInt()
        : int.tryParse(totalPrice?.toString() ?? '0') ?? 0;

    final remainingDebtValue = widget.saleData['remainingDebt'] is num
        ? (widget.saleData['remainingDebt'] as num).toInt()
        : int.tryParse(widget.saleData['remainingDebt']?.toString() ?? '0') ?? 0;

    final data = <String, String>{
      'shopName': widget.saleData['shopName']?.toString() ?? 'SHOP NEW',
      'shopAddr': widget.saleData['shopAddr']?.toString() ?? '',
      'shopPhone': widget.saleData['shopPhone']?.toString() ?? '',
      'code': widget.saleData['firestoreId']?.toString() ?? 'N/A',
      'date': DateFormat('dd/MM/yyyy').format(soldAtDate),
      'time': DateFormat('HH:mm').format(soldAtDate),
      'customerName': widget.saleData['customerName']?.toString() ?? 'Khach le',
      'customerPhone': widget.saleData['customerPhone']?.toString() ?? '',
      'customerAddress': widget.saleData['customerAddress']?.toString() ?? '',
      'pricingTierLabel':
          widget.saleData['pricingTierLabel']?.toString() ?? 'THƯỜNG',
        'products': ProductConstants.cleanCompositeProductNames(names.join(', ')),
      'imeis': imeis.where((e) => e.trim().isNotEmpty).join(', '),
      'warranty': widget.saleData['warranty']?.toString() ?? '',
      'total': MoneyUtils.formatVND(priceValue),
      'paymentMethod': widget.saleData['paymentMethod']?.toString() ?? '',
      'sellerName': widget.saleData['sellerName']?.toString() ?? '',
      'discount': MoneyUtils.formatVND(
        widget.saleData['discount'] is num
            ? (widget.saleData['discount'] as num).toInt()
            : int.tryParse(widget.saleData['discount']?.toString() ?? '0') ??
                0,
      ),
      'finalTotal': MoneyUtils.formatVND(
        widget.saleData['finalTotal'] is num
            ? (widget.saleData['finalTotal'] as num).toInt()
            : int.tryParse(widget.saleData['finalTotal']?.toString() ?? '0') ??
                priceValue,
      ),
      'downPayment': MoneyUtils.formatVND(
        widget.saleData['downPayment'] is num
            ? (widget.saleData['downPayment'] as num).toInt()
            : int.tryParse(widget.saleData['downPayment']?.toString() ?? '0') ??
                0,
      ),
      'downPaymentMethod': widget.saleData['downPaymentMethod']?.toString() ?? '',
      'loanAmount': MoneyUtils.formatVND(
        widget.saleData['loanAmount'] is num
            ? (widget.saleData['loanAmount'] as num).toInt()
            : int.tryParse(widget.saleData['loanAmount']?.toString() ?? '0') ??
                0,
      ),
      'loanAmount2': MoneyUtils.formatVND(
        widget.saleData['loanAmount2'] is num
            ? (widget.saleData['loanAmount2'] as num).toInt()
            : int.tryParse(widget.saleData['loanAmount2']?.toString() ?? '0') ??
                0,
      ),
      'installmentTerm': widget.saleData['installmentTerm']?.toString() ?? '',
      'bankName': widget.saleData['bankName']?.toString() ?? '',
      'bankName2': widget.saleData['bankName2']?.toString() ?? '',
      'remainingDebt': MoneyUtils.formatVND(remainingDebtValue),
      'customerTotalDebt': MoneyUtils.formatVND(
        widget.saleData['customerTotalDebt'] is num
            ? (widget.saleData['customerTotalDebt'] as num).toInt()
            : int.tryParse(
                    widget.saleData['customerTotalDebt']?.toString() ?? '0',
                  ) ??
                0,
      ),
      'qrData':
          'sale_check:${widget.saleData['firestoreId']?.toString() ?? 'N/A'}',
      'warrantyPolicy': prefs.getString('warranty_policy') ?? '',
      'returnPolicy': prefs.getString('return_policy') ?? '',
    };

    final templateText = [header, body, footer].where((s) => s.trim().isNotEmpty).join('\n');
    final fullText = _applyTemplate(templateText, data);
    // Bỏ dòng [QR]... khỏi bản hiển thị/ảnh chia sẻ — đó là mã tra cứu nội
    // bộ (in giấy dùng để quét lại đơn tại shop), không phải QR chuyển
    // khoản, hiện ra sẽ chỉ là chuỗi kỹ thuật khó hiểu với khách. Không đụng
    // luồng in giấy — UnifiedPrinterService tự build text riêng, không dùng
    // biến này.
    final displayText = fullText
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('[QR]'))
        .join('\n');

    final bankBin = prefs.getString('bank_qr_bin') ?? '';
    final bankName = prefs.getString('bank_qr_name') ?? '';
    final bankAccount = prefs.getString('bank_qr_account') ?? '';
    final bankHolder = prefs.getString('bank_qr_holder') ?? '';

    setState(() {
      _useTemplate = useTemplate;
      _previewText = displayText;
      _remainingDebt = remainingDebtValue;
      _bankBin = bankBin;
      _bankName = bankName;
      _bankAccount = bankAccount;
      _bankHolder = bankHolder;
      _isLoading = false;
    });
  }

  Future<void> _shareImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final bytes = await _screenshotController.capture(pixelRatio: 2.5);
      if (bytes == null) throw Exception('Không chụp được ảnh biên nhận');

      final dir = await getTemporaryDirectory();
      final code = widget.saleData['firestoreId']?.toString() ?? 'don_ban';
      final file = File('${dir.path}/bien_nhan_$code.png');
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

    await UnifiedPrinterService.printSaleReceipt(
      widget.saleData,
      widget.paper,
      printerType: printerType,
      bluetoothPrinter: bluetoothPrinter,
      wifiIp: wifiIp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(
        title: 'XEM TRƯỚC HÓA ĐƠN BÁN',
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
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_useTemplate)
                    const Text(
                      'Mẫu đang tắt, bản xem trước dùng template mặc định.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Screenshot(
                        controller: _screenshotController,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(16),
                                width: double.infinity,
                                child: Text(
                                  _previewText,
                                  style: const TextStyle(fontFamily: 'monospace'),
                                ),
                              ),
                              if (_remainingDebt > 0 && _hasBankInfo) ...[
                                const SizedBox(height: 12),
                                _buildPaymentQrBlock(),
                              ],
                            ],
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

  Widget _buildPaymentQrBlock() {
    final code = widget.saleData['firestoreId']?.toString() ?? '';
    final shortCode = code.length > 12 ? code.substring(code.length - 6) : code;
    final message = VietnameseUtils.removeDiacritics('CK don $shortCode').toUpperCase();
    final payload = buildVietQrPayload(
      bankBin: _bankBin,
      accountNumber: _bankAccount,
      amountVnd: _remainingDebt,
      message: message,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'QUÉT MÃ ĐỂ CHUYỂN KHOẢN',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 10),
          QrImageView(data: payload, size: 180, backgroundColor: Colors.white),
          const SizedBox(height: 10),
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
          const SizedBox(height: 4),
          Text(
            'Số tiền: ${MoneyUtils.formatVND(_remainingDebt)} đ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          Text(
            'Nội dung: $message',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
