import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';

class RevenueReportView extends StatefulWidget {
  const RevenueReportView({super.key});

  @override
  State<RevenueReportView> createState() => _RevenueReportViewState();
}

class _RevenueReportViewState extends State<RevenueReportView> {
  final db = DBHelper();

  // Bộ lọc thời gian
  String _selectedTimeFilter = 'month'; // today, week, month, custom
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DateTimeRange? _customDateRange;

  // Dữ liệu
  List<Repair> _repairs = [];
  List<SaleOrder> _sales = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoading = true;

  // Theme colors
  final Color _primaryColor = const Color(0xFF2196F3);
  final Color _incomeColor = const Color(0xFF4CAF50);
  final Color _expenseColor = const Color(0xFFF44336);
  final Color _profitColor = const Color(0xFF9C27B0);

  @override
  void initState() {
    super.initState();
    _initializeDateRange();
    _loadData();
  }

  void _initializeDateRange() {
    final now = DateTime.now();
    switch (_selectedTimeFilter) {
      case 'today':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'week':
        final monday = now.subtract(Duration(days: now.weekday - 1));
        _startDate = DateTime(monday.year, monday.month, monday.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'month':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'custom':
        if (_customDateRange != null) {
          _startDate = _customDateRange!.start;
          _endDate = _customDateRange!.end;
        }
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final repairs = await db.getAllRepairs();
      final sales = await db.getAllSales();
      final expenses = await db.getAllExpenses();

      // Filter by date range
      final filteredRepairs = repairs.where((r) {
        final date = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
        return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
               date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      final filteredSales = sales.where((s) {
        final date = DateTime.fromMillisecondsSinceEpoch(s.soldAt);
        return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
               date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      final filteredExpenses = expenses.where((e) {
        final date = DateTime.fromMillisecondsSinceEpoch(e['date'] as int);
        return date.isAfter(_startDate.subtract(const Duration(days: 1))) &&
               date.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      setState(() {
        _repairs = filteredRepairs;
        _sales = filteredSales;
        _expenses = filteredExpenses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedTimeFilter = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadData();
    }
  }

  void _changeTimeFilter(String filter) {
    if (filter == 'custom') {
      _selectCustomDateRange();
    } else {
      setState(() {
        _selectedTimeFilter = filter;
        _customDateRange = null;
      });
      _initializeDateRange();
      _loadData();
    }
  }

  // Helper method for safe double conversion
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return 0.0;
      }
    }
    return 0.0;
  }

  // Tính toán các chỉ số
  double get totalRevenue {
    double revenue = 0;
    for (var sale in _sales) {
      revenue += sale.totalPrice.toDouble();
    }
    for (var repair in _repairs) {
      revenue += repair.price.toDouble();
    }
    return revenue;
  }

  double get totalCosts {
    double costs = 0;
    for (var expense in _expenses) {
      costs += (expense['amount'] as num).toDouble();
    }
    // Add cost of goods sold from sales
    for (var sale in _sales) {
      costs += sale.totalCost.toDouble();
    }
    // Add repair costs
    for (var repair in _repairs) {
      costs += repair.cost.toDouble();
    }
    return costs;
  }

  double get totalProfit => totalRevenue - totalCosts;

  // Chi tiết theo nguồn
  double get revenueFromSales {
    return _sales.fold(0.0, (sum, sale) => sum + sale.totalPrice);
  }

  double get revenueFromRepairs {
    return _repairs.fold(0.0, (sum, repair) => sum + repair.price);
  }

  double get costOfGoodsSold {
    return _sales.fold(0.0, (sum, sale) => sum + sale.totalCost) +
           _repairs.fold(0.0, (sum, repair) => sum + repair.cost);
  }

  double get operatingExpenses {
    return _expenses.fold(0.0, (sum, expense) => sum + ((expense['amount'] as num).toDouble()));
  }

  // Tạo danh sách giao dịch chi tiết
  List<Map<String, dynamic>> get _transactionDetails {
    List<Map<String, dynamic>> transactions = [];

    // Thêm doanh thu từ bán hàng
    for (var sale in _sales) {
      transactions.add({
        'date': DateTime.fromMillisecondsSinceEpoch(sale.soldAt),
        'type': 'income',
        'category': 'Bán hàng',
        'description': sale.productNames,
        'amount': sale.totalPrice.toDouble(),
        'cost': sale.totalCost.toDouble(),
        'source': 'Bán lẻ',
      });
    }

    // Thêm doanh thu từ sửa chữa
    for (var repair in _repairs) {
      transactions.add({
        'date': DateTime.fromMillisecondsSinceEpoch(repair.createdAt),
        'type': 'income',
        'category': 'Sửa chữa',
        'description': '${repair.model} - ${repair.issue}',
        'amount': repair.price.toDouble(),
        'cost': repair.cost.toDouble(),
        'source': 'Dịch vụ',
      });
    }

    // Thêm chi phí
    for (var expense in _expenses) {
      transactions.add({
        'date': DateTime.fromMillisecondsSinceEpoch(expense['date'] as int),
        'type': 'expense',
        'category': 'Chi phí',
        'description': expense['description'] as String,
        'amount': (expense['amount'] as num).toDouble(),
        'cost': 0.0,
        'source': expense['category'] as String? ?? 'Khác',
      });
    }

    // Sắp xếp theo ngày giảm dần
    transactions.sort((a, b) => b['date'].compareTo(a['date']));
    return transactions;
  }

  // Dữ liệu cho biểu đồ
  List<FlSpot> _getRevenueSpots() {
    Map<DateTime, double> dailyRevenue = {};
    for (var sale in _sales) {
      final date = DateTime.fromMillisecondsSinceEpoch(sale.soldAt);
      final day = DateTime(date.year, date.month, date.day);
      dailyRevenue[day] = (dailyRevenue[day] ?? 0) + sale.totalPrice.toDouble();
    }
    for (var repair in _repairs) {
      final date = DateTime.fromMillisecondsSinceEpoch(repair.createdAt);
      final day = DateTime(date.year, date.month, date.day);
      dailyRevenue[day] = (dailyRevenue[day] ?? 0) + repair.price.toDouble();
    }

    List<FlSpot> spots = [];
    int index = 0;
    final sortedDates = dailyRevenue.keys.toList()..sort();
    for (var date in sortedDates) {
      spots.add(FlSpot(index.toDouble(), dailyRevenue[date]! / 1000000)); // Đơn vị triệu
      index++;
    }
    return spots;
  }

  List<FlSpot> _getCostSpots() {
    Map<DateTime, double> dailyCosts = {};

    // Chi phí từ bán hàng
    for (var sale in _sales) {
      final date = DateTime.fromMillisecondsSinceEpoch(sale.soldAt);
      final day = DateTime(date.year, date.month, date.day);
      dailyCosts[day] = (dailyCosts[day] ?? 0) + sale.totalCost.toDouble();
    }

    // Chi phí từ sửa chữa
    for (var repair in _repairs) {
      final date = DateTime.fromMillisecondsSinceEpoch(repair.createdAt);
      final day = DateTime(date.year, date.month, date.day);
      dailyCosts[day] = (dailyCosts[day] ?? 0) + repair.cost.toDouble();
    }

    // Chi phí vận hành
    for (var expense in _expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense['date'] as int);
      final day = DateTime(date.year, date.month, date.day);
      dailyCosts[day] = (dailyCosts[day] ?? 0) + ((expense['amount'] as num).toDouble());
    }

    List<FlSpot> spots = [];
    int index = 0;
    final sortedDates = dailyCosts.keys.toList()..sort();
    for (var date in sortedDates) {
      spots.add(FlSpot(index.toDouble(), dailyCosts[date]! / 1000000)); // Đơn vị triệu
      index++;
    }
    return spots;
  }

  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Báo cáo doanh thu'];

    // Headers
    sheetObject.appendRow([
      TextCellValue('Ngày'),
      TextCellValue('Loại'),
      TextCellValue('Danh mục'),
      TextCellValue('Mô tả'),
      TextCellValue('Nguồn'),
      TextCellValue('Thu nhập'),
      TextCellValue('Chi phí'),
      TextCellValue('Lợi nhuận'),
    ]);

    // Data từ danh sách giao dịch
    for (var transaction in _transactionDetails) {
      final profit = transaction['type'] == 'income'
          ? transaction['amount'] - transaction['cost']
          : -transaction['amount'];

      sheetObject.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(transaction['date'])),
        TextCellValue(transaction['type'] == 'income' ? 'Thu' : 'Chi'),
        TextCellValue(transaction['category']),
        TextCellValue(transaction['description']),
        TextCellValue(transaction['source']),
        DoubleCellValue(transaction['type'] == 'income' ? transaction['amount'] : 0.0),
        DoubleCellValue(transaction['cost']),
        DoubleCellValue(profit),
      ]);
    }

    // Thêm dòng trống
    sheetObject.appendRow([TextCellValue('')]);

    // Tổng kết
    sheetObject.appendRow([
      TextCellValue('TỔNG KẾT'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    sheetObject.appendRow([
      TextCellValue('Tổng doanh thu'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalRevenue),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    sheetObject.appendRow([
      TextCellValue('Tổng chi phí'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalCosts),
      TextCellValue(''),
    ]);

    sheetObject.appendRow([
      TextCellValue('Lợi nhuận'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(totalProfit),
    ]);

    // Save file
    final directory = await getExternalStorageDirectory();
    final fileName = 'bao_cao_doanh_thu_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    final file = File('${directory!.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xuất file: $fileName')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: const Text(
          '📊 Báo Cáo Doanh Thu Chi Tiết',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Xuất Excel',
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải dữ liệu...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bộ lọc thời gian
                    _buildTimeFilterSection(),

                    const SizedBox(height: 20),

                    // Cards tổng quan
                    _buildSummaryCards(),

                    const SizedBox(height: 24),

                    // Biểu đồ doanh thu và chi phí
                    _buildRevenueChart(),

                    const SizedBox(height: 24),

                    // Phân tích theo nguồn
                    _buildSourceAnalysis(),

                    const SizedBox(height: 24),

                    // Danh sách giao dịch chi tiết
                    _buildTransactionList(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimeFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: _primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Lọc Theo Thời Gian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTimeFilterButton('Hôm nay', 'today'),
                const SizedBox(width: 8),
                _buildTimeFilterButton('Tuần này', 'week'),
                const SizedBox(width: 8),
                _buildTimeFilterButton('Tháng này', 'month'),
                const SizedBox(width: 8),
                _buildTimeFilterButton('Tùy chọn', 'custom'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range, color: _primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _selectedTimeFilter == 'custom' && _customDateRange != null
                      ? '${DateFormat('dd/MM/yyyy').format(_customDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_customDateRange!.end)}'
                      : '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  style: TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterButton(String label, String filter) {
    final isSelected = _selectedTimeFilter == filter;
    return ElevatedButton(
      onPressed: () => _changeTimeFilter(filter),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? _primaryColor : Colors.white,
        foregroundColor: isSelected ? Colors.white : _primaryColor,
        elevation: isSelected ? 4 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                '💰 Tổng Thu Nhập',
                totalRevenue,
                _incomeColor,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                '💸 Tổng Chi Phí',
                totalCosts,
                _expenseColor,
                Icons.trending_down,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          '📈 Lợi Nhuận',
          totalProfit,
          totalProfit >= 0 ? _profitColor : _expenseColor,
          totalProfit >= 0 ? Icons.show_chart : Icons.warning,
          isFullWidth: true,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (amount != totalProfit) ...[
            const SizedBox(height: 4),
            Text(
              '${((amount / (totalRevenue + totalCosts)) * 100).toStringAsFixed(1)}% tổng',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: _primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Biểu Đồ Doanh Thu & Chi Phí',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Đơn vị: Triệu VND',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= _getRevenueSpots().length) return const Text('');
                        return Text(
                          'Ngày ${value.toInt() + 1}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                minX: 0,
                maxX: _getRevenueSpots().isNotEmpty ? _getRevenueSpots().length.toDouble() - 1 : 0,
                minY: 0,
                lineBarsData: [
                  // Doanh thu
                  LineChartBarData(
                    spots: _getRevenueSpots(),
                    isCurved: true,
                    color: _incomeColor,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _incomeColor.withOpacity(0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: _incomeColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                  // Chi phí
                  LineChartBarData(
                    spots: _getCostSpots(),
                    isCurved: true,
                    color: _expenseColor,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: _expenseColor.withOpacity(0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: _expenseColor,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isRevenue = spot.barIndex == 0;
                        final value = spot.y * 1000000; // Convert back to VND
                        return LineTooltipItem(
                          '${isRevenue ? 'Thu' : 'Chi'}: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value)}',
                          TextStyle(
                            color: isRevenue ? _incomeColor : _expenseColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Doanh thu', _incomeColor),
              const SizedBox(width: 20),
              _buildLegendItem('Chi phí', _expenseColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildSourceAnalysis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: _primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Phân Tích Theo Nguồn',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildSourceItem('Bán hàng', revenueFromSales, _incomeColor, Icons.shopping_cart),
          const SizedBox(height: 12),
          _buildSourceItem('Sửa chữa', revenueFromRepairs, _incomeColor, Icons.build),
          const SizedBox(height: 12),
          _buildSourceItem('Chi phí hàng bán', costOfGoodsSold, _expenseColor, Icons.inventory),
          const SizedBox(height: 12),
          _buildSourceItem('Chi phí vận hành', operatingExpenses, _expenseColor, Icons.account_balance_wallet),
        ],
      ),
    );
  }

  Widget _buildSourceItem(String label, double amount, Color color, IconData icon) {
    final percentage = totalRevenue + totalCosts > 0 ? (amount / (totalRevenue + totalCosts)) * 100 : 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: _primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Chi Tiết Giao Dịch',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${_transactionDetails.length} giao dịch',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactionDetails.length,
            itemBuilder: (context, index) {
              final transaction = _transactionDetails[index];
              final isIncome = transaction['type'] == 'income';
              
              // Safe casting for amount and cost
              final amount = _safeToDouble(transaction['amount']);
              final cost = _safeToDouble(transaction['cost']);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isIncome ? _incomeColor.withOpacity(0.05) : Colors.red.shade900,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isIncome ? _incomeColor : _expenseColor).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isIncome ? _incomeColor : _expenseColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncome ? Icons.add : Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction['description'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: isIncome ? null : Colors.yellow.shade700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                transaction['category'],
                                style: TextStyle(
                                  color: isIncome ? Colors.grey : Colors.yellow.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  transaction['source'],
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isIncome ? '+' : '-'}${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount)}',
                          style: TextStyle(
                            color: isIncome ? _incomeColor : Colors.yellow.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (cost > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'CP: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(cost)}',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('dd/MM/yyyy').format(transaction['date']),
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          if (_transactionDetails.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.inbox,
                    size: 48,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Không có giao dịch nào',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
