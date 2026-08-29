import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';

/// Bottom padding for the content of a modal bottom sheet that tracks the
/// on-screen keyboard height by reading the platform [FlutterView] directly
/// (via [WidgetsBindingObserver.didChangeMetrics]) — NOT via
/// `MediaQuery.viewInsetsOf`.
///
/// Background: `showModalBottomSheet` installs a route-scoped `MediaQuery` that
/// rebuilds every frame while the keyboard animates. A `Padding` inside the
/// sheet that depends on that MediaQuery (`MediaQuery.viewInsetsOf(ctx)`) can be
/// torn down mid keyboard-animation during `Navigator.pop`, tripping the
/// `_dependents.isEmpty` assert (`InheritedElement.debugDeactivated`, seen at
/// framework.dart:6268). The historical workaround was to read `viewInsets` from
/// the *outer* widget/State context instead — that dodges the crash, but the
/// padding then never updates when the keyboard opens inside the sheet, so the
/// focused `TextField` (and the text being typed) ends up hidden behind the
/// keyboard and the user has to drag the sheet up to see it.
///
/// This widget sidesteps both problems: it holds **zero InheritedWidget
/// dependencies**, so it can never trip the assert, yet `didChangeMetrics`
/// keeps it fully reactive to the keyboard. Same technique as
/// `QuickActionBubble`.
///
/// Drop-in replacement for:
/// ```dart
/// Padding(
///   padding: EdgeInsets.only(
///     bottom: MediaQuery.viewInsetsOf(context).bottom + bottomSafe,
///   ),
///   child: <sheet content>,
/// )
/// ```
/// →
/// ```dart
/// KeyboardAwarePadding(
///   minBottom: 16,
///   child: <sheet content>,
/// )
/// ```
class KeyboardAwarePadding extends StatefulWidget {
  final Widget child;

  /// Minimum bottom inset when the keyboard is closed. The effective bottom
  /// padding is `max(keyboardHeight, [systemNavBarBottom,] minBottom)`, so the
  /// last row of buttons is never swallowed by the OEM gesture strip.
  final double minBottom;

  /// When true (default) the system nav-bar / gesture-strip height is folded
  /// into the bottom inset. Set to false if the child already wraps itself in a
  /// `SafeArea(top: false)` (otherwise the nav bar is counted twice while the
  /// keyboard is closed).
  final bool includeNavBar;

  /// Optional left / top / right padding (bottom is always keyboard-driven).
  final EdgeInsets padding;

  const KeyboardAwarePadding({
    super.key,
    required this.child,
    this.minBottom = 0,
    this.includeNavBar = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<KeyboardAwarePadding> createState() => _KeyboardAwarePaddingState();
}

class _KeyboardAwarePaddingState extends State<KeyboardAwarePadding>
    with WidgetsBindingObserver {
  FlutterView get _view =>
      WidgetsBinding.instance.platformDispatcher.views.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = _view.devicePixelRatio;
    final keyboard = _view.viewInsets.bottom / r;
    final navBar = widget.includeNavBar ? _view.padding.bottom / r : 0.0;
    final bottom = math.max(keyboard, math.max(navBar, widget.minBottom));
    return Padding(
      padding: EdgeInsets.only(
        left: widget.padding.left,
        top: widget.padding.top,
        right: widget.padding.right,
        bottom: bottom,
      ),
      child: widget.child,
    );
  }
}
