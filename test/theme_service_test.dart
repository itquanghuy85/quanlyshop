import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quanlyshop/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeService', () {
    late ThemeService themeService;

    setUp(() {
      themeService = ThemeService();
    });

    test('should initialize with system theme mode by default', () async {
      SharedPreferences.setMockInitialValues({});
      await themeService.init();

      expect(themeService.themeMode, ThemeMode.system);
      expect(themeService.locale.languageCode, 'vi');
    });

    test('should toggle between light and dark mode', () async {
      SharedPreferences.setMockInitialValues({});
      await themeService.init();

      // Start with light mode
      await themeService.setThemeMode(ThemeMode.light);
      expect(themeService.isLightMode, true);
      expect(themeService.isDarkMode, false);

      // Toggle to dark
      await themeService.toggleTheme();
      expect(themeService.isLightMode, false);
      expect(themeService.isDarkMode, true);

      // Toggle back to light
      await themeService.toggleTheme();
      expect(themeService.isLightMode, true);
      expect(themeService.isDarkMode, false);
    });

    test('should return correct theme mode name', () async {
      SharedPreferences.setMockInitialValues({});
      await themeService.init();

      await themeService.setThemeMode(ThemeMode.light);
      expect(themeService.getThemeModeName(), 'Sáng');

      await themeService.setThemeMode(ThemeMode.dark);
      expect(themeService.getThemeModeName(), 'Tối');

      await themeService.setThemeMode(ThemeMode.system);
      expect(themeService.getThemeModeName(), 'Hệ thống');
    });
  });
}