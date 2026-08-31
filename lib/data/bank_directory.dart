// Danh bạ app ngân hàng + đầu số SMS ngân hàng — dùng để LỌC thông báo trước
// khi đọc nội dung. Chỉ thông báo từ nguồn trong danh sách này mới được xử lý;
// mọi thông báo khác bị BỎ QUA hoàn toàn (không đọc, không lưu).
//
// Danh sách best-effort — sai/thiếu 1 gói app chỉ khiến ngân hàng đó không
// được tự bắt (người dùng vẫn gõ tay ở "Đối soát tiền về"), KHÔNG gây lỗi.

/// package name app ngân hàng → tên hiển thị.
const Map<String, String> kBankAppPackages = {
  'com.VCB': 'Vietcombank',
  'com.vietcombank.vcbdigibank': 'Vietcombank',
  'com.vietinbank.ipay': 'VietinBank',
  'com.vnpay.bidv': 'BIDV',
  'com.vnpay.Agribank3g': 'Agribank',
  'com.agribank3g': 'Agribank',
  'com.agribank.mbanking': 'Agribank',
  'vn.com.techcombank.bb.app': 'Techcombank',
  'com.mbmobile': 'MB Bank',
  'mobile.acb.com.vn': 'ACB',
  'com.acb.mbanking': 'ACB',
  'com.vnpay.vpbankonline': 'VPBank',
  'com.vpbank.mobile': 'VPBank',
  'com.vnpay.sacombank': 'Sacombank',
  'src.com.sacombank': 'Sacombank',
  'com.sacombank.ewallet': 'Sacombank',
  'com.tpb.mb.gprsandroid': 'TPBank',
  'com.vnpay.hdbank': 'HDBank',
  'vn.shb.mbanking': 'SHB',
  'com.shb.mb': 'SHB',
  'com.vib.myvib2': 'VIB',
  'com.vib.myvib': 'VIB',
  'com.msb.mobilebanking': 'MSB',
  'vn.com.msb.smartBanking': 'MSB',
  'vn.com.ocb.awe': 'OCB',
  'com.ocb.omni': 'OCB',
  'vn.com.seabank.mb': 'SeABank',
  'com.eximbank.ebank': 'Eximbank',
  'com.vnpay.EximBankOmni': 'Eximbank',
  'com.lienvietpostbank.mydigi': 'LPBank',
  'vn.com.lpb.lienvietbank': 'LPBank',
  'ops.namabank.com.vn': 'Nam A Bank',
  'com.bacabank.bankplus': 'Bac A Bank',
  'com.pvcombank.retail': 'PVcomBank',
  'com.scb.mobilebanking': 'SCB',
  'com.abbank.mobile': 'ABBank',
  'vn.abbank.retail': 'ABBank',
  'com.ncb.bank': 'NCB',
  'com.vietabank.ipay': 'VietABank',
  'com.baovietbank.mobile': 'BaoVietBank',
  'com.kienlongbank.mbanking': 'KienLongBank',
  // Ví điện tử phổ biến ở cửa hàng (cũng gửi thông báo +/- tiền).
  'com.mservice.momotransfer': 'MoMo',
  'vn.com.vng.zalopay': 'ZaloPay',
  'com.vietteltelecom.bankplus': 'Viettel Money',
  'com.vnpt.media.vnptpay': 'VNPT Money',
};

/// package name app nhắn tin (SMS) — thông báo SMS ngân hàng đi qua đây.
const Set<String> kSmsAppPackages = {
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.android.messaging',
  'com.android.mms',
  'com.coloros.mms', // Oppo/Realme
  'com.oppo.messaging',
  'com.vivo.messaging', // Vivo
  'com.miui.messages', // Xiaomi
  'com.oneplus.mms',
  'com.transsion.sms',
};

/// đầu số / brandname SMS ngân hàng (đã chuẩn hoá: bỏ dấu, IN HOA, bỏ khoảng
/// trắng) → tên hiển thị. Thông báo SMS chỉ được xử lý nếu tiêu đề (tên người
/// gửi) khớp danh sách này.
const Map<String, String> kBankSmsSenders = {
  'VIETCOMBANK': 'Vietcombank',
  'VCB': 'Vietcombank',
  'VCBDIGIBANK': 'Vietcombank',
  'VIETINBANK': 'VietinBank',
  'BIDV': 'BIDV',
  'BIDVSMARTBANKING': 'BIDV',
  'AGRIBANK': 'Agribank',
  'TECHCOMBANK': 'Techcombank',
  'TCB': 'Techcombank',
  'MBBANK': 'MB Bank',
  'MB': 'MB Bank',
  'ACB': 'ACB',
  'VPBANK': 'VPBank',
  'SACOMBANK': 'Sacombank',
  'TPBANK': 'TPBank',
  'HDBANK': 'HDBank',
  'SHB': 'SHB',
  'VIB': 'VIB',
  'MSB': 'MSB',
  'OCB': 'OCB',
  'SEABANK': 'SeABank',
  'EXIMBANK': 'Eximbank',
  'LPBANK': 'LPBank',
  'LIENVIETPOSTBANK': 'LPBank',
  'NAMABANK': 'Nam A Bank',
  'BACABANK': 'Bac A Bank',
  'PVCOMBANK': 'PVcomBank',
  'SCB': 'SCB',
  'ABBANK': 'ABBank',
  'NCB': 'NCB',
  'VIETABANK': 'VietABank',
  'BAOVIETBANK': 'BaoVietBank',
  'KIENLONGBANK': 'KienLongBank',
  'KLB': 'KienLongBank',
};

String _normSender(String s) {
  const from =
      'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
  const to =
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  final b = StringBuffer();
  for (final ch in s.toUpperCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Xác định thông báo có phải từ 1 ngân hàng được hỗ trợ không.
/// Trả về tên ngân hàng, hoặc `null` nếu KHÔNG phải nguồn ngân hàng
/// (→ service bỏ qua hoàn toàn, không đọc nội dung).
String? resolveBankSource({
  required String? packageName,
  required String? notificationTitle,
}) {
  final pkg = (packageName ?? '').trim();
  if (pkg.isEmpty) return null;

  final direct = kBankAppPackages[pkg];
  if (direct != null) return direct;

  if (kSmsAppPackages.contains(pkg)) {
    final sender = _normSender(notificationTitle ?? '');
    if (sender.isEmpty) return null;
    // Khớp chính xác trước, rồi khớp tiền tố (một số máy thêm hậu tố).
    final exact = kBankSmsSenders[sender];
    if (exact != null) return exact;
    for (final e in kBankSmsSenders.entries) {
      if (sender.startsWith(e.key) && e.key.length >= 3) return e.value;
    }
  }
  return null;
}
