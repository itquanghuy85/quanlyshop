import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/utils/internal_tools.dart';

void main() {
  group('InternalTools.visibleFor — bản phát hành (isDebugBuild: false)', () {
    bool release(String? email, {bool isSuperAdmin = false}) =>
        InternalTools.visibleFor(
          email: email,
          isSuperAdmin: isSuperAdmin,
          isDebugBuild: false,
        );

    test('email nội bộ trong danh sách thì thấy', () {
      expect(release('huy@huluca.com'), isTrue);
    });

    test('chuẩn hoá hoa/thường và khoảng trắng thừa', () {
      expect(release('  HUY@Huluca.COM '), isTrue);
    });

    test('chủ shop thường KHÔNG thấy', () {
      expect(release('m@m.com'), isFalse);
    });

    test('email rỗng / null KHÔNG thấy', () {
      expect(release(null), isFalse);
      expect(release(''), isFalse);
      expect(release('   '), isFalse);
    });

    test('email gần giống KHÔNG lọt', () {
      expect(release('huy@huluca.com.vn'), isFalse);
      expect(release('xhuy@huluca.com'), isFalse);
    });

    test('super admin luôn thấy dù không có trong danh sách', () {
      expect(release('admin@huluca.com', isSuperAdmin: true), isTrue);
      expect(release(null, isSuperAdmin: true), isTrue);
    });
  });

  test('bản debug thì ai cũng thấy', () {
    expect(
      InternalTools.visibleFor(
        email: 'm@m.com',
        isSuperAdmin: false,
        isDebugBuild: true,
      ),
      isTrue,
    );
  });
}
