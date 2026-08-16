import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/repair_model.dart';
import '../utils/money_utils.dart';
import '../widgets/custom_app_bar.dart';
import 'repair_detail_view.dart';

/// Danh sách các đơn sửa chữa đã dùng để tính "Giá tham khảo" (Bảng giá
/// thông minh) — CHỈ ĐỌC, cho phép xem/tham khảo từng đơn, không có thao
/// tác chỉnh sửa nào trên màn này.
class SimilarRepairHistoryView extends StatelessWidget {
  const SimilarRepairHistoryView({super.key, required this.repairs});

  final List<Repair> repairs;

  String _statusLabel(int status, {bool pendingApproval = false}) {
    switch (status) {
      case 1:
        return 'TIẾP NHẬN';
      case 2:
        return 'ĐANG SỬA';
      case 3:
        return pendingApproval ? 'CHỜ DUYỆT GIAO' : 'SỬA XONG';
      case 4:
        return 'ĐÃ GIAO';
      default:
        return '—';
    }
  }

  Color _statusColor(int status, {bool pendingApproval = false}) {
    switch (status) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return pendingApproval ? Colors.deepOrange : Colors.green;
      case 4:
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  Widget _infoChip(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? Colors.blueGrey).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.blueGrey.shade800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...repairs]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: CustomAppBar.build(
        title: 'ĐƠN SỬA TƯƠNG TỰ',
        subtitle: '${sorted.length} đơn dùng để tính giá tham khảo',
      ),
      body: sorted.isEmpty
          ? const Center(child: Text('Không có đơn nào'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = sorted[i];
                final profit = r.price - r.cost;
                final hasTechnician = (r.repairedBy ?? '').trim().isNotEmpty;

                void openDetail() => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RepairDetailView(repair: r),
                  ),
                );

                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    onTap: openDetail,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Model + trạng thái
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r.model,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    r.status,
                                    pendingApproval: r.pendingDeliveryApproval,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel(
                                    r.status,
                                    pendingApproval: r.pendingDeliveryApproval,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (r.issue.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              r.issue,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          // Thông tin theo dõi nhanh — không cần bấm vào mới xem
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (r.customerName.trim().isNotEmpty)
                                _infoChip('👤 ${r.customerName}'),
                              if (r.phone.trim().isNotEmpty)
                                _infoChip('📞 ${r.phone}'),
                              _infoChip(
                                '⏱ ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(r.createdAt))}',
                              ),
                              if (hasTechnician)
                                _infoChip(
                                  '🔧 ${r.repairedBy}',
                                  color: Colors.purple.shade700,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          // Tài chính + link xem chi tiết
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 10,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${MoneyUtils.formatCurrency(r.price)}đ',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Vốn ${MoneyUtils.formatCurrency(r.cost)}đ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      profit >= 0
                                          ? 'Lãi ${MoneyUtils.formatCurrency(profit)}đ'
                                          : 'Lỗ ${MoneyUtils.formatCurrency(profit.abs())}đ',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: profit >= 0
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: openDetail,
                                icon: const Icon(
                                  Icons.open_in_new_rounded,
                                  size: 15,
                                ),
                                label: const Text('Xem chi tiết'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
