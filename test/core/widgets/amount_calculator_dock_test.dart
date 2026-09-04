import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/widgets/amount_calculator_dock.dart';

final _format = UnitFormat(
  locale: 'en',
  preferences: const UnitPreferences(
    distance: DistanceUnit.km,
    volume: VolumeUnit.liter,
    currencyCode: 'EUR',
  ),
);

void main() {
  testWidgets('serves whichever amount field has focus, in one fixed slot', (
    tester,
  ) async {
    final price = TextEditingController();
    final total = TextEditingController();
    final priceFocus = FocusNode();
    final totalFocus = FocusNode();
    addTearDown(() {
      price.dispose();
      total.dispose();
      priceFocus.dispose();
      totalFocus.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(
                key: const Key('price'),
                controller: price,
                focusNode: priceFocus,
              ),
              TextField(
                key: const Key('total'),
                controller: total,
                focusNode: totalFocus,
              ),
              AmountCalculatorDock(
                fields: [
                  AmountField(price, priceFocus),
                  AmountField(total, totalFocus),
                ],
                format: _format,
              ),
              const Text('save'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final saveAtRest = tester.getTopLeft(find.text('save'));
    expect(find.text('×'), findsNothing);

    await tester.tap(find.byKey(const Key('total')));
    await tester.pumpAndSettle();
    expect(find.text('×'), findsOneWidget);
    // Save has not moved: the slot was there all along.
    expect(tester.getTopLeft(find.text('save')), saveAtRest);

    await tester.tap(find.text('×'));
    await tester.pumpAndSettle();
    expect(total.text, '×');
    expect(price.text, isEmpty);
  });

  testWidgets('keeps the running total when focus moves on', (tester) async {
    // The total describes the value, not the keyboard: it used to vanish
    // when the person tapped Notes.
    final amount = TextEditingController();
    final notes = TextEditingController();
    final amountFocus = FocusNode();
    addTearDown(() {
      amount.dispose();
      notes.dispose();
      amountFocus.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(
                key: const Key('amount'),
                controller: amount,
                focusNode: amountFocus,
              ),
              TextField(key: const Key('notes'), controller: notes),
              AmountCalculatorDock(
                fields: [AmountField(amount, amountFocus)],
                format: _format,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('amount')), '2×1.50');
    await tester.pumpAndSettle();
    expect(find.text('= €3.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notes')));
    await tester.pumpAndSettle();
    expect(find.text('= €3.00'), findsOneWidget);
    expect(find.text('×'), findsNothing);
  });
}
