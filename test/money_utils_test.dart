import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/utils/money_utils.dart';

void main() {
  group('MoneyUtils', () {
    test('parseMoney with empty string', () {
      expect(MoneyUtils.parseMoney(''), 0);
    });

    test('parseMoney with integer', () {
      expect(MoneyUtils.parseMoney('123'), 123);
    });

    test('parseMoney with dots and spaces', () {
      expect(MoneyUtils.parseMoney('1.000'), 1000);
    });

    test('parseMoney with mixed characters', () {
      expect(MoneyUtils.parseMoney('abc123def'), 123);
    });

    test('parseMoney with negative', () {
      expect(MoneyUtils.parseMoney('-123'), 123); // since RegExp removes -
    });
  });
}