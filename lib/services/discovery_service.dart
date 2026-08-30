import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/db_helper.dart';
import '../data/discovery_checklist.dart';

/// Trạng thái thẻ "Khám phá Ứng Dụng" ở Trang chủ.
///
/// Một nhiệm vụ coi là XONG khi: (a) người dùng đã bấm vào nó, hoặc
/// (b) dữ liệu thực tế cho thấy đã làm (vd đã có ≥1 đơn sửa).
class DiscoveryStatus {
  final List<DiscoveryTask> tasks;
  final Set<String> doneIds;
  final bool dismissed;

  const DiscoveryStatus({
    required this.tasks,
    required this.doneIds,
    required this.dismissed,
  });

  int get total => tasks.length;
  int get done => tasks.where((t) => doneIds.contains(t.id)).length;
  double get progress => total == 0 ? 0 : done / total;
  bool get allDone => total > 0 && done >= total;

  /// Có nên hiện thẻ không: chưa ẩn tay và chưa hoàn thành hết.
  bool get shouldShow => !dismissed && !allDone;
}

class DiscoveryService {
  DiscoveryService._();

  static const _pfxDone = 'discovery_done_';
  static const _keyDismissed = 'discovery_dismissed_v1';

  static List<DiscoveryTask> tasksFor(String? role) {
    final r = (role ?? '').toLowerCase();
    return kDiscoveryTasks.where((t) {
      if (t.audience.contains('all') || r.isEmpty) return true;
      if (r == 'owner' || r == 'admin' || r == 'super_admin') return true;
      return t.audience.contains(r);
    }).toList();
  }

  static Future<void> markDone(String id, {bool done = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_pfxDone$id', done);
    } catch (_) {}
  }

  static Future<void> setDismissed(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDismissed, value);
    } catch (_) {}
  }

  /// Tính trạng thái đầy đủ (prefs + suy từ dữ liệu). An toàn khi lỗi → coi như chưa xong.
  static Future<DiscoveryStatus> load(String? role) async {
    final tasks = tasksFor(role);
    final ids = tasks.map((t) => t.id).toSet();
    final done = <String>{};
    var dismissed = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      dismissed = prefs.getBool(_keyDismissed) ?? false;
      for (final id in ids) {
        if (prefs.getBool('$_pfxDone$id') == true) done.add(id);
      }
    } catch (_) {}

    // Suy từ dữ liệu thực tế — chỉ dùng các bộ đếm công khai, sẵn có.
    try {
      final db = DBHelper();
      if (ids.contains('create-repair') && await db.getRepairsCount() > 0) {
        done.add('create-repair');
      }
      if (ids.contains('create-sale') && await db.getSalesCount() > 0) {
        done.add('create-sale');
      }
      if (ids.contains('stock-in') && await db.getProductsCount() > 0) {
        done.add('stock-in');
      }
    } catch (e) {
      debugPrint('DiscoveryService.load auto-detect: $e');
    }

    return DiscoveryStatus(tasks: tasks, doneIds: done, dismissed: dismissed);
  }
}
