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

ServiceEntry service({String id = 's1', double? cost = 210.5, DateTime? date}) {
  return ServiceEntry(
    id: id,
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 4, 2),
    odometerKm: 49000,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: 'u1',
    cost: cost,
    shop: 'Auto Hrvoje',
  );
}

CostEntry cost({String id = 'c1', DateTime? date}) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 3, 1),
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

  /// How many times the registry was actually contacted.
  int get calls => asked.length;

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
  double textScale = 1,
}) {
  final car = vehicle ?? testVehicle('v1', nickname: 'Golf');
  return pumpScreen(
    tester,
    const VehicleDetailScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1',
    surface: surface,
    textScale: textScale,
    extraRoutes: const {
      '/vehicles/v1/fuel',
      '/vehicles/v1/maintenance',
      '/vehicles/v1/tyres',
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
  // The tab used to end in a fixed block — the recalls card plus a wrapped row
  // of three buttons, capped at 60% of the tab's height — which left the list
  // of what the car actually needs squeezed into the strip above it.
  group('the service tab gives its height to the list', () {
    testWidgets('logging a service is a floating button, not a footer row', (
      tester,
    ) async {
      await pumpDetail(tester, projections: [projection()]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingActionButton),
          matching: find.text('Log service'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the calendar and tyres no longer sit in the tab', (
      tester,
    ) async {
      await pumpDetail(tester, projections: [projection()]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Calendar'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Tyre sets'), findsNothing);
    });

    testWidgets(
      'the recalls card scrolls with the list instead of pinning it',
      (tester) async {
        await pumpDetail(tester, projections: [projection()]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Service'));
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.byKey(const Key('recalls-card')),
            matching: find.byType(ListView),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('a car with nothing due still offers the recall check', (
      tester,
    ) async {
      // The card lives in the list now, and an empty list must not take it
      // down with it: an unidentified car has no projections at all.
      await pumpDetail(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('recalls-card')), findsOneWidget);
    });

    testWidgets('and the tab holds together at twice the text size', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        surface: const Size(320, 900),
        textScale: 2,
        projections: [projection()],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('the calendar and tyre sets move into the menu', () {
    testWidgets('the menu offers both', (tester) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Tyre sets'), findsOneWidget);
    });

    testWidgets('the calendar entry reaches the maintenance screen', (
      tester,
    ) async {
      final log = await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar'));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/vehicles/v1/maintenance'));
    });

    testWidgets('the tyre entry reaches the tyre sets screen', (tester) async {
      final log = await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tyre sets'));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/vehicles/v1/tyres'));
    });
  });
  // Archiving was built in the repository and reachable from nowhere:
  // `setArchived` had no caller in any screen and `archivedVehiclesProvider`
  // none at all. There was no per-vehicle delete either — only the household
  // -wide "start over".
  group('taking a vehicle off the lists', () {
    testWidgets('the app bar keeps one icon and puts the rest behind a menu', (
      tester,
    ) async {
      // Four icon buttons plus a menu button made a phone's app bar a row of
      // small grey glyphs nobody could tell apart. Logging a reading is the
      // everyday act and stays; editing, transferring and reporting are not.
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.speed_outlined), findsOneWidget);
      expect(find.byKey(const Key('vehicle-menu')), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      expect(find.byIcon(Icons.description_outlined), findsNothing);
    });

    testWidgets('the menu carries everything that left the bar', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Edit vehicle'), findsOneWidget);
      expect(find.text('Transfer this vehicle'), findsOneWidget);
      expect(find.text('Create report'), findsOneWidget);
    });

    testWidgets('editing from the menu reaches the edit screen', (
      tester,
    ) async {
      final log = await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit vehicle'));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/vehicles/v1/edit'));
    });

    testWidgets('archive and delete are both offered', (tester) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete vehicle'), findsOneWidget);
    });

    testWidgets('deleting asks first, and names what goes with it', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete vehicle'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this vehicle?'), findsOneWidget);
      expect(
        find.textContaining('Archive it instead'),
        findsOneWidget,
        reason: 'the reversible option is the one most sellers actually want',
      );
    });
  });

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
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Costs'), findsOneWidget);
      expect(
        tester.widget<TabBar>(find.byType(TabBar)).isScrollable,
        isFalse,
        reason: 'four labels that fit should divide the width evenly',
      );
    });

    testWidgets('no label is cut off, at any font size a phone offers', (
      tester,
    ) async {
      // Fitting at the default font size is not fitting. Android goes to 2.0
      // in accessibility settings and plenty of people run 1.3 without
      // thinking of it as a setting at all — which is how "Maintenance" came
      // back cut off after the icons were removed.
      for (final scale in [1.0, 1.3, 1.6]) {
        await pumpDetail(
          tester,
          surface: const Size(360, 900),
          textScale: scale,
        );
        await tester.pumpAndSettle();

        for (final label in ['Economy', 'Service', 'History', 'Costs']) {
          expect(
            tester
                .renderObject<RenderParagraph>(find.text(label))
                .didExceedMaxLines,
            isFalse,
            reason: '"$label" is cut off at a font scale of $scale',
          );
        }
      }
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

    await tester.tap(find.text('Service'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Oil change'), findsWidgets);
  });

  testWidgets('the service tab can log a service without leaving', (
    tester,
  ) async {
    // It was a read-only copy of the Maintenance screen's list: it showed what
    // was due and offered nothing to do about it, while the Costs tab beside
    // it carried two inline add buttons. Logging a service from the car you
    // were looking at meant six taps through two screens.
    await pumpDetail(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Service'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('log-service')), findsOneWidget);
  });

  testWidgets('and each due item can be acted on where it is shown', (
    tester,
  ) async {
    await pumpDetail(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Service'));
    await tester.pumpAndSettle();

    // The same row menu the Maintenance screen has — settle it, edit it,
    // delete it — rather than an inert ListTile.
    expect(find.byType(PopupMenuButton<String>), findsWidgets);
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
    /// Opens the recalls card.
    ///
    /// It is folded away by default: a US register is an optional check for a
    /// European car, and it was spending a heading, a caveat and a button on
    /// saying so permanently, on a screen about what the car needs next.
    Future<void> openRecalls(WidgetTester tester) async {
      await tester.tap(find.text('Service'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recalls-card')));
      await tester.pumpAndSettle();
    }

    testWidgets('a vehicle without make and model cannot be checked', (
      tester,
    ) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      await openRecalls(tester);

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

      await openRecalls(tester);
      await tester.tap(find.byKey(const Key('check-recalls')));
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

      await openRecalls(tester);
      await tester.tap(find.byKey(const Key('check-recalls')));
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

      await openRecalls(tester);
      await tester.tap(find.byKey(const Key('check-recalls')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Oil change'), findsNothing);
    });

    testWidgets('nothing is looked up until the button is pressed', (
      tester,
    ) async {
      // The lookup leaves the EU for a US government API. Firing it on every
      // visit to a vehicle screen was a transfer the privacy policy did not
      // describe — it says NHTSA is contacted only when a button is pressed.
      final lookup = FakeRecallLookup(found: [recall()]);
      await pumpDetail(tester, vehicle: identifiedCar(), recalls: lookup);
      await tester.pumpAndSettle();

      await openRecalls(tester);

      expect(lookup.calls, 0, reason: 'nobody asked for this yet');
      expect(find.byKey(const Key('check-recalls')), findsOneWidget);
      expect(find.textContaining('23V123000'), findsNothing);
    });

    testWidgets('pressing it is what sends the request', (tester) async {
      final lookup = FakeRecallLookup(found: [recall()]);
      await pumpDetail(tester, vehicle: identifiedCar(), recalls: lookup);
      await tester.pumpAndSettle();

      await openRecalls(tester);
      await tester.tap(find.byKey(const Key('check-recalls')));
      await tester.pumpAndSettle();

      expect(lookup.calls, 1);
      expect(find.textContaining('23V123000'), findsOneWidget);
    });

    testWidgets('the US caveat is shown before asking, not only after', (
      tester,
    ) async {
      await pumpDetail(tester, vehicle: identifiedCar());
      await tester.pumpAndSettle();

      await openRecalls(tester);

      expect(
        find.textContaining('NHTSA'),
        findsOneWidget,
        reason: 'where the data goes belongs before the request, not after it',
      );
    });
  });

  group('what the vehicle costs to run', () {
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

      expect(
        find.textContaining('to see what this vehicle costs'),
        findsOneWidget,
      );
    });
  });

  // Neither list said when relative to the other something happened, unlike
  // Timeline and Fuel, which group by month.
  group('History and Costs grouped by month', () {
    testWidgets('History shows a header for each month it spans', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        services: [
          service(id: 's1', date: DateTime.utc(2026, 8, 3)),
          service(id: 's2', date: DateTime.utc(2026, 6, 20)),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('JUNE 2026'), findsOneWidget);
    });

    testWidgets('one History header covers a service and a reading together', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        services: [service(id: 's1', date: DateTime.utc(2026, 8, 3))],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('AUGUST 2026'), findsOneWidget);
    });

    testWidgets('Costs shows a header for each month it spans', (tester) async {
      await pumpDetail(
        tester,
        costs: [
          cost(id: 'c1', date: DateTime.utc(2026, 8, 3)),
          cost(id: 'c2', date: DateTime.utc(2026, 5, 12)),
        ],
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Costs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Costs'));
      await tester.pumpAndSettle();

      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.text('MAY 2026'), findsOneWidget);
    });
  });
}
