import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/finance_v2/finance_v2_cache.dart';
import 'package:quanlyshop/finance_v2/finance_v2_data_service.dart';

FinanceV2Snapshot _snap(int totalIn) => FinanceV2Snapshot(
  totalIn: totalIn,
  totalOut: 0,
  operatingExpenseOut: 0,
  debtRepayOut: 0,
  receivableTotal: 0,
  payableTotal: 0,
  netCashflow: totalIn,
  incomeFromSales: 0,
  incomeFromRepairs: 0,
  cogsFromSales: 0,
  cogsFromRepairs: 0,
  grossProfitFromSales: 0,
  grossProfitFromRepairs: 0,
  grossProfitTotal: 0,
  incomeOther: 0,
  transactionCount: 0,
  avgIncomePerTransaction: 0,
  previousTotalIn: 0,
  previousTotalOut: 0,
  previousNetCashflow: 0,
  previousCogsFromSales: 0,
  previousCogsFromRepairs: 0,
  previousGrossProfitFromSales: 0,
  previousGrossProfitFromRepairs: 0,
  dashboardCards: const [],
  topExpenseCategories: const [],
  transactions: const [],
  receivables: const [],
  payables: const [],
  byDay: const [],
  byMonth: const [],
  byYear: const [],
  auditLogs: const [],
  debtAging: const {},
);

void main() {
  setUp(() {
    FinanceV2Cache.clear();
    FinanceV2Cache.resetCounters();
  });

  String? k(String shop) => FinanceV2Cache.key(
    shopId: shop,
    startMs: 1,
    endMs: 2,
    previousStartMs: 0,
    previousEndMs: 0,
  );

  test('không cache khi thiếu shopId', () {
    expect(
      FinanceV2Cache.key(
        shopId: null,
        startMs: 1,
        endMs: 2,
        previousStartMs: 0,
        previousEndMs: 0,
      ),
      isNull,
    );
    FinanceV2Cache.put(null, _snap(1));
    expect(FinanceV2Cache.length, 0);
    expect(FinanceV2Cache.get(null), isNull);
  });

  test('hit cùng shop + kỳ; miss khác shop (không cache xuyên shop)', () {
    FinanceV2Cache.put(k('A'), _snap(10));
    expect(FinanceV2Cache.get(k('A'))?.totalIn, 10);
    expect(FinanceV2Cache.get(k('B')), isNull);
    expect(FinanceV2Cache.hits, 1);
    expect(FinanceV2Cache.misses, 1);
  });

  test('invalidate chọn lọc: ghi thu làm bẩn cash, không đụng debt', () {
    FinanceV2Cache.put(k('A'), _snap(10));
    FinanceV2Cache.invalidate(
      FinanceV2Cache.sectionsForEvent('expenses_changed'),
    );
    // Tab Nợ vẫn dùng được bản cũ.
    expect(
      FinanceV2Cache.get(k('A'), needs: const {FinanceSection.debt}),
      isNotNull,
    );
    // Tab Tiền phải tải lại.
    expect(
      FinanceV2Cache.get(k('A'), needs: const {FinanceSection.cash}),
      isNull,
    );
  });

  test('thu/trả nợ làm bẩn cash + debt + transactions, KHÔNG bẩn profit', () {
    FinanceV2Cache.put(k('A'), _snap(10));
    FinanceV2Cache.invalidate(
      FinanceV2Cache.sectionsForEvent('debt_payments_changed'),
    );
    expect(
      FinanceV2Cache.get(k('A'), needs: const {FinanceSection.profit}),
      isNotNull,
    );
    for (final s in [
      FinanceSection.cash,
      FinanceSection.debt,
      FinanceSection.transactions,
    ]) {
      expect(FinanceV2Cache.get(k('A'), needs: {s}), isNull, reason: '$s');
    }
  });

  test('sự kiện lạ không đụng cache; financial_changed bẩn toàn bộ', () {
    expect(FinanceV2Cache.sectionsForEvent('something_else'), isEmpty);
    expect(FinanceV2Cache.sectionsForEvent('financial_changed'), isNull);
    FinanceV2Cache.put(k('A'), _snap(10));
    FinanceV2Cache.invalidate(null);
    expect(FinanceV2Cache.get(k('A')), isNull);
  });

  test('put lại sau khi bẩn ⇒ sạch trở lại', () {
    FinanceV2Cache.put(k('A'), _snap(10));
    FinanceV2Cache.invalidate(const {FinanceSection.cash});
    FinanceV2Cache.put(k('A'), _snap(11));
    expect(FinanceV2Cache.get(k('A'))?.totalIn, 11);
  });
}
