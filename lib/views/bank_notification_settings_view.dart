import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/bank_directory.dart';
import '../services/bank_notification_service.dart';
import '../services/notification_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';
import '../theme/app_colors.dart';

/// Cài đặt "Đọc thông báo ngân hàng" — tính năng TÙY CHỌN, chỉ Android.
/// App đọc nội dung thông báo của các app ngân hàng trong danh sách để tự
/// nhận diện số tiền +/- và gợi ý đối soát ở màn "Đối soát tiền về".
class BankNotificationSettingsView extends StatefulWidget {
  const BankNotificationSettingsView({super.key});

  @override
  State<BankNotificationSettingsView> createState() =>
      _BankNotificationSettingsViewState();
}

class _BankNotificationSettingsViewState
    extends State<BankNotificationSettingsView> with WidgetsBindingObserver {
  final _svc = BankNotificationService.instance;
  bool _loading = true;
  bool _enabled = false;
  bool _hasPermission = false;
  bool _pendingEnable = false; // người dùng vừa bật, đang chờ cấp quyền

  bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Người dùng vừa quay lại từ màn Cài đặt hệ thống → cập nhật trạng thái quyền.
    if (state == AppLifecycleState.resumed) _onResumed();
  }

  Future<void> _onResumed() async {
    await _refresh();
    // Vừa cấp quyền xong sau khi bấm bật → tự bật luôn, không bắt bấm lại.
    if (_pendingEnable && _hasPermission && !_enabled) {
      _pendingEnable = false;
      await _svc.setEnabled(true);
      await _refresh();
      if (mounted) {
        NotificationService.showSnackBar(
          'Đã bật đọc thông báo ngân hàng.',
          color: Colors.green,
        );
      }
    }
  }

  Future<void> _refresh() async {
    final enabled = await _svc.isEnabled();
    final perm = _supported ? await _svc.hasPermission() : false;
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hasPermission = perm;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value && !_hasPermission) {
      _pendingEnable = true;
      await _svc.requestPermission();
      await _refresh();
      if (!_hasPermission) {
        if (mounted) {
          NotificationService.showSnackBar(
            'Sau khi cấp quyền "Truy cập thông báo", quay lại đây — tính năng '
            'sẽ tự bật.',
            color: Colors.blue,
          );
        }
        return;
      }
      _pendingEnable = false;
    }
    await _svc.setEnabled(value);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(title: 'Đọc thông báo ngân hàng'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveCenter(
              maxWidth: 600,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Khi bật, app đọc nội dung thông báo của CÁC APP NGÂN HÀNG '
                      '(và tin nhắn SMS từ đầu số ngân hàng) để tự nhận diện số '
                      'tiền nhận / chuyển, rồi gợi ý khớp đơn / công nợ ở màn '
                      '"Đối soát tiền về".\n\n'
                      '• App KHÔNG đọc thông báo của ứng dụng khác.\n'
                      '• App KHÔNG tự ghi nhận tiền — bạn vẫn phải bấm Xác nhận.\n'
                      '• Dữ liệu lưu trên máy này, không tải lên máy chủ.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_supported)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Chỉ hỗ trợ trên Android'),
                        subtitle: Text(
                          'iOS không cho phép ứng dụng đọc thông báo của app khác.',
                        ),
                      ),
                    )
                  else ...[
                    Card(
                      child: SwitchListTile(
                        title: const Text('Bật đọc thông báo ngân hàng'),
                        subtitle: Text(
                          _hasPermission
                              ? 'Đã cấp quyền "Truy cập thông báo".'
                              : 'Cần cấp quyền "Truy cập thông báo" của hệ thống.',
                        ),
                        value: _enabled && _hasPermission,
                        onChanged: _toggle,
                      ),
                    ),
                    if (!_hasPermission)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _svc.requestPermission();
                            await _refresh();
                          },
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('Mở cài đặt Truy cập thông báo'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Lưu ý: app cần đang mở hoặc chạy nền để bắt thông báo. '
                        'Giao dịch xảy ra khi app đã tắt hẳn có thể không tự bắt '
                        'được — vẫn có thể gõ tay số tiền ở "Đối soát tiền về".',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ngân hàng / ví được hỗ trợ (${_supportedNames().length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _supportedNames()
                          .map((n) => Chip(
                                label: Text(n,
                                    style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ngân hàng của bạn không có trong danh sách? Vẫn dùng '
                      '"Đối soát tiền về" bằng cách gõ số tiền.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  List<String> _supportedNames() {
    final set = <String>{
      ...kBankAppPackages.values,
      ...kBankSmsSenders.values,
    };
    final list = set.toList()..sort();
    return list;
  }
}
