import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/services/dashboard_config_service.dart';
import 'package:quanlyshop/widgets/shortcut_edit_grid.dart';

void main() {
  List<ShortcutConfig> configs() => [
        ShortcutConfig(type: ShortcutType.sellCreate, visible: true, order: 0),
        ShortcutConfig(type: ShortcutType.repairCreate, visible: true, order: 1),
        ShortcutConfig(type: ShortcutType.stockIn, visible: true, order: 2),
        ShortcutConfig(type: ShortcutType.debt, visible: false, order: 3),
        // Not permitted for this user: must never show, must keep its slot.
        ShortcutConfig(type: ShortcutType.staff, visible: true, order: 4),
      ];

  Widget host(List<ShortcutConfig> list, {VoidCallback? onChanged}) =>
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: ShortcutEditGrid(
              configs: list,
              columns: 4,
              canShow: (c) => c.type != ShortcutType.staff,
              onChanged: onChanged ?? () {},
            ),
          ),
        ),
      );

  testWidgets('hides permission-filtered shortcuts, shows hidden section',
      (tester) async {
    await tester.pumpWidget(host(configs()));
    expect(find.text('Nhân sự'), findsNothing);
    expect(find.text('Công nợ'), findsOneWidget);
    expect(find.textContaining('ĐÃ ẨN (1)'), findsOneWidget);
  });

  testWidgets('long-press drag reorders on the full list', (tester) async {
    final list = configs();
    var changed = 0;
    await tester.pumpWidget(host(list, onChanged: () => changed++));

    final from = tester.getCenter(find.text('Bán hàng'));
    final to = tester.getCenter(find.text('Nhập kho'));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 200)); // past delay
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(list.map((c) => c.type).toList(), [
      ShortcutType.repairCreate,
      ShortcutType.stockIn,
      ShortcutType.sellCreate,
      ShortcutType.debt,
      ShortcutType.staff,
    ]);
    expect(list.map((c) => c.order).toList(), [0, 1, 2, 3, 4]);
    expect(changed, greaterThan(0));
  });

  testWidgets('− hides, tapping hidden tile restores at end of visible',
      (tester) async {
    final list = configs();
    await tester.pumpWidget(host(list));

    // Red badge of the first visible tile.
    await tester.tap(find.byIcon(Icons.remove).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(list[0].visible, isFalse);
    expect(find.textContaining('ĐÃ ẨN (2)'), findsOneWidget);

    // Restore "Công nợ": should land right after the last visible one.
    await tester.tap(find.text('Công nợ'));
    await tester.pump(const Duration(milliseconds: 300));
    final debt = list.firstWhere((c) => c.type == ShortcutType.debt);
    expect(debt.visible, isTrue);
    final lastVisible = list.lastIndexWhere((c) => c.visible);
    expect(list[lastVisible].type, ShortcutType.debt);
  });
}
