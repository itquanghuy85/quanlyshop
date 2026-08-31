// Parser thông báo giao dịch ngân hàng → số tiền + chiều (ghi có / ghi nợ).
//
// Thuần tính toán, không phụ thuộc gì — dễ test. Cố gắng THẬN TRỌNG: thà trả
// `direction = 'unknown'` để người dùng tự chọn còn hơn đoán sai chiều tiền.
//
// Các mẫu thông báo NH VN rất đa dạng; parser dùng heuristic:
//  1. Chỉ nhận khi có token tiền tệ rõ ràng (có "VND"/"đ" hoặc dấu +/-).
//  2. Loại token đứng sau "SỐ DƯ" ra khỏi số tiền giao dịch (đó là số dư).
//  3. Chiều tiền: ưu tiên dấu +/- ngay trước số tiền, rồi tới từ khoá
//     "GHI CÓ"/"BÁO CÓ" vs "GHI NỢ"/"BÁO NỢ". Không rõ → 'unknown'.

class BankTxnParseResult {
  /// Số tiền giao dịch (VND, > 0).
  final int amount;

  /// 'credit' (tiền vào) | 'debit' (tiền ra) | 'unknown'.
  final String direction;

  /// Số dư sau giao dịch (VND), nếu đọc được.
  final int? balanceAfter;

  /// Nội dung chuyển khoản, nếu đọc được.
  final String? memo;

  const BankTxnParseResult({
    required this.amount,
    required this.direction,
    this.balanceAfter,
    this.memo,
  });

  bool get isCredit => direction == 'credit';
  bool get isDebit => direction == 'debit';
}

class BankNotificationParser {
  BankNotificationParser._();

  static const _from =
      'ÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ'
      'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
  static const _to =
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD'
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  static String _stripDiacritics(String s) {
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = _from.indexOf(ch);
      b.write(i >= 0 ? _to[i] : ch);
    }
    return b.toString();
  }

  /// Các thông báo KHÔNG phải biến động số dư — bỏ qua kể cả khi có số tiền.
  static final _rejectCues = <String>[
    'OTP',
    'MA XAC THUC',
    'SMART OTP',
    'DANG NHAP',
    'KICH HOAT',
    'DOI MAT KHAU',
    'UU DAI',
    'KHUYEN MAI',
    'TRI AN',
    'QUA TANG',
    'TICH DIEM',
    'DEN HAN THANH TOAN',
    'NHAC NO',
    'SAP DEN HAN',
    'SAO KE',
    'CHUONG TRINH',
    'DANG KY THANH CONG',
  ];

  static final _creditCues = <String>[
    'GHI CO',
    'BAO CO',
    '+CT',
    'NHAN TIEN',
    'NHAN CK',
    'TIEN VAO',
    'CONG TIEN',
    'CREDITED',
    'RECEIVED',
    'TK TANG',
    'PS +',
  ];

  static final _debitCues = <String>[
    'GHI NO',
    'BAO NO',
    '-CT',
    'TRU TIEN',
    'TIEN RA',
    'THANH TOAN',
    'CHUYEN TIEN DI',
    'CHUYEN KHOAN DI',
    'RUT TIEN',
    'DEBITED',
    'TK GIAM',
    'PS -',
  ];

  /// Token tiền tệ: (dấu ngoặc tuỳ chọn) + dấu tuỳ chọn + số (có . , ngăn
  /// cách) + hậu tố VND/đ/DONG. Hậu tố tiền tệ là BẮT BUỘC để tránh nhầm với
  /// ngày / số điện thoại / mã GD. Cho phép "(±X)đ" kiểu MB Bank.
  /// (chạy trên chuỗi đã bỏ dấu + IN HOA nên "đ" → "D", "VNĐ" → "VND".)
  static final _moneyRe = RegExp(
    r'[(]?\s*([+\-])?\s*([0-9]{1,3}(?:[.,][0-9]{3})+|[0-9]+)(?:[.,][0-9]{1,2})?\s*[)]?\s*(VND|DONG|D)\b',
  );

  /// Parse. Trả về `null` nếu không phải thông báo giao dịch dùng được.
  static BankTxnParseResult? parse({String? title, String? content}) {
    final raw = [title ?? '', content ?? '']
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join('\n');
    if (raw.isEmpty) return null;

    // Bỏ dấu + IN HOA + gộp khoảng trắng. "đ" → "D", "VNĐ" → "VND".
    final norm = _stripDiacritics(raw)
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ');

    // Tìm token tiền tệ.
    final matches = _moneyRe.allMatches(norm).toList();
    if (matches.isEmpty) return null;

    // Loại thông báo không phải biến động số dư (nếu không có dấu +/- rõ ràng).
    final hasSignedAmount =
        matches.any((m) => (m.group(1) ?? '').isNotEmpty);
    if (!hasSignedAmount) {
      for (final cue in _rejectCues) {
        if (norm.contains(cue)) return null;
      }
    }

    // Đuôi đoạn văn cho biết SỐ NGAY SAU là "số dư" (vd "... Số dư ", "SD: ",
    // "Số dư mới ", "Số dư khả dụng: "). "Số dư TK <số tài khoản> +X" KHÔNG
    // tính — đoạn đó kết thúc bằng số tài khoản chứ không phải nhãn số dư.
    final balanceTailRe = RegExp(
      r'(SO ?DU( (MOI|CON LAI|HIEN TAI|KHA DUNG|TK|TAI KHOAN))?|SD|BALANCE|AVAIL(ABLE)? ?BAL|CON LAI)\s*(:|=|LA)?\s*[(]?\s*$',
    );

    int? balanceAfter;
    final List<_MoneyTok> signed = [];
    final List<_MoneyTok> unsigned = [];
    var prevEnd = 0;
    for (final m in matches) {
      final start = m.start;
      final segment = norm.substring(prevEnd, start);
      prevEnd = m.end;
      final value = _parseAmount(m.group(2)!);
      if (value == null) continue;
      final sign = m.group(1) ?? '';
      final ctxBefore =
          norm.substring((start - 20).clamp(0, norm.length), start);
      final tok = _MoneyTok(
          value: value, sign: sign, start: start, ctxBefore: ctxBefore);

      if (sign.isNotEmpty) {
        signed.add(tok); // token có dấu → chắc chắn là số tiền giao dịch
      } else if (balanceTailRe.hasMatch(segment)) {
        balanceAfter ??= value;
      } else {
        unsigned.add(tok);
      }
    }

    final _MoneyTok? picked = signed.isNotEmpty
        ? signed.first
        : (unsigned.isNotEmpty ? unsigned.first : null);
    if (picked == null) return null; // chỉ có số dư

    final amount = picked.value;
    if (amount <= 0 || amount > 100000000000) return null;

    // Chiều tiền.
    final creditHit = _creditCues.any(norm.contains);
    final debitHit = _debitCues.any(norm.contains);
    String direction = 'unknown';
    if (picked.sign == '+') {
      direction = 'credit';
    } else if (picked.sign == '-') {
      direction = 'debit';
    } else if (creditHit && !debitHit) {
      direction = 'credit';
    } else if (debitHit && !creditHit) {
      direction = 'debit';
    }

    // Thông báo "số dư của bạn là X" (1 token, không dấu, không cue chiều tiền,
    // không nhắc "biến động"/"giao dịch") → chỉ là báo số dư, không phải GD.
    if (picked.sign.isEmpty &&
        matches.length == 1 &&
        direction == 'unknown' &&
        !norm.contains('BIEN DONG') &&
        !norm.contains('GIAO DICH') &&
        !norm.contains('PHAT SINH')) {
      return null;
    }

    return BankTxnParseResult(
      amount: amount,
      direction: direction,
      balanceAfter: balanceAfter,
      memo: _extractMemo(raw),
    );
  }

  /// "1.500.000" / "1,500,000" / "500000" / "1.500.000,00" → 1500000 VND.
  static int? _parseAmount(String s) {
    var t = s.trim();
    // Bỏ phần thập phân ",dd" hoặc ".dd" ở CUỐI khi có nhiều dấu ngăn cách.
    final decTail = RegExp(r'^(.+[.,]\d{3}.*)[.,]\d{1,2}$').firstMatch(t);
    if (decTail != null) t = decTail.group(1)!;
    t = t.replaceAll(RegExp(r'[.,\s]'), '');
    final v = int.tryParse(t);
    if (v == null) return null;
    return v;
  }

  static String? _extractMemo(String raw) {
    final line = raw.replaceAll('\n', ' ');
    final m = RegExp(
      r'(?:ND|NDCK|NOI DUNG|NỘI DUNG|MEMO|DESC|MO TA|MÔ TẢ|CONTENT)\s*[:\-]\s*(.{2,140})',
      caseSensitive: false,
    ).firstMatch(line);
    if (m == null) return null;
    var memo = m.group(1)!.trim();
    // Cắt tại dấu phân đoạn phổ biến để không nuốt cả phần sau.
    final cut = RegExp(r'\s(?:SO DU|SỐ DƯ|BALANCE|REF|MA GD|LUC|AT)\b',
        caseSensitive: false)
        .firstMatch(memo);
    if (cut != null) memo = memo.substring(0, cut.start).trim();
    return memo.isEmpty ? null : memo;
  }
}

class _MoneyTok {
  final int value;
  final String sign;
  final int start;
  final String ctxBefore;
  _MoneyTok({
    required this.value,
    required this.sign,
    required this.start,
    required this.ctxBefore,
  });
}
