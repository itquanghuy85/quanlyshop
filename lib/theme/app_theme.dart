import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_button_styles.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -1),

      // ========== COLORS ==========
      primaryColor: AppColors.primary,
      primaryColorLight: AppColors.primaryLight,
      primaryColorDark: AppColors.primaryDark,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.divider,

      colorScheme: DesignTokens.colorScheme,
      fontFamily: 'Roboto',
      textTheme: AppTypography.textTheme,

      // ========== APP BAR ==========
      // toolbarHeight aligned with CustomAppBar.kAppBarHeight = 44
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0068FF), // Zalo Blue
        foregroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.surface,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 1.3,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: AppColors.surface, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.surface, size: 22),
        toolbarHeight: 44,
      ),

      // ========== BOTTOM NAVIGATION ==========
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey400,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 11,
        ),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedIconTheme: const IconThemeData(size: 22),
        unselectedIconTheme: const IconThemeData(size: 22),
      ),

      // ========== TAB BAR ==========
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: AppColors.primary,
        dividerColor: AppColors.outline,
      ),

      // ========== CARD ==========
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shadowColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.brMd,
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        clipBehavior: Clip.antiAlias,
      ),

      // ========== BUTTONS ==========
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: AppButtonStyles.elevatedButtonStyle,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.outlinedButtonStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppButtonStyles.textButtonStyle,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          minimumSize: const Size(0, DesignTokens.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: DesignTokens.brMd),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ========== INPUT DECORATION ==========
      // Compact sizes — controlled via DesignTokens.formPaddingH/V & formFontSize.
      // Change those constants to resize ALL form fields app-wide.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: DesignTokens.formContentPadding,
        border: OutlineInputBorder(
          borderRadius: DesignTokens.brSm,
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brSm,
          borderSide: const BorderSide(color: AppColors.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brSm,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brSm,
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: DesignTokens.brSm,
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(
          fontSize: DesignTokens.formLabelSize,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          fontSize: DesignTokens.formFontSize,
          color: AppColors.textHint,
          fontWeight: FontWeight.w400,
        ),
        errorStyle: const TextStyle(
          fontSize: 10,
          color: AppColors.error,
          height: 1.3,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        iconColor: AppColors.textSecondary,
        helperStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        prefixIconConstraints: const BoxConstraints(
          minWidth: DesignTokens.iconMd + 16,
          minHeight: DesignTokens.iconMd,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: DesignTokens.iconMd + 16,
          minHeight: DesignTokens.iconMd,
        ),
      ),

      // ========== LIST TILE ==========
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minLeadingWidth: 0,
        minVerticalPadding: 8,
        iconColor: AppColors.textSecondary,
        visualDensity: VisualDensity(horizontal: 0, vertical: -2),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        leadingAndTrailingTextStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),

      // ========== DIALOG ==========
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 4,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brLg),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),

      // ========== BOTTOM SHEET ==========
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLg)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        dragHandleColor: AppColors.grey300,
      ),

      // ========== SNACK BAR ==========
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.grey900,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: DesignTokens.brSm),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // ========== CHIP ==========
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.grey100,
        selectedColor: AppColors.primarySurface,
        disabledColor: AppColors.grey100,
        secondarySelectedColor: AppColors.primarySurface,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary),
        brightness: Brightness.light,
        deleteIconColor: AppColors.textSecondary,
        checkmarkColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusFull),
          side: const BorderSide(color: AppColors.outline),
        ),
        side: const BorderSide(color: AppColors.outline),
      ),

      // ========== FLOATING ACTION BUTTON ==========
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        focusElevation: 4,
        hoverElevation: 4,
        disabledElevation: 0,
        shape: CircleBorder(),
      ),

      // ========== ICON THEME ==========
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: DesignTokens.iconLg),
      primaryIconTheme: const IconThemeData(color: AppColors.onPrimary, size: DesignTokens.iconLg),

      // ========== DIVIDER ==========
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ========== PROGRESS INDICATOR ==========
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySurface,
        circularTrackColor: AppColors.primarySurface,
      ),

      // ========== SWITCH ==========
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.grey400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primarySurface;
          return AppColors.grey200;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.grey300;
        }),
      ),

      // ========== CHECKBOX ==========
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.grey400, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ========== RADIO ==========
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.grey400;
        }),
      ),

      // ========== POPUP MENU ==========
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        elevation: 4,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: DesignTokens.brMd,
          side: const BorderSide(color: AppColors.outline),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme.copyWith(brightness: Brightness.dark);
}
