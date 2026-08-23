import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../utils/vietqr_builder.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';
import '../theme/app_colors.dart';

/// Cài đặt tài khoản ngân hàng nhận chuyển khoản (VietQR) — dùng để tạo mã
/// QR chuyển khoản trên biên nhận đơn bán. Lưu tách riêng khỏi
/// `shop_settings_view.dart` (doc Firestore riêng `settings/bank_qr`) để
/// không đụng luồng lưu thông tin shop hiện có.
///
/// V1: chỉ chủ shop (owner) sửa được — đúng theo rule Firestore sẵn có cho
/// `shops/{shopId}/settings/{settingId}` (không cần thêm Cloud Function).
class BankQrSettingsView extends StatefulWidget {
  const BankQrSettingsView({super.key});

  @override
  State<BankQrSettingsView> createState() => _BankQrSettingsViewState();
}

class _BankQrSettingsViewState extends State<BankQrSettingsView> {
  bool _loading = true;
  bool _saving = false;
  String? _shopId;

  VietQrBank? _selectedBank;
  final _accountCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _accountCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedBin = prefs.getString('bank_qr_bin');
      final cachedAccount = prefs.getString('bank_qr_account') ?? '';
      final cachedHolder = prefs.getString('bank_qr_holder') ?? '';
      if (cachedBin != null) {
        _selectedBank = vietQrBanks.where((b) => b.bin == cachedBin).firstOrNull;
      }
      _accountCtrl.text = cachedAccount;
      _holderCtrl.text = cachedHolder;

      final shopId = await UserService.getCurrentShopId();
      _shopId = shopId;
      if (shopId != null && shopId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(shopId)
            .collection('settings')
            .doc('bank_qr')
            .get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final bin = (data['bankBin'] as String?) ?? '';
          if (bin.isNotEmpty) {
            _selectedBank = vietQrBanks.where((b) => b.bin == bin).firstOrNull;
          }
          _accountCtrl.text = (data['accountNumber'] as String?) ?? _accountCtrl.text;
          _holderCtrl.text = (data['accountHolder'] as String?) ?? _holderCtrl.text;
          await _syncToPrefs();
        }
      }
    } catch (e) {
      debugPrint('BankQrSettingsView load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bank_qr_bin', _selectedBank?.bin ?? '');
    await prefs.setString('bank_qr_name', _selectedBank?.shortName ?? '');
    await prefs.setString('bank_qr_account', _accountCtrl.text.trim());
    await prefs.setString('bank_qr_holder', _holderCtrl.text.trim());
  }

  Future<void> _save() async {
    if (_selectedBank == null) {
      NotificationService.showSnackBar('Vui lòng chọn ngân hàng', color: Colors.red);
      return;
    }
    final account = _accountCtrl.text.trim();
    if (account.isEmpty) {
      NotificationService.showSnackBar('Vui lòng nhập số tài khoản', color: Colors.red);
      return;
    }
    final holder = _holderCtrl.text.trim().toUpperCase();
    if (holder.isEmpty) {
      NotificationService.showSnackBar('Vui lòng nhập tên chủ tài khoản', color: Colors.red);
      return;
    }

    final shopId = _shopId;
    if (shopId == null || shopId.isEmpty) {
      NotificationService.showSnackBar('Không tìm thấy thông tin shop', color: Colors.red);
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('settings')
          .doc('bank_qr')
          .set({
        'bankBin': _selectedBank!.bin,
        'bankName': _selectedBank!.shortName,
        'accountNumber': account,
        'accountHolder': holder,
        'shopId': shopId,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      _holderCtrl.text = holder;
      await _syncToPrefs();

      if (mounted) {
        NotificationService.showSnackBar('Đã lưu thông tin ngân hàng', color: Colors.green);
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isPermission = msg.contains('permission-denied') || msg.contains('insufficient permissions');
      if (mounted) {
        NotificationService.showSnackBar(
          isPermission
              ? 'Chỉ chủ shop mới có thể cập nhật thông tin ngân hàng'
              : 'Lưu thất bại: $e',
          color: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar.build(title: 'QR chuyển khoản'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveCenter(
              maxWidth: 600,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Thông tin tài khoản nhận chuyển khoản — dùng để tạo mã QR trên biên nhận đơn bán khi khách còn nợ. Sau khi lưu, hãy tự quét thử bằng app ngân hàng để xác nhận đúng trước khi dùng cho khách.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Ngân hàng', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<VietQrBank>(
                      initialValue: _selectedBank,
                      isExpanded: true,
                      decoration: InputDecoration(
                        hintText: 'Chọn ngân hàng',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: vietQrBanks
                          .map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text('${b.shortName} — ${b.fullName}', overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (b) => setState(() => _selectedBank = b),
                    ),
                    const SizedBox(height: 16),
                    const Text('Số tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _accountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'VD: 0071000123456',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tên chủ tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _holderCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'VD: NGUYEN VAN A',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('LƯU'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
