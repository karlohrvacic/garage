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
import 'package:garage/features/maintenance/screens/maintenance_screen.dart';
import 'package:garage/features/vehicles/screens/vehicle_detail_screen.dart';

import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/costs/running_cost.dart';
import 'package:garage/features/costs/providers/running_cost_providers.dart';

import '../../support/pump_screen.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import '../../support/fake_repositories.dart';

final _today = DateTime(2026, 8, 15);

FuelEntry fill(String id, int odometerKm, {String? fuelTypeKey}) {
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
    fuelTypeKey: fuelTypeKey,
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
  UnitPreferences preferences = metricPreferences,
  RunningCost? runningCost,
  VehicleRepository? repository,
}) {
  final car = vehicle ?? testVehicle('v1', nickname: 'Golf');
  return pumpScreen(
    tester,
    const VehicleDetailScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1',
    surface: surface,
    textScale: textScale,
    preferences: preferences,
    extraRoutes: const {
      '/vehicles/v1/fuel',
      '/vehicles/v1/maintenance',
      '/vehicles/v1/tyres',
      '/vehicles/v1/edit',
    },
    overrides: [
      vehicleRepositoryProvider.overrideWithValue(
        repository ?? FakeVehicleRepository(vehicles: [car]),
      ),
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
      if (runningCost != null)
        runningCostProvider('v1').overrideWith((ref) async => runningCost),
    ],
  );
}

List<FuelEntry> economyFuel() => [
  FuelEntry(
    id: 'f1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 1, 10),
    odometerKm: 50000,
    volumeL: 40,
    pricePerL: 1.5,
    total: 60,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  ),
  FuelEntry(
    id: 'f2',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 2, 10),
    odometerKm: 51000,
    volumeL: 40,
    pricePerL: 1.5,
    total: 60,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  ),
];

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

/// Records what was archived and restored.
class ArchivingRepository extends FakeVehicleRepository {
  ArchivingRepository(List<Vehicle> vehicles) : super(vehicles: vehicles);

  final archived = <(String, bool)>[];

  @override
  Future<void> setArchived(String id, bool archived) async {
    this.archived.add((id, archived));
  }
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
      await tester.tap(find.text('Reminders'));
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
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Calendar'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Tyres'), findsNothing);
    });

    testWidgets(
      'the recalls card scrolls with the list instead of pinning it',
      (tester) async {
        await pumpDetail(tester, projections: [projection()]);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reminders'));
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
      await tester.tap(find.text('Reminders'));
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
      await tester.tap(find.text('Reminders'));
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
      expect(find.text('Tyres'), findsWidgets);
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

      // On its calendar: the item says Calendar, and the list is the tab
      // beside it in different chrome.
      expect(log.visited, contains('/vehicles/v1/maintenance?tab=calendar'));
    });

    testWidgets('the tyre entry reaches the tyre sets screen', (tester) async {
      final log = await pumpDetail(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tyres').last);
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

    testWidgets('archiving asks first, and Undo brings it back', (
      tester,
    ) async {
      // It ran on one tap, two rows above Delete, and took the household's
      // main car off every screen and total with nothing to undo.
      final repository = ArchivingRepository([testVehicle('v1')]);
      await pumpDetail(tester, repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vehicle-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Archive this vehicle?'), findsOneWidget);
      expect(repository.archived, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      await tester.pumpAndSettle();
      expect(repository.archived, [('v1', true)]);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.archived, [('v1', true), ('v1', false)]);
    });

    testWidgets('an archived vehicle says so, and offers Restore', (
      tester,
    ) async {
      await pumpDetail(tester, vehicle: testVehicle('v1', archived: true));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('archived-banner')), findsOneWidget);
      expect(find.text('Restore'), findsOneWidget);
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
      expect(find.text('Reminders'), findsOneWidget);
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

        for (final label in ['Economy', 'Reminders', 'History', 'Costs']) {
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

    await tester.tap(find.text('Reminders'));
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

    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('log-service')), findsOneWidget);
  });

  testWidgets('and each due item can be acted on where it is shown', (
    tester,
  ) async {
    await pumpDetail(tester, projections: [projection()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
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
      await tester.tap(find.text('Reminders'));
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
      // The figure carries its own unit; the fixed "Per kilometre" caption
      // that used to sit under it was wrong for a household reading miles.
      expect(
        find.byKey(const Key('running-cost-per-distance')),
        findsOneWidget,
      );
      expect(find.textContaining('/km'), findsWidgets);
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

  // `UnitFormat.formatCostPerDistance` exists precisely for this, and its own
  // docstring records the bug being fixed: "a household reading miles was
  // shown a per-kilometre number under a heading that said km". It was applied
  // to the fuel log screen and never to this card, which shows three
  // per-distance figures and converted none of them.
  // `UnitFormat.formatCostPerDistance` exists precisely for this, and its own
  // docstring records the bug being fixed: "a household reading miles was
  // shown a per-kilometre number under a heading that said km". It was applied
  // to the fuel log screen and never to this card, which shows three
  // per-distance figures and converted none of them.
  group('running cost per distance', () {
    const inMiles = UnitPreferences(
      distance: DistanceUnit.mi,
      volume: VolumeUnit.usGallon,
      currencyCode: 'USD',
    );

    // 0.12 of fuel and 0.06 of upkeep per kilometre, over a thousand of them.
    RunningCost spending() => const RunningCost(
      fuel: 120,
      service: 40,
      other: 20,
      distanceKm: 1000,
      months: 6,
    );

    /// The card lives on the Economy tab, which is the one the screen opens
    /// on, but below the fold.
    Future<void> openCard(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Fuel '),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the Costs tab counts fuel, read-only', (tester) async {
      // "No costs logged yet." sat one tab away from a cost card counting
      // €60 of fuel.
      await pumpDetail(tester, fuel: [economyFuel().first]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Costs'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('costs-fuel-line')), findsOneWidget);
      expect(find.textContaining('Fuel €60.00'), findsOneWidget);
      expect(find.text('No costs beyond fuel yet.'), findsOneWidget);
      expect(find.text('No costs logged yet.'), findsNothing);
    });

    testWidgets('Add reminder stays once reminders exist', (tester) async {
      // It lived only in the empty state, so a tab with one reminder offered
      // "Log service" and nothing else.
      await pumpDetail(
        tester,
        projections: [
          ReminderProjection(
            ruleId: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            projectedDueDate: _today.add(const Duration(days: 200)),
            state: ReminderState.upcoming,
            dueOdometerKm: 60000,
            fractionConsumed: 0.3,
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reminders'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('service-tab-add-rule')), findsOneWidget);
      expect(find.text('Oil change'), findsWidgets);
    });

    testWidgets('History can log a service', (tester) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('log-service-history')), findsOneWidget);
    });

    testWidgets('the cost card shows what was paid, and says what it spread', (
      tester,
    ) async {
      // €600 of insurance shown as €1.64 read as a bug, not amortisation.
      await pumpDetail(
        tester,
        fuel: economyFuel(),
        runningCost: const RunningCost(
          fuel: 100,
          service: 0,
          other: 1.64,
          otherPaid: 600,
          distanceKm: 500,
          months: 0.1,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Since you added it'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('€700.00'), findsOneWidget);
      expect(find.textContaining('spread over its year'), findsOneWidget);
    });

    testWidgets('the breakdown rows add up to the total above them', (
      tester,
    ) async {
      // Fuel + servicing + the rest read €101.64 under a stated €700.00: the
      // breakdown was mixing the spread figure into a list of what was paid.
      await pumpDetail(
        tester,
        fuel: economyFuel(),
        runningCost: const RunningCost(
          fuel: 100,
          service: 0,
          other: 1.64,
          otherPaid: 600,
          distanceKm: 500,
          months: 0.1,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Registration, insurance and the rest'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('€600.00'), findsOneWidget);
      expect(find.text('€1.64'), findsNothing);
    });

    testWidgets('the ring says what it is scaled against', (tester) async {
      // A proportion with no stated basis is not information.
      await pumpDetail(tester, fuel: economyFuel());
      await tester.pumpAndSettle();

      expect(find.textContaining('The ring runs'), findsOneWidget);
    });

    testWidgets('the ring says how many full tanks are in', (tester) async {
      // An empty ring with "—" said nothing about how far off the figure is.
      await pumpDetail(tester, fuel: [economyFuel().first]);
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 full tanks logged'), findsOneWidget);
    });

    testWidgets('holds the per-distance figure until economy exists', (
      tester,
    ) async {
      // One tank and 450 km gave "€0.136/km" to three decimals while the
      // dashboard had just said consumption needs one more full tank. Same
      // rule for both: no figure before two full tanks.
      await pumpDetail(
        tester,
        fuel: [economyFuel().first],
        runningCost: spending(),
      );
      await tester.pumpAndSettle();
      // Not through openCard: it scrolls to the "Fuel …" share line, which
      // is exactly what this state no longer shows.
      await tester.scrollUntilVisible(
        find.byKey(const Key('running-cost-per-distance')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(const Key('running-cost-per-distance')))
            .data,
        '—',
      );
      expect(
        find.text('One more full tank and the cost per distance appears'),
        findsOneWidget,
      );
      expect(find.text('Since you added it'), findsOneWidget);
    });

    testWidgets('says per mile for a household that reads miles', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        fuel: economyFuel(),
        preferences: inMiles,
        runningCost: spending(),
      );
      await openCard(tester);

      // The headline by key, not merely "something says /mi": the fuel and
      // upkeep shares below it also carry the unit, so a looser assertion
      // passes with the headline still unconverted.
      expect(
        tester
            .widget<Text>(find.byKey(const Key('running-cost-per-distance')))
            .data,
        r'$0.290/mi',
      );
      expect(find.text('Per kilometre'), findsNothing);
      expect(find.textContaining('/km'), findsNothing);
    });

    // The metric half is where a conversion bug most easily hides on the way
    // past, so it is pinned rather than assumed.
    testWidgets('and per kilometre for one that reads kilometres', (
      tester,
    ) async {
      await pumpDetail(tester, fuel: economyFuel(), runningCost: spending());
      await openCard(tester);

      expect(
        tester
            .widget<Text>(find.byKey(const Key('running-cost-per-distance')))
            .data,
        '€0.180/km',
      );
      expect(find.textContaining('/mi'), findsNothing);
    });
  });

  // Each fuel gets its own chain of full tanks, so a petrol figure is computed
  // from petrol volumes alone — but the chains overlap. An LPG span from 1000
  // to 1500 km includes whatever was driven on petrol in between, so each
  // figure approximates that fuel's consumption over a period rather than
  // measuring it. The card stated two numbers and none of that.
  testWidgets('the bi-fuel split says what it cannot separate', (tester) async {
    await pumpDetail(
      tester,
      vehicle: testVehicle(
        'v1',
        nickname: 'Golf',
        secondaryFuelTypeKey: 'fuel_lpg',
      ),
      fuel: [
        fill('f1', 50000, fuelTypeKey: 'fuel_petrol'),
        fill('f2', 50500, fuelTypeKey: 'fuel_lpg'),
        fill('f3', 51000, fuelTypeKey: 'fuel_petrol'),
        fill('f4', 51500, fuelTypeKey: 'fuel_lpg'),
      ],
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('economy-by-fuel')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('economy-by-fuel')),
        matching: find.textContaining('overlap'),
      ),
      findsOneWidget,
    );
  });

  // The recalls card sits in the same padded ListView as the service cards and
  // was adding another `space4` of its own, so it came out inset twice and
  // visibly narrower than everything above it.
  testWidgets('the recalls card is as wide as the service cards', (
    tester,
  ) async {
    await pumpDetail(tester, projections: [projection()]);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Reminders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    final recalls = find.byKey(const Key('recalls-card'));
    await tester.scrollUntilVisible(
      recalls,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    // Scoped to the same list: TabBarView keeps the other tabs alive, so an
    // unscoped Card finder picks one up from a different tab entirely.
    final serviceCard = find
        .descendant(
          of: find.byType(MaintenanceProjectionList),
          matching: find.byType(Card),
        )
        .first;

    // Card to Card: the key sits on the ExpansionTile *inside* the card, so
    // measuring it directly compares an inner widget against an outer one and
    // reports the card's own margin as a mismatch.
    final recallsCard = find
        .ancestor(of: recalls, matching: find.byType(Card))
        .first;

    expect(
      tester.getSize(recallsCard).width,
      tester.getSize(serviceCard).width,
    );
  });

  testWidgets('tyres are a row on the Service tab, not a menu item only', (
    tester,
  ) async {
    // Tyre sets lived only behind the vehicle page's overflow menu, four taps
    // from the dashboard; nobody who did not already know found them.
    await pumpDetail(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vehicle-tyres-row')), findsOneWidget);
    expect(find.text('Tyres'), findsWidgets);
  });

  testWidgets('with a schedule the tyres row is still in view', (tester) async {
    await pumpDetail(
      tester,
      projections: [
        for (var i = 0; i < 8; i++)
          ReminderProjection(
            ruleId: 'r$i',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            projectedDueDate: _today.add(Duration(days: 12 + i)),
            state: ReminderState.upcoming,
            dueOdometerKm: 60000 + i,
            fractionConsumed: 0.7,
          ),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('vehicle-tyres-row'));
    expect(row, findsOneWidget);
    expect(tester.getTopLeft(row).dy, lessThan(600));
  });
}
