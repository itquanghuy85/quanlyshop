import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanlyshop/widgets/warranty_note_field.dart';

void main() {
  testWidgets('bấm ✕ rồi gõ tự do — không bị nối đuôi "KO BH"', (t) async {
    String value = '12 THÁNG';
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setS) => WarrantyNoteField(
              value: value,
              onChanged: (v) => setS(() => value = v),
            ),
          ),
        ),
      ),
    );
    expect(find.text('12 THÁNG'), findsWidgets);

    await t.tap(find.byIcon(Icons.clear));
    await t.pumpAndSettle();
    expect(value, 'KO BH');
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');

    await t.enterText(find.byType(TextField), 'BH TAI NGHE 3 THANG');
    await t.pumpAndSettle();
    expect(value, 'BH TAI NGHE 3 THANG');
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      'BH TAI NGHE 3 THANG',
    );
  });

  testWidgets('bấm chip ghi đúng chữ chip vào ô', (t) async {
    String value = 'KO BH';
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setS) => WarrantyNoteField(
              value: value,
              onChanged: (v) => setS(() => value = v),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.widgetWithText(ChoiceChip, '6 THÁNG'));
    await t.pumpAndSettle();
    expect(value, '6 THÁNG');
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '6 THÁNG');
  });
}
