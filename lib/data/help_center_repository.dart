import 'package:flutter/material.dart';

import 'app_knowledge_base.dart';

/// Data models for in-app help center.
class HelpCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> audience; // Role codes that should see this category

  const HelpCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.audience = const ['all'],
  });
}

class HelpTopic {
  final String id;
  final String categoryId;
  final String title;
  final String summary;
  final List<String> steps;
  final List<String> tips;
  final List<String> tags;
  final List<String> audience;
  final String difficulty;
  final String? estimatedTime;
  final List<String> prerequisites;
  final List<String> resources;
  final List<String> relatedTopicIds;
  final bool isFeatured;
  final String? videoUrl;

  const HelpTopic({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.summary,
    required this.steps,
    this.tips = const [],
    this.tags = const [],
    this.audience = const ['all'],
    this.difficulty = 'Cơ bản',
    this.estimatedTime,
    this.prerequisites = const [],
    this.resources = const [],
    this.relatedTopicIds = const [],
    this.isFeatured = false,
    this.videoUrl,
  });
}

/// Static repository for help content. This can later be moved to Firestore.
class HelpCenterRepository {
  static final List<HelpCategory> categories = [
    const HelpCategory(
      id: 'inventory',
      title: 'Quản lý kho',
      description: 'Nhập hàng, kiểm kho, in tem và đồng bộ số lượng giữa các thiết bị.',
      icon: Icons.inventory_2,
      audience: ['all'],
    ),
    const HelpCategory(
      id: 'repairs',
      title: 'Đơn sửa chữa',
      description: 'Quy trình tạo đơn, cập nhật trạng thái, bàn giao và hạch toán đơn sửa chữa.',
      icon: Icons.build_circle,
      audience: ['technician', 'manager', 'owner'],
    ),
    const HelpCategory(
      id: 'sales',
      title: 'Bán hàng và công nợ',
      description: 'Tạo hóa đơn bán lẻ, thu công nợ, in phiếu và xem báo cáo doanh thu.',
      icon: Icons.point_of_sale,
      audience: ['manager', 'owner', 'cashier'],
    ),
    const HelpCategory(
      id: 'finance',
      title: 'Tài chính & báo cáo',
      description: 'Tổng quan lời lỗ, dòng tiền, quỹ và nhật ký chi tiêu.',
      icon: Icons.analytics_outlined,
      audience: ['owner', 'manager'],
    ),
    const HelpCategory(
      id: 'setup',
      title: 'Thiết lập hệ thống',
      description: 'Tài khoản, phân quyền, đồng bộ dữ liệu và sao lưu.',
      icon: Icons.settings_suggest,
      audience: ['owner', 'admin'],
    ),
  ];

  /// Mục hướng dẫn biên tập thủ công (giữ nguyên).
  static final List<HelpTopic> _curatedTopics = [
    const HelpTopic(
      id: 'glossary-finance-debt',
      categoryId: 'finance',
      title: 'Thuật ngữ tài chính & công nợ (giải thích dễ hiểu)',
      summary:
          'Các khái niệm hay gây nhầm: dồn tích vs dòng tiền, chốt quỹ, công nợ, trả góp NH, giá vốn.',
      steps: [
        'DÒNG TIỀN (cash): tiền THỰC SỰ đã vào/ra két và tài khoản. Ví dụ: bán 10tr nhưng khách nợ 4tr → dòng tiền chỉ +6tr.',
        'DỒN TÍCH (accrual): ghi nhận doanh thu/lãi ngay khi bán, dù chưa thu đủ tiền. Ví dụ: bán 10tr công nợ → doanh thu +10tr, lãi tính đủ, nhưng tiền chưa về. Báo cáo lãi/lỗ dùng cách này.',
        'Vì sao 2 con số khác nhau: "Lãi gộp (phần đã thu)" là theo dòng tiền; "Lợi nhuận (accrual)" là theo dồn tích. Khách còn nợ nhiều thì 2 số lệch nhau — đó là bình thường.',
        'CHỐT QUỸ (Sổ quỹ): cuối ngày đếm tiền mặt + số dư ngân hàng thực tế, nhập vào app. App so: Kỳ vọng = Đầu kỳ + Thu trong ngày − Chi trong ngày. Lệch = thừa/thiếu quỹ cần tìm nguyên nhân.',
        'CÔNG NỢ PHẢI THU: khách đang nợ shop. PHẢI TRẢ: shop đang nợ (nhà cung cấp, đối tác sửa chữa). Nợ tự sinh khi bán/nhập chọn "CÔNG NỢ".',
        'THU NỢ / THANH TOÁN NỢ: mỗi lần nhận/trả tiền bấm nút tương ứng, được trả từng phần. Số "đã trả" cộng dồn và đồng bộ mọi máy.',
        'TRẢ GÓP (NH): khách đưa tiền CỌC, phần còn lại NGÂN HÀNG cho vay. Chỉ tiền cọc tính là tiền shop thu ngay; tiền NH ghi nhận khi ngân hàng tất toán (giải ngân) cho shop.',
        'GIÁ VỐN: số tiền shop bỏ ra để có món hàng (giá nhập). LÃI = Giá bán − Giá vốn. SP thiếu giá vốn sẽ hiện cảnh báo vì không tính được lãi.',
        'TỒN KHO (giá vốn): tổng giá vốn của hàng còn trong kho — là "tiền đang nằm ở hàng hoá".',
      ],
      tips: [
        'Khách nợ nhiều → "tiền vào" ít hơn "doanh thu": không phải lỗi, chỉ là chưa thu.',
        'Chốt quỹ mỗi ngày giúp phát hiện thất thoát sớm.',
        'Mỗi màn có nút ⓘ ở góc trên — bấm để xem lại hướng dẫn bất cứ lúc nào.',
      ],
      tags: ['tài chính', 'công nợ', 'thuật ngữ', 'chốt quỹ', 'trả góp'],
      audience: ['manager', 'owner', 'cashier'],
      difficulty: 'Cơ bản',
      estimatedTime: '4 phút',
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'inventory-fast-check',
      categoryId: 'inventory',
      title: 'Kiểm kho nhanh bằng QR',
      summary: 'Chuẩn bị thiết bị, in tem và quét mã để kiểm tra tồn kho.',
      steps: [
        'Vào Kho > Kiểm kho nhanh và chọn khu vực cần kiểm.',
        'In tem QR nếu sản phẩm chưa có mã bằng nút In tem trong chi tiết sản phẩm.',
        'Nhấn Bắt đầu quét và đưa camera vào mã (hỗ trợ mã ngắn 4-5 số hoặc IMEI).',
        'Quan sát checklist bên phải: hàng thiếu sẽ được đánh dấu đỏ.',
        'Sau khi hoàn tất, nhấn Xuất báo cáo để lưu kết quả.',
      ],
      tips: [
        'Có thể bật âm thanh và rung để phản hồi mỗi khi mã được quét.',
        'Nếu thiếu ánh sáng, bật đèn flash ngay trong màn hình quét.',
      ],
      tags: ['qr', 'inventory', 'scan'],
      audience: ['all'],
      difficulty: 'Cơ bản',
      estimatedTime: '5 phút',
      prerequisites: [
        'Máy có camera hoạt động tốt',
        'Đã dán tem QR cho sản phẩm',
      ],
      resources: [
        'Video demo thao tác trên kho mẫu',
        'Checklist kiểm kho chuẩn PDF',
      ],
      relatedTopicIds: ['inventory-print-label', 'setup-sync-data'],
      isFeatured: true,
      videoUrl: 'https://youtu.be/dummy-fast-check',
    ),
    const HelpTopic(
      id: 'inventory-print-label',
      categoryId: 'inventory',
      title: 'In tem sản phẩm',
      summary: 'Tạo tem QR với giá bán, bảo hành và mã sản phẩm.',
      steps: [
        'Từ màn hình Kho, chọn sản phẩm và nhấn nút In tem.',
        'Chọn mẫu tem phù hợp (Kiểm kho, Bán hàng, Khuyến mãi, Bảo hành).',
        'Điền số lượng cần in, xem trước nội dung tem.',
        'Nếu cần tùy chỉnh, mở mục "Tùy chỉnh nội dung tem" để bật/tắt các trường.',
        'Kết nối máy in bluetooth và nhấn In.',
      ],
      tips: [
        'Tem kiểm kho dùng mã "check_product:" nên có thể quét lại trong tính năng Kiểm kho.',
        'Giá CPK có thể cấu hình trong phần Cài đặt tem để tự động tính theo hệ số.',
      ],
      tags: ['label', 'printing'],
      audience: ['all'],
      difficulty: 'Trung bình',
      estimatedTime: '7 phút',
      prerequisites: [
        'Máy in nhiệt bluetooth đã ghép đôi',
        'Đã thiết lập mẫu tem trong phần Thiết kế tem',
      ],
      resources: [
        'Tài liệu hướng dẫn cài đặt máy in SUNMI',
        'Template Excel nhập nhanh dữ liệu tem',
      ],
      relatedTopicIds: ['inventory-fast-check', 'sales-create-invoice'],
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'repairs-create-order',
      categoryId: 'repairs',
      title: 'Tạo đơn sửa mới',
      summary: 'Lập đơn nhận máy, ghi nhận tình trạng và phụ tùng dự kiến.',
      steps: [
        'Vào tab Sửa chữa > nhấn dấu + để tạo đơn mới.',
        'Nhập thông tin khách hàng, thiết bị, tình trạng ban đầu và ghi chú hẹn.',
        'Chọn nhân viên kỹ thuật phụ trách và tải ảnh biên bản nếu có.',
        'Lưu đơn để hệ thống cấp mã và đưa vào danh sách chờ sửa.',
      ],
      tips: [
        'Có thể quét QR/IMEI để tự động điền thông tin thiết bị.',
        'Khi hoàn tất sửa chữa, chuyển trạng thái để kích hoạt thông báo cho khách.',
      ],
      tags: ['repair', 'order'],
      audience: ['technician', 'manager'],
      difficulty: 'Cơ bản',
      estimatedTime: '4 phút',
      prerequisites: [
        'Đã bật đồng bộ khách hàng với Cloud',
      ],
      resources: [
        'Biểu mẫu biên nhận bàn giao PDF',
      ],
      relatedTopicIds: ['setup-sync-data'],
      isFeatured: true,
    ),
    const HelpTopic(
      id: 'sales-create-invoice',
      categoryId: 'sales',
      title: 'Tạo hóa đơn bán lẻ',
      summary: 'Chọn hàng hóa, phụ kiện và in hóa đơn bán hàng.',
      steps: [
        'Vào tab Bán hàng > nhấn nút Tạo hóa đơn.',
        'Tìm sản phẩm bằng tên, mã, IMEI hoặc quét QR.',
        'Chọn số lượng, giá bán và ghi chú bảo hành nếu cần.',
        'Nhập thông tin khách hàng và hình thức thanh toán.',
        'Hoàn tất để lưu hóa đơn, có thể in tem và gửi hóa đơn qua Zalo/SMS.',
      ],
      tips: [
        'Sử dụng công nợ khi khách thanh toán một phần và cần theo dõi thu sau.',
        'Sau khi bán có thể tự động trừ tồn kho nếu sản phẩm được liên kết kho.',
      ],
      tags: ['sales', 'invoice'],
      audience: ['cashier', 'manager'],
      difficulty: 'Trung bình',
      estimatedTime: '6 phút',
      prerequisites: [
        'Đã liên kết máy in hóa đơn',
      ],
      resources: [
        'Video thao tác tạo hóa đơn trên Android',
        'Checklist thu ngân ca tối',
      ],
      relatedTopicIds: ['inventory-print-label'],
      isFeatured: false,
    ),
    const HelpTopic(
      id: 'setup-sync-data',
      categoryId: 'setup',
      title: 'Đồng bộ dữ liệu giữa nhiều máy',
      summary: 'Kiểm tra trạng thái sync và xử lý khi bị treo.',
      steps: [
        'Ở tab Cài đặt, kiểm tra mục Đồng bộ xem đã đăng nhập cùng Shop chưa.',
        'Nhấn "Đồng bộ ngay" để đẩy dữ liệu lên cloud.',
        'Nếu máy phụ không lên dữ liệu, vào mục "Tải lại dữ liệu từ cloud".',
        'Đảm bảo kết nối internet ổn định trong suốt quá trình sync.',
      ],
      tips: [
        'Super admin có thể đổi sang shop khác bằng nút "Chọn shop khác".',
        'Kiểm tra nhật ký sync trong SYNC_SYSTEM_GUIDE.md nếu cần debug sâu.',
      ],
      tags: ['sync', 'cloud'],
      audience: ['owner', 'admin', 'manager'],
      difficulty: 'Nâng cao',
      estimatedTime: '10 phút',
      prerequisites: [
        'Đã đăng nhập cùng tài khoản trên các thiết bị',
        'Kết nối internet ổn định',
      ],
      resources: [
        'Bảng kiểm tra sự cố đồng bộ',
        'Video hướng dẫn đồng bộ lần đầu',
      ],
      relatedTopicIds: ['inventory-fast-check'],
      isFeatured: true,
    ),
  ];

  /// Mục hướng dẫn dựng tự động từ [AppKnowledgeBase] — DÙNG CHUNG một nguồn
  /// sự thật với AI Trợ Lý. Sửa nội dung tại `lib/data/app_knowledge_base.dart`.
  static final List<HelpTopic> _kbTopics = [
    for (final e in AppKnowledgeBase.entries)
      HelpTopic(
        id: 'kb-${e.id}',
        categoryId: _kbCategoryFor(e.id),
        title: e.title,
        summary: e.whatItDoes.length > 160
            ? '${e.whatItDoes.substring(0, 158)}…'
            : e.whatItDoes,
        steps: [
          '📍 ${e.menuPath}',
          if (e.steps.isNotEmpty)
            ...e.steps
          else if (e.whenToUse.isNotEmpty)
            'Khi nào dùng: ${e.whenToUse}',
        ],
        tips: [
          for (final id in e.terms)
            if (AppKnowledgeBase.termById(id) case final t?)
              '${t.term}: ${t.definition}',
          ...e.notes,
        ],
        tags: e.tags,
        audience: e.audience,
      ),
  ];

  static String _kbCategoryFor(String id) {
    if (id.startsWith('repair') || id == 'warranty') return 'repairs';
    if (id.startsWith('sale')) return 'sales';
    if (id.startsWith('debt') ||
        id == 'data-reconciliation' ||
        id == 'customers') {
      return 'sales';
    }
    if (id.startsWith('inventory') ||
        id.startsWith('stock') ||
        id == 'purchase-order') {
      return 'inventory';
    }
    if (id.startsWith('finance') ||
        id.startsWith('bank-') ||
        id == 'cash-closing' ||
        id == 'monthly-profit' ||
        id == 'expense' ||
        id == 'money-reconcile' ||
        id.startsWith('price-book') ||
        id == 'payroll' ||
        id == 'attendance' ||
        id.startsWith('home-')) {
      return 'finance';
    }
    return 'setup';
  }

  /// Danh sách hiển thị = mục biên tập thủ công + mục sinh từ Knowledge Base.
  static final List<HelpTopic> topics = [..._curatedTopics, ..._kbTopics];

  static List<HelpTopic> searchTopics(String query, {String? audience}) {
    final lower = query.trim().toLowerCase();
    return topics.where((topic) {
      final matchesAudience = audience == null || audience == 'all'
          ? true
          : topic.audience.contains('all') || topic.audience.contains(audience);
      if (!matchesAudience) return false;
      if (lower.isEmpty) return true;
      final haystack = (
        topic.title +
        topic.summary +
        topic.steps.join(' ') +
        topic.tips.join(' ') +
        topic.tags.join(' ')
      ).toLowerCase();
      return haystack.contains(lower);
    }).toList();
  }

  static List<HelpTopic> topicsByCategory(String categoryId, {String? audience}) {
    return topics.where((topic) {
      final matchesCategory = topic.categoryId == categoryId;
      final matchesAudience = audience == null || audience == 'all'
          ? true
          : topic.audience.contains('all') || topic.audience.contains(audience);
      return matchesCategory && matchesAudience;
    }).toList();
  }

  static List<HelpTopic> featuredTopics({String? audience}) {
    return topics.where((topic) {
      final matchesAudience = audience == null || audience == 'all'
          ? true
          : topic.audience.contains('all') || topic.audience.contains(audience);
      return topic.isFeatured && matchesAudience;
    }).toList();
  }

  static List<HelpTopic> relatedTopics(HelpTopic topic, {String? audience}) {
    if (topic.relatedTopicIds.isEmpty) return const [];
    final allowedAudience = audience ?? 'all';
    return topics.where((candidate) {
      if (candidate.id == topic.id) return false;
      if (!topic.relatedTopicIds.contains(candidate.id)) return false;
      if (allowedAudience == 'all') return true;
      return candidate.audience.contains('all') ||
          candidate.audience.contains(allowedAudience);
    }).toList();
  }

  static HelpCategory? findCategory(String id) {
    try {
      return categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
