import 'dart:convert';

/// Danh mục giá ("Bảng giá từ hoá đơn NCC") — mô hình dữ liệu.
///
/// Khác `PricePin` (giá ghim lưu SharedPreferences theo máy): danh mục này
/// lưu trong SQLite + đồng bộ Firestore theo `shopId`, nên mọi thiết bị
/// trong cùng shop đều tra cứu được.

/// Một DÒNG hoá đơn NCC đọc từ sheet "Chi tiết nhập hàng".
///
/// Giữ nguyên theo từng hoá đơn (không gộp) — việc gộp thành giá vốn gần
/// nhất/thấp nhất/cao nhất/bình quân gia quyền do [PriceCatalogItem] làm.
class InvoiceCostLine {
  final String dataType; // "Loại dữ liệu": phụ tùng / dịch vụ / …
  final String group; // "Nhóm"
  final String brand; // "Hãng"
  final String name; // "Tên mặt hàng"
  final String compatibleModels; // "Model tương thích"
  final String partType; // "Loại linh kiện"
  final String sku; // "Mã hàng/SKU"
  final String unit; // "Đơn vị tính"
  final int qty; // "Số lượng"
  final int unitPrice; // "Đơn giá nhập"
  final int discount; // "Chiết khấu"
  final int tax; // "Thuế"
  final int lineTotal; // "Thành tiền"
  final int cost; // "Giá vốn" (giá nhập thực tế theo đơn vị)
  final int? customerPrice; // "Giá thu khách" — null = chưa nhập
  final String supplier; // "Nhà cung cấp"
  final String invoiceNo; // "Số hóa đơn"
  final String invoiceDate; // "Ngày hóa đơn" (YYYY-MM-DD)
  final String note; // "Ghi chú"
  final String imageSource; // "Nguồn ảnh"
  final String confidence; // "Mức độ tin cậy"
  final String errorNote; // "Lỗi cần kiểm tra"
  final String importKey; // "_khóa_import"

  /// Sheet + số dòng gốc — để báo lỗi cho người dùng biết sửa ở đâu.
  final String sheetName;
  final int rowNumber;

  const InvoiceCostLine({
    this.dataType = '',
    this.group = '',
    this.brand = '',
    required this.name,
    this.compatibleModels = '',
    this.partType = '',
    this.sku = '',
    this.unit = '',
    this.qty = 1,
    this.unitPrice = 0,
    this.discount = 0,
    this.tax = 0,
    this.lineTotal = 0,
    this.cost = 0,
    this.customerPrice,
    this.supplier = '',
    this.invoiceNo = '',
    this.invoiceDate = '',
    this.note = '',
    this.imageSource = '',
    this.confidence = '',
    this.errorNote = '',
    this.importKey = '',
    this.sheetName = '',
    this.rowNumber = 0,
  });

  /// Một dòng hoá đơn liệt kê NHIỀU model tương thích (vd 1 màn hình dùng
  /// chung cho 12 máy) — phải để người dùng tự kiểm tra, KHÔNG tự tách thành
  /// nhiều mặt hàng (dễ tạo dữ liệu rác/sai).
  bool get hasMultipleModels {
    final s = compatibleModels.trim();
    if (s.isEmpty) return false;
    return s.contains(',') || s.contains(';') || s.contains('/');
  }

  bool get needsReview =>
      errorNote.trim().isNotEmpty ||
      hasMultipleModels ||
      _lowConfidence(confidence);

  static bool _lowConfidence(String c) {
    final s = c.trim().toLowerCase();
    return s == 'thấp' || s == 'thap' || s == 'low';
  }
}

/// Một mặt hàng trong danh mục giá của shop (bảng `price_catalog_items`).
class PriceCatalogItem {
  final int? id;
  final String? firestoreId;

  /// Khoá ổn định để nhận diện & cập nhật (cột `_khóa_import` của Excel).
  final String importKey;

  final String itemName;
  final String brand;
  final String model;
  final String partType;
  final String sku;
  final String unit;
  final String supplier;

  /// Giá vốn gần nhất (theo ngày hoá đơn mới nhất).
  final int lastCost;

  /// Giá vốn bình quân GIA QUYỀN theo số lượng.
  final int avgCost;
  final int minCost;
  final int maxCost;

  /// Giá thu khách — 0 nghĩa là CHƯA thiết lập. Không bao giờ tự suy từ giá
  /// vốn: nhân viên báo giá phải thấy rõ "chưa có giá" thay vì báo nhầm vốn.
  final int customerPrice;

  final String lastInvoiceNo;
  final String lastInvoiceDate; // YYYY-MM-DD
  final String note;

  /// Nguồn dữ liệu: 'supplier_invoice_excel' | 'manual'.
  final String sourceType;

  /// Cần người dùng kiểm tra lại (nhiều model tương thích, độ tin cậy thấp…).
  final bool needsReview;
  final String reviewNote;
  final String confidence;

  /// Lịch sử giá theo từng dòng hoá đơn — JSON list các [CostHistoryEntry].
  /// Là nguồn tính lại toàn bộ [lastCost]/[avgCost]/[minCost]/[maxCost], và
  /// là cơ chế chống trùng khi nhập lại CÙNG một file.
  final List<CostHistoryEntry> costHistory;

  final int createdAt;
  final int updatedAt;
  final bool deleted;
  final String? shopId;
  final bool isSynced;

  const PriceCatalogItem({
    this.id,
    this.firestoreId,
    required this.importKey,
    required this.itemName,
    this.brand = '',
    this.model = '',
    this.partType = '',
    this.sku = '',
    this.unit = '',
    this.supplier = '',
    this.lastCost = 0,
    this.avgCost = 0,
    this.minCost = 0,
    this.maxCost = 0,
    this.customerPrice = 0,
    this.lastInvoiceNo = '',
    this.lastInvoiceDate = '',
    this.note = '',
    this.sourceType = 'supplier_invoice_excel',
    this.needsReview = false,
    this.reviewNote = '',
    this.confidence = '',
    this.costHistory = const [],
    this.createdAt = 0,
    this.updatedAt = 0,
    this.deleted = false,
    this.shopId,
    this.isSynced = false,
  });

  bool get hasCustomerPrice => customerPrice > 0;

  /// Lợi nhuận tham khảo — chỉ có nghĩa khi đã thiết lập giá thu khách.
  int get referenceProfit =>
      hasCustomerPrice && lastCost > 0 ? customerPrice - lastCost : 0;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'firestoreId': firestoreId,
        'importKey': importKey,
        'itemName': itemName,
        'brand': brand,
        'model': model,
        'partType': partType,
        'sku': sku,
        'unit': unit,
        'supplier': supplier,
        'lastCost': lastCost,
        'avgCost': avgCost,
        'minCost': minCost,
        'maxCost': maxCost,
        'customerPrice': customerPrice,
        'lastInvoiceNo': lastInvoiceNo,
        'lastInvoiceDate': lastInvoiceDate,
        'note': note,
        'sourceType': sourceType,
        'needsReview': needsReview ? 1 : 0,
        'reviewNote': reviewNote,
        'confidence': confidence,
        'costHistoryJson': encodeHistory(costHistory),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'deleted': deleted ? 1 : 0,
        'shopId': shopId,
        'isSynced': isSynced ? 1 : 0,
      };

  factory PriceCatalogItem.fromMap(Map<String, dynamic> m) => PriceCatalogItem(
        id: m['id'] as int?,
        firestoreId: m['firestoreId'] as String?,
        importKey: (m['importKey'] as String?) ?? '',
        itemName: (m['itemName'] as String?) ?? '',
        brand: (m['brand'] as String?) ?? '',
        model: (m['model'] as String?) ?? '',
        partType: (m['partType'] as String?) ?? '',
        sku: (m['sku'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? '',
        supplier: (m['supplier'] as String?) ?? '',
        lastCost: _int(m['lastCost']),
        avgCost: _int(m['avgCost']),
        minCost: _int(m['minCost']),
        maxCost: _int(m['maxCost']),
        customerPrice: _int(m['customerPrice']),
        lastInvoiceNo: (m['lastInvoiceNo'] as String?) ?? '',
        lastInvoiceDate: (m['lastInvoiceDate'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
        sourceType: (m['sourceType'] as String?) ?? 'supplier_invoice_excel',
        needsReview: _bool(m['needsReview']),
        reviewNote: (m['reviewNote'] as String?) ?? '',
        confidence: (m['confidence'] as String?) ?? '',
        costHistory: decodeHistory(m['costHistoryJson'] as String?),
        createdAt: _int(m['createdAt']),
        updatedAt: _int(m['updatedAt']),
        deleted: _bool(m['deleted']),
        shopId: m['shopId'] as String?,
        isSynced: _bool(m['isSynced']),
      );

  PriceCatalogItem copyWith({
    int? id,
    String? firestoreId,
    String? itemName,
    String? brand,
    String? model,
    String? partType,
    String? sku,
    String? unit,
    String? supplier,
    int? lastCost,
    int? avgCost,
    int? minCost,
    int? maxCost,
    int? customerPrice,
    String? lastInvoiceNo,
    String? lastInvoiceDate,
    String? note,
    String? sourceType,
    bool? needsReview,
    String? reviewNote,
    String? confidence,
    List<CostHistoryEntry>? costHistory,
    int? createdAt,
    int? updatedAt,
    bool? deleted,
    String? shopId,
    bool? isSynced,
  }) =>
      PriceCatalogItem(
        id: id ?? this.id,
        firestoreId: firestoreId ?? this.firestoreId,
        importKey: importKey,
        itemName: itemName ?? this.itemName,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        partType: partType ?? this.partType,
        sku: sku ?? this.sku,
        unit: unit ?? this.unit,
        supplier: supplier ?? this.supplier,
        lastCost: lastCost ?? this.lastCost,
        avgCost: avgCost ?? this.avgCost,
        minCost: minCost ?? this.minCost,
        maxCost: maxCost ?? this.maxCost,
        customerPrice: customerPrice ?? this.customerPrice,
        lastInvoiceNo: lastInvoiceNo ?? this.lastInvoiceNo,
        lastInvoiceDate: lastInvoiceDate ?? this.lastInvoiceDate,
        note: note ?? this.note,
        sourceType: sourceType ?? this.sourceType,
        needsReview: needsReview ?? this.needsReview,
        reviewNote: reviewNote ?? this.reviewNote,
        confidence: confidence ?? this.confidence,
        costHistory: costHistory ?? this.costHistory,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
        shopId: shopId ?? this.shopId,
        isSynced: isSynced ?? this.isSynced,
      );

  static int _int(dynamic v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0);

  static bool _bool(dynamic v) => v == true || v == 1 || v == '1';

  static String encodeHistory(List<CostHistoryEntry> h) =>
      jsonEncode(h.map((e) => e.toJson()).toList());

  static List<CostHistoryEntry> decodeHistory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => CostHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

/// Một lần nhập hàng đã ghi nhận cho 1 mặt hàng (1 dòng của 1 hoá đơn).
///
/// [fingerprint] để nhận diện dòng đã ghi — nhập lại CÙNG file thì dòng đó
/// bị coi là trùng và KHÔNG cộng thêm vào bình quân gia quyền.
class CostHistoryEntry {
  final String fingerprint;
  final String invoiceNo;
  final String invoiceDate; // YYYY-MM-DD
  final int unitCost;
  final int qty;
  final String supplier;

  const CostHistoryEntry({
    required this.fingerprint,
    this.invoiceNo = '',
    this.invoiceDate = '',
    required this.unitCost,
    this.qty = 1,
    this.supplier = '',
  });

  /// Khoá JSON viết tắt — danh sách này đi lên Firestore, giữ nhỏ gọn.
  Map<String, dynamic> toJson() => {
        'fp': fingerprint,
        if (invoiceNo.isNotEmpty) 'no': invoiceNo,
        if (invoiceDate.isNotEmpty) 'd': invoiceDate,
        'p': unitCost,
        'q': qty,
        if (supplier.isNotEmpty) 's': supplier,
      };

  factory CostHistoryEntry.fromJson(Map<String, dynamic> j) => CostHistoryEntry(
        fingerprint: (j['fp'] as String?) ?? '',
        invoiceNo: (j['no'] as String?) ?? '',
        invoiceDate: (j['d'] as String?) ?? '',
        unitCost: PriceCatalogItem._int(j['p']),
        qty: PriceCatalogItem._int(j['q']),
        supplier: (j['s'] as String?) ?? '',
      );
}

/// Người dùng chọn xử lý thế nào với mặt hàng ĐÃ CÓ trong danh mục.
enum CatalogExistingPolicy {
  /// Cập nhật (gộp thêm lịch sử giá, tính lại bình quân).
  update,

  /// Bỏ qua — giữ nguyên bản ghi cũ.
  skip,
}

/// Kết quả PHÂN TÍCH file Excel trước khi ghi (bản xem trước).
class CatalogImportPreview {
  final List<InvoiceCostLine> lines;

  /// Mặt hàng sau khi gộp các dòng hoá đơn theo `_khóa_import`.
  final List<PriceCatalogItem> newItems;
  final List<PriceCatalogItem> updatedItems;

  /// Khoá → mặt hàng đang có trong danh mục (để hiển thị giá cũ).
  final Map<String, PriceCatalogItem> existing;

  final int validRows;
  final int duplicateRows; // dòng hoá đơn đã ghi nhận từ lần nhập trước
  final int missingNameRows;
  final int missingCostRows;
  final int emptyCustomerPriceItems;
  final int needsReviewItems;
  final int invalidQtyRows;

  /// Lỗi cấu trúc file (thiếu cột, sai sheet…) + lỗi từng dòng.
  final List<String> errors;

  /// Cảnh báo không chặn nhập (vd sheet phụ bị thiếu).
  final List<String> warnings;

  const CatalogImportPreview({
    this.lines = const [],
    this.newItems = const [],
    this.updatedItems = const [],
    this.existing = const {},
    this.validRows = 0,
    this.duplicateRows = 0,
    this.missingNameRows = 0,
    this.missingCostRows = 0,
    this.emptyCustomerPriceItems = 0,
    this.needsReviewItems = 0,
    this.invalidQtyRows = 0,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get isEmpty => newItems.isEmpty && updatedItems.isEmpty;
  int get totalItems => newItems.length + updatedItems.length;

  /// File sai cấu trúc hoàn toàn (không đọc được sheet/cột bắt buộc).
  bool get isFatal => lines.isEmpty && newItems.isEmpty && updatedItems.isEmpty;
}

/// Kết quả SAU KHI ghi vào danh mục.
class CatalogImportResult {
  final int created;
  final int updated;
  final int skipped;
  final int failed;
  final List<String> errors;

  const CatalogImportResult({
    this.created = 0,
    this.updated = 0,
    this.skipped = 0,
    this.failed = 0,
    this.errors = const [],
  });

  int get total => created + updated + skipped + failed;
}
