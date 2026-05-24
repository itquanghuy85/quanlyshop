/// Unified AI parse result covering repair, sale, and stock-entry orders.
/// Schema mirrors the `parseOrderAI` Cloud Function response.
enum AiOrderIntent { repair, sale, stockEntry, unknown }

class AiUniversalResult {
  final AiOrderIntent intent;

  // ── Shared ───────────────────────────────────────────────────────────────
  final String customerName;
  final String customerPhone;

  // ── Repair ───────────────────────────────────────────────────────────────
  final String device;
  final String issue;
  final int deposit;

  // ── Sale ─────────────────────────────────────────────────────────────────
  final String productHint;
  final String imei;
  final String paymentMethod;
  final String financePartner;
  final int totalPrice;

  // ── Stock entry ──────────────────────────────────────────────────────────
  final String stockProductName;
  final int quantity;
  final int unitPrice;
  final String supplierName;

  // ── Source flag ──────────────────────────────────────────────────────────
  final bool fromAi;

  const AiUniversalResult({
    required this.intent,
    this.customerName = '',
    this.customerPhone = '',
    this.device = '',
    this.issue = '',
    this.deposit = 0,
    this.productHint = '',
    this.imei = '',
    this.paymentMethod = '',
    this.financePartner = '',
    this.totalPrice = 0,
    this.stockProductName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.supplierName = '',
    this.fromAi = false,
  });

  bool get isRepair => intent == AiOrderIntent.repair;
  bool get isSale => intent == AiOrderIntent.sale;
  bool get isStockEntry => intent == AiOrderIntent.stockEntry;
  bool get isUnknown => intent == AiOrderIntent.unknown;

  bool get hasEnoughData => switch (intent) {
        AiOrderIntent.repair => device.isNotEmpty || issue.isNotEmpty,
        AiOrderIntent.sale => productHint.isNotEmpty || imei.isNotEmpty,
        AiOrderIntent.stockEntry => stockProductName.isNotEmpty,
        AiOrderIntent.unknown => false,
      };

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Parse the unified JSON returned by `parseOrderAI` Cloud Function.
  factory AiUniversalResult.fromJson(Map<String, dynamic> json,
      {bool fromAi = true}) {
    final raw = (json['intent'] as String? ?? 'unknown');
    return switch (raw) {
      'create_repair_order' => AiUniversalResult(
          intent: AiOrderIntent.repair,
          device: _s(json['device']),
          issue: _s(json['issue']),
          deposit: _i(json['deposit']),
          customerName: _s(json['customer_name']),
          customerPhone: _s(json['customer_phone']),
          fromAi: fromAi,
        ),
      'create_sale_order' => AiUniversalResult(
          intent: AiOrderIntent.sale,
          productHint: _s(json['product_hint']),
          imei: _s(json['imei']),
          paymentMethod: _s(json['payment_method']),
          financePartner: _s(json['finance_partner']),
          totalPrice: _i(json['total_price']),
          customerName: _s(json['customer_name']),
          customerPhone: _s(json['customer_phone']),
          fromAi: fromAi,
        ),
      'create_stock_entry' => AiUniversalResult(
          intent: AiOrderIntent.stockEntry,
          stockProductName: _s(json['product_name']),
          quantity: _i(json['quantity'], defaultVal: 1),
          unitPrice: _i(json['unit_price']),
          supplierName: _s(json['supplier_name']),
          fromAi: fromAi,
        ),
      _ => const AiUniversalResult(intent: AiOrderIntent.unknown),
    };
  }

  static String _s(dynamic v) => (v?.toString() ?? '').trim();

  static int _i(dynamic v, {int defaultVal = 0}) {
    if (v == null) return defaultVal;
    if (v is int) return v < 0 ? defaultVal : v;
    if (v is double) return v < 0 ? defaultVal : v.toInt();
    return int.tryParse(v.toString()) ?? defaultVal;
  }

  static const AiUniversalResult unknown =
      AiUniversalResult(intent: AiOrderIntent.unknown);

  @override
  String toString() =>
      'AiUniversalResult(intent=$intent, device=$device, issue=$issue, '
      'product=$productHint, stock=$stockProductName, fromAi=$fromAi)';
}
