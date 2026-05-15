import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ========== PRIMARY ==========
  static const Color primary       = Color(0xFF007AFF); // iOS System Blue
  static const Color primaryLight  = Color(0xFF40AEFF);
  static const Color primaryDark   = Color(0xFF0056D6);
  static const Color primarySurface = Color(0xFFEBF4FF);

  // ========== SECONDARY ==========
  static const Color secondary     = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFBBF24);
  static const Color secondaryDark  = Color(0xFFD97706);

  // ========== SEMANTIC ==========
  static const Color success      = Color(0xFF34A853);
  static const Color successLight = Color(0xFFEEF9F1);
  static const Color warning      = Color(0xFFE6A700);
  static const Color warningLight = Color(0xFFFFF8E8);
  static const Color error        = Color(0xFFEF4444);
  static const Color errorLight   = Color(0xFFFEF2F2);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoLight    = Color(0xFFEFF6FF);

  // ========== SURFACE ==========
  static const Color background    = Color(0xFFF5F7FB);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF9FAFB);
  static const Color shadow        = Color(0x14000000);

  // ========== BORDER ==========
  static const Color divider    = Color(0xFFEEF2F7);
  static const Color outline    = Color(0xFFE5EAF2);
  static const Color outlineFocus = primary;

  // ========== TEXT ==========
  static const Color onPrimary    = Color(0xFFFFFFFF);
  static const Color onSecondary  = Color(0xFFFFFFFF);
  static const Color onSurface    = Color(0xFF1F2937);
  static const Color onBackground = Color(0xFF1F2937);
  static const Color onError      = Color(0xFFFFFFFF);
  static const Color onSuccess    = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled  = Color(0xFFD1D5DB);
  static const Color textHint      = Color(0xFF9CA3AF);

  // ========== STATUS ==========
  static const Color active    = Color(0xFF34A853);
  static const Color inactive  = Color(0xFF9CA3AF);
  static const Color pending   = Color(0xFFE6A700);
  static const Color completed = Color(0xFF34A853);
  static const Color cancelled = Color(0xFFEF4444);

  // ========== REPAIR STATUS ==========
  static const Color repairReceived        = Color(0xFF007AFF);
  static const Color repairRepairing       = Color(0xFFE6A700);
  static const Color repairDone            = Color(0xFF34A853);
  static const Color repairPendingApproval = Color(0xFFF07526);
  static const Color repairDelivered       = Color(0xFF7C3AED);

  // ========== PASTEL ICON BACKGROUNDS ==========
  static const Color iconBgBlue   = Color(0xFFEBF4FF);
  static const Color iconBgGreen  = Color(0xFFEEF9F1);
  static const Color iconBgOrange = Color(0xFFFFF7ED);
  static const Color iconBgRed    = Color(0xFFFEF2F2);
  static const Color iconBgPurple = Color(0xFFF5F3FF);
  static const Color iconBgTeal   = Color(0xFFF0FDFA);
  static const Color iconBgYellow = Color(0xFFFFF8E8);
  static const Color iconBgGray   = Color(0xFFF9FAFB);
  static const Color iconBgPink   = Color(0xFFFDF2F8);

  // ========== GREY SCALE (Tailwind Gray) ==========
  static const Color grey50  = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // ========== INTERACTION ==========
  static const Color hover      = Color(0x0A007AFF);
  static const Color ripple     = Color(0x1A007AFF);
  static const Color focusBorder = primary;

  // ========== APP BAR ==========
  static const Color appBarBg = Color(0xFF007AFF); // iOS System Blue
  static const Color appBarFg = Color(0xFFFFFFFF);

  // ========== GRADIENTS ==========
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF007AFF), Color(0xFF0056D6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color withAlpha(Color color, int alpha) =>
      color.withAlpha(alpha);
}
