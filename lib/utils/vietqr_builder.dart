import 'dart:convert';

/// Danh sách ngân hàng VN phổ biến kèm mã BIN theo chuẩn NAPAS247/VietQR.
/// Nguồn: danh sách BIN công khai của napas.com.vn / vietqr.io (ổn định,
/// hiếm khi đổi). Nếu ngân hàng khách dùng không có trong danh sách, cho
/// phép nhập tay mã BIN 6 số ở màn cài đặt.
class VietQrBank {
  final String bin;
  final String shortName;
  final String fullName;

  const VietQrBank({
    required this.bin,
    required this.shortName,
    required this.fullName,
  });
}

const List<VietQrBank> vietQrBanks = [
  VietQrBank(bin: '970436', shortName: 'Vietcombank', fullName: 'Ngân hàng TMCP Ngoại thương Việt Nam'),
  VietQrBank(bin: '970415', shortName: 'VietinBank', fullName: 'Ngân hàng TMCP Công thương Việt Nam'),
  VietQrBank(bin: '970418', shortName: 'BIDV', fullName: 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam'),
  VietQrBank(bin: '970405', shortName: 'Agribank', fullName: 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam'),
  VietQrBank(bin: '970407', shortName: 'Techcombank', fullName: 'Ngân hàng TMCP Kỹ thương Việt Nam'),
  VietQrBank(bin: '970422', shortName: 'MB Bank', fullName: 'Ngân hàng TMCP Quân đội'),
  VietQrBank(bin: '970416', shortName: 'ACB', fullName: 'Ngân hàng TMCP Á Châu'),
  VietQrBank(bin: '970432', shortName: 'VPBank', fullName: 'Ngân hàng TMCP Việt Nam Thịnh Vượng'),
  VietQrBank(bin: '970403', shortName: 'Sacombank', fullName: 'Ngân hàng TMCP Sài Gòn Thương Tín'),
  VietQrBank(bin: '970423', shortName: 'TPBank', fullName: 'Ngân hàng TMCP Tiên Phong'),
  VietQrBank(bin: '970437', shortName: 'HDBank', fullName: 'Ngân hàng TMCP Phát triển TP.HCM'),
  VietQrBank(bin: '970443', shortName: 'SHB', fullName: 'Ngân hàng TMCP Sài Gòn - Hà Nội'),
  VietQrBank(bin: '970431', shortName: 'Eximbank', fullName: 'Ngân hàng TMCP Xuất Nhập khẩu Việt Nam'),
  VietQrBank(bin: '970426', shortName: 'MSB', fullName: 'Ngân hàng TMCP Hàng Hải'),
  VietQrBank(bin: '970440', shortName: 'SeABank', fullName: 'Ngân hàng TMCP Đông Nam Á'),
  VietQrBank(bin: '970448', shortName: 'OCB', fullName: 'Ngân hàng TMCP Phương Đông'),
  VietQrBank(bin: '970425', shortName: 'ABBank', fullName: 'Ngân hàng TMCP An Bình'),
  VietQrBank(bin: '970441', shortName: 'VIB', fullName: 'Ngân hàng TMCP Quốc tế Việt Nam'),
  VietQrBank(bin: '970449', shortName: 'LienVietPostBank', fullName: 'Ngân hàng TMCP Bưu điện Liên Việt'),
  VietQrBank(bin: '970429', shortName: 'SCB', fullName: 'Ngân hàng TMCP Sài Gòn'),
  VietQrBank(bin: '970406', shortName: 'DongABank', fullName: 'Ngân hàng TMCP Đông Á'),
  VietQrBank(bin: '970428', shortName: 'NamABank', fullName: 'Ngân hàng TMCP Nam Á'),
  VietQrBank(bin: '970409', shortName: 'BacABank', fullName: 'Ngân hàng TMCP Bắc Á'),
  VietQrBank(bin: '970412', shortName: 'PVcomBank', fullName: 'Ngân hàng TMCP Đại Chúng Việt Nam'),
  VietQrBank(bin: '970419', shortName: 'NCB', fullName: 'Ngân hàng TMCP Quốc Dân'),
  VietQrBank(bin: '970427', shortName: 'VietABank', fullName: 'Ngân hàng TMCP Việt Á'),
  VietQrBank(bin: '970438', shortName: 'BaoVietBank', fullName: 'Ngân hàng TMCP Bảo Việt'),
  VietQrBank(bin: '970433', shortName: 'VietBank', fullName: 'Ngân hàng TMCP Việt Nam Thương Tín'),
  VietQrBank(bin: '970452', shortName: 'KienLongBank', fullName: 'Ngân hàng TMCP Kiên Long'),
  VietQrBank(bin: '970430', shortName: 'PGBank', fullName: 'Ngân hàng TMCP Xăng dầu Petrolimex'),
];

/// Tạo chuỗi payload QR chuyển khoản theo chuẩn EMVCo QR / VietQR (NAPAS,
/// GUID "A000000727") — chuẩn công khai, được mọi app ngân hàng/ví VN hỗ
/// trợ đọc. Tính toán thuần offline, không gọi API ngoài.
///
/// QUAN TRỌNG: đây là tính năng liên quan trực tiếp tới tiền — PHẢI tự quét
/// thử bằng 1 app ngân hàng thật trước khi dùng cho khách, để xác nhận đọc
/// đúng số tài khoản/số tiền trước khi tin tưởng hoàn toàn.
String buildVietQrPayload({
  required String bankBin,
  required String accountNumber,
  int? amountVnd,
  String? message,
}) {
  String tlv(String id, String value) {
    final len = value.length.toString().padLeft(2, '0');
    return '$id$len$value';
  }

  final hasAmount = amountVnd != null && amountVnd > 0;

  final merchantAccountInfo = tlv('00', 'A000000727') +
      tlv('01', tlv('00', bankBin) + tlv('01', accountNumber)) +
      tlv('02', 'QRIBFTTA');

  final buffer = StringBuffer()
    ..write(tlv('00', '01')) // Payload Format Indicator
    ..write(tlv('01', hasAmount ? '12' : '11')) // Point of Initiation Method
    ..write(tlv('38', merchantAccountInfo)) // Merchant Account Info (VietQR)
    ..write(tlv('53', '704')); // Transaction Currency: VND

  if (hasAmount) {
    buffer.write(tlv('54', amountVnd.toString()));
  }

  buffer.write(tlv('58', 'VN')); // Country Code

  final trimmedMessage = message?.trim() ?? '';
  if (trimmedMessage.isNotEmpty) {
    buffer.write(tlv('62', tlv('08', trimmedMessage)));
  }

  final withCrcTag = '${buffer.toString()}6304';
  final crc = _crc16CcittFalse(withCrcTag).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$withCrcTag$crc';
}

/// CRC-16/CCITT-FALSE: poly=0x1021, init=0xFFFF, không reflect, xorout=0.
/// Đây đúng biến thể CRC mà chuẩn EMVCo QR yêu cầu cho field 63.
int _crc16CcittFalse(String data) {
  int crc = 0xFFFF;
  for (final byte in utf8.encode(data)) {
    crc ^= (byte << 8);
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return crc & 0xFFFF;
}
