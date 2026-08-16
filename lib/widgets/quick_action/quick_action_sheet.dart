import 'package:flutter/material.dart';
import 'quick_action_controller.dart';
import '../../views/create_repair_order_view.dart';
import '../../views/create_sale_view.dart';
import '../../views/smart_stock_in_view.dart';
import '../../views/debt_view.dart';
import '../../views/expense_view.dart';
import '../../views/salvage_phone_view.dart';

class QuickActionSheet extends StatelessWidget {
  final QuickActionController controller;
  final VoidCallback onClose;

  const QuickActionSheet({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = controller.side < 0.5;
    final actions = _buildActions(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.scale(
          scale: 0.88 + 0.12 * v,
          alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          child: child,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 204,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: Color(0xFF252540),
                      indent: 52,
                      endIndent: 0,
                    ),
                  _ActionTile(item: actions[i], onDone: onClose),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_ActionItem> _buildActions(BuildContext context) {
    void push(Widget view) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => view));
    }

    final items = <_ActionItem>[];

    if (controller.enableRepair) {
      items.add(
        _ActionItem(
          icon: Icons.build_rounded,
          label: 'Tạo sửa mới',
          color: const Color(0xFF7986CB),
          onTap: () => push(CreateRepairOrderView(role: controller.role)),
        ),
      );
    }

    items.addAll([
      _ActionItem(
        icon: Icons.shopping_cart_rounded,
        label: 'Tạo bán mới',
        color: const Color(0xFF26C6DA),
        onTap: () => push(const CreateSaleView()),
      ),
      _ActionItem(
        icon: Icons.inventory_2_rounded,
        label: 'Tạo sản phẩm mới',
        color: const Color(0xFF66BB6A),
        onTap: () => push(const SmartStockInView()),
      ),
      _ActionItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Tạo công nợ mới',
        color: const Color(0xFFEF5350),
        onTap: () => push(const DebtView()),
      ),
      _ActionItem(
        icon: Icons.receipt_long_rounded,
        label: 'Tạo thu chi mới',
        color: const Color(0xFFFF7043),
        onTap: () => push(
          const ExpenseView(initialMode: 'CHI', openCreateDialogOnStart: true),
        ),
      ),
      _ActionItem(
        icon: Icons.phonelink_erase_rounded,
        label: 'Tạo máy xác mới',
        color: const Color(0xFF8D6E63),
        onTap: () => push(const SalvagePhoneView()),
      ),
    ]);

    return items;
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionItem item;
  final VoidCallback onDone;

  const _ActionTile({required this.item, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap == null
          ? null
          : () {
              onDone();
              item.onTap!();
            },
      highlightColor: item.color.withValues(alpha: 0.08),
      splashColor: item.color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFFE8E8F0),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ],
        ),
      ),
    );
  }
}
