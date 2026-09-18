import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/vehicle_entries.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/features/vehicles/providers/guest_pass_providers.dart';
import 'package:garage/domain/entities/guest_pass.dart';
import 'package:garage/domain/entities/household.dart';
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
import 'package:garage/core/widgets/skeleton.dart';
import 'package:garage/features/dashboard/screens/dashboard_screen.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
import 'package:garage/features/documents/providers/document_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:garage/features/observations/providers/observation_providers.dart';
import '../../support/fake_documents.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';
import '../settings/backup_restore_test.dart'
    show
        FakeCosts,
        FakeFuel,
        FakeIncome,
        FakeMaintenance,
        FakeObservations,
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
  ReminderState state = ReminderState.upcoming,
}) {
  return ReminderProjection(
    ruleId: ruleId,
    vehicleId: 'v1',
    serviceTypeKey: serviceTypeKey,
    projectedDueDate: due ?? _today.add(const Duration(days: 10)),
    state: state,
    dueOdometerKm: 60000,
    fractionConsumed: 0.5,
  );
}

Future<NavigationLog> pumpDashboard(
  WidgetTester tester, {
  List<Vehicle> vehicles = const [],
  MaintenanceBundle? topBundle,
  List<ReminderProjection> projections = const [],

  /// The measured driving rate behind distance-based due dates; null means
  /// the projector's assumed rate.
  double? drivingRate,
  List<TimelineItem> timeline = const [],

  /// Holds the timeline in its loading state, so a test can tell "still
  /// arriving" apart from "genuinely empty".
  bool timelineLoading = false,

  /// Holds the reminder projections in their loading state.
  bool projectionsLoading = false,

  /// Holds the vehicle list in flight, for the tests about what the screen
  /// shows before it has arrived.
  bool vehiclesLoading = false,
  Future<Household?>? householdFuture,
  Size surface = const Size(400, 1400),

  /// What every vehicle's tank range resolves to. Null by default: deriving it
  /// would pull five per-vehicle providers into tests that only render a row.
  List<Override> extraOverrides = const [],
  Locale? locale,
  double textScale = 1,

  /// Every pass on the garage's cars; a live one is a car out on loan.
  List<GuestPass> passes = const [],
}) {
  return pumpScreen(
    tester,
    householdFuture: householdFuture,
    const DashboardScreen(),
    surface: surface,
    locale: locale,
    textScale: textScale,
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
      garagePassesProvider.overrideWith((ref) async => passes),
      notificationServiceProvider.overrideWithValue(
        SilentNotificationService(),
      ),
      todayProvider.overrideWithValue(_today),
      drivingRateProvider('v1').overrideWith((ref) async => drivingRate),
      // Filtered, the way production derives it: `vehiclesProvider` is
      // `allVehiclesProvider` minus the archived. Overriding both with the
      // same list made an archived car behave like an active one in every
      // test, which is precisely the difference the screen has to get right.
      vehiclesProvider.overrideWith(
        (ref) => vehiclesLoading
            ? Completer<List<Vehicle>>().future
            : Future.value([
                for (final vehicle in vehicles)
                  if (!vehicle.archived) vehicle,
              ]),
      ),
      allVehiclesProvider.overrideWith(
        (ref) => vehiclesLoading
            ? Completer<List<Vehicle>>().future
            : Future.value(vehicles),
      ),
      topBundleProvider.overrideWith((ref) async => topBundle),
      bundlesProvider.overrideWith(
        (ref) async => topBundle == null ? const [] : [topBundle],
      ),
      householdProjectionsProvider.overrideWith(
        (ref) => projectionsLoading
            ? Completer<List<ReminderProjection>>().future
            : Future.value(projections),
      ),
      timelineProvider.overrideWith(
        (ref) => timelineLoading
            ? Completer<List<TimelineItem>>().future
            : Future.value(timeline),
      ),
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
  group('what the dashboard leads to', () {
    // Every recent row opened the top of the timeline, and the three figures
    // at the top did nothing at all.
    final cost = CostEntry(
      id: 'c1',
      vehicleId: 'v1',
      date: _today,
      category: CostCategories.insurance,
      amount: 320,
      createdBy: 'u1',
    );
    final recent = [
      TimelineItem(
        entryId: 'c1',
        kind: TimelineKind.cost,
        date: _today,
        vehicleId: 'v1',
        amount: 320,
        costCategory: CostCategories.insurance,
        createdBy: 'u1',
      ),
    ];

    Future<NavigationLog> pumpWithRecent(WidgetTester tester) async {
      final log = await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        timeline: recent,
        // Fuel and services are already stood in for by the harness.
        extraOverrides: vehicleEntryOverrides(
          'v1',
          fuel: null,
          services: null,
          costs: [cost],
        ),
      );
      await tester.pumpAndSettle();
      return log;
    }

    testWidgets('a recent row opens that entry', (tester) async {
      await pumpWithRecent(tester);

      final row = find.byKey(const Key('recent-c1'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(find.text('Edit cost'), findsOneWidget);
    });

    testWidgets('and the heading still opens the whole timeline', (
      tester,
    ) async {
      final log = await pumpWithRecent(tester);

      final heading = find.byKey(const Key('recent-all'));
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      await tester.tap(heading);
      await tester.pumpAndSettle();

      expect(log.last, '/timeline');
    });

    for (final (label, where) in [
      ('VEHICLES', '/vehicles'),
      ('TOTAL SPENT', '/stats?tab=costs'),
      ('AVERAGE', '/stats'),
    ]) {
      testWidgets('the $label figure opens where it is explained', (
        tester,
      ) async {
        final log = await pumpWithRecent(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        // Contains, not last: a pushed page leaves the dashboard beneath it,
        // and the router builds that again after the page it pushed.
        expect(log.visited, contains(where));
      });
    }
  });

  testWidgets('a car out on loan says so on its card', (tester) async {
    // Only its own page said so; the dashboard showed it like any other.
    final now = DateTime.now().toUtc();
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      passes: [
        GuestPass(
          id: 'p1',
          vehicleId: 'v1',
          code: 'ABCD2345',
          createdBy: 'u1',
          createdAt: now.subtract(const Duration(days: 1)),
          expiresAt: DateTime.utc(now.year + 1, 10, 3),
          redeemedBy: 'g1',
          redeemedAt: now.subtract(const Duration(hours: 2)),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('on-loan-badge')), findsOneWidget);
    expect(find.textContaining('On loan until'), findsOneWidget);
  });

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

    await tester.tap(find.text('Add your first vehicle'));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/new'));
  });

  // A garage with nothing to bundle now says nothing. The line used to lead
  // the dashboard — first slot, above recent activity — to announce an absence
  // on every visit, which is what decision 65 was about and this had been left
  // out of. Bundling is discovered the first time a real bundle appears, which
  // is when it means anything.
  testWidgets('with nothing bundled it says nothing at all', (tester) async {
    await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    expect(find.textContaining('bundle'), findsNothing);
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
  });

  testWidgets('a desktop window has no icons the sidebar already lists', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      surface: const Size(1400, 900),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Statistics'), findsNothing);
    expect(find.byTooltip('Calculator'), findsNothing);
  });

  testWidgets('an empty garage still says which garage it is', (tester) async {
    // Creating a second garage switches into it, and a nameless empty
    // dashboard is what losing every vehicle would look like.
    await pumpDashboard(tester, vehicles: const []);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-garage')), findsOneWidget);
  });

  testWidgets('a vehicle card says what is next, however far out', (
    tester,
  ) async {
    // The reward for setting a reminder, where the card asked for it: a
    // rule a year out was invisible on the home screen.
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      projections: [
        ReminderProjection(
          ruleId: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          projectedDueDate: _today.add(const Duration(days: 360)),
          dateFromTime: _today.add(const Duration(days: 360)),
          state: ReminderState.upcoming,
          dueOdometerKm: 60000,
          fractionConsumed: 0.05,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Next: Oil change'), findsOneWidget);
  });

  testWidgets('an overdue rule on the card says so, not a past "Next"', (
    tester,
  ) async {
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      projections: [
        ReminderProjection(
          ruleId: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_registration',
          projectedDueDate: _today.subtract(const Duration(days: 40)),
          dateFromTime: _today.subtract(const Duration(days: 40)),
          state: ReminderState.overdue,
          dueOdometerKm: null,
          fractionConsumed: 1,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Overdue: Registration'), findsOneWidget);
    expect(find.textContaining('Next: Registration'), findsNothing);
  });

  testWidgets('the pump on a vehicle card opens the fill-up sheet', (
    tester,
  ) async {
    // The same icon on the checklist opened the sheet; on the card it went
    // to the log, and "pump = log a fill" broke on the second use.
    final log = await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-vehicles')),
        matching: find.byIcon(Icons.local_gas_station),
      ),
    );
    await tester.pumpAndSettle();

    // The sheet, by a field only it has: "Log a fill-up" is also the What
    // next card's row, behind the sheet.
    expect(find.text('Filled to full'), findsOneWidget);
    expect(log.visited, isNot(contains('/vehicles/v1/fuel')));
  });

  testWidgets('a date the odometer decided says what rate it measured', (
    tester,
  ) async {
    // "Oct 26, 2026" rested on a driving rate the dashboard never mentioned;
    // the maintenance page did. A first-timer could neither trust nor
    // correct it.
    final due = _today.add(const Duration(days: 30));
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      drivingRate: 196,
      projections: [
        ReminderProjection(
          ruleId: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          projectedDueDate: due,
          dateFromDistance: due,
          dateFromTime: _today.add(const Duration(days: 300)),
          state: ReminderState.upcoming,
          dueOdometerKm: 60000,
          fractionConsumed: 0.9,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('by distance, about 196 km a day'),
      findsOneWidget,
    );
  });

  testWidgets('and says so when the rate is only assumed', (tester) async {
    final due = _today.add(const Duration(days: 30));
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      projections: [
        ReminderProjection(
          ruleId: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          projectedDueDate: due,
          dateFromDistance: due,
          dateFromTime: _today.add(const Duration(days: 300)),
          state: ReminderState.upcoming,
          dueOdometerKm: 60000,
          fractionConsumed: 0.9,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('by distance, assuming 30 km a day'),
      findsOneWidget,
    );
  });

  testWidgets('a date the calendar decided rests on no rate', (tester) async {
    final due = _today.add(const Duration(days: 30));
    await pumpDashboard(
      tester,
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      drivingRate: 196,
      projections: [
        ReminderProjection(
          ruleId: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          projectedDueDate: due,
          dateFromDistance: _today.add(const Duration(days: 300)),
          dateFromTime: due,
          state: ReminderState.upcoming,
          dueOdometerKm: 60000,
          fractionConsumed: 0.9,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('by distance'), findsNothing);
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

    // The due list's row, not the vehicle card's "Next: Oil change" line.
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dashboard-due')),
        matching: find.text('Oil change'),
      ),
    );
    await tester.pumpAndSettle();

    expect(log.visited, contains('/vehicles/v1/maintenance'));
  });

  // Nothing on this dashboard is actually urgent most of the time: a
  // registration eleven months out sat above the fill-up logged yesterday,
  // so the screen led with a deadline nobody can act on and buried the thing
  // the household just did. What is due leads only when it is genuinely
  // pressing; otherwise recent activity does.
  // A registration eleven months out is real and dated and nothing anybody can
  // act on. The list was showing whatever the five soonest happened to be, so a
  // garage in good order got a panel of deadlines at 27%, 15% and 5% consumed.
  group('what counts as due soon', () {
    testWidgets('leaves out what is still a year away', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection(due: _today.add(const Duration(days: 300)))],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-due')), findsNothing);
    });

    testWidgets('keeps what falls inside the next ninety days', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection(due: _today.add(const Duration(days: 80)))],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-due')), findsOneWidget);
    });

    // The boundary, pinned in both directions.
    testWidgets('and the ninetieth day itself', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection(due: _today.add(const Duration(days: 90)))],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-due')), findsOneWidget);
    });

    // Something already late is always worth showing, however it was dated.
    testWidgets('an overdue item is never filtered out', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [
          projection(
            due: _today.subtract(const Duration(days: 400)),
            state: ReminderState.overdue,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dashboard-due')), findsOneWidget);
    });
  });

  group('section order', () {
    List<TimelineItem> someHistory() => [
      TimelineItem(
        entryId: 'e1',
        kind: TimelineKind.fuel,
        date: _today,
        vehicleId: 'v1',
        amount: 62,
        odometerKm: 51000,
        createdBy: 'u1',
      ),
    ];

    testWidgets('recent activity leads when nothing is pressing', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection()],
        timeline: someHistory(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('dashboard-recent'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('dashboard-due'))).dy),
      );
    });

    // The cars are the overview, and each row carries its own way into a
    // fill-up, so they sit above the log of what has already happened.
    testWidgets('the cars lead, above recent activity', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection()],
        timeline: someHistory(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('dashboard-vehicles'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('dashboard-recent'))).dy,
        ),
      );
    });

    // Except when something is genuinely pressing, which outranks even them.
    testWidgets('but something overdue still outranks them', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection(state: ReminderState.overdue)],
        timeline: someHistory(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('dashboard-due'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('dashboard-vehicles'))).dy,
        ),
      );
    });

    testWidgets('an overdue item takes the top back', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection(state: ReminderState.overdue)],
        timeline: someHistory(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('dashboard-due'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('dashboard-recent'))).dy,
        ),
      );
    });

    // Due, not merely upcoming, is the notice window: close enough that the
    // household can still do something about it before it lapses.
    testWidgets('so does one inside the notice window', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        projections: [projection(state: ReminderState.due)],
        timeline: someHistory(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.byKey(const Key('dashboard-due'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('dashboard-recent'))).dy,
        ),
      );
    });
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

      expect(find.text('Fill-up'), findsOneWidget);
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
      expect(find.text('Add your first vehicle'), findsOneWidget);
      expect(find.text('See everything Garage can do'), findsOneWidget);
      expect(find.text('Receive a vehicle with a code'), findsOneWidget);
      // Two import sources are one question, asked once someone wants to
      // import rather than as two equal rows on the first screen.
      await tester.tap(find.text('Import from another app'));
      await tester.pumpAndSettle();
      expect(find.text('Import from Fuelio'), findsOneWidget);
      expect(find.text('Import a CSV (any app)'), findsOneWidget);
    });

    testWidgets('and every one of them does something', (tester) async {
      await pumpDashboard(tester);
      await tester.pumpAndSettle();

      // The complaint that started this: of the old card's four lines, two
      // were inert. A row that looks like a control and is not is worse than
      // no row.
      for (final label in [
        'Import from another app',
        'Receive a vehicle with a code',
        'See everything Garage can do',
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

      await tester.tap(find.text('Set a reminder: what it needs, and when'));
      await tester.pumpAndSettle();

      expect(
        find.text('Every (distance)'),
        findsOneWidget,
        reason:
            'this is the interval sheet; the service sheet has no such '
            'field',
      );
    });

    testWidgets('with two cars the checklist asks which one', (tester) async {
      // It took the first by name, which with two cars was the wrong one
      // half the time and looked like a decision.
      await pumpDashboard(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Astra'),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set a reminder: what it needs, and when'));
      await tester.pumpAndSettle();

      expect(find.text('Which vehicle?'), findsOneWidget);
      expect(find.text('Every (distance)'), findsNothing);
    });

    testWidgets('the checklist outlives the first entry', (tester) async {
      // It vanished with the first timeline item, so whoever logged fuel
      // first was never told to set a reminder: the step that feeds the
      // planner, Due soonest and bundling.
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

      expect(find.text('WHAT NEXT'), findsOneWidget);
      expect(find.text('Log a fill-up'), findsNothing);
      expect(
        find.text('Set a reminder: what it needs, and when'),
        findsOneWidget,
      );
    });

    testWidgets('a reminder ticks its row off', (tester) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        projections: [
          ReminderProjection(
            ruleId: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            projectedDueDate: _today.add(const Duration(days: 400)),
            state: ReminderState.upcoming,
            dueOdometerKm: 60000,
            fractionConsumed: 0.1,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Set a reminder: what it needs, and when'),
        findsNothing,
      );
      expect(find.text('Log a fill-up'), findsOneWidget);
    });

    testWidgets('can be put away, and stays away', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // The mock store outlives the test; the next one must not inherit
      // the hidden flag.
      addTearDown(() => SharedPreferences.setMockInitialValues({}));
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('what-next-hide')));
      await tester.pumpAndSettle();

      expect(find.text('WHAT NEXT'), findsNothing);
      // "Stays away" is the store, not the widget tree.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('what_next_hidden'), isTrue);
    });

    testWidgets('says nothing about reminders until it knows', (tester) async {
      // A projection fetch still loading, or failed, is not "no reminders":
      // a garage with twenty rules must not be told to set its first.
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1')],
        projectionsLoading: true,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Set a reminder: what it needs, and when'),
        findsNothing,
      );
    });

    testWidgets('a garage with a car but no history is nudged, not walked', (
      tester,
    ) async {
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      // Different work to do, so a different card: the ways in are done with.
      expect(find.text('WHAT NEXT'), findsOneWidget);
      expect(find.text('See everything Garage can do'), findsOneWidget);
      expect(find.text('Log a fill-up'), findsOneWidget);
      expect(
        find.text('Set a reminder: what it needs, and when'),
        findsOneWidget,
      );
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
      documentRepositoryProvider.overrideWithValue(FakeDocumentRepository()),
      observationRepositoryProvider.overrideWithValue(FakeObservations()),
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

  // `AsyncValueView` exists to keep these apart and says so in its docstring;
  // the dashboard read `timelineProvider.value ?? const []` instead, so a
  // garage with four years of history was told to log its first fill-up for as
  // long as the timeline took to arrive.
  group('while the data is still loading', () {
    testWidgets('does not tell an established garage to get started', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
        timelineLoading: true,
      );
      await tester.pump();

      expect(find.textContaining('first fill-up'), findsNothing);
      expect(find.textContaining('Log your first'), findsNothing);
    });

    // The other half: once the timeline has actually arrived empty, the card
    // is exactly what should be there.
    testWidgets('and does once the history has arrived, and is empty', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Golf')],
      );
      await tester.pumpAndSettle();

      expect(find.text('WHAT NEXT'), findsOneWidget);
    });
  });

  // The vehicle row carried "≈900 km left" beside the odometer, and it was the
  // most prominent number in the app and the least true one: it counted down
  // from the last full tank against a reading that only moves when something
  // is logged, so it read as a full tank for the whole tank (decision 152).
  group('what the vehicle row says about distance', () {
    testWidgets('the odometer, which is a reading somebody took', (
      tester,
    ) async {
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      expect(find.textContaining('51,000 km'), findsOneWidget);
    });

    testWidgets('and nothing about how far the car still goes', (tester) async {
      await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('left'),
        findsNothing,
        reason: 'a guess at the fuel level does not belong on the home screen',
      );
      expect(find.textContaining('≈'), findsNothing);
    });
  });

  testWidgets('while the garage is still loading the shell is already there', (
    tester,
  ) async {
    // Decision 74 replaced a tab bar over spinners with a plain "Opening your
    // garage…" screen, and it was right that a screen of spinners reads as
    // broken. A skeleton is the third option it did not weigh: the shell and
    // the shape of the cards are correct from the first frame, so nothing
    // moves when the data lands and nothing has to be waited for twice.
    await pumpDashboard(
      tester,
      householdFuture: Completer<Household?>().future,
    );
    await tester.pump();

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Opening your garage…'), findsNothing);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the skeleton replaces the spinner rather than joining it',
    );
  });

  testWidgets('the vehicles arriving does not bring a second spinner', (
    tester,
  ) async {
    // The old screen gated twice: once on the household and again on the
    // vehicles, so a cold start showed a spinner, then a spinner, then cards
    // appearing one at a time.
    await pumpDashboard(tester, vehiclesLoading: true);
    await tester.pump();

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a garage still loading is not a garage with no cars', (
    tester,
  ) async {
    // The empty state offers to add a first vehicle. Shown while the list is
    // merely in flight, it tells somebody with four years of history that
    // they have nothing.
    await pumpDashboard(tester, vehiclesLoading: true);
    await tester.pump();

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.text('Add your first vehicle'), findsNothing);
  });

  testWidgets('the quick-add sheet leads with the three that cost money', (
    tester,
  ) async {
    await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-add')));
    await tester.pumpAndSettle();

    expect(find.text('Fill-up'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Cost'), findsOneWidget);
    expect(find.text('Income'), findsNothing);

    await tester.tap(find.byKey(const Key('quick-add-more')));
    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Add reminder'), findsOneWidget);
  });

  testWidgets('the quick-add sheet can start a drive, not only log one', (
    tester,
  ) async {
    // Starting a drive was five taps away, under More › Trips, and the
    // sheet's "Trip" could only record one already made (decision 156).
    await pumpDashboard(tester, vehicles: [testVehicle('v1')]);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick-add-more')));
    await tester.pumpAndSettle();

    expect(find.text('Log a trip'), findsOneWidget);
    await tester.tap(find.text('Start a drive'));
    await tester.pumpAndSettle();

    expect(find.text('Odometer now'), findsOneWidget);
  });

  group('the quick-add sheet and archived cars', () {
    testWidgets('a sold car is not offered as somewhere to log a fill-up', (
      tester,
    ) async {
      // Reported from the field: a garage with one car and one sold one was
      // asked "which car?" and offered the sold one. The vehicle row's own
      // shortcut had always read the active list; this sheet read the full
      // one, archived included.
      await pumpDashboard(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Old Passat').copyWith(archived: true),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill-up'));
      await tester.pumpAndSettle();

      expect(
        find.text('Old Passat'),
        findsNothing,
        reason: 'an archived car is not somewhere anybody logs a fill-up',
      );
    });

    testWidgets('and with one active car it does not ask at all', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Old Passat').copyWith(archived: true),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('dashboard-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fill-up'));
      await tester.pumpAndSettle();

      expect(
        find.text('Which vehicle?'),
        findsNothing,
        reason: 'a question with one possible answer should not be asked',
      );
    });
  });

  group('in Croatian on a narrow phone at a large font', () {
    // Croatian runs 20–30% longer than English, and the ARB tests only check
    // that a translation exists. An overflow throws, so the assertion is that
    // nothing did.
    testWidgets('the dashboard with a car and a due item lays out', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        vehicles: [testVehicle('v1', nickname: 'Renault Clio')],
        projections: [
          projection(),
          projection(ruleId: 'r2'),
        ],
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
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 3000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the dashboard with a car and a due item lays out, in Italian',
      (tester) async {
        await pumpDashboard(
          tester,
          vehicles: [testVehicle('v1', nickname: 'Renault Clio')],
          projections: [
            projection(),
            projection(ruleId: 'r2'),
          ],
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
          locale: const Locale('it'),
          textScale: 1.5,
          surface: const Size(320, 3000),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('and the empty garage that greets a new account', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        locale: const Locale('hr'),
        textScale: 1.5,
        surface: const Size(320, 3000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the empty garage that greets a new account, in Italian', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        locale: const Locale('it'),
        textScale: 1.5,
        surface: const Size(320, 3000),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
