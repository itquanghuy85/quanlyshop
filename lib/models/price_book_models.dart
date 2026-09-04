import 'price_catalog_models.dart';

/// Nguồn giá của một dòng bảng giá.
enum PriceSource {
  /// Chủ shop đã GHIM (giá niêm yết chính thức).
  pinned,

  /// Trung vị tự tính từ lịch sử.
  auto,

  /// Chưa đủ dữ liệu.
  none,
}

/// Một dòng trong "Bảng giá" (sửa chữa hoặc bán hàng).
class PriceBookRow {
  final String scope; // 'repair' | 'sale'
  final String key; // khoá ổn định để ghim
  final String brand; // nhóm hiển thị: iPhone / Samsung / …
  final String title; // "iPhone 12 · Ép kính" hoặc "iPhone 12 128GB (Mới)"
  final String note; // model gốc / lỗi gốc (để tìm kiếm)

  final int autoPrice; // trung vị giá bán / giá thu
  final int autoCost; // trung vị giá vốn
  final int minPrice;
  final int maxPrice;
  final int sampleCount;
  final String confidenceLabel;

  final PriceSource source;
  final int? pinnedPrice;
  final int? pinnedCost;
  final String? pinnedNote;

  /// Mặt hàng trong danh mục giá ("Bảng giá từ hoá đơn NCC") sinh ra dòng
  /// này — chỉ có khi [scope] == 'catalog'. Mang theo giá vốn bình quân/thấp
  /// nhất/cao nhất, NCC, ngày hoá đơn… để thẻ giá hiển thị mà không phải
  /// truy vấn lại DB.
  final PriceCatalogItem? catalog;

  /// Thành phần gốc để mở "các đơn/SP tương ứng".
  /// repair: [src1] = model, [src2] = lỗi.
  /// sale:   [src1] = hãng, [src2] = model, [src3] = dung lượng, [src4] = tình trạng.
  final String src1;
  final String src2;
  final String src3;
  final String src4;

  const PriceBookRow({
    required this.scope,
    required this.key,
    required this.brand,
    required this.title,
    this.note = '',
    this.autoPrice = 0,
    this.autoCost = 0,
    this.minPrice = 0,
    this.maxPrice = 0,
    this.sampleCount = 0,
    this.confidenceLabel = '',
    this.source = PriceSource.none,
    this.pinnedPrice,
    this.pinnedCost,
    this.pinnedNote,
    this.catalog,
    this.src1 = '',
    this.src2 = '',
    this.src3 = '',
    this.src4 = '',
  });

  bool get isPinned => source == PriceSource.pinned;

  /// Có giá để hiển thị/dùng không (đã ghim, hoặc có trung vị lịch sử > 0).
  /// false = chưa đủ dữ liệu để đề xuất VÀ chưa ghim — không nên vẽ như 1 khoản
  /// lãi/lỗ, chỉ nên mời chủ shop đặt giá.
  bool get hasPrice => isPinned ? (pinnedPrice ?? autoPrice) > 0 : autoPrice > 0;

  int get effectivePrice =>
      isPinned ? (pinnedPrice ?? autoPrice) : autoPrice;

  int get effectiveCost => isPinned
      ? (pinnedCost ?? autoCost)
      : autoCost;

  int get effectiveProfit => effectivePrice - effectiveCost;

  PriceBookRow copyWith({
    PriceSource? source,
    int? pinnedPrice,
    int? pinnedCost,
    String? pinnedNote,
  }) {
    return PriceBookRow(
      scope: scope,
      key: key,
      brand: brand,
      title: title,
      note: note,
      autoPrice: autoPrice,
      autoCost: autoCost,
      minPrice: minPrice,
      maxPrice: maxPrice,
      sampleCount: sampleCount,
      confidenceLabel: confidenceLabel,
      source: source ?? this.source,
      pinnedPrice: pinnedPrice ?? this.pinnedPrice,
      pinnedCost: pinnedCost ?? this.pinnedCost,
      pinnedNote: pinnedNote ?? this.pinnedNote,
      catalog: catalog,
      src1: src1,
      src2: src2,
      src3: src3,
      src4: src4,
    );
  }
}

/// Giá ghim (niêm yết) chủ shop đặt cho một khoá.
class PricePin {
  final int price;
  final int? cost;
  final String note;
  final int pinnedAt;
  final String pinnedBy;

  /// Tên gốc (chưa chuẩn hoá) — dùng khi KHÔNG có dữ liệu lịch sử/kho để tự
  /// suy ra tên hiển thị: ghim phụ tùng (khoá `p|...`, đây là tên phụ tùng),
  /// hoặc ghim sửa chữa mới tạo tay chưa từng có đơn (khoá `r|...`, đây là
  /// tên model — đi kèm [displayExtra] là tên lỗi/dịch vụ).
  final String? displayName;

  /// Chỉ dùng cho ghim sửa chữa mới tạo tay (khoá `r|...`) chưa từng có đơn
  /// lịch sử — lưu tên lỗi/dịch vụ gốc song song với [displayName] (model).
  final String? displayExtra;

  /// Hãng máy tường minh (khoá `p|...`) — khi có (vd từ cột "Hãng" của file
  /// Excel nhập hoá đơn NCC, hoặc chọn tay khi tạo mục mới), Bảng giá dùng
  /// trực tiếp thay vì tự đoán hãng từ tên phụ tùng (đoán có thể sai với
  /// tên không nêu rõ hãng, vd "Pin Zin 13").
  final String? brandHint;

  const PricePin({
    required this.price,
    this.cost,
    this.note = '',
    required this.pinnedAt,
    this.pinnedBy = '',
    this.displayName,
    this.displayExtra,
    this.brandHint,
  });

  Map<String, dynamic> toJson() => {
        'price': price,
        if (cost != null) 'cost': cost,
        'note': note,
        'at': pinnedAt,
        'by': pinnedBy,
        if (displayName != null) 'name': displayName,
        if (displayExtra != null) 'name2': displayExtra,
        if (brandHint != null) 'brand': brandHint,
      };

  factory PricePin.fromJson(Map<String, dynamic> j) => PricePin(
        price: (j['price'] as num?)?.toInt() ?? 0,
        cost: (j['cost'] as num?)?.toInt(),
        note: (j['note'] as String?) ?? '',
        pinnedAt: (j['at'] as num?)?.toInt() ?? 0,
        pinnedBy: (j['by'] as String?) ?? '',
        displayName: (j['name'] as String?),
        displayExtra: (j['name2'] as String?),
        brandHint: (j['brand'] as String?),
      );
}

/// Kết quả tra giá cho form tạo đơn.
class PriceResolution {
  final int? price;
  final int? cost;
  final PriceSource source;
  final int sampleCount;
  final String confidenceLabel;

  const PriceResolution({
    this.price,
    this.cost,
    this.source = PriceSource.none,
    this.sampleCount = 0,
    this.confidenceLabel = '',
  });

  bool get hasPrice => price != null && price! > 0;
  bool get isPinned => source == PriceSource.pinned;
}

/// Một đề xuất đổi giá SP (dry-run của "áp giá hàng loạt").
class SalePriceProposal {
  final int productId;
  final String label;
  final int oldPrice;
  final int newPrice;
  const SalePriceProposal({
    required this.productId,
    required this.label,
    required this.oldPrice,
    required this.newPrice,
  });
}
