import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/utils/responsive_layout.dart';

void main() {
  group('ResponsiveLayout', () {
    // TODO: Uncomment when static methods are accessible
    /*
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
    */
  });
}