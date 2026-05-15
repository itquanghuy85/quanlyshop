import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/utils/money_utils.dart';
import '../data/db_helper.dart';
import '../models/customer_model.dart';
import '../services/customer_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_spacing.dart';
import '../theme/design_tokens.dart';
import '../widgets/entity_avatar.dart';
import '../widgets/responsive_wrapper.dart';
import 'repair_detail_view.dart';
import 'sale_detail_view.dart';

class CustomerProfileView extends StatefulWidget {
  final Customer customer;

  const CustomerProfileView({super.key, required this.customer});

  @override
  State<CustomerProfileView> createState() => _CustomerProfileViewState();
}

class _CustomerProfileViewState extends State<CustomerProfileView> {
  final _service = CustomerService();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _saving = false;
  bool _loadingHistory = true;
  String _avatarUrl = '';
  String? _pendingAvatarPath;

  Map<String, dynamic> _history = const {
    'history': <dynamic>[],
    'totalSales': 0,
    'totalRepairs': 0,
    'totalPayments': 0,
    'totalSpent': 0,
    'totalRepairCost': 0,
    'totalPaymentAmount': 0,
  };

  String _historyFilter = 'all';

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone;
    _emailCtrl.text = c.email ?? '';
    _addressCtrl.text = c.address ?? '';
    _notesCtrl.text = c.notes ?? '';
    _avatarUrl = c.avatarUrl ?? '';
    _loadHistory();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final data = await _service.getCustomerHistory(_phoneCtrl.text.trim());
      if (!mounted) return;
      setState(() => _history = data);
    } catch (e) {
      NotificationService.showSnackBar('Không tải được lịch sử: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_saving) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2200,
    );
    if (picked == null) return;
    setState(() {
      _pendingAvatarPath = picked.path;
      _avatarUrl = picked.path;
    });
    NotificationService.showSnackBar(
      'Đã chọn ảnh khách hàng. Nhấn Lưu để tải lên.',
      color: AppColors.primary,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      NotificationService.showSnackBar('Tên và số điện thoại là bắt buộc', color: AppColors.error);
      return;
    }

    final base = widget.customer;
    String finalAvatarUrl = _avatarUrl;

    setState(() => _saving = true);
    try {
      if (_pendingAvatarPath != null && _pendingAvatarPath!.trim().isNotEmpty) {
        NotificationService.showSnackBar(
          'Đang tải ảnh khách hàng lên hệ thống...',
          color: AppColors.primary,
          duration: const Duration(seconds: 6),
        );
        final urls = await StorageService.uploadMultipleImages([
          _pendingAvatarPath!,
        ], 'user_photos');
        if (urls.isEmpty || urls.first.trim().isEmpty) {
          NotificationService.showSnackBar(
            'Tải ảnh khách hàng thất bại, vui lòng thử lại',
            color: AppColors.error,
          );
          return;
        }
        finalAvatarUrl = urls.first;
      }

    final updated = base.copyWith(
      avatarUrl: finalAvatarUrl,
      name: name,
      phone: phone,
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

      final ok = await _service.updateCustomer(updated);
      if (!mounted) return;
      if (!ok) {
        NotificationService.showSnackBar('Lưu khách hàng thất bại', color: AppColors.error);
        return;
      }
      _avatarUrl = finalAvatarUrl;
      _pendingAvatarPath = null;
      NotificationService.showSnackBar('Đã lưu hồ sơ khách hàng', color: AppColors.success);
      Navigator.pop(context, updated);
    } catch (e) {
      NotificationService.showSnackBar('Lỗi lưu khách hàng: $e', color: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCustomer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa khách hàng'),
        content: Text('Bạn có chắc muốn xóa ${_nameCtrl.text.trim()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final id = widget.customer.id;
      if (id == null) return;
      final deleted = await _service.deleteCustomer(id);
      if (!mounted) return;
      if (!deleted) {
        NotificationService.showSnackBar('Xóa khách hàng thất bại', color: AppColors.error);
        return;
      }
      NotificationService.showSnackBar('Đã xóa khách hàng', color: AppColors.success);
      Navigator.pop(context, {'deleted': true});
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openOrder(Map<String, dynamic> h) async {
    final type = (h['type'] ?? '').toString();
    final id = (h['id'] as num?)?.toInt();
    if (id == null) return;
    if (type == 'sale') {
      final sale = await DBHelper().getSaleById(id);
      if (!mounted) return;
      if (sale == null) {
        NotificationService.showSnackBar('Không tìm thấy đơn bán', color: AppColors.warning);
        return;
      }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => SaleDetailView(sale: sale)));
    } else if (type == 'repair') {
      final repair = await DBHelper().getRepairById(id);
      if (!mounted) return;
      if (repair == null) {
        NotificationService.showSnackBar('Không tìm thấy đơn sửa', color: AppColors.warning);
        return;
      }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => RepairDetailView(repair: repair)));
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    final all = List<Map<String, dynamic>>.from(_history['history'] as List<dynamic>? ?? const []);
    if (_historyFilter == 'all') return all;
    return all.where((e) => (e['type'] ?? '').toString() == _historyFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalSpent = (_history['totalSpent'] as int?) ?? widget.customer.totalSpent;
    final totalRepair = (_history['totalRepairCost'] as int?) ?? widget.customer.totalRepairCost;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ khách hàng'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
        ),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            // ── Header banner ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => EntityAvatar.showPreview(
                      context,
                      _avatarUrl,
                      _nameCtrl.text.trim(),
                    ),
                    child: Stack(
                      children: [
                        EntityAvatar(
                          imageUrl: _avatarUrl,
                          name: _nameCtrl.text.trim().isEmpty ? 'KH' : _nameCtrl.text.trim(),
                          radius: 28,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 12, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameCtrl.text.trim().isEmpty ? 'Khách hàng' : _nameCtrl.text.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.headline6.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _phoneCtrl.text.trim(),
                          style: AppTextStyles.body2.copyWith(color: Colors.white70),
                        ),
                        if (_emailCtrl.text.trim().isNotEmpty)
                          Text(
                            _emailCtrl.text.trim(),
                            style: AppTextStyles.caption.copyWith(color: Colors.white60),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Stat cards ─────────────────────────────────────────
            const SizedBox(height: 12),
            Padding(
              padding: AppSpacing.phMd,
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Đã mua',
                      MoneyUtils.formatCompact(totalSpent),
                      Icons.shopping_cart_checkout,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Số lần sửa',
                      '${widget.customer.totalRepairs}',
                      Icons.build,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _statCard(
                      'Tổng sửa',
                      MoneyUtils.formatCompact(totalRepair),
                      Icons.receipt_long,
                    ),
                  ),
                ],
              ),
            ),

            // ── Quick actions card ──────────────────────────────────
            AppSpacing.gapMd,
            _sectionCard(
              label: 'TÁC VỤ NHANH',
              icon: Icons.flash_on_rounded,
              iconBg: AppColors.iconBgYellow,
              iconColor: AppColors.warning,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _actionChip('Tất cả', 'all'),
                        _actionChip('Mua bán', 'sale'),
                        _actionChip('Sửa chữa', 'repair'),
                        _actionChip('Thanh toán', 'payment'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save, size: DesignTokens.iconMd),
                            label: const Text('Lưu'),
                          ),
                        ),
                        AppSpacing.hSm,
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _deleteCustomer,
                            icon: const Icon(Icons.delete_outline, size: DesignTokens.iconMd, color: AppColors.error),
                            label: const Text('Xóa', style: TextStyle(color: AppColors.error)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Customer info card ──────────────────────────────────
            AppSpacing.gapMd,
            _sectionCard(
              label: 'THÔNG TIN KHÁCH HÀNG',
              icon: Icons.person_outline_rounded,
              iconBg: AppColors.iconBgBlue,
              iconColor: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person)),
                      onChanged: (_) => setState(() {}),
                    ),
                    AppSpacing.gapSm,
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Số điện thoại', prefixIcon: Icon(Icons.phone)),
                    ),
                    AppSpacing.gapSm,
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                    ),
                    AppSpacing.gapSm,
                    TextField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Địa chỉ', prefixIcon: Icon(Icons.location_on)),
                    ),
                    AppSpacing.gapSm,
                    TextField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Ghi chú', prefixIcon: Icon(Icons.notes)),
                    ),
                  ],
                ),
              ),
            ),

            // ── Transaction history card ────────────────────────────
            AppSpacing.gapMd,
            _sectionCard(
              label: 'LỊCH SỬ GIAO DỊCH',
              icon: Icons.history_rounded,
              iconBg: AppColors.iconBgGreen,
              iconColor: AppColors.success,
              trailing: _loadingHistory
                  ? const SizedBox(
                      width: DesignTokens.iconSm,
                      height: DesignTokens.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              child: _filteredHistory.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                      child: Text('Chưa có lịch sử phù hợp', style: AppTextStyles.caption),
                    )
                  : Column(
                      children: [
                        ..._filteredHistory.take(20).map((h) {
                          final dateMs = (h['date'] as int?) ?? 0;
                          final amount = (h['amount'] as int?) ?? 0;
                          final dateText = dateMs > 0
                              ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(dateMs))
                              : '--';
                          final type = (h['type'] ?? '').toString();
                          final description = (h['description'] ?? '').toString();
                          final label = type == 'sale'
                              ? 'Mua bán'
                              : (type == 'repair' ? 'Sửa chữa' : 'Thanh toán');
                          final canTap = type == 'sale' || type == 'repair';
                          final iconBg = type == 'sale'
                              ? AppColors.iconBgGreen
                              : (type == 'repair' ? AppColors.iconBgOrange : AppColors.iconBgBlue);
                          final iconColor = type == 'sale'
                              ? AppColors.success
                              : (type == 'repair' ? AppColors.warning : AppColors.info);
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: canTap ? () => _openOrder(h) : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: DesignTokens.iconContainer,
                                        height: DesignTokens.iconContainer,
                                        decoration: BoxDecoration(
                                          color: iconBg,
                                          borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                                        ),
                                        child: Icon(
                                          type == 'sale'
                                              ? Icons.shopping_bag
                                              : (type == 'repair' ? Icons.build : Icons.payments_outlined),
                                          size: DesignTokens.iconMd,
                                          color: iconColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(label, style: AppTextStyles.body2.copyWith(fontWeight: FontWeight.w600)),
                                            if (description.isNotEmpty)
                                              Text(description, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text(dateText, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        MoneyUtils.formatCompact(amount),
                                        style: AppTextStyles.body2.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (canTap) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right, size: DesignTokens.iconSm, color: AppColors.textHint),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 1, color: AppColors.divider),
                            ],
                          );
                        }),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String label,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      margin: AppSpacing.phMd,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                Container(
                  width: DesignTokens.iconContainer,
                  height: DesignTokens.iconContainer,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusSm),
                  ),
                  child: Icon(icon, size: DesignTokens.iconMd, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          child,
        ],
      ),
    );
  }

  Widget _actionChip(String label, String value) {
    final selected = _historyFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _historyFilter = value);
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMd),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: DesignTokens.iconMd),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body1.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
