import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';

class SupplierDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailsDialog({super.key, required this.supplier});

  @override
  State<SupplierDetailsDialog> createState() => _SupplierDetailsDialogState();
}

class _SupplierDetailsDialogState extends State<SupplierDetailsDialog> with SingleTickerProviderStateMixin {
  final db = DBHelper();
  late TabController _tabController;

  List<Map<String, dynamic>> _importHistory = [];
  List<Map<String, dynamic>> _productPrices = [];
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _debtSummary;
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = true;

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
    setState(() => _isLoading = true);
    try {
      final supplierId = widget.supplier['id'];
      final supplierName = widget.supplier['name'];
      if (supplierId != null && supplierName != null) {
        final history = await db.getSupplierImportHistory(supplierId, limit: 50);
        final prices = await db.getSupplierProductPrices(supplierId);
        final stats = await db.getSupplierImportStats(supplierId);
        final debtSummary = await db.getSupplierDebtSummary(supplierName);
        final paymentHistory = await db.getSupplierPaymentHistory(supplierName);

        setState(() {
          _importHistory = history;
          _productPrices = prices;
          _stats = stats;
          _debtSummary = debtSummary;
          _paymentHistory = paymentHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading supplier details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.business, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.supplier['name'] ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  if (_stats != null) ...[
                    const SizedBox(height: 8),
                    // Row 1: Tổng nhập và Tổng tiền
                    Row(
                      children: [
                        _statChip('Tổng nhập', '${_stats!['totalImports'] ?? 0} lần'),
                        const SizedBox(width: 8),
                        _statChip('Tổng tiền', '${NumberFormat('#,###').format(_stats!['totalAmount'] ?? 0)} đ'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 2: Tổng số lượng và Sản phẩm duy nhất
                    Row(
                      children: [
                        _statChip('Tổng SL', '${_stats!['totalQuantity'] ?? 0} cái'),
                        const SizedBox(width: 8),
                        _statChip('SP duy nhất', '${_stats!['uniqueProducts'] ?? 0} loại'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 3: Giá trung bình và Khoảng giá
                    Row(
                      children: [
                        _statChip('Giá TB', '${NumberFormat('#,###').format(_stats!['avgPrice'] ?? 0)} đ'),
                        const SizedBox(width: 8),
                        _statChip('Giá từ',
                          '${NumberFormat('#,###').format(_stats!['minPrice'] ?? 0)} - ${NumberFormat('#,###').format(_stats!['maxPrice'] ?? 0)} đ'),
                      ],
                    ),
                    // Row 4: Ngày nhập đầu tiên và cuối cùng
                    if (_stats!['firstImportDate'] != null && _stats!['lastImportDate'] != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _statChip('Nhập đầu',
                            DateFormat('dd/MM/yy').format(DateTime.fromMillisecondsSinceEpoch(_stats!['firstImportDate']))),
                          const SizedBox(width: 8),
                          _statChip('Nhập cuối',
                            DateFormat('dd/MM/yy').format(DateTime.fromMillisecondsSinceEpoch(_stats!['lastImportDate']))),
                        ],
                      ),
                    ],
                  ],
                  // Debt information
                  if (_debtSummary != null && _debtSummary!['totalDebt'] > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red.shade700, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                'CÔNG NỢ: ${NumberFormat('#,###').format(_debtSummary!['totalDebt'])} đ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_debtSummary!['pendingPurchaseCount']} đơn nhập + ${_debtSummary!['activeDebtCount']} khoản nợ',
                            style: TextStyle(fontSize: 12, color: Colors.red.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Lịch sử nhập hàng', icon: Icon(Icons.history)),
                Tab(text: 'Giá sản phẩm', icon: Icon(Icons.price_change)),
                Tab(text: 'Thống kê', icon: Icon(Icons.analytics)),
                Tab(text: 'Công nợ', icon: Icon(Icons.account_balance_wallet)),
              ],
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
            ),

            // Tab content
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildImportHistoryTab(),
                      _buildProductPricesTab(),
                      _buildStatisticsTab(),
                      _buildDebtTab(),
                    ],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade50,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportHistoryTab() {
    if (_importHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có lịch sử nhập hàng', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _importHistory.length,
      itemBuilder: (context, index) {
        final item = _importHistory[index];
        final date = DateTime.fromMillisecondsSinceEpoch(item['importDate']);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['productName'] ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('IMEI: ${item['imei'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 16),
                    Text('SL: ${item['quantity'] ?? 0}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Giá: ${NumberFormat('#,###').format(item['costPrice'] ?? 0)} đ',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Tổng: ${NumberFormat('#,###').format(item['totalAmount'] ?? 0)} đ',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ghi chú: ${item['notes']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProductPricesTab() {
    if (_productPrices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.price_change, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có thông tin giá sản phẩm', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productPrices.length,
      itemBuilder: (context, index) {
        final price = _productPrices[index];
        final lastUpdated = DateTime.fromMillisecondsSinceEpoch(price['lastUpdated']);
        final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(lastUpdated);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price['productName'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Thương hiệu: ${price['productBrand'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (price['productModel'] != null) ...[
                      const SizedBox(width: 16),
                      Text(
                        'Model: ${price['productModel']}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Giá nhập: ${NumberFormat('#,###').format(price['costPrice'] ?? 0)} đ',
                      style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Cập nhật: $formattedDate',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatisticsTab() {
    if (_stats == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có dữ liệu thống kê', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tổng quan
          _buildStatSection(
            'Tổng quan hoạt động',
            [
              _buildStatRow('Tổng số lần nhập hàng', '${_stats!['totalImports'] ?? 0} lần'),
              _buildStatRow('Tổng số lượng sản phẩm', '${_stats!['totalQuantity'] ?? 0} cái'),
              _buildStatRow('Tổng giá trị nhập hàng', '${NumberFormat('#,###').format(_stats!['totalAmount'] ?? 0)} đ'),
              _buildStatRow('Số loại sản phẩm khác nhau', '${_stats!['uniqueProducts'] ?? 0} loại'),
            ],
          ),

          const SizedBox(height: 20),

          // Thống kê giá cả
          _buildStatSection(
            'Thống kê giá cả',
            [
              _buildStatRow('Giá nhập trung bình', '${NumberFormat('#,###').format(_stats!['avgPrice'] ?? 0)} đ'),
              _buildStatRow('Giá nhập thấp nhất', '${NumberFormat('#,###').format(_stats!['minPrice'] ?? 0)} đ'),
              _buildStatRow('Giá nhập cao nhất', '${NumberFormat('#,###').format(_stats!['maxPrice'] ?? 0)} đ'),
            ],
          ),

          const SizedBox(height: 20),

          // Thời gian hoạt động
          if (_stats!['firstImportDate'] != null && _stats!['lastImportDate'] != null) ...[
            _buildStatSection(
              'Thời gian hoạt động',
              [
                _buildStatRow('Lần nhập đầu tiên',
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_stats!['firstImportDate']))),
                _buildStatRow('Lần nhập gần nhất',
                  DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(_stats!['lastImportDate']))),
                _buildStatRow('Thời gian hợp tác',
                  _calculateCooperationPeriod(_stats!['firstImportDate'], _stats!['lastImportDate'])),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Thống kê hiệu suất
          _buildStatSection(
            'Hiệu suất',
            [
              _buildStatRow('Giá trị trung bình/lần nhập',
                '${NumberFormat('#,###').format((_stats!['totalAmount'] ?? 0) / (_stats!['totalImports'] ?? 1))} đ'),
              _buildStatRow('Số lượng trung bình/lần nhập',
                '${((_stats!['totalQuantity'] ?? 0) / (_stats!['totalImports'] ?? 1)).toStringAsFixed(1)} cái'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatSection(String title, List<Widget> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 12),
          ...stats,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  String _calculateCooperationPeriod(int firstDate, int lastDate) {
    final first = DateTime.fromMillisecondsSinceEpoch(firstDate);
    final last = DateTime.fromMillisecondsSinceEpoch(lastDate);
    final difference = last.difference(first);

    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    final days = difference.inDays % 30;

    final parts = <String>[];
    if (years > 0) parts.add('$years năm');
    if (months > 0) parts.add('$months tháng');
    if (days > 0 || parts.isEmpty) parts.add('$days ngày');

    return parts.join(', ');
  }

  Widget _buildDebtTab() {
    if (_debtSummary == null) {
      return const Center(child: Text('Không có dữ liệu công nợ'));
    }

    final totalDebt = _debtSummary!['totalDebt'] as int? ?? 0;
    final purchaseOrders = _debtSummary!['purchaseOrders'] as List<Map<String, dynamic>>? ?? [];
    final debts = _debtSummary!['debts'] as List<Map<String, dynamic>>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total debt summary
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'TỔNG CÔNG NỢ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NumberFormat('#,###').format(totalDebt)} đ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Purchase orders debt
          if (purchaseOrders.isNotEmpty) ...[
            Text(
              'ĐƠN NHẬP CHƯA THANH TOÁN (${purchaseOrders.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...purchaseOrders.map((order) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Đơn: ${order['orderCode'] ?? 'N/A'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngày: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(order['createdAt'] ?? 0))}\n'
                      'Số lượng: ${order['totalAmount'] ?? 0} sản phẩm',
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _payPurchaseOrderDebt(order),
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Thanh toán'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  '${NumberFormat('#,###').format(order['totalCost'] ?? 0)} đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            )),
          ],

          // Debts
          if (debts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'KHOẢN NỢ KHÁC (${debts.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...debts.map((debt) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Nợ: ${debt['note'] ?? 'Không có ghi chú'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ngày: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(debt['createdAt'] ?? 0))}\n'
                      'Đã trả: ${NumberFormat('#,###').format(debt['paidAmount'] ?? 0)} đ',
                    ),
                    const SizedBox(height: 4),
                    ElevatedButton.icon(
                      onPressed: () => _paySupplierDebt(debt),
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Thanh toán'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                trailing: Text(
                  '${NumberFormat('#,###').format((debt['totalAmount'] ?? 0) - (debt['paidAmount'] ?? 0))} đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            )),
          ],

          // Payment History
          if (_paymentHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'LỊCH SỬ TRẢ NỢ (${_paymentHistory.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ..._paymentHistory.map((payment) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: Colors.green.shade50,
              child: ListTile(
                leading: Icon(
                  payment['paymentType'] == 'debt_payment' ? Icons.payment : Icons.check_circle,
                  color: Colors.green.shade700,
                ),
                title: Text(
                  payment['paymentType'] == 'debt_payment' 
                    ? 'Trả nợ: ${payment['debtNote'] ?? 'Nợ khác'}'
                    : 'Thanh toán đơn nhập: ${payment['orderCode'] ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(payment['paidAt'] ?? 0))}\n'
                  'PTTT: ${payment['paymentMethod'] ?? 'N/A'} • ${payment['createdBy'] ?? 'N/A'}',
                ),
                trailing: Text(
                  '${NumberFormat('#,###').format(payment['amount'] ?? 0)} đ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            )),
          ],

          if (purchaseOrders.isEmpty && debts.isEmpty && _paymentHistory.isEmpty) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Không có khoản nợ nào',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _payPurchaseOrderDebt(Map<String, dynamic> order) {
    final payController = TextEditingController();
    String paymentMethod = 'TIỀN MẶT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Thanh toán đơn nhập: ${order['orderCode']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: payController,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thanh toán (đ)',
                  hintText: 'Nhập số tiền',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Phương thức thanh toán:'),
              Wrap(
                spacing: 8,
                children: ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'THẺ'].map((method) => ChoiceChip(
                  label: Text(method),
                  selected: paymentMethod == method,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => paymentMethod = method);
                    }
                  },
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(payController.text.replaceAll('.', '')) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                  );
                  return;
                }

                final orderTotal = order['totalCost'] as int? ?? 0;
                if (amount != orderTotal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Số tiền phải bằng tổng đơn: ${NumberFormat('#,###').format(orderTotal)} đ')),
                  );
                  return;
                }

                try {
                  // Get the purchase order and update its status
                  final allOrders = await db.getAllPurchaseOrders();
                  final orderToUpdate = allOrders.firstWhere(
                    (o) => o.firestoreId == order['firestoreId'],
                    orElse: () => throw Exception('Không tìm thấy đơn nhập'),
                  );
                  
                  orderToUpdate.status = 'PAID';
                  await db.updatePurchaseOrder(orderToUpdate);
                  
                  // Record payment in debt_payments table for tracking
                  await db.insertDebtPayment({
                    'firestoreId': 'pay_po_${DateTime.now().millisecondsSinceEpoch}',
                    'debtId': null, // No specific debt ID for purchase orders
                    'debtFirestoreId': order['firestoreId'],
                    'amount': amount,
                    'paidAt': DateTime.now().millisecondsSinceEpoch,
                    'paymentMethod': paymentMethod,
                    'note': 'Thanh toán đơn nhập: ${order['orderCode']}',
                    'createdBy': 'SYSTEM', // TODO: Get current user
                  });

                  Navigator.pop(ctx);
                  _loadData(); // Refresh data
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã thanh toán đơn nhập thành công')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  void _paySupplierDebt(Map<String, dynamic> debt) {
    final payController = TextEditingController();
    String paymentMethod = 'TIỀN MẶT';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Thanh toán nợ nhà cung cấp'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: payController,
                decoration: const InputDecoration(
                  labelText: 'Số tiền thanh toán (đ)',
                  hintText: 'Nhập số tiền',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              const Text('Phương thức thanh toán:'),
              Wrap(
                spacing: 8,
                children: ['TIỀN MẶT', 'CHUYỂN KHOẢN', 'THẺ'].map((method) => ChoiceChip(
                  label: Text(method),
                  selected: paymentMethod == method,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => paymentMethod = method);
                    }
                  },
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = int.tryParse(payController.text.replaceAll('.', '')) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                  );
                  return;
                }

                final remaining = (debt['totalAmount'] as int? ?? 0) - (debt['paidAmount'] as int? ?? 0);
                if (amount > remaining) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Số tiền không được vượt quá nợ còn lại: ${NumberFormat('#,###').format(remaining)} đ')),
                  );
                  return;
                }

                try {
                  // Record payment
                  await db.insertDebtPayment({
                    'firestoreId': 'pay_debt_${DateTime.now().millisecondsSinceEpoch}',
                    'debtId': debt['id'],
                    'debtFirestoreId': debt['firestoreId'],
                    'amount': amount,
                    'paidAt': DateTime.now().millisecondsSinceEpoch,
                    'paymentMethod': paymentMethod,
                    'note': 'Thanh toán nợ NCC: ${debt['note'] ?? ''}',
                    'createdBy': 'SYSTEM', // TODO: Get current user
                  });

                  // Update debt paid amount
                  await db.updateDebtPaid(debt['id'], amount);

                  Navigator.pop(ctx);
                  _loadData(); // Refresh data
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã thanh toán nợ thành công')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e')),
                  );
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }
}