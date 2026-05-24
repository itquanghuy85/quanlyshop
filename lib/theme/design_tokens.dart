import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

class DesignTokens {
  DesignTokens._();

  // ========== TOUCH TARGET ==========
  static const double touchTargetMin = 44;

  // ========== BORDER RADIUS ==========
  static const double radiusXs  = 6;
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusXl  = 20;
  static const double radiusFull = 999;

  static BorderRadius get brXs   => BorderRadius.circular(radiusXs);
  static BorderRadius get brSm   => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd   => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg   => BorderRadius.circular(radiusLg);
  static BorderRadius get brXl   => BorderRadius.circular(radiusXl);
  static BorderRadius get brFull => BorderRadius.circular(radiusFull);

  // ========== ICON SIZES ==========
  static const double iconXs  = 12;
  static const double iconSm  = 14;
  static const double iconMd  = 16;
  static const double iconLg  = 18;
  static const double iconXl  = 20;

  // ========== ICON CONTAINER ==========
  static const double iconContainer = 26;
  static const double iconContainerLg = 30;

  // ========== FIELD / BUTTON HEIGHTS ==========
  // Compact — ~2/3 of previous values for dense form layouts
  static const double fieldHeight     = 36;
  static const double fieldHeightSm   = 30;
  static const double buttonHeight    = 36;
  static const double buttonHeightSm  = 30;
  static const double listItemHeight  = 44;

  // ========== FORM CONTENT PADDING ==========
  // Single source of truth — change here to resize all themed fields
  static const double formPaddingH = 10.0;
  static const double formPaddingV = 7.0;
  static const EdgeInsets formContentPadding = EdgeInsets.symmetric(
    horizontal: formPaddingH,
    vertical: formPaddingV,
  );
  static const double formFontSize     = 13.0;
  static const double formLabelSize    = 12.0;
  static const double formSectionGap   = 8.0;
  static const double formSectionPad   = 10.0;

  // ========== GAPS ==========
  static const double iconTextGap = AppSpacing.sm;

  // ========== MOTION ==========
  static const Duration motionFast   = Duration(milliseconds: 150);
  static const Duration motionNormal = Duration(milliseconds: 220);
  static const Duration motionSlow   = Duration(milliseconds: 350);

  // ========== ELEVATION / SHADOW ==========
  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowElevated => [
    BoxShadow(
      color: AppColors.grey900.withAlpha(20),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ========== TYPOGRAPHY ==========
  static TextTheme get textTheme => AppTypography.textTheme;

  // ========== COLOR SCHEME ==========
  static ColorScheme get colorScheme => const ColorScheme.light(
    primary:      AppColors.primary,
    secondary:    AppColors.secondary,
    surface:      AppColors.surface,
    error:        AppColors.error,
    onPrimary:    AppColors.onPrimary,
    onSecondary:  AppColors.onSecondary,
    onSurface:    AppColors.onSurface,
    onError:      AppColors.onError,
    outline:      AppColors.outline,
    surfaceContainerHighest: AppColors.surfaceVariant,
  );

  // ========== ICON CONTAINER DECORATION ==========
  static BoxDecoration iconContainerDecoration(Color bg, {double radius = radiusSm}) =>
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius));
}
