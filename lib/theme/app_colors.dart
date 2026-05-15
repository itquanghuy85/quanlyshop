import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ========== PRIMARY ==========
  static const Color primary       = Color(0xFF4D8EE9); // Soft Blue (original)
  static const Color primaryLight  = Color(0xFF42A5F5); // Blue 400
  static const Color primaryDark   = Color(0xFF0068FF); // Zalo Blue
  static const Color primarySurface = Color(0xFFE8F1FD); // soft blue tint

  // ========== SECONDARY ==========
  static const Color secondary     = Color(0xFFFF9800); // Orange 500
  static const Color secondaryLight = Color(0xFFFFB74D); // Orange 300
  static const Color secondaryDark  = Color(0xFFF57C00); // Orange 700

  // ========== SEMANTIC ==========
  static const Color success      = Color(0xFF388E3C); // Green 700
  static const Color successLight = Color(0xFFE8F5E9); // Green 50
  static const Color warning      = Color(0xFFF57C00); // Orange 700
  static const Color warningLight = Color(0xFFFFF3E0); // Orange 50
  static const Color error        = Color(0xFFD32F2F); // Red 700
  static const Color errorLight   = Color(0xFFFFEBEE); // Red 50
  static const Color info         = Color(0xFF0068FF); // Zalo Blue
  static const Color infoLight    = Color(0xFFE3F2FD); // Blue 50

  // ========== SURFACE ==========
  static const Color background    = Color(0xFFF8FAFF); // blue-tinted white
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5); // Grey 100
  static const Color shadow        = Color(0x1F000000);

  // ========== BORDER ==========
  static const Color divider    = Color(0xFFE0E0E0); // Grey 300
  static const Color outline    = Color(0xFFE0E0E0); // Grey 300
  static const Color outlineFocus = primary;

  // ========== TEXT ==========
  static const Color onPrimary    = Color(0xFFFFFFFF);
  static const Color onSecondary  = Color(0xFFFFFFFF);
  static const Color onSurface    = Color(0xFF1C1B1F);
  static const Color onBackground = Color(0xFF1C1B1F);
  static const Color onError      = Color(0xFFFFFFFF);
  static const Color onSuccess    = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1C1B1F); // near-black
  static const Color textSecondary = Color(0xFF616161); // Grey 700
  static const Color textDisabled  = Color(0xFF9E9E9E); // Grey 500
  static const Color textHint      = Color(0xFFBDBDBD); // Grey 400

  // ========== STATUS ==========
  static const Color active    = Color(0xFF4CAF50); // Green 500
  static const Color inactive  = Color(0xFF9E9E9E); // Grey 500
  static const Color pending   = Color(0xFFFF9800); // Orange 500
  static const Color completed = Color(0xFF4CAF50); // Green 500
  static const Color cancelled = Color(0xFFF44336); // Red 500

  // ========== REPAIR STATUS ==========
  static const Color repairReceived        = Color(0xFF1976D2); // Blue 700
  static const Color repairRepairing       = Color(0xFFFF9800); // Orange 500
  static const Color repairDone            = Color(0xFF2E7D32); // Green 800
  static const Color repairPendingApproval = Color(0xFFE65100); // Deep Orange
  static const Color repairDelivered       = Color(0xFF7B1FA2); // Purple 700

  // ========== PASTEL ICON BACKGROUNDS (Material 50 tints) ==========
  static const Color iconBgBlue   = Color(0xFFE3F2FD); // Blue 50
  static const Color iconBgGreen  = Color(0xFFE8F5E9); // Green 50
  static const Color iconBgOrange = Color(0xFFFFF3E0); // Orange 50
  static const Color iconBgRed    = Color(0xFFFFEBEE); // Red 50
  static const Color iconBgPurple = Color(0xFFF3E5F5); // Purple 50
  static const Color iconBgTeal   = Color(0xFFE0F2F1); // Teal 50
  static const Color iconBgYellow = Color(0xFFFFFDE7); // Yellow 50
  static const Color iconBgGray   = Color(0xFFF5F5F5); // Grey 100
  static const Color iconBgPink   = Color(0xFFFCE4EC); // Pink 50

  // ========== GREY SCALE (Material Design Grey) ==========
  static const Color grey50  = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // ========== INTERACTION ==========
  static const Color hover       = Color(0x1F0068FF);
  static const Color ripple      = Color(0x330068FF);
  static const Color focusBorder = Color(0xFF0068FF);

  // ========== APP BAR ==========
  static const Color appBarBg = Color(0xFF0068FF); // Zalo Blue
  static const Color appBarFg = Color(0xFFFFFFFF);

  // ========== GRADIENTS ==========
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0068FF), Color(0xFF0084FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color withAlpha(Color color, int alpha) =>
      color.withAlpha(alpha);
}
