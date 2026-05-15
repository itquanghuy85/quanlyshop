import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/kiotviet_service.dart';

void main() {
  group('normalizeRetailerCode', () {
    test('giu nguyen retailer code don gian', () {
      expect(KiotVietService.normalizeRetailerCode('huymobile'), 'huymobile');
    });

    test('chuan hoa url https', () {
      expect(
        KiotVietService.normalizeRetailerCode(
          'https://huymobile.kiotviet.vn',
        ),
        'huymobile',
      );
    });

    test('chuan hoa url http', () {
      expect(
        KiotVietService.normalizeRetailerCode(
          'http://huymobile.kiotviet.vn',
        ),
        'huymobile',
      );
    });

    test('trim va lower case retailer code', () {
      expect(
        KiotVietService.normalizeRetailerCode('  HUYMOBILE  '),
        'huymobile',
      );
    });

    test('bao loi neu retailer khong hop le', () {
      expect(
        () => KiotVietService.normalizeRetailerCode('https://google.com'),
        throwsA(isA<FormatException>()),
      );
    });

    test('bao loi neu retailer rong', () {
      expect(
        () => KiotVietService.normalizeRetailerCode('   '),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
