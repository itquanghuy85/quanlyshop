import '../utils/vietnamese_utils.dart';

/// Result of a voice correction pass.
class VoiceCorrectionResult {
  final String corrected;
  final List<String> changes; // human-readable list of applied fixes
  const VoiceCorrectionResult({required this.corrected, this.changes = const []});
  bool get hasChanges => changes.isNotEmpty;
}

/// Post-processes raw STT text to fix domain-specific mis-recognitions.
///
/// Strategy:
///   1. Normalize input (strip diacritics, lowercase) → apply regex rules.
///   2. Rules are written in normalized form; replacements are correct Vietnamese.
///   3. Return corrected string + list of changes for UI feedback.
class VoiceCorrectionService {
  VoiceCorrectionService._();

  // ── Rules ─────────────────────────────────────────────────────────────────
  // Pattern matches NORMALIZED text (no diacritics, lowercase).
  // Replacement is the correct display term (with diacritics where needed).
  static final _kRules = <(RegExp, String)>[

    // ── Phone brands ─────────────────────────────────────────────────────────
    (RegExp(r'\bai\s*phon\w*'),           'iPhone'),
    (RegExp(r'\bi\s*phon\w*'),            'iPhone'),
    (RegExp(r'\bip\s*hon\w*'),            'iPhone'),
    (RegExp(r'sam\s*s[ui]ng'),            'Samsung'),
    (RegExp(r'sang\s*sung'),              'Samsung'),
    (RegExp(r'sam\s*xung'),               'Samsung'),
    (RegExp(r'xam\s*sung'),               'Samsung'),
    (RegExp(r'\bxi\s*ao\s*mi\b'),         'Xiaomi'),
    (RegExp(r'\bxiao\s*mi\b'),            'Xiaomi'),
    (RegExp(r'\bsiao\s*mi\b'),            'Xiaomi'),
    (RegExp(r'\bxao\s*mi\b'),             'Xiaomi'),
    (RegExp(r'\bxa\s*mi\b'),              'Xiaomi'),
    (RegExp(r'\bshi\s*a\s*mi\b'),         'Xiaomi'),
    (RegExp(r'\bop\s*po\b'),              'Oppo'),
    (RegExp(r'\bo\s*po\b'),               'Oppo'),
    (RegExp(r'\bvi\s*v[o0]\b'),           'Vivo'),
    (RegExp(r'\bvi\s*b[o0]\b'),           'Vivo'),
    (RegExp(r'\bhua\s*w?ei\b'),           'Huawei'),
    (RegExp(r'\bhua\s*uei\b'),            'Huawei'),
    (RegExp(r'\bre\s*al\s*me\b'),         'Realme'),
    (RegExp(r'\bri\s*[oa]n\s*mi\b'),      'Realme'),
    (RegExp(r'\bnokia\b'),                'Nokia'),
    (RegExp(r'\btek\s*no\b'),             'Tecno'),
    (RegExp(r'\bmo\s*to\s*ro\s*la\b'),    'Motorola'),
    (RegExp(r'\binfinix\b'),              'Infinix'),

    // ── Screen / LCD ─────────────────────────────────────────────────────────
    (RegExp(r'thay\s*m[ao][nm]g\b'),      'thay màn hình'),
    (RegExp(r'thay\s*bang\b'),            'thay màn hình'),
    (RegExp(r'thay\s*man\s*h[iy]?nh'),    'thay màn hình'),
    (RegExp(r'\bman\s*h[iy]?nh\b'),       'màn hình'),
    (RegExp(r'\blcd\b'),                  'màn hình LCD'),
    (RegExp(r'\boled\b'),                 'màn hình OLED'),

    // ── Main board / chip ────────────────────────────────────────────────────
    (RegExp(r'\bsua\s*ma[yi]?n\b'),       'sửa main'),
    (RegExp(r'\bsua\s*me[yi]?n\b'),       'sửa main'),
    (RegExp(r'\bthay\s*ma[yi]?n\b'),      'thay main'),
    (RegExp(r'\bsua\s*ic\b'),             'sửa IC'),
    (RegExp(r'\bthay\s*ic\b'),            'thay IC'),

    // ── Battery ──────────────────────────────────────────────────────────────
    (RegExp(r'\bthay\s*pi[nm]\b'),        'thay pin'),
    (RegExp(r'\bnap\s*pi[nm]\b'),         'nạp pin'),
    (RegExp(r'\bthay\s*bat\b'),           'thay pin'),
    (RegExp(r'\bpin\b'),                  'pin'),

    // ── Glass / screen protector ─────────────────────────────────────────────
    (RegExp(r'\bthay\s*ki[nm]h?\b'),      'thay kính'),
    (RegExp(r'\bthay\s*ki[nm]g\b'),       'thay kính'),
    (RegExp(r'\bdan\s*ki[nm]h?\b'),       'dán kính'),
    (RegExp(r'\bdan\s*man\b'),            'dán màn'),
    (RegExp(r'\bmieng\s*dan\b'),          'miếng dán'),

    // ── Charging port / jack ─────────────────────────────────────────────────
    (RegExp(r'\bthay\s*jack\b'),          'thay jack'),
    (RegExp(r'\bthay\s*rac\b'),           'thay jack'),
    (RegExp(r'\bthay\s*cong\s*sac\b'),    'thay cổng sạc'),
    (RegExp(r'\bcong\s*sac\b'),           'cổng sạc'),
    (RegExp(r'\bsua\s*sac\b'),            'sửa sạc'),
    (RegExp(r'\bthay\s*sac\b'),           'thay sạc'),
    (RegExp(r'\bday\s*sac\b'),            'dây sạc'),

    // ── Back cover / housing ─────────────────────────────────────────────────
    (RegExp(r'\bthay\s*vo\b'),            'thay vỏ'),
    (RegExp(r'\bthay\s*mat\s*lung\b'),    'thay mặt lưng'),
    (RegExp(r'\bthay\s*nap\s*lung\b'),    'thay nắp lưng'),
    (RegExp(r'\bmat\s*lung\b'),           'mặt lưng'),
    (RegExp(r'\bnap\s*lung\b'),           'nắp lưng'),

    // ── Touch / camera / speaker / mic ───────────────────────────────────────
    (RegExp(r'\bcam\s*ung\b'),            'cảm ứng'),
    (RegExp(r'\bsua\s*cam\s*ung\b'),      'sửa cảm ứng'),
    (RegExp(r'\bsua\s*loa\b'),            'sửa loa'),
    (RegExp(r'\bthay\s*loa\b'),           'thay loa'),
    (RegExp(r'\bsua\s*mic\b'),            'sửa mic'),
    (RegExp(r'\bthay\s*cam\b'),           'thay camera'),
    (RegExp(r'\bsua\s*cam\b'),            'sửa camera'),
    (RegExp(r'\bcamera\s*truoc\b'),       'camera trước'),
    (RegExp(r'\bcamera\s*sau\b'),         'camera sau'),

    // ── Power / WiFi / Bluetooth ─────────────────────────────────────────────
    (RegExp(r'\bsua\s*nguon\b'),          'sửa nguồn'),
    (RegExp(r'\bsua\s*wifi\b'),           'sửa WiFi'),
    (RegExp(r'\bsua\s*blue\s*tooth\b'),   'sửa Bluetooth'),
    (RegExp(r'\bkhong\s*len\s*nguon\b'),  'không lên nguồn'),
    (RegExp(r'\bmat\s*nguon\b'),          'mất nguồn'),

    // ── Other repair ─────────────────────────────────────────────────────────
    (RegExp(r'\bnhan\s*may\b'),           'nhận máy'),
    (RegExp(r'\bsua\s*may\b'),            'sửa máy'),
    (RegExp(r'\bsua\s*chua\b'),           'sửa chữa'),
    (RegExp(r'\btreo\s*tao\b'),           'treo táo'),    // iPhone boot loop
    (RegExp(r'\bmat\s*hang\b'),           'mất hàng'),
    (RegExp(r'\bgiam\s*gia\b'),           'giảm giá'),
    (RegExp(r'\bbao\s*hanh\b'),           'bảo hành'),

    // ── App commands ─────────────────────────────────────────────────────────
    (RegExp(r'\btao\s*don\s*sua\b'),      'tạo đơn sửa'),
    (RegExp(r'\btao\s*don\s*ban\b'),      'tạo đơn bán'),
    (RegExp(r'\bnhap\s*kho\b'),           'nhập kho'),
    (RegExp(r'\bnhap\s*hang\b'),          'nhập hàng'),
    (RegExp(r'\bnhan\s*hang\b'),          'nhận hàng'),
    (RegExp(r'\bkiem\s*kho\b'),           'kiểm kho'),
    (RegExp(r'\bton\s*kho\b'),            'tồn kho'),
    (RegExp(r'\bhan\s*ton\b'),            'hàng tồn'),
    (RegExp(r'\bcong\s*no\b'),            'công nợ'),
    (RegExp(r'\bxem\s*no\b'),             'xem nợ'),
    (RegExp(r'\bcham\s*cong\b'),          'chấm công'),
    (RegExp(r'\btai\s*chinh\b'),          'tài chính'),
    (RegExp(r'\bbao\s*cao\b'),            'báo cáo'),
    (RegExp(r'\bdoanh\s*thu\b'),          'doanh thu'),
    (RegExp(r'\bthu\s*chi\b'),            'thu chi'),
    (RegExp(r'\btim\s*khach\b'),          'tìm khách'),
    (RegExp(r'\bkhach\s*hang\b'),         'khách hàng'),
    (RegExp(r'\bban\s*hang\b'),           'bán hàng'),
    (RegExp(r'\bban\s*may\b'),            'bán máy'),
    (RegExp(r'\bxuat\s*hang\b'),          'xuất hàng'),
    (RegExp(r'\bdon\s*cho\b'),            'đơn chờ'),
    (RegExp(r'\bdon\s*sua\b'),            'đơn sửa'),
    (RegExp(r'\bdon\s*ban\b'),            'đơn bán'),
  ];

  /// Correct [raw] STT text using domain-specific vocabulary rules.
  static VoiceCorrectionResult correct(String raw) {
    if (raw.trim().isEmpty) {
      return const VoiceCorrectionResult(corrected: '');
    }

    // Work on normalized (diacritics-stripped, lowercase) version
    String working = VietnameseUtils.normalize(raw.toLowerCase());
    final applied = <String>{};

    for (final (pattern, replacement) in _kRules) {
      if (pattern.hasMatch(working)) {
        working = working.replaceAll(pattern, replacement);
        applied.add(replacement);
      }
    }

    // Capitalize first letter
    if (working.isNotEmpty) {
      working = working[0].toUpperCase() + working.substring(1);
    }

    // Only report changes if the corrected text actually differs from normalized raw
    final normalizedRaw = VietnameseUtils.normalize(raw.toLowerCase());
    final normalizedResult = VietnameseUtils.normalize(working.toLowerCase());
    final hasChanges = normalizedResult != normalizedRaw;

    return VoiceCorrectionResult(
      corrected: working,
      changes: hasChanges ? applied.take(3).toList() : [],
    );
  }
}
