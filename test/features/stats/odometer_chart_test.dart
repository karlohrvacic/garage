import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/features/stats/providers/stats_providers.dart';
import 'package:garage/features/stats/widgets/odometer_chart.dart';
import 'package:garage/l10n/app_localizations.dart';

OdometerReading reading(
  int day,
  int km, {
  OdometerSource source = OdometerSource.fuel,
}) {
  return OdometerReading(
    date: DateTime.utc(2026, 1, day),
    km: km,
    source: source,
  );
}

Future<void> pumpChart(
  WidgetTester tester,
  List<List<OdometerReading>> readings,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 700);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: GarageTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: OdometerChart(
          readingsPerVehicle: readings,
          format: UnitFormat(
            locale: 'en',
            preferences: UnitPreferences(
              distance: DistanceUnit.km,
              volume: VolumeUnit.liter,
              currencyCode: 'EUR',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The chart used to colour every point by which table the reading came out
  // of, with a six-item legend under it naming fuel, service, costs, odometer,
  // trips and income. That answers a question nobody asks while looking at a
  // mileage curve — the curve is the story, and the key was most of the card.
  group('the odometer chart', () {
    final mixed = [
      [
        reading(1, 40000, source: OdometerSource.income),
        reading(20, 41000, source: OdometerSource.fuel),
        reading(40, 42500, source: OdometerSource.service),
        reading(60, 44000, source: OdometerSource.trip),
      ],
    ];

    testWidgets('does not explain where each reading came from', (
      tester,
    ) async {
      await pumpChart(tester, mixed);

      for (final label in ['Fuel', 'Service', 'Costs', 'Trips', 'Income']) {
        expect(
          find.text(label),
          findsNothing,
          reason:
              '"$label" is a key to a distinction the chart no longer draws',
        );
      }
    });

    testWidgets('draws every reading the same, whatever recorded it', (
      tester,
    ) async {
      await pumpChart(tester, mixed);

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final dots = chart.data.lineBarsData.single.dotData;
      final colours = {
        for (var i = 0; i < mixed.single.length; i++)
          dots
              .getDotPainter(
                FlSpot(i.toDouble(), mixed.single[i].km.toDouble()),
                0,
                chart.data.lineBarsData.single,
                i,
              )
              .mainColor,
      };

      expect(
        colours,
        hasLength(1),
        reason: 'four sources, one line, one colour',
      );
    });

    testWidgets('still draws the line itself', (tester) async {
      await pumpChart(tester, mixed);

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.single.spots, hasLength(4));
    });

    testWidgets('keeps one line per vehicle', (tester) async {
      await pumpChart(tester, [
        mixed.single,
        [reading(1, 10000), reading(60, 12000)],
      ]);

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(
        chart.data.lineBarsData,
        hasLength(2),
        reason: 'two cars are not points on the same series',
      );
    });

    testWidgets('labels its axis with the calendar, not with its own dates', (
      tester,
    ) async {
      // It used to print the first day, the last and the one halfway between
      // — "7/25", "2/26", "9/26" — three dates nobody would think to look for.
      await pumpChart(tester, [
        [
          OdometerReading(
            date: DateTime.utc(2025, 7, 20),
            km: 22000,
            source: OdometerSource.fuel,
          ),
          OdometerReading(
            date: DateTime.utc(2026, 9, 15),
            km: 50000,
            source: OdometerSource.fuel,
          ),
        ],
      ]);

      // A quarter apart, with the year where the year turns.
      for (final label in ['Oct', '2026', 'Apr', 'Jul']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('7/25'), findsNothing);
      expect(find.text('9/26'), findsNothing);
    });

    testWidgets('a span inside one month is labelled by its ends', (
      tester,
    ) async {
      await pumpChart(tester, [
        [reading(3, 40000), reading(23, 40600)],
      ]);

      expect(find.text('Jan 3'), findsOneWidget);
      expect(find.text('Jan 23'), findsOneWidget);
    });

    testWidgets('spaces its y-axis labels so they cannot collide', (
      tester,
    ) async {
      // The bottom two labels overlapped — "19k" printed under "20k" — because
      // the interval was left to the chart library and the axis minimum landed
      // a hair below the first gridline.
      await pumpChart(tester, mixed);

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final interval = chart.data.titlesData.leftTitles.sideTitles.interval;

      expect(interval, isNotNull);
      expect(interval, greaterThan(0));
    });
  });
}
