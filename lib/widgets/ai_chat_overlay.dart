import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/app_knowledge_base.dart';
import '../data/db_helper.dart';
import '../services/ai_chat_service.dart';
import '../services/ai_knowledge_service.dart';
import '../services/ai_nav_bridge.dart';
import '../services/ai_usage_logger.dart';
import '../services/connectivity_service.dart';
import '../services/user_service.dart';
import '../services/voice_correction_service.dart';
import '../theme/popup_theme.dart';
import '../views/feature_catalog_view.dart';
import '../views/repair_detail_view.dart';
import '../views/sale_detail_view.dart';
import 'ai_order_input_sheet.dart';

// ── Message model ──────────────────────────────────────────────────────────────

enum _Role { user, assistant }

class _Msg {
  final _Role role;
  final String text;
  final bool isLoading;
  final List<AiAction> actions;
  final List<AiIntentSuggestion> suggestions;
  _Msg(this.role, this.text, {
    this.isLoading = false,
    this.actions = const [],
    this.suggestions = const [],
  });
}

// ── Quick chip presets ─────────────────────────────────────────────────────────

/// Chip mặc định đặt NĂNG LỰC lên trước câu hỏi số liệu.
///
/// Trước đây 4 chip đều là truy vấn số liệu, còn ngay sau lời chào thì chip bị
/// thay bằng 3 câu mẫu "cách dùng tính năng" — nên người dùng không có đường
/// nào biết AI còn **tạo đơn / nhập kho / mở màn hình hộ** được.
const _kChipWhatCanYouDo = ('✨ AI làm được gì?', Icons.auto_awesome_rounded);

/// Nhãn chip cần quyền xem doanh thu — ẩn với nhân viên không có quyền.
const _kFinanceChipLabels = {
  'Doanh thu hôm nay',
  'Lợi nhuận hôm nay',
  'Công nợ khách hàng',
  'Ai nợ nhiều nhất',
};

const _kChipsHome = [
  ('Tạo đơn sửa', Icons.build_circle_rounded),
  ('Đơn đang chờ', Icons.pending_actions_rounded),
  ('Doanh thu hôm nay', Icons.trending_up_rounded),
  ('Tồn kho hiện tại', Icons.inventory_2_rounded),
  ('Công nợ khách hàng', Icons.account_balance_wallet_rounded),
];

/// Chip gợi ý theo tab đang mở — mỗi nhãn phải khớp một nhánh quick-answer.
const _kChipsByTab = <String, List<(String, IconData)>>{
  AiNavBridge.tabRepairs: [
    ('Tạo đơn sửa', Icons.build_circle_rounded),
    ('Đơn đang chờ', Icons.pending_actions_rounded),
    ('Sửa chữa hôm nay', Icons.today_rounded),
  ],
  AiNavBridge.tabSales: [
    ('Tạo đơn bán', Icons.point_of_sale_rounded),
    ('Bán hàng hôm nay', Icons.today_rounded),
    ('Đơn bán gần nhất', Icons.receipt_long_rounded),
  ],
  AiNavBridge.tabInventory: [
    ('Nhập kho mới', Icons.add_box_rounded),
    ('Tồn kho hiện tại', Icons.inventory_2_rounded),
    ('Kho linh kiện', Icons.memory_rounded),
  ],
  AiNavBridge.tabFinance: [
    ('Doanh thu hôm nay', Icons.trending_up_rounded),
    ('Lợi nhuận hôm nay', Icons.savings_rounded),
    ('Ai nợ nhiều nhất', Icons.account_balance_wallet_rounded),
  ],
};

// ── Widget ─────────────────────────────────────────────────────────────────────

/// Persistent FAB + slide-up AI chat panel.
///
/// Add once to the root [Stack] in HomeView. Manages its own open/closed state.
class AiChatOverlay extends StatefulWidget {
  const AiChatOverlay({super.key});

  @override
  State<AiChatOverlay> createState() => _AiChatOverlayState();
}

class _AiChatOverlayState extends State<AiChatOverlay>
    with TickerProviderStateMixin {
  // ── Visibility ────────────────────────────────────────────────────────────
  bool _open = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _anim;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  // ── Chat state ────────────────────────────────────────────────────────────
  final _messages = <_Msg>[];
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  AiChatStats? _stats;
  DateTime? _statsLoadedAt;          // TTL cache — reload only if >5 min old
  DateTime? _lastCloudCallAt;        // client-side rate limit for cloud AI
  static const _kStatsTtl = Duration(minutes: 5);
  static const _kCloudRateLimit = Duration(seconds: 4);
  // Tracks last resolved topic for "gần nhất" context continuity
  String? _lastIntent; // 'repair' | 'sale' | 'debt' | 'stock' | null

  // Context-aware follow-up chips shown after AI answers
  List<(String, IconData)> _contextChips = [];

  // Whether welcome message has been sent this session
  bool _welcomeSent = false;

  /// Lần đầu mở app trong ngày → chấm đỏ trên nút AI để mời xem bản tin sáng.
  /// Chỉ ĐỌC mốc ngày; việc ghi vẫn do [_sendWelcome] làm khi thực sự hiện tin.
  bool _briefingPending = false;

  // ── FAB drag position (null = default bottom-right on first build) ─────────
  Offset? _fabOffset;

  // ── Permission / connectivity ─────────────────────────────────────────────
  bool _canCloudAI = false;        // Manager+ only
  bool _canViewFinance = true;     // false for staff without allowViewRevenue
  bool _isOnline = true;           // driven by ConnectivityService
  String? _role;                   // owner/manager/technician/cashier — for KB scoping

  // ── Feedback (👍/👎 per message index) ────────────────────────────────────
  final Map<int, bool> _feedbackMap = {};

  // ── Search ────────────────────────────────────────────────────────────────
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  // ── Voice ─────────────────────────────────────────────────────────────────
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _recording = false;
  bool _micAutoSent = false; // prevents double-send when finalResult fires
  late final AnimationController _pulse;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const _kPurple = Color(0xFF4F46E5);        // indigo — less neon than violet
  static const _kPurpleLight = Color(0xFFEEF2FF);   // indigo-50
  static const _kBubbleUser = Color(0xFF1E293B);    // slate-800 (dark navy)
  static const _kBubbleAI = Color(0xFFF1F5F9);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeIn);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _initSpeech();
    _loadPermissions();
    _watchConnectivity();
    _loadHistory();
    _checkBriefingPending();
    AiNavBridge.askRequest.addListener(_onExternalAsk);
    AiNavBridge.screenContext.addListener(_onScreenContextChanged);
    // Stats loaded lazily on first open — not in initState to avoid wasted SQLite reads
  }

  /// Mở màn "Tất cả tính năng" — nhãn chip đặc biệt.
  static const _kSeeAllFeatures = '📚 Tất cả tính năng';

  /// Có màn khác (vd Tất cả tính năng) nhờ hỏi AI hộ một câu.
  void _onExternalAsk() {
    final q = AiNavBridge.askRequest.value;
    if (q == null || q.isEmpty) return;
    AiNavBridge.askRequest.value = null;
    if (!mounted) return;
    if (!_open) _toggle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _send(q);
    });
  }

  /// Tab đang mở đổi → **xoá** chip ngữ cảnh của câu trả lời cũ để thanh chip
  /// quay về bộ gợi ý của tab mới.
  ///
  /// Nếu chỉ `setState` khi `_contextChips` rỗng thì chip theo tab gần như
  /// không bao giờ hiện được: `_sendWelcome` set `_contextChips` ngay lúc mở
  /// bong bóng, và giá trị đó nằm lại cho tới câu trả lời có `followUpChips`
  /// tiếp theo.
  void _onScreenContextChanged() {
    if (!mounted) return;
    setState(() => _contextChips = []);
  }

  Future<void> _checkBriefingPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';
      final pending = (prefs.getString(_kLastOpenKey) ?? '') != todayStr;
      if (mounted && pending) setState(() => _briefingPending = true);
    } catch (_) {}
  }

  /// Chip mặc định: năng lực trước, rồi gợi ý theo tab, lọc theo quyền.
  List<(String, IconData)> _defaultChips() {
    final tab = AiNavBridge.screenContext.value;
    final chips = <(String, IconData)>[
      _kChipWhatCanYouDo,
      ...(_kChipsByTab[tab] ?? _kChipsHome),
    ];
    if (!_canViewFinance) {
      chips.removeWhere((c) => _kFinanceChipLabels.contains(c.$1));
      // Tab tài chính lọc xong có thể rỗng → quay về bộ chip chung.
      if (chips.length == 1) {
        chips.addAll(_kChipsHome
            .where((c) => !_kFinanceChipLabels.contains(c.$1)));
      }
    }
    chips.add((_kSeeAllFeatures, Icons.apps_rounded));
    return chips;
  }

  Future<void> _loadPermissions() async {
    final perms = await UserService.getCurrentUserPermissions();
    final role = await UserService.getCachedRole();
    if (mounted) {
      setState(() {
        _canCloudAI = perms['allowCloudAI'] as bool? ?? false;
        _canViewFinance = perms['allowViewRevenue'] as bool? ?? false;
        _role = role;
      });
    }
  }

  void _watchConnectivity() {
    _isOnline = ConnectivityService.instance.isOnline;
    // Poll once per second — lightweight, avoids stream subscription teardown
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final online = ConnectivityService.instance.isOnline;
      if (online != _isOnline) setState(() => _isOnline = online);
      return true;
    });
  }

  @override
  void dispose() {
    AiNavBridge.askRequest.removeListener(_onExternalAsk);
    AiNavBridge.screenContext.removeListener(_onScreenContextChanged);
    _anim.dispose();
    _pulse.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onError: (_) { if (mounted) setState(() => _recording = false); },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && _recording) {
            if (mounted) setState(() => _recording = false);
          }
        },
      );
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  // Re-request speech permission if not yet granted, then start listening.
  Future<void> _requestAndStartMic() async {
    bool ok = false;
    bool deviceUnsupported = false;
    try {
      ok = await _speech.initialize(
        onError: (_) { if (mounted) setState(() => _recording = false); },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && _recording) {
            if (mounted) setState(() => _recording = false);
          }
        },
      );
    } catch (e) {
      ok = false;
      deviceUnsupported = e.toString().contains('recognizerNotAvailable') ||
          e.toString().contains('not available');
    }
    if (!mounted) return;
    setState(() => _speechAvailable = ok);
    if (ok) {
      _toggleMic();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deviceUnsupported
                ? 'Thiết bị này không hỗ trợ nhận dạng giọng nói'
                : 'Vui lòng cấp quyền Microphone trong Cài đặt điện thoại',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _preloadStats({bool forceRefresh = false}) async {
    // Skip if cache is still fresh
    if (!forceRefresh &&
        _stats != null &&
        _statsLoadedAt != null &&
        DateTime.now().difference(_statsLoadedAt!) < _kStatsTtl) {
      return;
    }
    try {
      final s = await AiChatService.instance.getTodayStats();
      if (mounted) {
        setState(() {
          _stats = s;
          _statsLoadedAt = DateTime.now();
        });
      }
    } catch (_) {}
  }

  // ── History persistence ───────────────────────────────────────────────────

  static const _kHistoryKey = 'ai_chat_history';
  static const _kLastOpenKey = 'ai_last_open_date';

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kHistoryKey) ?? [];
      final msgs = raw.map((s) {
        final sep = s.indexOf('|');
        if (sep < 0) return null;
        final role = s.substring(0, sep) == 'user' ? _Role.user : _Role.assistant;
        return _Msg(role, s.substring(sep + 1));
      }).whereType<_Msg>().toList();
      if (mounted && msgs.isNotEmpty) setState(() => _messages.addAll(msgs));
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = _messages
          .where((m) => !m.isLoading && m.text.isNotEmpty)
          .toList()
          .reversed
          .take(20)
          .toList()
          .reversed
          .map((m) => '${m.role == _Role.user ? "user" : "assistant"}|${m.text}')
          .toList();
      await prefs.setStringList(_kHistoryKey, toSave);
    } catch (_) {}
  }

  // ── Open / close ──────────────────────────────────────────────────────────

  void _toggle() {
    if (_open) {
      _anim.reverse().then((_) => setState(() => _open = false));
    } else {
      setState(() => _open = true);
      _anim.forward();
      // Lazy-load stats on first open (or if cache expired), then send welcome once per session
      _preloadStats().then((_) {
        if (mounted && _open && !_welcomeSent) {
          _welcomeSent = true;
          _sendWelcome();
        }
      });
    }
  }

  Future<void> _sendWelcome() async {
    final stats = _stats;
    if (stats == null) {
      _addAI('Chào bạn! Tôi là AI Trợ Lý. Đang tải dữ liệu shop...');
      return;
    }

    // Check if this is the first open today for a richer daily briefing
    bool isFirstToday = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';
      isFirstToday = (prefs.getString(_kLastOpenKey) ?? '') != todayStr;
      if (isFirstToday) await prefs.setString(_kLastOpenKey, todayStr);
    } catch (_) {}

    if (!mounted) return;
    if (_briefingPending) setState(() => _briefingPending = false);

    if (isFirstToday && (stats.repairsPending > 0 || (_canViewFinance && stats.debtReceivable > 0))) {
      final buf = StringBuffer('Chào buổi mới! Điểm cần lưu ý hôm nay:\n');
      if (stats.repairsPending > 0) {
        // Nói "chưa giao" chứ KHÔNG nói "đang chờ xử lý": con số này gồm cả máy
        // đã sửa xong đang chờ khách lấy. Thẻ "CẦN XỬ LÝ" ở Trang chủ chỉ đếm
        // status 1–2, nói khác đi là hai nơi đá nhau.
        final parts = <String>[
          if (stats.repairsInProgress > 0)
            '${stats.repairsInProgress} đang xử lý',
          if (stats.repairsAwaitingPickup > 0)
            '${stats.repairsAwaitingPickup} xong chờ khách lấy',
        ];
        buf.writeln('• **${stats.repairsPending} đơn sửa** chưa giao'
            '${parts.isEmpty ? '' : ' (${parts.join(' · ')})'}');
      }
      if (stats.repairsOverdue > 0) {
        buf.writeln(
            '• ⚠️ Trong đó **${stats.repairsOverdue} đơn** tồn từ hôm trước');
      }
      if (_canViewFinance && stats.debtReceivable > 0) {
        buf.writeln('• Công nợ khách hàng: **${_fmtStats(stats.debtReceivable)}**');
      }
      if (_canViewFinance && stats.debtPayable > 0) {
        buf.writeln('• Nợ NCC phải trả: **${_fmtStats(stats.debtPayable)}**');
      }
      buf.write('\nBạn muốn biết thêm gì?');
      _addAI(buf.toString());
    } else if (_canViewFinance) {
      _addAI(
        'Chào bạn! Hôm nay bán được **${stats.salesToday} đơn**, '
        'doanh thu **${_fmtStats(stats.revenueToday)}**'
        '${stats.repairsPending > 0 ? ", còn **${stats.repairsPending} đơn sửa** chưa giao" : ""}. '
        'Bạn muốn biết thêm gì?',
      );
    } else {
      _addAI(
        'Chào bạn! Hôm nay có **${stats.salesToday} đơn bán**, '
        '**${stats.repairsToday} đơn sửa**'
        '${stats.repairsPending > 0 ? ", **${stats.repairsPending} đơn** chưa giao" : ""}. '
        'Bạn muốn biết thêm gì?',
      );
    }

    // Gợi ý khám phá: 3 câu hỏi mẫu xoay theo ngày + lối vào "Tất cả tính năng".
    try {
      final now = DateTime.now();
      final daySeed = DateTime(now.year, now.month, now.day)
          .difference(DateTime(now.year))
          .inDays;
      final samples = AppKnowledgeBase.sampleQuestionSpread(3, seed: daySeed);
      if (samples.isNotEmpty && mounted) {
        // `_buildMsgText` chỉ hiểu `**đậm**` — dấu `*` / `_` sẽ hiện ra thô.
        _addAI(
          'Mình **làm hộ** được chứ không chỉ trả lời: "Tạo đơn sửa iPhone 13 '
          'thay màn cho Minh", "Nhập kho mới 10 pin", "Mở đơn sửa gần nhất".\n\n'
          'Hoặc hỏi **cách dùng bất kỳ tính năng nào**:\n'
          '${samples.map((s) => '• "$s"').join('\n')}',
        );
        setState(() {
          _contextChips = [
            _kChipWhatCanYouDo,
            for (final s in samples) (s, Icons.help_outline_rounded),
            (_kSeeAllFeatures, Icons.apps_rounded),
          ];
        });
      }
    } catch (_) {}
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  void _addAI(String text, {bool isLoading = false}) {
    setState(() {
      _messages.add(_Msg(_Role.assistant, text, isLoading: isLoading));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? text]) async {
    final q = (text ?? _ctrl.text).trim();
    if (q.isEmpty || _sending) return;

    // Chip đặc biệt: mở màn "Tất cả tính năng" thay vì gửi câu hỏi.
    if (q == _kSeeAllFeatures || q == 'Tất cả tính năng') {
      _ctrl.clear();
      openFeatureCatalog(context, userRole: _role ?? '');
      return;
    }

    _ctrl.clear();
    setState(() {
      _sending = true;
      _messages.add(_Msg(_Role.user, q));
    });
    _scrollToBottom();

    // Ensure stats are loaded
    final stats = _stats ?? await AiChatService.instance.getTodayStats();
    if (mounted) setState(() => _stats = stats);

    // Fast local answer (pass lastIntent for context continuity)
    final quick = AiChatService.instance.quickAnswer(q, stats, lastIntent: _lastIntent, canViewFinance: _canViewFinance);

    // KB "thắng" quick-answer khi câu hỏi RÕ RÀNG là how-to và khớp rất mạnh —
    // tránh nhánh mơ hồ ("... thế nào?") trả lời số liệu thay vì hướng dẫn.
    final preferKb = AiKnowledgeService.instance.looksLikeHowTo(q) &&
        AiKnowledgeService.instance
            .retrieve(q, role: _role, minScore: 12)
            .entries
            .isNotEmpty;

    if (quick != null && !preferKb) {
      _updateLastIntent(quick.actions);
      AiUsageLogger.log(type: AiCallType.quickAnswer, query: q, answer: quick.text).ignore();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_Msg(_Role.assistant, quick.text, actions: quick.actions));
        if (quick.followUpChips.isNotEmpty) _contextChips = quick.followUpChips;
      });
      _scrollToBottom();
      _saveHistory().ignore();
      return;
    }

    // Ambiguous domain → show clarification chips instead of calling cloud
    final clarify = AiChatService.instance.detectAmbiguousIntent(q);
    if (clarify != null) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_Msg(
          _Role.assistant,
          clarify.prompt,
          suggestions: clarify.suggestions,
        ));
      });
      _scrollToBottom();
      return;
    }

    // Kiến thức tính năng (offline, không tốn lượt cloud): trả lời trực tiếp
    // các câu "làm thế nào / ở đâu / là gì" từ Knowledge Base của app.
    // Không khớp → null → chuyển tiếp lên cloud (cloud vẫn nhận KB làm context).
    final kbAnswer = AiKnowledgeService.instance.offlineAnswer(q, role: _role);
    if (kbAnswer != null) {
      AiUsageLogger.log(
        type: AiCallType.quickAnswer,
        query: q,
        answer: kbAnswer,
        matchedKb: AiKnowledgeService.instance.matchedIds(q, role: _role),
      ).ignore();
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_Msg(_Role.assistant, kbAnswer));
      });
      _scrollToBottom();
      _saveHistory().ignore();
      return;
    }

    // Connectivity gate — quick-answers still work offline (handled above)
    if (!_isOnline) {
      setState(() => _sending = false);
      _addAI('Không có kết nối internet. Chỉ hỗ trợ quick-answer khi mất mạng.');
      return;
    }

    // Permission gate — cloud AI is Manager+ only.
    // (Câu "cách dùng / khái niệm" đã được KB trả lời offline ở trên.)
    if (!_canCloudAI) {
      setState(() => _sending = false);
      _addAI('Câu này cần AI nâng cao (chỉ dành cho quản lý trở lên). Bạn có thể '
          'hỏi về cách dùng tính năng, hoặc số liệu như "đơn đang chờ", "tồn kho".');
      return;
    }

    // Cloud AI — client-side rate limit
    final now = DateTime.now();
    if (_lastCloudCallAt != null &&
        now.difference(_lastCloudCallAt!) < _kCloudRateLimit) {
      final wait = _kCloudRateLimit - now.difference(_lastCloudCallAt!);
      setState(() { _sending = false; });
      _addAI('Vui lòng chờ ${wait.inSeconds + 1} giây trước khi hỏi tiếp.');
      return;
    }
    _lastCloudCallAt = now;

    setState(() {
      _messages.add(_Msg(_Role.assistant, '', isLoading: true));
    });
    _scrollToBottom();

    // Send only last 8 messages (4 pairs) to reduce token cost
    final history = _messages
        .where((m) => !m.isLoading && m.text.isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed
        .map((m) => {'role': m.role == _Role.user ? 'user' : 'assistant', 'content': m.text})
        .toList();

    final (answer, error) =
        await AiChatService.instance.askAI(q, stats, history, role: _role);
    if (!mounted) return;

    if (answer != null) {
      AiUsageLogger.log(type: AiCallType.cloudAI, query: q, answer: answer).ignore();
    }

    setState(() {
      _sending = false;
      _messages.removeLast(); // remove loading bubble
      _messages.add(
        _Msg(_Role.assistant, answer ?? error ?? 'Mình chưa hiểu rõ. Bạn thử hỏi: "doanh thu hôm nay", "tồn kho", "đơn sửa đang chờ", "công nợ", "tạo đơn sửa"...'),
      );
    });
    _scrollToBottom();
    _saveHistory().ignore();
  }

  // ── Intent tracking ───────────────────────────────────────────────────────

  void _updateLastIntent(List<AiAction> actions) {
    if (actions.isEmpty) return;
    final type = actions.first.type;
    _lastIntent = switch (type) {
      AiActionType.openLatestRepair ||
      AiActionType.openRepairsTab ||
      AiActionType.createRepairFromChat => 'repair',
      AiActionType.openLatestSale ||
      AiActionType.openSalesTab ||
      AiActionType.createSaleFromChat => 'sale',
      AiActionType.viewDebts || AiActionType.viewDebtPayable => 'debt',
      AiActionType.viewStock || AiActionType.createStockFromChat => 'stock',
    };
  }

  // ── Action handler ────────────────────────────────────────────────────────

  Future<void> _handleAction(AiAction action) async {
    switch (action.type) {
      case AiActionType.openLatestRepair:
        final repair = await DBHelper().getLatestRepair();
        if (!mounted || repair == null) return;
        // Navigate first, then close overlay so context is still valid
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => RepairDetailView(repair: repair)),
        );
        _toggle();
      case AiActionType.openLatestSale:
        final sale = await DBHelper().getLatestSale();
        if (!mounted || sale == null) return;
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => SaleDetailView(sale: sale)),
        );
        _toggle();
      case AiActionType.viewDebts:
      case AiActionType.viewDebtPayable:
        AiNavBridge.switchToTab(AiNavBridge.tabFinance);
        _toggle();
      case AiActionType.viewStock:
        AiNavBridge.switchToTab(AiNavBridge.tabInventory);
        _toggle();
      case AiActionType.openSalesTab:
        AiNavBridge.switchToTab(AiNavBridge.tabSales);
        _toggle();
      case AiActionType.openRepairsTab:
        AiNavBridge.switchToTab(AiNavBridge.tabRepairs);
        _toggle();
      case AiActionType.createRepairFromChat:
        _toggle();
        if (mounted) {
          AiOrderInputSheet.show(
            context,
            mode: AiSheetMode.repair,
            prefilledText: action.payload,
          );
        }
      case AiActionType.createSaleFromChat:
        _toggle();
        if (mounted) {
          AiOrderInputSheet.show(
            context,
            mode: AiSheetMode.sale,
            prefilledText: action.payload,
          );
        }
      case AiActionType.createStockFromChat:
        _toggle();
        if (mounted) {
          AiOrderInputSheet.show(
            context,
            mode: AiSheetMode.stock,
            prefilledText: action.payload,
          );
        }
    }
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    if (_recording) {
      await _speech.stop();
      setState(() => _recording = false);
      // Only send if finalResult callback hasn't already sent
      if (!_micAutoSent && _ctrl.text.trim().isNotEmpty) _send();
      _micAutoSent = false;
      return;
    }
    if (!_speechAvailable) return;
    setState(() {
      _recording = true;
      _micAutoSent = false;
      _ctrl.clear();
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final corrected = VoiceCorrectionService.correct(result.recognizedWords);
        setState(() => _ctrl.text =
            corrected.corrected.isNotEmpty ? corrected.corrected : result.recognizedWords);
        // Guard against double-fire of finalResult (STT library quirk)
        if (result.finalResult && !_micAutoSent) {
          _speech.stop();
          setState(() => _recording = false);
          if (_ctrl.text.trim().isNotEmpty) {
            _micAutoSent = true;
            _send();
          }
        }
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        localeId: 'vi-VN',
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim background when open
        if (_open)
          GestureDetector(
            onTap: _toggle,
            child: FadeTransition(
              opacity: _fade,
              child: Container(color: Colors.black38),
            ),
          ),

        // Chat panel
        if (_open) _buildPanel(context),

        // Draggable FAB
        _buildDraggableFab(context),
      ],
    );
  }

  Widget _buildDraggableFab(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Initialise to bottom-right on first build
    _fabOffset ??= Offset(mq.size.width - 68, mq.size.height - 156);

    return Positioned(
      left: _fabOffset!.dx,
      top: _fabOffset!.dy,
      child: GestureDetector(
        onPanUpdate: _open
            ? null
            : (d) {
                final mq = MediaQuery.of(context);
                setState(() {
                  _fabOffset = Offset(
                    (_fabOffset!.dx + d.delta.dx).clamp(0, mq.size.width - 56),
                    (_fabOffset!.dy + d.delta.dy)
                        .clamp(0, mq.size.height - 100),
                  );
                });
              },
        child: _buildFab(),
      ),
    );
  }

  Widget _buildFab() {
    return AnimatedScale(
      scale: _open ? 0.85 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: _toggle,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            // Chấm đỏ: có bản tin đầu ngày chưa xem.
            if (_briefingPending && !_open)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final mq = MediaQuery.of(context);
    final panelH = mq.size.height * 0.82;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(_slide),
        child: Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          elevation: 12,
          shadowColor: Colors.black38,
          child: SizedBox(
            height: panelH,
            child: Column(
              children: [
                _buildPanelHeader(),
                _searchMode ? _buildSearchBar() : _buildChips(),
                Expanded(child: _buildMessageList()),
                if (!_isOnline) _buildOfflineBanner(),
                _buildInput(mq),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Trợ Lý',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Hỏi về doanh thu, tồn kho, công nợ...',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _searchMode ? Icons.search_off_rounded : Icons.search_rounded,
                  color: _searchMode ? Colors.white : Colors.white54,
                  size: 18,
                ),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: _searchMode ? 'Đóng tìm kiếm' : 'Tìm trong lịch sử',
                onPressed: () {
                  setState(() {
                    _searchMode = !_searchMode;
                    if (!_searchMode) {
                      _searchQuery = '';
                      _searchCtrl.clear();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white54, size: 18),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                tooltip: 'Làm mới dữ liệu',
                onPressed: () => _preloadStats(forceRefresh: true),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 20),
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: _toggle,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Tìm trong lịch sử hội thoại...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () => setState(() { _searchQuery = ''; _searchCtrl.clear(); }),
                  child: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPurple, width: 1.5),
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
      ),
    );
  }

  Widget _buildChips() {
    final chips = _contextChips.isNotEmpty ? _contextChips : _defaultChips();
    final isContext = _contextChips.isNotEmpty;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, icon) = chips[i];
          return GestureDetector(
            onTap: _sending ? null : () => _send(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isContext
                    ? const Color(0xFFF0FDF4) // green tint for context chips
                    : _kPurpleLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isContext
                      ? const Color(0xFF16A34A).withValues(alpha: 0.35)
                      : _kPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13,
                      color: isContext ? const Color(0xFF16A34A) : _kPurple),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      color: isContext ? const Color(0xFF15803D) : _kPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    // Build filtered index list (preserves original index for feedback map)
    final filtered = <(int, _Msg)>[];
    for (int i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (_searchQuery.isEmpty || m.text.toLowerCase().contains(_searchQuery)) {
        filtered.add((i, m));
      }
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _searchQuery.isEmpty
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.search_off_rounded,
              size: 40,
              color: const Color(0xFFD8C5FF),
            ),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isEmpty
                  ? 'Hỏi tôi về shop của bạn!'
                  : 'Không tìm thấy "$_searchQuery"',
              style: const TextStyle(color: PopupTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final (origIdx, msg) = filtered[i];
        return _buildBubble(msg, origIdx, highlight: _searchQuery);
      },
    );
  }

  Widget _buildBubble(_Msg msg, int index, {String highlight = ''}) {
    final isUser = msg.role == _Role.user;
    final hasActions = !isUser && msg.actions.isNotEmpty && !msg.isLoading;
    final hasSuggestions = !isUser && msg.suggestions.isNotEmpty && !msg.isLoading;
    final hasFeedback = !isUser && !msg.isLoading && msg.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? _kBubbleUser : _kBubbleAI,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: msg.isLoading
                      ? _buildTypingIndicator()
                      : _buildMsgText(msg.text, isUser, highlight: highlight),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),
          if (hasActions) _buildActionRow(msg.actions),
          if (hasSuggestions) _buildSuggestionChips(msg.suggestions),
          if (hasFeedback) _buildFeedbackRow(index, msg.text),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips(List<AiIntentSuggestion> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 36),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: suggestions.map((s) {
          return GestureDetector(
            onTap: _sending ? null : () => _send(s.query),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kPurple.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: _kPurple.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.icon, size: 13, color: _kPurple),
                  const SizedBox(width: 5),
                  Text(
                    s.label,
                    style: const TextStyle(
                      color: _kPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionRow(List<AiAction> actions) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 36),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: actions.map((a) {
          return GestureDetector(
            onTap: () => _handleAction(a),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(a.icon, size: 13, color: const Color(0xFF4F46E5)),
                  const SizedBox(width: 5),
                  Text(
                    a.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.3;
            final t = (_pulse.value + delay) % 1.0;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Color.lerp(
                      PopupTheme.textMuted, _kPurple, t.clamp(0.0, 1.0)),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMsgText(String text, bool isUser, {String highlight = ''}) {
    final baseColor = isUser ? Colors.white : PopupTheme.textPrimary;
    const baseSize = 13.5;
    const baseHeight = 1.45;

    // Build flat list of plain/bold segments from **markdown**
    final segments = <({String text, bool bold})>[];
    final boldRe = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final m in boldRe.allMatches(text)) {
      if (m.start > last) segments.add((text: text.substring(last, m.start), bold: false));
      segments.add((text: m.group(1)!, bold: true));
      last = m.end;
    }
    if (last < text.length) segments.add((text: text.substring(last), bold: false));

    // Apply search highlight within each segment
    final spans = <InlineSpan>[];
    for (final seg in segments) {
      final color = seg.bold ? (isUser ? Colors.white : _kPurple) : baseColor;
      final weight = seg.bold ? FontWeight.w700 : FontWeight.normal;

      if (highlight.isEmpty) {
        spans.add(TextSpan(
            text: seg.text,
            style: TextStyle(color: color, fontSize: baseSize, fontWeight: weight, height: baseHeight)));
        continue;
      }

      // Split segment by highlight match (case-insensitive)
      int pos = 0;
      final hlRe = RegExp(RegExp.escape(highlight), caseSensitive: false);
      for (final hm in hlRe.allMatches(seg.text)) {
        if (hm.start > pos) {
          spans.add(TextSpan(
              text: seg.text.substring(pos, hm.start),
              style: TextStyle(color: color, fontSize: baseSize, fontWeight: weight, height: baseHeight)));
        }
        spans.add(TextSpan(
            text: seg.text.substring(hm.start, hm.end),
            style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: baseSize,
                fontWeight: FontWeight.w700,
                height: baseHeight,
                backgroundColor: Color(0xFFFEF3C7))));
        pos = hm.end;
      }
      if (pos < seg.text.length) {
        spans.add(TextSpan(
            text: seg.text.substring(pos),
            style: TextStyle(color: color, fontSize: baseSize, fontWeight: weight, height: baseHeight)));
      }
    }
    return RichText(text: TextSpan(children: spans));
  }

  void _giveFeedback(int msgIndex, String aiAnswer, bool positive) {
    setState(() => _feedbackMap[msgIndex] = positive);
    String query = '';
    for (int i = msgIndex - 1; i >= 0; i--) {
      if (_messages[i].role == _Role.user) { query = _messages[i].text; break; }
    }
    AiUsageLogger.log(
      type: AiCallType.feedback,
      query: query.isEmpty ? 'N/A' : query,
      answer: aiAnswer,
      feedbackPositive: positive,
      matchedKb: query.isEmpty
          ? const []
          : AiKnowledgeService.instance.matchedIds(query, role: _role),
    ).ignore();
  }

  Widget _buildFeedbackRow(int index, String aiAnswer) {
    final given = _feedbackMap[index];
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 36),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _feedbackBtn(Icons.thumb_up_rounded, given == true,
              given != null ? null : () => _giveFeedback(index, aiAnswer, true)),
          const SizedBox(width: 6),
          _feedbackBtn(Icons.thumb_down_rounded, given == false,
              given != null ? null : () => _giveFeedback(index, aiAnswer, false)),
          if (given != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'Cảm ơn phản hồi!',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feedbackBtn(IconData icon, bool active, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: active ? _kPurpleLight : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? _kPurple.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Icon(icon, size: 14,
            color: active ? _kPurple : Colors.grey.shade400),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFEF3C7),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 15, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mất kết nối — chỉ hỗ trợ quick-answer offline',
              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(MediaQueryData mq) {
    return Container(
      // Panel neo `bottom: 0` của TOÀN màn hình nên đáy của nó nằm DƯỚI thanh
      // điều hướng hệ thống. Trước đây chỉ trừ `viewInsets` (bàn phím) ⇒ trên
      // máy có thanh 3 nút, cả hàng nhập bị thanh đó che, rất khó bấm.
      // `mq.padding.bottom` tự về 0 khi bàn phím mở (Flutter đã trừ viewInsets),
      // nên cộng cả hai không bị đệm thừa.
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + mq.viewInsets.bottom + mq.padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PopupTheme.borderDark)),
      ),
      child: Row(
        children: [
          // Mic — always visible; requests permission on first tap if needed
          GestureDetector(
            onTap: _sending
                ? null
                : (_speechAvailable ? _toggleMic : _requestAndStartMic),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _recording
                    ? const Color(0xFFFEF2F2)
                    : _speechAvailable
                        ? _kPurpleLight
                        : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _recording
                      ? const Color(0xFFDC2626)
                      : _speechAvailable
                          ? _kPurple.withValues(alpha: 0.3)
                          : const Color(0xFFCBD5E1),
                ),
              ),
              child: _recording
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Icon(
                        Icons.mic_rounded,
                        size: 20,
                        color: Color.lerp(
                            const Color(0xFFDC2626),
                            Colors.red.shade300,
                            _pulse.value),
                      ),
                    )
                  : Icon(
                      _speechAvailable ? Icons.mic_rounded : Icons.mic_off_rounded,
                      size: 20,
                      color: _speechAvailable ? _kPurple : const Color(0xFF94A3B8),
                    ),
            ),
          ),
          // Text field
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: AiNavBridge.screenContext,
              builder: (_, screen, __) {
                final hint = switch (screen) {
                  AiNavBridge.tabSales => 'Hỏi về đơn bán, doanh thu...',
                  AiNavBridge.tabRepairs => 'Hỏi về đơn sửa, tình trạng...',
                  AiNavBridge.tabInventory => 'Kiểm tra tồn kho, linh kiện...',
                  AiNavBridge.tabFinance => 'Hỏi về công nợ, tài chính...',
                  _ => 'Hỏi về doanh thu, tồn kho...',
                };
                return TextField(
                  controller: _ctrl,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                      color: PopupTheme.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                        color: PopupTheme.textMuted, fontSize: 13),
                    filled: true,
                    fillColor: PopupTheme.surfaceDark,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: PopupTheme.borderDark),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _kPurple, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          // Send
          GestureDetector(
            onTap: _sending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _sending ? PopupTheme.cardDark : _kPurple,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kPurple),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtStats(int amount) => AiChatService.fmt(amount);
}
