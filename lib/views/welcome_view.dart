import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../theme/app_colors.dart';
import 'login_view.dart';

/// First screen on a device that has neither a Firebase session nor an
/// offline shop (PLAN_OFFLINE_FIRST step 3).
///
/// "Dùng ngay" starts an offline session: a local shopId is generated and the
/// whole app works from SQLite, without any account. "Đăng nhập" goes to the
/// historical login flow.
class WelcomeView extends StatefulWidget {
  final void Function(Locale)? setLocale;
  const WelcomeView({super.key, this.setLocale});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  bool _starting = false;
  // LoginView is rendered IN PLACE (not pushed): AuthGate swaps this whole
  // widget for HomeView on sign-in, so nothing may be left on the Navigator.
  bool _showLogin = false;
  final _shopNameCtrl = TextEditingController(
    text: AppSession.defaultOfflineShopName,
  );

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _startOffline() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await AppSession.startOffline(shopName: _shopNameCtrl.text.trim());
      // AuthGate listens to AppSession.revision and swaps to HomeView.
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _goLogin() => setState(() => _showLogin = true);

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _showLogin = false);
        },
        child: Stack(
          children: [
            LoginView(setLocale: widget.setLocale),
            Positioned(
              top: 8,
              left: 4,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _showLogin = false),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/images/logo.png', height: 96),
                  const SizedBox(height: 20),
                  const Text(
                    'Quản Lý Shop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quản lý cửa hàng sửa chữa điện thoại.\n'
                    'Dùng ngay trên máy này, không cần tài khoản — '
                    'khi nào muốn đồng bộ nhiều máy thì kết nối sau.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _shopNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tên cửa hàng',
                      prefixIcon: Icon(Icons.storefront_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _starting ? null : _startOffline,
                    icon: _starting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Dùng ngay, không cần tài khoản',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _starting ? null : _goLogin,
                    icon: const Icon(Icons.login_rounded),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Đăng nhập / Tạo tài khoản',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chế độ không tài khoản lưu toàn bộ dữ liệu trên '
                            'máy này. Hãy sao lưu định kỳ (Cài đặt → Sao lưu) '
                            'hoặc kết nối tài khoản để đồng bộ lên đám mây.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
