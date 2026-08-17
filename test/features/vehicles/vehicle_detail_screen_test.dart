import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/data/recall_lookup.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/features/vehicles/screens/vehicle_detail_screen.dart';

import '../../support/pump_screen.dart';

final _today = DateTime(2026, 8, 15);

FuelEntry fill(String id, int odometerKm) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 5, 1).add(Duration(days: odometerKm ~/ 100)),
    odometerKm: odometerKm,
    volumeL: 40,
    pricePerL: 1.55,
    total: 62,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

ServiceEntry service({String id = 's1', double? cost = 210.5}) {
  return ServiceEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 4, 2),
    odometerKm: 49000,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: 'u1',
    cost: cost,
    shop: 'Auto Hrvoje',
  );
}

CostEntry cost({String id = 'c1'}) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 3, 1),
    category: CostCategories.insurance,
    amount: 320,
    createdBy: 'u1',
  );
}

ReminderProjection projection() {
  return ReminderProjection(
    ruleId: 'r1',
    vehicleId: 'v1',
    serviceTypeKey: 'service_oil_change',
    projectedDueDate: _today.add(const Duration(days: 12)),
    state: ReminderState.upcoming,
    dueOdometerKm: 60000,
    fractionConsumed: 0.7,
  );
}

class FakeRecallLookup implements RecallLookup {
  FakeRecallLookup({this.found = const [], this.fails = false});

  final List<Recall> found;
  final bool fails;
  final List<String> asked = [];

  @override
  Future<List<Recall>> forVehicle({
    required String? make,
    required String? model,
    required int? year,
  }) async {
    asked.add('$make $model $year');
    if (fails) {
      throw Exception('nope');
    }
    return found;
  }
}

Future<NavigationLog> pumpDetail(
  WidgetTester tester, {
  Vehicle? vehicle,
  FakeRecallLookup? recalls,
  List<FuelEntry> fuel = const [],
  List<ServiceEntry> services = const [],
  List<CostEntry> costs = const [],
  List<ReminderProjection> projections = const [],
  Size surface = const Size(420, 1200),
}) {
  final car = vehicle ?? testVehicle('v1', nickname: 'Golf');
  return pumpScreen(
    tester,
    const VehicleDetailScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1',
    surface: surface,
    extraRoutes: const {
      '/vehicles/v1/fuel',
      '/vehicles/v1/maintenance',
      '/vehicles/v1/edit',
    },
    overrides: [
      vehicleProvider('v1').overrideWith((ref) async => car),
      allVehiclesProvider.overrideWith((ref) async => [car]),
      vehiclesProvider.overrideWith((ref) async => [car]),
      rawFuelEntriesProvider('v1').overrideWith((ref) async => fuel),
      economyPointsProvider(
        'v1',
      ).overrideWith((ref) async => FuelEconomy.compute(fuel)),
      averageEconomyProvider('v1').overrideWith(
        (ref) async => FuelEconomy.average(FuelEconomy.compute(fuel)),
      ),
      serviceEntriesProvider('v1').overrideWith((ref) async => services),
      costEntriesProvider('v1').overrideWith((ref) async => costs),
      vehicleProjectionsProvider('v1').overrideWith((ref) async => projections),
      currentOdometerProvider('v1').overrideWith((ref) async => 51000),
      todayProvider.overrideWithValue(_today),
      recallLookupProvider.overrideWithValue(recalls ?? FakeRecallLookup()),
    ],
  );
}

Vehicle identifiedCar() {
  return Vehicle(
    id: 'v1',
    householdId: 'h1',
    nickname: 'Golf',
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 50000,
    baselineDate: DateTime.utc(2026, 1, 1),
    make: 'Volkswagen',
    model: 'Golf',
    year: 2015,
  );
}

Recall recall({String campaign = '23V123000'}) {
  return Recall(
    campaign: campaign,
    component: 'ENGINE',
    summary: 'The coil pack may fail.',
    remedy: 'Dealers will replace it free of charge.',
  );
}

void main() {
  group('the tab strip', () {
    testWidgets('spans the pane on a desktop window, not the text column', (
      tester,
    ) async {
      // Tabs belong to the surface they switch, so the strip and its divider
      // run edge to edge under the header; the reading column is for what the
      // tab then shows. Inside the column it reads as floating mid-page.
      await pumpDetail(tester, surface: const Size(1400, 1000));
      await tester.pumpAndSettle();

      final strip = tester.getSize(find.byType(TabBar)).width;

      expect(
        strip,
        greaterThan(GarageBreakpoints.contentMaxWidth),
        reason: 'the strip was capped at the reading column',
      );
      // Everything but the navigation rail and its divider.
      expect(strip, greaterThan(1400 - 300));
    });

    testWidgets('every label fits a narrow phone without scrolling', (
      tester,
    ) async {
      // Four text labels fit where four labels with icons above them did not;
      // that truncation is what the scrollable strip was working around.
      await pumpDetail(tester, surface: const Size(360, 900));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Economy'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Costs'), findsOneWidget);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).isScrollable,
        isFalse,
        reason: 'four labels that fit should divide the width evenly',
      );
    });

    testWidgets('the longest label is not cut off on a small phone', (
      tester,
    ) async {
      // The reason the strip used to scroll. Four labels across 360 pixels
      // leave about 90 each, which "Maintenance" fits only without an icon
      // above it competing for the same tab.
      await pumpDetail(tester, surface: const Size(360, 900));
      await tester.pumpAndSettle();

      final label = tester.renderObject<RenderParagraph>(
        find.text('Maintenance'),
      );

      expect(label.didExceedMaxLines, isFalse);
    });

    testWidgets('is labels alone, like every other tabbed screen', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      final tabs = tester
          .widgetList<Tab>(find.byType(Tab))
          .toList(growable: false);

      expect(tabs, hasLength(4));
      for (final tab in tabs) {
        expect(tab.icon, isNull);
      }
    });
  });

  testWidgets('the vehicle is named in the app bar', (tester) async {
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    expect(find.text('Golf'), findsWidgets);
  });

  testWidgets('all four tabs are offered', (tester) async {
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    expect(find.byType(Tab), findsNWidgets(4));
  });

  testWidgets('a vehicle with one fill cannot show economy yet', (
    tester,
  ) async {
    await pumpDetail(tester, fuel: [fill('f1', 50000)]);
    await tester.pumpAndSettle();

    expect(find.text('Log two full-tank fills to see economy'), findsOneWidget);
  });

  testWidgets('two full fills produce an economy figure', (tester) async {
    await pumpDetail(tester, fuel: [fill('f1', 50000), fill('f2', 50500)]);
    await tester.pumpAndSettle();

    expect(find.textContaining('l/100km'), findsWidgets);
  });

  testWidgets('an electric vehicle reads its economy in kWh', (tester) async {
    await pumpDetail(
      tester,
      vehicle: Vehicle(
        id: 'v1',
        householdId: 'h1',
        nickname: 'Zoe',
        fuelTypeKey: 'fuel_electric',
        baselineOdometerKm: 50000,
        baselineDate: DateTime.utc(2026, 1, 1),
      ),
      fuel: [fill('f1', 50000), fill('f2', 50500)],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('kWh/100km'), findsWidgets);
    expect(find.textContaining('l/100km'), findsNothing);
  });

  testWidgets('the maintenance tab lists what is projected', (tester) async {
    await pumpDetail(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maintenance'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsWidgets);
  });

  testWidgets('the history tab lists services with their shop', (tester) async {
    await pumpDetail(tester, services: [service()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Auto Hrvoje'), findsOneWidget);
    expect(find.textContaining('Oil change'), findsWidgets);
  });

  testWidgets('an empty history says so', (tester) async {
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('No services logged yet'), findsOneWidget);
  });

  testWidgets('the costs tab lists costs by category', (tester) async {
    await pumpDetail(tester, costs: [cost()]);
    await tester.pumpAndSettle();

    // The strip scrolls on a phone, so the fourth tab starts off-screen.
    await tester.ensureVisible(find.text('Costs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Costs'));
    await tester.pumpAndSettle();

    expect(find.text('Insurance'), findsOneWidget);
    expect(find.textContaining('320'), findsWidgets);
  });

  testWidgets('the fuel log is reachable from the economy tab', (tester) async {
    final log = await pumpDetail(
      tester,
      fuel: [fill('f1', 50000), fill('f2', 50500)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Fuel').last);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/fuel'));
  });

  group('safety recalls', () {
    testWidgets('a vehicle without make and model cannot be checked', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();

      expect(
        find.text('Add the make, model, and year to check for recalls'),
        findsOneWidget,
      );
    });

    testWidgets('an identified vehicle with nothing recalled says so', (
      tester,
    ) async {
      await pumpDetail(tester, vehicle: identifiedCar());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();

      expect(
        find.text('No recalls found for this make, model, and year'),
        findsOneWidget,
      );
    });

    testWidgets('an open recall is listed with what to do about it', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        vehicle: identifiedCar(),
        recalls: FakeRecallLookup(found: [recall()]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();

      expect(find.textContaining('23V123000'), findsOneWidget);
      expect(find.textContaining('coil pack'), findsWidgets);
      expect(find.textContaining('NHTSA'), findsOneWidget);
    });

    testWidgets('a lookup that fails does not break the tab', (tester) async {
      await pumpDetail(
        tester,
        vehicle: identifiedCar(),
        recalls: FakeRecallLookup(fails: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Maintenance'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Oil change'), findsNothing);
    });
  });

  group('what the car costs to run', () {
    testWidgets('shows a cost per kilometre across all three kinds of spend', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        fuel: [fill('f1', 50000), fill('f2', 60000)],
        services: [service(cost: 200)],
        costs: [cost()],
      );
      await tester.pumpAndSettle();

      // The question a driver actually asks, which no single table answered.
      expect(find.text('Per kilometre'), findsOneWidget);
    });

    testWidgets('says what is missing rather than showing a bare zero', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('to see what this car costs'), findsOneWidget);
    });
  });
}
