import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/core/utils/money_utils.dart' as core;
import 'package:quanlyshop/utils/money_utils.dart';

/// Tab Lãi 2026-09-12: "848.2 Tr" / "24.43 Tr" đọc không ra vì cả app dùng
/// dấu CHẤM ngăn nghìn ("24.430.000"). Dạng rút gọn phải theo ký hiệu Việt:
/// phẩy thập phân, chấm ngăn nghìn.
void main() {
  group('MoneyUtils.formatCompactCurrency — ký hiệu Việt', () {
    test('triệu: phẩy thập phân', () {
      expect(MoneyUtils.formatCompactCurrency(24430000), '24,43 Tr');
      expect(MoneyUtils.formatCompactCurrency(848200000), '848,2 Tr');
      expect(MoneyUtils.formatCompactCurrency(1500000), '1,5 Tr');
      expect(MoneyUtils.formatCompactCurrency(5000000), '5 Tr');
    });

    test('tỷ: phẩy thập phân, chấm ngăn nghìn', () {
      expect(MoneyUtils.formatCompactCurrency(6350000000), '6,35 Tỷ');
      expect(MoneyUtils.formatCompactCurrency(1234000000000), '1.234 Tỷ');
    });

    test('dưới 1 triệu in đầy đủ, âm giữ dấu', () {
      expect(MoneyUtils.formatCompactCurrency(550000), '550.000');
      expect(MoneyUtils.formatCompactCurrency(-24430000), '-24,43 Tr');
    });
  });

  test('core MoneyUtils.formatCompact cùng ký hiệu', () {
    expect(core.MoneyUtils.formatCompact(24430000), '24,43 Tr');
    expect(core.MoneyUtils.formatCompact(6350000000), '6,35 Tỷ');
    expect(core.MoneyUtils.formatCompact(550000), '550.000');
  });
}
