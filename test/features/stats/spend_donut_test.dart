import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/stats/spend_breakdown.dart';
import 'package:garage/features/stats/widgets/spend_donut.dart';

import '../../support/pump_screen.dart';

Future<void> pumpDonut(
  WidgetTester tester, {
  List<SpendSlice> slices = const [
    SpendSlice(label: 'INA', amount: 120),
    SpendSlice(label: 'Petrol', amount: 80),
  ],
  Size surface = const Size(420, 900),
  Locale? locale,
  double textScale = 1,
}) async {
  await pumpScreen(
    tester,
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: SpendDonut(
          title: 'By station',
          slices: slices,
          format: UnitFormat(
            locale: locale?.languageCode ?? 'en',
            preferences: metricPreferences,
          ),
        ),
      ),
    ),
    surface: surface,
    locale: locale,
  );
  await tester.pumpAndSettle();
}

void main() {
  // A legend is a column of figures, and a column of figures that does not
  // line up is harder to compare than a list of sentences. Both of the ways
  // this row can go wrong have happened, so both are held here.
  group('the legend', () {
    testWidgets('ends its amounts flush, at the same edge', (tester) async {
      // The regression: making the amount `Flexible` to stop an overflow let
      // it *under-fill* its slot, so the leftover space landed after it and
      // the amounts ended at 342 and 327 on a 420px card instead of together.
      await pumpDonut(tester);

      expect(
        tester.getBottomRight(find.text('€120.00')).dx,
        tester.getBottomRight(find.text('€80.00')).dx,
      );
    });

    testWidgets('fits a long name in Croatian at 320px and 1.5x', (
      tester,
    ) async {
      // The overflow the flexing was for: the swatch, the percentage and the
      // amount are fixed widths that scale with the text, and at this size
      // they ran 12 pixels past the row with the label already given up.
      await pumpDonut(
        tester,
        slices: const [
          SpendSlice(label: 'Petrol i plin Zagreb zapad', amount: 1234.56),
          SpendSlice(label: 'INA Savska', amount: 987.65),
        ],
        locale: const Locale('hr'),
        surface: const Size(320, 900),
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a long name in Italian at 320px and 1.5x', (
      tester,
    ) async {
      // The overflow the flexing was for: the swatch, the percentage and the
      // amount are fixed widths that scale with the text, and at this size
      // they ran 12 pixels past the row with the label already given up.
      await pumpDonut(
        tester,
        slices: const [
          SpendSlice(label: 'Petrol i plin Zagreb zapad', amount: 1234.56),
          SpendSlice(label: 'INA Savska', amount: 987.65),
        ],
        locale: const Locale('it'),
        surface: const Size(320, 900),
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
