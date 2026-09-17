import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/calculator/screens/calculator_screen.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:go_router/go_router.dart';

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

  /// The chosen car's own average, when it differs from the fleet's.
  double? Function()? vehicleEconomy,
  List<Vehicle>? vehicles,
  List<FuelEntry> log = const [],
  UnitPreferences preferences = metricPreferences,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(320, 3200),
}) {
  return pumpScreen(
    tester,
    const CalculatorScreen(),
    initialLocation: '/calculator',
    locale: locale,
    textScale: textScale,
    surface: surface,
    preferences: preferences,
    overrides: [
      vehiclesProvider.overrideWith(
        (ref) async => vehicles ?? [testVehicle('v1', nickname: 'Golf')],
      ),
      fleetAverageEconomyProvider.overrideWith((ref) async => fleetEconomy),
      averageEconomyProvider('v1').overrideWith(
        (ref) async => vehicleEconomy == null ? fleetEconomy : vehicleEconomy(),
      ),
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

  // The same box appears in two modes and means opposite things: fuel you
  // still have, and fuel you have already burned. It was labelled "Volume" in
  // both, borrowed from the fill-up sheet where the surrounding form supplies
  // the context — standing alone here it asked for a quantity of nothing in
  // particular. Two tests rather than one because `chooseMode` opens the
  // dropdown by its current label and so can only switch once.
  testWidgets('in distance mode the fuel box is what is in the tank', (
    tester,
  ) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await chooseMode(tester, 'Distance');
    await tester.pumpAndSettle();

    expect(
      find.text('Fuel in the tank'),
      findsOneWidget,
      reason: 'the question is how far this much will get you',
    );
    expect(find.text('Fuel used'), findsNothing);
  });

  testWidgets('in consumption mode the same box is what has been burned', (
    tester,
  ) async {
    await pumpCalculator(tester, fleetEconomy: null);
    await tester.pumpAndSettle();

    await chooseMode(tester, 'Consumption');
    await tester.pumpAndSettle();

    expect(find.text('Fuel used'), findsOneWidget);
    expect(find.text('Fuel in the tank'), findsNothing);
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

  // The first field was labelled with the name of its own default option, so
  // the screen read "All vehicles" above a box already saying "All vehicles",
  // while every field under it named what it was for.
  testWidgets('the vehicle picker is labelled by what it picks', (
    tester,
  ) async {
    await pumpCalculator(tester);
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsOneWidget);
    expect(
      find.text('All vehicles'),
      findsOneWidget,
      reason: 'the option keeps its name; only the label above it changes',
    );
  });

  // The prefill reads five providers with awaits between them, so leaving the
  // screen while it is in flight lands the next read on a dead element — the
  // `Using "ref" ... unmounted is unsafe` crash, from a screen nobody would
  // think to blame because they had already left it.
  testWidgets('leaving while the prefill is in flight does not throw', (
    tester,
  ) async {
    final gate = Completer<List<Vehicle>>();
    await pumpScreen(
      tester,
      const CalculatorScreen(),
      initialLocation: '/calculator',
      overrides: [
        vehiclesProvider.overrideWith((ref) => gate.future),
        fleetAverageEconomyProvider.overrideWith((ref) async => 6.5),
        averageEconomyProvider('v1').overrideWith((ref) async => 6.5),
        rawFuelEntriesProvider('v1').overrideWith((ref) async => [fill()]),
      ],
    );
    await tester.pump();

    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
    await tester.pumpAndSettle();

    gate.complete([testVehicle('v1', nickname: 'Golf')]);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('every input says its unit', (tester) async {
    await pumpCalculator(tester, log: [fill()]);
    await tester.pumpAndSettle();

    // Trip cost mode: distance, consumption and price are asked for.
    expect(find.text('km'), findsOneWidget);
    expect(find.text('l/100km'), findsWidgets);
    expect(find.text('€/l'), findsOneWidget);
  });

  // The calculator works in litres. A charge is priced per kilowatt-hour and
  // an electric car's consumption is kilowatt-hours per 100 km: seeded as
  // though they were litres, they came out as a price per gallon and a figure
  // in miles per gallon that nobody had typed.
  group('a charge seeds nothing into a calculator of litres', () {
    testWidgets('the price is the last one paid for a tank', (tester) async {
      await pumpCalculator(
        tester,
        vehicles: [
          testVehicle(
            'v1',
            nickname: 'Outlander',
            fuelTypeKey: 'fuel_petrol',
            secondaryFuelTypeKey: 'fuel_electric',
          ),
        ],
        log: [
          fill(pricePerL: 1.55, date: DateTime.utc(2026, 7, 1)),
          fill(
            pricePerL: 0.30,
            date: DateTime.utc(2026, 7, 24),
          ).copyWith(fuelTypeKey: 'fuel_electric'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('1.55'), findsOneWidget);
      expect(find.text('0.30'), findsNothing);
    });

    testWidgets('an electric garage leaves the price for you', (tester) async {
      await pumpCalculator(
        tester,
        vehicles: [testVehicle('v1', fuelTypeKey: 'fuel_electric')],
        fleetEconomy: null,
        log: [fill(pricePerL: 0.30)],
      );
      await tester.pumpAndSettle();

      expect(find.text('0.30'), findsNothing);
    });

    testWidgets('an electric car picked leaves consumption for you', (
      tester,
    ) async {
      await pumpCalculator(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Leaf', fuelTypeKey: 'fuel_electric'),
        ],
        fleetEconomy: null,
        vehicleEconomy: () => 18,
        log: [fill(pricePerL: 0.30)],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('All vehicles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leaf').last);
      await tester.pumpAndSettle();

      expect(find.text('18.0'), findsNothing);
      expect(find.text('0.30'), findsNothing);
    });
  });

  group('a household that reads miles and gallons', () {
    // The inputs went straight into the maths as km and litres while the
    // results came out converted, so the screen contradicted itself.
    const imperial = UnitPreferences(
      distance: DistanceUnit.mi,
      volume: VolumeUnit.usGallon,
      currencyCode: 'USD',
    );

    testWidgets('seeds consumption in mpg and price per gallon', (
      tester,
    ) async {
      await pumpCalculator(tester, log: [fill()], preferences: imperial);
      await tester.pumpAndSettle();

      // 6.5 l/100km inverted, and 1.55 €/l by the litres in a US gallon.
      expect(find.text('36.2'), findsOneWidget);
      expect(find.text('5.87'), findsOneWidget);
      expect(find.text('mpg'), findsWidgets);
      expect(find.text(r'$/gal'), findsOneWidget);
    });

    testWidgets('a trip typed in miles costs what the maths says', (
      tester,
    ) async {
      await pumpCalculator(tester, log: [fill()], preferences: imperial);
      await tester.pumpAndSettle();

      await tester.enterText(field(0), '100');
      await tester.pumpAndSettle();

      // 100 mi at 36.2 mpg and $5.87/gal, computed in km and litres.
      expect(find.text(r'$16.22'), findsOneWidget);
    });
  });

  testWidgets('in Croatian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    await pumpCalculator(tester, locale: const Locale('hr'), textScale: 1.5);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('in Italian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    await pumpCalculator(tester, locale: const Locale('it'), textScale: 1.5);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
