import 'dart:ui' show FlutterView;
import 'package:flutter/material.dart';
import 'quick_action_controller.dart';
import 'quick_action_sheet.dart';

const double _kBubbleSize = 52.0;
const double _kEdgePeek = 8.0;
const double _kBottomNavHeight = 56.0;

/// Global draggable quick-action bubble.
///
/// Uses [WidgetsBindingObserver.didChangeMetrics] to read screen/keyboard
/// dimensions directly from the platform [FlutterView] — zero InheritedWidget
/// dependencies, so it never triggers the _dependents.isEmpty assertion that
/// fires when modal routes install their own MediaQuery scope.
class QuickActionBubble extends StatefulWidget {
  final QuickActionController controller;
  const QuickActionBubble({super.key, required this.controller});

  @override
  State<QuickActionBubble> createState() => _QuickActionBubbleState();
}

class _QuickActionBubbleState extends State<QuickActionBubble>
    with WidgetsBindingObserver {
  bool _isDragging = false;
  double? _dragCX;
  double? _dragCY;

  QuickActionController get _ctrl => widget.controller;

  // ── Platform metrics (no InheritedWidget) ─────────────────────────────────

  FlutterView get _view =>
      WidgetsBinding.instance.platformDispatcher.views.first;

  double get _pixelRatio => _view.devicePixelRatio;

  Size get _screenSize {
    final s = _view.physicalSize;
    final r = _pixelRatio;
    return Size(s.width / r, s.height / r);
  }

  EdgeInsets get _windowPadding {
    final p = _view.padding;
    final r = _pixelRatio;
    return EdgeInsets.fromLTRB(
        p.left / r, p.top / r, p.right / r, p.bottom / r);
  }

  double get _keyboardHeight => _view.viewInsets.bottom / _pixelRatio;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_rebuild);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_rebuild);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenSize = _screenSize;
    final screenW = screenSize.width;
    final screenH = screenSize.height;
    final padding = _windowPadding;
    final topPad = padding.top;
    final sysBotPad = padding.bottom;
    final keyboardH = _keyboardHeight;

    final isWide = screenW > 720;
    final bottomClear = sysBotPad + (isWide ? 0.0 : _kBottomNavHeight);
    final availH = screenH - topPad - bottomClear;

    if (!_ctrl.isLoaded || availH <= 0) return const SizedBox.shrink();

    // ── Bubble position ────────────────────────────────────────────────────
    final double bubbleLeft, bubbleTop;

    if (_isDragging && _dragCX != null && _dragCY != null) {
      bubbleLeft =
          (_dragCX! - _kBubbleSize / 2).clamp(0.0, screenW - _kBubbleSize);
      bubbleTop = (_dragCY! - _kBubbleSize / 2)
          .clamp(topPad, screenH - bottomClear - _kBubbleSize);
    } else {
      final isRight = _ctrl.side >= 0.5;
      bubbleLeft = isRight
          ? screenW - _kBubbleSize + _kEdgePeek
          : -_kEdgePeek;
      bubbleTop = (topPad + _ctrl.yFraction * availH)
          .clamp(topPad, screenH - bottomClear - _kBubbleSize);
    }

    // ── Sheet position ─────────────────────────────────────────────────────
    final isRight = (_isDragging && _dragCX != null)
        ? _dragCX! > screenW / 2
        : _ctrl.side >= 0.5;

    const sheetWidth = 204.0;
    const sheetGap = 10.0;
    double sheetLeft = isRight
        ? bubbleLeft - sheetWidth - sheetGap
        : bubbleLeft + _kBubbleSize + sheetGap;
    double sheetTop = bubbleTop - 40.0;
    sheetLeft = sheetLeft.clamp(8.0, screenW - sheetWidth - 8.0);
    sheetTop = sheetTop.clamp(topPad + 8.0, screenH - bottomClear - 280.0);

    // ── Keyboard fade ──────────────────────────────────────────────────────
    final visible = keyboardH < 80.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: visible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Stack(
          children: [
            // Scrim
            if (_ctrl.isExpanded)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _ctrl.close,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.28),
                  ),
                ),
              ),

            // Action sheet
            if (_ctrl.isExpanded)
              Positioned(
                left: sheetLeft,
                top: sheetTop,
                child: QuickActionSheet(
                  controller: _ctrl,
                  onClose: _ctrl.close,
                ),
              ),

            // Draggable bubble
            Positioned(
              left: bubbleLeft,
              top: bubbleTop,
              child: GestureDetector(
                onTap: () {
                  if (!_isDragging) _ctrl.toggle();
                },
                onPanStart: (details) {
                  if (_ctrl.isExpanded) _ctrl.close();
                  setState(() {
                    _isDragging = true;
                    _dragCX = bubbleLeft + _kBubbleSize / 2;
                    _dragCY = bubbleTop + _kBubbleSize / 2;
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _dragCX = (_dragCX! + details.delta.dx)
                        .clamp(_kBubbleSize / 2, screenW - _kBubbleSize / 2);
                    _dragCY = (_dragCY! + details.delta.dy).clamp(
                      topPad + _kBubbleSize / 2,
                      screenH - bottomClear - _kBubbleSize / 2,
                    );
                  });
                },
                onPanEnd: (_) {
                  _snapToEdge(screenW, screenH, topPad, bottomClear, availH);
                },
                child: AnimatedScale(
                  scale: _ctrl.isExpanded ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutBack,
                  child: _BubbleBody(isExpanded: _ctrl.isExpanded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snapToEdge(
    double screenW,
    double screenH,
    double topPad,
    double bottomClear,
    double availH,
  ) {
    if (_dragCX == null || _dragCY == null) {
      if (mounted) setState(() => _isDragging = false);
      return;
    }

    final newSide = _dragCX! > screenW / 2 ? 1.0 : 0.0;
    final rawTop = _dragCY! - _kBubbleSize / 2;
    final clampedTop =
        rawTop.clamp(topPad, screenH - bottomClear - _kBubbleSize);
    final newYFraction =
        availH > 0 ? ((clampedTop - topPad) / availH).clamp(0.05, 0.93) : 0.45;

    setState(() {
      _isDragging = false;
      _dragCX = null;
      _dragCY = null;
    });

    _ctrl.updatePosition(newSide, newYFraction);
  }
}

// ── Bubble body ────────────────────────────────────────────────────────────

class _BubbleBody extends StatelessWidget {
  final bool isExpanded;
  const _BubbleBody({required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final color =
        isExpanded ? const Color(0xFF5C6BC0) : const Color(0xFF00ACC1);

    return Container(
      width: _kBubbleSize,
      height: _kBubbleSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isExpanded
              ? [const Color(0xFF7986CB), const Color(0xFF3949AB)]
              : [const Color(0xFF26C6DA), const Color(0xFF00838F)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween(begin: 0.15, end: 0.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          isExpanded ? Icons.close_rounded : Icons.bolt_rounded,
          key: ValueKey(isExpanded),
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
