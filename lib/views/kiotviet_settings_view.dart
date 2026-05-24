import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../services/kiotviet_service.dart';
import '../services/notification_service.dart';
import '../theme/app_button_styles.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/design_tokens.dart';
import '../widgets/custom_app_bar.dart';

class KiotVietSettingsViewDelegate {
  const KiotVietSettingsViewDelegate();

  Future<KiotVietConnectionSnapshot> loadSnapshot({
    KiotVietLogHandler? onLog,
  }) {
    return KiotVietService.loadConnectionSnapshot(onLog: onLog);
  }

  Future<void> saveClientCredentials(String clientId, String clientSecret) {
    return KiotVietService.saveClientCredentials(clientId, clientSecret);
  }

  Future<void> clearClientCredentials() {
    return KiotVietService.clearClientCredentials();
  }

  Future<KiotVietSyncResult> connectAndSync(
    String retailerCode, {
    void Function(String message)? onProgress,
    KiotVietLogHandler? onLog,
  }) {
    return KiotVietService.connectAndSync(
      retailerCode,
      onProgress: onProgress,
      onLog: onLog,
    );
  }

  Future<void> clearConnection() {
    return KiotVietService.clearConnection();
  }

  String normalizeRetailerCode(String input) {
    return KiotVietService.normalizeRetailerCode(input);
  }
}

class KiotVietSettingsView extends StatefulWidget {
  const KiotVietSettingsView({
    super.key,
    this.delegate = const KiotVietSettingsViewDelegate(),
  });

  final KiotVietSettingsViewDelegate delegate;

  @override
  State<KiotVietSettingsView> createState() => _KiotVietSettingsViewState();
}

class _KiotVietSettingsViewState extends State<KiotVietSettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _retailerController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();

  bool _initializing = true;
  bool _connecting = false;
  bool _obscureSecret = true;
  bool _savingCredentials = false;
  String? _initError;
  String? _operationError;
  String? _fieldErrorText;
  String? _credentialsSavedMsg;
  String? _normalizedPreview;
  KiotVietConnectionSnapshot? _snapshot;
  KiotVietSyncResult? _result;
  final List<String> _progressLog = <String>[];
  Future<void> Function()? _retryAction;

  @override
  void initState() {
    super.initState();
    _retailerController.addListener(_handleRetailerInputChanged);
    _logEvent('page_open');
    _retryAction = _initialize;
    _initialize();
  }

  @override
  void dispose() {
    _retailerController.removeListener(_handleRetailerInputChanged);
    _retailerController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _safeSetState(() {
      _initializing = true;
      _initError = null;
    });

    try {
      final snapshot = await widget.delegate.loadSnapshot(onLog: _logEvent);
      if (!mounted) return;
      _retailerController.text = snapshot.retailerCode;
      // Pre-fill client id if already saved (don't pre-fill secret for security)
      if (snapshot.savedClientId.isNotEmpty) {
        _clientIdController.text = snapshot.savedClientId;
      }
      _safeSetState(() {
        _snapshot = snapshot;
        _operationError = snapshot.lastError;
        _initializing = false;
        _fieldErrorText = null;
      });
      _handleRetailerInputChanged();
    } catch (error, stackTrace) {
      _logEvent('init_error', error: error, stackTrace: stackTrace);
      _safeSetState(() {
        _snapshot = null;
        _initializing = false;
        _initError =
            'Không thể tải cấu hình kết nối KiotViet. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _handleSaveCredentials() async {
    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) {
      NotificationService.showSnackBar(
        'Vui lòng nhập đủ Client ID và Client Secret',
        color: AppColors.warning,
      );
      return;
    }
    _safeSetState(() => _savingCredentials = true);
    try {
      await widget.delegate.saveClientCredentials(clientId, clientSecret);
      if (!mounted) return;
      _safeSetState(() {
        _savingCredentials = false;
        _credentialsSavedMsg = 'Đã lưu thông tin xác thực';
      });
      NotificationService.showSnackBar('Đã lưu Client ID & Secret', color: AppColors.success);
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() => _savingCredentials = false);
      NotificationService.showSnackBar('Lỗi khi lưu: $e', color: AppColors.error);
    }
  }

  Future<void> _handleClearCredentials() async {
    await widget.delegate.clearClientCredentials();
    if (!mounted) return;
    _clientIdController.clear();
    _clientSecretController.clear();
    _safeSetState(() => _credentialsSavedMsg = null);
    NotificationService.showSnackBar('Đã xóa thông tin xác thực', color: AppColors.warning);
    await _initialize();
  }

  Future<void> _handleConnect() async {
    FocusScope.of(context).unfocus();
    final rawInput = _retailerController.text;

    String normalizedRetailer;
    try {
      normalizedRetailer = widget.delegate.normalizeRetailerCode(rawInput);
    } on FormatException catch (error) {
      _safeSetState(() {
        _fieldErrorText = error.message;
      });
      return;
    }

    _retailerController.value = TextEditingValue(
      text: normalizedRetailer,
      selection: TextSelection.collapsed(offset: normalizedRetailer.length),
    );

    _safeSetState(() {
      _connecting = true;
      _fieldErrorText = null;
      _operationError = null;
      _result = null;
      _progressLog.clear();
      _normalizedPreview = normalizedRetailer;
      _retryAction = _handleConnect;
    });

    try {
      final result = await widget.delegate.connectAndSync(
        normalizedRetailer,
        onProgress: _appendProgress,
        onLog: _logEvent,
      );
      final snapshot = await widget.delegate.loadSnapshot(onLog: _logEvent);
      if (!mounted) return;
      _safeSetState(() {
        _snapshot = snapshot;
        _result = result;
        _operationError = null;
      });
      NotificationService.showSnackBar(
        'Kết nối KiotViet thành công. Đã thêm ${result.added}, cập nhật ${result.updated}, lỗi ${result.failed}.',
        color: result.failed > 0 ? AppColors.warning : AppColors.success,
      );
    } catch (error, stackTrace) {
      _logEvent('connect_error', error: error, stackTrace: stackTrace);
      final message = _toUserMessage(error);
      _appendProgress(message);
      _safeSetState(() {
        _operationError = message;
      });
      NotificationService.showSnackBar(message, color: AppColors.error);
    } finally {
      _safeSetState(() {
        _connecting = false;
      });
    }
  }

  Future<void> _handleClearConnection() async {
    await widget.delegate.clearConnection();
    _retailerController.clear();
    _safeSetState(() {
      _snapshot = KiotVietConnectionSnapshot(
        retailerCode: '',
        hasSecureConfiguration: KiotVietService.hasSecureConfiguration,
        hasCachedToken: false,
      );
      _operationError = null;
      _result = null;
      _progressLog.clear();
      _fieldErrorText = null;
      _normalizedPreview = null;
      _retryAction = _initialize;
    });
  }

  void _handleRetailerInputChanged() {
    final input = _retailerController.text;
    if (input.trim().isEmpty) {
      _safeSetState(() {
        _normalizedPreview = null;
        _fieldErrorText = null;
      });
      return;
    }

    try {
      final normalized = widget.delegate.normalizeRetailerCode(input);
      _safeSetState(() {
        _normalizedPreview = normalized;
        _fieldErrorText = null;
      });
    } on FormatException catch (error) {
      _safeSetState(() {
        _normalizedPreview = null;
        _fieldErrorText = error.message;
      });
    }
  }

  void _appendProgress(String message) {
    _safeSetState(() {
      _progressLog.add(message);
    });
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _toUserMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('KIOTVIET_CLIENT_ID') ||
        raw.contains('KIOTVIET_CLIENT_SECRET')) {
      return 'KiotViet chưa được cấu hình bảo mật trên ứng dụng. Vui lòng liên hệ quản trị viên để thêm dart-define an toàn.';
    }
    if (raw.contains('token') || raw.contains('Không lấy được token')) {
      return 'Không thể xác thực với KiotViet. Hãy kiểm tra mã cửa hàng hoặc thử lại sau.';
    }
    if (raw.contains('timed out')) {
      return 'Kết nối KiotViet bị quá thời gian chờ. Vui lòng kiểm tra mạng và thử lại.';
    }
    return 'Kết nối KiotViet thất bại. Vui lòng thử lại.';
  }

  void _logEvent(
    String event, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extras = const {},
  }) {
    final payload = <String, Object?>{
      'event': event,
      'source': 'KiotVietSettingsView',
      ...extras,
      'retailerPreview': _normalizedPreview,
    };
    developer.log(
      jsonEncode(payload),
      name: 'KiotVietPage',
      error: error,
      stackTrace: stackTrace,
    );
    if (stackTrace != null) {
      developer.log(
        stackTrace.toString(),
        name: 'KiotVietPageStackTrace',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar.build(title: 'Kết nối KiotViet'),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: DesignTokens.motionNormal,
            child: _buildBody(),
          ),
        ),
      );
    } catch (error, stackTrace) {
      _logEvent('build_error', error: error, stackTrace: stackTrace);
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar.build(title: 'Kết nối KiotViet'),
        body: _buildFullscreenState(
          icon: Icons.error_outline,
          iconColor: AppColors.error,
          title: 'Đã xảy ra lỗi hiển thị',
          description:
              'Trang vẫn được giữ an toàn. Bạn có thể thử tải lại mà không ảnh hưởng dữ liệu hiện tại.',
          actionLabel: 'Tải lại',
          onAction: _retryAction ?? _initialize,
        ),
      );
    }
  }

  Widget _buildBody() {
    if (_initializing) {
      return _buildFullscreenState(
        icon: Icons.sync,
        iconColor: AppColors.primary,
        title: 'Đang tải cấu hình KiotViet',
        description:
            'Ứng dụng đang kiểm tra cấu hình bảo mật, retailer đã lưu và token hiện có.',
        loading: true,
      );
    }

    if (_initError != null) {
      return _buildFullscreenState(
        icon: Icons.cloud_off,
        iconColor: AppColors.error,
        title: 'Không thể mở trang KiotViet',
        description: _initError!,
        actionLabel: 'Thử lại',
        onAction: _initialize,
      );
    }

    return ListView(
      padding: AppSpacing.pLg,
      children: [
        _buildHeroCard(),
        AppSpacing.gapLg,
        _buildConnectionCard(),
        AppSpacing.gapLg,
        _buildStatusCard(),
        if (_progressLog.isNotEmpty) ...[
          AppSpacing.gapLg,
          _buildLogCard(),
        ],
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: AppSpacing.pLg,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: DesignTokens.brLg,
        boxShadow: DesignTokens.shadowElevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(36),
              borderRadius: DesignTokens.brMd,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: AppColors.surface,
              size: 24,
            ),
          ),
          AppSpacing.gapMd,
          Text(
            'Kết nối cửa hàng KiotViet',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.onPrimary,
            ),
          ),
          AppSpacing.gapSm,
          Text(
            'Nhập tên cửa hàng KiotViet của bạn để kết nối và đồng bộ dữ liệu.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.surface.withAlpha(235),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: DesignTokens.brLg,
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: AppSpacing.pLg,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Credentials section ---
              const Text(
                'Thông tin xác thực API',
                style: AppTypography.titleSmall,
              ),
              AppSpacing.gapSm,
              Text(
                'Nhập Client ID và Client Secret từ ứng dụng KiotViet của bạn. Thông tin được lưu mã hoá trên thiết bị.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              AppSpacing.gapMd,
              TextFormField(
                controller: _clientIdController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Client ID',
                  hintText: 'Nhập Client ID',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              AppSpacing.gapSm,
              TextFormField(
                controller: _clientSecretController,
                textInputAction: TextInputAction.done,
                obscureText: _obscureSecret,
                decoration: InputDecoration(
                  labelText: 'Client Secret',
                  hintText: 'Nhập Client Secret',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => _safeSetState(() => _obscureSecret = !_obscureSecret),
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              AppSpacing.gapSm,
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _savingCredentials ? null : _handleSaveCredentials,
                      style: AppButtonStyles.elevatedButtonStyle,
                      icon: _savingCredentials
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_savingCredentials ? 'Đang lưu...' : 'Lưu thông tin xác thực'),
                    ),
                  ),
                  if (_snapshot?.hasUserCredentials == true) ...[
                    AppSpacing.hSm,
                    TextButton(
                      onPressed: _savingCredentials ? null : _handleClearCredentials,
                      style: AppButtonStyles.textButtonStyle,
                      child: const Text('Xóa'),
                    ),
                  ],
                ],
              ),
              if (_credentialsSavedMsg != null) ...[
                AppSpacing.gapSm,
                Container(
                  padding: AppSpacing.pSm,
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: DesignTokens.brMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      AppSpacing.hSm,
                      Text(
                        _credentialsSavedMsg!,
                        style: AppTypography.bodySmall.copyWith(color: AppColors.success),
                      ),
                    ],
                  ),
                ),
              ],
              AppSpacing.gapLg,
              const Divider(),
              AppSpacing.gapMd,
              // --- Retailer section ---
              const Text(
                'Mã cửa hàng KiotViet',
                style: AppTypography.titleSmall,
              ),
              AppSpacing.gapSm,
              Text(
                'Bạn có thể nhập dạng `huymobile` hoặc URL đầy đủ như `https://huymobile.kiotviet.vn`.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              AppSpacing.gapMd,
              TextFormField(
                controller: _retailerController,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleConnect(),
                decoration: InputDecoration(
                  labelText: 'Mã cửa hàng KiotViet',
                  hintText: 'Ví dụ: huymobile',
                  errorText: _fieldErrorText,
                  prefixIcon: const Icon(Icons.apartment_outlined),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: DesignTokens.brMd,
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              if (_normalizedPreview != null) ...[
                AppSpacing.gapSm,
                Container(
                  padding: AppSpacing.pSm,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: DesignTokens.brMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          'Ứng dụng sẽ chuẩn hóa thành: $_normalizedPreview',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              AppSpacing.gapLg,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _connecting ? null : _handleConnect,
                  style: AppButtonStyles.elevatedButtonStyle,
                  icon: _connecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(
                    _connecting ? 'Đang kết nối...' : 'Kết nối KiotViet',
                  ),
                ),
              ),
              if (_snapshot?.hasSavedRetailer == true ||
                  _retailerController.text.trim().isNotEmpty) ...[
                AppSpacing.gapSm,
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _connecting ? null : _handleClearConnection,
                    style: AppButtonStyles.textButtonStyle,
                    child: const Text('Xóa mã đã lưu'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (!_snapshotSafeToUse) {
      return _buildInlineStateCard(
        icon: Icons.info_outline,
        iconColor: AppColors.info,
        title: 'Sẵn sàng kết nối',
        description:
            'Chưa có retailer nào được lưu. Nhập mã cửa hàng rồi nhấn kết nối để bắt đầu đồng bộ.',
      );
    }

    if (!_snapshot!.hasSecureConfiguration) {
      return _buildInlineStateCard(
        icon: Icons.lock_outline,
        iconColor: AppColors.warning,
        title: 'Thiếu cấu hình bảo mật nội bộ',
        description:
            'Ứng dụng đang ẩn Client ID và Client Secret. Hãy cấu hình `KIOTVIET_CLIENT_ID` và `KIOTVIET_CLIENT_SECRET` bằng dart-define trước khi kết nối.',
      );
    }

    if (_operationError != null) {
      return _buildInlineStateCard(
        icon: Icons.error_outline,
        iconColor: AppColors.error,
        title: 'Kết nối chưa thành công',
        description: _operationError!,
        actionLabel: 'Thử lại',
        onAction: _retryAction ?? _handleConnect,
      );
    }

    if (_connecting) {
      return _buildInlineStateCard(
        icon: Icons.sync,
        iconColor: AppColors.primary,
        title: 'Đang xác thực và đồng bộ',
        description:
            'Ứng dụng đang lấy token KiotViet, lưu cấu hình an toàn và đồng bộ dữ liệu về máy.',
        loading: true,
      );
    }

    if (_result != null) {
      return Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.brLg,
          side: const BorderSide(color: AppColors.outline),
        ),
        child: Padding(
          padding: AppSpacing.pLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: DesignTokens.brMd,
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  AppSpacing.hMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kết nối thành công',
                          style: AppTypography.titleSmall,
                        ),
                        Text(
                          'Retailer: ${_snapshot?.retailerCode ?? _normalizedPreview ?? ''}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              _buildMetricRow('Thêm mới', _result!.added, AppColors.success),
              _buildMetricRow('Cập nhật', _result!.updated, AppColors.primary),
              _buildMetricRow('Lỗi', _result!.failed, AppColors.error),
              if (_snapshot?.lastConnectedAt != null) ...[
                AppSpacing.gapSm,
                Text(
                  'Token và retailer đã được lưu nội bộ để dùng cho lần đồng bộ tiếp theo.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return _buildInlineStateCard(
      icon: _snapshot!.hasCachedToken ? Icons.link : Icons.link_off,
      iconColor: _snapshot!.hasCachedToken ? AppColors.success : AppColors.info,
      title: _snapshot!.hasCachedToken
          ? 'Đã có phiên KiotViet khả dụng'
          : 'Chưa có phiên xác thực đang hoạt động',
      description: _snapshot!.hasCachedToken
          ? 'Retailer ${_snapshot!.retailerCode} đã có token hợp lệ. Bạn có thể kết nối lại để đồng bộ dữ liệu mới nhất.'
          : 'Retailer ${_snapshot!.retailerCode} đã được lưu. Nhấn kết nối để xác thực lại và đồng bộ dữ liệu.',
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: DesignTokens.brLg,
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: AppSpacing.pLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nhật ký kết nối',
                  style: AppTypography.titleSmall,
                ),
                TextButton(
                  onPressed: () {
                    _safeSetState(() {
                      _progressLog.clear();
                    });
                  },
                  style: AppButtonStyles.textButtonStyle,
                  child: const Text('Xóa'),
                ),
              ],
            ),
            AppSpacing.gapSm,
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _progressLog.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final message = _progressLog[index];
                  final isError = message.toLowerCase().contains('lỗi') ||
                      message.toLowerCase().contains('thất bại');
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isError
                            ? Icons.error_outline
                            : Icons.check_circle_outline,
                        size: 18,
                        color: isError ? AppColors.error : AppColors.success,
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          message,
                          style: AppTypography.bodySmall.copyWith(
                            color: isError
                                ? AppColors.error
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, int value, Color color) {
    return Padding(
      padding: AppSpacing.pvXs,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Text(label, style: AppTypography.bodyMedium),
          ),
          Text(
            '$value',
            style: AppTypography.titleSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStateCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    bool loading = false,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: DesignTokens.brLg,
        side: const BorderSide(color: AppColors.outline),
      ),
      child: Padding(
        padding: AppSpacing.pLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(24),
                    borderRadius: DesignTokens.brMd,
                  ),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: iconColor,
                          ),
                        )
                      : Icon(icon, color: iconColor),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: Text(title, style: AppTypography.titleSmall),
                ),
              ],
            ),
            AppSpacing.gapSm,
            Text(
              description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              AppSpacing.gapMd,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onAction,
                  style: AppButtonStyles.outlinedButtonStyle,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullscreenState({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
    bool loading = false,
  }) {
    return Center(
      child: Padding(
        padding: AppSpacing.pLg,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: DesignTokens.brLg,
              side: const BorderSide(color: AppColors.outline),
            ),
            child: Padding(
              padding: AppSpacing.pLg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(24),
                      borderRadius: DesignTokens.brLg,
                    ),
                    child: loading
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: iconColor,
                            ),
                          )
                        : Icon(icon, color: iconColor, size: 30),
                  ),
                  AppSpacing.gapMd,
                  Text(
                    title,
                    style: AppTypography.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapSm,
                  Text(
                    description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (actionLabel != null && onAction != null) ...[
                    AppSpacing.gapLg,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onAction,
                        style: AppButtonStyles.elevatedButtonStyle,
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _snapshotSafeToUse => _snapshot != null;
}
