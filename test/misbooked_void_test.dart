import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/data_reconciliation_service.dart';

/// D-3b regression: a VOID reversal in financial_activity_log must equal the
/// money that actually came IN for the SAME transaction number. The detector
/// must NOT flag a correctly-booked VOID, and must converge (re-running after a
/// VOID_AMOUNT_ADJUST leaves nothing to flag).
Map<String, dynamic> fal({
  required String type,
  required String dir,
  required int amount,
  required String ref,
}) =>
    {'activityType': type, 'direction': dir, 'amount': amount, 'referenceId': ref};

void main() {
  test('correctly-booked repair VOID is NOT flagged', () {
    final rows = [
      fal(type: 'REPAIR_SERVICE', dir: 'IN', amount: 900000, ref: 'rep_1786936363336_900001111'),
      fal(type: 'REPAIR_VOID', dir: 'OUT', amount: 900000, ref: 'rep_1786936363336_900001111'),
    ];
    expect(DataReconciliationService.computeMisbookedVoids(rows), isEmpty);
  });

  test('over-reversed repair VOID (18M booked, 12M received) → diff +6M', () {
    final rows = [
      fal(type: 'REPAIR_SERVICE', dir: 'IN', amount: 6000000, ref: 'rep_1781237441355_441355'),
      fal(type: 'REPAIR_PRICE_ADJUST', dir: 'IN', amount: 6000000, ref: 'rep_1781237441355_441355'),
      fal(type: 'REPAIR_PARTNER_DEBT', dir: 'OUT', amount: 12000000, ref: 'rep_1781237441355_441355'),
      fal(type: 'REPAIR_VOID', dir: 'OUT', amount: 18000000, ref: 'rep_1781237441355_441355'),
    ];
    final r = DataReconciliationService.computeMisbookedVoids(rows);
    expect(r.length, 1);
    expect(r.first['receivedIn'], 12000000);
    expect(r.first['diff'], 6000000);
  });

  test('under-reversed repair VOID (60k booked, 120k received) → diff -60k', () {
    final rows = [
      fal(type: 'REPAIR_PRICE_ADJUST', dir: 'IN', amount: 60000, ref: 'rep_1781234587303_587303'),
      fal(type: 'REPAIR_SERVICE', dir: 'IN', amount: 60000, ref: 'rep_1781234587303_587303'),
      fal(type: 'REPAIR_COST_ADJUST', dir: 'OUT', amount: 50000, ref: 'rep_1781234587303_587303'),
      fal(type: 'REPAIR_VOID', dir: 'OUT', amount: 60000, ref: 'rep_1781234587303_587303'),
    ];
    final r = DataReconciliationService.computeMisbookedVoids(rows);
    expect(r.length, 1);
    expect(r.first['diff'], -60000);
  });

  test('CÔNG NỢ sale VOID: 200k booked, only 50k collected → diff +150k', () {
    final rows = [
      fal(type: 'CUSTOMER_DEBT_COLLECT', dir: 'IN', amount: 50000, ref: 'debt_1787995317501_0900000001'),
      fal(type: 'SALE_VOID', dir: 'OUT', amount: 200000, ref: 'sale_1787995317501_0900000001'),
    ];
    final r = DataReconciliationService.computeMisbookedVoids(rows);
    expect(r.length, 1);
    expect(r.first['receivedIn'], 50000);
    expect(r.first['diff'], 150000);
  });

  test('converges: after VOID_AMOUNT_ADJUST the same VOID is no longer flagged', () {
    final rows = [
      fal(type: 'CUSTOMER_DEBT_COLLECT', dir: 'IN', amount: 50000, ref: 'debt_1787995317501_0900000001'),
      fal(type: 'SALE_VOID', dir: 'OUT', amount: 200000, ref: 'sale_1787995317501_0900000001'),
      // the fix posts IN 150k against the same txn number
      fal(type: 'VOID_AMOUNT_ADJUST', dir: 'IN', amount: 150000, ref: 'sale_1787995317501_0900000001'),
    ];
    expect(DataReconciliationService.computeMisbookedVoids(rows), isEmpty);
  });

  test('VOID with no referenceId digits is ignored (not crash)', () {
    final rows = [fal(type: 'SALE_VOID', dir: 'OUT', amount: 100, ref: 'sale_')];
    expect(DataReconciliationService.computeMisbookedVoids(rows), isEmpty);
  });
}
