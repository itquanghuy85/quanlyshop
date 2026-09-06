import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/finance_v2/finance_v2_data_service.dart';
import 'package:quanlyshop/models/sale_order_model.dart';

/// Ghi nhận tiền trả góp theo CASH BASIS — vá lỗi đo được trên shop thật
/// 06/09/2026: cửa sổ 30 ngày **bỏ sót 59.660.000đ** tiền tất toán ngân hàng.
///
/// Lỗi cũ: mọi nơi tính `downPayment + settlementAmount` trên danh sách đơn
/// bound theo `soldAt` ⇒ sai CẢ HAI CHIỀU:
/// - bán TRONG kỳ, ngân hàng trả SAU kỳ  → ghi nhận SỚM (tiền chưa về đã tính);
/// - bán TRƯỚC kỳ, ngân hàng trả TRONG kỳ → BỎ SÓT (tiền về mà không tính).
///
/// Quy tắc đúng: cọc tính theo ngày BÁN, tất toán tính theo ngày NHẬN TIỀN.
void main() {
  // Kỳ báo cáo: 08/08/2026 00:00 → 06/09/2026 23:59 (đúng 30 ngày kể cả hôm nay)
  final startMs = DateTime(2026, 8, 8).millisecondsSinceEpoch;
  final endMs = DateTime(2026, 9, 6, 23, 59, 59).millisecondsSinceEpoch;

  SaleOrder make({
    required DateTime soldAt,
    required int downPayment,
    DateTime? settledAt,
    int settlementAmount = 0,
  }) {
    return SaleOrder(
      customerName: 'KH',
      phone: '0900000000',
      productNames: 'IPHONE',
      productImeis: '',
      sellerName: 'NV',
      totalPrice: 20000000,
      soldAt: soldAt.millisecondsSinceEpoch,
      isInstallment: true,
      downPayment: downPayment,
      settlementReceivedAt: settledAt?.millisecondsSinceEpoch,
      settlementAmount: settlementAmount,
    );
  }

  int cashIn(SaleOrder s) =>
      FinanceV2DataService.installmentCashIn(s, startMs, endMs);

  test('bán trong kỳ + tất toán trong kỳ ⇒ cọc + tất toán', () {
    final s = make(
      soldAt: DateTime(2026, 8, 20),
      downPayment: 3000000,
      settledAt: DateTime(2026, 8, 30),
      settlementAmount: 15000000,
    );
    expect(cashIn(s), 18000000);
  });

  test('bán trong kỳ, ngân hàng trả SAU kỳ ⇒ chỉ cọc (không ghi sớm)', () {
    final s = make(
      soldAt: DateTime(2026, 9, 1),
      downPayment: 3000000,
      settledAt: DateTime(2026, 9, 20),
      settlementAmount: 15000000,
    );
    expect(cashIn(s), 3000000);
  });

  test('bán TRƯỚC kỳ, ngân hàng trả TRONG kỳ ⇒ chỉ tất toán (không bỏ sót)', () {
    // Đúng ca thật: PHẠM PHONG LƯU bán 01/08, ngân hàng trả 19/08, 17.590.000đ.
    final s = make(
      soldAt: DateTime(2026, 8, 1),
      downPayment: 2000000,
      settledAt: DateTime(2026, 8, 19),
      settlementAmount: 17590000,
    );
    expect(cashIn(s), 17590000);
  });

  test('bán trước kỳ, chưa tất toán ⇒ 0', () {
    final s = make(soldAt: DateTime(2026, 7, 1), downPayment: 2000000);
    expect(cashIn(s), 0);
  });

  test('chưa có ngày nhận tiền ⇒ không tính phần tất toán', () {
    final s = make(
      soldAt: DateTime(2026, 8, 20),
      downPayment: 3000000,
      settlementAmount: 15000000, // đã ghi số tiền nhưng CHƯA nhận
    );
    expect(cashIn(s), 3000000);
  });

  test('đúng mốc đầu và cuối kỳ đều được tính', () {
    final dau = make(
      soldAt: DateTime(2026, 8, 8),
      downPayment: 1000000,
      settledAt: DateTime(2026, 8, 8),
      settlementAmount: 5000000,
    );
    expect(cashIn(dau), 6000000);

    final cuoi = make(
      soldAt: DateTime(2026, 9, 6, 23, 59, 59),
      downPayment: 1000000,
      settledAt: DateTime(2026, 9, 6, 23, 59, 59),
      settlementAmount: 5000000,
    );
    expect(cashIn(cuoi), 6000000);
  });

  test('ngoài kỳ 1 mili giây thì KHÔNG tính', () {
    final s = make(
      soldAt: DateTime(2026, 8, 8).subtract(const Duration(milliseconds: 1)),
      downPayment: 1000000,
      settledAt: DateTime(2026, 9, 6, 23, 59, 59).add(
        const Duration(milliseconds: 1),
      ),
      settlementAmount: 5000000,
    );
    expect(cashIn(s), 0);
  });

  test('tổng 5 đơn bị bỏ sót ngoài đời = 59.660.000đ', () {
    // Số liệu thật đo trên shop HULUCA STORE ngày 06/09/2026.
    final boSot = [
      make(
        soldAt: DateTime(2026, 8, 1),
        downPayment: 0,
        settledAt: DateTime(2026, 8, 19),
        settlementAmount: 17590000,
      ),
      make(
        soldAt: DateTime(2026, 8, 1),
        downPayment: 0,
        settledAt: DateTime(2026, 8, 19),
        settlementAmount: 15590000,
      ),
      make(
        soldAt: DateTime(2026, 8, 2),
        downPayment: 0,
        settledAt: DateTime(2026, 8, 19),
        settlementAmount: 5500000,
      ),
      make(
        soldAt: DateTime(2026, 8, 3),
        downPayment: 0,
        settledAt: DateTime(2026, 8, 19),
        settlementAmount: 15390000,
      ),
      make(
        soldAt: DateTime(2026, 8, 3),
        downPayment: 0,
        settledAt: DateTime(2026, 8, 19),
        settlementAmount: 5590000,
      ),
    ];
    expect(boSot.fold<int>(0, (a, s) => a + cashIn(s)), 59660000);
  });
}
