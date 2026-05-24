import 'package:flutter/foundation.dart';

/// Singleton bridge allowing AiChatOverlay to switch HomeView tabs
/// and receive screen-context updates without direct widget references.
class AiNavBridge {
  AiNavBridge._();

  // Tab IDs matching HomeView's config
  static const tabHome = 'home';
  static const tabSales = 'sales';
  static const tabRepairs = 'repairs';
  static const tabInventory = 'inventory';
  static const tabFinance = 'finance';

  /// Notifier updated by HomeView whenever the active tab changes.
  /// Overlay listens to this to show context-aware placeholder text.
  static final screenContext = ValueNotifier<String>(tabHome);

  /// Registered by HomeView to switch bottom-nav tabs by ID.
  static Function(String tabId)? _onSwitchTab;

  static void registerTabSwitcher(Function(String tabId) fn) {
    _onSwitchTab = fn;
  }

  static void switchToTab(String tabId) {
    _onSwitchTab?.call(tabId);
  }
}
