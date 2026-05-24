/// Kết quả phân tích đơn sửa chữa từ DeepSeek AI.
/// Schema khớp 1-1 với JSON trả về từ Cloud Function `createRepairOrderAI`.
class AiRepairResult {
  final String intent;
  final String customerName;
  final String customerPhone;
  final String device;
  final String issue;
  final int deposit;

  const AiRepairResult({
    required this.intent,
    required this.customerName,
    required this.customerPhone,
    required this.device,
    required this.issue,
    required this.deposit,
  });

  bool get isRepairOrder => intent == 'create_repair_order';

  /// Parse từ JSON trả về Cloud Function — không throw, luôn trả về object hợp lệ.
  factory AiRepairResult.fromJson(Map<String, dynamic> json) {
    return AiRepairResult(
      intent: (json['intent'] as String? ?? 'unknown').trim(),
      customerName: (json['customer_name'] as String? ?? '').trim(),
      customerPhone: (json['customer_phone'] as String? ?? '').trim(),
      device: (json['device'] as String? ?? '').trim(),
      issue: (json['issue'] as String? ?? '').trim(),
      deposit: _parseInt(json['deposit']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v < 0 ? 0 : v;
    if (v is double) return v < 0 ? 0 : v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Map<String, dynamic> toJson() => {
        'intent': intent,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'device': device,
        'issue': issue,
        'deposit': deposit,
      };

  /// Kết quả rỗng — dùng khi AI không nhận diện được.
  static const AiRepairResult unknown = AiRepairResult(
    intent: 'unknown',
    customerName: '',
    customerPhone: '',
    device: '',
    issue: '',
    deposit: 0,
  );

  @override
  String toString() =>
      'AiRepairResult(intent=$intent, device=$device, issue=$issue, '
      'customer=$customerName, phone=$customerPhone, deposit=$deposit)';
}
