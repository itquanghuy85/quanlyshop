import '../utils/vietnamese_utils.dart';

// ignore_for_file: constant_identifier_names

/// Industry Vocabulary Engine — Phone Repair Shop.
///
/// Handles AI query normalization:  alias expansion, slang mapping,
/// typo correction, device recognition, and intent synonym mapping.
///
/// DOES NOT duplicate VoiceCorrectionService (regex-based, voice-focused).
/// This service operates on VietnameseUtils.normalize()'d text and focuses
/// on the intent-matching pipeline inside AiChatService.
///
/// Pipeline:
///   raw user input
///     → VietnameseUtils.normalize()   (remove diacritics, lowercase)
///     → RepairVocabularyService.preprocessQuery()
///         phase 1: typo correction
///         phase 2: repair slang → canonical terms
///         phase 3: device aliases → canonical device names
///         phase 4: single-word slang (whole-word only)
///         phase 5: intent synonyms → quickAnswer keywords
///     → AiChatService._expandSynonyms()  (existing)
///     → quickAnswer() / detectAmbiguousIntent()
class RepairVocabularyService {
  RepairVocabularyService._();
  static final instance = RepairVocabularyService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. DEVICE ALIASES
  //    Normalized abbreviations / slang → canonical normalized form.
  //    Keys are already VietnameseUtils.normalize()'d (no diacritics, lowercase).
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kDeviceAliases = {
    // ── iPhone shorthands ──────────────────────────────────────────────────
    'ip': 'iphone',
    'ip7': 'iphone 7',
    'ip8': 'iphone 8',
    'ip x': 'iphone x',
    'ipx': 'iphone x',
    'ip xr': 'iphone xr',
    'ipxr': 'iphone xr',
    'ip xs': 'iphone xs',
    'ipxs': 'iphone xs',
    'ip xs max': 'iphone xs max',
    'ipxsmax': 'iphone xs max',
    'xs max': 'iphone xs max',
    'xsmax': 'iphone xs max',
    'ip se': 'iphone se',
    'ip se2': 'iphone se 2',
    'ip se3': 'iphone se 3',
    'ip11': 'iphone 11',
    'ip12': 'iphone 12',
    'ip13': 'iphone 13',
    'ip14': 'iphone 14',
    'ip15': 'iphone 15',
    'ip16': 'iphone 16',
    'ip 11': 'iphone 11',
    'ip 12': 'iphone 12',
    'ip 13': 'iphone 13',
    'ip 14': 'iphone 14',
    'ip 15': 'iphone 15',
    'ip 16': 'iphone 16',
    // ── Pro Max shorthand ──────────────────────────────────────────────────
    'prm': 'pro max',
    'promax': 'pro max',
    'prom': 'pro max',
    'pro mas': 'pro max',
    'pro mak': 'pro max',
    'pro mac': 'pro max',
    'pro macs': 'pro max',
    // ── Combined model + variant ───────────────────────────────────────────
    'ip11 pro': 'iphone 11 pro',
    'ip11 prm': 'iphone 11 pro max',
    'ip11prm': 'iphone 11 pro max',
    'ip12 mini': 'iphone 12 mini',
    'ip12 mn': 'iphone 12 mini',
    'ip12 pro': 'iphone 12 pro',
    'ip12 prm': 'iphone 12 pro max',
    'ip12prm': 'iphone 12 pro max',
    'ip13 mini': 'iphone 13 mini',
    'ip13 mn': 'iphone 13 mini',
    'ip13 pro': 'iphone 13 pro',
    'ip13 prm': 'iphone 13 pro max',
    'ip13prm': 'iphone 13 pro max',
    'ip14 plus': 'iphone 14 plus',
    'ip14 pro': 'iphone 14 pro',
    'ip14 prm': 'iphone 14 pro max',
    'ip14prm': 'iphone 14 pro max',
    'ip15 plus': 'iphone 15 plus',
    'ip15 pro': 'iphone 15 pro',
    'ip15 prm': 'iphone 15 pro max',
    'ip15prm': 'iphone 15 pro max',
    'ip16 plus': 'iphone 16 plus',
    'ip16 pro': 'iphone 16 pro',
    'ip16 prm': 'iphone 16 pro max',
    'ip16prm': 'iphone 16 pro max',
    // ── Number words → iPhone model (after normalize: muoi ba = 13) ────────
    'muoi mot': 'iphone 11',
    'muoi hai': 'iphone 12',
    'muoi ba': 'iphone 13',
    'muoi bon': 'iphone 14',
    'muoi lam': 'iphone 15',
    'muoi sau': 'iphone 16',
    'muoi bay': 'iphone 7',
    'muoi tam': 'iphone 8',
    'muoi mot prm': 'iphone 11 pro max',
    'muoi hai prm': 'iphone 12 pro max',
    'muoi ba prm': 'iphone 13 pro max',
    'muoi bon prm': 'iphone 14 pro max',
    'muoi lam prm': 'iphone 15 pro max',
    'muoi ba pro max': 'iphone 13 pro max',
    'muoi bon pro max': 'iphone 14 pro max',
    'muoi lam pro max': 'iphone 15 pro max',
    // ── Samsung shorthands ─────────────────────────────────────────────────
    'ss': 'samsung',
    'sam': 'samsung',
    'ss a12': 'samsung a12',
    'ss a13': 'samsung a13',
    'ss a14': 'samsung a14',
    'ss a15': 'samsung a15',
    'ss a32': 'samsung a32',
    'ss a52': 'samsung a52',
    'ss a53': 'samsung a53',
    'ss a54': 'samsung a54',
    'ss s22': 'samsung s22',
    'ss s23': 'samsung s23',
    'ss s24': 'samsung s24',
    'ss s22 ultra': 'samsung s22 ultra',
    'ss s23 ultra': 'samsung s23 ultra',
    'ss s24 ultra': 'samsung s24 ultra',
    'samsung a 12': 'samsung a12',
    'samsung a 13': 'samsung a13',
    'samsung a 14': 'samsung a14',
    'samsung a 15': 'samsung a15',
    'samsung a 32': 'samsung a32',
    'samsung a 52': 'samsung a52',
    'samsung a 53': 'samsung a53',
    'samsung a 54': 'samsung a54',
    'samsung s 22': 'samsung s22',
    'samsung s 23': 'samsung s23',
    'samsung s 24': 'samsung s24',
    // Number words → Samsung models
    'a muoi hai': 'samsung a12',
    'a muoi ba': 'samsung a13',
    'a muoi bon': 'samsung a14',
    'a muoi lam': 'samsung a15',
    's hai muoi hai': 'samsung s22',
    's hai muoi ba': 'samsung s23',
    's hai muoi bon': 'samsung s24',
    // ── Other brands ───────────────────────────────────────────────────────
    'rdm': 'redmi',
    'xiao': 'xiaomi',
    'opo': 'oppo',
    'op': 'oppo',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. REPAIR TERM ALIASES
  //    Slang / shorthand / misspoken → canonical normalized repair terms.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kRepairAliases = {
    // ── Face ID ────────────────────────────────────────────────────────────
    'fei': 'face id',
    'fee': 'face id',
    'fai': 'face id',
    'mat fei': 'mat face id',
    'mat fee': 'mat face id',
    'loi fei': 'loi face id',
    'fix fei': 'sua face id',
    'fix face': 'sua face id',
    'hong fei': 'hong face id',
    // ── Screen ─────────────────────────────────────────────────────────────
    'ep kieng': 'ep kinh',
    'ep keng': 'ep kinh',
    'ep man': 'ep kinh',
    'ep mat kinh': 'ep kinh',
    'thay mat kinh': 'ep kinh',
    'vo man': 'vo man hinh',
    'soc man': 'soc man hinh',
    'den man': 'den man hinh',
    'man den': 'den man hinh',
    'man trang': 'trang man hinh',
    'man bong': 'bong man hinh',
    'cam ung chet': 'liet cam ung',
    'cam ung nhan': 'cam ung nhay',
    // ── Camera ─────────────────────────────────────────────────────────────
    'cam t': 'camera truoc',
    'cam truoc': 'camera truoc',
    'cam s': 'camera sau',
    'cam sau': 'camera sau',
    'cam chinh': 'camera sau',
    'cam mo': 'camera mo',
    'kinh cam': 'kinh camera',
    // ── Speaker ────────────────────────────────────────────────────────────
    'loa t': 'loa trong',
    'loa n': 'loa ngoai',
    'loa tai': 'loa trong',
    'loa thanh': 'loa ngoai',
    'mat loa t': 'mat loa trong',
    'mat loa n': 'mat loa ngoai',
    // ── Power / Battery ────────────────────────────────────────────────────
    'mat ngon': 'mat nguon',
    'mat nguong': 'mat nguon',
    'lam nguon': 'sua nguon',
    'con nguon': 'mat nguon',
    'chet nguon': 'mat nguon',
    'hong nguon': 'mat nguon',
    'ic nguon': 'ic nguon',
    'ic sac': 'ic sac',
    'ic charge': 'ic sac',
    'pin kho': 'hao pin',
    'pin tut': 'pin yeu',
    'pin yeu': 'pin yeu',
    'hao pin': 'hao pin',
    'ap pin': 'kiem tra pin',
    'thay bat': 'thay pin',
    'thay bin': 'thay pin',
    // ── Vibration ──────────────────────────────────────────────────────────
    'con rung': 'bo rung',
    'fix rung': 'sua rung',
    'thay rung': 'thay bo rung',
    'mat rong': 'mat rung',
    // ── Connectivity ───────────────────────────────────────────────────────
    'mat net': 'mat wifi',
    'mat mang': 'mat song',
    'mat mic': 'mat micro',
    'mic hu': 'hong micro',
    // ── Mainboard / IC tech slang ──────────────────────────────────────────
    'sang main': 'kiem tra mainboard',
    'cau day': 'nhay day jumper',
    'dong ic': 'thay ic',
    'reball': 're-ball bga',
    'chap': 'ngan mach',
    'cham': 'ngan mach',
    'leak dong': 'ro dong dien',
    'chay ic': 'hong ic',
    'ic wifi': 'wifi ic',
    'ic audio': 'audio ic',
    'ic baseband': 'baseband ic',
    'ic nand': 'nand ic',
    'nan di': 'nand ic',
    // ── Housing / Back ─────────────────────────────────────────────────────
    'thay man': 'thay man hinh',
    'thay lung': 'thay kinh lung',
    'thay mat lung': 'thay kinh lung',
    'mat lung': 'mat lung',
    'kinh lung': 'kinh lung',
    'vo may': 'vo may',
    // ── General repair actions ─────────────────────────────────────────────
    'bao hanh': 'bao hanh',
    'bao gia': 'bao gia',
    'nhan may': 'tiep nhan may',
    'tra may': 'giao may cho khach',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. SLANG & GENERAL ALIASES
  //    Colloquial shorthands not specific to repair or devices.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kSlangMap = {
    'tao': 'iphone',       // "táo" = Apple brand
    'dt': 'dien thoai',
    'mobi': 'dien thoai',
    'may': 'dien thoai',
    'chet': 'hong',
    'liet': 'hong',
    'keu': 'co tieng dong',
    'fix': 'sua',
    'check': 'kiem tra',
    'rep': 'sua chua',
    'loi': 'loi nhuan',
    'von': 'gia von',
    'lai': 'loi nhuan',
    'ncc': 'nha cung cap',
    'ktv': 'ky thuat vien',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. TYPO MAP
  //    Common misspellings (normalized) → correct normalized form.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kTypoMap = {
    // iPhone
    'iphne': 'iphone',
    'ipone': 'iphone',
    'ipon': 'iphone',
    'iphon': 'iphone',
    'ifone': 'iphone',
    'aphone': 'iphone',
    'eyphone': 'iphone',
    'i phone': 'iphone',
    'i fone': 'iphone',
    // Pro Max
    'pro mas': 'pro max',
    'pro mak': 'pro max',
    'pro mac': 'pro max',
    'pro macs': 'pro max',
    'promax': 'pro max',
    // Samsung
    'samsug': 'samsung',
    'samsang': 'samsung',
    'samson': 'samsung',
    'samxung': 'samsung',
    // Issues
    'mat ngoun': 'mat nguon',
    'mat nguong': 'mat nguon',
    'mat rong': 'mat rung',
    'thay mang': 'thay man hinh',
    'thay mang hinh': 'thay man hinh',
    'ep kieng': 'ep kinh',
    'ep keng': 'ep kinh',
    // Finance
    'cong noi': 'cong no',
    'doan thu': 'doanh thu',
    'loi nhuan': 'loi nhuan',
    'gia von': 'gia von',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. PHONETIC MAP
  //    Voice recognition mishearings → correct normalized form.
  //    Complements VoiceCorrectionService (which operates on raw text).
  //    This map operates on already-normalize()'d text.
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kPhoneticMap = {
    // Number words → iPhone (already normalize()'d form)
    'muoi mot': 'iphone 11',
    'muoi hai': 'iphone 12',
    'muoi ba': 'iphone 13',
    'muoi bon': 'iphone 14',
    'muoi lam': 'iphone 15',
    'muoi sau': 'iphone 16',
    'muoi ba prm': 'iphone 13 pro max',
    'muoi bon prm': 'iphone 14 pro max',
    'muoi lam prm': 'iphone 15 pro max',
    // Samsung voice
    'a muoi hai': 'samsung a12',
    'a muoi ba': 'samsung a13',
    'a muoi bon': 'samsung a14',
    'a muoi lam': 'samsung a15',
    'es hai muoi hai': 'samsung s22',
    'es hai muoi ba': 'samsung s23',
    'es hai muoi bon': 'samsung s24',
    // Common voice mishearings (after normalize)
    'ep kieng': 'ep kinh',
    'mat fei': 'mat face id',
    'lam nguon': 'sua nguon',
    'con nguon': 'mat nguon',
    'loa noi': 'loa trong',
    'loa bao': 'loa ngoai',
    'tao don': 'tao don',      // "táo đơn" → "tạo đơn"
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. INTENT SYNONYMS
  //    Maps normalized phrases → keywords used by AiChatService.quickAnswer().
  //    Complements AiChatService._expandSynonyms().
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kIntentSynonyms = {
    // Sale
    'bill': 'hoa don ban',
    'invoice': 'hoa don ban',
    'receipt': 'hoa don ban',
    'don moi nhat': 'don ban gan nhat',
    'hoa don gan nhat': 'don ban gan nhat',
    'ban moi': 'don ban gan nhat',
    'xem ban': 'don ban gan nhat',
    'don ban moi': 'don ban gan nhat',
    // Repair
    'sua moi': 'don sua gan nhat',
    'may nhan gan nhat': 'don sua gan nhat',
    'don sua moi': 'don sua gan nhat',
    // Debt
    'no ai': 'ai no nhieu nhat',
    'ai no': 'ai no nhieu nhat',
    'khach thieu': 'thu no khach',
    'khach chua tra': 'thu no khach',
    'thieu tien': 'thu no khach',
    'no ncc': 'tra no ncc',
    'nha cung cap': 'ncc',
    'supplier': 'ncc',
    // Inventory
    'inventory': 'ton kho',
    'stock': 'ton kho',
    'hang con': 'ton kho',
    'hang trong kho': 'ton kho',
    'con hang': 'ton kho',
    'kiem hang': 'ton kho',
    // Finance
    'revenue': 'doanh thu',
    'profit': 'loi nhuan',
    'lai bao nhieu': 'loi nhuan',
    'thu bao nhieu': 'doanh thu',
    'tong hop': 'tong hop tai chinh',
    'tom tat': 'tong hop tai chinh',
    // Parts
    'linh phu': 'linh kien',
    'phu tung': 'linh kien',
    'kho linh': 'linh kien',
    // Create intents
    'nhan may moi': 'tao don sua',
    'tiep nhan may': 'tao don sua',
    'lam don sua': 'tao don sua',
    'viet don sua': 'tao don sua',
    'lam don ban': 'tao don ban',
    'tao hoa don': 'tao don ban',
    'xuat hang': 'tao don ban',
    'tinh tien': 'tao don ban',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. ISSUE KEYWORDS (for extractIssueMention)
  // ═══════════════════════════════════════════════════════════════════════════

  static const Map<String, String> kIssueKeywords = {
    // Hardware failures
    'mat nguon': 'Mất nguồn',
    'chet nguon': 'Mất nguồn',
    'khong len nguon': 'Không lên nguồn',
    'mat face id': 'Mất Face ID',
    'mat fei': 'Mất Face ID',
    'loi face id': 'Lỗi Face ID',
    'soc man hinh': 'Sọc màn hình',
    'den man hinh': 'Đen màn hình',
    'treo tao': 'Treo táo (boot loop)',
    'boot loop': 'Boot loop',
    'nong may': 'Nóng máy',
    'hao pin': 'Hao pin',
    'pin yeu': 'Pin yếu',
    'mat rung': 'Mất rung',
    'mat wifi': 'Mất WiFi',
    'mat song': 'Mất sóng',
    'mat mic': 'Mất mic',
    'mat loa': 'Mất loa',
    'mat loa trong': 'Mất loa trong',
    'mat loa ngoai': 'Mất loa ngoài',
    'vo nuoc': 'Bị nước',
    'ngam nuoc': 'Ngấm nước',
    // Services
    'ep kinh': 'Ép kính',
    'thay pin': 'Thay pin',
    'thay man hinh': 'Thay màn hình',
    'thay loa trong': 'Thay loa trong',
    'thay loa ngoai': 'Thay loa ngoài',
    'thay bo rung': 'Thay bộ rung',
    'thay camera': 'Thay camera',
    'thay kinh lung': 'Thay kính lưng',
    'thay ic sac': 'Thay IC sạc',
    'thay ic nguon': 'Thay IC nguồn',
    // Mainboard
    'sang main': 'Sàng main',
    'cau day': 'Câu dây (jumper)',
    'dong ic': 'Đóng IC',
    'reball bga': 'Reball BGA',
    'ngan mach': 'Chập mạch',
    'ro dong dien': 'Rò dòng điện',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. KNOWN DEVICE BRANDS (for detectAmbiguousIntent brand check)
  // ═══════════════════════════════════════════════════════════════════════════

  static const List<String> kBrands = [
    'iphone', 'samsung', 'xiaomi', 'redmi', 'poco',
    'oppo', 'vivo', 'realme', 'huawei', 'nokia',
    'tecno', 'infinix', 'motorola',
  ];

  // Aliases that map to a brand (shorthand → canonical brand)
  static const Map<String, String> kBrandAliases = {
    'ip': 'iphone',
    'tao': 'iphone',
    'apple': 'iphone',
    'ss': 'samsung',
    'sam': 'samsung',
    'rdm': 'redmi',
    'xiao': 'xiaomi',
    'opo': 'oppo',
    'op': 'oppo',
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Main pipeline — preprocesses a VietnameseUtils.normalize()'d query.
  /// Call AFTER VietnameseUtils.normalize() and BEFORE intent matching.
  String preprocessQuery(String normalized) {
    if (normalized.trim().isEmpty) return normalized;
    String r = normalized.trim();

    // Phase 1: Typo correction (multi-word patterns first)
    r = _applyMap(r, kTypoMap);

    // Phase 2: Phonetic normalization
    r = _applyMap(r, kPhoneticMap);

    // Phase 3: Repair slang → canonical (multi-word first)
    r = _applyMap(r, kRepairAliases);

    // Phase 4: Device aliases (multi-word first for "ip13 prm" etc.)
    r = _applyMap(r, kDeviceAliases);

    // Phase 5: Single-word slang (whole-word match only)
    r = _applySingleWordMap(r, kSlangMap);

    // Phase 6: Intent synonyms
    r = _applyMap(r, kIntentSynonyms);

    return r;
  }

  /// Returns canonical brand name if the input mentions a known device brand.
  String? extractBrand(String normalized) {
    for (final brand in kBrands) {
      if (normalized.contains(brand)) return brand;
    }
    for (final entry in kBrandAliases.entries) {
      // Whole-word check for short aliases like 'ip', 'ss', 'op'
      if (_containsWord(normalized, entry.key)) return entry.value;
    }
    return null;
  }

  /// Returns the display-name of the first repair issue mentioned, or null.
  String? extractIssue(String normalized) {
    for (final entry in kIssueKeywords.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Apply map entries sorted by key length descending (longest first).
  /// Safe for multi-word patterns — avoids short keys shadowing longer ones.
  String _applyMap(String input, Map<String, String> map) {
    if (map.isEmpty) return input;
    final sorted = map.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    String result = input;
    for (final e in sorted) {
      if (result.contains(e.key)) {
        result = result.replaceAll(e.key, e.value);
      }
    }
    return result;
  }

  /// Apply map only at word boundaries (for single-char / short keys like 'ip', 'ss').
  String _applySingleWordMap(String input, Map<String, String> map) {
    if (map.isEmpty) return input;
    final words = input.split(RegExp(r'\s+'));
    final corrected = words.map((w) => map[w] ?? w).toList();
    return corrected.join(' ');
  }

  /// Word boundary check without regex overhead.
  bool _containsWord(String text, String word) {
    final idx = text.indexOf(word);
    if (idx < 0) return false;
    final before = idx == 0 || !_isAlpha(text[idx - 1]);
    final after = idx + word.length >= text.length ||
        !_isAlpha(text[idx + word.length]);
    return before && after;
  }

  bool _isAlpha(String ch) =>
      (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122);

  // ═══════════════════════════════════════════════════════════════════════════
  // COMBINED JSON EXPORT (for documentation / debugging)
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> exportVocabularyJson() => {
        'version': '1.0',
        'description': 'Industry Vocabulary Engine — Phone Repair Shop',
        'device_aliases': kDeviceAliases,
        'repair_aliases': kRepairAliases,
        'slang_map': kSlangMap,
        'typo_map': kTypoMap,
        'phonetic_map': kPhoneticMap,
        'intent_synonyms': kIntentSynonyms,
        'issue_keywords': kIssueKeywords,
        'brands': kBrands,
        'brand_aliases': kBrandAliases,
      };
}

// ── Convenience top-level alias ─────────────────────────────────────────────

/// Shorthand: normalize a raw query and run through the full vocabulary pipeline.
String repairVocabPreprocess(String raw) {
  final normalized = VietnameseUtils.normalize(raw.toLowerCase());
  return RepairVocabularyService.instance.preprocessQuery(normalized);
}
