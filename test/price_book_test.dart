import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/price_book_models.dart';
import 'package:quanlyshop/services/price_book_service.dart';

void main() {
  group('PriceBookService — khoá', () {
    test('repairKey chuẩn hoá (bỏ dấu, gộp khoảng trắng, thường)', () {
      final a = PriceBookService.repairKey('iPhone   12', 'Ép Kính');
      final b = PriceBookService.repairKey('IPHONE 12', 'ép kính');
      expect(a, b);
      expect(a.startsWith('r|'), isTrue);
    });

    test('saleKey gồm brand/model/dung lượng/tình trạng', () {
      final k = PriceBookService.saleKey('Apple', 'iPhone 12', '128GB', 'Mới');
      expect(k.startsWith('s|'), isTrue);
      expect(
        PriceBookService.saleKey('APPLE', 'IPHONE 12', '128gb', 'MỚI'),
        k,
      );
    });

    test('issue rỗng vẫn ra khoá hợp lệ, khác khoá có issue', () {
      final noIssue = PriceBookService.repairKey('iPhone 12', null);
      final withIssue = PriceBookService.repairKey('iPhone 12', 'Thay pin');
      expect(noIssue, isNot(withIssue));
    });
  });

  group('PriceBookRow — giá hiệu lực', () {
    test('chưa ghim → dùng giá auto', () {
      const r = PriceBookRow(
        scope: 'repair',
        key: 'r|x|y',
        brand: 'iPhone',
        title: 'iPhone 12 · Ép kính',
        autoPrice: 350000,
        autoCost: 120000,
        source: PriceSource.auto,
      );
      expect(r.effectivePrice, 350000);
      expect(r.effectiveProfit, 230000);
      expect(r.isPinned, isFalse);
    });

    test('đã ghim → dùng giá ghim, đè giá auto', () {
      const r = PriceBookRow(
        scope: 'repair',
        key: 'r|x|y',
        brand: 'iPhone',
        title: 'iPhone 12 · Ép kính',
        autoPrice: 350000,
        autoCost: 120000,
        source: PriceSource.pinned,
        pinnedPrice: 400000,
        pinnedCost: 130000,
      );
      expect(r.effectivePrice, 400000);
      expect(r.effectiveCost, 130000);
      expect(r.effectiveProfit, 270000);
      expect(r.isPinned, isTrue);
    });

    test('ghim không kèm giá vốn → dùng giá vốn auto', () {
      const r = PriceBookRow(
        scope: 'sale',
        key: 's|a|b|c|d',
        brand: 'iPhone',
        title: 'iPhone 12 128GB',
        autoPrice: 8000000,
        autoCost: 7000000,
        source: PriceSource.pinned,
        pinnedPrice: 8500000,
      );
      expect(r.effectivePrice, 8500000);
      expect(r.effectiveCost, 7000000);
    });
  });

  group('PricePin JSON', () {
    test('roundtrip giữ nguyên dữ liệu', () {
      const pin = PricePin(
        price: 400000,
        cost: 130000,
        note: 'giá Tết',
        pinnedAt: 1735600000000,
        pinnedBy: 'huy',
      );
      final back = PricePin.fromJson(pin.toJson());
      expect(back.price, pin.price);
      expect(back.cost, pin.cost);
      expect(back.note, pin.note);
      expect(back.pinnedAt, pin.pinnedAt);
      expect(back.pinnedBy, pin.pinnedBy);
    });

    test('thiếu cost → null', () {
      final back = PricePin.fromJson({'price': 100, 'at': 1, 'by': ''});
      expect(back.cost, isNull);
      expect(back.price, 100);
    });
  });

  group('PriceResolution', () {
    test('hasPrice / isPinned', () {
      const none = PriceResolution();
      expect(none.hasPrice, isFalse);
      const pinned = PriceResolution(
        price: 300000,
        source: PriceSource.pinned,
      );
      expect(pinned.hasPrice, isTrue);
      expect(pinned.isPinned, isTrue);
    });
  });
}
