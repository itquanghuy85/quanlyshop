import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/dashboard_config_service.dart';

/// Kiểm thử bước nâng cấp bố cục Trang chủ (v3 → v4).
///
/// Đây là logic đụng thẳng vào **bố cục người dùng đã tự sắp**, nên rủi ro lớn
/// nhất không phải "thiếu thẻ mới" mà là **đạp mất thứ tự cũ của họ**. App đang
/// chạy thật trên Play Store, người dùng đã quen chỗ nào ở đâu.

List<DashboardCardConfig> _cfg(List<(DashboardCardType, bool)> items) {
  var order = 0;
  return [
    for (final it in items)
      DashboardCardConfig(type: it.$1, visible: it.$2, order: order++),
  ];
}

void main() {
  const role = 'owner';
  const v3 = 3;

  group('Người dùng CHƯA từng tuỳ chỉnh', () {
    test('đang đúng y mẫu v3 ⇒ được nâng lên mặc định v4 mới', () {
      final saved = DashboardConfigService.debugV3Layout(
        role: role,
        isSuperAdmin: false,
      );
      final r = DashboardConfigService.debugMigrate(
        configs: saved,
        savedVersion: v3,
        role: role,
        isSuperAdmin: false,
      );

      final expected = DashboardConfigService.getDefaultLayout(
        role: role,
        isSuperAdmin: false,
      );
      expect(r.migrated, isTrue);
      expect(
        r.configs.map((c) => c.type).toList(),
        expected.map((c) => c.type).toList(),
        reason: 'phải nhận đúng thứ tự mặc định v4',
      );
    });

    test('thứ tự v4: việc gấp và thao tác nhanh lên trước chat', () {
      final d = DashboardConfigService.getDefaultLayout(
        role: role,
        isSuperAdmin: false,
      );
      final types = d.map((c) => c.type).toList();
      final iAction = types.indexOf(DashboardCardType.actionRequired);
      final iQuick = types.indexOf(DashboardCardType.quickActions);
      final iChat = types.indexOf(DashboardCardType.chat);
      final iFeed = types.indexOf(DashboardCardType.activityFeed);

      expect(iAction, 0, reason: 'việc gấp phải đứng đầu');
      expect(iQuick, lessThan(iChat));
      expect(iQuick, lessThan(iFeed),
          reason: 'người ta mở app để làm việc, không phải đọc chat');
    });
  });

  group('Người dùng ĐÃ tuỳ chỉnh — KHÔNG được đạp lên bố cục của họ', () {
    test('giữ nguyên thứ tự cũ, thẻ mới nối vào CUỐI', () {
      // Bố cục tự sắp: chat lên đầu, tắt cảnh báo.
      final saved = _cfg([
        (DashboardCardType.chat, true),
        (DashboardCardType.quickActions, true),
        (DashboardCardType.alerts, false),
        (DashboardCardType.greeting, true),
      ]);

      final r = DashboardConfigService.debugMigrate(
        configs: saved,
        savedVersion: v3,
        role: role,
        isSuperAdmin: false,
      );
      final types = r.configs.map((c) => c.type).toList();

      // 4 thẻ cũ giữ NGUYÊN thứ tự đã sắp.
      expect(types.take(4).toList(), [
        DashboardCardType.chat,
        DashboardCardType.quickActions,
        DashboardCardType.alerts,
        DashboardCardType.greeting,
      ]);
      // Và giữ nguyên trạng thái bật/tắt người dùng đã chọn.
      expect(
        r.configs.firstWhere((c) => c.type == DashboardCardType.alerts).visible,
        isFalse,
      );
      expect(
        r.configs
            .firstWhere((c) => c.type == DashboardCardType.greeting)
            .visible,
        isTrue,
        reason: 'người dùng bật Lời chào thì phải còn bật, dù v4 mặc định tắt',
      );
    });

    test('3 thẻ mới (Khám phá / Mẹo / Cộng đồng) được thêm vào', () {
      final saved = _cfg([
        (DashboardCardType.quickActions, true),
        (DashboardCardType.alerts, true),
      ]);
      final r = DashboardConfigService.debugMigrate(
        configs: saved,
        savedVersion: v3,
        role: role,
        isSuperAdmin: false,
      );
      final types = r.configs.map((c) => c.type).toSet();

      expect(types, contains(DashboardCardType.discovery));
      expect(types, contains(DashboardCardType.tipOfDay));
      expect(types, contains(DashboardCardType.community));
      expect(r.migrated, isTrue);
    });

    test('không mất thẻ nào — mọi loại còn dùng đều có mặt sau nâng cấp', () {
      final saved = _cfg([(DashboardCardType.quickActions, true)]);
      final r = DashboardConfigService.debugMigrate(
        configs: saved,
        savedVersion: v3,
        role: role,
        isSuperAdmin: false,
      );
      final types = r.configs.map((c) => c.type).toSet();

      for (final t in DashboardCardType.values) {
        final probe = DashboardCardConfig(type: t, visible: true, order: 0);
        if (probe.isRetired) continue;
        expect(types, contains(t), reason: 'thiếu thẻ ${probe.displayName}');
      }
    });

    test('order được đánh lại liên tục 0..n-1, không trùng, không hổng', () {
      final saved = _cfg([
        (DashboardCardType.chat, true),
        (DashboardCardType.alerts, true),
      ]);
      final r = DashboardConfigService.debugMigrate(
        configs: saved,
        savedVersion: v3,
        role: role,
        isSuperAdmin: false,
      );
      final orders = r.configs.map((c) => c.order).toList();
      expect(orders, List.generate(r.configs.length, (i) => i));
    });
  });

  group('Thẻ đã ngừng dùng', () {
    test('dailyReport bị lọc bỏ khỏi cấu hình đã lưu', () {
      final saved = _cfg([
        (DashboardCardType.quickActions, true),
        (DashboardCardType.dailyReport, true),
        (DashboardCardType.alerts, true),
      ]);
      final r = DashboardConfigService.debugMigrate(
        configs: saved,
        savedVersion: v3,
        role: role,
        isSuperAdmin: false,
      );
      expect(
        r.configs.any((c) => c.type == DashboardCardType.dailyReport),
        isFalse,
        reason: 'công tắc bật lên không hiện gì thì không nên còn trong danh sách',
      );
      expect(r.migrated, isTrue);
    });

    test('mặc định v4 không chứa thẻ đã ngừng dùng', () {
      final d = DashboardConfigService.getDefaultLayout(
        role: role,
        isSuperAdmin: false,
      );
      expect(d.any((c) => c.isRetired), isFalse);
    });
  });

  group('Phân quyền tài chính', () {
    test('nhân viên: các thẻ tài chính mặc định TẮT', () {
      final d = DashboardConfigService.getDefaultLayout(
        role: 'staff',
        isSuperAdmin: false,
      );
      for (final c in d.where((c) => c.requiresFinanceAccess)) {
        expect(c.visible, isFalse, reason: '${c.displayName} phải tắt với NV');
      }
    });

    test('chủ shop: chi tiết tài chính mặc định BẬT', () {
      final d = DashboardConfigService.getDefaultLayout(
        role: 'owner',
        isSuperAdmin: false,
      );
      expect(
        d
            .firstWhere((c) => c.type == DashboardCardType.financeDetail)
            .visible,
        isTrue,
      );
    });
  });

  test('đã ở phiên bản mới nhất ⇒ không đánh dấu migrated vô cớ', () {
    final saved = DashboardConfigService.getDefaultLayout(
      role: role,
      isSuperAdmin: false,
    );
    final r = DashboardConfigService.debugMigrate(
      configs: saved,
      savedVersion: DashboardConfigService.debugSchemaVersion,
      role: role,
      isSuperAdmin: false,
    );
    expect(r.migrated, isFalse);
    expect(r.configs.length, saved.length);
  });
}
