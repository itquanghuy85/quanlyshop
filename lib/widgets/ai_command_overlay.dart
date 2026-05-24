import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/ai_command_result.dart';
import '../services/ai_command_router.dart';
import '../services/voice_correction_service.dart';

// ── Command chip descriptor ────────────────────────────────────────────────────

class _Chip {
  final AiCommandIntent intent;
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.intent, this.icon, this.label, this.color);
}

const _kChips = [
  _Chip(AiCommandIntent.createRepair, Icons.build_circle_rounded, 'Tạo đơn sửa', Color(0xFF7C3AED)),
  _Chip(AiCommandIntent.createSale, Icons.point_of_sale_rounded, 'Tạo đơn bán', Color(0xFF0369A1)),
  _Chip(AiCommandIntent.stockEntry, Icons.inventory_2_rounded, 'Nhập kho', Color(0xFF047857)),
  _Chip(AiCommandIntent.viewFinanceToday, Icons.today_rounded, 'Tài chính hôm nay', Color(0xFFD97706)),
  _Chip(AiCommandIntent.viewFinanceWeek, Icons.date_range_rounded, 'Tài chính tuần', Color(0xFFD97706)),
  _Chip(AiCommandIntent.viewFinanceMonth, Icons.calendar_month_rounded, 'Tài chính tháng', Color(0xFFD97706)),
  _Chip(AiCommandIntent.findCustomer, Icons.person_search_rounded, 'Tìm khách', Color(0xFF0891B2)),
  _Chip(AiCommandIntent.viewDebt, Icons.account_balance_wallet_rounded, 'Công nợ', Color(0xFFDC2626)),
  _Chip(AiCommandIntent.viewPendingRepairs, Icons.pending_actions_rounded, 'Đơn đang sửa', Color(0xFFB45309)),
  _Chip(AiCommandIntent.stockCheck, Icons.checklist_rounded, 'Kiểm kho', Color(0xFF0F766E)),
  _Chip(AiCommandIntent.attendanceIn, Icons.login_rounded, 'Chấm công vào', Color(0xFF15803D)),
  _Chip(AiCommandIntent.attendanceOut, Icons.logout_rounded, 'Chấm công ra', Color(0xFFBE185D)),
];

// ── Overlay state ──────────────────────────────────────────────────────────────

enum _OverlayStatus { idle, listening, done }

// ── Widget ────────────────────────────────────────────────────────────────────

class AiCommandOverlay extends StatefulWidget {
  const AiCommandOverlay({super.key});

  static Future<AiCommandResult?> show(BuildContext context) {
    return showGeneralDialog<AiCommandResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => const AiCommandOverlay(),
    );
  }

  @override
  State<AiCommandOverlay> createState() => _AiCommandOverlayState();
}

class _AiCommandOverlayState extends State<AiCommandOverlay>
    with SingleTickerProviderStateMixin {
  final _speech = SpeechToText();
  final _textCtrl = TextEditingController();

  _OverlayStatus _status = _OverlayStatus.idle;
  bool _speechAvailable = false;
  String _transcript = '';
  List<String> _corrections = [];

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _textCtrl.dispose();
    if (_speech.isListening) _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final ok = await _speech.initialize();
    if (mounted) setState(() => _speechAvailable = ok);
  }

  Future<void> _toggleListen() async {
    if (_status == _OverlayStatus.listening) {
      await _speech.stop();
      _pulse.stop();
      setState(() => _status = _OverlayStatus.idle);
      return;
    }
    if (!_speechAvailable) return;
    setState(() {
      _status = _OverlayStatus.listening;
      _transcript = '';
    });
    _textCtrl.clear();
    _pulse.repeat(reverse: true);
    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        localeId: 'vi-VN',
        pauseFor: const Duration(seconds: 3),
        listenMode: ListenMode.dictation,
        partialResults: true,
      ),
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _transcript = result.recognizedWords);
    if (result.finalResult && result.recognizedWords.isNotEmpty) {
      _pulse.stop();
      final corrected = VoiceCorrectionService.correct(result.recognizedWords);
      _textCtrl.text = corrected.corrected;
      setState(() {
        _status = _OverlayStatus.done;
        _corrections = corrected.changes;
      });
    }
  }

  void _submit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final result = AiCommandRouterService.detect(trimmed);
    Navigator.of(context).pop(result);
  }

  void _onChipTap(_Chip chip) {
    Navigator.of(context).pop(
      AiCommandResult(intent: chip.intent, rawText: chip.label),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCenter()),
            _buildChips(),
            _buildTypeBar(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Quản Lý Shop AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            tooltip: 'Đóng',
          ),
        ],
      ),
    );
  }

  Widget _buildCenter() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatusText(),
        const SizedBox(height: 32),
        _buildMicButton(),
        const SizedBox(height: 12),
        if (_status == _OverlayStatus.done)
          TextButton.icon(
            onPressed: () {
              _textCtrl.clear();
              setState(() {
                _transcript = '';
                _corrections = [];
                _status = _OverlayStatus.idle;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white54),
            label: const Text('Nói lại', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          if (_corrections.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_fix_high_rounded, size: 13, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Đã tự sửa: ${_corrections.join(', ')}',
                      style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        _buildTranscript(),
      ],
    );
  }

  Widget _buildStatusText() {
    final text = switch (_status) {
      _OverlayStatus.idle => 'Nhấn mic rồi nói lệnh\nhoặc chọn lệnh bên dưới',
      _OverlayStatus.listening => 'Đang nghe — nói rõ ràng...',
      _OverlayStatus.done => 'Kiểm tra lại rồi nhấn ▶ để xác nhận',
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _status == _OverlayStatus.done
            ? const Color(0xFF86EFAC) // green hint
            : Colors.white70,
        fontSize: 14,
        height: 1.5,
      ),
    );
  }

  Widget _buildMicButton() {
    final isListening = _status == _OverlayStatus.listening;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        final scale = isListening ? (1.0 + _pulse.value * 0.12) : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: GestureDetector(
        onTap: _toggleListen,
        child: Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isListening
                ? const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: [
              BoxShadow(
                color: (isListening ? Colors.red : const Color(0xFF7C3AED))
                    .withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.stop_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildTranscript() {
    if (_transcript.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        _transcript,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _kChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _buildChipItem(_kChips[i]),
      ),
    );
  }

  Widget _buildChipItem(_Chip chip) {
    return GestureDetector(
      onTap: () => _onChipTap(chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: chip.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chip.color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon, color: chip.color, size: 14),
            const SizedBox(width: 5),
            Text(
              chip.label,
              style: TextStyle(
                color: chip.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Hoặc gõ lệnh tại đây...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                ),
              ),
              onSubmitted: _submit,
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(onTap: () => _submit(_textCtrl.text)),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}
