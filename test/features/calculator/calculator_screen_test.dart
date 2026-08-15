import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/calculator/screens/calculator_screen.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/pump_screen.dart';

FuelEntry fill({double? pricePerL = 1.55, DateTime? date}) {
  return FuelEntry(
    id: 'f1',
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 7, 24),
    odometerKm: 51000,
    volumeL: 40,
    pricePerL: pricePerL,
    total: 62,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

Future<NavigationLog> pumpCalculator(
  WidgetTester tester, {
  double? fleetEconomy = 6.5,
  List<FuelEntry> log = const [],
}) {
  return pumpScreen(
    tester,
    const CalculatorScreen(),
    initialLocation: '/calculator',
    overrides: [
      vehiclesProvider.overrideWith(
        (ref) async => [testVehicle('v1', nickname: 'Golf')],
      ),
      fleetAverageEconomyProvider.overrideWith((ref) async => fleetEconomy),
      averageEconomyProvider('v1').overrideWith((ref) async => fleetEconomy),
      rawFuelEntriesProvider('v1').overrideWith((ref) async => log),
    ],
  );
}

/// The calculator's fields, in the order they appear on screen.
Finder field(int index) => find.byType(TextField).at(index);

Future<void> chooseMode(WidgetTester tester, String label) async {
  await tester.tap(find.text('Trip cost').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it seeds consumption and price from real data', (tester) async {
    await pumpCalculator(tester, log: [fill()]);
    await tester.pumpAndSettle();

    expect(find.text('6.5'), findsOneWidget);
    expect(find.text('1.55'), findsOneWidget);
  });

  testWidgets('a trip cost is computed from distance, use, and price', (
    tester,
  ) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await tester.enterText(field(0), '100');
    await tester.enterText(field(1), '8');
    await tester.enterText(field(2), '1.50');
    await tester.pumpAndSettle();

    // 100 km at 8 l/100km is 8 l, at €1.50 that is €12.
    expect(find.text('€12.00'), findsOneWidget);
  });

  testWidgets('an incomplete calculation shows no result', (tester) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await tester.enterText(field(0), '100');
    await tester.pumpAndSettle();

    expect(find.text('—'), findsWidgets);
  });

  testWidgets('a comma decimal separator is accepted', (tester) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await tester.enterText(field(0), '100');
    await tester.enterText(field(1), '8');
    await tester.enterText(field(2), '1,50');
    await tester.pumpAndSettle();

    expect(find.text('€12.00'), findsOneWidget);
  });

  testWidgets('the reachable-distance mode answers in kilometres', (
    tester,
  ) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await chooseMode(tester, 'Distance');
    await tester.enterText(field(0), '40');
    await tester.enterText(field(1), '8');
    await tester.pumpAndSettle();

    // 40 l at 8 l/100km reaches 500 km.
    expect(find.text('500 km'), findsOneWidget);
  });

  testWidgets('the consumption mode answers in l/100km', (tester) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await chooseMode(tester, 'Consumption');
    await tester.enterText(field(0), '500');
    await tester.enterText(field(1), '40');
    await tester.pumpAndSettle();

    expect(find.text('8.0 l/100km'), findsOneWidget);
  });

  testWidgets('the required-fuel mode answers in litres', (tester) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await chooseMode(tester, 'Required fuel');
    await tester.enterText(field(0), '500');
    await tester.enterText(field(1), '8');
    await tester.pumpAndSettle();

    expect(find.text('40.00 l'), findsOneWidget);
  });
}
