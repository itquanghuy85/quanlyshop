import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/ai_service.dart';
import '../services/natural_order_parser_service.dart';
import '../theme/popup_theme.dart';
import 'app_popup.dart';

/// Result returned when user confirms the AI-parsed input.
class AiRepairSheetResult {
  final String customerName;
  final String customerPhone;
  final String device;
  final String issue;
  final int deposit;
  final bool fromAi;

  const AiRepairSheetResult({
    required this.customerName,
    required this.customerPhone,
    required this.device,
    required this.issue,
    required this.deposit,
    required this.fromAi,
  });

  bool get hasEnoughData => device.isNotEmpty || issue.isNotEmpty;
}

enum _SheetState { idle, recording, parsing, preview, error }

/// Professional natural-language input sheet for repair orders.
///
/// Flow:
///   type / speak → local parse (fast) → AI parse if needed → preview → apply
class AiRepairInputSheet extends StatefulWidget {
  const AiRepairInputSheet({super.key});

  /// Opens the sheet and returns [AiRepairSheetResult] on confirm, null on cancel.
  static Future<AiRepairSheetResult?> show(BuildContext context) {
    return showModalBottomSheet<AiRepairSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AiRepairInputSheet(),
    );
  }

  @override
  State<AiRepairInputSheet> createState() => _AiRepairInputSheetState();
}

class _AiRepairInputSheetState extends State<AiRepairInputSheet>
    with SingleTickerProviderStateMixin {
  // ── Controllers / state ──────────────────────────────────────────────────
  final _ctrl = TextEditingController();
  final _speech = SpeechToText();
  late final AnimationController _pulse;

  _SheetState _state = _SheetState.idle;
  bool _speechAvailable = false;
  String _errorMsg = '';
  AiRepairSheetResult? _result;

  // ── Colors ───────────────────────────────────────────────────────────────
  static const _kPurple = Color(0xFF7C3AED);
  static const _kPurpleLight = Color(0xFFF5F3FF);
  static const _kPurpleBorder = Color(0xFFDDD6FE);
  static const _kGreen = Color(0xFF059669);
  static const _kGreenLight = Color(0xFFF0FDF4);
  static const _kRed = Color(0xFFDC2626);
  static const _kRedLight = Color(0xFFFEF2F2);

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _speech.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => _stopRecording(),
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _state == _SheetState.recording) {
          _stopRecording();
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  // ── Voice input ──────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    if (_state == _SheetState.recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable) return;
    _ctrl.clear();
    setState(() {
      _state = _SheetState.recording;
      _result = null;
      _errorMsg = '';
    });
    _pulse.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() => _ctrl.text = result.recognizedWords);
        if (result.finalResult) _stopRecording();
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        localeId: 'vi-VN',
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _stopRecording() async {
    _pulse.stop();
    await _speech.stop();
    if (!mounted) return;
    setState(() => _state = _SheetState.idle);
    if (_ctrl.text.trim().isNotEmpty) await _parse();
  }

  // ── AI parsing ───────────────────────────────────────────────────────────

  Future<void> _parse() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _state = _SheetState.parsing;
      _result = null;
      _errorMsg = '';
    });

    // 1. Local parse — instant, no network
    final local = NaturalOrderParserService.parse(text);
    final lRepair = local.repair;
    final hasDevice = (lRepair?.model ?? '').isNotEmpty;
    final hasIssue = (lRepair?.issue ?? '').isNotEmpty;

    if (hasDevice && hasIssue) {
      if (!mounted) return;
      setState(() {
        _result = AiRepairSheetResult(
          customerName: lRepair?.customerName ?? '',
          customerPhone: lRepair?.phone ?? '',
          device: lRepair?.model ?? '',
          issue: lRepair?.issue ?? '',
          deposit: lRepair?.price ?? 0,
          fromAi: false,
        );
        _state = _SheetState.preview;
      });
      return;
    }

    // 2. Local insufficient → call AI
    final (aiResult, error) = await AiService.instance.tryParseRepairText(text);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _errorMsg = error;
        _state = _SheetState.error;
      });
      return;
    }

    if (aiResult == null || !aiResult.isRepairOrder) {
      setState(() {
        _errorMsg = 'AI không nhận diện được đơn sửa. Thử mô tả rõ hơn.';
        _state = _SheetState.error;
      });
      return;
    }

    // Merge: AI preferred, local as fallback
    setState(() {
      _result = AiRepairSheetResult(
        customerName: aiResult.customerName.isNotEmpty
            ? aiResult.customerName
            : (lRepair?.customerName ?? ''),
        customerPhone: aiResult.customerPhone.isNotEmpty
            ? aiResult.customerPhone
            : (lRepair?.phone ?? ''),
        device: aiResult.device.isNotEmpty
            ? aiResult.device
            : (lRepair?.model ?? ''),
        issue: aiResult.issue.isNotEmpty
            ? aiResult.issue
            : (lRepair?.issue ?? ''),
        deposit: aiResult.deposit > 0
            ? aiResult.deposit
            : (lRepair?.price ?? 0),
        fromAi: true,
      );
      _state = _SheetState.preview;
    });
  }

  void _retry() => setState(() {
    _state = _SheetState.idle;
    _errorMsg = '';
    _result = null;
  });

  void _apply() {
    if (_result != null && _result!.hasEnoughData) {
      Navigator.pop(context, _result);
    }
  }

  void _cancel() => Navigator.pop(context);

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final navBar = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb + navBar),
      child: Container(
        decoration: const BoxDecoration(
          color: PopupTheme.bgDark,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PopupTheme.radiusSheet),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PopupDragHandle(),
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(),
                    const SizedBox(height: 14),
                    _buildActionRow(),
                    const SizedBox(height: 14),
                    _buildStateBody(),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            _buildFooter(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _kPurple.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NHẬP NHANH ĐƠN SỬA',
                  style: TextStyle(
                    color: PopupTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Gõ hoặc nói — AI tự điền form',
                  style: TextStyle(
                    color: PopupTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField() {
    final isEditable =
        _state == _SheetState.idle || _state == _SheetState.error;
    return TextField(
      controller: _ctrl,
      maxLines: 3,
      autofocus: _state == _SheetState.idle,
      enabled: isEditable,
      style: const TextStyle(
        color: PopupTheme.textPrimary,
        fontSize: 14,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText:
            'Ví dụ: iphone 13 mất face id khách Hùng sdt 0901234567 đặt cọc 500',
        hintStyle: const TextStyle(color: PopupTheme.textMuted, fontSize: 12.5),
        filled: true,
        fillColor: isEditable ? PopupTheme.surfaceDark : PopupTheme.cardDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
          borderSide: const BorderSide(color: PopupTheme.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
          borderSide: const BorderSide(color: PopupTheme.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
          borderSide: const BorderSide(color: _kPurple, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PopupTheme.radiusField),
          borderSide: const BorderSide(color: PopupTheme.borderDark),
        ),
        suffixIcon: isEditable && _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  size: 16,
                  color: PopupTheme.textMuted,
                ),
                onPressed: () => setState(() {
                  _ctrl.clear();
                  _result = null;
                  _state = _SheetState.idle;
                }),
              )
            : null,
      ),
      onChanged: (_) {
        if (_state == _SheetState.preview || _state == _SheetState.error) {
          setState(() {
            _state = _SheetState.idle;
            _result = null;
          });
        }
      },
    );
  }

  Widget _buildActionRow() {
    final canAnalyze =
        _state == _SheetState.idle ||
        _state == _SheetState.error ||
        _state == _SheetState.preview;
    final isActive = _state == _SheetState.idle || _state == _SheetState.error;

    return Row(
      children: [
        // Mic button
        if (_speechAvailable) ...[
          GestureDetector(
            onTap: isActive ? _toggleMic : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _state == _SheetState.recording
                    ? const Color(0xFFFEE2E2)
                    : PopupTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _state == _SheetState.recording
                      ? _kRed
                      : PopupTheme.borderDark,
                ),
              ),
              child: _state == _SheetState.recording
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Icon(
                        Icons.mic_rounded,
                        size: 22,
                        color: Color.lerp(
                          _kRed,
                          Colors.red.shade300,
                          _pulse.value,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.mic_rounded,
                      size: 22,
                      color: isActive ? _kPurple : PopupTheme.textMuted,
                    ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Analyze button
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _state == _SheetState.parsing
                ? _buildParsingButton()
                : ElevatedButton.icon(
                    key: const ValueKey('analyze'),
                    onPressed: canAnalyze && _ctrl.text.trim().isNotEmpty
                        ? _parse
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: PopupTheme.cardDark,
                      disabledForegroundColor: PopupTheme.textMuted,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PopupTheme.radiusButton,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: const Text(
                      'Phân tích AI',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildParsingButton() {
    return Container(
      key: const ValueKey('parsing'),
      height: 48,
      decoration: BoxDecoration(
        color: _kPurpleLight,
        borderRadius: BorderRadius.circular(PopupTheme.radiusButton),
        border: Border.all(color: _kPurpleBorder),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _kPurple),
          ),
          SizedBox(width: 10),
          Text(
            'AI đang phân tích...',
            style: TextStyle(
              color: _kPurple,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: switch (_state) {
        _SheetState.recording => _buildRecordingCard(),
        _SheetState.preview => _buildPreviewCard(),
        _SheetState.error => _buildErrorCard(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildRecordingCard() {
    return Container(
      key: const ValueKey('recording'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kRedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Color.lerp(_kRed, Colors.red.shade300, _pulse.value),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _kRed.withValues(alpha: 0.4 + 0.3 * _pulse.value),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Đang nghe... Nói tự nhiên, dừng lại khi xong',
              style: TextStyle(
                color: _kRed,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Dừng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final r = _result!;
    final isAi = r.fromAi;
    final accent = isAi ? _kPurple : _kGreen;
    final bg = isAi ? _kPurpleLight : _kGreenLight;
    final borderC = isAi ? _kPurpleBorder : _kGreen.withValues(alpha: 0.3);

    return Container(
      key: const ValueKey('preview'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isAi ? Icons.auto_awesome_rounded : Icons.flash_on_rounded,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isAi ? 'AI phân tích' : 'Nhận diện nhanh',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _retry,
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: accent.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sửa lại',
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(height: 1, color: borderC),

          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                if (r.device.isNotEmpty)
                  _previewRow(
                    Icons.smartphone_rounded,
                    'Thiết bị',
                    r.device,
                    accent,
                  ),
                if (r.issue.isNotEmpty)
                  _previewRow(Icons.build_rounded, 'Lỗi', r.issue, accent),
                if (r.customerName.isNotEmpty)
                  _previewRow(
                    Icons.person_rounded,
                    'Khách',
                    r.customerName,
                    accent,
                  ),
                if (r.customerPhone.isNotEmpty)
                  _previewRow(
                    Icons.phone_rounded,
                    'SĐT',
                    r.customerPhone,
                    accent,
                  ),
                if (r.deposit > 0)
                  _previewRow(
                    Icons.payments_rounded,
                    'Đặt cọc',
                    _formatMoney(r.deposit),
                    accent,
                  ),
                if (!r.hasEnoughData)
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: Color(0xFFD97706),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Thiếu thông tin. Thêm tên thiết bị hoặc lỗi.',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewRow(IconData icon, String label, String value, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: const TextStyle(
                color: PopupTheme.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: PopupTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      key: const ValueKey('error'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kRedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMsg,
              style: const TextStyle(color: _kRed, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _retry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final canApply =
        _state == _SheetState.preview &&
        _result != null &&
        _result!.hasEnoughData;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancel,
              style: PopupTheme.secondaryButton(),
              child: const Text('HỦY'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: canApply ? _apply : null,
              style: PopupTheme.primaryButton(color: _kPurple),
              icon: const Icon(Icons.check_circle_rounded, size: 17),
              label: const Text(
                'ÁP DỤNG',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(int amount) {
    final s = amount.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buf.write('.');
      buf.write(s[i]);
      count++;
    }
    return '${buf.toString().split('').reversed.join()}đ';
  }
}
