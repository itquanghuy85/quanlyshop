import 'history/history_models.dart';
import 'history/history_service.dart';
import 'sync_audit_service.dart';

class RecentActivitySource {
  static const String all = 'all';
  static const String financial = 'financial';
  static const String sync = 'sync';
  static const String audit = 'audit';
}

class RecentActivityItem {
  final String id;
  final String source;
  final String domain;
  final String title;
  final String subtitle;
  final int timestamp;
  final int? amount;
  final String? direction;
  final String? status;

  /// Loại đối tượng gốc của dòng này (`sale`, `repair`, `expense`, `debt`…) và
  /// mã của nó — để bấm vào mở được màn chi tiết.
  ///
  /// Trước đây model KHÔNG mang hai trường này, nên cả màn "HOẠT ĐỘNG GẦN ĐÂY"
  /// không có dòng nào bấm được, dù dữ liệu gốc (`financial_activity_log`
  /// có `referenceType`/`referenceId`, `audit_logs` có `targetType`/`targetId`)
  /// vốn đã đủ để mở.
  final String? referenceType;
  final String? referenceId;

  const RecentActivityItem({
    required this.id,
    required this.source,
    required this.domain,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.amount,
    required this.direction,
    required this.status,
    this.referenceType,
    this.referenceId,
  });
}

class RecentActivitySnapshot {
  final DateTime generatedAt;
  final List<RecentActivityItem> items;

  const RecentActivitySnapshot({
    required this.generatedAt,
    required this.items,
  });

  int get totalCount => items.length;
  int get financialCount =>
      items.where((i) => i.source == RecentActivitySource.financial).length;
  int get syncCount =>
      items.where((i) => i.source == RecentActivitySource.sync).length;
  int get auditCount =>
      items.where((i) => i.source == RecentActivitySource.audit).length;
}

/// Feed "Hoạt động gần đây" ở trang chủ.
///
/// PHA 0: đã chuyển sang là CONSUMER của `HistoryService` — không còn tự gọi
/// `DBHelper.getFinancialActivities`/`getAuditLogs`/`SyncAuditService`
/// rời rạc rồi tự gộp như trước. Việc lấy dữ liệu + gộp theo thời gian nay
/// nằm trong `HistoryService.getRecentActivity()`; lớp này chỉ còn lo phần
/// ĐỊNH DẠNG HIỂN THỊ riêng của màn "Hoạt động gần đây" (tiêu đề/mô tả nhân
/// văn hoá tiếng Việt) — phần này đặc thù cho màn này nên không đưa vào
/// `HistoryService` dùng chung.
///
/// Toàn bộ hàm định dạng bên dưới GIỮ NGUYÊN logic như trước khi có
/// `HistoryService` — chỉ đổi nguồn đọc field từ `row` sang
/// `entry.metadata` (chính là row gốc, không mất field nào).
class RecentActivityService {
  static Future<RecentActivitySnapshot> load({
    String sourceFilter = RecentActivitySource.all,
    Duration window = const Duration(hours: 24),
    int limit = 300,
  }) async {
    final now = DateTime.now();
    final entries = await HistoryService.getRecentActivity(
      sourceFilter: _toHistoryCategory(sourceFilter),
      window: window,
      limit: limit,
    );
    final items = entries.map(_toItem).toList();
    return RecentActivitySnapshot(generatedAt: now, items: items);
  }

  /// `RecentActivitySource.*` ('financial') và `HistoryCategory.*` ('finance')
  /// cố tình đặt tên khác nhau (2 tầng độc lập) — hàm này là điểm dịch DUY
  /// NHẤT giữa 2 bộ hằng số, để không đổi API công khai của lớp này.
  static String _toHistoryCategory(String sourceFilter) {
    switch (sourceFilter) {
      case RecentActivitySource.financial:
        return HistoryCategory.finance;
      case RecentActivitySource.sync:
        return HistoryCategory.sync;
      case RecentActivitySource.audit:
        return HistoryCategory.audit;
      default:
        // Bao gồm `RecentActivitySource.all` và bất kỳ giá trị lạ nào khác —
        // giữ nguyên chuỗi để hành vi giống hệt code gốc: 'all' khớp đúng
        // điều kiện `sourceFilter == 'all'` trong `HistoryService`, còn giá
        // trị lạ (không khớp category nào) sẽ không chạy nhánh nào, cho ra
        // kết quả rỗng — đúng như code gốc khi gặp sourceFilter không hợp lệ.
        return sourceFilter;
    }
  }

  static RecentActivityItem _toItem(HistoryEntry e) {
    switch (e.category) {
      case HistoryCategory.finance:
        final row = e.metadata;
        return RecentActivityItem(
          id: e.id,
          source: RecentActivitySource.financial,
          domain: _financialDomain(row['activityType']?.toString() ?? ''),
          title: _financialTitle(row),
          subtitle: _financialSubtitle(row),
          timestamp: e.createdAt,
          amount: e.amount,
          direction: e.direction,
          status: null,
          referenceType: e.entityType,
          referenceId: e.entityId,
        );
      case HistoryCategory.sync:
        final event = e.metadata['event'] as SyncAuditEvent;
        return RecentActivityItem(
          id: e.id,
          source: RecentActivitySource.sync,
          domain: event.domainKey,
          title: _syncTitle(event),
          subtitle: _syncSubtitle(event),
          timestamp: e.createdAt,
          amount: null,
          direction: null,
          status: e.status,
        );
      case HistoryCategory.audit:
        final row = e.metadata;
        return RecentActivityItem(
          id: e.id,
          source: RecentActivitySource.audit,
          domain: row['targetType']?.toString() ?? 'system',
          title: _auditTitle(row),
          subtitle: _auditSubtitle(row),
          timestamp: e.createdAt,
          amount: null,
          direction: null,
          status: null,
          referenceType: e.entityType,
          referenceId: e.entityId,
        );
      default:
        // Không xảy ra trong PHA 0 — getRecentActivity() chỉ trả về 3 category
        // ở trên. Giữ nhánh này để không crash nếu HistoryService thêm
        // category mới mà quên cập nhật màn này (sẽ hiện dòng chung chung
        // thay vì vỡ UI).
        return RecentActivityItem(
          id: e.id,
          source: e.category,
          domain: e.category,
          title: e.title ?? 'Hoạt động',
          subtitle: e.description ?? '',
          timestamp: e.createdAt,
          amount: e.amount,
          direction: e.direction,
          status: e.status,
          referenceType: e.entityType,
          referenceId: e.entityId,
        );
    }
  }

  static String _financialDomain(String activityType) {
    final t = activityType.toUpperCase();
    if (t == 'SALE') return 'sales';
    if (t == 'REPAIR') return 'repair';
    if (t == 'EXPENSE') return 'financial';
    if (t == 'PURCHASE') return 'inventory';
    if (t == 'DEBT_COLLECT' || t == 'DEBT_PAY') return 'financial';
    if (t == 'SETTLEMENT') return 'financial';
    return 'financial';
  }

  static String _financialTitle(Map<String, dynamic> row) {
    final rawTitle = row['title']?.toString().trim() ?? '';
    if (rawTitle.isNotEmpty && !_looksTechnical(rawTitle)) {
      return rawTitle;
    }

    final type = (row['activityType']?.toString() ?? '').toUpperCase();
    final direction = (row['direction']?.toString() ?? '').toUpperCase();

    switch (type) {
      case 'SALE':
        return 'Bán hàng';
      case 'REPAIR':
        return 'Sửa chữa';
      case 'EXPENSE':
        return direction == 'IN' ? 'Thu khác' : 'Chi phí';
      case 'PURCHASE':
        return 'Nhập hàng';
      case 'DEBT_COLLECT':
        return 'Thu nợ khách hàng';
      case 'DEBT_PAY':
        return 'Trả nợ nhà cung cấp';
      case 'SETTLEMENT':
        return 'Thu tất toán trả góp';
      case 'PAYMENT_REQUEST_IN':
        return 'Nhận tiền yêu cầu đóng tiền';
      case 'PAYMENT_REQUEST_OUT':
        return 'Chi tiền yêu cầu đóng tiền';
      default:
        return 'Hoạt động tài chính';
    }
  }

  static String _financialSubtitle(Map<String, dynamic> row) {
    final description = row['description']?.toString().trim() ?? '';
    if (description.isNotEmpty && !_looksTechnical(description)) {
      return description;
    }

    final customer = row['customerName']?.toString().trim() ?? '';
    final phone = row['phone']?.toString().trim() ?? '';
    final note = row['note']?.toString().trim() ?? '';
    final parts = <String>[];

    if (customer.isNotEmpty) parts.add(customer);
    if (phone.isNotEmpty) parts.add(phone);
    if (note.isNotEmpty && !_looksTechnical(note)) parts.add(note);

    if (parts.isNotEmpty) return parts.join(' • ');
    return 'Chi tiết hoạt động tài chính';
  }

  static String _syncTitle(SyncAuditEvent event) {
    final entity = _syncEntityLabel(event.entityType);
    final outcome = _syncOutcomeLabel(event.outcome);
    return '$outcome: $entity';
  }

  static String _syncSubtitle(SyncAuditEvent event) {
    final operation = _syncOperationLabel(event.operation);
    final base = '$operation • Mã #${event.entityId}';
    final error = (event.errorMessage ?? '').trim();
    if (error.isNotEmpty) {
      return '$base • ${_safeInlineError(error)}';
    }
    return base;
  }

  static String _syncEntityLabel(String entityType) {
    switch (entityType) {
      case 'sale':
        return 'Đơn bán hàng';
      case 'repair':
        return 'Đơn sửa chữa';
      case 'expense':
        return 'Khoản thu/chi';
      case 'debt':
        return 'Công nợ';
      case 'debtPayment':
        return 'Phiếu thanh toán công nợ';
      case 'supplierPayment':
        return 'Phiếu trả nhà cung cấp';
      case 'partnerPayment':
        return 'Phiếu trả đối tác sửa chữa';
      case 'product':
        return 'Sản phẩm/kho';
      case 'purchaseOrder':
        return 'Đơn nhập hàng';
      case 'cashClosing':
        return 'Chốt quỹ';
      case 'customer':
        return 'Khách hàng';
      default:
        return 'Dữ liệu hệ thống';
    }
  }

  static String _syncOperationLabel(String operation) {
    switch (operation.toLowerCase()) {
      case 'insert':
      case 'create':
        return 'Tạo mới';
      case 'update':
      case 'upsert':
        return 'Cập nhật';
      case 'delete':
        return 'Xóa';
      case 'sync':
        return 'Đồng bộ';
      default:
        return 'Đồng bộ dữ liệu';
    }
  }

  static String _syncOutcomeLabel(String outcome) {
    switch (outcome.toLowerCase()) {
      case 'success':
        return 'Đồng bộ thành công';
      case 'retry':
        return 'Đang thử đồng bộ lại';
      case 'failed':
        return 'Đồng bộ thất bại';
      default:
        return 'Trạng thái đồng bộ';
    }
  }

  static String _auditTitle(Map<String, dynamic> row) {
    final action = row['action']?.toString().trim() ?? '';
    if (action.isEmpty) return 'Nhật ký hệ thống';

    const directMap = {
      'DEBT_COLLECTED': 'Thu nợ khách hàng',
      'DEBT_COLLECT': 'Thu nợ khách hàng',
      'SUPPLIER_PAID': 'Trả nợ nhà cung cấp',
      'PART_IMPORT': 'Nhập kho linh kiện',
      'PART_INFO_UPDATE': 'Cập nhật thông tin linh kiện',
      'PART_ADD_STOCK': 'Bổ sung tồn kho linh kiện',
      'DELETE_PART': 'Xóa linh kiện',
      'PAYMENT_REQUEST_APPROVED': 'Duyệt yêu cầu đóng tiền',
      'PAYMENT_REQUEST_REJECTED': 'Từ chối yêu cầu đóng tiền',
      'PAYMENT_REQUEST_CREATED': 'Tạo yêu cầu đóng tiền',
    };

    final upper = action.toUpperCase();
    if (directMap.containsKey(upper)) {
      return directMap[upper]!;
    }

    return _humanizeActionLabel(action);
  }

  static String _auditSubtitle(Map<String, dynamic> row) {
    final description = row['description']?.toString().trim() ?? '';
    if (description.isNotEmpty && !_looksTechnical(description)) {
      return description;
    }

    final userName = row['userName']?.toString().trim() ?? '';
    final targetType = row['targetType']?.toString().trim() ?? '';
    final targetId = row['targetId']?.toString().trim() ?? '';

    final parts = <String>[];
    if (userName.isNotEmpty) parts.add('Bởi $userName');
    if (targetType.isNotEmpty) {
      final typeLabel = _humanizeActionLabel(targetType);
      if (targetId.isNotEmpty) {
        parts.add('$typeLabel #$targetId');
      } else {
        parts.add(typeLabel);
      }
    }

    if (parts.isNotEmpty) return parts.join(' • ');
    return 'Chi tiết nhật ký hệ thống';
  }

  static String _humanizeActionLabel(String input) {
    final normalized = _normalizeHumanText(input);
    if (normalized.isEmpty) return 'Nhật ký hệ thống';

    // Preserve human-readable Vietnamese action strings as-is.
    if (!_looksLikeTechnicalCode(normalized)) {
      return normalized;
    }

    // Keep Vietnamese accents even when legacy data used underscores.
    if (normalized.contains('_') && RegExp(r'[^\x00-\x7F]').hasMatch(normalized)) {
      return normalized.replaceAll('_', ' ');
    }

    return _humanizeActionCode(normalized);
  }

  static String _normalizeHumanText(String input) {
    return input.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _looksLikeTechnicalCode(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;
    if (_looksTechnical(raw)) return true;
    if (raw.contains('_')) return true;

    final asciiOnly = RegExp(r'^[A-Za-z0-9 ]+$').hasMatch(raw);
    if (!asciiOnly) return false;

    final letters = raw.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) return false;
    return letters == letters.toUpperCase();
  }

  static String _humanizeActionCode(String input) {
    final normalized = input
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ', '_')
        .toUpperCase();

    final tokens = normalized.split('_').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return 'Nhật ký hệ thống';

    const tokenMap = {
      'DEBT': 'công nợ',
      'COLLECT': 'thu',
      'COLLECTED': 'đã thu',
      'PAY': 'trả',
      'PAID': 'đã trả',
      'SUPPLIER': 'nhà cung cấp',
      'CUSTOMER': 'khách hàng',
      'PART': 'linh kiện',
      'STOCK': 'tồn kho',
      'IMPORT': 'nhập kho',
      'ADD': 'thêm',
      'UPDATE': 'cập nhật',
      'EDIT': 'chỉnh sửa',
      'DELETE': 'xóa',
      'REMOVE': 'xóa',
      'CREATE': 'tạo',
      'PAYMENT': 'thanh toán',
      'REQUEST': 'yêu cầu',
      'APPROVED': 'đã duyệt',
      'REJECTED': 'đã từ chối',
      'REPAIR': 'sửa chữa',
      'SALE': 'bán hàng',
      'SYSTEM': 'hệ thống',
      'LOG': 'nhật ký',
      'SYNC': 'đồng bộ',
    };

    final words = tokens.map((t) => tokenMap[t] ?? t.toLowerCase()).toList();
    final sentence = words.join(' ').trim();
    if (sentence.isEmpty) return 'Nhật ký hệ thống';
    return '${sentence[0].toUpperCase()}${sentence.substring(1)}';
  }

  static bool _looksTechnical(String text) {
    final value = text.trim();
    if (value.isEmpty) return false;
    final upper = value.toUpperCase();
    if (upper.contains('SYNC ') || upper.contains('SYNC_')) return true;
    if (upper.contains('DEBT_') || upper.contains('PAYMENT_REQUEST_')) {
      return true;
    }
    if (upper.contains('#') && upper.contains('ID')) return true;
    return false;
  }

  static String _safeInlineError(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 90) return cleaned;
    return '${cleaned.substring(0, 90)}...';
  }
}
