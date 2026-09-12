import 'package:flutter/material.dart';

import '../services/user_service.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/responsive_wrapper.dart';
import '../widgets/top_services_widget.dart';

/// Màn toàn màn hình "Dịch vụ lãi nhất" — trước chỉ là một khối nhúng cuối
/// màn Báo cáo, theo đúng kỳ của báo cáo (mặc định hôm nay) nên gần như luôn
/// "Chưa có dữ liệu" và không bấm được gì. Ở đây mặc định 30 ngày, đổi kỳ
/// bằng chip; mở từ Trang chủ (THAO TÁC NHANH) hoặc chạm khối trong Báo cáo.
class TopServicesReportView extends StatefulWidget {
  const TopServicesReportView({super.key});

  @override
  State<TopServicesReportView> createState() => _TopServicesReportViewState();
}

class _TopServicesReportViewState extends State<TopServicesReportView> {
  static const _ranges = <String, int>{
    '7 ngày': 7,
    '30 ngày': 30,
    '90 ngày': 90,
    '1 năm': 365,
  };

  int _days = 30;
  bool _hasPermission = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    bool allowed = false;
    try {
      final perms = await UserService.getCurrentUserPermissions();
      allowed = perms['allowViewRevenue'] ?? false;
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    setState(() {
      _hasPermission = allowed;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final end = DateTime.now();
    final start = DateTime(end.year, end.month, end.day)
        .subtract(Duration(days: _days - 1));

    if (!_checked) {
      return Scaffold(
        appBar: CustomAppBar.build(title: 'Dịch vụ lãi nhất'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasPermission) {
      return Scaffold(
        appBar: CustomAppBar.build(title: 'Dịch vụ lãi nhất'),
        body: const Center(
          child: Text(
            'Bạn không có quyền truy cập tính năng này',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar.build(title: 'Dịch vụ lãi nhất'),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final e in _ranges.entries)
                  ChoiceChip(
                    label: Text(e.key),
                    selected: _days == e.value,
                    onSelected: (_) => setState(() => _days = e.value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TopServicesWidget(
              startDate: start,
              endDate: end,
              canOpenFullView: false,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

void openTopServicesReport(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => const TopServicesReportView()),
  );
}
