import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/bank_notification_parser.dart';
import 'package:quanlyshop/data/bank_directory.dart';

void main() {
  group('BankNotificationParser.parse', () {
    test('VCB — ghi có, có dấu +, có số dư', () {
      final r = BankNotificationParser.parse(
        title: 'Vietcombank',
        content:
            'So du TK 0071000123456 +500,000 VND luc 31-08-2025 10:30. '
            'So du 1,234,567 VND. Ref abc123',
      );
      expect(r, isNotNull);
      expect(r!.amount, 500000);
      expect(r.direction, 'credit');
      expect(r.balanceAfter, 1234567);
    });

    test('Techcombank — GD: +, memo, số dư', () {
      final r = BankNotificationParser.parse(
        title: 'TCB',
        content:
            'TK 19012345678 | GD: +2,000,000 VND 10:30 31/08 | '
            'So du: 5,000,000 VND | ND: CHUYEN TIEN TRA HANG',
      );
      expect(r, isNotNull);
      expect(r!.amount, 2000000);
      expect(r.direction, 'credit');
      expect(r.balanceAfter, 5000000);
      expect(r.memo, contains('CHUYEN TIEN'));
    });

    test('MB Bank — (-1.000.000)đ ghi nợ', () {
      final r = BankNotificationParser.parse(
        title: 'MB Bank',
        content:
            '(-1.000.000)d | TK 0123 | 10:30 31/08/24 | So du 234.567d | '
            'ND thanh toan tien dien',
      );
      expect(r, isNotNull);
      expect(r!.amount, 1000000);
      expect(r.direction, 'debit');
      expect(r.balanceAfter, 234567);
    });

    test('ACB — GHI CO không dấu', () {
      final r = BankNotificationParser.parse(
        title: 'ACB',
        content:
            'TK cua Quy khach GHI CO 300,000 VND. So du 900,000 VND',
      );
      expect(r, isNotNull);
      expect(r!.amount, 300000);
      expect(r.direction, 'credit');
      expect(r.balanceAfter, 900000);
    });

    test('BIDV — biến động không rõ chiều → unknown', () {
      final r = BankNotificationParser.parse(
        title: 'BIDV',
        content: 'TK 123 bien dong 250,000 VND. So du 750,000 VND',
      );
      expect(r, isNotNull);
      expect(r!.amount, 250000);
      expect(r.direction, 'unknown');
      expect(r.balanceAfter, 750000);
    });

    test('GHI NO — ghi nợ không dấu', () {
      final r = BankNotificationParser.parse(
        title: 'VPBank',
        content: 'TK 123 GHI NO 2,000,000 VND. SD: 500,000 VND',
      );
      expect(r, isNotNull);
      expect(r!.amount, 2000000);
      expect(r.direction, 'debit');
      expect(r.balanceAfter, 500000);
    });

    test('Số có phần thập phân ",00"', () {
      final r = BankNotificationParser.parse(
        title: 'Sacombank',
        content: '+1.500.000,00 VND. So du: 2.000.000,00 VND',
      );
      expect(r, isNotNull);
      expect(r!.amount, 1500000);
      expect(r.direction, 'credit');
      expect(r.balanceAfter, 2000000);
    });

    test('Số không có ngăn cách', () {
      final r = BankNotificationParser.parse(
        title: 'VPBank',
        content: '+500000 VND So du 1000000 VND',
      );
      expect(r, isNotNull);
      expect(r!.amount, 500000);
      expect(r.direction, 'credit');
    });

    test('OTP → bỏ qua', () {
      final r = BankNotificationParser.parse(
        title: 'Vietcombank',
        content:
            'Ma OTP cua ban la 123456. Khong chia se cho ai. Han muc 5,000,000 VND',
      );
      expect(r, isNull);
    });

    test('Ưu đãi / khuyến mãi → bỏ qua', () {
      final r = BankNotificationParser.parse(
        title: 'TPBank',
        content: 'Uu dai: Hoan tien 50,000 VND khi thanh toan hoa don',
      );
      expect(r, isNull);
    });

    test('Đăng nhập thành công (không có tiền) → bỏ qua', () {
      final r = BankNotificationParser.parse(
        title: 'MB Bank',
        content: 'Dang nhap thanh cong luc 10:30 tren thiet bi Oppo CPH2203',
      );
      expect(r, isNull);
    });

    test('Số không kèm đơn vị tiền tệ → bỏ qua (tránh nhầm ngày/mã)', () {
      final r = BankNotificationParser.parse(
        title: 'ACB',
        content: 'Giao dich thanh cong ma 202508311030 luc 31/08/2025',
      );
      expect(r, isNull);
    });

    test('Nhắc nợ thẻ tín dụng → bỏ qua', () {
      final r = BankNotificationParser.parse(
        title: 'VIB',
        content:
            'Nhac no: The tin dung den han thanh toan 3,000,000 VND ngay 05/09',
      );
      expect(r, isNull);
    });

    test('title + content rỗng → null', () {
      expect(BankNotificationParser.parse(title: '', content: ''), isNull);
      expect(BankNotificationParser.parse(), isNull);
    });

    // Luồng "Dán tin nhắn NH" ở màn Đối soát chỉ truyền `content` (người dùng
    // copy nguyên body SMS, không có tiêu đề) — phải parse được như thường.
    test('dán body SMS (chỉ content, không title) — ghi có', () {
      final r = BankNotificationParser.parse(
        content:
            'TK 0071000123456|GD:+690,000VND luc 31/08/2025 12:22'
            '|So du:5,200,000VND|ND: TRAN THUONG CK tra hang',
      );
      expect(r, isNotNull);
      expect(r!.amount, 690000);
      expect(r.direction, 'credit');
      expect(r.balanceAfter, 5200000);
      expect(r.memo, contains('TRAN THUONG'));
    });

    test('dán body SMS (chỉ content) — ghi nợ', () {
      final r = BankNotificationParser.parse(
        content: 'TK 0071000123456 -2.500.000 VND. So du 700.000 VND',
      );
      expect(r, isNotNull);
      expect(r!.amount, 2500000);
      expect(r.direction, 'debit');
      expect(r.balanceAfter, 700000);
    });

    test('dán nội dung không liên quan → null', () {
      final r = BankNotificationParser.parse(
        content: 'Chieu nay 5h qua quan cafe nhe',
      );
      expect(r, isNull);
    });

    test('chỉ có số dư, không có số tiền GD → null', () {
      final r = BankNotificationParser.parse(
        title: 'VCB',
        content: 'So du tai khoan cua quy khach la 1,234,567 VND',
      );
      expect(r, isNull);
    });
  });

  group('resolveBankSource', () {
    test('app ngân hàng trong danh sách → tên NH', () {
      expect(
        resolveBankSource(
            packageName: 'com.mbmobile', notificationTitle: 'Thông báo'),
        'MB Bank',
      );
      expect(
        resolveBankSource(
            packageName: 'vn.com.techcombank.bb.app', notificationTitle: null),
        'Techcombank',
      );
    });

    test('app SMS + đầu số ngân hàng → tên NH', () {
      expect(
        resolveBankSource(
          packageName: 'com.coloros.mms',
          notificationTitle: 'Vietcombank',
        ),
        'Vietcombank',
      );
      expect(
        resolveBankSource(
          packageName: 'com.google.android.apps.messaging',
          notificationTitle: 'TPBank',
        ),
        'TPBank',
      );
    });

    test('app SMS + người gửi KHÔNG phải ngân hàng → null', () {
      expect(
        resolveBankSource(
          packageName: 'com.coloros.mms',
          notificationTitle: 'Mom',
        ),
        isNull,
      );
      expect(
        resolveBankSource(
          packageName: 'com.google.android.apps.messaging',
          notificationTitle: '+84987654321',
        ),
        isNull,
      );
    });

    test('app bất kỳ khác → null (không đọc)', () {
      expect(
        resolveBankSource(
            packageName: 'com.facebook.orca', notificationTitle: 'Techcombank'),
        isNull,
      );
      expect(
        resolveBankSource(packageName: '', notificationTitle: 'VCB'),
        isNull,
      );
    });
  });
}
