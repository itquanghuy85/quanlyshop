import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/models/payment_intent_model.dart';
import 'package:quanlyshop/services/payment_intent_service.dart';

/// Sự cố 2026-09-18: khoá idempotency dài bị cắt cụt ở 70 ký tự ⇒ lần trả
/// nợ thứ 2 trên khoản nợ có firestoreId dài trùng intentId với lần đầu ⇒
/// "thành công" giả, không ghi phiếu. Test này khoá lại hành vi mới.
void main() {
  const type = PaymentIntentType.supplierDebt;
  const longDebt =
      'debt_partner_debt_rep_1789152135910_0902222222_svc_1789152048363531_25_900000';

  test('hai lần trả trên cùng khoản nợ dài ⇒ intentId KHÁC nhau', () {
    final a = PaymentIntentService.buildDirectPaymentIntentId(
      type: type,
      idempotencyKey: '${longDebt}_1789154152860',
    );
    final b = PaymentIntentService.buildDirectPaymentIntentId(
      type: type,
      idempotencyKey: '${longDebt}_1789737182000',
    );
    expect(a, isNotNull);
    expect(a, isNot(equals(b)));
    // Vẫn trong giới hạn độ dài cũ (prefix + 70).
    expect(a!.length, lessThanOrEqualTo('pi_direct_${type.code.toLowerCase()}_'.length + 70));
  });

  test('cùng khoá ⇒ cùng id (idempotent thật)', () {
    const key = '${longDebt}_1789154152860';
    expect(
      PaymentIntentService.buildDirectPaymentIntentId(type: type, idempotencyKey: key),
      PaymentIntentService.buildDirectPaymentIntentId(type: type, idempotencyKey: key),
    );
  });

  test('khoá ngắn giữ NGUYÊN id kiểu cũ (không đổi id phiếu đã có)', () {
    const key = 'debt_1787034406889_0964095979_1789154152860';
    final id = PaymentIntentService.buildDirectPaymentIntentId(
      type: type,
      idempotencyKey: key,
    );
    expect(id, 'pi_direct_supplier_debt_$key');
    expect(
      PaymentIntentService.buildDirectPaymentIntentId(
        type: type,
        idempotencyKey: key,
        legacy: true,
      ),
      id,
    );
  });

  test('legacy tái tạo đúng id cắt cụt của bản cũ', () {
    final legacy = PaymentIntentService.buildDirectPaymentIntentId(
      type: type,
      idempotencyKey: '${longDebt}_1789154152860',
      legacy: true,
    );
    // Id thật đo được trong SQLite shop M (payment_intents.id=71).
    expect(
      legacy,
      'pi_direct_supplier_debt_debt_partner_debt_rep_1789152135910_0902222222_svc_1789152048363531_25',
    );
  });

  test('firestoreId phiếu = rpp_ + intentId', () {
    final id = PaymentIntentService.buildDirectPaymentRecordFirestoreId(
      type: PaymentIntentType.repairPartnerDebt,
      idempotencyKey: '${longDebt}_x',
    );
    expect(id, startsWith('rpp_pi_direct_'));
  });
}
