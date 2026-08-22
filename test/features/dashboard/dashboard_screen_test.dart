import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/core/files/backup_folder.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/core/sync/realtime_sync.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/dashboard/screens/dashboard_screen.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:riverpod/misc.dart' show Override;

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';
import '../settings/backup_restore_test.dart'
    show
        FakeCosts,
        FakeFuel,
        FakeIncome,
        FakeMaintenance,
        FakeOdometer,
        FakeTrips,
        FakeTyres,
        FakeVehicles;

/// Local notifications would reach a platform channel; the dashboard only
/// needs to not blow up while scheduling them.
class SilentNotificationService implements NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool onlyAlertOnce = false,
  }) async {}
}

final _today = DateTime(2026, 8, 15);

ReminderProjection projection({
  String ruleId = 'r1',
  String serviceTypeKey = 'service_oil_change',
  DateTime? due,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: serviceTypeKey,
    projectedDueDate: due ?? _today.add(const Duration(days: 10)),
    state: ReminderState.upcoming,
    dueOdometerKm: 60000,
    fractionConsumed: 0.5,
  );
}

Future<NavigationLog> pumpDashboard(
  WidgetTester tester, {
  List<Vehicle> vehicles = const [],
  MaintenanceBundle? topBundle,
  List<ReminderProjection> projections = const [],
  List<TimelineItem> timeline = const [],
  Size surface = const Size(400, 1400),
  List<Override> extraOverrides = const [],
}) {
  return pumpScreen(
    tester,
    const DashboardScreen(),
    surface: surface,
    extraRoutes: const {
      '/vehicles/new',
      '/vehicles/v1/maintenance',
      // The empty-state card offers these two as ways to get a first
      // vehicle in, so the stub router has to know them.
      '/import',
      '/transfer',
    },
    overrides: [
      realtimeSyncProvider.overrideWith((ref) {}),
      notificationServiceProvider.overrideWithValue(
        SilentNotificationService(),
      ),
      todayProvider.overrideWithValue(_today),
      vehiclesProvider.overrideWith((ref) async => vehicles),
      allVehiclesProvider.overrideWith((ref) async => vehicles),
      topBundleProvider.overrideWith((ref) async => topBundle),
      bundlesProvider.overrideWith(
        (ref) async => topBundle == null ? const [] : [topBundle],
      ),
      householdProjectionsProvider.overrideWith((ref) async => projections),
      timelineProvider.overrideWith((ref) async => timeline),
      fleetSpendProvider.overrideWith((ref) async => 1234.5),
      fleetAverageEconomyProvider.overrideWith((ref) async => 6.4),
      for (final vehicle in vehicles) ...[
        vehicleProvider(vehicle.id).overrideWith((ref) async => vehicle),
        rawFuelEntriesProvider(
          vehicle.id,
        ).overrideWith((ref) async => const []),
        serviceEntriesProvider(
          vehicle.id,
        ).overrideWith((ref) async => const []),
        reminderRulesProvider(vehicle.id).overrideWith((ref) async => const []),
        vehicleProjectionsProvider(
          vehicle.id,
        ).overrideWith((ref) async => projections),
        averageEconomyProvider(vehicle.id).overrideWith((ref) async => 6.4),
        currentOdometerProvider(vehicle.id).overrideWith((ref) async => 51000),
      ],
      ...extraOverrides,
    ],
  );
}

void main() {
  // A seller who handed over a code had no way to know it had been used: the
  // vehicle stopped appearing, eventually, and nothing said why. It cannot
  // arrive as a change to `vehicles` either — by the time that update is
  // checked against the seller's policy the row is the buyer's — so the
  // transfer row is the signal, and this is what it drives.
  group('a vehicle that has been handed over', () {
    testWidgets('says so, by name', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        extraOverrides: [
          unseenCompletedTransfersProvider.overrideWith(
            (ref) async => [
              VehicleTransfer(
                id: 't1',
                vehicleId: 'gone',
                vehicleNickname: 'Golf',
                redeemedAt: DateTime.utc(2026, 8, 1),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Handed over'), findsOneWidget);
      expect(find.textContaining('Golf'), findsWidgets);
    });

    testWidgets('a transfer with no name recorded still says something', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        extraOverrides: [
          unseenCompletedTransfersProvider.overrideWith(
            (ref) async => [
              VehicleTransfer(
                id: 't1',
                vehicleId: 'gone',
                redeemedAt: DateTime.utc(2026, 8, 1),
              ),
            ],
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('is now in its new owner'),
        findsOneWidget,
        reason: 'a car called null is worse than the generic sentence',
      );
    });

    testWidgets('nothing is shown when nothing has been claimed', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      expect(find.text('Handed over'), findsNothing);
    });
  });

  testWidgets('a household with no vehicles is pointed at adding one', (
    tester,
  ) async {
    final log = await pumpDashboard(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a vehicle yourself'));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/new'));
  });

  testWidgets('with nothing bundled it says so', (tester) async {
    await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    expect(find.text('Nothing to bundle right now'), findsOneWidget);
  });

  testWidgets('the fleet metrics strip shows spend and economy', (
    tester,
  ) async {
    await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    expect(find.textContaining('1,234'), findsWidgets);
    expect(find.textContaining('6.4'), findsWidgets);
  });

  testWidgets('what is due soonest is listed', (tester) async {
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      projections: [projection()],
    );
    await tester.pumpAndSettle();

    expect(find.text('DUE SOONEST'), findsOneWidget);
    expect(find.textContaining('Oil change'), findsWidgets);
  });

  testWidgets('tapping a due item opens that vehicle maintenance', (
    tester,
  ) async {
    final log = await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      projections: [projection()],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Oil change').first);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/maintenance'));
  });

  testWidgets('recent activity appears once there is history', (tester) async {
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      timeline: [
        TimelineItem(
          entryId: 'e1',
          kind: TimelineKind.fuel,
          date: _today,
          vehicleId: 'v1',
          amount: 62,
          odometerKm: 51000,
          createdBy: 'u1',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('€62'), findsWidgets);
  });

  testWidgets('the toolbar reaches stations, calculator, and stats', (
    tester,
  ) async {
    final log = await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    // Scoped to the app bar: the empty-state card offers a fill-up under the
    // same icon, and an unscoped finder now matches both.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.local_gas_station_outlined),
      ),
    );
    await tester.pumpAndSettle();

    expect(log.visited, contains('/stations'));
  });

  testWidgets('the dashboard tab is the selected one', (tester) async {
    await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));

    expect(bar.selectedIndex, 0);
  });

  group('on a desktop window', () {
    // Section keys rather than text positions: the labels sit inside widgets
    // with different insets, so comparing their x proves nothing about layout.
    Finder section(String name) => find.byKey(Key('dashboard-$name'));

    testWidgets('sections sit beside each other instead of stacking', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        surface: const Size(1500, 1000),
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection()],
      );
      await tester.pumpAndSettle();

      // Which section lands in which column would over-specify the layout;
      // that they are in different ones is the behaviour.
      expect(
        tester.getTopLeft(section('vehicles')).dx,
        isNot(tester.getTopLeft(section('due')).dx),
        reason:
            'a single column of cards down a 1500px window is the '
            'complaint this layout answers',
      );
    });

    testWidgets('a phone still stacks them', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection()],
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(section('vehicles')).dx,
        tester.getTopLeft(section('due')).dx,
      );
    });
  });

  group('logging something from the dashboard', () {
    // Recording a fill-up meant Vehicles, then the car, then the fuel log,
    // then a button: four taps for the thing done most often. An unscheduled
    // service was buried deeper still, behind an app-bar icon on a tab.
    testWidgets('offers fuel, service and cost without leaving home', (
      tester,
    ) async {
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Fuel up'), findsOneWidget);
      expect(find.text('Service'), findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
    });

    testWidgets('a household with no car has nothing to log against', (
      tester,
    ) async {
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    // A floating button floats over the content, so the list has to end above
    // it. Without that room the last card's own buttons sit underneath and
    // cannot be tapped at all, which is the state this found on a phone.
    testWidgets('and never covers the end of the list', (tester) async {
      await pumpDashboard(
        tester,
        surface: const Size(400, 700),
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection()],
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final lastCard = tester.getRect(
        find.byKey(const Key('dashboard-vehicles')),
      );

      expect(lastCard.overlaps(fab), isFalse);
    });
  });

  group('a household that has just started', () {
    // "Nothing here yet" tells a new arrival nothing about what to do. This
    // card used to answer with a three-step checklist whose last two steps
    // were scenery — unclickable, and hard-coded never to tick. It now offers
    // the ways a vehicle actually gets into a garage, three of which were
    // buried in Settings.
    testWidgets('is offered every way a vehicle gets into a garage', (
      tester,
    ) async {
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      expect(find.text('GETTING STARTED'), findsOneWidget);
      expect(find.text('Add a vehicle yourself'), findsOneWidget);
      expect(find.text('Import from Fuelio'), findsOneWidget);
      expect(find.text('Import a CSV (any app)'), findsOneWidget);
      expect(find.text('Receive a vehicle with a code'), findsOneWidget);
    });

    testWidgets('and every one of them does something', (tester) async {
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      // The complaint that started this: of the old card's four lines, two
      // were inert. A row that looks like a control and is not is worse than
      // no row.
      for (final label in [
        'Add a vehicle yourself',
        'Import from Fuelio',
        'Import a CSV (any app)',
        'Receive a vehicle with a code',
      ]) {
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
        );
        expect(tile.onTap, isNotNull, reason: '"\$label" does nothing');
      }
    });

    testWidgets('reaches the CSV importer and the transfer screen', (
      tester,
    ) async {
      final log = await pumpDashboard(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Receive a vehicle with a code'));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/transfer'));
    });

    testWidgets('the nudge to set an interval opens the interval sheet', (
      tester,
    ) async {
      // It opened the log-a-past-service sheet, which has no interval in it at
      // all. Reminder rules feed the projections behind Due soonest, the
      // planner runway and bundling — so a new user did exactly what the card
      // asked and then found three surfaces still empty. The one place the app
      // volunteers to fix that sent them somewhere else.
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set what it needs, and when'));
      await tester.pumpAndSettle();

      expect(
        find.text('Every (distance)'),
        findsOneWidget,
        reason:
            'this is the interval sheet; the service sheet has no such '
            'field',
      );
    });

    testWidgets('a garage with a car but no history is nudged, not walked', (
      tester,
    ) async {
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      // Different work to do, so a different card: the ways in are done with.
      expect(find.text('WHAT NEXT'), findsOneWidget);
      expect(find.text('Log a fill-up'), findsOneWidget);
      expect(find.text('Set what it needs, and when'), findsOneWidget);
      expect(find.text('Add a vehicle yourself'), findsNothing);
    });

    // The card named sample data and then left the reader to find it: three
    // taps away, under Settings, with nothing on screen saying so. Naming a
    // feature you cannot reach from where it is named is worse than silence.
    testWidgets('can load the sample data the card offers', (tester) async {
      final vehicles = FakeVehicleRepository();
      await pumpDashboard(
        tester,
        extraOverrides: [
          vehicleRepositoryProvider.overrideWithValue(vehicles),
          fuelRepositoryProvider.overrideWithValue(FakeFuelRepository()),
          maintenanceRepositoryProvider.overrideWithValue(
            FakeMaintenanceRepository(),
          ),
          costRepositoryProvider.overrideWithValue(FakeCostRepository()),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load sample data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Load sample data'));
      await tester.pumpAndSettle();

      expect(vehicles.created, hasLength(1));
    });

    // One tap wrote a whole demo garage into a real one, from a card on the
    // dashboard. The sample car is called "Renault Clio", so anybody who owns
    // one — which is who the app was built for — ends up with two and has to
    // work out which is theirs.
    group('before writing a demo garage into a real one', () {
      Future<FakeVehicleRepository> tapLoad(WidgetTester tester) async {
        final vehicles = FakeVehicleRepository();
        await pumpDashboard(
          tester,
          extraOverrides: [
            vehicleRepositoryProvider.overrideWithValue(vehicles),
            fuelRepositoryProvider.overrideWithValue(FakeFuelRepository()),
            maintenanceRepositoryProvider.overrideWithValue(
              FakeMaintenanceRepository(),
            ),
            costRepositoryProvider.overrideWithValue(FakeCostRepository()),
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load sample data'));
        await tester.pumpAndSettle();
        return vehicles;
      }

      testWidgets('it asks, and names the car it will add', (tester) async {
        final vehicles = await tapLoad(tester);

        expect(
          find.textContaining('Renault Clio'),
          findsWidgets,
          reason:
              'naming the car is what tells someone who owns one that '
              'they are about to have two',
        );
        expect(vehicles.created, isEmpty, reason: 'nothing before a yes');
      });

      testWidgets('backing out writes nothing', (tester) async {
        final vehicles = await tapLoad(tester);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(vehicles.created, isEmpty);
      });
    });

    // Loading the sample writes about twenty rows one at a time, which takes
    // seconds against a real backend, and nothing on screen changed while it
    // ran. The first person to try it tapped five times and got five cars.
    group('while the sample is loading', () {
      Future<FakeVehicleRepository> pumpMidLoad(WidgetTester tester) async {
        final vehicles = FakeVehicleRepository()..pause = Completer<void>();
        await pumpDashboard(
          tester,
          extraOverrides: [
            vehicleRepositoryProvider.overrideWithValue(vehicles),
            fuelRepositoryProvider.overrideWithValue(FakeFuelRepository()),
            maintenanceRepositoryProvider.overrideWithValue(
              FakeMaintenanceRepository(),
            ),
            costRepositoryProvider.overrideWithValue(FakeCostRepository()),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Load sample data'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Load sample data'));
        await tester.pump();
        return vehicles;
      }

      testWidgets('it says so, instead of looking like nothing happened', (
        tester,
      ) async {
        final vehicles = await pumpMidLoad(tester);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        vehicles.pause!.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('tapping again does not load a second car', (tester) async {
        final vehicles = await pumpMidLoad(tester);

        await tester.tap(
          find.byType(CircularProgressIndicator),
          warnIfMissed: false,
        );
        await tester.pump();
        vehicles.pause!.complete();
        await tester.pumpAndSettle();

        expect(vehicles.created, hasLength(1));
      });
    });

    testWidgets('stops once there is history to show instead', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        timeline: [
          TimelineItem(
            entryId: 'e1',
            kind: TimelineKind.fuel,
            date: _today,
            vehicleId: 'v1',
            amount: 62,
            odometerKm: 51000,
            createdBy: 'u1',
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('GETTING STARTED'), findsNothing);
    });
  });

  // The automatic backup runs silently on every foreground by design — see
  // decision 60 — but the one moment it actually writes something is worth a
  // word, or a feature running quietly in the background may as well not be
  // running at all.
  group('the automatic-backup toast', () {
    List<Override> backupOverrides() => [
      backupFolderWriterProvider.overrideWithValue(
        ({
          required String folderUri,
          required String fileName,
          required Uint8List bytes,
        }) async {},
      ),
      backupFolderCheckProvider.overrideWithValue((uri) async => true),
      // The backup walks every repository, so all of them have to resolve —
      // this screen's own harness only stubs the providers the dashboard
      // itself reads.
      vehicleRepositoryProvider.overrideWithValue(
        FakeVehicles([testVehicle('v1')]),
      ),
      fuelRepositoryProvider.overrideWithValue(FakeFuel(const [])),
      costRepositoryProvider.overrideWithValue(FakeCosts()),
      odometerRepositoryProvider.overrideWithValue(FakeOdometer()),
      tripRepositoryProvider.overrideWithValue(FakeTrips()),
      incomeRepositoryProvider.overrideWithValue(FakeIncome()),
      maintenanceRepositoryProvider.overrideWithValue(FakeMaintenance()),
      tyreRepositoryProvider.overrideWithValue(FakeTyres()),
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'backup.folderUri': 'content://tree/backups',
      });
    });

    testWidgets('appears the moment a backup is actually written', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        extraOverrides: backupOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backed up automatically'), findsOneWidget);
    });

    testWidgets('says nothing when no folder has been chosen', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      expect(find.text('Backed up automatically'), findsNothing);
    });

    testWidgets('says nothing on the second foreground the same day', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        extraOverrides: backupOverrides(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Backed up automatically'), findsOneWidget);

      // Dismiss the first toast and rebuild, standing in for a second
      // foreground later the same day.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        extraOverrides: backupOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backed up automatically'), findsNothing);
    });
  });
}
