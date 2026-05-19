class FinanceV2ReconciliationReportInput {
  final int totalIn;
  final int totalOut;
  final int net;
  final int totalRevenue;
  final int totalCost;
  final int totalProfit;
  final int openingDebtCustomer;
  final int openingDebtSupplier;
  final int totalDebtCustomer;
  final int totalDebtSupplier;

  const FinanceV2ReconciliationReportInput({
    required this.totalIn,
    required this.totalOut,
    required this.net,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
    this.openingDebtCustomer = 0,
    this.openingDebtSupplier = 0,
    required this.totalDebtCustomer,
    required this.totalDebtSupplier,
  });
}

class FinanceV2ReconciliationMetric {
  final String key;
  final int logValue;
  final int reportValue;
  final String detail;

  const FinanceV2ReconciliationMetric({
    required this.key,
    required this.logValue,
    required this.reportValue,
    required this.detail,
  });

  int get diff => logValue - reportValue;
  bool get passed => diff == 0;
}

class FinanceV2ReconciliationResult {
  final List<FinanceV2ReconciliationMetric> metrics;

  const FinanceV2ReconciliationResult({required this.metrics});

  bool get passed => metrics.every((m) => m.passed);

  List<FinanceV2ReconciliationMetric> get failures =>
      metrics.where((m) => !m.passed).toList(growable: false);

  /// Vietnamese label for a reconciliation metric key — used in Excel and UI.
  static String metricLabel(String key) {
    switch (key) {
      case 'TOTAL_IN':
        return 'Tổng tiền vào';
      case 'TOTAL_OUT':
        return 'Tổng tiền ra';
      case 'NET':
        return 'Dòng tiền thuần';
      case 'TOTAL_REVENUE':
        return 'Tổng doanh thu';
      case 'TOTAL_COST':
        return 'Tổng chi phí';
      case 'TOTAL_PROFIT':
        return 'Tổng lợi nhuận';
      case 'TOTAL_DEBT_CUSTOMER':
        return 'Tổng công nợ khách hàng';
      case 'TOTAL_DEBT_SUPPLIER':
        return 'Tổng công nợ nhà cung cấp';
      default:
        return key;
    }
  }

  List<List<dynamic>> toSheetRows() {
    final statusLabel = passed ? 'Khớp ✓' : 'Sai lệch ✗';
    final rows = <List<dynamic>>[
      <dynamic>['Trạng thái đối soát', statusLabel, '', '', '', ''],
      <dynamic>['Quy tắc', 'Chênh lệch ≠ 0 là sai lệch', '', '', '', ''],
      <dynamic>['', '', '', '', '', ''],
      <dynamic>[
        'Chỉ số',
        'Giá trị từ nhật ký',
        'Giá trị báo cáo',
        'Chênh lệch',
        'Kết quả',
        'Ghi chú',
      ],
    ];

    for (final m in metrics) {
      rows.add(<dynamic>[
        metricLabel(m.key),
        m.logValue,
        m.reportValue,
        m.diff,
        m.passed ? 'Khớp' : 'Sai lệch',
        m.detail,
      ]);
    }

    if (failures.isNotEmpty) {
      rows.add(<dynamic>['', '', '', '', '', '']);
      rows.add(<dynamic>[
        'Các mục sai lệch',
        'Cần kiểm tra lại',
        '',
        '',
        '',
        '',
      ]);
      for (final f in failures) {
        rows.add(<dynamic>[
          metricLabel(f.key),
          'Lệch ${f.diff.abs()}đ',
          '',
          f.diff,
          'Sai lệch',
          f.detail,
        ]);
      }
    }

    return rows;
  }
}

class FinanceV2ReconciliationEngine {
  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static FinanceV2ReconciliationResult compute({
    required List<Map<String, dynamic>> entries,
    required FinanceV2ReconciliationReportInput report,
  }) {
    int totalIn = 0;
    int totalOut = 0;
    int revenue = 0;
    int cost = 0;
    int debtCustomerFlow = 0;
    int debtSupplierFlow = 0;

    for (final e in entries) {
      final action = (e['actionType'] ?? '').toString().toUpperCase();
      final cashIn = _toInt(e['cashIn']);
      final cashOut = _toInt(e['cashOut']);
      final transferIn = _toInt(e['transferIn']);
      final transferOut = _toInt(e['transferOut']);
      final lineAmount = _toInt(e['lineAmount']);
      final lineCostTotal = _toInt(e['lineCostTotal']);
      final debtCustomerChange = _toInt(e['debtCustomerChange']);
      final debtSupplierChange = _toInt(e['debtSupplierChange']);

      totalIn += cashIn + transferIn;
      totalOut += cashOut + transferOut;
      debtCustomerFlow += debtCustomerChange;
      // IMPORT entries track CÔNG NỢ imports via supplier_import_history, not debts table.
      // Including their debtSupplierChange would double-count vs DEBT_CREATE entries
      // and diverge from snap.payableTotal (which only sums debts-table records).
      if (action != 'IMPORT') {
        debtSupplierFlow += debtSupplierChange;
      }

      if (action == 'SALE' || action == 'REPAIR') {
        revenue += lineAmount;
        cost += lineCostTotal;
        continue;
      }
      if (action == 'RETURN') {
        revenue -= lineAmount;
        cost -= lineCostTotal;
        continue;
      }
      if (action == 'OTHER_EXPENSE' || action == 'EXPENSE') {
        cost += cashOut + transferOut;
      }
    }

    final net = totalIn - totalOut;
    final profit = revenue - cost;
    final debtCustomerClosing = report.openingDebtCustomer + debtCustomerFlow;
    final debtSupplierClosing = report.openingDebtSupplier + debtSupplierFlow;

    final metrics = <FinanceV2ReconciliationMetric>[
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_IN',
        logValue: totalIn,
        reportValue: report.totalIn,
        detail: 'Tổng tiền mặt vào + chuyển khoản vào',
      ),
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_OUT',
        logValue: totalOut,
        reportValue: report.totalOut,
        detail: 'Tổng tiền mặt ra + chuyển khoản ra',
      ),
      FinanceV2ReconciliationMetric(
        key: 'NET',
        logValue: net,
        reportValue: report.net,
        detail: 'Tổng tiền vào − Tổng tiền ra',
      ),
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_REVENUE',
        logValue: revenue,
        reportValue: report.totalRevenue,
        detail: 'Doanh thu bán hàng + sửa chữa − hoàn trả',
      ),
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_COST',
        logValue: cost,
        reportValue: report.totalCost,
        detail: 'Giá vốn hàng bán + chi phí vận hành',
      ),
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_PROFIT',
        logValue: profit,
        reportValue: report.totalProfit,
        detail: 'Tổng doanh thu − Tổng chi phí',
      ),
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_DEBT_CUSTOMER',
        logValue: debtCustomerClosing,
        reportValue: report.totalDebtCustomer,
        detail: 'Số dư đầu kỳ + biến động công nợ khách hàng',
      ),
      FinanceV2ReconciliationMetric(
        key: 'TOTAL_DEBT_SUPPLIER',
        logValue: debtSupplierClosing,
        reportValue: report.totalDebtSupplier,
        detail: 'Số dư đầu kỳ + biến động công nợ nhà cung cấp',
      ),
    ];

    return FinanceV2ReconciliationResult(metrics: metrics);
  }
}
