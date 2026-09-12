import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/dashboard_config_service.dart';

/// iPhone-style "jiggle mode" grid for the home shortcuts.
///
/// - Visible shortcuts wiggle; hold ~150ms then drag to reorder (the grid
///   reflows live while dragging, like the iOS home screen).
/// - Red "−" badge hides a shortcut; it drops into the "Đã ẩn" section below.
/// - Tapping a hidden shortcut (green "+") appends it to the visible grid.
///
/// [configs] is the FULL saved list and is mutated in place so the caller
/// can persist it as-is. [canShow] filters what the current user may see
/// (permissions / feature flags) — entries it rejects are kept in the list
/// untouched but never displayed.
class ShortcutEditGrid extends StatefulWidget {
  final List<ShortcutConfig> configs;
  final bool Function(ShortcutConfig config) canShow;
  final VoidCallback onChanged;
  final int columns;

  const ShortcutEditGrid({
    super.key,
    required this.configs,
    required this.canShow,
    required this.onChanged,
    required this.columns,
  });

  @override
  State<ShortcutEditGrid> createState() => _ShortcutEditGridState();
}

class _ShortcutEditGridState extends State<ShortcutEditGrid>
    with SingleTickerProviderStateMixin {
  static const double _gap = 8;

  late final AnimationController _wiggle;
  ShortcutConfig? _dragging;

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..repeat();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  List<ShortcutConfig> get _shown =>
      widget.configs.where(widget.canShow).toList();

  void _notify() {
    for (var i = 0; i < widget.configs.length; i++) {
      widget.configs[i].order = i;
    }
    widget.onChanged();
  }

  /// Move [dragged] to [target]'s slot in the FULL list. Moving forward lands
  /// after the target, moving backward lands before it — the same
  /// "push through" feel as iOS. Works on the full list so hidden / filtered
  /// entries keep their relative positions.
  void _moveOnto(ShortcutConfig dragged, ShortcutConfig target) {
    if (identical(dragged, target)) return;
    final from = widget.configs.indexOf(dragged);
    final to = widget.configs.indexOf(target);
    if (from < 0 || to < 0 || from == to) return;
    setState(() {
      widget.configs.removeAt(from);
      widget.configs.insert(to, dragged);
    });
    HapticFeedback.selectionClick();
    _notify();
  }

  void _hide(ShortcutConfig c) {
    HapticFeedback.lightImpact();
    setState(() => c.visible = false);
    _notify();
  }

  /// Re-show and append after the last visible entry so it lands at the end
  /// of the grid rather than somewhere in the middle.
  void _show(ShortcutConfig c) {
    HapticFeedback.lightImpact();
    setState(() {
      widget.configs.remove(c);
      final lastVisible = widget.configs.lastIndexWhere((x) => x.visible);
      widget.configs.insert(lastVisible + 1, c..visible = true);
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final visible = shown.where((c) => c.visible).toList();
    final hidden = shown.where((c) => !c.visible).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = widget.columns;
        final itemWidth = (constraints.maxWidth - (cols - 1) * _gap) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Chưa có lối tắt nào — bấm dấu + bên dưới để thêm',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ),
            Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (var i = 0; i < visible.length; i++)
                  _buildDraggable(visible[i], i, itemWidth),
              ],
            ),
            if (hidden.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ĐÃ ẨN (${hidden.length}) — bấm để thêm lại',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final c in hidden)
                    SizedBox(
                      width: itemWidth,
                      child: GestureDetector(
                        onTap: () => _show(c),
                        child: _Tile(config: c, mode: _TileMode.hidden),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDraggable(ShortcutConfig c, int index, double itemWidth) {
    final tile = _Tile(config: c, mode: _TileMode.visible, onHide: () => _hide(c));
    return SizedBox(
      width: itemWidth,
      child: LongPressDraggable<ShortcutConfig>(
        data: c,
        delay: const Duration(milliseconds: 150),
        hapticFeedbackOnStart: true,
        onDragStarted: () => setState(() => _dragging = c),
        onDragEnd: (_) => setState(() => _dragging = null),
        onDraggableCanceled: (_, __) => setState(() => _dragging = null),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: itemWidth,
            child: Transform.scale(
              scale: 1.08,
              child: _Tile(config: c, mode: _TileMode.lifted),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: tile),
        child: DragTarget<ShortcutConfig>(
          // Reorder as soon as the finger hovers over another tile so the
          // grid reflows live — no need to drop precisely.
          onWillAcceptWithDetails: (d) {
            _moveOnto(d.data, c);
            return true;
          },
          builder: (context, _, __) => _Wiggle(
            controller: _wiggle,
            phase: index,
            enabled: _dragging == null,
            child: tile,
          ),
        ),
      ),
    );
  }
}

/// Small alternating rotation, phase-shifted per tile so neighbours don't
/// swing in lockstep (that looks mechanical rather than "alive").
class _Wiggle extends StatelessWidget {
  final AnimationController controller;
  final int phase;
  final bool enabled;
  final Widget child;

  const _Wiggle({
    required this.controller,
    required this.phase,
    required this.enabled,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final t = controller.value * 2 * math.pi + phase * 1.3;
        return Transform.rotate(angle: math.sin(t) * 0.022, child: child);
      },
    );
  }
}

enum _TileMode { visible, hidden, lifted }

class _Tile extends StatelessWidget {
  final ShortcutConfig config;
  final _TileMode mode;
  final VoidCallback? onHide;

  const _Tile({required this.config, required this.mode, this.onHide});

  @override
  Widget build(BuildContext context) {
    final isHidden = mode == _TileMode.hidden;
    final color = isHidden ? Colors.grey.shade400 : config.color;
    final lifted = mode == _TileMode.lifted;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: lifted
                ? Color.alphaBlend(color.withOpacity(0.12), Colors.white)
                : color.withOpacity(isHidden ? 0.04 : 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHidden ? Colors.grey.shade200 : color.withOpacity(0.3),
            ),
            boxShadow: lifted
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(isHidden ? 0.08 : 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  config.icon,
                  color: color.withOpacity(isHidden ? 0.5 : 1),
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                config.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(isHidden ? 0.5 : 0.9),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // iOS-style corner badge: red "−" removes, green "+" restores.
        if (mode != _TileMode.lifted)
          Positioned(
            left: -4,
            top: -4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isHidden ? null : onHide,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isHidden ? Colors.green : Colors.red.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  isHidden ? Icons.add : Icons.remove,
                  color: Colors.white,
                  size: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
