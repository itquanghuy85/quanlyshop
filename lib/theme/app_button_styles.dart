import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

class AppButtonStyles {
  AppButtonStyles._();

  // ========== ELEVATED BUTTON ==========
  static ButtonStyle get elevatedButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    shadowColor: Colors.transparent,
    minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: DesignTokens.brMd,
    ),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  ).copyWith(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.grey200;
      if (states.contains(WidgetState.pressed)) return AppColors.primaryDark;
      return AppColors.primary;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.grey50;
      return AppColors.onPrimary;
    }),
    elevation: WidgetStateProperty.all(0),
    overlayColor: WidgetStateProperty.all(Colors.white.withAlpha(25)),
  );

  // ========== OUTLINED BUTTON ==========
  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(
      borderRadius: DesignTokens.brMd,
    ),
    side: const BorderSide(color: AppColors.primary, width: 1),
    textStyle: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return AppColors.grey400;
      return AppColors.primary;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return const BorderSide(color: AppColors.grey300);
      }
      return const BorderSide(color: AppColors.primary);
    }),
  );

  // ========== TEXT BUTTON ==========
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size(0, DesignTokens.buttonHeightSm),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  // ========== DANGER BUTTON ==========
  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: AppColors.onError,
    elevation: 0,
    minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  // ========== SMALL BUTTON ==========
  static ButtonStyle get smallButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    minimumSize: const Size(0, DesignTokens.buttonHeightSm),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
  );

  // ========== SUCCESS BUTTON ==========
  static ButtonStyle get successElevatedButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );

  // ========== ERROR BUTTON ==========
  static ButtonStyle get errorElevatedButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: AppColors.onPrimary,
    elevation: 0,
    minimumSize: const Size(double.infinity, DesignTokens.buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  );
}
