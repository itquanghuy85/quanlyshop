import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/ai_universal_result.dart';
import '../services/ai_service.dart';
import '../services/natural_order_parser_service.dart';
import '../services/voice_correction_service.dart';
import '../theme/popup_theme.dart';
import 'app_popup.dart';

// ── Mode ──────────────────────────────────────────────────────────────────────

enum AiSheetMode { repair, sale, stock }

extension _AiSheetModeX on AiSheetMode {
  String get title => switch (this) {
        AiSheetMode.repair => 'NHẬP NHANH ĐƠN SỬA',
        AiSheetMode.sale => 'NHẬP NHANH ĐƠN BÁN',
        AiSheetMode.stock => 'NHẬP NHANH NHẬP KHO',
      };

  String get subtitle => switch (this) {
        AiSheetMode.repair => 'Gõ hoặc nói — AI tự điền form sửa chữa',
        AiSheetMode.sale => 'Gõ hoặc nói — AI tự điền form bán hàng',
        AiSheetMode.stock => 'Gõ hoặc nói — AI tự điền form nhập kho',
      };

  String get hintText => switch (this) {
        AiSheetMode.repair =>
          'VD: sửa iphone 13 mất face id khách Hùng 0901234567 thu 500k',
        AiSheetMode.sale =>
          'VD: bán samsung a55 imei 1234 khách Nam 0965444567 trả góp FE',
        AiSheetMode.stock =>
          'VD: nhập kho 5 iPhone 14 Pro giá vốn 18tr NCC Minh Đức',
      };

  String get voiceExampleSentence => switch (this) {
        AiSheetMode.repair =>
          '"Sửa iPhone 13 Pro Max, mất Face ID,\nkhách Hùng, số 0901234567, thu 500 nghìn"',
        AiSheetMode.sale =>
          '"Bán Samsung A55, IMEI 1234,\nkhách Nam, số 0965444567, trả góp FE"',
        AiSheetMode.stock =>
          '"Nhập kho 5 iPhone 14 Pro,\ngiá vốn 18 triệu, NCC Minh Đức"',
      };

  String get hintMode => switch (this) {
        AiSheetMode.repair => 'repair',
        AiSheetMode.sale => 'sale',
        AiSheetMode.stock => 'stock',
      };

  IconData get icon => switch (this) {
        AiSheetMode.repair => Icons.build_circle_rounded,
        AiSheetMode.sale => Icons.point_of_sale_rounded,
        AiSheetMode.stock => Icons.inventory_2_rounded,
      };

  Color get accent => switch (this) {
        AiSheetMode.repair => const Color(0xFF7C3AED), // purple
        AiSheetMode.sale => const Color(0xFF0369A1),   // blue
        AiSheetMode.stock => const Color(0xFF047857),  // green
      };
}

// ── States ────────────────────────────────────────────────────────────────────

enum _SheetState { idle, recording, parsing, preview, error }

// ── Widget ────────────────────────────────────────────────────────────────────

/// Universal AI-powered quick-entry bottom sheet.
///
/// Supports three modes via [AiSheetMode]: repair, sale, stock.
/// Flow: type/speak → local parse (instant) → AI parse if needed → preview → apply.
/// Returns [AiUniversalResult] on confirm, null on cancel.
class AiOrderInputSheet extends StatefulWidget {
  final AiSheetMode mode;

  /// When set, the text field is pre-populated and parsing is triggered automatically.
  final String? prefilledText;

  const AiOrderInputSheet({super.key, required this.mode, this.prefilledText});

  /// Opens the sheet and returns [AiUniversalResult] on confirm, null on cancel.
  static Future<AiUniversalResult?> show(
    BuildContext context, {
    required AiSheetMode mode,
    String? prefilledText,
  }) {
    return showModalBottomSheet<AiUniversalResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiOrderInputSheet(mode: mode, prefilledText: prefilledText),
    );
  }

  @override
  State<AiOrderInputSheet> createState() => _AiOrderInputSheetState();
}

class _AiOrderInputSheetState extends State<AiOrderInputSheet>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────────────────
  final _ctrl = TextEditingController();
  final _speech = SpeechToText();
  late final AnimationController _pulse;

  _SheetState _sheetState = _SheetState.idle;
  bool _speechAvailable = false;
  String _errorMsg = '';
  AiUniversalResult? _result;

  // Convenient alias
  AiSheetMode get _mode => widget.mode;

  // ── Derived colors ────────────────────────────────────────────────────────
  Color get _accent => _mode.accent;
  Color get _accentLight => _accent.withValues(alpha: 0.08);
  Color get _accentBorder => _accent.withValues(alpha: 0.25);

  static const _kRed = Color(0xFFDC2626);
  static const _kRedLight = Color(0xFFFEF2F2);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _initSpeech();
    if (widget.prefilledText != null && widget.prefilledText!.isNotEmpty) {
      _ctrl.text = widget.prefilledText!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _parse();
      });
    }
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
            _sheetState == _SheetState.recording) {
          _stopRecording();
        }
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    if (_sheetState == _SheetState.recording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable) return;
    _ctrl.clear();
    setState(() {
      _sheetState = _SheetState.recording;
      _result = null;
      _errorMsg = '';
    });
    _pulse.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        final corrected = VoiceCorrectionService.correct(result.recognizedWords);
        setState(() => _ctrl.text = corrected.corrected.isNotEmpty
            ? corrected.corrected
            : result.recognizedWords);
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
    setState(() => _sheetState = _SheetState.idle);
    if (_ctrl.text.trim().isNotEmpty) await _parse();
  }

  // ── Parse flow ────────────────────────────────────────────────────────────

  Future<void> _parse() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sheetState = _SheetState.parsing;
      _result = null;
      _errorMsg = '';
    });

    // 1. Local parse — instant, offline
    final local = NaturalOrderParserService.parse(text);
    final localResult = _localToUniversal(local);
    if (localResult != null && localResult.hasEnoughData) {
      if (!mounted) return;
      setState(() {
        _result = localResult;
        _sheetState = _SheetState.preview;
      });
      return;
    }

    // 2. AI parse — network, uses cache
    final (aiResult, error) = await AiService.instance.tryParseUniversal(
      text,
      hintMode: _mode.hintMode,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _errorMsg = error;
        _sheetState = _SheetState.error;
      });
      return;
    }

    if (aiResult == null || aiResult.isUnknown || !aiResult.hasEnoughData) {
      // Merge: if local had partial data, use it even without AI confirmation
      if (localResult != null && (localResult.device.isNotEmpty ||
          localResult.issue.isNotEmpty ||
          localResult.productHint.isNotEmpty ||
          localResult.stockProductName.isNotEmpty)) {
        setState(() {
          _result = localResult;
          _sheetState = _SheetState.preview;
        });
        return;
      }
      setState(() {
        _errorMsg = 'AI không nhận diện được. Hãy mô tả rõ hơn.';
        _sheetState = _SheetState.error;
      });
      return;
    }

    // Merge: AI preferred, local as fallback for missing fields
    setState(() {
      _result = _mergeResults(aiResult, localResult);
      _sheetState = _SheetState.preview;
    });
  }

  /// Convert local parser result to AiUniversalResult for this mode.
  AiUniversalResult? _localToUniversal(ParsedOrderCommand local) {
    switch (_mode) {
      case AiSheetMode.repair:
        if (local.intent != NaturalOrderIntent.repair || local.repair == null) {
          return null;
        }
        final r = local.repair!;
        return AiUniversalResult(
          intent: AiOrderIntent.repair,
          device: r.model,
          issue: r.issue,
          deposit: r.price,
          customerName: r.customerName ?? '',
          customerPhone: r.phone ?? '',
          fromAi: false,
        );

      case AiSheetMode.sale:
        if (local.intent != NaturalOrderIntent.sale || local.sale == null) {
          return null;
        }
        final s = local.sale!;
        return AiUniversalResult(
          intent: AiOrderIntent.sale,
          productHint: s.productHint,
          imei: s.imei ?? '',
          paymentMethod: s.paymentMethod ?? '',
          financePartner: s.financePartner ?? '',
          totalPrice: s.totalPrice ?? 0,
          customerName: s.customerName ?? '',
          customerPhone: s.phone ?? '',
          fromAi: false,
        );

      case AiSheetMode.stock:
        if (local.intent != NaturalOrderIntent.stock || local.stock == null) {
          return null;
        }
        final st = local.stock!;
        return AiUniversalResult(
          intent: AiOrderIntent.stockEntry,
          stockProductName: st.productName,
          quantity: st.quantity,
          unitPrice: st.unitPrice,
          fromAi: false,
        );
    }
  }

  /// Merge AI result with local fallback.
  AiUniversalResult _mergeResults(
      AiUniversalResult ai, AiUniversalResult? local) {
    if (local == null) return ai;
    switch (_mode) {
      case AiSheetMode.repair:
        return AiUniversalResult(
          intent: AiOrderIntent.repair,
          device: ai.device.isNotEmpty ? ai.device : local.device,
          issue: ai.issue.isNotEmpty ? ai.issue : local.issue,
          deposit: ai.deposit > 0 ? ai.deposit : local.deposit,
          customerName: ai.customerName.isNotEmpty
              ? ai.customerName
              : local.customerName,
          customerPhone: ai.customerPhone.isNotEmpty
              ? ai.customerPhone
              : local.customerPhone,
          fromAi: true,
        );
      case AiSheetMode.sale:
        return AiUniversalResult(
          intent: AiOrderIntent.sale,
          productHint: ai.productHint.isNotEmpty
              ? ai.productHint
              : local.productHint,
          imei: ai.imei.isNotEmpty ? ai.imei : local.imei,
          paymentMethod: ai.paymentMethod.isNotEmpty
              ? ai.paymentMethod
              : local.paymentMethod,
          financePartner: ai.financePartner.isNotEmpty
              ? ai.financePartner
              : local.financePartner,
          totalPrice: ai.totalPrice > 0 ? ai.totalPrice : local.totalPrice,
          customerName: ai.customerName.isNotEmpty
              ? ai.customerName
              : local.customerName,
          customerPhone: ai.customerPhone.isNotEmpty
              ? ai.customerPhone
              : local.customerPhone,
          fromAi: true,
        );
      case AiSheetMode.stock:
        return AiUniversalResult(
          intent: AiOrderIntent.stockEntry,
          stockProductName: ai.stockProductName.isNotEmpty
              ? ai.stockProductName
              : local.stockProductName,
          quantity: ai.quantity > 1 ? ai.quantity : local.quantity,
          unitPrice: ai.unitPrice > 0 ? ai.unitPrice : local.unitPrice,
          supplierName: ai.supplierName.isNotEmpty
              ? ai.supplierName
              : local.supplierName,
          fromAi: true,
        );
    }
  }

  void _retry() => setState(() {
        _sheetState = _SheetState.idle;
        _errorMsg = '';
        _result = null;
      });

  void _apply() {
    if (_result != null && _result!.hasEnoughData) {
      Navigator.pop(context, _result);
    }
  }

  void _cancel() => Navigator.pop(context);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: kb),
      child: Container(
        decoration: const BoxDecoration(
          color: PopupTheme.bgDark,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(PopupTheme.radiusSheet)),
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
                    const SizedBox(height: 12),
                    _buildActionRow(),
                    const SizedBox(height: 12),
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

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent, _accent.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(_mode.icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mode.title,
                  style: const TextStyle(
                    color: PopupTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  _mode.subtitle,
                  style: const TextStyle(
                      color: PopupTheme.textSecondary, fontSize: 11.5),
                ),
              ],
            ),
          ),
          // Cache indicator
          if (_result?.fromAi == false)
            Tooltip(
              message: 'Nhận diện nhanh (không tốn token)',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Text('LOCAL',
                    style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            )
          else if (_result?.fromAi == true)
            Tooltip(
              message: 'DeepSeek AI (có cache 24h)',
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentBorder),
                ),
                child: Text('AI',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Text field ────────────────────────────────────────────────────────────

  Widget _buildTextField() {
    final isEditable =
        _sheetState == _SheetState.idle || _sheetState == _SheetState.error;
    final isRecording = _sheetState == _SheetState.recording;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PopupTheme.radiusField),
        border: Border.all(
          color: isRecording
              ? _kRed
              : (isEditable ? PopupTheme.borderDark : _accent),
          width: isRecording ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _ctrl,
        maxLines: 3,
        autofocus: _sheetState == _SheetState.idle,
        enabled: isEditable,
        style: const TextStyle(
            color: PopupTheme.textPrimary, fontSize: 14, height: 1.5),
        decoration: InputDecoration(
          hintText: _mode.hintText,
          hintStyle:
              const TextStyle(color: PopupTheme.textMuted, fontSize: 12),
          filled: true,
          fillColor:
              isEditable ? PopupTheme.surfaceDark : PopupTheme.cardDark,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PopupTheme.radiusField),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PopupTheme.radiusField),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PopupTheme.radiusField),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PopupTheme.radiusField),
            borderSide: BorderSide.none,
          ),
          suffixIcon: isEditable && _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      size: 16, color: PopupTheme.textMuted),
                  onPressed: () => setState(() {
                    _ctrl.clear();
                    _result = null;
                    _sheetState = _SheetState.idle;
                  }),
                )
              : null,
        ),
        onChanged: (_) {
          if (_sheetState == _SheetState.preview ||
              _sheetState == _SheetState.error) {
            setState(() {
              _sheetState = _SheetState.idle;
              _result = null;
            });
          }
        },
      ),
    );
  }

  // ── Action row ────────────────────────────────────────────────────────────

  Widget _buildActionRow() {
    final canAnalyze = _sheetState == _SheetState.idle ||
        _sheetState == _SheetState.error ||
        _sheetState == _SheetState.preview;
    final isActive =
        _sheetState == _SheetState.idle || _sheetState == _SheetState.error;

    return Row(
      children: [
        if (_speechAvailable) ...[
          GestureDetector(
            onTap: isActive ? _toggleMic : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _sheetState == _SheetState.recording
                    ? _kRedLight
                    : PopupTheme.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sheetState == _SheetState.recording
                      ? _kRed
                      : PopupTheme.borderDark,
                ),
              ),
              child: _sheetState == _SheetState.recording
                  ? AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Icon(
                        Icons.mic_rounded,
                        size: 22,
                        color: Color.lerp(_kRed, Colors.red.shade300, _pulse.value),
                      ),
                    )
                  : Icon(
                      Icons.mic_rounded,
                      size: 22,
                      color: isActive ? _accent : PopupTheme.textMuted,
                    ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _sheetState == _SheetState.parsing
                ? _buildParsingButton()
                : ElevatedButton.icon(
                    key: const ValueKey('analyze'),
                    onPressed:
                        canAnalyze && _ctrl.text.trim().isNotEmpty ? _parse : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: PopupTheme.cardDark,
                      disabledForegroundColor: PopupTheme.textMuted,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              PopupTheme.radiusButton)),
                    ),
                    icon:
                        const Icon(Icons.auto_awesome_rounded, size: 17),
                    label: const Text('Phân tích AI',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
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
        color: _accentLight,
        borderRadius: BorderRadius.circular(PopupTheme.radiusButton),
        border: Border.all(color: _accentBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
          const SizedBox(width: 10),
          Text(
            'AI đang phân tích...',
            style: TextStyle(
                color: _accent,
                fontWeight: FontWeight.w600,
                fontSize: 13.5),
          ),
        ],
      ),
    );
  }

  // ── State body ────────────────────────────────────────────────────────────

  Widget _buildStateBody() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position:
              Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOut),
          ),
          child: child,
        ),
      ),
      child: switch (_sheetState) {
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: _kRedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
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
                        color: _kRed.withValues(
                            alpha: 0.4 + 0.3 * _pulse.value),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Đang nghe... nói tự nhiên, dừng lại khi xong',
                  style: TextStyle(
                      color: _kRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: _stopRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _kRed,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Dừng',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          // Example sentence hint
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kRed.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nói theo mẫu:',
                  style: TextStyle(
                    color: Color(0xFF9B1C1C),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _mode.voiceExampleSentence,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Preview card ──────────────────────────────────────────────────────────

  Widget _buildPreviewCard() {
    final r = _result!;
    return Container(
      key: const ValueKey('preview'),
      decoration: BoxDecoration(
        color: _accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  r.fromAi
                      ? Icons.auto_awesome_rounded
                      : Icons.flash_on_rounded,
                  size: 14,
                  color: _accent,
                ),
                const SizedBox(width: 6),
                Text(
                  r.fromAi ? 'AI phân tích' : 'Nhận diện nhanh',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _retry,
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded,
                          size: 13,
                          color: _accent.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text('Sửa lại',
                          style: TextStyle(
                              color: _accent.withValues(alpha: 0.7),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: _accentBorder),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                ..._buildPreviewRows(r),
                if (!r.hasEnoughData)
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 15, color: Color(0xFFD97706)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Thiếu thông tin quan trọng. Thêm chi tiết và phân tích lại.',
                          style: TextStyle(
                              color: Color(0xFFD97706), fontSize: 12.5),
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

  List<Widget> _buildPreviewRows(AiUniversalResult r) {
    final rows = <Widget>[];
    switch (_mode) {
      case AiSheetMode.repair:
        if (r.device.isNotEmpty) {
          rows.add(_row(Icons.smartphone_rounded, 'Thiết bị', r.device));
        }
        if (r.issue.isNotEmpty) {
          rows.add(_row(Icons.build_rounded, 'Lỗi', r.issue));
        }
        if (r.customerName.isNotEmpty) {
          rows.add(_row(Icons.person_rounded, 'Khách', r.customerName));
        }
        if (r.customerPhone.isNotEmpty) {
          rows.add(_row(Icons.phone_rounded, 'SĐT', r.customerPhone));
        }
        if (r.deposit > 0) {
          rows.add(_row(Icons.payments_rounded, 'Thu khách', _fmt(r.deposit)));
        }

      case AiSheetMode.sale:
        if (r.productHint.isNotEmpty) {
          rows.add(_row(Icons.shopping_bag_rounded, 'Sản phẩm', r.productHint));
        }
        if (r.imei.isNotEmpty) {
          rows.add(_row(Icons.qr_code_rounded, 'IMEI', r.imei));
        }
        if (r.customerName.isNotEmpty) {
          rows.add(_row(Icons.person_rounded, 'Khách', r.customerName));
        }
        if (r.customerPhone.isNotEmpty) {
          rows.add(_row(Icons.phone_rounded, 'SĐT', r.customerPhone));
        }
        if (r.paymentMethod.isNotEmpty) {
          rows.add(_row(Icons.credit_card_rounded, 'Thanh toán', r.paymentMethod));
        }
        if (r.financePartner.isNotEmpty) {
          rows.add(_row(Icons.account_balance_rounded, 'Đối tác', r.financePartner));
        }
        if (r.totalPrice > 0) {
          rows.add(_row(Icons.attach_money_rounded, 'Giá bán', _fmt(r.totalPrice)));
        }

      case AiSheetMode.stock:
        if (r.stockProductName.isNotEmpty) {
          rows.add(_row(Icons.inventory_2_rounded, 'Sản phẩm', r.stockProductName));
        }
        rows.add(_row(Icons.numbers_rounded, 'Số lượng', '${r.quantity} cái'));
        if (r.unitPrice > 0) {
          rows.add(_row(Icons.price_change_rounded, 'Giá vốn', _fmt(r.unitPrice)));
        }
        if (r.supplierName.isNotEmpty) {
          rows.add(_row(Icons.store_rounded, 'NCC', r.supplierName));
        }
    }
    return rows;
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: _accent),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: PopupTheme.textSecondary, fontSize: 12.5)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: PopupTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
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
            child: Text(_errorMsg,
                style: const TextStyle(color: _kRed, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _retry,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _kRed, borderRadius: BorderRadius.circular(6)),
              child: const Text('Thử lại',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final canApply = _sheetState == _SheetState.preview &&
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
              style: PopupTheme.primaryButton(color: _accent),
              icon: const Icon(Icons.check_circle_rounded, size: 17),
              label: const Text('ÁP DỤNG',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(int amount) {
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
