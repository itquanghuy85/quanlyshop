import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/ai_chat_service.dart';
import '../services/voice_correction_service.dart';
import '../theme/popup_theme.dart';

// ── Message model ──────────────────────────────────────────────────────────────

enum _Role { user, assistant }

class _Msg {
  final _Role role;
  final String text;
  final bool isLoading;
  _Msg(this.role, this.text, {this.isLoading = false});
}

// ── Quick chip presets ─────────────────────────────────────────────────────────

const _kChips = [
  ('Doanh thu hôm nay', Icons.trending_up_rounded),
  ('Tồn kho hiện tại', Icons.inventory_2_rounded),
  ('Công nợ khách hàng', Icons.account_balance_wallet_rounded),
  ('Đơn sửa đang chờ', Icons.build_circle_rounded),
];

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
    with SingleTickerProviderStateMixin {
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

  // ── Voice ─────────────────────────────────────────────────────────────────
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _recording = false;
  late final AnimationController _pulse;

  // ── Colors ────────────────────────────────────────────────────────────────
  static const _kPurple = Color(0xFF7C3AED);
  static const _kPurpleLight = Color(0xFFF5F3FF);
  static const _kBubbleUser = Color(0xFF7C3AED);
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
    _preloadStats();
  }

  @override
  void dispose() {
    _anim.dispose();
    _pulse.dispose();
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize(
      onError: (_) => setState(() => _recording = false),
      onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && _recording) {
          setState(() => _recording = false);
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _preloadStats() async {
    try {
      final s = await AiChatService.instance.getTodayStats();
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  // ── Open / close ──────────────────────────────────────────────────────────

  void _toggle() {
    if (_open) {
      _anim.reverse().then((_) => setState(() => _open = false));
    } else {
      setState(() => _open = true);
      _anim.forward();
      if (_messages.isEmpty) _sendWelcome();
    }
  }

  void _sendWelcome() {
    final stats = _stats;
    if (stats == null) {
      _addAI(
        'Chào bạn! Tôi là AI Trợ Lý. Đang tải dữ liệu shop...',
      );
      return;
    }
    _addAI(
      'Chào bạn! Hôm nay shop bán được **${stats.salesToday} đơn**, '
      'doanh thu **${_fmtStats(stats.revenueToday)}**. '
      'Bạn muốn biết thêm gì?',
    );
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
    _ctrl.clear();
    setState(() {
      _sending = true;
      _messages.add(_Msg(_Role.user, q));
    });
    _scrollToBottom();

    // Ensure stats are loaded
    final stats = _stats ?? await AiChatService.instance.getTodayStats();
    if (mounted) setState(() => _stats = stats);

    // Fast local answer
    final quick = AiChatService.instance.quickAnswer(q, stats);
    if (quick != null) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _sending = false;
        _messages.add(_Msg(_Role.assistant, quick));
      });
      _scrollToBottom();
      return;
    }

    // Cloud AI answer
    setState(() {
      _messages.add(_Msg(_Role.assistant, '', isLoading: true));
    });
    _scrollToBottom();

    final history = _messages
        .where((m) => !m.isLoading)
        .take(20)
        .map((m) => {'role': m.role == _Role.user ? 'user' : 'assistant', 'content': m.text})
        .toList();

    final (answer, error) = await AiChatService.instance.askAI(q, stats, history);
    if (!mounted) return;

    setState(() {
      _sending = false;
      _messages.removeLast(); // remove loading bubble
      _messages.add(
        _Msg(_Role.assistant, answer ?? error ?? 'Lỗi không xác định.'),
      );
    });
    _scrollToBottom();
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    if (_recording) {
      await _speech.stop();
      setState(() => _recording = false);
      if (_ctrl.text.trim().isNotEmpty) _send();
      return;
    }
    if (!_speechAvailable) return;
    setState(() {
      _recording = true;
      _ctrl.clear();
    });
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final corrected = VoiceCorrectionService.correct(result.recognizedWords);
        setState(() => _ctrl.text =
            corrected.corrected.isNotEmpty ? corrected.corrected : result.recognizedWords);
        if (result.finalResult) {
          _speech.stop();
          setState(() => _recording = false);
          if (_ctrl.text.trim().isNotEmpty) _send();
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

        // FAB
        Positioned(
          right: 16,
          bottom: 80, // above bottom nav
          child: _buildFab(),
        ),
      ],
    );
  }

  Widget _buildFab() {
    return AnimatedScale(
      scale: _open ? 0.85 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _kPurple.withValues(alpha: 0.4),
                blurRadius: 14,
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
        child: Container(
          height: panelH,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildPanelHeader(),
              _buildChips(),
              Expanded(child: _buildMessageList()),
              _buildInput(mq),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Trợ Lý Shop',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Hỏi về doanh thu, tồn kho, công nợ...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 20),
                tooltip: 'Làm mới dữ liệu',
                onPressed: () async {
                  setState(() => _stats = null);
                  await _preloadStats();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: _toggle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        itemCount: _kChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, icon) = _kChips[i];
          return GestureDetector(
            onTap: _sending ? null : () => _send(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kPurpleLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _kPurple.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: _kPurple),
                  const SizedBox(width: 5),
                  Text(
                    label,
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
        },
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 40, color: Color(0xFFD8C5FF)),
            SizedBox(height: 10),
            Text(
              'Hỏi tôi về shop của bạn!',
              style: TextStyle(color: PopupTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_Msg msg) {
    final isUser = msg.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
                  colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
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
                  : _buildMsgText(msg.text, isUser),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
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

  Widget _buildMsgText(String text, bool isUser) {
    // Simple bold markdown: **text**
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.*?)\*\*');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
            text: text.substring(last, m.start),
            style: TextStyle(
                color: isUser ? Colors.white : PopupTheme.textPrimary,
                fontSize: 13.5,
                height: 1.45)));
      }
      spans.add(TextSpan(
          text: m.group(1),
          style: TextStyle(
              color: isUser ? Colors.white : _kPurple,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.45)));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
          text: text.substring(last),
          style: TextStyle(
              color: isUser ? Colors.white : PopupTheme.textPrimary,
              fontSize: 13.5,
              height: 1.45)));
    }
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildInput(MediaQueryData mq) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + mq.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: PopupTheme.borderDark)),
      ),
      child: Row(
        children: [
          // Mic
          if (_speechAvailable)
            GestureDetector(
              onTap: _sending ? null : _toggleMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _recording
                      ? const Color(0xFFFEF2F2)
                      : _kPurpleLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _recording
                        ? const Color(0xFFDC2626)
                        : _kPurple.withValues(alpha: 0.3),
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
                    : const Icon(Icons.mic_rounded, size: 20, color: _kPurple),
              ),
            ),
          // Text field
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              style: const TextStyle(
                  color: PopupTheme.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Hỏi về doanh thu, tồn kho...',
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
                  borderSide: const BorderSide(color: PopupTheme.borderDark),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: _kPurple, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _send(),
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

  static String _fmtStats(int amount) {
    if (amount == 0) return '0đ';
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}tr';
    }
    final raw = amount.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = raw.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(raw[i]);
      count++;
    }
    return '${buf.toString().split('').reversed.join()}đ';
  }
}
