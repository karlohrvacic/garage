import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/vehicles/widgets/economy_chart.dart';

import '../../support/pump_screen.dart';

EconomyPoint point({
  String id = 'f1',
  int odometerKm = 50000,
  double litersPer100Km = 7.2,
}) {
  return EconomyPoint(
    entryId: id,
    date: DateTime.utc(2026, 5, 1),
    odometerKm: odometerKm,
    litersPer100Km: litersPer100Km,
    distanceKm: 500,
    volumeL: 36,
  );
}

Future<NavigationLog> pumpChart(
  WidgetTester tester,
  List<EconomyPoint> points, {
  Size surface = const Size(420, 700),
}) {
  return pumpScreen(
    tester,
    Scaffold(
      body: EconomyChart(
        points: points,
        formatEconomy: (value) =>
            value == null ? '—' : '${value.toStringAsFixed(1)} l/100km',
      ),
    ),
    surface: surface,
  );
}

void main() {
  testWidgets('one point cannot make a trend, and says so', (tester) async {
    await pumpChart(tester, [point()]);
    await tester.pumpAndSettle();

    expect(
      find.text('Log more full-tank fills to see the trend'),
      findsOneWidget,
    );
  });

  testWidgets('no points at all points at the gauge instead', (tester) async {
    // With nothing logged the figure above is empty too, so the chart says
    // what to do rather than "log more".
    await pumpChart(tester, const []);
    await tester.pumpAndSettle();

    expect(find.text('Log two full-tank fills to see economy'), findsOneWidget);
  });

  testWidgets('two points draw a line', (tester) async {
    await pumpChart(tester, [
      point(id: 'f1', odometerKm: 50000, litersPer100Km: 7.2),
      point(id: 'f2', odometerKm: 50500, litersPer100Km: 6.4),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.text('Log more full-tank fills to see the trend'),
      findsNothing,
    );
    expect(find.byType(EconomyChart), findsOneWidget);
  });

  // A real car's economy sits inside one or two l/100km, so the axis ticks are
  // fractions. Rounding each to a whole number printed the same label several
  // times over: a scale reading 7, 7, 6, 6, 5 down the side, which says
  // nothing about where the line is.
  testWidgets('the scale down the side does not repeat a label', (
    tester,
  ) async {
    await pumpChart(tester, [
      point(id: 'f1', odometerKm: 50000, litersPer100Km: 5.4),
      point(id: 'f2', odometerKm: 50600, litersPer100Km: 6.6),
      point(id: 'f3', odometerKm: 51200, litersPer100Km: 6.0),
    ]);
    await tester.pumpAndSettle();

    // Bottom-axis labels are odometer thousands and share the widget type, so
    // the left axis is identified by its own formatting: it is the one whose
    // labels carry a decimal.
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .where((label) => label.contains('.'))
        .toList();

    expect(labels, isNotEmpty, reason: 'the scale should be labelled at all');
    expect(labels.toSet(), hasLength(labels.length));
  });

  testWidgets('a long history still lays out on a narrow phone', (
    tester,
  ) async {
    await pumpChart(tester, [
      for (var i = 0; i < 40; i++)
        point(
          id: 'f$i',
          odometerKm: 50000 + i * 500,
          litersPer100Km: 6 + i % 3,
        ),
    ], surface: const Size(320, 640));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
