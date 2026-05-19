import 'package:flutter/material.dart';

/// Light Premium Business design tokens — inspired by KiotViet, MISA, Zalo.
/// White backgrounds, clean borders, subtle shadows, blue accent.
/// All dialog/sheet/modal components share these constants for pixel-perfect consistency.
abstract class PopupTheme {
  PopupTheme._();

  // ── BACKGROUNDS ─────────────────────────────────────────────────────────────
  static const Color bgDark      = Color(0xFFFFFFFF); // dialog / sheet background
  static const Color surfaceDark = Color(0xFFF8FAFC); // field / card fill
  static const Color cardDark    = Color(0xFFF1F5F9); // locked / disabled field fill
  static const Color borderDark  = Color(0xFFE2E8F0); // subtle border

  // ── TEXT ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1E293B); // near-black
  static const Color textSecondary = Color(0xFF64748B); // medium gray
  static const Color textMuted     = Color(0xFF94A3B8); // light gray

  // ── BRAND COLORS ────────────────────────────────────────────────────────────
  static const Color blue   = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
  static const Color green  = Color(0xFF059669);
  static const Color yellow = Color(0xFFD97706);
  static const Color red    = Color(0xFFDC2626);
  static const Color teal   = Color(0xFF0891B2);
  static const Color orange = Color(0xFFEA580C);

  // ── GRADIENTS (vivid header banners — contrast on white content) ─────────
  static const LinearGradient headerEdit = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerDetail = LinearGradient(
    colors: [Color(0xFF334155), Color(0xFF475569)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerGreen = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerRed = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient headerOrange = LinearGradient(
    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── RADIUS ──────────────────────────────────────────────────────────────────
  static const double radiusSheet  = 20.0;
  static const double radiusDialog = 14.0;
  static const double radiusCard   = 10.0;
  static const double radiusButton = 8.0;
  static const double radiusField  = 8.0;
  static const double radiusBadge  = 16.0;

  // ── SPACING ─────────────────────────────────────────────────────────────────
  static const double pagePadding  = 16.0;
  static const double sectionGap   = 12.0;
  static const double itemGap      = 8.0;
  static const double buttonHeight = 40.0;
  static const double fieldHeight  = 38.0;

  // ── SHADOWS (light & subtle — KiotViet style) ────────────────────────────
  static List<BoxShadow> get shadowMedium => const [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 6,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowCard => const [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  // ── FIELD DECORATION ────────────────────────────────────────────────────────
  static InputDecoration darkField({
    required String label,
    IconData? prefixIcon,
    String? hint,
    Widget? suffix,
    bool isLocked = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isLocked ? textMuted : textSecondary,
        fontSize: 12,
      ),
      hintStyle: const TextStyle(color: textMuted, fontSize: 12),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, size: 16, color: isLocked ? textMuted : textSecondary)
          : null,
      suffix: suffix,
      filled: true,
      fillColor: isLocked ? cardDark : surfaceDark,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusField),
        borderSide: BorderSide(color: borderDark.withValues(alpha: 0.6)),
      ),
    );
  }

  // ── BUTTON STYLES ───────────────────────────────────────────────────────────
  static ButtonStyle primaryButton({Color color = blue}) => ElevatedButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    ),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );

  static ButtonStyle secondaryButton() => OutlinedButton.styleFrom(
    foregroundColor: textSecondary,
    side: const BorderSide(color: borderDark, width: 1),
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    ),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
    ),
  );

  static ButtonStyle dangerButton() => ElevatedButton.styleFrom(
    backgroundColor: red,
    foregroundColor: Colors.white,
    elevation: 0,
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    ),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );

  static ButtonStyle outlineButton({required Color color}) => OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color.withValues(alpha: 0.7), width: 1.5),
    minimumSize: const Size(double.infinity, buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusButton),
    ),
    textStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );
}
