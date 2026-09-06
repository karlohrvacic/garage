import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/core/sync/realtime_sync.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/dashboard/screens/dashboard_screen.dart';
import 'package:garage/features/income/providers/income_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/odometer/providers/odometer_providers.dart';
import 'package:garage/features/trips/providers/trip_providers.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';

class SilentNotifications implements NotificationService {
  int syncs = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> cancelAll() async => syncs++;

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

/// The dashboard over its **real** provider graph, with only the repositories
/// faked.
///
/// Every other dashboard test overrides `bundlesProvider`,
/// `householdProjectionsProvider` and the rest directly, which means the
/// screen's reminder listeners fire against futures the test supplies and
/// never against the graph actually being invalidated. That is why the
/// "setState during build" assertion in `known-bugs-and-risks.md` could not be
/// reproduced, and why none of those listeners was covered at all.
Future<SilentNotifications> pumpLiveDashboard(
  WidgetTester tester,
  FakeGarageBootstrapRepository bootstrap, {
  List<ServiceEntry> services = const [],
  List<ReminderRule> rules = const [],
}) async {
  final notifications = SilentNotifications();
  await pumpScreen(
    tester,
    const DashboardScreen(),
    surface: const Size(500, 1800),
    vehicles: bootstrap.vehicles,
    extraRoutes: const {'/vehicles/new', '/import', '/transfer'},
    // Startup's own fetch, live: the test's own, so it can add a car to it and
    // invalidate, the way saving one does.
    bootstrap: bootstrap,
    overrides: [
      realtimeSyncProvider.overrideWith((ref) {}),
      notificationServiceProvider.overrideWithValue(notifications),
      vehicleRepositoryProvider.overrideWithValue(
        FakeVehicleRepository(vehicles: bootstrap.vehicles),
      ),
      fuelRepositoryProvider.overrideWithValue(FakeFuelRepository()),
      costRepositoryProvider.overrideWithValue(FakeCostRepository()),
      odometerRepositoryProvider.overrideWithValue(FakeOdometerRepository()),
      maintenanceRepositoryProvider.overrideWithValue(
        FakeMaintenanceRepository(services: services, rules: rules),
      ),
      // The seasonal-swap rule asks what the car is shod with before deciding
      // whether its reminder applies. Without this the projection chain lands
      // in an error state and every listener below it stays silent — which is
      // exactly how a harness can look like it covers something and not.
      tyreRepositoryProvider.overrideWithValue(FakeTyreRepository()),
      tripRepositoryProvider.overrideWithValue(FakeTripRepository()),
      incomeRepositoryProvider.overrideWithValue(FakeIncomeRepository()),
    ],
  );
  await tester.pumpAndSettle();
  return notifications;
}

void main() {
  final golf = testVehicle('v1', nickname: 'Golf');

  testWidgets('the dashboard stands up on the real provider graph', (
    tester,
  ) async {
    // The harness itself is the point: if this ever stops holding, the
    // listener tests below are testing nothing.
    await pumpLiveDashboard(
      tester,
      FakeGarageBootstrapRepository(vehicles: [golf]),
    );

    expect(find.text('Golf'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving the first vehicle does not assert during build', (
    tester,
  ) async {
    // The bug this harness was built for: "setState() called during build",
    // seen once in a debug web build at the moment the first vehicle was
    // saved, pointing at the dashboard's `ref.listen(bundlesProvider, …)`.
    final bootstrap = FakeGarageBootstrapRepository();
    await pumpLiveDashboard(tester, bootstrap);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    // Exactly what the vehicle sheet does when it saves: the car exists, and
    // the one fetch that knows about cars is thrown away.
    bootstrap.vehicles = [golf];
    container.invalidate(garageBootstrapProvider);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Golf'), findsWidgets);
  });

  testWidgets('a reminder that comes due reaches the notification service', (
    tester,
  ) async {
    // The listener chain end to end: a rule and a service entry produce a
    // projection, the projection produces a bundle, and the bundle is what
    // the dashboard's listener syncs. Nothing in the suite covered this.
    final bootstrap = FakeGarageBootstrapRepository(vehicles: [golf]);
    final notifications = await pumpLiveDashboard(
      tester,
      bootstrap,
      rules: const [
        ReminderRule(
          id: 'r1',
          vehicleId: 'v1',
          serviceTypeKey: 'service_oil_change',
          intervalKm: 15000,
          intervalMonths: 12,
        ),
      ],
      services: [
        ServiceEntry(
          id: 's1',
          vehicleId: 'v1',
          date: DateTime.utc(2026, 1, 10),
          odometerKm: 50000,
          serviceTypeKeys: const ['service_oil_change'],
          createdBy: 'u1',
        ),
      ],
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DashboardScreen)),
    );
    expect(
      container.read(householdProjectionsProvider).hasValue,
      isTrue,
      reason: 'the projections must actually resolve, or this test is vacuous',
    );
    expect(
      notifications.syncs,
      greaterThan(0),
      reason: 'the dashboard listener syncs the schedule once data arrives',
    );
    expect(tester.takeException(), isNull);
  });
}
