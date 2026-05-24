import '../utils/vietnamese_utils.dart';

class VoiceCorrectionResult {
  final String corrected;
  final List<String> changes;
  const VoiceCorrectionResult({required this.corrected, this.changes = const []});
  bool get hasChanges => changes.isNotEmpty;
}

/// Sửa lỗi nhận dạng giọng nói chuyên ngành shop điện thoại.
///
/// Chiến lược 3 lớp:
///   1. Regex rules trên text đã normalize (không dấu, viết thường)
///   2. Chuyển số bằng lời → chữ số trong ngữ cảnh model máy
///   3. Ghép âm gần đúng cho các từ thường bị nghe sai hoàn toàn
class VoiceCorrectionService {
  VoiceCorrectionService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // LỚP 1 — REGEX RULES (khớp trên text đã normalize)
  // ═══════════════════════════════════════════════════════════════════════════

  static final _kRules = <(RegExp, String)>[

    // ── THƯƠNG HIỆU MÁY ─────────────────────────────────────────────────────

    // iPhone — các biến thể phát âm sai phổ biến
    (RegExp(r'\bai\s*f[o0]n\w*'),         'iPhone'),
    (RegExp(r'\bai\s*ph[o0]n\w*'),        'iPhone'),
    (RegExp(r'\bi\s*ph[o0]n\w*'),         'iPhone'),
    (RegExp(r'\bip\s*h[o0]n\w*'),         'iPhone'),
    (RegExp(r'\bai\s*p[o0]n\w*'),         'iPhone'),
    (RegExp(r'\bay\s*ph[o0]n\w*'),        'iPhone'),
    (RegExp(r'\baif[o0]n\w*'),            'iPhone'),
    (RegExp(r'\bapple\s*ph[o0]n\w*'),     'iPhone'),

    // Samsung — biến thể miền Nam/Bắc
    (RegExp(r'\bsam\s*s[ui]ng\b'),        'Samsung'),
    (RegExp(r'\bsang\s*sung\b'),          'Samsung'),
    (RegExp(r'\bsam\s*xung\b'),           'Samsung'),
    (RegExp(r'\bxam\s*sung\b'),           'Samsung'),
    (RegExp(r'\bxam\s*xung\b'),           'Samsung'),
    (RegExp(r'\bsan\s*sung\b'),           'Samsung'),
    (RegExp(r'\bsam\s*soong\b'),          'Samsung'),
    (RegExp(r'\bxam\s*soong\b'),          'Samsung'),

    // Galaxy (dòng sản phẩm Samsung)
    (RegExp(r'\bgal\s*axy\b'),            'Galaxy'),
    (RegExp(r'\bgal\s*ac\s*xi\b'),        'Galaxy'),
    (RegExp(r'\bgal\s*lek\s*xi\b'),       'Galaxy'),
    (RegExp(r'\bga\s*la\s*xi\b'),         'Galaxy'),

    // Oppo
    (RegExp(r'\bop\s*p[o0]\b'),           'Oppo'),
    (RegExp(r'\bo\s*p[o0]\b'),            'Oppo'),
    (RegExp(r'\bop\s*pô\b'),              'Oppo'),
    (RegExp(r'\bo\s*pô\b'),               'Oppo'),

    // Xiaomi — nhiều biến thể
    (RegExp(r'\bxi\s*ao\s*mi\b'),         'Xiaomi'),
    (RegExp(r'\bxiao\s*mi\b'),            'Xiaomi'),
    (RegExp(r'\bsiao\s*mi\b'),            'Xiaomi'),
    (RegExp(r'\bxao\s*mi\b'),             'Xiaomi'),
    (RegExp(r'\bxa\s*mi\b'),              'Xiaomi'),
    (RegExp(r'\bshi\s*a\s*mi\b'),         'Xiaomi'),
    (RegExp(r'\bshao\s*mi\b'),            'Xiaomi'),
    (RegExp(r'\bsia\s*o\s*mi\b'),         'Xiaomi'),
    (RegExp(r'\bsieu\s*mi\b'),            'Xiaomi'),
    (RegExp(r'\bxieu\s*mi\b'),            'Xiaomi'),

    // Redmi (Xiaomi sub-brand)
    (RegExp(r'\bred\s*mi\b'),             'Redmi'),
    (RegExp(r'\bred\s*mi\b'),             'Redmi'),
    (RegExp(r'\bret\s*mi\b'),             'Redmi'),

    // POCO (Xiaomi sub-brand)
    (RegExp(r'\bp[o0]k\s*[o0]\b'),        'POCO'),
    (RegExp(r'\bp[o0]c\s*[o0]\b'),        'POCO'),

    // Vivo
    (RegExp(r'\bvi\s*v[o0]\b'),           'Vivo'),
    (RegExp(r'\bvi\s*b[o0]\b'),           'Vivo'),
    (RegExp(r'\bvie\s*v[o0]\b'),          'Vivo'),

    // Realme
    (RegExp(r'\bre\s*al\s*me\b'),         'Realme'),
    (RegExp(r'\bri\s*[oa]n\s*mi\b'),      'Realme'),
    (RegExp(r'\bri\s*an\s*me\b'),         'Realme'),
    (RegExp(r'\breal\s*mi\b'),            'Realme'),
    (RegExp(r'\bre\s*mi\b'),              'Realme'),

    // Huawei
    (RegExp(r'\bhua\s*w?ei\b'),           'Huawei'),
    (RegExp(r'\bhua\s*uei\b'),            'Huawei'),
    (RegExp(r'\bhua\s*ue\b'),             'Huawei'),
    (RegExp(r'\bhua\s*way\b'),            'Huawei'),

    // Nokia
    (RegExp(r'\bn[o0]\s*kia\b'),          'Nokia'),
    (RegExp(r'\bn[o0]\s*ki\s*a\b'),       'Nokia'),

    // Tecno / Infinix / Motorola
    (RegExp(r'\btek\s*n[o0]\b'),          'Tecno'),
    (RegExp(r'\bin\s*fi\s*nix\b'),        'Infinix'),
    (RegExp(r'\bm[o0]\s*t[o0]\s*r[o0]\s*la\b'), 'Motorola'),
    (RegExp(r'\bm[o0]\s*t[o0]\b'),        'Motorola'),

    // Apple Watch / AirPods
    (RegExp(r'\bap\s*ple\s*watch\b'),     'Apple Watch'),
    (RegExp(r'\bai\s*r\s*p[o0]ds?\b'),    'AirPods'),
    (RegExp(r'\btai\s*nghe\s*apple\b'),   'AirPods'),

    // ── MODEL IPHONE ─────────────────────────────────────────────────────────
    // Dạng "iPhone Pro Max", "iPhone Plus", "iPhone Mini"
    (RegExp(r'\bpr[o0]\s*max\b'),         'Pro Max'),
    (RegExp(r'\bpr[o0]\s*mak\b'),         'Pro Max'),
    (RegExp(r'\bpro\s*mex\b'),            'Pro Max'),
    (RegExp(r'\bpr[o0]\b'),               'Pro'),
    (RegExp(r'\bpl[ui]s\b'),              'Plus'),
    (RegExp(r'\bplu\b'),                  'Plus'),
    (RegExp(r'\bmin[il]\b'),              'Mini'),
    (RegExp(r'\bmi\s*ni\b'),              'Mini'),

    // ── DÒNG SAMSUNG ────────────────────────────────────────────────────────
    (RegExp(r'\bgal\w*\b'),               'Galaxy'),   // "gal..." → Galaxy (giữ model phía sau)
    (RegExp(r'\bfe\b'),                   'FE'),
    (RegExp(r'\btab\s*[as]\w*\b'),        'Galaxy Tab'),

    // ── MÀN HÌNH / LCD / OLED ───────────────────────────────────────────────

    // Biến thể nghe sai của "màn hình"
    (RegExp(r'\blam\s*hinh\b'),           'màn hình'),   // Làm đêm → màn hình?
    (RegExp(r'\blam\s*him\b'),            'màn hình'),
    (RegExp(r'\bman\s*hinh\b'),           'màn hình'),
    (RegExp(r'\bman\s*him\b'),            'màn hình'),
    (RegExp(r'\bman\s*hin\b'),            'màn hình'),
    (RegExp(r'\bman\s*hins\b'),           'màn hình'),
    (RegExp(r'\bmang\s*hinh\b'),          'màn hình'),
    (RegExp(r'\bmang\s*him\b'),           'màn hình'),
    (RegExp(r'\bmon\s*hinh\b'),           'màn hình'),
    (RegExp(r'\bmon\s*him\b'),            'màn hình'),
    (RegExp(r'\bdan\s*hinh\b'),           'màn hình'),   // "đen hình"
    (RegExp(r'\bdem\s*hinh\b'),           'màn hình'),   // "đêm hình"
    (RegExp(r'\bmen\s*hinh\b'),           'màn hình'),
    (RegExp(r'\bmai\s*hinh\b'),           'màn hình'),

    (RegExp(r'\bthay\s*m[ao][nm]g?\b'),   'thay màn hình'),
    (RegExp(r'\bthay\s*bang\b'),          'thay màn hình'),
    (RegExp(r'\bthay\s*man\b'),           'thay màn hình'),
    (RegExp(r'\bthay\s*dem\b'),           'thay màn hình'),  // "đêm" → "màn"
    (RegExp(r'\bthay\s*lam\b'),           'thay màn hình'),  // "làm" → "màn"
    (RegExp(r'\bthay\s*ben\b'),           'thay màn hình'),  // "bên" → "màn"
    (RegExp(r'\bthay\s*dan\b'),           'thay màn hình'),  // "đan" → "màn"
    (RegExp(r'\bthay\s*lcd\b'),           'thay màn hình LCD'),
    (RegExp(r'\bthay\s*oled\b'),          'thay màn hình OLED'),
    (RegExp(r'\bep\s*kinh\b'),            'ép kính'),
    (RegExp(r'\bep\s*man\b'),             'ép màn hình'),
    (RegExp(r'\bman\s*hinh\s*den\b'),     'màn hình đen'),
    (RegExp(r'\bman\s*hinh\s*trang\b'),   'màn hình trắng'),
    (RegExp(r'\bman\s*hinh\s*liet\b'),    'màn hình liệt'),
    (RegExp(r'\bman\s*hinh\s*nut\b'),     'màn hình nứt'),
    (RegExp(r'\bman\s*hinh\s*be\b'),      'màn hình bể'),
    (RegExp(r'\bman\s*hinh\s*vo\b'),      'màn hình vỡ'),
    (RegExp(r'\bman\s*bong\b'),           'màn hình bong tróc'),
    (RegExp(r'\bbong\s*man\b'),           'màn hình bong tróc'),

    // Cảm ứng
    (RegExp(r'\bcam\s*ung\b'),            'cảm ứng'),
    (RegExp(r'\bcam\s*hung\b'),           'cảm ứng'),
    (RegExp(r'\bkan\s*ung\b'),            'cảm ứng'),
    (RegExp(r'\bcam\s*ung\s*liet\b'),     'cảm ứng liệt'),
    (RegExp(r'\bcam\s*ung\s*kem\b'),      'cảm ứng kém'),
    (RegExp(r'\bcam\s*ung\s*nhay\b'),     'cảm ứng nhảy'),
    (RegExp(r'\bman\s*nhay\b'),           'màn hình nhảy'),

    // Kính / ép kính
    (RegExp(r'\bthay\s*ki[nm]h?\b'),      'thay kính'),
    (RegExp(r'\bthay\s*ki[nm]g\b'),       'thay kính'),
    (RegExp(r'\bthay\s*kin\b'),           'thay kính'),
    (RegExp(r'\bdan\s*ki[nm]h?\b'),       'dán kính'),
    (RegExp(r'\bdan\s*man\s*hinh\b'),     'dán màn hình'),
    (RegExp(r'\bmieng\s*dan\b'),          'miếng dán'),
    (RegExp(r'\bkiing\b'),                'kính'),

    // ── PIN / SẠC ────────────────────────────────────────────────────────────

    (RegExp(r'\bthay\s*pi[nm]\b'),        'thay pin'),
    (RegExp(r'\bthay\s*bin\b'),           'thay pin'),
    (RegExp(r'\bthay\s*phin\b'),          'thay pin'),
    (RegExp(r'\bthay\s*pinh\b'),          'thay pin'),
    (RegExp(r'\bthay\s*bat\b'),           'thay pin'),
    (RegExp(r'\bnap\s*pi[nm]\b'),         'nạp pin'),
    (RegExp(r'\bsac\s*pi[nm]\b'),         'sạc pin'),
    (RegExp(r'\bpi[nm]\s*chai\b'),        'pin chai'),
    (RegExp(r'\bpi[nm]\s*yeu\b'),         'pin yếu'),
    (RegExp(r'\bpi[nm]\s*han\b'),         'pin hao nhanh'),
    (RegExp(r'\bpi[nm]\s*nhanh\b'),       'pin hao nhanh'),
    (RegExp(r'\bhao\s*pi[nm]\b'),         'hao pin'),
    (RegExp(r'\bthay\s*cuc\s*sac\b'),     'thay cục sạc'),
    (RegExp(r'\bthay\s*day\s*sac\b'),     'thay dây sạc'),
    (RegExp(r'\bthay\s*cong\s*sac\b'),    'thay cổng sạc'),
    (RegExp(r'\bthay\s*jack\b'),          'thay jack sạc'),
    (RegExp(r'\bthay\s*rac\b'),           'thay jack sạc'),
    (RegExp(r'\bthay\s*sac\b'),           'thay sạc'),
    (RegExp(r'\bsua\s*sac\b'),            'sửa sạc'),
    (RegExp(r'\bcong\s*sac\b'),           'cổng sạc'),
    (RegExp(r'\bkhong\s*nhan\s*sac\b'),   'không nhận sạc'),
    (RegExp(r'\bkhong\s*sac\s*duoc\b'),   'không sạc được'),

    // ── MAIN / IC / BO MẠCH ─────────────────────────────────────────────────

    (RegExp(r'\bsua\s*ma[yi]?n\b'),       'sửa main'),
    (RegExp(r'\bsua\s*me[yi]?n\b'),       'sửa main'),
    (RegExp(r'\bsua\s*mai\b'),            'sửa main'),
    (RegExp(r'\bsua\s*men\b'),            'sửa main'),
    (RegExp(r'\bsua\s*bo\s*mach\b'),      'sửa bo mạch'),
    (RegExp(r'\bthay\s*ma[yi]?n\b'),      'thay main'),
    (RegExp(r'\bthay\s*ic\b'),            'thay IC'),
    (RegExp(r'\bsua\s*ic\b'),             'sửa IC'),
    (RegExp(r'\bsua\s*nguon\b'),          'sửa nguồn'),
    (RegExp(r'\bkhong\s*len\s*nguon\b'),  'không lên nguồn'),
    (RegExp(r'\bkhong\s*bat\s*nguon\b'),  'không bật nguồn'),
    (RegExp(r'\bmat\s*nguon\b'),          'mất nguồn'),
    (RegExp(r'\bchet\s*nguon\b'),         'chết nguồn'),
    (RegExp(r'\btao\b(?=\s*may)'),        'táo'),          // "táo" = iOS (bị nghe thành "tạo")
    (RegExp(r'\btreo\s*tao\b'),           'treo táo'),     // iPhone reboot loop
    (RegExp(r'\bkho[yi]\s*may\b'),        'khởi động máy'),
    (RegExp(r'\brestart\b'),              'khởi động lại'),
    (RegExp(r'\bformat\b'),               'format máy'),
    (RegExp(r'\bflash\b'),                'flash máy'),

    // ── CAMERA ──────────────────────────────────────────────────────────────

    (RegExp(r'\bthay\s*cam\s*era\b'),     'thay camera'),
    (RegExp(r'\bthay\s*cam\b'),           'thay camera'),
    (RegExp(r'\bsua\s*cam\s*era\b'),      'sửa camera'),
    (RegExp(r'\bsua\s*cam\b'),            'sửa camera'),
    (RegExp(r'\bcam\s*era\s*truoc\b'),    'camera trước'),
    (RegExp(r'\bcam\s*era\s*sau\b'),      'camera sau'),
    (RegExp(r'\bcam\s*era\s*mo\b'),       'camera mờ'),
    (RegExp(r'\bcam\s*mo\b'),             'camera mờ'),
    (RegExp(r'\bcam\s*khong\s*chup\b'),   'camera không chụp được'),
    (RegExp(r'\bkhong\s*chup\s*duoc\b'),  'không chụp được'),
    (RegExp(r'\bden\s*flash\b'),          'đèn flash'),
    (RegExp(r'\bthay\s*kinh\s*cam\b'),    'thay kính camera'),

    // ── LOA / MIC / TAI NGHE ────────────────────────────────────────────────

    (RegExp(r'\bsua\s*loa\b'),            'sửa loa'),
    (RegExp(r'\bthay\s*loa\b'),           'thay loa'),
    (RegExp(r'\bloa\s*ngoai\b'),          'loa ngoài'),
    (RegExp(r'\bloa\s*trong\b'),          'loa trong'),
    (RegExp(r'\bloa\s*nho\b'),            'loa nhỏ'),
    (RegExp(r'\bloa\s*lon\b'),            'loa lớn'),
    (RegExp(r'\bloa\s*hong\b'),           'loa hỏng'),
    (RegExp(r'\bkhong\s*nghe\s*am\b'),    'không nghe âm thanh'),
    (RegExp(r'\bam\s*thanh\s*nho\b'),     'âm thanh nhỏ'),
    (RegExp(r'\bsua\s*mic\b'),            'sửa mic'),
    (RegExp(r'\bthay\s*mic\b'),           'thay mic'),
    (RegExp(r'\bmic\s*hong\b'),           'mic hỏng'),
    (RegExp(r'\bkhong\s*nghe\s*tieng\b'), 'không nghe tiếng'),

    // ── VỎ / MẶT LƯNG / VỎ MÁY ─────────────────────────────────────────────

    (RegExp(r'\bthay\s*vo\b'),            'thay vỏ'),
    (RegExp(r'\bthay\s*vo\s*may\b'),      'thay vỏ máy'),
    (RegExp(r'\bthay\s*mat\s*lung\b'),    'thay mặt lưng'),
    (RegExp(r'\bthay\s*nap\s*lung\b'),    'thay nắp lưng'),
    (RegExp(r'\bmat\s*lung\b'),           'mặt lưng'),
    (RegExp(r'\bnap\s*lung\b'),           'nắp lưng'),
    (RegExp(r'\bvo\s*may\b'),             'vỏ máy'),
    (RegExp(r'\bvo\s*nhom\b'),            'vỏ nhôm'),
    (RegExp(r'\bthay\s*khung\b'),         'thay khung'),
    (RegExp(r'\bthay\s*nut\b'),           'thay nút'),
    (RegExp(r'\bthay\s*nut\s*nguon\b'),   'thay nút nguồn'),
    (RegExp(r'\bthay\s*nut\s*volume\b'),  'thay nút âm lượng'),
    (RegExp(r'\bthay\s*sim\s*khay\b'),    'thay khay sim'),
    (RegExp(r'\bthay\s*khay\s*sim\b'),    'thay khay sim'),

    // ── VÔ NƯỚC / ƯỚT ───────────────────────────────────────────────────────
    // "nổi nước" là lỗi STT phổ biến khi nói "vô nước" / "ngấm nước"

    (RegExp(r'\bn[o0]i\s*nuoc\b'),        'vô nước'),      // "nổi nước" → vô nước
    (RegExp(r'\bv[o0]\s*nuoc\b'),         'vô nước'),
    (RegExp(r'\bngam\s*nuoc\b'),          'ngấm nước'),
    (RegExp(r'\brot\s*nuoc\b'),           'rớt nước'),
    (RegExp(r'\brot\s*xuong\s*nuoc\b'),   'rớt xuống nước'),
    (RegExp(r'\bxuong\s*nuoc\b'),         'xuống nước'),    // "xuống nổi nước" phổ biến
    (RegExp(r'\buot\b'),                  'ướt'),
    (RegExp(r'\bbj\s*nuoc\b'),            'bị nước'),
    (RegExp(r'\bbi\s*nuoc\b'),            'bị nước'),
    (RegExp(r'\bmay\s*bi\s*nuoc\b'),      'máy bị nước'),
    (RegExp(r'\bmay\s*nuoc\b'),           'máy bị nước'),
    (RegExp(r'\bsuot\s*nuoc\b'),          'bị nước'),
    (RegExp(r'\bxuot\s*nuoc\b'),          'bị nước'),

    // ── WIFI / BLUETOOTH / MẠNG ─────────────────────────────────────────────

    (RegExp(r'\bsua\s*wifi\b'),           'sửa WiFi'),
    (RegExp(r'\bkhong\s*bat\s*duoc\s*wifi\b'), 'không bật WiFi'),
    (RegExp(r'\bkhong\s*ket\s*wifi\b'),   'không kết WiFi'),
    (RegExp(r'\bsua\s*blue\s*tooth\b'),   'sửa Bluetooth'),
    (RegExp(r'\bkhong\s*bắt\s*song\b'),   'không bắt sóng'),
    (RegExp(r'\bkhong\s*bat\s*song\b'),   'không bắt sóng'),
    (RegExp(r'\bkhong\s*co\s*song\b'),    'không có sóng'),
    (RegExp(r'\bmat\s*song\b'),           'mất sóng'),
    (RegExp(r'\bkhong\s*co\s*mang\b'),    'không có mạng'),

    // ── CÁC TRIỆU CHỨNG PHỔ BIẾN ────────────────────────────────────────────

    (RegExp(r'\bnhan\s*may\b'),           'nhận máy'),
    (RegExp(r'\bsua\s*may\b'),            'sửa máy'),
    (RegExp(r'\bsua\s*chua\b'),           'sửa chữa'),
    (RegExp(r'\bmay\s*bi\s*hong\b'),      'máy bị hỏng'),
    (RegExp(r'\bmay\s*hu\b'),             'máy hỏng'),
    (RegExp(r'\bmay\s*hong\b'),           'máy hỏng'),
    (RegExp(r'\bmay\s*dung\b'),           'máy dừng'),
    (RegExp(r'\bbao\s*hanh\b'),           'bảo hành'),
    (RegExp(r'\bbao\s*gia\b'),            'báo giá'),
    (RegExp(r'\bgiam\s*gia\b'),           'giảm giá'),
    (RegExp(r'\bkhuyen\s*mai\b'),         'khuyến mãi'),
    (RegExp(r'\bphu\s*kien\b'),           'phụ kiện'),
    (RegExp(r'\bop\s*lung\b'),            'ốp lưng'),
    (RegExp(r'\bdan\s*lung\b'),           'dán lưng'),

    // ── LỆNH APP ─────────────────────────────────────────────────────────────

    // Tạo đơn sửa
    (RegExp(r'\btao\s*don\s*su[ae]\b'),   'tạo đơn sửa'),
    (RegExp(r'\btao\s*don\s*sua\b'),      'tạo đơn sửa'),
    (RegExp(r'\btao\s*sua\b'),            'tạo đơn sửa'),
    (RegExp(r'\bdon\s*sua\b'),            'đơn sửa'),
    (RegExp(r'\bmo\s*don\s*sua\b'),       'tạo đơn sửa'),
    (RegExp(r'\bviet\s*don\s*sua\b'),     'tạo đơn sửa'),
    (RegExp(r'\bnhap\s*don\s*sua\b'),     'tạo đơn sửa'),

    // Tạo đơn bán
    (RegExp(r'\btao\s*don\s*ban\b'),      'tạo đơn bán'),
    (RegExp(r'\btao\s*ban\b'),            'tạo đơn bán'),
    (RegExp(r'\bdon\s*ban\b'),            'đơn bán'),
    (RegExp(r'\bban\s*hang\b'),           'bán hàng'),
    (RegExp(r'\bban\s*may\b'),            'bán máy'),
    (RegExp(r'\bxuat\s*hang\b'),          'xuất hàng'),
    (RegExp(r'\bthu\s*tien\b'),           'thu tiền'),
    (RegExp(r'\bthanh\s*toan\b'),         'thanh toán'),
    (RegExp(r'\btinh\s*tien\b'),          'tính tiền'),

    // Nhập kho
    (RegExp(r'\bnhap\s*kho\b'),           'nhập kho'),
    (RegExp(r'\bnhap\s*hang\b'),          'nhập hàng'),
    (RegExp(r'\bnhan\s*hang\b'),          'nhận hàng'),
    (RegExp(r'\bhang\s*ve\b'),            'hàng về'),
    (RegExp(r'\bhang\s*moi\s*ve\b'),      'hàng mới về'),
    (RegExp(r'\bcap\s*nhat\s*kho\b'),     'cập nhật kho'),

    // Kiểm kho / Tồn kho
    (RegExp(r'\bkiem\s*kho\b'),           'kiểm kho'),
    (RegExp(r'\bton\s*kho\b'),            'tồn kho'),
    (RegExp(r'\bhan\s*ton\b'),            'hàng tồn'),
    (RegExp(r'\bxem\s*kho\b'),            'xem kho'),
    (RegExp(r'\bso\s*luong\s*ton\b'),     'số lượng tồn kho'),
    (RegExp(r'\bcon\s*bao\s*nhieu\b'),    'còn bao nhiêu'),

    // Tài chính / Thu chi
    (RegExp(r'\btai\s*chinh\b'),          'tài chính'),
    (RegExp(r'\bbao\s*cao\s*tai\s*chinh\b'), 'báo cáo tài chính'),
    (RegExp(r'\bthu\s*chi\b'),            'thu chi'),
    (RegExp(r'\bdoanh\s*thu\b'),          'doanh thu'),
    (RegExp(r'\bdoanh\s*so\b'),           'doanh số'),
    (RegExp(r'\bloi\s*nhuan\b'),          'lợi nhuận'),
    (RegExp(r'\bbao\s*cao\b'),            'báo cáo'),
    (RegExp(r'\bthong\s*ke\b'),           'thống kê'),

    // Khách hàng
    (RegExp(r'\btim\s*khach\b'),          'tìm khách'),
    (RegExp(r'\bkhach\s*hang\b'),         'khách hàng'),
    (RegExp(r'\bxem\s*khach\b'),          'xem khách'),
    (RegExp(r'\bquan\s*ly\s*khach\b'),    'quản lý khách hàng'),
    (RegExp(r'\btim\s*ten\b'),            'tìm tên'),
    (RegExp(r'\btim\s*so\b'),             'tìm số điện thoại'),

    // Công nợ
    (RegExp(r'\bcong\s*no\b'),            'công nợ'),
    (RegExp(r'\bxem\s*no\b'),             'xem nợ'),
    (RegExp(r'\bno\s*chua\s*tra\b'),      'nợ chưa trả'),
    (RegExp(r'\bthu\s*no\b'),             'thu nợ'),
    (RegExp(r'\bkhach\s*no\b'),           'khách nợ'),

    // Chấm công
    (RegExp(r'\bcham\s*cong\s*vao\b'),    'chấm công vào'),
    (RegExp(r'\bcham\s*cong\s*ra\b'),     'chấm công ra'),
    (RegExp(r'\bcham\s*cong\b'),          'chấm công'),
    (RegExp(r'\bvao\s*lam\b'),            'vào làm'),
    (RegExp(r'\bra\s*ve\b'),              'ra về'),
    (RegExp(r'\btan\s*ca\b'),             'tan ca'),
    (RegExp(r'\bhet\s*ca\b'),             'hết ca'),
    (RegExp(r'\bbat\s*dau\s*ca\b'),       'bắt đầu ca'),

    // Đơn đang chờ / Đang sửa
    (RegExp(r'\bdon\s*cho\b'),            'đơn chờ'),
    (RegExp(r'\bdon\s*dang\s*sua\b'),     'đơn đang sửa'),
    (RegExp(r'\bmay\s*chua\s*xong\b'),    'máy chưa xong'),
    (RegExp(r'\bcho\s*lay\b'),            'chờ lấy'),

    // ── TỪ NHẬP KHÁCH HÀNG / ĐƠN HÀNG THƯỜNG BỊ MẤT DẤU ────────────────────
    // STT tiếng Việt hay bỏ dấu những từ không chuyên ngành → phục hồi
    (RegExp(r'\bkhach\b'),                'khách'),
    (RegExp(r'\bten\b'),                  'tên'),
    (RegExp(r'\bso\s*dien\s*thoai\b'),    'số điện thoại'),
    (RegExp(r'\bso\s*dt\b'),              'số điện thoại'),
    (RegExp(r'\bgia\s*(?=\d)'),           'giá '),       // "gia 500" → "giá 500"
    (RegExp(r'\bgia\s*von\b'),            'giá vốn'),
    (RegExp(r'\bgia\s*ban\b'),            'giá bán'),
    (RegExp(r'\bghi\s*chu\b'),            'ghi chú'),
    (RegExp(r'\bdat\s*coc\b'),            'đặt cọc'),
    (RegExp(r'\bthu\s*khach\b'),          'thu khách'),
    (RegExp(r'\bthu\s*truoc\b'),          'thu trước'),
    (RegExp(r'\bmau\b(?=\s+\w)'),         'màu'),        // "mau den" → "màu đen"
    (RegExp(r'\bncc\b'),                  'NCC'),        // nhà cung cấp
    (RegExp(r'\bnha\s*cung\s*cap\b'),     'nhà cung cấp'),
    (RegExp(r'\bimei\b'),                 'IMEI'),
    (RegExp(r'\bmodel\b'),                'model'),
    (RegExp(r'\bso\s*luong\b'),           'số lượng'),
    (RegExp(r'\bdon\s*gia\b'),            'đơn giá'),
    (RegExp(r'\btien\s*mat\b'),           'tiền mặt'),
    (RegExp(r'\bchuyen\s*khoan\b'),       'chuyển khoản'),
    (RegExp(r'\btra\s*gop\b'),            'trả góp'),
    (RegExp(r'\bcong\s*no\b'),            'công nợ'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // LỚP 2 — CHUYỂN SỐ BẰNG LỜI → CHỮ SỐ (trong ngữ cảnh model máy)
  // ═══════════════════════════════════════════════════════════════════════════

  // Map: từ số tiếng Việt (đã normalize) → chữ số
  static const _kNumWords = {
    'muoi lam': '15', 'muoi nam': '15',
    'muoi bon': '14', 'muoi tu':  '14',
    'muoi ba':  '13',
    'muoi hai': '12',
    'muoi mot': '11',
    'muoi':     '10',
    'chin':     '9',
    'tam':      '8',
    'bay':      '7',
    'sau':      '6',
    'nam':      '5',
    'bon':      '4',
    'ba':       '3',
    'hai':      '2',
    'mot':      '1',
  };

  /// Ghép brand + series letter + số rời thành model chuẩn.
  /// "Samsung a 52" → "Samsung A52", "Redmi note 12" → "Redmi Note 12"
  static String _fixSeriesNumbers(String text) {
    // Samsung A/M/S/F/Z-series: "Samsung a 52" → "Samsung A52"
    text = text.replaceAllMapped(
      RegExp(r'\b(Samsung)\s+([aAmMsSfFzZ])\s+(\d+)\b'),
      (m) => '${m[1]} ${m[2]!.toUpperCase()}${m[3]}',
    );
    // Redmi Note / POCO X: "Redmi note 12" → "Redmi Note 12"
    text = text.replaceAllMapped(
      RegExp(r'\b(Redmi|POCO)\s+(note|x|f|m|c)\s+(\d+)\b', caseSensitive: false),
      (m) => '${m[1]} ${_cap(m[2]!)} ${m[3]}',
    );
    // iPhone số đứng riêng: "iPhone 13 pro" — đã OK, không cần xử lý thêm
    return text;
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  static String _convertNumberWords(String text) {
    // Duyệt qua từng match của brand context rồi thử convert từ số phía sau
    String result = text;
    for (final entry in _kNumWords.entries) {
      final numWord = entry.key;  // đã normalize
      final digit   = entry.value;
      // Tìm pattern: "Brand <numWord>" → "Brand <digit>"
      final pattern = RegExp(
        r'(iPhone|Samsung|Galaxy|Oppo|Xiaomi|Vivo|Realme|Nokia|Redmi|POCO|Huawei|Note|Fold|Flip|Reno)\s+' +
        numWord.replaceAll(' ', r'\s+'),
        caseSensitive: false,
      );
      result = result.replaceAllMapped(pattern, (m) => '${m[1]} $digit');
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LỚP 3 — GHI ÂM GẦN ĐÚNG (soundalike cho các từ thường bị nghe sai)
  // ═══════════════════════════════════════════════════════════════════════════
  // Các cặp (âm bị nghe sai thường → từ đúng) để xử lý trường hợp STT sai xa

  static final _kSoundalikes = <(RegExp, String)>[
    // "làm đêm" hay bị nhận khi user nói "màn hình"
    (RegExp(r'\blam\s+dem\b'),            'màn hình'),
    (RegExp(r'\blam\s+hinh\b'),           'màn hình'),
    (RegExp(r'\bdem\s+hinh\b'),           'màn hình'),

    // "nổi nước" / "xuống nổi nước" ← STT nghe sai "vô nước"
    (RegExp(r'\bxuong\s+n[o0]i\s+nuoc\b'), 'bị vô nước'),
    (RegExp(r'\bn[o0]i\s+nuoc\b'),         'vô nước'),

    // "suất" ← STT nghe thành từ "sửa"
    (RegExp(r'\bsuat\b'),                 'sửa'),

    // "toa" ← STT nghe thành "tạo"
    (RegExp(r'\btoa\s+don\b'),            'tạo đơn'),

    // "bán" bị nghe thành "bang" / "ban"
    (RegExp(r'\bbang\s+hang\b'),          'bán hàng'),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sửa lỗi STT và trả về kết quả cùng danh sách thay đổi đã áp dụng.
  static VoiceCorrectionResult correct(String raw) {
    if (raw.trim().isEmpty) {
      return const VoiceCorrectionResult(corrected: '');
    }

    // Bước 1: Normalize (bỏ dấu, viết thường) để khớp rule
    String working = VietnameseUtils.normalize(raw.toLowerCase());
    final applied = <String>{};

    // Bước 2: Soundalike pass trước (xử lý từ sai xa)
    for (final (pattern, replacement) in _kSoundalikes) {
      if (pattern.hasMatch(working)) {
        working = working.replaceAll(pattern, replacement);
        applied.add(replacement);
      }
    }

    // Bước 3: Main rules
    for (final (pattern, replacement) in _kRules) {
      if (pattern.hasMatch(working)) {
        working = working.replaceAll(pattern, replacement);
        applied.add(replacement);
      }
    }

    // Bước 4: Chuyển số bằng lời
    final beforeNum = working;
    working = _convertNumberWords(working);
    if (working != beforeNum) applied.add('số model');

    // Bước 4b: Ghép tên dòng máy với model number (dạng "Samsung a 52" → "Samsung A52")
    working = _fixSeriesNumbers(working);

    // Bước 5: Viết hoa chữ đầu câu
    if (working.isNotEmpty) {
      working = working[0].toUpperCase() + working.substring(1);
    }

    // Chỉ báo thay đổi nếu text thực sự khác
    final normalizedRaw    = VietnameseUtils.normalize(raw.toLowerCase());
    final normalizedResult = VietnameseUtils.normalize(working.toLowerCase());
    final hasChanges = normalizedResult != normalizedRaw;

    return VoiceCorrectionResult(
      corrected: working,
      changes: hasChanges ? applied.take(3).toList() : [],
    );
  }
}
