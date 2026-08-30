import '../data/app_knowledge_base.dart';
import '../utils/vietnamese_utils.dart';

/// Kết quả truy hồi kiến thức cho một câu hỏi.
class KbRetrieval {
  /// Các mục KB khớp nhất (đã lọc theo vai trò), điểm cao trước.
  final List<KbEntry> entries;

  /// Các thuật ngữ liên quan (từ [entries] + tên thuật ngữ xuất hiện trong câu hỏi).
  final List<KbTerm> terms;

  const KbRetrieval({required this.entries, required this.terms});

  bool get isEmpty => entries.isEmpty && terms.isEmpty;
}

/// Truy hồi kiến thức tính năng — thuần Dart, chạy offline, KHÔNG gọi mạng.
///
/// Dùng cho:
///  • Trả lời "làm thế nào / ở đâu / là gì" ngay trên máy (không tốn tiền AI).
///  • Ghép context "KIẾN THỨC TÍNH NĂNG" gửi lên cloud `chatAssistant`.
class AiKnowledgeService {
  AiKnowledgeService._();
  static final AiKnowledgeService instance = AiKnowledgeService._();

  // Từ dừng — bỏ qua khi chấm điểm để tránh nhiễu.
  static const _stop = {
    'la', 'gi', 'the', 'nao', 'lam', 'sao', 'o', 'dau', 'cho', 'toi', 'minh',
    'co', 'khong', 'duoc', 'va', 'thi', 'nhu', 'moi', 'cai', 'nay', 'do', 'de',
    'muon', 'can', 'giup', 'xem', 'hoi', 'ban', 'a', 'ah', 'voi', 've', 'trong',
    'ra', 'vao', 'bi', 'hay', 'ai', 'app',
  };

  List<String> _tokens(String s) {
    final norm = VietnameseUtils.normalize(s);
    return norm
        .split(RegExp(r'[^a-z0-9]+'))
        .where((w) => w.length >= 2 && !_stop.contains(w))
        .toList();
  }

  /// Câu hỏi có vẻ là "hướng dẫn / khái niệm / vị trí" (không phải hỏi số liệu).
  bool looksLikeHowTo(String question) {
    final n = VietnameseUtils.normalize(question);
    const howToCues = [
      'lam sao', 'lam the nao', 'the nao', 'cach ', 'huong dan', 'o dau',
      'vao dau', 'nam o dau', 'cho nao', 'la gi', 'nghia la', 'khac nhau',
      'khac gi', 'khac ', 'tai sao', 'vi sao', 'dung de lam gi', 'de lam gi',
      'khi nao dung', 'co the', 'lam duoc gi', 'chuc nang', 'tinh nang',
      'bam vao dau', 'thao tac', 'quy trinh', 'cac buoc', 'giai thich',
    ];
    if (howToCues.any(n.contains)) return true;

    // "<động từ thao tác> ..." — vd "tạo đơn sửa", "chốt quỹ", "miễn nợ"
    const verbCues = [
      'tao ', 'them ', 'sua ', 'xoa ', 'in ', 'xuat ', 'nhap ', 'chot ',
      'mien ', 'thu no', 'tra no', 'kiem kho', 'sao luu', 'khoi phuc',
      'phan quyen', 'bao hanh',
    ];
    return verbCues.any(n.contains);
  }

  /// Chấm điểm một mục KB với tập token câu hỏi.
  int _score(KbEntry e, List<String> qTokens, String normQuestion) {
    if (qTokens.isEmpty) return 0;
    var score = 0;

    final titleTokens = _tokens(e.title).toSet();
    final tagTokens = <String>{
      for (final t in e.tags) ...VietnameseUtils.normalize(t).split(RegExp(r'\s+')),
    };
    final sampleNorm = e.sampleQuestions.map(VietnameseUtils.normalize).toList();
    final bodyTokens = <String>{
      ..._tokens(e.whatItDoes),
      ..._tokens(e.whenToUse),
      ..._tokens(e.menuPath),
      for (final s in e.steps) ..._tokens(s),
    };

    final matched = <String>{};
    for (final qt in qTokens) {
      var hit = false;
      if (tagTokens.contains(qt)) {
        score += 5;
        hit = true;
      }
      if (titleTokens.contains(qt)) {
        score += 4;
        hit = true;
      }
      if (bodyTokens.contains(qt)) {
        score += 1;
        hit = true;
      }
      if (hit) matched.add(qt);
    }

    // Câu hỏi mẫu gần khớp → cộng mạnh.
    var sampleStrong = false;
    for (final s in sampleNorm) {
      if (s.isEmpty) continue;
      if (normQuestion.contains(s) || s.contains(normQuestion)) {
        score += 8;
        sampleStrong = true;
        continue;
      }
      final sTokens = _tokens(s).toSet();
      if (sTokens.isEmpty) continue;
      final overlap = qTokens.where(sTokens.contains).length;
      if (overlap >= 2) {
        score += overlap * 2;
        sampleStrong = true;
      }
    }

    // Chống khớp nhầm do bỏ dấu (vd "phở bò" ~ "đồng bộ"): câu dài mà chỉ
    // trúng đúng 1 từ, không có câu mẫu nào gần khớp ⇒ coi như không liên quan.
    if (!sampleStrong && matched.length < 2 && qTokens.length >= 3) return 0;

    return score;
  }

  /// Lấy tối đa [maxEntries] mục KB liên quan nhất, lọc theo [role].
  /// [minScore] — ngưỡng điểm tối thiểu để coi là "khớp" (chống trùng do bỏ dấu).
  KbRetrieval retrieve(
    String question, {
    String? role,
    int maxEntries = 4,
    int minScore = 1,
  }) {
    final normQ = VietnameseUtils.normalize(question);
    final qTokens = _tokens(question);
    final r = (role ?? '').toLowerCase();

    bool visible(List<String> audience) {
      if (audience.contains('all')) return true;
      if (r.isEmpty) return true; // không rõ vai trò → không giấu
      if (r == 'owner' || r == 'admin' || r == 'super_admin') return true;
      return audience.contains(r);
    }

    final threshold = minScore < 1 ? 1 : minScore;
    final scored = <(KbEntry, int)>[];
    for (final e in AppKnowledgeBase.entries) {
      if (!visible(e.audience)) continue;
      final s = _score(e, qTokens, normQ);
      if (s >= threshold) scored.add((e, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    final entries = [for (final t in scored.take(maxEntries)) t.$1];

    // Thuật ngữ: từ các mục đã chọn + tên thuật ngữ xuất hiện trong câu hỏi.
    final termIds = <String>{};
    for (final e in entries) {
      termIds.addAll(e.terms);
    }
    for (final term in AppKnowledgeBase.terms) {
      final tn = VietnameseUtils.normalize(term.term)
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .trim();
      if (tn.length >= 3 && normQ.contains(tn)) termIds.add(term.id);
    }
    final terms = [
      for (final id in termIds)
        if (AppKnowledgeBase.termById(id) != null) AppKnowledgeBase.termById(id)!,
    ];

    return KbRetrieval(entries: entries, terms: terms);
  }

  /// Chuỗi context gọn để nhét vào prompt cloud. Rỗng nếu không có gì khớp.
  String buildCloudContext(String question, {String? role, int maxChars = 2600}) {
    final res = retrieve(question, role: role, maxEntries: 4, minScore: 3);
    if (res.isEmpty) return '';

    final buf = StringBuffer();
    for (final e in res.entries) {
      buf.writeln('# ${e.title}');
      buf.writeln('Vị trí: ${e.menuPath}');
      buf.writeln('Làm gì: ${e.whatItDoes}');
      if (e.whenToUse.isNotEmpty) buf.writeln('Khi nào dùng: ${e.whenToUse}');
      if (e.steps.isNotEmpty) {
        buf.writeln('Các bước:');
        for (var i = 0; i < e.steps.length; i++) {
          buf.writeln('  ${i + 1}. ${e.steps[i]}');
        }
      }
      for (final note in e.notes) {
        buf.writeln('Lưu ý: $note');
      }
      buf.writeln();
    }
    if (res.terms.isNotEmpty) {
      buf.writeln('## Thuật ngữ');
      for (final t in res.terms) {
        buf.write('- ${t.term}: ${t.definition}');
        if (t.example != null) buf.write(' Ví dụ: ${t.example}');
        buf.writeln();
      }
    }

    var out = buf.toString().trimRight();
    if (out.length > maxChars) out = '${out.substring(0, maxChars)}…';
    return out;
  }

  /// Câu trả lời "how-to" dựng hoàn toàn từ KB — dùng khi offline hoặc khi
  /// không muốn tốn lượt cloud. Trả về null nếu không đủ tự tin.
  String? offlineAnswer(String question, {String? role}) {
    if (!looksLikeHowTo(question)) return null;
    // Ngưỡng cao hơn: câu how-to phải khớp rõ ràng mới trả lời offline,
    // tránh khớp nhầm do bỏ dấu (vd "phở bò" ~ "đồng bộ").
    final res = retrieve(question, role: role, maxEntries: 2, minScore: 6);
    if (res.entries.isEmpty) {
      // Có thể chỉ là hỏi định nghĩa một thuật ngữ.
      if (res.terms.isNotEmpty) {
        final t = res.terms.first;
        return '**${t.term}**\n${t.definition}'
            '${t.example != null ? '\n\n_Ví dụ:_ ${t.example}' : ''}';
      }
      return null;
    }

    final e = res.entries.first;
    final buf = StringBuffer();
    buf.writeln('**${e.title}**');
    buf.writeln('📍 ${e.menuPath}');
    buf.writeln();
    buf.writeln(e.whatItDoes);
    if (e.steps.isNotEmpty) {
      buf.writeln();
      for (var i = 0; i < e.steps.length; i++) {
        buf.writeln('${i + 1}. ${e.steps[i]}');
      }
    }
    if (e.notes.isNotEmpty) {
      buf.writeln();
      for (final note in e.notes) {
        buf.writeln('• $note');
      }
    }
    // Chỉ kèm thuật ngữ NẾU nó thuộc chính mục này, hoặc tên thuật ngữ xuất
    // hiện trong câu hỏi — tránh dính thuật ngữ của mục phụ (kém liên quan).
    final normQ = VietnameseUtils.normalize(question);
    final relevantTerm = res.terms.where((t) {
      if (e.terms.contains(t.id)) return true;
      final tn = VietnameseUtils.normalize(t.term)
          .replaceAll(RegExp(r'\(.*?\)'), '')
          .trim();
      return tn.length >= 3 && normQ.contains(tn);
    }).toList();
    if (relevantTerm.isNotEmpty) {
      final t = relevantTerm.first;
      buf.writeln();
      buf.writeln('_${t.term}: ${t.definition}_');
    }
    return buf.toString().trimRight();
  }

  /// Danh sách id mục KB khớp (để ghi log feedback → biết sửa mục nào).
  List<String> matchedIds(String question, {String? role}) =>
      retrieve(question, role: role, maxEntries: 4)
          .entries
          .map((e) => e.id)
          .toList();
}
