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
  static const double iconXs  = 14;
  static const double iconSm  = 16;
  static const double iconMd  = 18;
  static const double iconLg  = 20;
  static const double iconXl  = 24;

  // ========== ICON CONTAINER ==========
  static const double iconContainer = 30;
  static const double iconContainerLg = 36;

  // ========== FIELD / BUTTON HEIGHTS ==========
  static const double fieldHeight     = 46;
  static const double fieldHeightSm   = 40;
  static const double buttonHeight    = 44;
  static const double buttonHeightSm  = 36;
  static const double listItemHeight  = 50;

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
