/// Ngưỡng cấu hình cho Pricing Engine (Bảng giá thông minh).
/// Tập trung 1 chỗ theo yêu cầu — không hard-code rải rác trong nhiều file.
class PricingEngineConfig {
  PricingEngineConfig._();

  /// Chỉ dùng đơn đã Xong (3) hoặc Đã giao (4) — giá đã chốt.
  static const List<int> pricingStatuses = [3, 4];

  /// Ngưỡng số lượng mẫu → nhãn độ tin cậy (mục 7-8 đặc tả).
  /// 0    → none
  /// 1-2  → veryLow
  /// 3-4  → low
  /// 5-9  → fair
  /// 10+  → good
  static const int veryLowSampleMax = 2;
  static const int lowSampleMax = 4;
  static const int fairSampleMax = 9;

  /// Nếu hệ số biến động giá (stddev/median) vượt ngưỡng này, hạ 1 bậc độ
  /// tin cậy dù số mẫu đủ lớn — tránh báo "Tốt" khi dữ liệu thực chất lẫn
  /// nhiều loại dịch vụ/linh kiện khác nhau (mục 8 đặc tả).
  static const double highVolatilityCoefficient = 0.5;

  /// Số mẫu tối thiểu để coi 1 level group là "có dữ liệu" và dùng luôn,
  /// thay vì fallback xuống level rộng hơn.
  static const int minSampleToUseLevel = 1;
}
