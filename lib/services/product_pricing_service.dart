import 'dart:math' as math;

import '../data/db_helper.dart';
import '../models/product_model.dart';
import '../utils/vietnamese_utils.dart';
import 'pricing_engine_config.dart';
import 'pricing_engine_service.dart' show PricingConfidence;

export 'pricing_engine_service.dart' show PricingConfidence, PricingConfidenceLabel;

/// Kết quả gợi ý giá vốn/giá bán từ lịch sử nhập kho — chỉ mang tính THAM
/// KHẢO, không tự động ghi vào form.
class ProductPricingSuggestion {
  final int sampleCount;
  final int medianCost;
  final int medianSalePrice;
  final int medianProfit;
  final int minPrice;
  final int maxPrice;
  final PricingConfidence confidence;

  const ProductPricingSuggestion({
    required this.sampleCount,
    required this.medianCost,
    required this.medianSalePrice,
    required this.medianProfit,
    required this.minPrice,
    required this.maxPrice,
    required this.confidence,
  });
}

/// Gợi ý giá vốn/giá bán khi nhập kho, dựa trên thống kê median từ các sản
/// phẩm đã nhập trước đó cùng model — cùng kiến trúc/thuật toán thống kê với
/// `PricingEngineService` (đơn sửa), nhưng khớp đơn giản theo model (sản
/// phẩm không có khái niệm "dịch vụ"/"linh kiện" như đơn sửa).
///
/// Chạy hoàn toàn trên SQLite local — không gọi Firestore. Chỉ mang tính GỢI
/// Ý, không tự động ghi/lưu bất cứ đâu.
class ProductPricingService {
  ProductPricingService._();

  static String _normalize(String s) {
    final collapsed = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';
    return VietnameseUtils.normalize(collapsed);
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
    final nums = <num>[...values];
    final mean = nums.reduce((a, b) => a + b) / nums.length;
    final variance =
        nums.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b) / nums.length;
    final stddev = math.sqrt(variance);
    return stddev / median;
  }

  static PricingConfidence _confidenceForSampleCount(int n) {
    if (n <= 0) return PricingConfidence.none;
    if (n <= PricingEngineConfig.veryLowSampleMax) return PricingConfidence.veryLow;
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

  /// Tính gợi ý giá thuần Dart trên danh sách sản phẩm đã tải sẵn — hàm
  /// pure, dùng cho cả app lẫn unit test (không cần DB thật).
  static ProductPricingSuggestion? computeSuggestion({
    required List<Product> products,
    required String model,
  }) {
    final normModel = _normalize(model);
    if (normModel.isEmpty) return null;

    final matches = products
        .where((p) => !p.isPending && p.cost > 0 && p.price > 0)
        .where((p) => _normalize(p.model ?? '') == normModel)
        .toList();

    if (matches.length < PricingEngineConfig.minSampleToUseLevel) return null;

    final costs = matches.map((p) => p.cost).toList();
    final prices = matches.map((p) => p.price).toList();
    final profits = matches.map((p) => p.price - p.cost).toList();

    final trimmedCosts = _trimOutliers(costs);
    final trimmedPrices = _trimOutliers(prices);
    final trimmedProfits = _trimOutliers(profits);

    final medianPriceRaw = _median(prices);
    final cv = _coefficientOfVariation(prices, medianPriceRaw);

    var confidence = _confidenceForSampleCount(matches.length);
    if (cv > PricingEngineConfig.highVolatilityCoefficient) {
      confidence = _downgrade(confidence);
    }

    final sortedTrimmedPrices = [...trimmedPrices]..sort();

    return ProductPricingSuggestion(
      sampleCount: matches.length,
      medianCost: _median(trimmedCosts).round(),
      medianSalePrice: _median(trimmedPrices).round(),
      medianProfit: _median(trimmedProfits).round(),
      minPrice: sortedTrimmedPrices.first.round(),
      maxPrice: sortedTrimmedPrices.last.round(),
      confidence: confidence,
    );
  }

  /// Lấy gợi ý giá từ dữ liệu SQLite local của shop hiện tại. Không gọi
  /// Firestore. An toàn để gọi sau debounce khi người dùng nhập model trong
  /// màn nhập kho.
  static Future<ProductPricingSuggestion?> getSuggestion({
    required String model,
    DBHelper? dbHelper,
  }) async {
    if (model.trim().isEmpty) return null;
    final db = dbHelper ?? DBHelper();
    final products = await db.getProductsForPricing();
    return computeSuggestion(products: products, model: model);
  }
}
