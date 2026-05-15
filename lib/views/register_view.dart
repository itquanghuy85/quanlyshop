import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';
import '../services/user_service.dart';
import '../services/notification_service.dart';
import '../services/category_service.dart';
import '../models/shop_settings_model.dart';
import '../theme/app_text_styles.dart';
import '../widgets/responsive_wrapper.dart';

class RegisterView extends StatefulWidget {
  final Function(Locale)? setLocale;
  const RegisterView({super.key, this.setLocale});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  // Localization getter
  AppLocalizations get loc => AppLocalizations.of(context)!;

  final _emailC = TextEditingController();
  final _passC = TextEditingController();
  final _confirmPassC = TextEditingController();
  final _nameC = TextEditingController();
  final _phoneC = TextEditingController();
  final _addressC = TextEditingController();
  final _shopNameC = TextEditingController();
  final _inviteCodeC = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _isJoinShop = false;
  int _currentStep = 0;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String _selectedRole = 'employee'; // Default role for join shop

  @override
  void dispose() {
    _emailC.dispose();
    _passC.dispose();
    _confirmPassC.dispose();
    _nameC.dispose();
    _phoneC.dispose();
    _addressC.dispose();
    _shopNameC.dispose();
    _inviteCodeC.dispose();
    super.dispose();
  }

  String _formatError(dynamic e) {
    final String err = e.toString();
    if (err.contains('email-already-in-use')) return loc.emailAlreadyInUse;
    if (err.contains('weak-password')) return loc.weakPassword;
    if (err.contains('invalid-email')) return loc.invalidEmailAddress;
    if (err.contains('network-request-failed')) return loc.networkError;
    if (err.contains('too-many-requests')) return loc.tooManyRequests;
    return err
        .replaceAll("Exception: ", "")
        .replaceAll("PlatformException(", "")
        .replaceAll(")", "");
  }

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final email = _emailC.text.trim();
      final pass = _passC.text.trim();
      final shopName = _shopNameC.text.trim();
      final name = _nameC.text.trim();

      if (shopName.isEmpty) throw loc.pleaseEnterShopName;
      if (name.isEmpty) throw loc.pleaseEnterFullName;
      if (email.isEmpty || pass.isEmpty) throw loc.pleaseEnterRequiredFields;
      if (pass != _confirmPassC.text.trim()) throw loc.passwordMismatch;

      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      if (cred.user != null) {
        try {
          if (_isJoinShop) {
            final success = await UserService.useInviteCode(
              _inviteCodeC.text.trim(),
              cred.user!.uid,
            );
            if (!success) throw loc.invalidOrExpiredInviteCode;
            // Save employee displayName + info to Firestore (useInviteCode only sets shopId)
            await FirebaseFirestore.instance
                .collection('users')
                .doc(cred.user!.uid)
                .set({
                  'displayName': name.toUpperCase(),
                  'email': email,
                  'phone': _phoneC.text.trim(),
                  'address': _addressC.text.trim().toUpperCase(),
                  'role': _selectedRole,
                }, SetOptions(merge: true));
            // Also set Firebase Auth displayName for fast lookup
            await cred.user!.updateDisplayName(name.toUpperCase());
          } else {
            // Create user info with business type
            await UserService.syncUserInfo(
              cred.user!.uid,
              email,
              extra: {
                'displayName': name.toUpperCase(),
                'phone': _phoneC.text.trim(),
                'address': _addressC.text.trim().toUpperCase(),
                'shopName': shopName.toUpperCase(),
              },
            );
            // Also set Firebase Auth displayName for fast lookup
            await cred.user!.updateDisplayName(name.toUpperCase());

            // Save shop settings with business type (electronics only)
            final shopId = await UserService.getCurrentShopId();
            if (shopId != null) {
              final settings = ShopSettings.fromBusinessType(
                'electronics',
                shopId,
              );
              await CategoryService().saveShopSettings(settings);
            }
          }
        } catch (e) {
          // Setup failed after Firebase Auth already signed the user in.
          // Sign out immediately so AuthGate returns to login instead of
          // staying in a half-configured authenticated state.
          await FirebaseAuth.instance.signOut();
          rethrow;
        }

        // Registration is complete. Keep the authenticated session and simply
        // close this route so AuthGate can reveal HomeView underneath.
        try {
          await cred.user!.reload();
        } catch (e) {
          debugPrint('RegisterView: user reload failed (non-fatal): $e');
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      final errorMsg = _formatError(e);
      setState(() {
        _error = errorMsg;
        _loading = false;
      });
      NotificationService.showSnackBar(errorMsg, color: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0068FF), Color(0xFF0084FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
          AppLocalizations.of(context)!.registerAccount,
          style: TextStyle(
            fontSize: AppTextStyles.headline2.fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: ResponsiveCenter(
        maxWidth: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 30),
              _currentStep == 0 ? _stepSelectRole() : _stepInputInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepNode(
          0,
          AppLocalizations.of(context)!.storeOwner,
          _currentStep >= 0,
        ),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1 ? Colors.blueAccent : AppColors.outline,
          ),
        ),
        _stepNode(
          1,
          AppLocalizations.of(context)!.information,
          _currentStep >= 1,
        ),
      ],
    );
  }

  Widget _stepNode(int step, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: active ? Colors.blueAccent : AppColors.outline,
          child: Text(
            "${step + 1}",
            style: TextStyle(
              color: active ? AppColors.surface : AppColors.textHint,
              fontSize: AppTextStyles.subtitle1.fontSize,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTextStyles.body1.fontSize,
            color: active ? Colors.blueAccent : AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _stepSelectRole() {
    return Column(
      children: [
        _roleOption(
          false,
          AppLocalizations.of(context)!.storeOwner,
          AppLocalizations.of(context)!.createNewShop,
          Icons.storefront,
        ),
        const SizedBox(height: 16),
        // Employee option: show guidance instead of self-registration
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge, color: AppColors.textHint, size: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.employee,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            AppLocalizations.of(context)!.joinExistingShop,
                            style: TextStyle(
                              fontSize: AppTextStyles.subtitle1.fontSize,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Hướng dẫn tham gia cửa hàng',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Nhân viên không tự đăng ký tài khoản.\n'
                        'Chủ shop sẽ tạo tài khoản cho bạn:\n\n'
                        '1. Chủ shop đăng nhập ứng dụng\n'
                        '2. Vào tab Cài đặt → Quản lý nhân viên\n'
                        '3. Nhấn nút \"Tạo tài khoản nhân viên\"\n'
                        '4. Nhập thông tin và tạo tài khoản\n'
                        '5. Bạn đăng nhập bằng email & mật khẩu được cấp',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isJoinShop
                ? null
                : () => setState(() => _currentStep = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context)!.next,
              style: const TextStyle(
                color: AppColors.surface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roleOption(bool value, String title, String desc, IconData icon) {
    final selected = _isJoinShop == value;
    return GestureDetector(
      onTap: () => setState(() => _isJoinShop = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? Colors.blueAccent : AppColors.outline,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.blueAccent : AppColors.textHint,
              size: 30,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: AppTextStyles.subtitle1.fontSize,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.blueAccent : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepInputInfo() {
    return Column(
      children: [
        _input(_shopNameC, AppLocalizations.of(context)!.shopName, Icons.shop),
        _input(_nameC, AppLocalizations.of(context)!.fullName, Icons.person),
        _input(
          _phoneC,
          AppLocalizations.of(context)!.phoneNumber,
          Icons.phone,
          type: TextInputType.phone,
        ),
        _input(
          _emailC,
          AppLocalizations.of(context)!.loginEmail,
          Icons.email,
          type: TextInputType.emailAddress,
          helperText: 'Nhập email đăng nhập của bạn',
        ),
        _input(
          _passC,
          AppLocalizations.of(context)!.password,
          Icons.lock,
          obscure: _obscurePass,
          suffix: IconButton(
            icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePass = !_obscurePass),
          ),
        ),
        _input(
          _confirmPassC,
          AppLocalizations.of(context)!.confirmPassword,
          Icons.lock_clock,
          obscure: _obscureConfirm,
          suffix: IconButton(
            icon: Icon(
              _obscureConfirm ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        _input(_addressC, AppLocalizations.of(context)!.address, Icons.map),
        // Business type selection for store owners (electronics only)
        if (!_isJoinShop) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(77)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cửa hàng điện thoại & điện tử',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quản lý sửa chữa, IMEI, bảo hành',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_isJoinShop) ...[
          _input(
            _inviteCodeC,
            AppLocalizations.of(context)!.shopInviteCode,
            Icons.qr_code,
          ), // Role selection for join shop
          _buildRoleSelector(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.howToGetInviteCode,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: AppTextStyles.headline4.fontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.joinShopInstructions,
                  style: TextStyle(
                    fontSize: AppTextStyles.headline5.fontSize,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInstructionStep(
                  1,
                  AppLocalizations.of(context)!.storeOwnerLogin,
                ),
                _buildInstructionStep(
                  2,
                  AppLocalizations.of(context)!.selectStaffTab,
                ),
                _buildInstructionStep(
                  3,
                  AppLocalizations.of(context)!.selectEmployeeList,
                ),
                _buildInstructionStep(
                  4,
                  AppLocalizations.of(context)!.selectRegisterEmployee,
                ),
                _buildInstructionStep(
                  5,
                  AppLocalizations.of(context)!.ownerProvidesCredentials,
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.loginWithCredentials,
                  style: TextStyle(
                    fontSize: AppTextStyles.subtitle1.fontSize,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_error != null)
          Text(
            _error!,
            style: TextStyle(
              color: AppColors.error,
              fontSize: AppTextStyles.headline5.fontSize,
            ),
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: Text(AppLocalizations.of(context)!.back),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(AppLocalizations.of(context)!.register),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController c,
    String l,
    IconData i, {
    bool obscure = false,
    TextInputType type = TextInputType.text,
    bool readOnly = false,
    Widget? suffix,
    String? helperText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        obscureText: obscure,
        keyboardType: type,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: l,
          prefixIcon: Icon(i, size: 20),
          suffixIcon: suffix,
          helperText: helperText,
          helperStyle: TextStyle(
            fontSize: AppTextStyles.subtitle1.fontSize,
            color: AppColors.textHint,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: AppColors.surface,
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: AppColors.surface,
                  fontSize: AppTextStyles.subtitle1.fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: TextStyle(
                fontSize: AppTextStyles.headline5.fontSize,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    final roles = [
      {
        'value': 'manager',
        'label': '👔 Quản lý',
        'desc': 'Toàn quyền quản lý cửa hàng',
      },
      {
        'value': 'employee',
        'label': '🧑‍💼 Nhân viên',
        'desc': 'Bán hàng, nhận đơn sửa',
      },
      {
        'value': 'technician',
        'label': '🔧 Kỹ thuật',
        'desc': 'Sửa chữa thiết bị',
      },
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Vai trò trong cửa hàng',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppTextStyles.headline4.fontSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...roles.map((r) {
            final selected = _selectedRole == r['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedRole = r['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withAlpha(26)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.outline,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      r['label'] as String,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r['desc'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      selected ? Icons.check_circle : Icons.radio_button_off,
                      color: selected ? AppColors.primary : AppColors.textHint,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
