import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/vehicles/widgets/economy_chart.dart';

import '../../support/pump_screen.dart';

EconomyPoint at(int odometerKm, double economy) {
  return EconomyPoint(
    entryId: 'f$odometerKm',
    date: DateTime.utc(2026, 5, 1),
    odometerKm: odometerKm,
    litersPer100Km: economy,
    distanceKm: 500,
    volumeL: 36,
  );
}

Future<void> pumpChart(WidgetTester tester, List<EconomyPoint> points) {
  return pumpScreen(
    tester,
    Scaffold(
      body: EconomyChart(
        points: points,
        formatEconomy: (v) => v == null ? '—' : v.toStringAsFixed(1),
      ),
    ),
    surface: const Size(420, 700),
  );
}

void main() {
  // A car whose every measured tank came out the same gives the chart a range
  // of zero to scale against. The old sample data did exactly this — every
  // span was 6.0 — and a real household hits it the moment two tanks match.
  testWidgets('a perfectly flat history still draws', (tester) async {
    await pumpChart(tester, [at(50000, 6.0), at(50600, 6.0), at(51200, 6.0)]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('and so does one where every reading is zero', (tester) async {
    await pumpChart(tester, [at(50000, 0), at(50600, 0)]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  // Two fills at the same odometer would give the horizontal axis no range
  // either.
  testWidgets('and one that never moved', (tester) async {
    await pumpChart(tester, [at(50000, 6.0), at(50000, 6.4)]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
