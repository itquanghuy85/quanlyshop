import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/claim_service.dart';
import '../theme/app_colors.dart';

/// "Kết nối tài khoản" — attaches the offline shop to a Firebase account
/// (PLAN_OFFLINE_FIRST step 4 + 5).
///
/// Flow: sign in / create account → [ClaimService.precheck] →
///   • account has no shop  → offline shop becomes its shop (same id), upload;
///   • account has a shop   → 3 choices (decision D4): move local data into it
///     (only when the cloud shop is empty), replace local with cloud
///     (requires a backup confirmation), or cancel.
/// While the flow runs `AppSession.claimInProgress` is true so nothing else in
/// the app touches Firebase and SQLite is never wiped by the auth gate.
class ClaimAccountView extends StatefulWidget {
  const ClaimAccountView({super.key});

  @override
  State<ClaimAccountView> createState() => _ClaimAccountViewState();
}

enum _Mode { login, register }

class _ClaimAccountViewState extends State<ClaimAccountView> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  _Mode _mode = _Mode.register;
  bool _busy = false;
  bool _obscure = true;
  String? _step;
  String? _error;
  bool _done = false;
  bool _replacedWithCloud = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  void _setStep(String s) {
    if (mounted) setState(() => _step = s);
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
      _step = _mode == _Mode.register ? 'Tạo tài khoản…' : 'Đăng nhập…';
    });
    AppSession.claimInProgress = true;
    User? user;
    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;
      final auth = FirebaseAuth.instance;
      final cred = _mode == _Mode.register
          ? await auth.createUserWithEmailAndPassword(
              email: email,
              password: pass,
            )
          : await auth.signInWithEmailAndPassword(email: email, password: pass);
      user = cred.user;
      if (user == null) throw Exception('Không lấy được thông tin tài khoản');

      _setStep('Kiểm tra tài khoản…');
      final pre = await ClaimService.precheck(user);
      if (pre.kind == ClaimCase.newAccount) {
        await ClaimService.claimToNewAccount(user, onStep: _setStep);
        _finish();
        return;
      }

      // Existing shop → let the user decide.
      if (!mounted) return;
      final choice = await _askExistingShop(pre);
      switch (choice) {
        case _ExistingChoice.moveLocalUp:
          await ClaimService.attachToExistingEmptyShop(
            user,
            pre.cloudShopId!,
            onStep: _setStep,
          );
          _finish();
          return;
        case _ExistingChoice.replaceWithCloud:
          await ClaimService.replaceLocalWithCloud(user, onStep: _setStep);
          _replacedWithCloud = true;
          _finish();
          return;
        case _ExistingChoice.cancel:
        case null:
          await ClaimService.abort();
          if (mounted) {
            setState(() {
              _busy = false;
              _step = null;
            });
          }
          return;
      }
    } on FirebaseAuthException catch (e) {
      await ClaimService.abort();
      if (mounted) {
        setState(() {
          _busy = false;
          _step = null;
          _error = _authMessage(e);
        });
      }
    } catch (e) {
      // Anything after auth succeeded: sign out so the device stays offline
      // with its data untouched.
      await ClaimService.abort();
      if (mounted) {
        setState(() {
          _busy = false;
          _step = null;
          _error = 'Không kết nối được: $e';
        });
      }
    }
  }

  void _finish() {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
      _step = 'Hoàn tất';
    });
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email này đã có tài khoản — chọn "Đăng nhập" thay vì tạo mới.';
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Sai email hoặc mật khẩu.';
      case 'network-request-failed':
        return 'Không có mạng. Kết nối internet rồi thử lại.';
      case 'too-many-requests':
        return 'Thử quá nhiều lần, vui lòng đợi rồi thử lại.';
      default:
        return 'Lỗi đăng nhập: ${e.message ?? e.code}';
    }
  }

  Future<_ExistingChoice?> _askExistingShop(ClaimPrecheck pre) {
    var backedUp = false;
    return showDialog<_ExistingChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Tài khoản đã có cửa hàng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tài khoản này đang thuộc cửa hàng '
                  '"${(pre.cloudShopName ?? '').isEmpty ? pre.cloudShopId : pre.cloudShopName}"'
                  '${pre.cloudShopEmpty ? ' (chưa có dữ liệu)' : ' (đã có dữ liệu)'}.\n\n'
                  'Ứng dụng KHÔNG tự gộp hai bộ dữ liệu. Hãy chọn:',
                ),
                const SizedBox(height: 12),
                if (pre.cloudShopEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.cloud_upload_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Đưa dữ liệu trên máy lên tài khoản'),
                    subtitle: const Text(
                      'Cửa hàng trên đám mây đang trống → dùng dữ liệu máy này.',
                    ),
                    onTap: () =>
                        Navigator.pop(ctx, _ExistingChoice.moveLocalUp),
                  )
                else
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: false,
                    leading: Icon(Icons.cloud_upload_outlined),
                    title: Text('Đưa dữ liệu trên máy lên tài khoản'),
                    subtitle: Text(
                      'Không khả dụng: cửa hàng trên đám mây đã có dữ liệu. '
                      'Hãy dùng tài khoản mới, hoặc chọn tải dữ liệu đám mây về.',
                    ),
                  ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.cloud_download_outlined,
                    color: AppColors.error,
                  ),
                  title: const Text('Tải dữ liệu tài khoản về máy'),
                  subtitle: const Text(
                    'XOÁ toàn bộ dữ liệu đang có trên máy này rồi tải dữ liệu '
                    'của tài khoản về.',
                  ),
                  enabled: backedUp,
                  onTap: backedUp
                      ? () =>
                            Navigator.pop(ctx, _ExistingChoice.replaceWithCloud)
                      : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: backedUp,
                  onChanged: (v) => setD(() => backedUp = v ?? false),
                  title: const Text(
                    'Tôi đã sao lưu (Cài đặt → Sao lưu & Khôi phục) hoặc '
                    'chấp nhận mất dữ liệu trên máy',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _ExistingChoice.cancel),
              child: const Text('Huỷ, giữ nguyên offline'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Kết nối tài khoản')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _done ? _doneBody() : _formBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _doneBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.check_circle, color: AppColors.success, size: 72),
        const SizedBox(height: 16),
        const Text(
          'Đã kết nối tài khoản',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _replacedWithCloud
              ? 'Dữ liệu của tài khoản đang được tải về máy (có thể mất vài '
                    'phút tuỳ lượng dữ liệu). Từ giờ ứng dụng tự động đồng bộ 2 chiều.'
              : 'Dữ liệu trên máy đã được đưa lên đám mây. Từ giờ ứng dụng tự động '
                    'đồng bộ 2 chiều; bạn có thể đăng nhập cùng tài khoản trên máy khác.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Về trang chủ', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _formBody() {
    final shopName =
        AppSession.offlineShopName ?? AppSession.defaultOfflineShopName;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Cửa hàng "$shopName" và toàn bộ dữ liệu trên máy sẽ được gắn '
              'vào tài khoản bạn chọn và đưa lên đám mây. Không có gì bị xoá.',
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                value: _Mode.register,
                label: Text('Tạo tài khoản mới'),
                icon: Icon(Icons.person_add_alt_1),
              ),
              ButtonSegment(
                value: _Mode.login,
                label: Text('Đã có tài khoản'),
                icon: Icon(Icons.login),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _busy
                ? null
                : (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty || !t.contains('@')) return 'Nhập email hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passCtrl,
            enabled: !_busy,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) {
              if ((v ?? '').length < 6) return 'Tối thiểu 6 ký tự';
              return null;
            },
          ),
          if (_mode == _Mode.register) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass2Ctrl,
              enabled: !_busy,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != _passCtrl.text) return 'Mật khẩu không khớp';
                return null;
              },
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _mode == _Mode.register
                    ? 'Tạo tài khoản & kết nối'
                    : 'Đăng nhập & kết nối',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          if (_step != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(_step!)),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Cần kết nối internet. Đăng nhập Google/Apple sẽ có ở bản sau — '
            'hiện dùng email & mật khẩu.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

enum _ExistingChoice { moveLocalUp, replaceWithCloud, cancel }
