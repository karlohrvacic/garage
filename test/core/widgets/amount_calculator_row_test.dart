import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/widgets/amount_calculator_row.dart';

import '../../support/pump_screen.dart';

final _format = UnitFormat(locale: 'en', preferences: metricPreferences);

Future<TextEditingController> pumpRow(
  WidgetTester tester, {
  String initial = '',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);

  final controller = TextEditingController(text: initial);
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TextField(controller: controller),
            AmountCalculatorRow(controller: controller, format: _format),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets(
    'given the field\'s focus node, waits for the field to be focused',
    (tester) async {
      // Three permanent + − × ÷ rows on one sheet read as stray toolbars; the
      // operators belong to the field being typed in.
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, focusNode: focus),
                AmountCalculatorRow(
                  controller: controller,
                  format: _format,
                  focusNode: focus,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('×'), findsNothing);
      final resting = tester.getSize(find.byType(AmountCalculatorRow));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('×'), findsOneWidget);
      // Same height either way: appearing on focus, the row pushed Save
      // below the fold and the first tap on where Save had been only
      // blurred the field.
      expect(tester.getSize(find.byType(AmountCalculatorRow)), resting);
    },
  );

  testWidgets('the operator a thumb cannot reach on a number pad is offered', (
    tester,
  ) async {
    await pumpRow(tester);

    for (final glyph in ['+', '−', '×', '÷']) {
      expect(find.text(glyph), findsOneWidget);
    }
  });

  testWidgets('tapping an operator appends it to the amount', (tester) async {
    final controller = await pumpRow(tester, initial: '1.50');

    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();

    expect(controller.text, '1.50×');
  });

  testWidgets('an operator lands at the cursor, not at the end', (
    tester,
  ) async {
    final controller = await pumpRow(tester, initial: '150');
    controller.selection = const TextSelection.collapsed(offset: 1);

    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    expect(controller.text, '1+50');
    expect(
      controller.selection.baseOffset,
      2,
      reason: 'typing continues after the operator, not before it',
    );
  });

  testWidgets('an operator replaces the selection it was typed over', (
    tester,
  ) async {
    final controller = await pumpRow(tester, initial: '1.50');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 4);

    await tester.tap(find.text('÷'));
    await tester.pumpAndSettle();

    expect(controller.text, '÷');
  });

  testWidgets('a plain number gets no result line, because it needs none', (
    tester,
  ) async {
    await pumpRow(tester, initial: '12.50');

    expect(find.textContaining('='), findsNothing);
  });

  testWidgets('a sum shows what it comes to, in the household currency', (
    tester,
  ) async {
    await pumpRow(tester, initial: '2×1.50');

    expect(find.text('= €3.00'), findsOneWidget);
  });

  testWidgets('the result follows the field as it is typed', (tester) async {
    final controller = await pumpRow(tester, initial: '2×1.50');
    expect(find.text('= €3.00'), findsOneWidget);

    controller.text = '3×1.50';
    await tester.pumpAndSettle();

    expect(find.text('= €4.50'), findsOneWidget);
  });

  testWidgets('an unfinished sum shows nothing rather than a wrong total', (
    tester,
  ) async {
    await pumpRow(tester, initial: '2×');

    expect(find.textContaining('='), findsNothing);
  });

  testWidgets('a sum that cannot be read shows nothing', (tester) async {
    await pumpRow(tester, initial: '1//2');

    expect(find.textContaining('='), findsNothing);
  });
}
