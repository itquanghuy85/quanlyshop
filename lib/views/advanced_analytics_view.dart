import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/db_helper.dart';
import '../models/repair_model.dart';
import '../models/sale_order_model.dart';
import '../models/product_model.dart';
import '../services/user_service.dart';
import '../services/sync_service.dart';

class AdvancedAnalyticsView extends StatefulWidget {
  const AdvancedAnalyticsView({super.key});

  @override
  State<AdvancedAnalyticsView> createState() => _AdvancedAnalyticsViewState();
}

class _AdvancedAnalyticsViewState extends State<AdvancedAnalyticsView>
    with TickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;

  // Data
  List<Repair> _repairs = [];
  List<SaleOrder> _sales = [];
  List<Product> _products = [];
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _debts = [];

  // Analytics data
  Map<String, double> _monthlyRevenue = {};
  Map<String, int> _customerFrequency = {};
  Map<String, double> _inventoryTurnover = {};
  List<Map<String, dynamic>> _maintenanceAlerts = [];

  // UI state
  bool _isLoading = true;
  bool _isSyncing = false;
  String _selectedTimeframe = 'month';
  String _selectedMetric = 'revenue';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Load all data
      _repairs = await db.getAllRepairs();
      _sales = await db.getAllSales();
      _products = await db.getAllProducts();
      _expenses = await db.getAllExpenses();
      _debts = await db.getAllDebts();

      // Process analytics
      await _processRevenueAnalytics();
      await _processCustomerAnalytics();
      await _processInventoryAnalytics();
      await _processMaintenanceAlerts();

    } catch (e) {
      debugPrint('Analytics load error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processRevenueAnalytics() async {
    _monthlyRevenue.clear();
    final now = DateTime.now();

    // Process repairs revenue
    for (var repair in _repairs) {
      if (repair.status >= 3 && repair.deliveredAt != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(repair.deliveredAt!);
        final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
        _monthlyRevenue[key] = (_monthlyRevenue[key] ?? 0) +
            ((repair.price as int) - (repair.cost as int));
      }
    }

    // Process sales revenue
    for (var sale in _sales) {
      final date = DateTime.fromMillisecondsSinceEpoch(sale.soldAt);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      _monthlyRevenue[key] = (_monthlyRevenue[key] ?? 0) +
          ((sale.totalPrice as int) - (sale.totalCost as int));
    }

    // Subtract expenses
    for (var expense in _expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense['date'] as int);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      _monthlyRevenue[key] = (_monthlyRevenue[key] ?? 0) -
          (expense['amount'] as int);
    }
  }

  Future<void> _processCustomerAnalytics() async {
    _customerFrequency.clear();
    final customerMap = <String, int>{};

    // Count repairs by customer
    for (var repair in _repairs) {
      if (repair.phone.isNotEmpty) {
        customerMap[repair.phone] =
            (customerMap[repair.phone] ?? 0) + 1;
      }
    }

    // Count sales by customer
    for (var sale in _sales) {
      if (sale.phone.isNotEmpty) {
        customerMap[sale.phone] =
            (customerMap[sale.phone] ?? 0) + 1;
      }
    }

    // Categorize customers
    customerMap.forEach((phone, count) {
      String category;
      if (count >= 10) category = 'VIP (10+)';
      else if (count >= 5) category = 'Thường xuyên (5-9)';
      else if (count >= 2) category = 'Thỉnh thoảng (2-4)';
      else category = 'Mới (1)';

      _customerFrequency[category] = (_customerFrequency[category] ?? 0) + 1;
    });
  }

  Future<void> _processInventoryAnalytics() async {
    _inventoryTurnover.clear();

    for (var product in _products) {
      if (product.quantity > 0 && product.cost > 0) {
        // Calculate turnover ratio (COGS / Average Inventory)
        final cogs = product.cost * product.quantity;
        final avgInventory = product.cost * (product.quantity / 2);
        final turnover = avgInventory > 0 ? cogs / avgInventory : 0.0;

        String category;
        if (turnover >= 4) category = 'Rất nhanh (4+)';
        else if (turnover >= 2) category = 'Nhanh (2-4)';
        else if (turnover >= 1) category = 'Trung bình (1-2)';
        else category = 'Chậm (<1)';

        _inventoryTurnover[category] = (_inventoryTurnover[category] ?? 0) + 1;
      }
    }
  }

  Future<void> _processMaintenanceAlerts() async {
    _maintenanceAlerts.clear();
    final now = DateTime.now();

    for (var repair in _repairs) {
      if (repair.status >= 3 &&
          repair.deliveredAt != null &&
          repair.warranty.isNotEmpty &&
          repair.warranty != "KO BH") {

        final match = RegExp(r'(\d+)\s*tháng').firstMatch(repair.warranty);
        if (match != null) {
          final months = int.parse(match.group(1)!);
          final deliveredDate = DateTime.fromMillisecondsSinceEpoch(repair.deliveredAt!);
          final expiryDate = DateTime(deliveredDate.year, deliveredDate.month + months, deliveredDate.day);
          final daysUntilExpiry = expiryDate.difference(now).inDays;

          if (daysUntilExpiry <= 30 && daysUntilExpiry > 0) {
            _maintenanceAlerts.add({
              'type': 'warranty_expiring',
              'customer': repair.customerName,
              'phone': repair.phone,
              'device': repair.model,
              'daysLeft': daysUntilExpiry,
              'priority': daysUntilExpiry <= 7 ? 'high' : 'medium'
            });
          }
        }
      }
    }

    // Sort by priority and days left
    _maintenanceAlerts.sort((a, b) {
      if (a['priority'] == 'high' && b['priority'] != 'high') return -1;
      if (a['priority'] != 'high' && b['priority'] == 'high') return 1;
      return (a['daysLeft'] as int).compareTo(b['daysLeft'] as int);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải dữ liệu phân tích...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phân tích nâng cao'),
        backgroundColor: const Color(0xFF2962FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _syncData,
            icon: _isSyncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync),
            tooltip: 'Đồng bộ dữ liệu',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Doanh thu', icon: Icon(Icons.trending_up)),
            Tab(text: 'Khách hàng', icon: Icon(Icons.people)),
            Tab(text: 'Kho hàng', icon: Icon(Icons.inventory)),
            Tab(text: 'Bảo hành', icon: Icon(Icons.warning)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRevenueTab(),
          _buildCustomerTab(),
          _buildInventoryTab(),
          _buildMaintenanceTab(),
        ],
      ),
    );
  }

  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeframeSelector(),
          const SizedBox(height: 20),
          _buildRevenueChart(),
          const SizedBox(height: 20),
          _buildRevenueMetrics(),
          const SizedBox(height: 20),
          _buildRevenueDrilldown(),
        ],
      ),
    );
  }

  Widget _buildCustomerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân tích hành vi khách hàng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildCustomerChart(),
          const SizedBox(height: 20),
          _buildCustomerMetrics(),
        ],
      ),
    );
  }

  Widget _buildInventoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Phân tích luân chuyển kho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildInventoryChart(),
          const SizedBox(height: 20),
          _buildInventoryMetrics(),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cảnh báo bảo hành (${_maintenanceAlerts.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildMaintenanceAlerts(),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return Row(
      children: [
        const Text('Thời gian: ', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'month', label: Text('Tháng')),
            ButtonSegment(value: 'quarter', label: Text('Quý')),
            ButtonSegment(value: 'year', label: Text('Năm')),
          ],
          selected: {_selectedTimeframe},
          onSelectionChanged: (Set<String> selected) {
            setState(() => _selectedTimeframe = selected.first);
          },
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    final sortedEntries = _monthlyRevenue.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (sortedEntries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Chưa có dữ liệu doanh thu'),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Biểu đồ doanh thu theo thời gian',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        getTitlesWidget: (value, meta) {
                          return Text('${(value / 1000000).toStringAsFixed(1)}M',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < sortedEntries.length) {
                            final dateStr = sortedEntries[value.toInt()].key;
                            final date = DateTime.parse('$dateStr-01');
                            return Text(DateFormat('MM/yy').format(date),
                                style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sortedEntries.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value);
                      }).toList(),
                      isCurved: true,
                      color: const Color(0xFF2962FF),
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueMetrics() {
    final totalRevenue = _monthlyRevenue.values.fold(0.0, (sum, value) => sum + value);
    final avgMonthly = _monthlyRevenue.isNotEmpty ? totalRevenue / _monthlyRevenue.length : 0.0;
    final bestMonth = _monthlyRevenue.entries.isNotEmpty
        ? _monthlyRevenue.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Tổng doanh thu',
            '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalRevenue)}',
            Icons.account_balance_wallet,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Trung bình/tháng',
            '${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(avgMonthly)}',
            Icons.trending_up,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Tháng tốt nhất',
            bestMonth != null ? '${bestMonth.key}: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(bestMonth.value)}' : 'N/A',
            Icons.star,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueDrilldown() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chi tiết doanh thu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDrilldownItem(
                    'Sửa chữa',
                    _repairs.where((r) => r.status >= 3).length,
                    _repairs.where((r) => r.status >= 3)
                        .fold(0, (sum, r) => sum + ((r.price as int) - (r.cost as int))),
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDrilldownItem(
                    'Bán hàng',
                    _sales.length,
                    _sales.fold(0, (sum, s) => sum + ((s.totalPrice as int) - (s.totalCost as int))),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDrilldownItem(
                    'Chi phí',
                    _expenses.length,
                    _expenses.fold(0, (sum, e) => sum + (e['amount'] as int)),
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerChart() {
    if (_customerFrequency.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu khách hàng'));
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Phân loại khách hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: PieChart(
                PieChartData(
                  sections: _customerFrequency.entries.map((entry) {
                    final colors = {
                      'VIP (10+)': Colors.purple,
                      'Thường xuyên (5-9)': Colors.blue,
                      'Thỉnh thoảng (2-4)': Colors.orange,
                      'Mới (1)': Colors.grey,
                    };
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${entry.value}',
                      color: colors[entry.key] ?? Colors.grey,
                      radius: 100,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerMetrics() {
    final totalCustomers = _customerFrequency.values.fold(0, (sum, value) => sum + value);
    final vipCustomers = _customerFrequency['VIP (10+)'] ?? 0;
    final newCustomers = _customerFrequency['Mới (1)'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Tổng khách hàng',
            totalCustomers.toString(),
            Icons.people,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Khách VIP',
            vipCustomers.toString(),
            Icons.star,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Khách mới',
            newCustomers.toString(),
            Icons.person_add,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryChart() {
    if (_inventoryTurnover.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu kho hàng'));
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Luân chuyển kho hàng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: _inventoryTurnover.entries.map((entry) {
                    final colors = {
                      'Rất nhanh (4+)': Colors.green,
                      'Nhanh (2-4)': Colors.blue,
                      'Trung bình (1-2)': Colors.orange,
                      'Chậm (<1)': Colors.red,
                    };
                    return BarChartGroupData(
                      x: _inventoryTurnover.keys.toList().indexOf(entry.key),
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: colors[entry.key] ?? Colors.grey,
                          width: 20,
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _inventoryTurnover.length) {
                            final key = _inventoryTurnover.keys.elementAt(value.toInt());
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(key, style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryMetrics() {
    final totalProducts = _products.length;
    final fastMoving = (_inventoryTurnover['Rất nhanh (4+)'] ?? 0) + (_inventoryTurnover['Nhanh (2-4)'] ?? 0);
    final slowMoving = _inventoryTurnover['Chậm (<1)'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Tổng sản phẩm',
            totalProducts.toString(),
            Icons.inventory,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Luân chuyển nhanh',
            fastMoving.toString(),
            Icons.trending_up,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Luân chuyển chậm',
            slowMoving.toString(),
            Icons.trending_down,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildMaintenanceAlerts() {
    if (_maintenanceAlerts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Không có cảnh báo bảo hành nào'),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _maintenanceAlerts.length,
      itemBuilder: (context, index) {
        final alert = _maintenanceAlerts[index];
        final isHighPriority = alert['priority'] == 'high';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8),
          color: isHighPriority ? Colors.red.shade50 : Colors.orange.shade50,
          child: ListTile(
            leading: Icon(
              isHighPriority ? Icons.warning : Icons.info,
              color: isHighPriority ? Colors.red : Colors.orange,
            ),
            title: Text('${alert['customer']} - ${alert['device']}'),
            subtitle: Text(
              'SĐT: ${alert['phone']}\n'
              'Còn ${alert['daysLeft']} ngày hết bảo hành',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isHighPriority ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isHighPriority ? 'Khẩn cấp' : 'Cảnh báo',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrilldownItem(String title, int count, int amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$count đơn',
            style: TextStyle(color: color, fontSize: 12),
          ),
          Text(
            NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(amount),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _syncData() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);
    try {
      await SyncService.syncAllToCloud();
      await SyncService.downloadAllFromCloud();
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đồng bộ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }
}