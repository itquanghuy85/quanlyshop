import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/utils/warranty_note.dart';

void main() {
  group('WarrantyNote.normalize', () {
    test('mọi cách viết "không bảo hành" về KO BH', () {
      for (final v in ['', ' ', 'KO BH', 'Không bảo hành', 'KHÔNG BẢO HÀNH']) {
        expect(WarrantyNote.normalize(v), 'KO BH', reason: '"$v"');
        expect(WarrantyNote.isNone(v), isTrue);
      }
    });
    test('ghi chú tự do giữ nguyên', () {
      expect(WarrantyNote.normalize(' BH màn 3 tháng '), 'BH màn 3 tháng');
    });
  });

  group('WarrantyNote.parseMonths / expiryFrom', () {
    final start = DateTime(2026, 1, 15).millisecondsSinceEpoch;
    test('chip chuẩn', () {
      expect(WarrantyNote.parseMonths('6 THÁNG'), 6);
      expect(WarrantyNote.expiryFrom(start, '6 THÁNG'), DateTime(2026, 7, 15));
    });
    test('ghi chú tự do lấy mốc đầu tiên', () {
      expect(WarrantyNote.parseMonths('BH MÀN 3 THÁNG, PIN 6 THÁNG'), 3);
      expect(WarrantyNote.parseMonths('bh 12th'), 12);
      expect(WarrantyNote.parseMonths('1 năm'), 12);
    });
    test('ngày / tuần', () {
      expect(WarrantyNote.expiryFrom(start, '15 ngày'), DateTime(2026, 1, 30));
      expect(WarrantyNote.expiryFrom(start, '2 tuần'), DateTime(2026, 1, 29));
    });
    test('không có số ⇒ không tính hạn (không mặc định 12 tháng nữa)', () {
      expect(WarrantyNote.parseMonths('bảo hành theo hãng'), 0);
      expect(WarrantyNote.expiryFrom(start, 'bảo hành theo hãng'), isNull);
      expect(WarrantyNote.expiryFrom(start, 'KO BH'), isNull);
    });
  });
}
