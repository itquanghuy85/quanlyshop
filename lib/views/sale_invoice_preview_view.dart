import 'dart:async';
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
import '../services/chat_service.dart';
import '../services/audit_service.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/receipt_paper_view.dart';
import '../constants/product_constants.dart';

class SaleInvoicePreviewView extends StatefulWidget {
  final Map<String, dynamic> saleData;
  final PaperSize paper;
  final bool autoShare;

  const SaleInvoicePreviewView({
    super.key,
    required this.saleData,
    this.paper = PaperSize.mm58,
    this.autoShare = false,
  });

  @override
  State<SaleInvoicePreviewView> createState() => _SaleInvoicePreviewViewState();
}

class _SaleInvoicePreviewViewState extends State<SaleInvoicePreviewView> {
  bool _isLoading = true;
  // true = shop đã tự bật + tùy biến mẫu in riêng (máy in in nguyên văn
  // chuỗi mẫu này) → hiển thị lại y hệt. false = chưa tùy biến, máy in dùng
  // layout ESC/POS mặc định dựng sẵn (unified_printer_service.dart) → phải
  // dựng lại đúng layout đó bằng widget, không dùng chuỗi text chung chung.
  bool _useCustomTemplate = false;
  String _previewText = '';
  List<Widget> _defaultChildren = [];
  bool _sharing = false;
  bool _sharingInternal = false;

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
    final rawHeader = prefs.getString('sale_invoice_header') ?? '';
    final rawBody = prefs.getString('sale_invoice_body') ?? '';
    final rawFooter = prefs.getString('sale_invoice_footer') ?? '';
    // Khớp đúng điều kiện `useTemplate && hasTemplate` bên
    // UnifiedPrinterService.printSaleReceipt — chỉ khi ĐỦ CẢ 2 (bật VÀ đã
    // tự nhập ít nhất 1 phần mẫu) thì máy in mới in nguyên văn chuỗi mẫu
    // này; ngược lại máy in dùng layout ESC/POS mặc định dựng sẵn (không
    // phải chuỗi text nào cả) — bản xem trước phải khớp đúng nhánh nào máy
    // in thật sự dùng, không được tự suy luận sai.
    final hasTemplate = rawHeader.trim().isNotEmpty ||
        rawBody.trim().isNotEmpty ||
        rawFooter.trim().isNotEmpty;
    final useCustomTemplate = useTemplate && hasTemplate;

    final bankBin = prefs.getString('bank_qr_bin') ?? '';
    final bankName = prefs.getString('bank_qr_name') ?? '';
    final bankAccount = prefs.getString('bank_qr_account') ?? '';
    final bankHolder = prefs.getString('bank_qr_holder') ?? '';

    final remainingDebtValue = widget.saleData['remainingDebt'] is num
        ? (widget.saleData['remainingDebt'] as num).toInt()
        : int.tryParse(widget.saleData['remainingDebt']?.toString() ?? '0') ?? 0;

    if (!useCustomTemplate) {
      final children = _buildDefaultChildren(
        prefs.getString('warranty_policy') ?? '',
        prefs.getString('return_policy') ?? '',
      );
      setState(() {
        _useCustomTemplate = false;
        _defaultChildren = children;
        _remainingDebt = remainingDebtValue;
        _bankBin = bankBin;
        _bankName = bankName;
        _bankAccount = bankAccount;
        _bankHolder = bankHolder;
        _isLoading = false;
      });
      if (widget.autoShare && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _shareToCustomer());
      }
      return;
    }

    final header = rawHeader;
    final body = rawBody;
    final footer = rawFooter;

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

    setState(() {
      _useCustomTemplate = true;
      _previewText = displayText;
      _remainingDebt = remainingDebtValue;
      _bankBin = bankBin;
      _bankName = bankName;
      _bankAccount = bankAccount;
      _bankHolder = bankHolder;
      _isLoading = false;
    });

    if (widget.autoShare && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _shareToCustomer());
    }
  }

  /// Dựng lại ĐÚNG layout ESC/POS mặc định của
  /// `UnifiedPrinterService.printSaleReceipt` (nhánh không có mẫu tùy biến)
  /// bằng widget — cùng nội dung/thứ tự/phân cấp đậm-nhạt-cỡ chữ như giấy in
  /// thật, không thêm bớt trường nào máy in không có (vd. không có mục trả
  /// góp vì bản in mặc định cũng không in mục đó).
  List<Widget> _buildDefaultChildren(String warrantyPolicy, String returnPolicy) {
    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse(v?.toString() ?? '0') ?? 0;
    String fmt(dynamic v) => MoneyUtils.formatVND(asInt(v));

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
            ? productNames.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[];
    final imeis = productImeis is List
        ? productImeis.map((e) => e?.toString() ?? '').toList()
        : productImeis is String
            ? productImeis.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : <String>[];

    final customerPhone = widget.saleData['customerPhone']?.toString() ?? '';
    final customerAddress = widget.saleData['customerAddress']?.toString() ?? '';
    final pricingTierLabel = widget.saleData['pricingTierLabel']?.toString() ?? '';
    final warranty = widget.saleData['warranty']?.toString() ?? '';
    final sellerName = widget.saleData['sellerName']?.toString() ?? '';
    final discountValue = asInt(widget.saleData['discount']);
    final finalTotal = widget.saleData['finalTotal'] ?? widget.saleData['totalPrice'];

    return [
      receiptTitle(widget.saleData['shopName']?.toString() ?? 'SHOP NEW'),
      receiptCenter(widget.saleData['shopAddr']?.toString() ?? ''),
      receiptCenter('Hotline: ${widget.saleData['shopPhone']?.toString() ?? ''}', bold: true),
      receiptDivider(),
      receiptTitle('HÓA ĐƠN BÁN HÀNG', fontSize: 17),
      receiptCenter('Mã HD: ${widget.saleData['firestoreId']?.toString() ?? 'N/A'}'),
      receiptCenter('Ngày bán: ${DateFormat('dd/MM/yyyy HH:mm').format(soldAtDate)}'),
      receiptGap(),
      receiptLeft('Khách hàng: ${widget.saleData['customerName']?.toString() ?? 'Khách lẻ'}', bold: true),
      if (customerPhone.isNotEmpty) receiptLeft('SĐT: $customerPhone'),
      if (customerAddress.isNotEmpty) receiptLeft('Địa chỉ: $customerAddress'),
      if (pricingTierLabel.isNotEmpty) receiptLeft('Nhóm giá: $pricingTierLabel', bold: true),
      receiptGap(),
      receiptLeft('Sản phẩm:', bold: true),
      for (int i = 0; i < names.length; i++) ...[
        receiptSmall('- ${ProductConstants.cleanProductNameWithSuffix(names[i])}'),
        if (i < imeis.length && imeis[i].isNotEmpty) receiptSmall('  IMEI: ${imeis[i]}'),
      ],
      receiptGap(),
      if (warranty.isNotEmpty) ...[
        receiptLeft('Bảo hành: $warranty', bold: true),
        receiptGap(),
      ],
      if (discountValue > 0) ...[
        receiptCenter('Giảm giá: -${fmt(discountValue)} đ', fontSize: 12),
        receiptGap(6),
      ],
      receiptCenter('TỔNG TIỀN: ${fmt(finalTotal)} đ', bold: true, fontSize: 17),
      receiptGap(),
      if (sellerName.isNotEmpty) receiptCenter('NV bán hàng: $sellerName'),
      receiptGap(),
      receiptSmall('- Cảm ơn quý khách đã tin dùng shop.'),
      if (warrantyPolicy.trim().isNotEmpty) receiptSmall('- Bảo hành: $warrantyPolicy'),
      if (returnPolicy.trim().isNotEmpty)
        receiptSmall('- Đổi trả: $returnPolicy')
      else
        receiptSmall('- Hàng đã bán không được đổi trả.'),
    ];
  }

  Future<File?> _captureReceiptFile() async {
    final bytes = await _screenshotController.capture(pixelRatio: 2.5);
    if (bytes == null) throw Exception('Không chụp được ảnh biên nhận');
    final dir = await getTemporaryDirectory();
    final code = widget.saleData['firestoreId']?.toString() ?? 'don_ban';
    final file = File('${dir.path}/bien_nhan_$code.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Gửi cho khách — chia sẻ trực tiếp qua share sheet hệ thống, giữ đúng
  /// hành vi gốc: 1 chạm là ra ngay share sheet, không qua bước chọn đích
  /// trung gian (từng gây lỗi share sheet không hiện ra trên 1 số máy).
  Future<void> _shareToCustomer() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _captureReceiptFile();
      if (file == null) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      final code = widget.saleData['firestoreId']?.toString() ?? 'don_ban';
      unawaited(AuditService.logAction(
        action: 'SHARE_RECEIPT_CUSTOMER',
        entityType: 'SALE',
        entityId: code,
        summary: 'Chia sẻ ảnh biên nhận cho khách',
      ));
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar('Không tạo được ảnh: $e', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Gửi nội bộ — đăng thẳng ảnh vào chat nội bộ shop, tách riêng khỏi nút
  /// chia sẻ cho khách.
  Future<void> _shareToInternal() async {
    if (_sharingInternal) return;
    setState(() => _sharingInternal = true);
    try {
      final file = await _captureReceiptFile();
      if (file == null) return;
      final customerName = widget.saleData['customerName']?.toString() ?? 'Khách lẻ';
      final totalAmount = widget.saleData['finalTotal'] ?? widget.saleData['totalPrice'];
      final caption =
          '🛒 Biên nhận đơn bán - $customerName - ${MoneyUtils.formatVND(totalAmount is num ? totalAmount.toInt() : int.tryParse(totalAmount?.toString() ?? '0') ?? 0)} đ';
      final sentId = await ChatService.sendImageMessage(images: [file], caption: caption);
      if (sentId == null) throw Exception('Không gửi được vào chat nội bộ');
      if (mounted) {
        NotificationService.showSnackBar('Đã gửi ảnh vào chat nội bộ', color: Colors.green);
      }
      final code = widget.saleData['firestoreId']?.toString() ?? 'don_ban';
      unawaited(AuditService.logAction(
        action: 'SHARE_RECEIPT_INTERNAL',
        entityType: 'SALE',
        entityId: code,
        summary: 'Gửi ảnh biên nhận vào chat nội bộ',
      ));
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar('Không tạo được ảnh: $e', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _sharingInternal = false);
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
            tooltip: 'Chia sẻ ảnh cho khách',
            onPressed: (_isLoading || _sharing) ? null : _shareToCustomer,
          ),
          IconButton(
            icon: _sharingInternal
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.forum_rounded),
            tooltip: 'Gửi nội bộ',
            onPressed: (_isLoading || _sharingInternal) ? null : _shareToInternal,
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
                  if (!_useCustomTemplate)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        'Đang dùng mẫu in mặc định — khớp đúng bản in giấy. Tự tùy biến mẫu riêng ở Cài đặt > Mẫu in.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                            child: _useCustomTemplate
                                ? ReceiptPaperView(
                                    text: _previewText,
                                    footer: (_remainingDebt > 0 && _hasBankInfo)
                                        ? _buildPaymentQrContent()
                                        : null,
                                  )
                                : ReceiptPaperView(
                                    footer: (_remainingDebt > 0 && _hasBankInfo)
                                        ? _buildPaymentQrContent()
                                        : null,
                                    children: _defaultChildren,
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
    final code = widget.saleData['firestoreId']?.toString() ?? '';
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
