import 'dart:math' as math;

import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../utils/vietnamese_utils.dart';
import 'pricing_engine_config.dart';

/// Độ tin cậy của gợi ý giá — dựa trên số mẫu, hạ 1 bậc nếu giá biến động
/// mạnh (xem [PricingEngineConfig.highVolatilityCoefficient]).
enum PricingConfidence { none, veryLow, low, fair, good }

extension PricingConfidenceLabel on PricingConfidence {
  String get label {
    switch (this) {
      case PricingConfidence.none:
        return 'Không có dữ liệu';
      case PricingConfidence.veryLow:
        return 'Dữ liệu quá ít';
      case PricingConfidence.low:
        return 'Thấp';
      case PricingConfidence.fair:
        return 'Khá';
      case PricingConfidence.good:
        return 'Tốt';
    }
  }
}

/// Kết quả gợi ý giá từ Pricing Engine — chỉ mang tính THAM KHẢO.
/// Không tự động ghi vào form/đơn sửa.
class PricingSuggestion {
  /// 1 = model+dịch vụ+linh kiện, 2 = model+dịch vụ, 3 = model.
  final int matchLevel;
  final int sampleCount;
  final int medianCost;
  final int medianSalePrice;
  final int medianProfit;
  final int minPrice;
  final int maxPrice;
  final PricingConfidence confidence;

  /// Các đơn sửa thực tế đã dùng để tính gợi ý này — chỉ để XEM/THAM KHẢO
  /// (VD mở trang danh sách khi bấm vào dòng "N đơn tương tự"), không dùng
  /// để tính toán lại gì thêm.
  final List<Repair> matchedRepairs;

  const PricingSuggestion({
    required this.matchLevel,
    required this.sampleCount,
    required this.medianCost,
    required this.medianSalePrice,
    required this.medianProfit,
    required this.minPrice,
    required this.maxPrice,
    required this.confidence,
    required this.matchedRepairs,
  });
}

class _CandidateRepair {
  final Repair repair;
  final String normModel;
  final String? normService; // null nếu nhiều dịch vụ (đơn không "sạch")
  final String? singlePartName; // null nếu 0 hoặc >1 linh kiện xác định được

  _CandidateRepair({
    required this.repair,
    required this.normModel,
    required this.normService,
    required this.singlePartName,
  });
}

/// Bảng giá thông minh: gợi ý giá vốn/giá thu/lợi nhuận tham khảo dựa trên
/// thống kê median từ lịch sử đơn sửa đã hoàn thành (status Xong/Đã giao).
///
/// Chạy hoàn toàn trên SQLite local — không gọi Firestore, không tạo read
/// spike. Chỉ mang tính GỢI Ý, không tự động ghi/lưu bất cứ đâu.
class PricingEngineService {
  PricingEngineService._();

  /// Chuẩn hóa đơn giản: trim + gộp khoảng trắng + bỏ dấu + lowercase.
  /// Không dùng bảng alias mở rộng (rủi ro gộp nhầm model khác nhau).
  static String normalizeText(String s) {
    final collapsed = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return VietnameseUtils.normalize(collapsed);
  }

  /// Tách "TÊN xSL" (định dạng partsUsed hiện có) → tên linh kiện.
  static String? _parseSinglePartName(String partsUsed) {
    final parts = partsUsed
        .split(', ')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length != 1) return null;
    final match = RegExp(r'^(.+)\s+x(\d+)$').firstMatch(parts.first);
    return (match != null ? match.group(1)! : parts.first).trim();
  }

  static _CandidateRepair _annotate(Repair r) {
    final normModel = normalizeText(r.model);

    String? normService;
    if (r.services.length == 1) {
      normService = normalizeText(r.services.first.serviceName);
    } else if (r.services.isEmpty) {
      normService = r.issue.trim().isEmpty ? null : normalizeText(r.issue);
    } else {
      normService = null; // nhiều dịch vụ trong 1 đơn — không "sạch"
    }

    String? singlePartName;
    if (r.partsUsedDetailed.length == 1) {
      singlePartName = normalizeText(r.partsUsedDetailed.first.name);
    } else if (r.partsUsedDetailed.isEmpty) {
      final parsed = _parseSinglePartName(r.partsUsed);
      singlePartName = parsed == null ? null : normalizeText(parsed);
    } else {
      singlePartName = null; // nhiều linh kiện — không "sạch"
    }

    return _CandidateRepair(
      repair: r,
      normModel: normModel,
      normService: normService,
      singlePartName: singlePartName,
    );
  }

  static double _median(List<num> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid].toDouble();
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static double _percentile(List<num> sorted, double p) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first.toDouble();
    final idx = (p / 100) * (sorted.length - 1);
    final lower = idx.floor();
    final upper = idx.ceil();
    if (lower == upper) return sorted[lower].toDouble();
    final weight = idx - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  /// Loại outlier bằng IQR đơn giản: giữ giá trị trong [Q1-1.5*IQR, Q3+1.5*IQR].
  /// Không đủ dữ liệu (< 4 mẫu) thì giữ nguyên — IQR không đáng tin với mẫu nhỏ.
  static List<num> _trimOutliers(List<num> values) {
    if (values.length < 4) return values;
    final sorted = [...values]..sort();
    final q1 = _percentile(sorted, 25);
    final q3 = _percentile(sorted, 75);
    final iqr = q3 - q1;
    final lower = q1 - 1.5 * iqr;
    final upper = q3 + 1.5 * iqr;
    final trimmed = sorted.where((v) => v >= lower && v <= upper).toList();
    return trimmed.isEmpty ? sorted : trimmed;
  }

  static double _coefficientOfVariation(List<num> values, double median) {
    if (values.isEmpty || median <= 0) return double.infinity;
    // Copy qua list literal để ép reified type về List<num> — values có thể
    // thực chất là List<int> lúc runtime (covariance), khiến .reduce dùng
    // closure (num,num)=>num bị lệch kiểu với combine (int,int)=>int mong đợi.
    final nums = <num>[...values];
    final mean = nums.reduce((a, b) => a + b) / nums.length;
    final variance =
        nums.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) /
        nums.length;
    final stddev = math.sqrt(variance);
    return stddev / median;
  }

  static PricingConfidence _confidenceForSampleCount(int n) {
    if (n <= 0) return PricingConfidence.none;
    if (n <= PricingEngineConfig.veryLowSampleMax) {
      return PricingConfidence.veryLow;
    }
    if (n <= PricingEngineConfig.lowSampleMax) return PricingConfidence.low;
    if (n <= PricingEngineConfig.fairSampleMax) return PricingConfidence.fair;
    return PricingConfidence.good;
  }

  static PricingConfidence _downgrade(PricingConfidence c) {
    switch (c) {
      case PricingConfidence.good:
        return PricingConfidence.fair;
      case PricingConfidence.fair:
        return PricingConfidence.low;
      case PricingConfidence.low:
        return PricingConfidence.veryLow;
      case PricingConfidence.veryLow:
      case PricingConfidence.none:
        return c;
    }
  }

  static PricingSuggestion _buildSuggestion(
    int matchLevel,
    List<_CandidateRepair> matches,
  ) {
    final costs = matches.map((m) => m.repair.cost).toList();
    final prices = matches.map((m) => m.repair.price).toList();
    final profits = matches.map((m) => m.repair.price - m.repair.cost).toList();

    final trimmedCosts = _trimOutliers(costs);
    final trimmedPrices = _trimOutliers(prices);
    final trimmedProfits = _trimOutliers(profits);

    final medianPriceRaw = _median(prices);
    // Đo biến động trên dữ liệu THÔ (chưa trim) — mục đích là phát hiện dữ
    // liệu lẫn nhiều loại dịch vụ/linh kiện khác nhau, không phải làm đẹp số.
    final cv = _coefficientOfVariation(prices, medianPriceRaw);

    var confidence = _confidenceForSampleCount(matches.length);
    if (cv > PricingEngineConfig.highVolatilityCoefficient) {
      confidence = _downgrade(confidence);
    }

    final sortedTrimmedPrices = [...trimmedPrices]..sort();

    return PricingSuggestion(
      matchLevel: matchLevel,
      sampleCount: matches.length,
      medianCost: _median(trimmedCosts).round(),
      medianSalePrice: _median(trimmedPrices).round(),
      medianProfit: _median(trimmedProfits).round(),
      minPrice: sortedTrimmedPrices.first.round(),
      maxPrice: sortedTrimmedPrices.last.round(),
      confidence: confidence,
      matchedRepairs: matches.map((m) => m.repair).toList(),
    );
  }

  /// Tính gợi ý giá thuần Dart trên danh sách đơn đã tải sẵn — hàm pure,
  /// dùng cho cả app lẫn unit test (không cần DB thật).
  static PricingSuggestion? computeSuggestion({
    required List<Repair> repairs,
    required String model,
    String? issueOrService,
    String? partName,
  }) {
    final normModel = normalizeText(model);
    if (normModel.isEmpty) return null;

    // Phòng vệ: loại đơn đã soft-delete nếu caller lỡ truyền vào chưa lọc
    // (tầng DB — getRepairsForPricing — đã lọc sẵn, đây chỉ là an toàn kép).
    final candidates = repairs.where((r) => !r.deleted).map(_annotate).toList();
    final modelMatches = candidates
        .where((c) => c.normModel == normModel)
        .toList();
    if (modelMatches.isEmpty) return null;

    final normService =
        (issueOrService == null || issueOrService.trim().isEmpty)
        ? null
        : normalizeText(issueOrService);
    final normPart = (partName == null || partName.trim().isEmpty)
        ? null
        : normalizeText(partName);

    // Level 1: model + dịch vụ + linh kiện (chỉ đơn "sạch" — 1 dịch vụ, 1 linh kiện)
    if (normService != null && normPart != null) {
      final level1 = modelMatches
          .where(
            (c) => c.normService == normService && c.singlePartName == normPart,
          )
          .toList();
      if (level1.length >= PricingEngineConfig.minSampleToUseLevel) {
        return _buildSuggestion(1, level1);
      }
    }

    // Level 2: model + dịch vụ (đơn có đúng 1 dịch vụ xác định — không lẫn
    // đơn nhiều dịch vụ khác nhau, nhưng không quan tâm linh kiện)
    if (normService != null) {
      final level2 = modelMatches
          .where((c) => c.normService == normService)
          .toList();
      if (level2.length >= PricingEngineConfig.minSampleToUseLevel) {
        return _buildSuggestion(2, level2);
      }
    }

    // Level 3: chỉ model
    if (modelMatches.length >= PricingEngineConfig.minSampleToUseLevel) {
      return _buildSuggestion(3, modelMatches);
    }

    return null; // Level 4: chưa đủ dữ liệu — không bịa giá
  }

  /// Lấy gợi ý giá từ dữ liệu SQLite local của shop hiện tại.
  /// Không gọi Firestore. An toàn để gọi sau debounce khi người dùng nhập
  /// model/lỗi máy trong màn tạo đơn sửa.
  static Future<PricingSuggestion?> getSuggestion({
    required String model,
    String? issueOrService,
    String? partName,
    DBHelper? dbHelper,
  }) async {
    if (model.trim().isEmpty) return null;
    final db = dbHelper ?? DBHelper();
    final repairs = await db.getRepairsForPricing(
      statuses: PricingEngineConfig.pricingStatuses,
    );
    return computeSuggestion(
      repairs: repairs,
      model: model,
      issueOrService: issueOrService,
      partName: partName,
    );
  }
}
