// BankTransferAssist - khối "Thanh toán qua ngân hàng" dùng chung.
//
// Hiển thị BÊN TRONG các sheet thanh toán khi người dùng chọn phương thức
// "Chuyển khoản" / "Ngân hàng". Gồm:
//   - Mã QR VietQR (chuẩn NAPAS247) đã điền sẵn số tiền + nội dung, để khách
//     quét chuyển vào TK của shop (chiều NHẬN tiền).
//   - Nút "Mở app ngân hàng" (Android, best-effort deeplink).
//   - Nút sao chép STK / số tiền / nội dung.
//
// QUAN TRỌNG: đây là khối CỐ VẤN. Nó KHÔNG thực thi thanh toán. Nút Xác nhận
// của sheet vẫn gọi `PaymentIntentService.executePaymentDirect(...)` như cũ —
// người dùng chuyển khoản xong thì tự bấm Xác nhận.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bank_accounts_service.dart';
import '../services/bank_app_deeplink_service.dart';
import '../services/notification_service.dart';
import '../utils/money_utils.dart';
import '../utils/vietqr_builder.dart';
import '../views/bank_qr_settings_view.dart';

enum BankPayDirection {
  /// Shop NHẬN tiền (thu nợ khách, thu tiền đơn, tất toán NH…). → hiện QR TK shop.
  inbound,

  /// Shop CHUYỂN đi (trả nợ NCC, chi phí…). → chỉ nút mở app ngân hàng.
  outbound,
}

bool get _deeplinkSupported {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Chuẩn hoá nội dung chuyển khoản: bỏ dấu, ký tự lạ (đa số app NH giới hạn).
String _sanitizeAddInfo(String? s) {
  if (s == null) return '';
  const from =
      'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ'
      'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  final b = StringBuffer();
  for (final ch in s.trim().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b
      .toString()
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Bảng chọn app ngân hàng của NGƯỜI DÙNG (không phải ngân hàng của TK shop —
/// chiều nhận tiền thì khách chuyển bằng app của khách, còn nút này mở app
/// của mình để chuyển đi / kiểm tra tiền về).
Future<BankAppOption?> _pickBankApp(BuildContext context) {
  return showModalBottomSheet<BankAppOption>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                'Bạn dùng app ngân hàng nào?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Chọn một lần, lần sau bấm là mở thẳng. Đổi lại bằng nút "Đổi".',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: BankAppDeeplinkService.apps.length,
                itemBuilder: (_, i) {
                  final a = BankAppDeeplinkService.apps[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(a.name),
                    onTap: () => Navigator.pop(ctx, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openBankApp({
  required BuildContext context,
  required BankAccount? account,
  required int amount,
  required String addInfo,
  bool forcePick = false,
}) async {
  // `dl.vietqr.io/pay` BẮT BUỘC có `app=` — trước đây thiếu nên VietQR chỉ
  // trả JSON "Missing parameter app" (báo từ iPhone 2026-09-12).
  var app = forcePick ? null : await BankAppDeeplinkService.getSelected();
  if (app == null) {
    if (!context.mounted) return;
    app = await _pickBankApp(context);
    if (app == null) return;
    await BankAppDeeplinkService.setSelected(app);
  }

  final uri = BankAppDeeplinkService.buildPayUri(
    app: app,
    bankBin: account?.bankBin,
    accountNumber: account?.accountNumber,
    amount: amount,
    addInfo: addInfo,
  );
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) return;
  } catch (_) {
    // rơi xuống thông báo
  }
  NotificationService.showSnackBar(
    'Không mở được ${app.name} — hãy mở app ngân hàng và quét mã QR.',
    color: Colors.orange,
  );
}

/// Khối cố vấn thanh toán ngân hàng.
///
/// Truyền [amountController] để QR tự cập nhật khi người dùng gõ số tiền,
/// HOẶC truyền [amount] cố định.
Widget bankTransferAssistCard({
  int? amount,
  TextEditingController? amountController,
  BankPayDirection direction = BankPayDirection.inbound,
  String? counterpartyName,
  String? refText,
}) {
  return _BankTransferAssistCard(
    staticAmount: amount,
    amountController: amountController,
    direction: direction,
    counterpartyName: counterpartyName,
    refText: refText,
  );
}

class _BankTransferAssistCard extends StatefulWidget {
  final int? staticAmount;
  final TextEditingController? amountController;
  final BankPayDirection direction;
  final String? counterpartyName;
  final String? refText;

  const _BankTransferAssistCard({
    required this.staticAmount,
    required this.amountController,
    required this.direction,
    required this.counterpartyName,
    required this.refText,
  });

  @override
  State<_BankTransferAssistCard> createState() =>
      _BankTransferAssistCardState();
}

class _BankTransferAssistCardState extends State<_BankTransferAssistCard> {
  final _svc = BankAccountsService.instance;
  BankAppOption? _bankApp;

  @override
  void initState() {
    super.initState();
    _loadBankApp();
    // Nạp TK: prefs ngay + refresh cloud nền.
    _svc.ensureLoaded();
  }

  int get _amount {
    if (widget.amountController != null) {
      return MoneyUtils.parseCurrency(widget.amountController!.text);
    }
    return widget.staticAmount ?? 0;
  }

  String get _addInfo => _sanitizeAddInfo(
        widget.refText ??
            (widget.counterpartyName != null
                ? 'TT ${widget.counterpartyName}'
                : ''),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        if (widget.amountController != null) widget.amountController!,
        _svc.defaultAccount,
      ]),
      builder: (context, _) {
        final account = _svc.defaultAccount.value;
        final amount = _amount;
        final isInbound = widget.direction == BankPayDirection.inbound;

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFB9D4FF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance,
                      size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 6),
                  Text(
                    isInbound
                        ? 'Nhận tiền qua ngân hàng'
                        : 'Chuyển tiền qua ngân hàng',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (isInbound && account != null) ...[
                _qrBlock(account, amount),
                const SizedBox(height: 10),
                _accountRows(account, amount),
              ] else if (isInbound && account == null) ...[
                const Text(
                  'Chưa cấu hình tài khoản ngân hàng của shop.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BankQrSettingsView()),
                  ),
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Cấu hình tài khoản ngân hàng'),
                ),
              ] else ...[
                // outbound
                Text(
                  widget.counterpartyName != null
                      ? 'Chuyển khoản cho: ${widget.counterpartyName}'
                      : 'Mở app ngân hàng để chuyển khoản, sau đó bấm Xác nhận.',
                  style: const TextStyle(
                      fontSize: 12.5, color: Color(0xFF334155)),
                ),
              ],

              const SizedBox(height: 10),
              _actionRow(account, amount),
              const SizedBox(height: 4),
              Text(
                isInbound
                    ? 'Khách quét mã QR bằng app ngân hàng của khách. Nút trên mở '
                        'app ngân hàng của bạn để kiểm tra tiền về. Nhận được '
                        'tiền hãy bấm Xác nhận để ghi nhận.'
                    : 'Chuyển khoản xong hãy bấm nút Xác nhận để ghi nhận.',
                style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _qrBlock(BankAccount account, int amount) {
    final payload = buildVietQrPayload(
      bankBin: account.bankBin,
      accountNumber: account.accountNumber,
      amountVnd: amount > 0 ? amount : null,
      message: _addInfo.isNotEmpty ? _addInfo : null,
    );
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: QrImageView(
          data: payload,
          size: 168,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _accountRows(BankAccount account, int amount) {
    return Column(
      children: [
        _kv('Ngân hàng', account.displayBankName),
        _kv('Số TK', account.accountNumber, copy: account.accountNumber),
        if (account.accountHolder.isNotEmpty)
          _kv('Chủ TK', account.accountHolder),
        if (amount > 0)
          _kv('Số tiền', '${MoneyUtils.formatCurrency(amount)} đ',
              copy: amount.toString()),
        if (_addInfo.isNotEmpty)
          _kv('Nội dung', _addInfo, copy: _addInfo),
      ],
    );
  }

  Widget _kv(String k, String v, {String? copy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          if (copy != null)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copy));
                NotificationService.showSnackBar('Đã sao chép: $copy',
                    color: Colors.green);
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.copy, size: 15, color: Color(0xFF1D4ED8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionRow(BankAccount? account, int amount) {
    if (!_deeplinkSupported) {
      return const SizedBox.shrink();
    }
    final label = _bankApp == null
        ? 'Mở app ngân hàng'
        : 'Mở ${_bankApp!.name}';
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openBankApp(
              context: context,
              account: account,
              amount: amount,
              addInfo: _addInfo,
            ).then((_) => _loadBankApp()),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(label, overflow: TextOverflow.ellipsis),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
            ),
          ),
        ),
        if (_bankApp != null) ...[
          const SizedBox(width: 6),
          TextButton(
            onPressed: () => _openBankApp(
              context: context,
              account: account,
              amount: amount,
              addInfo: _addInfo,
              forcePick: true,
            ).then((_) => _loadBankApp()),
            child: const Text('Đổi'),
          ),
        ],
      ],
    );
  }

  Future<void> _loadBankApp() async {
    final app = await BankAppDeeplinkService.getSelected();
    if (mounted && app?.id != _bankApp?.id) setState(() => _bankApp = app);
  }
}
