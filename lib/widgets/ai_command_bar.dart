import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_command_result.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../views/attendance_view.dart';
import '../views/create_repair_order_view.dart';
import '../views/create_sale_view.dart';
import '../views/customer_management_view.dart';
import '../views/debt_view.dart';
import '../views/expense_view.dart';
import '../views/inventory_view.dart';
import '../views/order_list_view.dart';
import '../views/smart_stock_in_view.dart';
import '../widgets/ai_command_overlay.dart';
import '../widgets/ai_order_input_sheet.dart';

// ── Bar ────────────────────────────────────────────────────────────────────────

/// Thin persistent bar shown above the bottom navigation.
/// Tap anywhere → [AiCommandOverlay] opens fullscreen.
class AiCommandBar extends StatefulWidget {
  final String role;
  const AiCommandBar({super.key, required this.role});

  @override
  State<AiCommandBar> createState() => _AiCommandBarState();
}

class _AiCommandBarState extends State<AiCommandBar> {
  static const _hints = [
    'Nói: tạo đơn sửa...',
    'Nói: nhập kho...',
    'Nói: bán hàng...',
    'Nói: tài chính hôm nay',
    'Nói: tìm khách...',
    'Nói: công nợ',
    'Nói: chấm công vào',
    'Nói: kiểm kho',
  ];

  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  Future<void> _open() async {
    final result = await AiCommandOverlay.show(context);
    if (result == null || !mounted) return;
    await _execute(result);
  }

  Future<void> _execute(AiCommandResult result) async {
    if (!mounted) return;
    switch (result.intent) {
      case AiCommandIntent.createRepair:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (_) => CreateRepairOrderView(
            role: widget.role,
            initialAiText: result.payload,
          ),
        ));
      case AiCommandIntent.createSale:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (_) => CreateSaleView(initialAiText: result.payload),
        ));
      case AiCommandIntent.stockEntry:
        if (result.payload != null) {
          // Show AI sheet first so user can review the parsed stock data
          // ignore: use_build_context_synchronously
          final draft = await AiOrderInputSheet.show(
            context,
            mode: AiSheetMode.stock,
            prefilledText: result.payload,
          );
          if (!mounted) return;
          if (draft != null) {
            // ignore: use_build_context_synchronously
            await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
              builder: (_) => SmartStockInView(
                prefilledName: draft.stockProductName.isNotEmpty
                    ? draft.stockProductName
                    : null,
                prefilledQuantity:
                    draft.quantity > 1 ? draft.quantity : null,
                prefilledCostPrice:
                    draft.unitPrice > 0 ? draft.unitPrice : null,
              ),
            ));
          }
        } else {
          // ignore: use_build_context_synchronously
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => const SmartStockInView()),
          );
        }
      case AiCommandIntent.viewFinanceToday:
      case AiCommandIntent.viewFinanceWeek:
      case AiCommandIntent.viewFinanceMonth:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const ExpenseView()),
        );
      case AiCommandIntent.findCustomer:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const CustomerManagementView()),
        );
      case AiCommandIntent.viewDebt:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const DebtView()),
        );
      case AiCommandIntent.viewPendingRepairs:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => OrderListView(role: widget.role),
          ),
        );
      case AiCommandIntent.stockCheck:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => InventoryView(role: widget.role),
          ),
        );
      case AiCommandIntent.attendanceIn:
      case AiCommandIntent.attendanceOut:
        // ignore: use_build_context_synchronously
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => const AttendanceView()),
        );
      case AiCommandIntent.unknown:
        NotificationService.showSnackBar(
          'Không nhận dạng được lệnh. Hãy chọn lệnh từ danh sách.',
          color: Colors.orange,
        );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: _open,
        child: Container(
          height: 40,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF6D28D9), width: 1.5),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF7C3AED),
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'AI',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 18, color: const Color(0xFF6D28D9).withValues(alpha: 0.3)),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: Text(
                    _hints[_hintIndex],
                    key: ValueKey(_hintIndex),
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const Icon(
                Icons.mic_rounded,
                color: Color(0xFF7C3AED),
                size: 18,
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
