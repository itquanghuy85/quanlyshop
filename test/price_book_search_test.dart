import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/utils/vietnamese_utils.dart';

// Sao chép logic tách từ khoá của price_book_view (hàm private) để chốt hành
// vi: bỏ dấu, viết tắt, khớp mọi từ không cần thứ tự.
const aliases = {'ip': 'iphone', 'ss': 'samsung', 'ek': 'ep kinh'};
List<String> tokens(String q) => VietnameseUtils.normalize(q)
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .map((t) => aliases[t] ?? t)
    .toList();
bool match(String title, String q) {
  final hay = VietnameseUtils.normalize(title);
  return tokens(q).every(hay.contains);
}

void main() {
  test('khớp không cần thứ tự, bỏ dấu, viết tắt', () {
    expect(match('iPhone 12 · Ép kính', 'ép kính iphone 12'), isTrue);
    expect(match('iPhone 12 · Ép kính', 'ip 12 ek'), isTrue);
    expect(match('iPhone 12 · Ép kính', 'ep kinh 12'), isTrue);
    expect(match('Samsung A52 · Thay pin', 'ss a52'), isTrue);
    expect(match('iPhone 12 · Ép kính', 'iphone 13'), isFalse);
  });
}
