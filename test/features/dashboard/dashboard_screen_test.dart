import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/core/sync/realtime_sync.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/maintenance/bundling.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/dashboard/screens/dashboard_screen.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

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
    ],
  );
}

void main() {
  testWidgets('a household with no vehicles is pointed at adding one', (
    tester,
  ) async {
    final log = await pumpDashboard(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add vehicle'));
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
}
