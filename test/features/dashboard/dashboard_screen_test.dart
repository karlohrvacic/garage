import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/core/sync/realtime_sync.dart';
import 'package:garage/domain/entities/vehicle.dart';
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
    extraRoutes: const {'/vehicles/new', '/vehicles/v1/maintenance'},
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
  testWidgets('a household with no vehicles is pointed at adding one', (
    tester,
  ) async {
    final log = await pumpDashboard(tester);
    await tester.pumpAndSettle();

    // The bare "Add vehicle" button became the first step of the checklist.
    await tester.tap(find.text('Add your car'));
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

    await tester.tap(find.byIcon(Icons.local_gas_station_outlined));
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
    // "Nothing here yet" tells a new arrival nothing about what to do. Three
    // steps do, and they are the whole app: a car, a fill-up, and what it
    // needs next.
    testWidgets('is walked through the three things that matter', (
      tester,
    ) async {
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      expect(find.text('GETTING STARTED'), findsOneWidget);
      expect(find.text('Add your car'), findsOneWidget);
      expect(find.text('Log a fill-up'), findsOneWidget);
      expect(find.text('Set what it needs, and when'), findsOneWidget);
    });

    testWidgets('sees the first step ticked once a car exists', (tester) async {
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      // With a car and no history the checklist stays, showing what is left.
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
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

      expect(vehicles.created, hasLength(1));
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
}
