import 'package:flutter/foundation.dart';

class DailyFinancialAnalysis {
  final int cashIn;
  final int cashOut;
  final int bankIn;
  final int bankOut;
  final int saleIncome;
  final int settlementIncome;
  final int repairIncome;
  final int debtCollected;
  final int miscIncome;
  final int expenseOut;
  final int importOut;
  final int supplierPaid;
  final int partnerPaid;
  final int repairPartsCostFund;
  final int saleCost;
  final int repairCost;
  final int refundOut;
  final int returnCost;

  const DailyFinancialAnalysis({
    required this.cashIn,
    required this.cashOut,
    required this.bankIn,
    required this.bankOut,
    required this.saleIncome,
    required this.settlementIncome,
    required this.repairIncome,
    required this.debtCollected,
    required this.miscIncome,
    required this.expenseOut,
    required this.importOut,
    required this.supplierPaid,
    required this.partnerPaid,
    required this.repairPartsCostFund,
    required this.saleCost,
    required this.repairCost,
    required this.refundOut,
    required this.returnCost,
  });

  int get totalIn => cashIn + bankIn;
  int get totalOut => cashOut + bankOut;
  int get netProfit =>
      saleIncome +
      settlementIncome +
      repairIncome +
      miscIncome -
      expenseOut -
      saleCost -
      repairCost;

  int get saleProfit => saleIncome + settlementIncome - saleCost;
  int get repairProfit => repairIncome - repairCost;
}

class DailyFinancialAnalysisService {
  static DailyFinancialAnalysis analyze({
    required List<Map<String, dynamic>> sales,
    required List<Map<String, dynamic>> settlementSales,
    required List<Map<String, dynamic>> repairs,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> debtPayments,
    required List<Map<String, dynamic>> supplierPayments,
    required List<Map<String, dynamic>> repairPartnerPayments,
    required List<Map<String, dynamic>> supplierImports,
    required List<Map<String, dynamic>> repairPartsCostFundRows,
    required List<Map<String, dynamic>> salesReturns,
    required bool enableRepair,
    bool logDebug = false,
    String? debugLabel,
  }) {
    int cashIn = 0;
    int cashOut = 0;
    int bankIn = 0;
    int bankOut = 0;
    int saleIncome = 0;
    int repairIncome = 0;
    int debtCollected = 0;
    int miscIncome = 0;
    int expenseOut = 0;
    int importOut = 0;
    int supplierPaid = 0;
    int partnerPaid = 0;
    int repairPartsCostFund = 0;
    int saleCost = 0;
    int repairCost = 0;
    int settlementIncome = 0;
    int saleDebt = 0;
    int repairDebt = 0;
    int refundOut = 0;
    int returnCostTotal = 0;

    // Khử trùng thanh toán đối tác sửa chữa: mỗi khoản trả đối tác thường được
    // ghi song song thành 1 expense mirror `exp_partner_<X>` (X = firestoreId của
    // repair_partner_payments bỏ tiền tố `rpp_`). Nếu không loại một trong hai,
    // vòng `expenses` và vòng `repairPartnerPayments` cộng cùng số tiền 2 lần
    // vào cashOut/bankOut. FinanceV2 và danh sách chi tiết Sổ quỹ đều đã khử —
    // đây là chỗ `analyze()` bị thiếu. Thu thập ngay trong vòng `expenses` bên
    // dưới rồi dùng lại ở vòng `repairPartnerPayments`.
    final partnerExpenseFids = <String>{};
    final partnerExpenseAmounts = <int>{};

    for (final sale in sales) {
      final paymentMethod = _asString(sale['paymentMethod']);
      final totalPrice = _asInt(sale['totalPrice']);
      final discount = _asInt(sale['discount']);
      final finalPrice = totalPrice - discount > 0 ? totalPrice - discount : 0;
      final totalCost = _asInt(sale['totalCost']);
      final isInstallment = _asBool(sale['isInstallment']);
      final isKetHop = paymentMethod.toUpperCase() == 'KẾT HỢP';
      final cashAmount = _asInt(sale['cashAmount']);
      final transferAmount = _asInt(sale['transferAmount']);

      if (paymentMethod == 'CÔNG NỢ') {
        saleIncome += finalPrice;
        saleCost += totalCost;
        saleDebt += finalPrice;
        continue;
      }

      if (isInstallment) {
        final downPaid = _asInt(sale['downPayment']);
        saleIncome += downPaid;

        final ratio = finalPrice > 0 ? downPaid / finalPrice : 0.0;
        saleCost += (totalCost * ratio).round();

        final downMethod = _asString(
          sale['downPaymentMethod'] ?? sale['paymentMethod'],
        );
        if (downMethod == 'TIỀN MẶT') {
          cashIn += downPaid;
        } else {
          bankIn += downPaid;
        }
      } else if (isKetHop && (cashAmount + transferAmount) > 0) {
        final actualPaid = cashAmount + transferAmount;
        saleIncome += actualPaid;
        saleCost += totalCost;
        cashIn += cashAmount;
        bankIn += transferAmount;
      } else {
        saleIncome += finalPrice;
        saleCost += totalCost;
        if (paymentMethod == 'TIỀN MẶT') {
          cashIn += finalPrice;
        } else {
          bankIn += finalPrice;
        }
      }
    }

    for (final sale in settlementSales) {
      final settlementAmount = _asInt(sale['settlementAmount']);
      final loanAmount = _asInt(sale['loanAmount']);
      final loanAmount2 = _asInt(sale['loanAmount2']);
      final totalLoan = loanAmount + loanAmount2;
      final amount = settlementAmount.clamp(0, totalLoan);
      if (amount <= 0) continue;

      settlementIncome += amount;
      bankIn += amount;

      final totalPrice = _asInt(sale['totalPrice']);
      final discount = _asInt(sale['discount']);
      final finalPrice = totalPrice - discount > 0 ? totalPrice - discount : 0;
      final totalCost = _asInt(sale['totalCost']);
      final downPaid = _asInt(sale['downPayment']);
      final downRatio = finalPrice > 0 ? downPaid / finalPrice : 0.0;
      final remainRatio = 1.0 - downRatio;
      saleCost += (totalCost * remainRatio).round();
    }

    if (enableRepair) {
      for (final repair in repairs) {
        final price = _asInt(repair['price']);
        final totalCost = _repairCostValue(repair);
        final paymentMethod = _asString(repair['paymentMethod']);

        if (paymentMethod == 'CÔNG NỢ') {
          repairIncome += price;
          repairCost += totalCost;
          repairDebt += price;
          continue;
        }

        repairIncome += price;
        repairCost += totalCost;
        if (paymentMethod == 'TIỀN MẶT') {
          cashIn += price;
        } else {
          bankIn += price;
        }
      }
    } else {
      for (final repair in repairs) {
        final price = _asInt(repair['price']);
        final totalCost = _repairCostValue(repair);
        final paymentMethod = _asString(repair['paymentMethod']);

        if (paymentMethod == 'CÔNG NỢ') {
          repairIncome += price;
          repairCost += totalCost;
          repairDebt += price;
          continue;
        }

        repairIncome += price;
        repairCost += totalCost;
        if (paymentMethod == 'TIỀN MẶT') {
          cashIn += price;
        } else {
          bankIn += price;
        }
      }
    }

    for (final expense in expenses) {
      final category = _asString(expense['category']).toUpperCase();
      final amount = _asInt(expense['amount']);
      final type = _asString(expense['type'], fallback: 'CHI').toUpperCase();
      final method = _asString(
        expense['paymentMethod'],
        fallback: 'TIỀN MẶT',
      );

      // Ghi nhận các expense là "bản sao" của thanh toán đối tác sửa chữa để
      // vòng `repairPartnerPayments` bên dưới bỏ qua, tránh đếm 2 lần.
      final expenseFid = _asString(expense['firestoreId']);
      final isPartnerMirror = expenseFid.startsWith('exp_partner_') ||
          category.contains('ĐỐI TÁC') ||
          category.contains('PARTNER');
      if (expenseFid.startsWith('exp_partner_')) {
        partnerExpenseFids.add(expenseFid);
      }
      if (category.contains('ĐỐI TÁC') || category.contains('PARTNER')) {
        partnerExpenseAmounts.add(amount);
      }

      if (type == 'THU') {
        miscIncome += amount;
        if (method == 'TIỀN MẶT') {
          cashIn += amount;
        } else {
          bankIn += amount;
        }
        continue;
      }

      final isImport =
          category.contains('NHẬP') ||
          category.contains('LINH KIỆN') ||
          category.contains('PURCHASE');

      if (method == 'TIỀN MẶT') {
        cashOut += amount;
      } else {
        bankOut += amount;
      }

      // `expenseOut` = chi phí VẬN HÀNH thuần (trừ vào lợi nhuận accrual). KHÔNG
      // gồm: (1) nhập hàng — là tài sản, thành giá vốn lúc bán; (2) trả đối tác
      // sửa chữa (`exp_partner_*` / category "ĐỐI TÁC SỬA CHỮA") — giá vốn dịch
      // vụ đối tác ĐÃ nằm trong `repairCost` lúc giao máy, cộng thêm ở đây là
      // đếm 2 lần cùng 1 chi phí qua 2 kỳ. Nhất quán với FinanceV2:
      // `operatingExpenseOut = expenseOut - debtRepayOut - importExpenseOut - partnerPaymentOut`.
      if (!isImport && !isPartnerMirror) {
        expenseOut += amount;
      }
    }

    for (final import in supplierImports) {
      final method = _asString(import['paymentMethod'], fallback: 'TIỀN MẶT');
      if (method == 'CÔNG NỢ') continue;

      final amount = _asInt(import['totalAmount']) > 0
          ? _asInt(import['totalAmount'])
          : _asInt(import['costPrice']);
      importOut += amount;

      final hasMatchingExpense = expenses.any((expense) {
        final category = _asString(expense['category']).toUpperCase();
        if (!category.contains('NHẬP') &&
            !category.contains('LINH KIỆN') &&
            !category.contains('PURCHASE')) {
          return false;
        }
        final expenseAmount = _asInt(expense['amount']);
        return (expenseAmount - amount).abs() < 1000;
      });

      if (!hasMatchingExpense) {
        if (method == 'TIỀN MẶT') {
          cashOut += amount;
        } else {
          bankOut += amount;
        }
      }
    }

    for (final payment in supplierPayments) {
      final amount = _asInt(payment['amount']);
      final method = _asString(
        payment['paymentMethod'],
        fallback: 'TIỀN MẶT',
      );
      supplierPaid += amount;

      if (method == 'TIỀN MẶT') {
        cashOut += amount;
      } else {
        bankOut += amount;
      }
    }

    if (enableRepair) {
      for (final payment in repairPartnerPayments) {
        final amount = _asInt(payment['amount']);
        final method = _asString(
          payment['paymentMethod'],
          fallback: 'TIỀN MẶT',
        );

        // Bỏ qua nếu khoản này đã được cộng ở vòng `expenses` dưới dạng expense
        // mirror `exp_partner_*` (khớp chính theo firestoreId, giống FinanceV2).
        // Dự phòng khớp theo số tiền + category "ĐỐI TÁC"/"PARTNER" chỉ khi
        // payment không có firestoreId để so (dữ liệu cũ / caller lược cột).
        final paymentFid = _asString(payment['firestoreId']);
        final mirrorFid = paymentFid.startsWith('rpp_')
            ? 'exp_partner_${paymentFid.substring(4)}'
            : 'exp_partner_$paymentFid';
        final alreadyCounted = paymentFid.isNotEmpty
            ? partnerExpenseFids.contains(mirrorFid)
            : partnerExpenseAmounts.contains(amount);
        if (alreadyCounted) {
          continue;
        }

        partnerPaid += amount;

        if (method == 'TIỀN MẶT') {
          cashOut += amount;
        } else {
          bankOut += amount;
        }
      }
    }

    for (final payment in debtPayments) {
      final amount = _asInt(payment['amount']);
      final method = _asString(
        payment['paymentMethod'],
        fallback: 'TIỀN MẶT',
      );
      final debtType = _resolvedDebtType(payment);

      if (_isShopOwesDebt(debtType)) {
        supplierPaid += amount;
        if (method == 'TIỀN MẶT') {
          cashOut += amount;
        } else {
          bankOut += amount;
        }
      } else {
        debtCollected += amount;
        if (method == 'TIỀN MẶT') {
          cashIn += amount;
        } else {
          bankIn += amount;
        }
      }
    }

    for (final repairCostRow in repairPartsCostFundRows) {
      final cost = _asInt(repairCostRow['costRecordedAmount']) > 0
          ? _asInt(repairCostRow['costRecordedAmount'])
          : _repairCostValue(repairCostRow);
      final method = _asString(
        repairCostRow['costPaymentMethod'] ?? repairCostRow['paymentMethod'],
        fallback: 'TIỀN MẶT',
      );

      // Linh kiện ghi sổ quỹ với phương thức CÔNG NỢ = CHƯA chi tiền (còn nợ
      // NCC) → không phát sinh dòng tiền ra. Trước đây nhánh `else` vẫn cộng
      // `bankOut` cho CÔNG NỢ → tiền ra ảo. Khớp cách xử lý ở vòng
      // `supplierImports` (bỏ qua CÔNG NỢ).
      if (method == 'CÔNG NỢ') {
        continue;
      }

      repairPartsCostFund += cost;
      if (method == 'TIỀN MẶT') {
        cashOut += cost;
      } else {
        bankOut += cost;
      }
    }

    for (final salesReturn in salesReturns) {
      final amount = _asInt(salesReturn['totalReturnAmount']);
      final returnCost = _asInt(salesReturn['totalReturnCost']);
      final method = _asString(
        salesReturn['refundMethod'],
        fallback: 'TIỀN MẶT',
      );
      if (method == 'CÔNG NỢ') continue;

      refundOut += amount;
      returnCostTotal += returnCost;
      saleIncome -= amount;
      saleCost -= returnCost;

      if (method == 'TIỀN MẶT') {
        cashOut += amount;
      } else {
        bankOut += amount;
      }
    }

    if (logDebug) {
      final label = (debugLabel != null && debugLabel.trim().isNotEmpty)
          ? debugLabel.trim()
          : 'N/A';
      debugPrint('=== DAILY FINANCIAL ANALYSIS [$label] ===');
      debugPrint('💵 cashIn=$cashIn, cashOut=$cashOut');
      debugPrint('🏦 bankIn=$bankIn, bankOut=$bankOut');
      debugPrint('📊 saleIncome=$saleIncome (debt=$saleDebt)');
      debugPrint('🏦 settlementIncome=$settlementIncome');
      debugPrint('🔧 repairIncome=$repairIncome (debt=$repairDebt)');
      debugPrint('➕ miscIncome=$miscIncome');
      debugPrint('💳 debtCollected=$debtCollected');
      debugPrint('📤 expenseOut=$expenseOut, importOut=$importOut, supplierPaid=$supplierPaid, partnerPaid=$partnerPaid');
      debugPrint('💰 saleCost=$saleCost, repairCost=$repairCost, repairPartsCostFund=$repairPartsCostFund');
      debugPrint('🧮 netProfit = saleIncome($saleIncome) + settlementIncome($settlementIncome) + repairIncome($repairIncome) + miscIncome($miscIncome) - expenseOut($expenseOut) - saleCost($saleCost) - repairCost($repairCost) = ${saleIncome + settlementIncome + repairIncome + miscIncome - expenseOut - saleCost - repairCost}');
    }

    return DailyFinancialAnalysis(
      cashIn: cashIn,
      cashOut: cashOut,
      bankIn: bankIn,
      bankOut: bankOut,
      saleIncome: saleIncome,
      settlementIncome: settlementIncome,
      repairIncome: repairIncome,
      debtCollected: debtCollected,
      miscIncome: miscIncome,
      expenseOut: expenseOut,
      importOut: importOut,
      supplierPaid: supplierPaid,
      partnerPaid: partnerPaid,
      repairPartsCostFund: repairPartsCostFund,
      saleCost: saleCost,
      repairCost: repairCost,
      refundOut: refundOut,
      returnCost: returnCostTotal,
    );
  }

  static bool _isShopOwesDebt(String? debtType) {
    if (debtType == null) return false;
    return debtType == 'SHOP_OWES' ||
        debtType == 'OTHER_SHOP_OWES' ||
        debtType == 'OWED';
  }

  static String _resolvedDebtType(Map<String, dynamic> payment) {
    final resolved = _asString(payment['resolvedDebtType']);
    if (resolved.isNotEmpty) return resolved;
    return _asString(payment['debtType']);
  }

  static int _repairCostValue(Map<String, dynamic> repair) {
    final totalCost = _asInt(repair['totalCost']);
    if (totalCost > 0) return totalCost;
    return _asInt(repair['cost']);
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
    }
    return 0;
  }

  static bool _asBool(dynamic value) {
    return value == true || value == 1 || value == '1';
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }
}