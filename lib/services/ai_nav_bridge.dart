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

  /// Yêu cầu mở bong bóng AI và hỏi sẵn một câu (vd từ màn "Tất cả tính năng").
  /// AiChatOverlay lắng nghe; xử lý xong tự đặt lại `null`.
  static final askRequest = ValueNotifier<String?>(null);

  /// Gọi từ bất kỳ đâu để nhờ AI trả lời [question]. Nên `popUntil(isFirst)`
  /// trước để đảm bảo Home (nơi có overlay) đang hiển thị.
  static void ask(String question) {
    final q = question.trim();
    if (q.isEmpty) return;
    askRequest.value = q;
  }

  /// Registered by HomeView to switch bottom-nav tabs by ID.
  static Function(String tabId)? _onSwitchTab;

  static void registerTabSwitcher(Function(String tabId) fn) {
    _onSwitchTab = fn;
  }

  static void switchToTab(String tabId) {
    _onSwitchTab?.call(tabId);
  }
}
