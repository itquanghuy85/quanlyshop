/// APP KNOWLEDGE BASE — nguồn sự thật DUY NHẤT cho:
///   1. AI Trợ Lý (offline how-to + context gửi lên cloud `chatAssistant`)
///   2. Trung tâm trợ giúp (Help Center) — xem `HelpCenterRepository.topics`
///
/// Mỗi lần THÊM / ĐỔI tính năng ⇒ cập nhật file này (CLAUDE.md mục VII).
/// Giữ nội dung NGẮN — AI đọc trực tiếp, prompt có giới hạn token.
///
/// Vai trò (audience): 'all' | 'owner' | 'manager' | 'technician' | 'cashier'
library;

import 'dart:math';

/// Một mục kiến thức = một tính năng / màn hình.
class KbEntry {
  final String id;

  /// Tên hiển thị, vd "Chốt quỹ / Sổ quỹ".
  final String title;

  /// Đường dẫn menu, vd "Trang chủ → Tài chính → Sổ quỹ".
  final String menuPath;

  /// Tính năng này LÀM GÌ (1–3 câu).
  final String whatItDoes;

  /// KHI NÀO dùng (1–2 câu).
  final String whenToUse;

  /// Các bước thao tác (đã sắp thứ tự).
  final List<String> steps;

  /// Lưu ý / mẹo / cạm bẫy hay gặp.
  final List<String> notes;

  /// id các thuật ngữ liên quan (xem [AppKnowledgeBase.terms]).
  final List<String> terms;

  /// Câu hỏi mẫu người dùng hay hỏi — cũng dùng để so khớp truy hồi.
  final List<String> sampleQuestions;

  /// Từ khoá không dấu / có dấu để so khớp truy hồi.
  final List<String> tags;

  /// Vai trò nên thấy mục này. 'all' = mọi vai trò.
  final List<String> audience;

  const KbEntry({
    required this.id,
    required this.title,
    required this.menuPath,
    required this.whatItDoes,
    required this.whenToUse,
    this.steps = const [],
    this.notes = const [],
    this.terms = const [],
    this.sampleQuestions = const [],
    this.tags = const [],
    this.audience = const ['all'],
  });
}

/// Một thuật ngữ + định nghĩa CHUẨN của app (tránh AI hiểu sai).
class KbTerm {
  final String id;
  final String term;
  final String definition;
  final String? example;

  const KbTerm({
    required this.id,
    required this.term,
    required this.definition,
    this.example,
  });
}

class AppKnowledgeBase {
  AppKnowledgeBase._();

  /// Bản tóm tắt cực ngắn về app — ghim vào system prompt.
  static const appOverview =
      'HULUCA Shop Manager (Quản Lý Shop): phần mềm quản lý cửa hàng sửa chữa & '
      'bán điện thoại. Có: đơn sửa, bán hàng, kho, công nợ, tài chính/sổ quỹ, '
      'khách hàng, nhân viên/lương, báo cáo, đồng bộ đa thiết bị, thông báo. '
      'Offline-first: dùng được khi mất mạng, có mạng thì tự đồng bộ.';

  // ─── THUẬT NGỮ ────────────────────────────────────────────────────────────
  static const List<KbTerm> terms = [
    KbTerm(
      id: 'dong-tien',
      term: 'Dòng tiền (cash)',
      definition:
          'Tiền THỰC SỰ đã vào/ra két và tài khoản ngân hàng. Khách còn nợ thì '
          'chưa tính vào dòng tiền.',
      example: 'Bán 10tr nhưng khách nợ 4tr → dòng tiền chỉ +6tr.',
    ),
    KbTerm(
      id: 'don-tich',
      term: 'Dồn tích (accrual)',
      definition:
          'Ghi nhận doanh thu và lãi ngay khi bán/giao, dù chưa thu đủ tiền. '
          'Báo cáo lãi/lỗ dùng cách này.',
      example: 'Bán 10tr công nợ → doanh thu +10tr, lãi tính đủ, tiền chưa về.',
    ),
    KbTerm(
      id: 'chot-quy',
      term: 'Chốt quỹ',
      definition:
          'Cuối ngày đếm tiền mặt + số dư ngân hàng thực tế rồi nhập vào app. '
          'App so với kỳ vọng: Kỳ vọng = Đầu kỳ + Thu trong ngày − Chi trong ngày.',
      example:
          'Đầu kỳ 2tr, thu 5tr, chi 1tr → kỳ vọng 6tr. Đếm thực 5,9tr → lệch −100k.',
    ),
    KbTerm(
      id: 'lech-quy',
      term: 'Lệch quỹ',
      definition:
          'Chênh lệch giữa tiền đếm thực tế và số kỳ vọng khi chốt quỹ. Lệch '
          'dương = thừa, âm = thiếu — cần tìm nguyên nhân (quên ghi thu/chi, nhầm tiền).',
    ),
    KbTerm(
      id: 'gia-von',
      term: 'Giá vốn',
      definition:
          'Số tiền shop bỏ ra để có món hàng / linh kiện (giá nhập). '
          'Lãi = Giá bán − Giá vốn.',
    ),
    KbTerm(
      id: 'lai-gop',
      term: 'Lãi gộp',
      definition:
          'Giá bán − Giá vốn, chưa trừ chi phí vận hành (mặt bằng, điện, lương…).',
    ),
    KbTerm(
      id: 'cong-no-phai-thu',
      term: 'Công nợ phải thu',
      definition: 'Khách đang nợ tiền shop. Tự sinh khi bán/sửa chọn "CÔNG NỢ".',
    ),
    KbTerm(
      id: 'cong-no-phai-tra',
      term: 'Công nợ phải trả',
      definition:
          'Shop đang nợ nhà cung cấp hoặc đối tác sửa chữa. Tự sinh khi nhập '
          'kho / dùng dịch vụ đối tác mà chọn "CÔNG NỢ".',
    ),
    KbTerm(
      id: 'tra-gop-nh',
      term: 'Trả góp (ngân hàng)',
      definition:
          'Khách đưa tiền CỌC, phần còn lại ngân hàng (FE, Home Credit, HD…) cho '
          'vay. Chỉ tiền cọc là tiền shop thu ngay; tiền NH ghi nhận khi ngân '
          'hàng tất toán (giải ngân) cho shop.',
    ),
    KbTerm(
      id: 'tat-toan',
      term: 'Tất toán (trả góp)',
      definition:
          'Ngân hàng chuyển nốt phần vay cho shop. Lúc này mới ghi nhận đủ doanh '
          'thu và giá vốn phần còn lại của đơn trả góp.',
    ),
    KbTerm(
      id: 'coc',
      term: 'Cọc / Trả trước',
      definition:
          'Tiền khách đưa trước một phần. Phần còn lại thành công nợ phải thu '
          '(hoặc do ngân hàng cho vay nếu là trả góp).',
    ),
    KbTerm(
      id: 'ton-kho-gia-von',
      term: 'Tồn kho (giá vốn)',
      definition:
          'Tổng giá vốn của hàng còn trong kho — "tiền đang nằm ở hàng hoá".',
    ),
    KbTerm(
      id: 'mat-hang-vs-ton',
      term: '"Mặt hàng" vs "Sản phẩm tồn"',
      definition:
          '"Mặt hàng" = số bản ghi sản phẩm còn hàng. "Sản phẩm tồn" = tổng số '
          'lượng. Không cộng gộp hai con số này.',
    ),
    KbTerm(
      id: 'bien-the',
      term: 'Biến thể sản phẩm',
      definition:
          'Cùng model nhưng khác dung lượng / màu / tình trạng (mới, cũ) — mỗi '
          'biến thể có tồn kho và giá riêng.',
    ),
    KbTerm(
      id: 'nhap-tam',
      term: 'Nhập tạm / Hàng chờ xác nhận',
      definition:
          'Phiếu nhập kho đã tạo nháp nhưng CHƯA cộng vào tồn. Phải "Xác nhận" '
          'thì hàng mới vào kho và (nếu chọn CÔNG NỢ) mới sinh nợ NCC.',
    ),
    KbTerm(
      id: 'trang-thai-don-sua',
      term: 'Trạng thái đơn sửa',
      definition:
          '1 Mới nhận → 2 Đang sửa → 3 Xong chờ lấy → 4 Đã giao. Doanh thu sửa '
          'chỉ tính khi đơn "Đã giao".',
    ),
    KbTerm(
      id: 'gia-von-don-sua',
      term: 'Giá vốn đơn sửa: "chưa ghi nhận" vs "không tốn"',
      definition:
          '0đ có 2 nghĩa: (a) CHƯA nhập giá vốn (cần xử lý) — hiện chữ cam "Chưa '
          'ghi nhận giá vốn"; (b) đơn thật sự KHÔNG dùng linh kiện — tích ô "Đơn '
          'này KHÔNG tốn giá vốn (0đ)", hiện chữ xám "Không tốn giá vốn (0đ)".',
    ),
    KbTerm(
      id: 'soft-delete',
      term: 'Xoá mềm (soft delete)',
      definition:
          'App không xoá hẳn — chỉ đánh dấu "deleted" và ẩn đi, để đồng bộ đúng '
          'giữa các máy và còn dấu vết đối soát.',
    ),
    KbTerm(
      id: 'dong-bo',
      term: 'Đồng bộ đa thiết bị',
      definition:
          'Mọi máy đăng nhập cùng shop chia sẻ dữ liệu realtime qua Firebase. '
          'Mất mạng vẫn dùng được; có mạng lại sẽ tự đẩy/kéo thay đổi.',
    ),
    KbTerm(
      id: 'vai-tro',
      term: 'Vai trò (phân quyền)',
      definition:
          'Chủ shop (owner): toàn quyền. Quản lý (manager): gần như toàn quyền, '
          'thấy tài chính. Kỹ thuật viên (technician): đơn sửa, kho. Nhân viên '
          'bán (cashier): bán hàng, khách. Chỉ owner/manager thấy số liệu tài chính.',
    ),
    KbTerm(
      id: 'shop-id',
      term: 'shopId (nhiều cửa hàng)',
      definition:
          'Mỗi cửa hàng có mã riêng. Dữ liệu tách theo shopId — máy chỉ thấy dữ '
          'liệu của shop mình đăng nhập.',
    ),
    KbTerm(
      id: 'nguon-khoan-no',
      term: 'Nguồn khoản nợ',
      definition:
          'Nợ tự sinh từ đâu: bán CÔNG NỢ, nhập kho CÔNG NỢ, bổ sung giá vốn, '
          'nhập linh kiện, dịch vụ đối tác sửa, hoặc tạo tay. Nợ nhập kho không '
          'tách thành "đơn" riêng nên bấm "xem đơn gốc" sẽ hiện bảng Nguồn khoản nợ.',
    ),
    KbTerm(
      id: 'mien-no',
      term: 'Miễn nợ (xoá nợ khó đòi)',
      definition:
          'Xoá phần còn nợ của một khoản mà shop chấp nhận không đòi nữa. Bắt '
          'buộc nhập lý do. Làm trong Công cụ điều chỉnh dữ liệu → tab CÔNG NỢ.',
    ),
    KbTerm(
      id: 'gia-tham-khao',
      term: 'Giá tham khảo',
      definition:
          'Giá vốn / giá bán gợi ý theo trung vị lịch sử nhập cùng model. Chỉ để '
          'THAM KHẢO, không tự điền — có nút "DÙNG GIÁ BÁN".',
    ),
  ];

  static KbTerm? termById(String id) {
    for (final t in terms) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ─── MỤC KIẾN THỨC ────────────────────────────────────────────────────────
  static const List<KbEntry> entries = [
    // ===== ĐƠN SỬA CHỮA =====
    KbEntry(
      id: 'repair-create',
      title: 'Tạo đơn sửa chữa',
      menuPath: 'Trang chủ → Sửa chữa → nút +  (hoặc "Nhập nhanh" bằng giọng nói)',
      whatItDoes:
          'Tiếp nhận một máy khách mang đến sửa: ghi khách, máy, lỗi, tình '
          'trạng máy, phụ kiện kèm theo, giá dự kiến.',
      whenToUse: 'Ngay khi khách mang máy đến, trước khi bắt đầu sửa.',
      steps: [
        'Bấm + ở màn Sửa chữa.',
        'Nhập tên + SĐT khách (app tự gợi ý nếu khách cũ).',
        'Chọn hãng / model máy, nhập lỗi khách báo.',
        'Mở "Thêm chi tiết" để ghi mật khẩu máy, ngoại quan, phụ kiện kèm theo.',
        'Nhập giá dự kiến (có thể sửa sau), lưu đơn.',
      ],
      notes: [
        'Đơn mới ở trạng thái "Mới nhận". Cập nhật trạng thái khi bắt đầu sửa / xong / giao.',
        'In phiếu tiếp nhận đưa khách để đối chiếu khi lấy máy.',
      ],
      terms: ['trang-thai-don-sua'],
      sampleQuestions: [
        'làm sao tạo đơn sửa',
        'nhận máy khách vào đâu',
        'tiếp nhận sửa chữa như thế nào',
      ],
      tags: [
        'don sua', 'tao don sua', 'nhan may', 'tiep nhan', 'sua chua', 'repair'
      ],
      audience: ['all'],
    ),
    KbEntry(
      id: 'repair-status',
      title: 'Cập nhật trạng thái & giao máy',
      menuPath: 'Trang chủ → Sửa chữa → mở đơn',
      whatItDoes:
          'Đổi trạng thái đơn theo tiến độ và bàn giao máy cho khách kèm thu tiền.',
      whenToUse:
          'Khi bắt đầu sửa, sửa xong, và khi khách đến lấy máy trả tiền.',
      steps: [
        'Mở đơn cần cập nhật.',
        'Bấm đổi trạng thái: Đang sửa → Xong chờ lấy.',
        'Khi khách lấy: bấm "Giao máy", chọn hình thức thanh toán (tiền mặt / '
            'chuyển khoản / công nợ), xác nhận.',
        'App ghi doanh thu sửa vào ngày giao.',
      ],
      notes: [
        'Doanh thu sửa chỉ tính khi đơn "Đã giao".',
        'Nhân viên giao có thể cần quản lý duyệt giá nếu lệch giá dự kiến.',
        'Đơn ĐÃ GIAO vẫn bổ sung / chỉnh sửa được: thêm linh kiện, đổi / xoá '
            'phụ tùng, "Sửa KTV" (đổi người sửa → tính lại hoa hồng), ghi chú KTV, '
            'sửa giá vốn — mọi thay đổi đều ghi nhật ký.',
      ],
      terms: ['trang-thai-don-sua', 'dong-tien'],
      sampleQuestions: [
        'giao máy cho khách làm sao',
        'đổi ktv đơn đã giao',
        'thêm linh kiện vào đơn đã giao',
        'đổi trạng thái đơn sửa',
        'đơn sửa xong rồi làm gì',
      ],
      tags: ['giao may', 'trang thai', 'don sua', 'ban giao', 'xong'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'repair-cost',
      title: 'Ghi giá vốn đơn sửa (linh kiện)',
      menuPath: 'Mở đơn sửa → mục "Tài chính đơn sửa" → sửa giá vốn',
      whatItDoes:
          'Ghi số tiền linh kiện đã dùng cho đơn để tính lãi. Có ô tích "Đơn '
          'này KHÔNG tốn giá vốn (0đ)" cho đơn chỉ công thợ, không thay linh kiện.',
      whenToUse:
          'Sau khi biết chính xác chi phí linh kiện, trước hoặc ngay khi giao máy.',
      steps: [
        'Mở đơn, vào "Tài chính đơn sửa".',
        'Nhập số tiền giá vốn linh kiện. App hỏi chi từ quỹ nào (tiền mặt / '
            'chuyển khoản / công nợ NCC).',
        'Nếu đơn KHÔNG dùng linh kiện: tích ô "Đơn này KHÔNG tốn giá vốn (0đ)".',
        'Lưu.',
      ],
      notes: [
        'Đơn cost 0đ chưa tích ô sẽ hiện cảnh báo cam "Chưa ghi nhận giá vốn" '
            'và bị nhắc ở khung CẦN XỬ LÝ ngoài Trang chủ.',
        'Tích "không tốn giá vốn" → hết bị nhắc, hiện chữ xám "Không tốn giá vốn (0đ)".',
        'Chọn "công nợ NCC" khi ghi giá vốn sẽ tạo một khoản nợ phải trả.',
        'Linh kiện thêm từ kho hiển thị kèm tên NCC ("Tên xSL · NCC: …") cho dễ '
            'nhận biết.',
      ],
      terms: ['gia-von-don-sua', 'gia-von', 'cong-no-phai-tra'],
      sampleQuestions: [
        'nhập giá vốn đơn sửa ở đâu',
        'đơn sửa không có giá vốn thì sao',
        'sao đơn sửa cứ báo chưa có giá vốn',
        'không tốn giá vốn là gì',
      ],
      tags: [
        'gia von', 'don sua', 'linh kien', 'chua ghi nhan', 'khong ton chi phi', 'cost'
      ],
      audience: ['owner', 'manager', 'technician'],
    ),
    KbEntry(
      id: 'repair-partner',
      title: 'Dịch vụ đối tác sửa chữa',
      menuPath: 'Trong đơn sửa → thêm dịch vụ đối tác',
      whatItDoes:
          'Ghi phần việc thuê ngoài (ép kính, thay main…) do một đối tác làm, '
          'kèm số tiền phải trả cho đối tác đó.',
      whenToUse: 'Khi một phần của đơn được gửi cho thợ/đơn vị ngoài làm.',
      steps: [
        'Mở đơn sửa, chọn thêm dịch vụ đối tác.',
        'Chọn đối tác, nhập nội dung + số tiền.',
        'Chọn trả ngay (tiền mặt / CK) hoặc CÔNG NỢ đối tác.',
      ],
      notes: [
        'Chọn CÔNG NỢ → sinh khoản nợ phải trả cho đối tác, quản lý ở mục Nhà '
            'cung cấp / Đối tác.',
      ],
      terms: ['cong-no-phai-tra'],
      sampleQuestions: [
        'thuê ngoài ép kính ghi vào đâu',
        'đối tác sửa chữa là gì',
      ],
      tags: ['doi tac', 'dtsc', 'thue ngoai', 'dich vu', 'don sua'],
      audience: ['owner', 'manager', 'technician'],
    ),
    KbEntry(
      id: 'warranty',
      title: 'Bảo hành',
      menuPath: 'Trang chủ → Bảo hành',
      whatItDoes:
          'Theo dõi các máy đã sửa / bán còn trong thời hạn bảo hành, tra cứu '
          'nhanh khi khách quay lại.',
      whenToUse: 'Khi khách quay lại khiếu nại trong thời hạn bảo hành.',
      steps: [
        'Vào Bảo hành, tìm theo tên khách / SĐT / IMEI.',
        'Xem thời hạn còn lại và nội dung sửa / sản phẩm gốc.',
        'Nếu còn hạn: tạo đơn sửa bảo hành (không thu tiền công phần lỗi cũ).',
      ],
      notes: [
        'Danh sách hiện SĐT khách, thời hạn BH và nội dung sửa của đơn gốc.',
      ],
      sampleQuestions: [
        'kiểm tra bảo hành ở đâu',
        'máy này còn bảo hành không',
      ],
      tags: ['bao hanh', 'warranty', 'bh', 'khieu nai'],
      audience: ['all'],
    ),

    // ===== BÁN HÀNG =====
    KbEntry(
      id: 'sale-create',
      title: 'Tạo đơn bán hàng',
      menuPath: 'Trang chủ → Bán hàng → nút +  (hoặc "Nhập nhanh" bằng giọng nói)',
      whatItDoes:
          'Lập hoá đơn bán điện thoại / phụ kiện / linh kiện: chọn sản phẩm, '
          'số lượng, giảm giá, tặng kèm, hình thức thanh toán, in phiếu.',
      whenToUse: 'Mỗi lần bán hàng cho khách.',
      steps: [
        'Bấm + ở màn Bán hàng.',
        'Chọn khách (hoặc để trống nếu khách lẻ).',
        'Thêm sản phẩm; đặt giá bán nếu SP chưa có giá (xem thẻ "GIÁ THAM KHẢO").',
        'Tuỳ chọn: Tặng / Giảm giá / sửa giá bán từng dòng.',
        'Chọn hình thức thanh toán (xem mục "Các hình thức thanh toán").',
        'Bấm HOÀN TẤT ĐƠN HÀNG, in phiếu nếu cần.',
      ],
      notes: [
        'Dòng SP chưa có giá bán hiện cảnh báo cam — chạm để đặt giá / xem gợi ý.',
        'Thiếu giá vốn thì không tính được lãi cho SP đó.',
      ],
      terms: ['gia-tham-khao', 'gia-von'],
      sampleQuestions: [
        'tạo đơn bán như thế nào',
        'bán hàng cho khách vào đâu',
        'xuất hoá đơn bán',
      ],
      tags: ['ban hang', 'tao don ban', 'hoa don', 'xuat hang', 'sale'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'sale-payment-methods',
      title: 'Các hình thức thanh toán khi bán / giao',
      menuPath: 'Trong đơn bán / lúc giao máy → mục thanh toán',
      whatItDoes:
          'Chọn cách khách trả tiền: Tiền mặt, Chuyển khoản, Kết hợp (một phần '
          'tiền + một phần CK), Công nợ (nợ toàn bộ hoặc trả trước một phần), '
          'Trả góp qua ngân hàng.',
      whenToUse: 'Ở bước cuối của mọi đơn bán và khi giao máy sửa.',
      steps: [
        'TIỀN MẶT / CHUYỂN KHOẢN: nhập đủ số tiền, tiền vào quỹ tương ứng.',
        'KẾT HỢP: nhập phần tiền mặt và phần chuyển khoản, tổng phải đủ.',
        'CÔNG NỢ: nhập số khách trả trước (có thể 0); phần còn lại thành nợ phải thu.',
        'TRẢ GÓP (NH): nhập tiền cọc khách đưa + chọn ngân hàng + số tiền vay. '
            'Có thể tách 2 ngân hàng.',
      ],
      notes: [
        'Công nợ trả trước một phần: phần trả trước ĐƯỢC ghi là tiền thực thu '
            '(vào sổ quỹ), phần còn lại là nợ.',
        'Trả góp: chỉ tiền cọc là tiền shop thu ngay; tiền ngân hàng ghi nhận '
            'khi tất toán.',
      ],
      terms: ['dong-tien', 'don-tich', 'cong-no-phai-thu', 'tra-gop-nh', 'coc', 'tat-toan'],
      sampleQuestions: [
        'có mấy hình thức thanh toán',
        'bán trả góp làm sao',
        'khách trả trước một phần thì nhập thế nào',
        'kết hợp tiền mặt và chuyển khoản',
      ],
      tags: [
        'thanh toan', 'tra gop', 'cong no', 'tien mat', 'chuyen khoan', 'ket hop',
        'coc', 'tra truoc', 'ngan hang'
      ],
      audience: ['all'],
    ),
    KbEntry(
      id: 'sale-price-suggestion',
      title: 'Giá tham khảo khi bán',
      menuPath: 'Trong đơn bán → thẻ "💡 GIÁ THAM KHẢO" ở bảng Tặng / Giảm giá / Sửa giá bán',
      whatItDoes:
          'Gợi ý giá vốn và giá bán theo trung vị lịch sử nhập cùng model, giúp '
          'định giá nhanh cho SP chưa có giá.',
      whenToUse: 'Khi bán một SP chưa đặt giá hoặc muốn tham khảo mặt bằng giá.',
      steps: [
        'Trong đơn bán, mở bảng Tặng / Giảm giá / 💰 Sửa giá bán của dòng SP.',
        'Xem thẻ "GIÁ THAM KHẢO": Vốn / Bán / Lợi nhuận.',
        'Bấm "DÙNG GIÁ BÁN" để điền nhanh, hoặc tự nhập.',
      ],
      notes: [
        'Vốn / Lợi nhuận chỉ hiện nếu bạn có quyền xem giá vốn.',
        'Chỉ là tham khảo — không tự động áp dụng.',
      ],
      terms: ['gia-tham-khao', 'gia-von', 'lai-gop'],
      sampleQuestions: [
        'giá tham khảo lấy từ đâu',
        'gợi ý giá bán là gì',
      ],
      tags: ['gia tham khao', 'goi y gia', 'dinh gia', 'gia ban', 'gia von'],
      audience: ['owner', 'manager', 'cashier'],
    ),
    KbEntry(
      id: 'sale-invoice',
      title: 'Phiếu bán & mã QR chuyển khoản',
      menuPath: 'Sau khi tạo đơn bán → Xem / In phiếu',
      whatItDoes:
          'Xuất phiếu bán cho khách, kèm mã QR VietQR để khách quét chuyển '
          'khoản đúng số tiền (kể cả tổng nợ nếu còn nợ cũ). Cấu hình tài khoản '
          'nhận tiền ở Cài đặt → QR chuyển khoản.',
      whenToUse: 'Khi cần đưa phiếu cho khách hoặc cho khách chuyển khoản.',
      steps: [
        'Mở đơn bán vừa tạo, chọn Xem phiếu.',
        'Khối "Nợ cũ / Lần này / Tổng nợ" hiện khi khách còn nợ.',
        'Khách quét QR để chuyển đúng số tiền; hoặc bấm In (máy in nhiệt).',
      ],
      notes: [
        'Cùng mã QR đó nay còn hiện ngay trong các sheet thanh toán khi chọn '
            '"Chuyển khoản" (thu nợ, thu tiền đơn, tất toán, trả NCC…) — kèm nút '
            '"Mở app ngân hàng" và nút sao chép. Vẫn phải bấm Xác nhận để ghi nhận.',
      ],
      sampleQuestions: [
        'in phiếu bán ở đâu',
        'mã qr chuyển khoản',
        'thanh toán qua ngân hàng',
        'mở app ngân hàng khi thu tiền',
      ],
      tags: ['phieu ban', 'in phieu', 'qr', 'chuyen khoan', 'vietqr', 'hoa don'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'sale-return',
      title: 'Trả hàng / huỷ đơn bán',
      menuPath: 'Trang chủ → Bán hàng → mở đơn → menu → Trả hàng / Xoá đơn',
      whatItDoes:
          'Nhận lại hàng khách trả và hoàn tài chính: trả lại tiền, cộng lại '
          'tồn kho, đảo các bút toán liên quan.',
      whenToUse: 'Khi khách trả lại sản phẩm hoặc đơn lập nhầm.',
      steps: [
        'Mở đơn bán cần xử lý.',
        'Chọn Trả hàng (một phần) hoặc Xoá đơn, hoàn tài chính.',
        'Xác thực quản lý nếu được yêu cầu.',
      ],
      notes: [
        'Thao tác này đảo lại doanh thu, giá vốn, tồn kho và công nợ của đơn.',
      ],
      sampleQuestions: [
        'khách trả hàng làm sao',
        'huỷ đơn bán nhầm',
      ],
      tags: ['tra hang', 'huy don', 'xoa don ban', 'hoan tien', 'return'],
      audience: ['owner', 'manager'],
    ),

    // ===== KHO =====
    KbEntry(
      id: 'inventory-overview',
      title: 'Xem tồn kho',
      menuPath: 'Trang chủ → Kho',
      whatItDoes:
          'Xem danh sách hàng còn trong kho theo nhóm (điện thoại / phụ kiện / '
          'linh kiện): số mặt hàng, số lượng tồn, tổng giá vốn.',
      whenToUse: 'Kiểm tra còn hàng để bán, hoặc xem tiền đang nằm ở hàng hoá.',
      steps: [
        'Vào Kho.',
        'Lọc theo nhóm hoặc tìm theo tên / mã.',
        'Chạm sản phẩm để xem biến thể, giá, lịch sử.',
      ],
      notes: [
        '"Mặt hàng" ≠ "Sản phẩm tồn" — xem thuật ngữ.',
      ],
      terms: ['mat-hang-vs-ton', 'ton-kho-gia-von', 'bien-the'],
      sampleQuestions: [
        'xem tồn kho ở đâu',
        'còn bao nhiêu hàng',
        'kho linh kiện còn gì',
      ],
      tags: ['ton kho', 'kho', 'con hang', 'so luong', 'inventory', 'stock'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'stock-in-cash',
      title: 'Nhập kho nhanh (trả tiền ngay)',
      menuPath: 'Trang chủ → Kho → Nhập hàng / Nhập nhanh',
      whatItDoes:
          'Thêm hàng mới vào kho và trả tiền NCC ngay bằng tiền mặt / chuyển khoản.',
      whenToUse: 'Khi lấy hàng và thanh toán liền cho nhà cung cấp.',
      steps: [
        'Vào Nhập hàng, chọn / thêm nhà cung cấp.',
        'Thêm từng SP: hãng, model, dung lượng, màu, tình trạng, số lượng, giá vốn.',
        'Chọn thanh toán Tiền mặt / Chuyển khoản.',
        'Lưu → tạo phiếu nháp; bấm "Xác nhận" để hàng vào kho.',
      ],
      notes: [
        'Chưa "Xác nhận" thì hàng CHƯA cộng vào tồn (xem "Hàng chờ xác nhận").',
        'Thiếu model → tên hàng để trống, không tự đặt "KHÁC MỚI".',
      ],
      terms: ['nhap-tam', 'gia-von', 'bien-the'],
      sampleQuestions: [
        'nhập hàng vào kho làm sao',
        'nhập kho trả tiền luôn',
      ],
      tags: ['nhap kho', 'nhap hang', 'nhap nhanh', 'ncc', 'stock in'],
      audience: ['owner', 'manager', 'technician'],
    ),
    KbEntry(
      id: 'stock-in-debt',
      title: 'Nhập kho ghi nợ nhà cung cấp',
      menuPath: 'Trang chủ → Kho → Nhập hàng → thanh toán "CÔNG NỢ"',
      whatItDoes:
          'Nhập hàng nhưng chưa trả tiền — sinh một khoản nợ phải trả cho NCC.',
      whenToUse: 'Khi lấy hàng trước, trả tiền sau.',
      steps: [
        'Nhập hàng như bình thường.',
        'Ở bước thanh toán chọn CÔNG NỢ, chọn / nhập nhà cung cấp.',
        'Lưu và "Xác nhận" phiếu → nợ NCC được tạo khi xác nhận.',
        'Trả tiền sau ở mục Nhà cung cấp → Thanh toán nợ.',
      ],
      notes: [
        'Nợ chỉ sinh khi phiếu được XÁC NHẬN, không phải lúc lưu nháp.',
        'Bấm "xem đơn gốc" của nợ này sẽ hiện bảng "Nguồn khoản nợ" (không có đơn riêng).',
      ],
      terms: ['nhap-tam', 'cong-no-phai-tra', 'nguon-khoan-no'],
      sampleQuestions: [
        'nhập hàng nợ tiền nhà cung cấp',
        'sao nợ ncc không thấy đơn gốc',
      ],
      tags: ['nhap kho', 'cong no', 'ncc', 'no phai tra', 'stock in'],
      audience: ['owner', 'manager', 'technician'],
    ),
    KbEntry(
      id: 'stock-pending-confirm',
      title: 'Hàng chờ xác nhận',
      menuPath: 'Trang chủ → Kho → Hàng chờ xác nhận (Phiếu nhập chờ)',
      whatItDoes:
          'Danh sách phiếu nhập kho đã tạo nháp nhưng chưa xác nhận. Xác nhận '
          'thì hàng mới vào tồn (và mới sinh nợ NCC nếu là công nợ).',
      whenToUse: 'Sau khi tạo phiếu nhập, khi đã kiểm đủ hàng thực tế.',
      steps: [
        'Vào Hàng chờ xác nhận.',
        'Mở phiếu, đối chiếu số lượng / giá vốn.',
        'Bấm Xác nhận → tồn kho tăng, nợ NCC (nếu có) được tạo.',
      ],
      terms: ['nhap-tam'],
      sampleQuestions: [
        'hàng chờ xác nhận là gì',
        'nhập kho rồi mà kho chưa tăng',
      ],
      tags: ['hang cho xac nhan', 'phieu nhap', 'xac nhan', 'nhap tam', 'draft'],
      audience: ['owner', 'manager', 'technician'],
    ),
    KbEntry(
      id: 'inventory-check',
      title: 'Kiểm kho (đối chiếu tồn thực tế)',
      menuPath: 'Trang chủ → Kho → Kiểm kho nhanh',
      whatItDoes:
          'Quét mã / tick từng SP để so tồn trên app với hàng thực tế, phát '
          'hiện thiếu / thừa.',
      whenToUse: 'Định kỳ (cuối tuần / cuối tháng) hoặc khi nghi thất thoát.',
      steps: [
        'Vào Kiểm kho nhanh, chọn khu vực.',
        'Quét QR (mã ngắn 4–5 số hoặc IMEI) hoặc tick thủ công.',
        'Xem checklist: hàng thiếu đánh dấu đỏ.',
        'Xuất báo cáo, điều chỉnh chênh lệch nếu cần (có ghi lý do).',
      ],
      sampleQuestions: [
        'kiểm kho như thế nào',
        'đối chiếu tồn kho thực tế',
      ],
      tags: ['kiem kho', 'doi chieu', 'quet ma', 'qr', 'that thoat'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'purchase-order',
      title: 'Đơn nhập hàng (Purchase Order)',
      menuPath: 'Trang chủ → Kho → Đơn nhập hàng',
      whatItDoes:
          'Lập đơn đặt hàng NCC trước, theo dõi đã về / chưa về, rồi chuyển '
          'thành phiếu nhập kho khi hàng tới.',
      whenToUse: 'Khi đặt hàng số lượng lớn, cần theo dõi tiến độ giao.',
      steps: [
        'Vào Đơn nhập hàng, tạo đơn: NCC, danh sách SP, số lượng, giá dự kiến.',
        'Khi hàng về: mở đơn, xác nhận nhận hàng → tạo phiếu nhập kho.',
      ],
      sampleQuestions: [
        'đơn nhập hàng là gì',
        'đặt hàng nhà cung cấp',
      ],
      tags: ['don nhap hang', 'purchase order', 'po', 'dat hang', 'ncc'],
      audience: ['owner', 'manager'],
    ),

    // ===== CÔNG NỢ =====
    KbEntry(
      id: 'debt-overview',
      title: 'Quản lý công nợ',
      menuPath: 'Trang chủ → Công nợ',
      whatItDoes:
          'Xem tất cả khoản nợ: khách nợ shop (phải thu) và shop nợ NCC / đối '
          'tác (phải trả); còn nợ bao nhiêu, đã trả bao nhiêu.',
      whenToUse: 'Xem ai còn nợ, nhắc thu, hoặc trước khi trả tiền NCC.',
      steps: [
        'Vào Công nợ, chọn tab Phải thu / Phải trả.',
        'Chạm một khoản để xem chi tiết và lịch sử trả.',
        'Bấm "xem đơn gốc" để mở đơn bán/sửa sinh ra nợ (nợ nhập kho hiện bảng Nguồn khoản nợ).',
      ],
      notes: [
        'Nợ tự sinh khi bán / sửa / nhập chọn "CÔNG NỢ". Cũng tạo tay được.',
        'Số "đã trả" cộng dồn từ từng lần trả và đồng bộ mọi máy.',
      ],
      terms: ['cong-no-phai-thu', 'cong-no-phai-tra', 'nguon-khoan-no'],
      sampleQuestions: [
        'xem công nợ ở đâu',
        'ai đang nợ mình',
        'shop đang nợ ncc bao nhiêu',
      ],
      tags: ['cong no', 'no', 'phai thu', 'phai tra', 'khach no', 'ncc no', 'debt'],
      audience: ['owner', 'manager', 'cashier'],
    ),
    KbEntry(
      id: 'debt-collect',
      title: 'Thu nợ khách / Trả nợ NCC',
      menuPath: 'Công nợ → mở khoản nợ → Thu nợ / Thanh toán nợ',
      whatItDoes:
          'Ghi nhận một lần nhận tiền từ khách (thu nợ) hoặc trả tiền cho NCC / '
          'đối tác (trả nợ). Trả từng phần được.',
      whenToUse: 'Mỗi lần tiền thực sự vào/ra liên quan một khoản nợ.',
      steps: [
        'Mở khoản nợ cần xử lý.',
        'Bấm Thu nợ (khách) hoặc Thanh toán nợ (NCC).',
        'Nhập số tiền, chọn quỹ (tiền mặt / chuyển khoản), xác nhận.',
      ],
      notes: [
        'Mỗi lần trả tạo một dòng "phiếu trả nợ"; tổng "đã trả" tự khớp lại và '
            'đồng bộ mọi máy (kể cả khi các máy nhập lệch nhau).',
        'Trả đủ → khoản nợ chuyển trạng thái "Đã trả".',
        'Chọn "Chuyển khoản" → hiện mã QR VietQR (điền sẵn số tiền + nội dung, '
            'theo TK ngân hàng đã cấu hình ở Cài đặt → QR chuyển khoản) + nút '
            '"Mở app ngân hàng" + sao chép STK/số tiền. Đây chỉ là hỗ trợ — '
            'chuyển khoản xong vẫn phải bấm Xác nhận để app ghi nhận.',
      ],
      terms: ['dong-tien', 'cong-no-phai-thu', 'cong-no-phai-tra'],
      sampleQuestions: [
        'thu tiền nợ của khách',
        'trả nợ nhà cung cấp',
        'sao thanh toán rồi mà nợ không giảm',
      ],
      tags: ['thu no', 'tra no', 'thanh toan no', 'cong no', 'khach tra tien'],
      audience: ['owner', 'manager', 'cashier'],
    ),
    KbEntry(
      id: 'debt-waive',
      title: 'Miễn nợ (xoá nợ khó đòi)',
      menuPath: 'Cài đặt → Dữ liệu & Hệ thống → Công cụ điều chỉnh dữ liệu → tab CÔNG NỢ',
      whatItDoes:
          'Xoá phần còn nợ của một khoản mà shop chấp nhận không đòi nữa, có '
          'ghi lý do và cần xác thực mật khẩu.',
      whenToUse: 'Nợ nhỏ, khách mất liên lạc, hoặc thoả thuận bỏ qua.',
      steps: [
        'Vào Công cụ điều chỉnh dữ liệu → tab CÔNG NỢ.',
        'Tìm khoản nợ còn dư, bấm "Miễn nợ".',
        'Nhập lý do (bắt buộc), xác nhận.',
      ],
      notes: [
        'Danh sách chỉ hiện khoản còn dư > 0, chưa trả hết / chưa huỷ.',
        'Có ghi nhật ký + gửi thông báo cho chủ shop / quản lý.',
      ],
      terms: ['mien-no'],
      sampleQuestions: [
        'miễn nợ ở đâu',
        'xoá nợ khó đòi',
        'nút miễn nợ bấm không được',
      ],
      tags: ['mien no', 'xoa no', 'no kho doi', 'cong cu dieu chinh du lieu'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'data-reconciliation',
      title: 'Công cụ điều chỉnh dữ liệu',
      menuPath: 'Cài đặt → Dữ liệu & Hệ thống → Công cụ điều chỉnh dữ liệu',
      whatItDoes:
          'Bộ công cụ dọn / sửa dữ liệu lệch: tab KHO & SP (sửa số lượng), tab '
          'CÔNG NỢ (miễn nợ, sửa tổng nợ), tab TÀI CHÍNH (dọn phiếu mồ côi, đảo '
          'bút toán sai). Mọi thao tác cần mật khẩu + có nhật ký.',
      whenToUse:
          'Khi phát hiện số liệu sai do thao tác nhầm / lỗi đồng bộ cũ. Dùng thận trọng.',
      steps: [
        'Vào Công cụ điều chỉnh dữ liệu, nhập mật khẩu.',
        'Chọn tab tương ứng, xem danh sách bất thường app phát hiện.',
        'Sửa / xoá từng dòng, luôn nhập lý do.',
      ],
      notes: [
        'Đây là công cụ sửa chữa — không dùng cho nghiệp vụ hằng ngày.',
      ],
      sampleQuestions: [
        'công cụ điều chỉnh dữ liệu để làm gì',
        'sửa số liệu bị lệch',
      ],
      tags: ['cong cu dieu chinh du lieu', 'doi soat', 'don du lieu', 'sua lech'],
      audience: ['owner', 'manager'],
    ),

    // ===== TÀI CHÍNH =====
    KbEntry(
      id: 'finance-cash-vs-accrual',
      title: 'Dòng tiền vs Dồn tích (vì sao 2 số lãi khác nhau)',
      menuPath: 'Trang chủ → Tài chính',
      whatItDoes:
          'App tách rõ 2 cách nhìn: DÒNG TIỀN (tiền thực vào/ra) và KẾT QUẢ KINH '
          'DOANH / dồn tích (ghi nhận khi bán, dù chưa thu).',
      whenToUse:
          'Khi thấy "Lãi gộp (phần đã thu)" khác "Lợi nhuận (accrual)" và thắc mắc.',
      steps: [
        'Báo cáo lãi/lỗ (tháng, năm) dùng DỒN TÍCH — phản ánh kinh doanh thật.',
        'Sổ quỹ / "tiền vào hôm nay" dùng DÒNG TIỀN — phản ánh tiền trong két.',
        'Khách còn nợ nhiều → 2 số lệch nhau, đó là bình thường.',
      ],
      terms: ['dong-tien', 'don-tich', 'lai-gop'],
      sampleQuestions: [
        'sao lợi nhuận và tiền vào khác nhau',
        'dồn tích là gì',
        'dòng tiền khác lợi nhuận chỗ nào',
      ],
      tags: ['dong tien', 'don tich', 'accrual', 'cash', 'loi nhuan', 'lai gop'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'cash-closing',
      title: 'Sổ quỹ / Chốt quỹ',
      menuPath: 'Trang chủ → Tài chính → Sổ quỹ',
      whatItDoes:
          'Cuối ngày đếm tiền mặt + số dư ngân hàng thực tế, nhập vào app. App '
          'so với kỳ vọng (Đầu kỳ + Thu − Chi) để phát hiện thừa/thiếu quỹ.',
      whenToUse: 'Mỗi ngày trước khi đóng cửa.',
      steps: [
        'Vào Sổ quỹ, xem Thu / Chi trong ngày.',
        'Đếm tiền mặt thực tế + tra số dư ngân hàng, nhập vào.',
        'App tính lệch = Thực tế − Kỳ vọng. Bấm Chốt quỹ.',
        'Nếu lệch: kiểm tra giao dịch quên ghi trước khi chốt.',
      ],
      notes: [
        'Công thức: Kỳ vọng = Đầu kỳ + Thu trong ngày − Chi trong ngày.',
        'Chốt quỹ đều mỗi ngày giúp phát hiện thất thoát sớm.',
        'Ngày chưa chốt quỹ sẽ được nhắc ở khung CẦN XỬ LÝ.',
      ],
      terms: ['chot-quy', 'lech-quy', 'dong-tien'],
      sampleQuestions: [
        'chốt quỹ là gì',
        'cách chốt quỹ cuối ngày',
        'quỹ bị lệch phải làm sao',
      ],
      tags: ['chot quy', 'so quy', 'cash closing', 'lech quy', 'dem tien', 'cuoi ngay'],
      audience: ['owner', 'manager', 'cashier'],
    ),
    KbEntry(
      id: 'price-book',
      title: 'Bảng giá (giá đề xuất + giá niêm yết)',
      menuPath:
          'Trang chủ → TRUY CẬP NHANH TÀI CHÍNH → Bảng giá  (hoặc tab Sửa '
          'chữa → "Bảng giá sửa chữa", tab Bán hàng → "Bảng giá bán hàng" — '
          'vào đúng tab tương ứng)',
      whatItDoes:
          'Tổng hợp giá đề xuất (trung vị lịch sử) cho từng "model · lỗi" (sửa '
          'chữa) và từng model/biến thể (bán hàng). Chủ shop có thể GHIM giá '
          'niêm yết chính thức; form tạo đơn sẽ tự điền giá đó.',
      whenToUse:
          'Xem mặt bằng giá, chốt bảng giá dịch vụ, hoặc đặt giá nhanh cho SP '
          'chưa có giá bán.',
      steps: [
        'Mở Bảng giá, chọn tab Sửa chữa hoặc Bán hàng.',
        'Tìm theo model/lỗi. Mỗi dòng hiện 3 ô Thu/Bán · Vốn · Lãi + số mẫu + '
            'độ tin cậy + khoảng giá thường gặp.',
        'Chạm 1 dòng → nhập "Giá niêm yết" (+ giá vốn, ghi chú tuỳ chọn) → '
            '**Ghim giá**. Dòng đó chuyển nhãn "NIÊM YẾT". Nút "Xem N đơn/SP '
            'tương ứng" mở danh sách các đơn sửa / SP đã tạo ra giá đó (bấm để '
            'xem chi tiết).',
        'Tab Bán hàng: nút "Áp giá cho SP chưa có giá" (góc trên) → xem danh '
            'sách đề xuất → xác nhận để đặt giá hàng loạt.',
        'Menu ⋮: **Hệ số giá mùa vụ** (+/-% vào giá đề xuất), **Xuất Excel**, '
            '**Nhập từ Excel** (sửa bảng giá hàng loạt rồi nhập lại — khớp theo '
            'cột _khoá, "Giá NIÊM YẾT" > 0 thì ghim).',
      ],
      notes: [
        'Giá đề xuất tính từ đơn sửa đã Xong/Đã giao và giá SP trong kho — chạy '
            'local, không tốn mạng.',
        'Khi tạo đơn sửa: nếu "model · lỗi" có giá ghim, thẻ "GIÁ NIÊM YẾT" hiện '
            'lên và tự điền vào ô giá (nếu đang trống). Nhập giá lệch >35% so với '
            'giá niêm yết/giá thường gặp → có cảnh báo.',
        'Hệ số mùa vụ chỉ áp cho GIÁ ĐỀ XUẤT, không đụng giá đã ghim.',
        'Giá ghim & hệ số mùa vụ lưu theo máy (chưa đồng bộ giữa các thiết bị).',
      ],
      terms: ['gia-tham-khao', 'gia-von', 'lai-gop'],
      sampleQuestions: [
        'bảng giá ở đâu',
        'giá ép kính iphone 12 bao nhiêu',
        'chốt bảng giá dịch vụ sửa',
        'áp giá hàng loạt cho sản phẩm chưa có giá',
        'tăng giá dịp tết',
        'xuất nhập bảng giá bằng excel',
      ],
      tags: [
        'bang gia', 'gia de xuat', 'gia niem yet', 'ghim gia', 'price book',
        'chot gia', 'ap gia hang loat', 'he so mua vu', 'gia tet', 'excel bang gia'
      ],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'money-reconcile',
      title: 'Đối soát tiền về',
      menuPath:
          'Trang chủ → TRUY CẬP NHANH TÀI CHÍNH → Đối soát tiền về  (cũng có ở '
          'Sổ quỹ, Công nợ, Tài chính, tab Bán hàng)',
      whatItDoes:
          'Nhập số tiền vừa nhận (hoặc vừa chuyển đi) → app tự tìm đơn trả góp '
          'ngân hàng chưa tất toán hoặc khoản công nợ có số tiền khớp → chọn và '
          'xác nhận để ghi nhận + cập nhật trạng thái.',
      whenToUse:
          'Khi có tiền về tài khoản (NH tất toán trả góp, khách chuyển trả nợ) '
          'mà chưa biết ứng với đơn/khoản nào; hoặc khi vừa chuyển tiền trả NCC.',
      steps: [
        'Mở "Đối soát tiền về".',
        'Chọn chiều: Tiền vào (nhận) hoặc Tiền ra (chuyển đi).',
        'Gõ số tiền — app **tự lọc ngay, không cần bấm nút**. Danh sách hiện các '
            'khoản khớp (khớp đúng / khớp một phần), khớp đúng lên trước.',
        'Chạm một khoản → xem lại → Xác nhận ghi. App ghi nhận qua đúng luồng '
            '(tất toán trả góp / thu nợ / trả nợ) và cập nhật trạng thái.',
        'Nút ↗ trên mỗi dòng: mở đơn bán/sửa gốc hoặc màn Công nợ để đối chiếu '
            'trước khi ghi.',
        'Kéo danh sách xuống để làm mới sau khi ghi.',
      ],
      notes: [
        'Luôn hiện danh sách để bạn xác nhận — không tự động ghi.',
        'Đơn bán/sửa CÔNG NỢ còn thiếu tiền nằm trong nhóm "công nợ khách".',
        'Ghi nhận xong khoản đó biến mất khỏi danh sách.',
        'Dữ liệu nạp một lần khi mở màn → gõ số tiền lọc trong bộ nhớ, không lag '
            'dù shop nhiều công nợ.',
      ],
      terms: ['tra-gop-nh', 'tat-toan', 'cong-no-phai-thu', 'cong-no-phai-tra', 'dong-tien'],
      sampleQuestions: [
        'đối soát tiền về là gì',
        'nhận tiền ngân hàng tất toán ghi ở đâu',
        'có tiền về không biết của đơn nào',
      ],
      tags: [
        'doi soat', 'tien ve', 'tat toan', 'nhan tien ngan hang', 'thu no',
        'khop so tien', 'sao ke'
      ],
      audience: ['owner', 'manager', 'cashier'],
    ),
    KbEntry(
      id: 'finance-daily-report',
      title: 'Báo cáo ngày',
      menuPath: 'Trang chủ → Tài chính → Báo cáo ngày',
      whatItDoes:
          'Tổng hợp một ngày: doanh thu / giá vốn / lợi nhuận (dồn tích) và '
          'tiền vào / tiền ra (dòng tiền), xuất Excel được.',
      whenToUse: 'Xem nhanh kết quả một ngày cụ thể hoặc đối chiếu.',
      steps: [
        'Vào Báo cáo ngày, chọn ngày.',
        'Xem 2 khối: KẾT QUẢ KINH DOANH (accrual) và DÒNG TIỀN (cash).',
        'Bấm xuất Excel nếu cần lưu.',
      ],
      terms: ['dong-tien', 'don-tich'],
      sampleQuestions: [
        'báo cáo ngày xem ở đâu',
        'doanh thu ngày hôm qua',
      ],
      tags: ['bao cao ngay', 'daily report', 'doanh thu ngay', 'excel'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'finance-v2',
      title: 'Tài chính (tổng quan 5 tab)',
      menuPath: 'Trang chủ → Tài chính',
      whatItDoes:
          'Màn tài chính chính: tổng quan dòng tiền, thu, chi, công nợ, báo cáo '
          '— theo khoảng thời gian chọn được, xuất Excel.',
      whenToUse: 'Xem sức khoẻ tài chính shop theo tuần / tháng / kỳ tuỳ chọn.',
      steps: [
        'Vào Tài chính, chọn khoảng thời gian.',
        'Chuyển giữa các tab: Tổng quan / Thu / Chi / Công nợ / Báo cáo.',
        'Bấm ⓘ ở góc để xem giải thích khái niệm.',
      ],
      notes: [
        'Các số ở đây là DÒNG TIỀN (tiền đã thu / đã chi), không phải lợi nhuận kế toán.',
      ],
      terms: ['dong-tien', 'don-tich'],
      sampleQuestions: [
        'màn tài chính có gì',
        'xem thu chi tháng này',
      ],
      tags: ['tai chinh', 'finance', 'thu chi', 'tong quan', 'dong tien'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'monthly-profit',
      title: 'Báo cáo lãi theo tháng / năm',
      menuPath: 'Trang chủ → Báo cáo → Lãi theo tháng',
      whatItDoes:
          'Doanh thu và lợi nhuận theo dồn tích cho từng tháng và cả năm, kèm '
          'tổng thu / tổng chi theo dòng tiền.',
      whenToUse: 'Đánh giá kinh doanh theo tháng, so sánh các tháng.',
      terms: ['don-tich', 'dong-tien'],
      sampleQuestions: [
        'lợi nhuận tháng này bao nhiêu',
        'báo cáo lãi cả năm',
      ],
      tags: ['bao cao lai', 'loi nhuan thang', 'monthly profit', 'nam'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'expense',
      title: 'Chi phí',
      menuPath: 'Trang chủ → Chi phí',
      whatItDoes:
          'Ghi các khoản chi vận hành: mặt bằng, điện nước, lương, ăn uống, '
          'vặt… theo nhóm, chọn chi từ tiền mặt hay chuyển khoản.',
      whenToUse: 'Mỗi lần shop chi tiền cho việc không phải nhập hàng.',
      steps: [
        'Vào Chi phí, bấm thêm.',
        'Chọn nhóm chi phí, nhập số tiền + ghi chú.',
        'Chọn quỹ chi (tiền mặt / chuyển khoản), lưu.',
      ],
      notes: [
        'Chi phí làm giảm dòng tiền và trừ vào lợi nhuận trong kỳ.',
      ],
      terms: ['dong-tien'],
      sampleQuestions: [
        'ghi chi phí ở đâu',
        'nhập tiền điện nước',
      ],
      tags: ['chi phi', 'expense', 'chi tien', 'mat bang', 'dien nuoc'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'payroll',
      title: 'Lương & Bảng lương',
      menuPath: 'Trang chủ → Nhân viên → Bảng lương',
      whatItDoes:
          'Tính lương nhân viên theo lương cơ bản + hoa hồng (theo đơn bán / '
          'đơn sửa) và ghi nhận khi trả.',
      whenToUse: 'Cuối kỳ lương.',
      steps: [
        'Vào Bảng lương, chọn kỳ.',
        'Xem lương cơ bản + hoa hồng từng người.',
        'Ghi nhận đã trả (chi từ quỹ) khi thanh toán.',
      ],
      terms: ['dong-tien'],
      sampleQuestions: [
        'tính lương nhân viên',
        'bảng lương ở đâu',
      ],
      tags: ['luong', 'bang luong', 'payroll', 'hoa hong', 'nhan vien'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'attendance',
      title: 'Chấm công',
      menuPath: 'Trang chủ → Nhân viên → Chấm công',
      whatItDoes:
          'Ghi công đi làm của nhân viên (theo ngày / ca), làm cơ sở tính lương.',
      whenToUse: 'Hằng ngày hoặc cuối kỳ nhập bù.',
      sampleQuestions: [
        'chấm công như thế nào',
        'ghi ngày công nhân viên',
      ],
      tags: ['cham cong', 'attendance', 'ngay cong', 'ca lam'],
      audience: ['owner', 'manager'],
    ),

    // ===== KHÁCH HÀNG =====
    KbEntry(
      id: 'customers',
      title: 'Khách hàng',
      menuPath: 'Trang chủ → Khách hàng',
      whatItDoes:
          'Danh bạ khách: thông tin liên hệ, lịch sử sửa chữa, lịch sử mua '
          'hàng, tổng công nợ hiện tại.',
      whenToUse: 'Tra cứu khách cũ, xem lịch sử, xem khách nợ.',
      steps: [
        'Vào Khách hàng, tìm theo tên / SĐT.',
        'Mở hồ sơ khách để xem lịch sử và công nợ.',
      ],
      terms: ['cong-no-phai-thu'],
      sampleQuestions: [
        'xem lịch sử khách hàng',
        'khách này từng sửa gì',
      ],
      tags: ['khach hang', 'customer', 'danh ba', 'lich su khach'],
      audience: ['all'],
    ),

    // ===== TRANG CHỦ / DASHBOARD =====
    KbEntry(
      id: 'home-action-required',
      title: 'Khung "CẦN XỬ LÝ" ở Trang chủ',
      menuPath: 'Trang chủ',
      whatItDoes:
          'Nhắc các việc tồn đọng trong TUẦN NÀY: đơn sửa đã giao chưa ghi giá '
          'vốn, tiền ngân hàng (trả góp) chưa tất toán, ngày chưa chốt quỹ…',
      whenToUse: 'Mở app đầu ngày để biết cần làm gì.',
      notes: [
        'Chỉ đếm việc trong tuần này để không bị nhiễu bởi tồn đọng quá cũ.',
        'Đơn sửa đã tích "không tốn giá vốn" không bị nhắc.',
        'Bấm từng mục để mở danh sách đầy đủ.',
      ],
      terms: ['gia-von-don-sua', 'tra-gop-nh', 'chot-quy'],
      sampleQuestions: [
        'khung cần xử lý là gì',
        'sao home báo đơn sửa chưa có giá vốn',
      ],
      tags: ['can xu ly', 'trang chu', 'home', 'nhac viec', 'canh bao'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'home-today-activity',
      title: '"Hoạt động hôm nay" ở Trang chủ',
      menuPath: 'Trang chủ',
      whatItDoes:
          'Dòng thời gian các việc trong ngày: nhận sửa, sửa xong, giao máy, '
          'đơn bán, thu/chi, tạo công nợ… kèm số tiền và người thực hiện.',
      whenToUse: 'Xem nhanh hôm nay đã làm gì.',
      sampleQuestions: [
        'hoạt động hôm nay hiển thị gì',
      ],
      tags: ['hoat dong hom nay', 'feed', 'trang chu', 'timeline'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'home-dashboard-cards',
      title: 'Thẻ số liệu ở Trang chủ',
      menuPath: 'Trang chủ',
      whatItDoes:
          'Thẻ tóm tắt: dòng tiền hôm nay, tiền bán / tiền sửa, đơn đang chờ, '
          'công nợ… Bật/tắt và sắp xếp được.',
      whenToUse: 'Liếc nhanh tình hình ngay khi mở app.',
      notes: [
        '"Dòng tiền hôm nay" = tiền thực thu − thực chi, không phải lợi nhuận.',
      ],
      terms: ['dong-tien'],
      sampleQuestions: [
        'thẻ ngoài trang chủ nghĩa là gì',
      ],
      tags: ['dashboard', 'the so lieu', 'trang chu', 'dong tien hom nay'],
      audience: ['owner', 'manager'],
    ),

    // ===== HỆ THỐNG =====
    KbEntry(
      id: 'roles-permissions',
      title: 'Phân quyền nhân viên',
      menuPath: 'Cài đặt → Nhân viên → Phân quyền',
      whatItDoes:
          'Gán vai trò và bật/tắt từng quyền chi tiết cho nhân viên (xem giá '
          'vốn, xem doanh thu, sửa đơn, xoá…).',
      whenToUse: 'Khi thêm nhân viên mới hoặc điều chỉnh quyền.',
      steps: [
        'Vào Phân quyền, chọn nhân viên.',
        'Chọn vai trò (chủ shop / quản lý / kỹ thuật / bán hàng).',
        'Bật/tắt quyền chi tiết nếu cần, lưu.',
      ],
      notes: [
        'Số liệu tài chính (doanh thu, lợi nhuận, công nợ) chỉ hiện cho chủ '
            'shop và quản lý. Nhân viên/kỹ thuật không nhận thông báo tài chính.',
      ],
      terms: ['vai-tro'],
      sampleQuestions: [
        'phân quyền nhân viên ở đâu',
        'nhân viên không xem được doanh thu',
      ],
      tags: ['phan quyen', 'vai tro', 'quyen', 'nhan vien', 'role', 'permission'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'multi-device-sync',
      title: 'Đồng bộ đa thiết bị',
      menuPath: 'Tự động (không cần thao tác)',
      whatItDoes:
          'Mọi máy đăng nhập cùng shop chia sẻ dữ liệu realtime. Mất mạng vẫn '
          'dùng, có mạng lại tự đồng bộ.',
      whenToUse: 'Luôn chạy nền. Kiểm tra khi 2 máy thấy số khác nhau.',
      steps: [
        'Đảm bảo cả 2 máy đăng nhập đúng tài khoản cùng shop.',
        'Bật mạng cho máy đang offline → chờ vài giây để đồng bộ.',
        'Nếu vẫn lệch: mở lại app, hoặc dùng Sao lưu / khôi phục.',
      ],
      notes: [
        'Xoá là xoá mềm để đồng bộ đúng giữa các máy.',
        'Số "đã trả nợ" tự khớp lại từ lịch sử phiếu trên mọi máy.',
      ],
      terms: ['dong-bo', 'soft-delete', 'shop-id'],
      sampleQuestions: [
        'sao 2 máy số liệu khác nhau',
        'dữ liệu có tự đồng bộ không',
      ],
      tags: ['dong bo', 'sync', 'da thiet bi', 'offline', 'lech du lieu'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'notifications',
      title: 'Thông báo',
      menuPath: 'Cài đặt → Thông báo',
      whatItDoes:
          'Đẩy thông báo giữa các máy trong shop: đơn mới, đổi trạng thái, và '
          'mọi hoạt động tài chính (thu/chi, chốt quỹ, công nợ tạo/thu/trả/miễn).',
      whenToUse: 'Bật để nắm hoạt động khi không trực tiếp thao tác.',
      notes: [
        'Thông báo tài chính / công nợ chỉ gửi cho chủ shop và quản lý.',
        'Bật/tắt từng loại trong Cài đặt → Thông báo.',
      ],
      terms: ['vai-tro'],
      sampleQuestions: [
        'tắt bớt thông báo',
        'ai nhận được thông báo tài chính',
      ],
      tags: ['thong bao', 'notification', 'push', 'canh bao'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'backup-restore',
      title: 'Sao lưu & Khôi phục',
      menuPath: 'Cài đặt → Dữ liệu & Hệ thống → Sao lưu / Khôi phục',
      whatItDoes:
          'Tạo bản sao dữ liệu shop và khôi phục lại khi cần (đổi máy, sự cố).',
      whenToUse: 'Trước khi đổi thiết bị hoặc khi nghi mất dữ liệu.',
      steps: [
        'Vào Sao lưu / Khôi phục.',
        'Bấm Sao lưu để tạo bản mới.',
        'Khi cần: chọn bản và Khôi phục (ghi đè dữ liệu hiện tại).',
      ],
      notes: [
        'Khôi phục ghi đè — chỉ làm khi chắc chắn.',
      ],
      sampleQuestions: [
        'sao lưu dữ liệu ở đâu',
        'đổi điện thoại thì chuyển dữ liệu sao',
      ],
      tags: ['sao luu', 'khoi phuc', 'backup', 'restore', 'doi may'],
      audience: ['owner'],
    ),
    KbEntry(
      id: 'excel-export',
      title: 'Xuất Excel',
      menuPath: 'Trong các màn Báo cáo / Tài chính / Kho → nút Xuất Excel',
      whatItDoes:
          'Xuất báo cáo tài chính, danh sách đơn, tồn kho ra file Excel tiếng Việt.',
      whenToUse: 'Khi cần lưu ngoài, gửi kế toán, hoặc đối chiếu.',
      sampleQuestions: [
        'xuất excel báo cáo',
        'lấy file excel tồn kho',
      ],
      tags: ['excel', 'xuat file', 'bao cao', 'xls'],
      audience: ['owner', 'manager'],
    ),
    KbEntry(
      id: 'voice-input',
      title: 'Nhập nhanh bằng giọng nói',
      menuPath: 'Nút micro ở màn Sửa chữa / Bán hàng / Kho',
      whatItDoes:
          'Nói tự nhiên ("nhận sửa iPhone 12 màn hình cho anh Minh 09xx") → AI '
          'tự điền vào form tạo đơn / nhập kho.',
      whenToUse: 'Khi muốn tạo đơn nhanh không gõ tay.',
      steps: [
        'Bấm nút micro, nói nội dung.',
        'AI điền form; kiểm tra lại và chỉnh nếu sai.',
        'Lưu như đơn bình thường.',
      ],
      notes: [
        'Luôn kiểm tra lại số tiền và tên trước khi lưu.',
      ],
      sampleQuestions: [
        'tạo đơn bằng giọng nói',
        'nhập nhanh bằng nói',
      ],
      tags: ['giong noi', 'voice', 'nhap nhanh', 'micro', 'ai'],
      audience: ['all'],
    ),
    KbEntry(
      id: 'ai-assistant',
      title: 'AI Trợ Lý (chat)',
      menuPath: 'Nút AI (bong bóng chat) ở Trang chủ',
      whatItDoes:
          'Hỏi đáp tiếng Việt về số liệu shop (doanh thu, đơn, kho, công nợ) và '
          'cách dùng mọi tính năng. Trả lời nhanh offline cho câu thường gặp.',
      whenToUse: 'Khi cần tra số nhanh hoặc quên thao tác một tính năng.',
      steps: [
        'Mở bong bóng AI, gõ hoặc nói câu hỏi.',
        'Bấm gợi ý nhanh hoặc mở màn liên quan từ nút trong câu trả lời.',
        'Bấm 👍/👎 để phản hồi chất lượng.',
      ],
      notes: [
        'Câu hỏi tài chính từ nhân viên/kỹ thuật sẽ bị từ chối theo phân quyền.',
        'AI chỉ đọc số liệu, không tự tạo/sửa đơn.',
      ],
      sampleQuestions: [
        'ai trợ lý làm được gì',
        'hỏi ai thế nào',
      ],
      tags: ['ai', 'tro ly', 'chat', 'hoi dap', 'assistant'],
      audience: ['all'],
    ),
  ];

  static KbEntry? entryById(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ─── NHÓM TÍNH NĂNG (cho màn "Tất cả tính năng") ──────────────────────────
  /// Thứ tự hiển thị + nhãn nhóm.
  static const List<(String id, String label)> areas = [
    ('home', 'Trang chủ & tổng quan'),
    ('repair', 'Sửa chữa'),
    ('sale', 'Bán hàng'),
    ('inventory', 'Kho hàng'),
    ('debt', 'Công nợ'),
    ('finance', 'Tài chính & báo cáo'),
    ('staff', 'Khách hàng & nhân viên'),
    ('system', 'Hệ thống & tiện ích'),
  ];

  /// Nhóm của một mục (suy từ id).
  static String areaOf(String id) {
    if (id.startsWith('home-')) return 'home';
    if (id.startsWith('repair') || id == 'warranty') return 'repair';
    if (id.startsWith('sale')) return 'sale';
    if (id.startsWith('inventory') ||
        id.startsWith('stock') ||
        id == 'purchase-order') {
      return 'inventory';
    }
    if (id.startsWith('debt') || id == 'data-reconciliation') return 'debt';
    if (id.startsWith('finance') ||
        id == 'cash-closing' ||
        id == 'monthly-profit' ||
        id == 'expense' ||
        id == 'money-reconcile' ||
        id == 'price-book') {
      return 'finance';
    }
    if (id == 'customers' || id == 'payroll' || id == 'attendance') {
      return 'staff';
    }
    return 'system';
  }

  /// Các mục thuộc một nhóm, giữ nguyên thứ tự khai báo.
  static List<KbEntry> entriesByArea(String areaId) =>
      [for (final e in entries) if (areaOf(e.id) == areaId) e];

  /// Câu hỏi mẫu ngẫu nhiên trải đều các nhóm — dùng cho gợi ý của AI.
  static List<String> sampleQuestionSpread(int n, {int? seed}) {
    final rnd = Random(seed ?? DateTime.now().millisecondsSinceEpoch);
    final pool = <String>[];
    final shuffledAreas = [...areas]..shuffle(rnd);
    for (final a in shuffledAreas) {
      final es = entriesByArea(a.$1)
          .where((e) => e.sampleQuestions.isNotEmpty)
          .toList()
        ..shuffle(rnd);
      if (es.isNotEmpty) {
        final qs = [...es.first.sampleQuestions]..shuffle(rnd);
        pool.add(qs.first);
      }
      if (pool.length >= n) break;
    }
    return pool.take(n).toList();
  }

  /// "Mẹo hôm nay" — 1 lưu ý xoay vòng theo ngày, kèm id mục để mở chi tiết.
  static ({String tip, String entryId})? tipOfTheDay([DateTime? now]) {
    final withNotes =
        [for (final e in entries) if (e.notes.isNotEmpty) e];
    if (withNotes.isEmpty) return null;
    final d = now ?? DateTime.now();
    final dayIndex = DateTime(d.year, d.month, d.day)
            .difference(DateTime(d.year))
            .inDays;
    final e = withNotes[dayIndex % withNotes.length];
    final note = e.notes[dayIndex % e.notes.length];
    return (tip: note, entryId: e.id);
  }
}
