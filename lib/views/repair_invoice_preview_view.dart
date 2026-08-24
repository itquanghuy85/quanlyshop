import 'dart:async';
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
import '../services/chat_service.dart';
import '../services/audit_service.dart';
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
  // true = shop đã tự bật + tùy biến mẫu in riêng → hiển thị lại y hệt chuỗi
  // mẫu đó. false = chưa tùy biến, máy in dùng layout ESC/POS mặc định dựng
  // sẵn (unified_printer_service.dart) → dựng lại đúng layout đó bằng widget.
  bool _useCustomTemplate = false;
  String _previewText = '';
  List<Widget> _defaultChildren = [];
  bool _sharing = false;
  bool _sharingInternal = false;

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
    final rawHeader = prefs.getString('repair_invoice_header') ?? '';
    final rawBody = prefs.getString('repair_invoice_body') ?? '';
    final rawFooter = prefs.getString('repair_invoice_footer') ?? '';
    // Khớp đúng điều kiện `useTemplate && hasTemplate` bên
    // UnifiedPrinterService.printRepairReceiptFromRepair — xem giải thích
    // đầy đủ ở sale_invoice_preview_view.dart._loadPreview().
    final hasTemplate = rawHeader.trim().isNotEmpty ||
        rawBody.trim().isNotEmpty ||
        rawFooter.trim().isNotEmpty;
    final useCustomTemplate = useTemplate && hasTemplate;

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

    await _precacheReceiveImages();

    if (!useCustomTemplate) {
      final children = _buildDefaultChildren();
      setState(() {
        _useCustomTemplate = false;
        _defaultChildren = children;
        _remainingDebt = remainingDebt;
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

    setState(() {
      _useCustomTemplate = true;
      _previewText = displayText;
      _remainingDebt = remainingDebt;
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

  /// Precache ảnh máy nhận (nếu là URL cloud) — đảm bảo đã tải xong trước
  /// khi chụp ảnh biên nhận/tự động chia sẻ ngay lúc màn vừa mở, tránh ảnh
  /// bị thiếu do `Image.network` chưa kịp tải xong lúc chụp.
  Future<void> _precacheReceiveImages() async {
    for (final path in widget.repair.receiveImages) {
      if (!mounted) break;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        try {
          await precacheImage(NetworkImage(path), context);
        } catch (_) {}
      }
    }
  }

  /// Dựng lại ĐÚNG layout ESC/POS mặc định của
  /// `UnifiedPrinterService.printRepairReceiptFromRepair` (nhánh không có
  /// mẫu tùy biến, dạng "phiếu tiếp nhận máy") bằng widget — cùng nội
  /// dung/thứ tự/phân cấp như giấy in thật. Bỏ hàng ký tên "Khách hàng |
  /// Nhân viên" — chỉ có ý nghĩa trên giấy thật để ký tay, không áp dụng
  /// cho ảnh số.
  List<Widget> _buildDefaultChildren() {
    final r = widget.repair;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    String subInfo = '';
    if (r.color != null && r.color!.isNotEmpty) subInfo += 'Màu: ${r.color} | ';
    if (r.condition != null && r.condition!.isNotEmpty) subInfo += 'Vỏ: ${r.condition}';

    return [
      receiptTitle(widget.shopInfo['shopName']?.toString() ?? 'SHOP NEW'),
      receiptCenter(widget.shopInfo['shopAddr']?.toString() ?? ''),
      receiptCenter('Hotline: ${widget.shopInfo['shopPhone']?.toString() ?? ''}', bold: true),
      receiptDivider(),
      receiptTitle('PHIẾU TIẾP NHẬN MÁY', fontSize: 17),
      receiptCenter('Mã đơn: ${r.firestoreId ?? r.createdAt}'),
      receiptCenter('Ngày nhận: ${DateFormat('dd/MM/yyyy HH:mm').format(createdAt)}'),
      receiptGap(),
      receiptLeft('Khách hàng: ${r.customerName}', bold: true),
      receiptLeft('SĐT: ${r.phone}'),
      receiptGap(),
      receiptLeft('Máy: ${r.model}', bold: true),
      if (r.imei != null && r.imei!.isNotEmpty) receiptLeft('IMEI/SN: ${r.imei}'),
      receiptLeft('Tình trạng: ${r.issue}'),
      if (subInfo.trim().isNotEmpty) receiptSmall(subInfo),
      receiptLeft('Phụ kiện: ${r.accessories}'),
      receiptGap(),
      receiptLeft('Giá dự kiến: ${MoneyUtils.formatVND(r.price)} đ', bold: true, fontSize: 17),
      receiptLeft('Hình thức: ${r.paymentMethod}'),
      receiptGap(),
      receiptSmall('- Quý khách vui lòng giữ phiếu để nhận máy.'),
      receiptSmall('- Shop không chịu trách nhiệm về dữ liệu trong máy.'),
      receiptGap(),
      receiptCenter('CẢM ƠN QUÝ KHÁCH!', bold: true),
    ];
  }

Future<File?> _captureReceiptFile() async {
    final bytes = await _screenshotController.capture(pixelRatio: 2.5);
    if (bytes == null) throw Exception('Không chụp được ảnh phiếu sửa');
    final dir = await getTemporaryDirectory();
    final code = widget.repair.firestoreId?.toString() ?? 'don_sua';
    final file = File('${dir.path}/phieu_sua_$code.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Gửi cho khách — chia sẻ trực tiếp qua share sheet hệ thống (Zalo,
  /// Messenger, lưu ảnh...), giữ đúng hành vi gốc: 1 chạm là ra ngay share
  /// sheet, không qua bước chọn đích trung gian (từng gây lỗi share sheet
  /// không hiện ra trên 1 số máy — có thể do độ trễ khi mở liền 2 lớp
  /// overlay hệ thống).
  Future<void> _shareToCustomer() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final file = await _captureReceiptFile();
      if (file == null) return;
      final result = await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      if (mounted && result.status == ShareResultStatus.success) {
        NotificationService.showSnackBar('Đã chia sẻ ảnh phiếu sửa', color: Colors.green);
      }
      final code = widget.repair.firestoreId?.toString() ?? 'don_sua';
      unawaited(AuditService.logAction(
        action: 'SHARE_RECEIPT_CUSTOMER',
        entityType: 'REPAIR',
        entityId: code,
        summary: 'Chia sẻ ảnh phiếu sửa cho khách',
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
  /// chia sẻ cho khách (không còn gộp chung 1 nút + sheet chọn đích).
  Future<void> _shareToInternal() async {
    if (_sharingInternal) return;
    setState(() => _sharingInternal = true);
    try {
      final file = await _captureReceiptFile();
      if (file == null) return;
      final caption =
          '🔧 Phiếu sửa - ${widget.repair.customerName} - ${widget.repair.model} - ${MoneyUtils.formatVND(widget.repair.price)} đ';
      final sentId = await ChatService.sendImageMessage(images: [file], caption: caption);
      if (sentId == null) throw Exception('Không gửi được vào chat nội bộ');
      if (mounted) {
        NotificationService.showSnackBar('Đã gửi ảnh vào chat nội bộ', color: Colors.green);
      }
      final code = widget.repair.firestoreId?.toString() ?? 'don_sua';
      unawaited(AuditService.logAction(
        action: 'SHARE_RECEIPT_INTERNAL',
        entityType: 'REPAIR',
        entityId: code,
        summary: 'Gửi ảnh phiếu sửa vào chat nội bộ',
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

    try {
      final success = await UnifiedPrinterService.printRepairReceiptFromRepair(
        widget.repair,
        widget.shopInfo,
        printerType: printerType,
        bluetoothPrinter: bluetoothPrinter,
        wifiIp: wifiIp,
      );
      if (mounted) {
        NotificationService.showSnackBar(
          success ? 'Đã gửi lệnh in' : 'In thất bại, vui lòng thử lại',
          color: success ? Colors.green : Colors.red,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showSnackBar('Lỗi khi in: $e', color: Colors.red);
      }
    }
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
                                    footer: _buildReceiptExtras(),
                                  )
                                : ReceiptPaperView(
                                    footer: _buildReceiptExtras(),
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

  /// Gộp mọi khối phụ kèm theo ảnh biên nhận: ảnh máy nhận (nếu có) → QR
  /// tra cứu đơn (luôn có) → QR chuyển khoản (nếu còn nợ + đã cấu hình NH).
  Widget? _buildReceiptExtras() {
    final images = widget.repair.receiveImages;
    final sections = <Widget>[
      if (images.isNotEmpty) _buildDeviceImagesSection(images),
      _buildLookupQrSection(),
      if (_remainingDebt > 0 && _hasBankInfo) _buildPaymentQrContent(),
    ];
    return Column(
      children: [
        for (int i = 0; i < sections.length; i++) ...[
          if (i > 0) ...[const SizedBox(height: 10), receiptDivider()],
          sections[i],
        ],
      ],
    );
  }

  Widget _buildDeviceImagesSection(List<String> images) {
    return Column(
      children: [
        const Text(
          'ẢNH MÁY NHẬN',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: images.map((path) {
            final isRemote = path.startsWith('http://') || path.startsWith('https://');
            return ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isRemote
                  ? Image.network(
                      path,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : Image.file(
                      File(path),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLookupQrSection() {
    final code = widget.repair.firestoreId?.toString() ?? widget.repair.createdAt.toString();
    return Column(
      children: [
        Text(
          'QUÉT MÃ TRA CỨU ĐƠN',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.5,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 10),
        QrImageView(data: 'repair_check:$code', size: 110, backgroundColor: Colors.white),
      ],
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
