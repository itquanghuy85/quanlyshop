import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/responsive_wrapper.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../services/adjustment_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

/// View hiển thị lịch sử bút toán điều chỉnh
class AdjustmentHistoryView extends StatefulWidget {
  final String? entityType;
  final String? entityId;

  const AdjustmentHistoryView({super.key, this.entityType, this.entityId});

  @override
  State<AdjustmentHistoryView> createState() => _AdjustmentHistoryViewState();
}

class _AdjustmentHistoryViewState extends State<AdjustmentHistoryView> {
  final db = DBHelper();
  List<Map<String, dynamic>> _adjustments = [];
  bool _isLoading = true;
  bool _canViewCostPrice = false;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadAdjustments();
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    if (!mounted) return;
    setState(() {
      _canViewCostPrice = perms['allowViewCostPrice'] ?? false;
    });
  }

  Future<void> _loadAdjustments() async {
    setState(() => _isLoading = true);

    try {
      final adjustments = await AdjustmentService.getAdjustmentHistory(
        entityType: widget.entityType,
        entityId: widget.entityId,
        limit: 100,
      );

      debugPrint('📋 Loaded ${adjustments.length} adjustment entries');

      if (!mounted) return;
      setState(() {
        _adjustments = adjustments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading adjustments: $e');
      if (!mounted) return;
      setState(() {
        _adjustments = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text("LỊCH SỬ ĐIỀU CHỈNH"),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _loadAdjustments,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ResponsiveCenter(child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _adjustments.isEmpty
          ? _buildEmpty()
          : _buildList()),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Chưa có bút toán điều chỉnh nào",
            style: AppTextStyles.body1.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _adjustments.length,
      itemBuilder: (ctx, i) => _buildAdjustmentCard(_adjustments[i]),
    );
  }

  Widget _buildAdjustmentCard(Map<String, dynamic> adj) {
    final adjustmentDate = DateTime.fromMillisecondsSinceEpoch(
      adj['adjustmentDate'] as int? ?? 0,
    );
    final originalDate = DateTime.fromMillisecondsSinceEpoch(
      adj['originalDate'] as int? ?? 0,
    );
    final adjustmentType = adj['adjustmentType'] as String? ?? '';
    final description = adj['description'] as String? ?? '';
    final reason = adj['reason'] as String? ?? '';
    final createdBy = adj['createdBy'] as String? ?? 'N/A';
    final costDelta = adj['costDelta'] as int? ?? 0;
    final debtDelta = adj['debtDelta'] as int? ?? 0;

    // Parse old/new values
    Map<String, dynamic> oldValues = {};
    Map<String, dynamic> newValues = {};
    try {
      if (adj['oldValues'] != null) {
        oldValues = jsonDecode(adj['oldValues'] as String);
      }
      if (adj['newValues'] != null) {
        newValues = jsonDecode(adj['newValues'] as String);
      }
    } catch (_) {}

    final typeColor = _getTypeColor(adjustmentType);
    final typeIcon = _getTypeIcon(adjustmentType);
    final typeLabel = _getTypeLabel(adjustmentType);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        boxShadow: [
          BoxShadow(color: AppColors.textPrimary.withAlpha(10), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: typeColor.withAlpha(26),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.lg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        typeLabel,
                        style: AppTextStyles.headline5.copyWith(
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                        ),
                      ),
                      Text(
                        description,
                        style: AppTextStyles.body2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dates
                Row(
                  children: [
                    const Icon(Icons.event_note, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      "Ngày gốc: ${DateFormat('dd/MM/yyyy').format(originalDate)}",
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.edit_calendar,
                      size: 14,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Điều chỉnh: ${DateFormat('dd/MM/yyyy HH:mm').format(adjustmentDate)}",
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // Reason
                if (reason.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(26),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.notes,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            "Lý do: $reason",
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                // Deltas
                if ((_canViewCostPrice && costDelta != 0) || debtDelta != 0)
                  Row(
                    children: [
                      if (_canViewCostPrice && costDelta != 0)
                        _buildDeltaChip(
                          "Chi phí",
                          costDelta,
                          costDelta > 0 ? AppColors.error : AppColors.success,
                        ),
                      if (_canViewCostPrice && costDelta != 0) const SizedBox(width: 8),
                      if (debtDelta != 0)
                        _buildDeltaChip(
                          "Công nợ",
                          debtDelta,
                          debtDelta > 0 ? AppColors.warning : AppColors.success,
                        ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                // Old -> New values
                if (oldValues.isNotEmpty || newValues.isNotEmpty)
                  _buildValueComparison(oldValues, newValues),
                const SizedBox(height: AppSpacing.sm),
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Người thực hiện: $createdBy",
                      style: AppTextStyles.overline.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(26),
                        borderRadius: BorderRadius.circular(AppSpacing.md),
                      ),
                      child: Text(
                        "ĐÃ DUYỆT",
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaChip(String label, int delta, Color color) {
    final sign = delta > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        "$label: $sign${NumberFormat('#,###').format(delta)}đ",
        style: AppTextStyles.body1.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildValueComparison(
    Map<String, dynamic> oldVals,
    Map<String, dynamic> newVals,
  ) {
    final allKeys = {...oldVals.keys, ...newVals.keys};

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.textHint.withAlpha(13),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Chi tiết thay đổi:",
            style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xs),
          ...allKeys.map((key) {
            // Hide cost values when no permission
            if (!_canViewCostPrice && (key == 'cost' || key == 'totalCost')) {
              return const SizedBox.shrink();
            }
            final oldVal = oldVals[key];
            final newVal = newVals[key];
            final oldStr = _formatValue(oldVal);
            final newStr = _formatValue(newVal);

            if (oldStr == newStr) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    "${_translateKey(key)}: ",
                    style: AppTextStyles.body1.copyWith(color: AppColors.textHint),
                  ),
                  Text(
                    oldStr,
                    style: AppTextStyles.body1.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: AppColors.error,
                    ),
                  ),
                  Text(" → ", style: AppTextStyles.body1),
                  Text(
                    newStr,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'N/A';
    if (value is int) {
      return '${NumberFormat('#,###').format(value)}đ';
    }
    return value.toString();
  }

  String _translateKey(String key) {
    switch (key) {
      case 'cost':
        return 'Giá vốn';
      case 'totalCost':
        return 'Tổng giá vốn';
      case 'totalAmount':
        return 'Tổng tiền';
      case 'paidAmount':
        return 'Đã thanh toán';
      case 'paymentMethod':
        return 'Hình thức TT';
      default:
        return key;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'COST_ADJUSTMENT':
        return AppColors.warning;
      case 'PAYMENT_ADJUSTMENT':
        return AppColors.primary;
      case 'DEBT_ADJUSTMENT':
        return AppColors.primary;
      case 'SALES_RETURN_INVENTORY':
        return AppColors.info;
      case 'SALES_RETURN_REFUND':
        return AppColors.error;
      default:
        return AppColors.textHint;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'COST_ADJUSTMENT':
        return Icons.price_change;
      case 'PAYMENT_ADJUSTMENT':
        return Icons.payment;
      case 'DEBT_ADJUSTMENT':
        return Icons.account_balance_wallet;
      case 'SALES_RETURN_INVENTORY':
        return Icons.inventory_2;
      case 'SALES_RETURN_REFUND':
        return Icons.currency_exchange;
      default:
        return Icons.edit_document;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'COST_ADJUSTMENT':
        return 'ĐIỀU CHỈNH GIÁ NHẬP';
      case 'PAYMENT_ADJUSTMENT':
        return 'ĐIỀU CHỈNH THANH TOÁN';
      case 'DEBT_ADJUSTMENT':
        return 'ĐIỀU CHỈNH CÔNG NỢ';
      case 'SALES_RETURN_INVENTORY':
        return 'TRẢ HÀNG - HOÀN KHO';
      case 'SALES_RETURN_REFUND':
        return 'TRẢ HÀNG - HOÀN TIỀN';
      default:
        return 'BÚT TOÁN ĐIỀU CHỈNH';
    }
  }
}
