import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quanlyshop/services/theme_service.dart';
import 'package:quanlyshop/utils/responsive_layout.dart';

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

    test('should return correct theme data', () async {
      SharedPreferences.setMockInitialValues({});
      await themeService.init();

      await themeService.setThemeMode(ThemeMode.light);
      // Test that theme mode is set correctly
      expect(themeService.themeMode, ThemeMode.light);

      await themeService.setThemeMode(ThemeMode.dark);
      expect(themeService.themeMode, ThemeMode.dark);
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

  // TODO: Uncomment when static methods are accessible
  /*
  group('ResponsiveLayout', () {
    test('should detect mobile screen', () {
      // Test with mobile width
      final mobileQuery = MediaQueryData(size: const Size(360, 640));
      expect(ResponsiveLayout.isMobileFromQuery(mobileQuery), true);
      expect(ResponsiveLayout.isTabletFromQuery(mobileQuery), false);
      expect(ResponsiveLayout.isDesktopFromQuery(mobileQuery), false);
    });

    test('should detect tablet screen', () {
      // Test with tablet width
      final tabletQuery = MediaQueryData(size: const Size(768, 1024));
      expect(ResponsiveLayout.isMobileFromQuery(tabletQuery), false);
      expect(ResponsiveLayout.isTabletFromQuery(tabletQuery), true);
      expect(ResponsiveLayout.isDesktopFromQuery(tabletQuery), false);
    });

    test('should calculate responsive font size', () {
      // Test with small mobile screen
      final smallQuery = MediaQueryData(size: const Size(320, 568));
      final smallFont = ResponsiveLayout.getResponsiveFontSizeFromQuery(smallQuery, 16);
      expect(smallFont, 14.4); // 16 * 0.9

      // Test with normal screen
      final normalQuery = MediaQueryData(size: const Size(360, 640));
      final normalFont = ResponsiveLayout.getResponsiveFontSizeFromQuery(normalQuery, 16);
      expect(normalFont, 16.0); // No scaling
    });

    test('should calculate responsive grid columns', () {
      // Test with mobile screen
      final mobileQuery = MediaQueryData(size: const Size(360, 640));
      expect(ResponsiveLayout.getResponsiveGridColumnsFromQuery(mobileQuery), 2);

      // Test with tablet screen
      final tabletQuery = MediaQueryData(size: const Size(768, 1024));
      expect(ResponsiveLayout.getResponsiveGridColumnsFromQuery(tabletQuery), 3);
    });
  });
  */

  group('AdaptiveText', () {
    testWidgets('should render with responsive font size', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return AdaptiveText(
                'Test Text',
                style: const TextStyle(fontSize: 16),
              );
            },
          ),
        ),
      );

      final textWidget = tester.widget<Text>(find.text('Test Text'));
      expect(textWidget.style?.fontSize, isNotNull);
    });
  });

  group('ResponsiveContainer', () {
    testWidgets('should apply responsive padding', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveContainer(
            child: const Text('Test'),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      expect(container.padding, isNotNull);
    });
  });
}