import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ========== PRIMARY ==========
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primarySurface = Color(0xFFEFF6FF); // blue-50

  // ========== SECONDARY ==========
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFBBF24);
  static const Color secondaryDark = Color(0xFFD97706);

  // ========== SEMANTIC ==========
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF0EA5E9);
  static const Color infoLight = Color(0xFFE0F2FE);

  // ========== SURFACE ==========
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8FAFC);
  static const Color shadow = Color(0x14000000);

  // ========== BORDER ==========
  static const Color divider = Color(0xFFF1F3F5);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color outlineFocus = primary;

  // ========== TEXT ==========
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color onBackground = Color(0xFF0F172A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color textHint = Color(0xFF94A3B8);

  // ========== STATUS ==========
  static const Color active = Color(0xFF16A34A);
  static const Color inactive = Color(0xFF94A3B8);
  static const Color pending = Color(0xFFF59E0B);
  static const Color completed = Color(0xFF16A34A);
  static const Color cancelled = Color(0xFFEF4444);

  // ========== REPAIR STATUS ==========
  static const Color repairReceived = Color(0xFF2563EB);
  static const Color repairRepairing = Color(0xFFF59E0B);
  static const Color repairDone = Color(0xFF16A34A);
  static const Color repairPendingApproval = Color(0xFFEA580C);
  static const Color repairDelivered = Color(0xFF7C3AED);

  // ========== PASTEL ICON BACKGROUNDS ==========
  static const Color iconBgBlue = Color(0xFFEFF6FF);
  static const Color iconBgGreen = Color(0xFFF0FDF4);
  static const Color iconBgOrange = Color(0xFFFFF7ED);
  static const Color iconBgRed = Color(0xFFFFF1F2);
  static const Color iconBgPurple = Color(0xFFF5F3FF);
  static const Color iconBgTeal = Color(0xFFF0FDFA);
  static const Color iconBgYellow = Color(0xFFFEFCE8);
  static const Color iconBgGray = Color(0xFFF8FAFC);
  static const Color iconBgPink = Color(0xFFFDF2F8);

  // ========== GREY SCALE ==========
  static const Color grey50  = Color(0xFFF8FAFC);
  static const Color grey100 = Color(0xFFF1F5F9);
  static const Color grey200 = Color(0xFFE2E8F0);
  static const Color grey300 = Color(0xFFCBD5E1);
  static const Color grey400 = Color(0xFF94A3B8);
  static const Color grey500 = Color(0xFF64748B);
  static const Color grey600 = Color(0xFF475569);
  static const Color grey700 = Color(0xFF334155);
  static const Color grey800 = Color(0xFF1E293B);
  static const Color grey900 = Color(0xFF0F172A);

  // ========== INTERACTION ==========
  static const Color hover = Color(0x0A2563EB);
  static const Color ripple = Color(0x1A2563EB);
  static const Color focusBorder = primary;

  // ========== APP BAR ==========
  static const Color appBarBg = Color(0xFF0068FF);   // Zalo Blue
  static const Color appBarFg = Color(0xFFFFFFFF);   // White

  // ========== GRADIENTS ==========
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
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
