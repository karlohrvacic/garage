import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// How wide [text] is when nothing cuts it short, in the font, style and scale
/// it was actually drawn with.
double naturalWidth(RenderParagraph paragraph) {
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

void main() {
  // A legend is a column of figures, and a column of figures that does not
  // line up is harder to compare than a list of sentences. All three of the
  // ways this row can go wrong have happened, so all three are held here.
  group('the legend', () {
    testWidgets('never cuts an amount short', (tester) async {
      // The regression: the amount took a quarter of the row whatever it
      // said, and "€1,229.45" on a phone came out as "€1,229.…" — the one
      // figure the legend exists to show, with its cents replaced by dots.
      await pumpDonut(
        tester,
        slices: const [
          SpendSlice(label: 'Petrol', amount: 1229.45),
          SpendSlice(label: 'INA', amount: 1042.10),
          SpendSlice(label: 'Tifon', amount: 60.19),
        ],
        surface: const Size(360, 900),
      );

      for (final amount in ['€1,229.45', '€1,042.10', '€60.19']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(amount),
        );
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(naturalWidth(paragraph)),
          reason: '$amount was drawn in a box narrower than itself',
        );
      }
    });

    testWidgets('gives the share up before it cuts the amount', (tester) async {
      // Every fixed part scales with the text, so a legend can reach a width
      // where the swatch, the share and the amount alone do not fit the row.
      // The amount is the figure; the share is the one to lose.
      await pumpDonut(
        tester,
        slices: const [
          SpendSlice(label: 'Petrol i plin Zagreb zapad', amount: 12345.67),
          SpendSlice(label: 'INA Savska', amount: 987.65),
        ],
        locale: const Locale('hr'),
        surface: const Size(320, 900),
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('%'), findsNothing);
      final amount = tester.renderObject<RenderParagraph>(
        find.textContaining('12.345,67'),
      );
      expect(amount.size.width, greaterThanOrEqualTo(naturalWidth(amount)));
    });

    testWidgets('keeps the share when there is room for it', (tester) async {
      await pumpDonut(tester);

      expect(find.text('60%'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
    });

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
