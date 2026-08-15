import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/features/stats/providers/stats_providers.dart';
import 'package:garage/features/stats/screens/stats_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

FuelEntry fill(String id, int odometerKm, {double total = 62}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 5, 1).add(Duration(days: odometerKm ~/ 100)),
    odometerKm: odometerKm,
    volumeL: 40,
    pricePerL: total / 40,
    total: total,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

StatsData statsWith({
  List<FuelEntry> fuel = const [],
  List<ServiceEntry> services = const [],
  List<CostEntry> costs = const [],
}) {
  return StatsData(
    fuel: fuel,
    services: services,
    costs: costs,
    economy: FuelEconomy.compute(fuel),
    readingsPerVehicle: [
      [
        for (final entry in fuel)
          OdometerReading(date: entry.date, km: entry.odometerKm),
      ],
    ],
  );
}

Future<NavigationLog> pumpStats(WidgetTester tester, {StatsData? data}) {
  final stats = data ?? statsWith();
  return pumpScreen(
    tester,
    const StatsScreen(),
    initialLocation: '/stats',
    surface: const Size(420, 1400),
    overrides: [
      vehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
      statsDataProvider(null).overrideWith((ref) async => stats),
      statsDataProvider('v1').overrideWith((ref) async => stats),
    ],
  );
}

void main() {
  testWidgets('the three stats tabs are offered', (tester) async {
    await pumpStats(tester);
    await tester.pumpAndSettle();

    expect(find.text('Fill-ups'), findsWidgets);
    expect(find.text('Costs'), findsWidgets);
    expect(find.text('Distance'), findsWidgets);
  });

  testWidgets('a household with no data says so', (tester) async {
    await pumpStats(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Not enough data'), findsWidgets);
  });

  testWidgets('fill-up figures are summarised', (tester) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500, total: 70)]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Fill-ups'), findsWidgets);
    expect(find.textContaining('l'), findsWidgets);
  });

  testWidgets('the costs tab totals spend with and without fuel', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(
        fuel: [fill('f1', 50000)],
        costs: [
          CostEntry(
            id: 'c1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 3, 1),
            category: CostCategories.insurance,
            amount: 300,
            createdBy: 'u1',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Costs').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('362'), findsWidgets);
    expect(find.textContaining('300'), findsWidgets);
  });

  testWidgets('the distance tab reports what the odometer covered', (
    tester,
  ) async {
    await pumpStats(
      tester,
      data: statsWith(fuel: [fill('f1', 50000), fill('f2', 50500)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Distance').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('500 km'), findsWidgets);
  });

  testWidgets('a vehicle can be picked out of the fleet', (tester) async {
    await pumpStats(tester, data: statsWith(fuel: [fill('f1', 50000)]));
    await tester.pumpAndSettle();

    expect(find.text('All vehicles'), findsWidgets);
  });
}
