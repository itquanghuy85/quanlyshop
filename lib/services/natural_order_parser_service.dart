import '../utils/vietnamese_utils.dart';

enum NaturalOrderIntent { repair, sale, stock, unknown }

class ParsedRepairCommand {
  final String model;
  final String issue;
  final String? customerName;
  final String? phone;
  final int price;

  const ParsedRepairCommand({
    required this.model,
    required this.issue,
    required this.customerName,
    required this.phone,
    required this.price,
  });
}

class ParsedSaleCommand {
  final String productHint;
  final String? imei;
  final String? customerName;
  final String? phone;
  final String? paymentMethod;
  final String? financePartner;
  final int? totalPrice;

  const ParsedSaleCommand({
    required this.productHint,
    required this.imei,
    required this.customerName,
    required this.phone,
    required this.paymentMethod,
    required this.financePartner,
    required this.totalPrice,
  });
}

class ParsedStockCommand {
  final String productName;
  final int quantity;
  final int unitPrice;

  const ParsedStockCommand({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });
}

class ParsedOrderCommand {
  final NaturalOrderIntent intent;
  final ParsedRepairCommand? repair;
  final ParsedSaleCommand? sale;
  final ParsedStockCommand? stock;
  final List<String> warnings;

  const ParsedOrderCommand({
    required this.intent,
    this.repair,
    this.sale,
    this.stock,
    this.warnings = const [],
  });
}

class NaturalOrderParserService {
  NaturalOrderParserService._();

  static ParsedOrderCommand parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const ParsedOrderCommand(
        intent: NaturalOrderIntent.unknown,
        warnings: ['Lệnh trống.'],
      );
    }

    final normalized = VietnameseUtils.normalize(trimmed);

    if (_looksLikeStock(normalized)) return _parseStock(trimmed, normalized);
    if (_looksLikeSale(normalized)) return _parseSale(trimmed, normalized);
    if (_looksLikeRepair(normalized)) return _parseRepair(trimmed, normalized);

    return const ParsedOrderCommand(
      intent: NaturalOrderIntent.unknown,
      warnings: [
        'Không nhận diện được loại đơn. '
            'Bắt đầu bằng "sửa ...", "bán ...", hoặc "nhập kho ...".',
      ],
    );
  }

  // ── Intent detectors ─────────────────────────────────────────────────────

  static bool _looksLikeRepair(String n) =>
      n.startsWith('sua ') ||
      n.contains(' sua ') ||
      n.contains('nhan sua');

  static bool _looksLikeSale(String n) =>
      n.startsWith('ban ') || n.contains(' ban ');

  static bool _looksLikeStock(String n) =>
      n.contains('nhap kho') ||
      n.contains('nhap hang') ||
      n.contains('nhan hang') ||
      n.contains('them kho') ||
      n.contains('ton kho') ||
      n.contains('kho linh kien') ||
      n.contains('kho phu kien') ||
      n.contains('ton kho hien tai') ||
      n.contains('hang ton hien tai') ||
      RegExp(r'^nhap\s+\d').hasMatch(n);

  // ── Repair ───────────────────────────────────────────────────────────────

  static ParsedOrderCommand _parseRepair(String original, String normalized) {
    final phone = _extractPhone(original);
    final customerName = _extractCustomerName(original, normalized);
    final price = _extractPrice(normalized) ?? 0;
    final model = _extractRepairModel(original, normalized);
    final issue = _extractRepairIssue(original, normalized);

    final warnings = <String>[];
    if (model.isEmpty) warnings.add('Chưa tách được model máy.');
    if (issue.isEmpty) warnings.add('Chưa tách được lỗi/dịch vụ sửa chữa.');
    if ((phone == null || phone.isEmpty) &&
        (customerName == null || customerName.isEmpty)) {
      warnings.add('Thiếu thông tin khách hàng (tên hoặc số điện thoại).');
    }
    if (price == 0) {
      warnings.add('Không thấy giá trong câu lệnh, hệ thống mặc định 0đ.');
    }

    return ParsedOrderCommand(
      intent: NaturalOrderIntent.repair,
      repair: ParsedRepairCommand(
        model: model,
        issue: issue,
        customerName: customerName,
        phone: phone,
        price: price,
      ),
      warnings: warnings,
    );
  }

  // ── Sale ─────────────────────────────────────────────────────────────────

  static ParsedOrderCommand _parseSale(String original, String normalized) {
    final phone = _extractPhone(original);
    final customerName = _extractCustomerName(original, normalized);
    final imei = _extractImei(original);
    final totalPrice = _extractPrice(normalized);
    final productHint = _extractSaleProductHint(original, normalized);
    final paymentMethod = _extractSalePaymentMethod(normalized);
    final financePartner = _extractFinancePartner(normalized);

    final warnings = <String>[];
    if (productHint.isEmpty && (imei == null || imei.isEmpty)) {
      warnings.add('Thiếu thông tin sản phẩm (tên hoặc IMEI).');
    }
    if ((phone == null || phone.isEmpty) &&
        (customerName == null || customerName.isEmpty)) {
      warnings.add('Thiếu thông tin khách hàng (tên hoặc số điện thoại).');
    }

    return ParsedOrderCommand(
      intent: NaturalOrderIntent.sale,
      sale: ParsedSaleCommand(
        productHint: productHint,
        imei: imei,
        customerName: customerName,
        phone: phone,
        paymentMethod: paymentMethod,
        financePartner: financePartner,
        totalPrice: totalPrice,
      ),
      warnings: warnings,
    );
  }

  // ── Stock entry ──────────────────────────────────────────────────────────

  static ParsedOrderCommand _parseStock(String original, String normalized) {
    final productName = _extractStockProductName(original, normalized);
    final quantity = _extractStockQuantity(normalized);
    final unitPrice = _extractPrice(normalized) ?? 0;

    final warnings = <String>[];
    if (productName.isEmpty) warnings.add('Chưa tách được tên sản phẩm.');
    if (unitPrice == 0) warnings.add('Không thấy giá vốn, hệ thống mặc định 0đ.');

    return ParsedOrderCommand(
      intent: NaturalOrderIntent.stock,
      stock: ParsedStockCommand(
        productName: productName,
        quantity: quantity,
        unitPrice: unitPrice,
      ),
      warnings: warnings,
    );
  }

  static String _extractStockProductName(String original, String normalized) {
    // Find the intent keyword index
    const triggers = [
      'nhap kho',
      'nhap hang',
      'nhan hang',
      'them kho',
      'nhap',
    ];
    int kwIdx = -1;
    int kwLen = 0;
    for (final kw in triggers) {
      final idx = normalized.indexOf(kw);
      if (idx >= 0) {
        kwIdx = idx;
        kwLen = kw.length;
        break;
      }
    }
    if (kwIdx < 0) return '';

    int start = kwIdx + kwLen;
    // Skip optional leading quantity (e.g. "nhập kho 5 samsung")
    final leadNum = RegExp(r'^\s*\d+\s*').firstMatch(normalized.substring(start));
    if (leadNum != null) start += leadNum.group(0)!.length;

    // Stop before price or supplier keywords
    var end = normalized.length;
    for (final stop in [' gia ', ' gia', ' ncc ', ' nha cung cap', ' so luong']) {
      final sIdx = normalized.indexOf(stop, start);
      if (sIdx >= 0 && sIdx < end) end = sIdx;
    }

    if (start >= end || start >= original.length) return '';
    final endInOriginal = start > original.length ? original.length : end;
    return original
        .substring(start, endInOriginal.clamp(0, original.length))
        .trim()
        .toUpperCase();
  }

  static int _extractStockQuantity(String normalized) {
    // "X cai", "X chiec", "X may", "X bo", etc.
    for (final unit in ['cai', 'chiec', 'may', 'bo', 'hop', 'loc', 'cay']) {
      final m = RegExp(r'(\d+)\s*' + unit).firstMatch(normalized);
      if (m != null) return int.tryParse(m.group(1) ?? '1') ?? 1;
    }
    // "nhập kho N" or "nhập N"
    final m = RegExp(
      r'(?:nhap kho|nhap hang|nhan hang|nhap)\s+(\d+)\s',
    ).firstMatch(normalized);
    if (m != null) return int.tryParse(m.group(1) ?? '1') ?? 1;
    return 1;
  }

  // ── Shared extractors ────────────────────────────────────────────────────

  static String? _extractPhone(String input) {
    final m = RegExp(r'(?<!\d)(0\d{8,10})(?!\d)').firstMatch(input);
    return m?.group(1);
  }

  static String? _extractImei(String input) {
    final m = RegExp(
      r'imei\s*[:\-]?\s*([a-zA-Z0-9\-]{4,25})',
      caseSensitive: false,
    ).firstMatch(input);
    return m?.group(1)?.trim().toUpperCase();
  }

  static String? _extractCustomerName(String original, String normalized) {
    // Priority: "tên [name]" marker is more precise than "khách"
    int start = -1;
    for (final marker in ['ten ', 'khach ten ', 'khach ']) {
      final idx = normalized.indexOf(marker);
      if (idx >= 0) {
        start = idx + marker.length;
        break;
      }
    }
    if (start < 0) return null;

    // Stop before phone/price markers
    var end = normalized.length;
    for (final stop in [
      ' so dien thoai', ' sdt', ' so dt', ' phone',
      ' imei', ' tra gop', ' gia ', ' thu ', ' loi ',
    ]) {
      final stopIdx = normalized.indexOf(stop, start);
      if (stopIdx >= 0 && stopIdx < end) end = stopIdx;
    }
    // Stop before a 10-digit phone number
    final phoneMatch = RegExp(r'0\d{9,10}').firstMatch(normalized.substring(start));
    if (phoneMatch != null) {
      final absPos = start + phoneMatch.start;
      if (absPos < end) end = absPos;
    }

    if (start >= end || start >= original.length) return null;
    final slice = original
        .substring(start, end.clamp(0, original.length))
        .trim();
    if (slice.isEmpty) return null;

    final cleaned = slice
        .replaceAll(RegExp(r'[^A-Za-zÀ-ỹà-ỹ\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned.toUpperCase();
  }

  static final _kBrandPattern = RegExp(
    r'\b(iPhone|Samsung|Galaxy|Oppo|Xiaomi|Vivo|Realme|Nokia|Redmi|POCO|Huawei|Tecno|Infinix|Motorola)\b',
    caseSensitive: false,
  );

  static String _extractRepairModel(String original, String normalized) {
    // 1. Brand-first: find brand name and read ahead for the model
    final brandMatch = _kBrandPattern.firstMatch(original);
    if (brandMatch != null) {
      final brandStart = brandMatch.start;
      var end = original.length;
      // Stop before customer / price / issue markers
      for (final stop in [
        ' khách', ' khach', ' tên', ' ten ', ' số điện thoại',
        ' so dien thoai', ' giá', ' gia ', ' lỗi', ' loi ', ' thu ',
      ]) {
        final idx = original.toLowerCase().indexOf(stop, brandStart + 1);
        if (idx >= 0 && idx < end) end = idx;
      }
      // Also stop before a 10-digit phone number
      final phoneM = RegExp(r'0\d{9,10}').firstMatch(original.substring(brandStart));
      if (phoneM != null) {
        final abs = brandStart + phoneM.start;
        if (abs < end) end = abs;
      }
      final model = original.substring(brandStart, end).trim();
      if (model.isNotEmpty) return model.toUpperCase();
    }

    // 2. Fallback: slice after "sửa/sua" until customer/price marker
    final idx = normalized.indexOf('sua');
    if (idx < 0) return '';
    final start = idx + 3;
    var end = normalized.length;
    for (final stop in [' khach', ' ten ', ' sdt', ' gia ', ' gia', ' imei']) {
      final stopIdx = normalized.indexOf(stop, start);
      if (stopIdx >= 0 && stopIdx < end) end = stopIdx;
    }
    if (start >= end || start >= original.length) return '';
    return original.substring(start, end.clamp(0, original.length)).trim().toUpperCase();
  }

  static String _extractRepairIssue(String original, String normalized) {
    const candidates = ['thay ', 'ep ', 'sua loi ', 'sua'];
    int issueStart = -1;
    for (final key in candidates) {
      final idx = normalized.indexOf(key);
      if (idx >= 0) {
        issueStart = idx;
        break;
      }
    }
    if (issueStart < 0) return '';

    var end = normalized.length;
    for (final stop in [' khach ', ' sdt', ' gia ', ' gia', ' imei ']) {
      final stopIdx = normalized.indexOf(stop, issueStart + 1);
      if (stopIdx >= 0 && stopIdx < end) end = stopIdx;
    }

    if (issueStart >= end || issueStart >= original.length) return '';
    return original.substring(issueStart, end).trim().toUpperCase();
  }

  static String _extractSaleProductHint(String original, String normalized) {
    final idx = normalized.indexOf('ban');
    if (idx < 0) return '';

    final start = idx + 3;
    var end = normalized.length;
    for (final stop in [' imei', ' khach ', ' sdt', ' tra gop', ' gia ']) {
      final stopIdx = normalized.indexOf(stop, start);
      if (stopIdx >= 0 && stopIdx < end) end = stopIdx;
    }

    if (start >= end || start >= original.length) return '';
    return original.substring(start, end).trim().toUpperCase();
  }

  static int? _extractPrice(String normalized) {
    // "1tr2" → 1,200,000
    final compactMillion = RegExp(r'(\d+)\s*tr\s*(\d{1,3})');
    final cm = compactMillion.firstMatch(normalized);
    if (cm != null) {
      final million = int.tryParse(cm.group(1) ?? '0') ?? 0;
      final tailRaw = cm.group(2) ?? '0';
      final tail = int.tryParse(tailRaw) ?? 0;
      final tailValue = tailRaw.length <= 2 ? tail * 100000 : tail * 1000;
      return (million * 1000000) + tailValue;
    }

    // "1.5 triệu"
    final million = RegExp(r'(\d+(?:[\.,]\d+)?)\s*(tr|trieu|triệu)');
    final mm = million.firstMatch(normalized);
    if (mm != null) {
      final n = double.tryParse(
              (mm.group(1) ?? '0').replaceAll(',', '.')) ??
          0;
      return (n * 1000000).round();
    }

    // "500k"
    final thousand = RegExp(r'(\d+(?:[\.,]\d+)?)\s*(k|nghin|nghìn)');
    final tm = thousand.firstMatch(normalized);
    if (tm != null) {
      final n = double.tryParse(
              (tm.group(1) ?? '0').replaceAll(',', '.')) ??
          0;
      return (n * 1000).round();
    }

    // "1.000.000"
    final fullAmount = RegExp(r'\b\d{1,3}(?:[\.,]\d{3}){1,3}\b')
        .firstMatch(normalized);
    if (fullAmount != null) {
      final raw = (fullAmount.group(0) ?? '').replaceAll(RegExp(r'[\.,]'), '');
      final n = int.tryParse(raw);
      if (n != null && n > 0) return n;
    }

    return null;
  }

  static String? _extractSalePaymentMethod(String normalized) {
    if (normalized.contains('tra gop')) return 'TRẢ GÓP (NH)';
    if (normalized.contains('cong no')) return 'CÔNG NỢ';
    if (normalized.contains('ket hop')) return 'KẾT HỢP';
    if (normalized.contains('chuyen khoan')) return 'CHUYỂN KHOẢN';
    if (normalized.contains('tien mat')) return 'TIỀN MẶT';
    return null;
  }

  static String? _extractFinancePartner(String normalized) {
    for (final p in ['fe', 'home', 'mirae', 'hd', 'mb', 'f83', 't86']) {
      if (RegExp('\\b$p\\b').hasMatch(normalized)) return p.toUpperCase();
    }
    return null;
  }
}
