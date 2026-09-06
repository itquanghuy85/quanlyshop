import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/daily_financial_analysis_service.dart';

/// Đơn "KẾT HỢP" (một phần tiền mặt + một phần chuyển khoản).
///
/// `analyze()` có nhánh riêng tách 2 phần này, nhưng nhánh chỉ chạy khi caller
/// truyền `cashAmount` / `transferAmount`. Trước 2026-09-06, Sổ quỹ / Trang chủ
/// / Báo cáo tháng đều lược 2 cột đó ⇒ đơn rơi xuống nhánh mặc định và vì
/// paymentMethod ('KẾT HỢP') != 'TIỀN MẶT' nên TOÀN BỘ tiền vào `bankIn`.
void main() {
  group('KẾT HỢP — tách tiền mặt / chuyển khoản', () {
    Map<String, dynamic> ketHopSale({
      required int cash,
      required int transfer,
      int totalPrice = 10000000,
      int discount = 0,
      int totalCost = 8000000,
    }) => {
      'paymentMethod': 'KẾT HỢP',
      'totalPrice': totalPrice,
      'discount': discount,
      'totalCost': totalCost,
      'isInstallment': false,
      'downPayment': 0,
      'downPaymentMethod': null,
      'cashAmount': cash,
      'transferAmount': transfer,
    };

    DailyFinancialAnalysis run(List<Map<String, dynamic>> sales) =>
        DailyFinancialAnalysisService.analyze(
          sales: sales,
          settlementSales: const [],
          repairs: const [],
          expenses: const [],
          debtPayments: const [],
          supplierPayments: const [],
          repairPartnerPayments: const [],
          supplierImports: const [],
          repairPartsCostFundRows: const [],
          salesReturns: const [],
          enableRepair: true,
        );

    test('có cashAmount/transferAmount → chia đúng 2 quỹ', () {
      final a = run([ketHopSale(cash: 4000000, transfer: 6000000)]);
      expect(a.cashIn, 4000000);
      expect(a.bankIn, 6000000);
      expect(a.saleIncome, 10000000);
    });

    test('thiếu 2 cột → dồn hết vào ngân hàng (hành vi lỗi cũ)', () {
      final broken = ketHopSale(cash: 4000000, transfer: 6000000)
        ..remove('cashAmount')
        ..remove('transferAmount');
      final a = run([broken]);
      // Đây là bằng chứng của bug: tiền mặt = 0 dù khách trả 4tr tiền mặt.
      expect(a.cashIn, 0);
      expect(a.bankIn, 10000000);
    });

    test('KẾT HỢP thu thiếu (phần còn lại ghi nợ) chỉ tính phần đã thu', () {
      final a = run([
        ketHopSale(cash: 3000000, transfer: 2000000, totalPrice: 10000000),
      ]);
      expect(a.cashIn, 3000000);
      expect(a.bankIn, 2000000);
      expect(a.saleIncome, 5000000);
    });

    test('KẾT HỢP toàn tiền mặt vẫn vào quỹ tiền mặt', () {
      final a = run([ketHopSale(cash: 10000000, transfer: 0)]);
      expect(a.cashIn, 10000000);
      expect(a.bankIn, 0);
    });

    test('không ảnh hưởng đơn TIỀN MẶT / CHUYỂN KHOẢN thường', () {
      final a = run([
        {
          'paymentMethod': 'TIỀN MẶT',
          'totalPrice': 5000000,
          'discount': 0,
          'totalCost': 4000000,
          'isInstallment': false,
          'cashAmount': 0,
          'transferAmount': 0,
        },
        {
          'paymentMethod': 'CHUYỂN KHOẢN',
          'totalPrice': 3000000,
          'discount': 0,
          'totalCost': 2000000,
          'isInstallment': false,
          'cashAmount': 0,
          'transferAmount': 0,
        },
      ]);
      expect(a.cashIn, 5000000);
      expect(a.bankIn, 3000000);
      expect(a.saleIncome, 8000000);
    });
  });
}
