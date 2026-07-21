import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

class FakeMaintenanceRepository implements MaintenanceRepository {
  FakeMaintenanceRepository({this.rules = const [], this.entries = const []});

  List<ReminderRule> rules;
  List<ServiceEntry> entries;

  @override
  Future<List<ServiceType>> serviceTypes() async => const [
        ServiceType(
          key: 'service_oil_change',
          defaultIntervalKm: 15000,
          defaultIntervalMonths: 12,
        ),
      ];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      entries;

  @override
  Future<void> upsertRule(ReminderRule rule) async {}

  @override
  Future<void> deleteRule(String id) async {}

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async {}
}

ProviderContainer containerWith({
  required FakeMaintenanceRepository maintenance,
  List<FuelEntry> fuelEntries = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      maintenanceRepositoryProvider.overrideWithValue(maintenance),
      rawFuelEntriesProvider('v1').overrideWith((ref) async => fuelEntries),
      vehicleProvider('v1').overrideWith(
        (ref) async => Vehicle(
          id: 'v1',
          householdId: 'h1',
          nickname: 'Golf',
          fuelTypeKey: 'fuel_diesel',
          baselineOdometerKm: 45000,
          baselineDate: DateTime.utc(2025, 12, 1),
        ),
      ),
      todayProvider.overrideWithValue(DateTime(2026, 7, 20)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

FuelEntry fill(int odometerKm, DateTime date) {
  return FuelEntry(
    id: 'f$odometerKm',
    vehicleId: 'v1',
    date: date,
    odometerKm: odometerKm,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

void main() {
  test('a rule with a past service projects from that service', () async {
    final container = containerWith(
      maintenance: FakeMaintenanceRepository(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 10000,
          ),
        ],
        entries: [
          ServiceEntry(
            id: 's1',
            vehicleId: 'v1',
            date: DateTime(2026, 1, 1),
            odometerKm: 50000,
            serviceTypeKeys: const ['service_oil_change'],
            createdBy: 'u1',
          ),
        ],
      ),
      fuelEntries: [
        fill(50000, DateTime(2026, 1, 1)),
        fill(54000, DateTime(2026, 5, 1)),
      ],
    );

    final projections =
        await container.read(vehicleProjectionsProvider('v1').future);

    expect(projections, hasLength(1));
    expect(projections.single.dueOdometerKm, 60000);
  });

  test('only the most recent matching service anchors the projection',
      () async {
    final container = containerWith(
      maintenance: FakeMaintenanceRepository(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 10000,
          ),
        ],
        entries: [
          ServiceEntry(
            id: 'old',
            vehicleId: 'v1',
            date: DateTime(2025, 1, 1),
            odometerKm: 40000,
            serviceTypeKeys: const ['service_oil_change'],
            createdBy: 'u1',
          ),
          ServiceEntry(
            id: 'new',
            vehicleId: 'v1',
            date: DateTime(2026, 1, 1),
            odometerKm: 50000,
            serviceTypeKeys: const ['service_oil_change'],
            createdBy: 'u1',
          ),
        ],
      ),
      fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
    );

    final projections =
        await container.read(vehicleProjectionsProvider('v1').future);

    expect(projections.single.dueOdometerKm, 60000);
  });

  test('a service entry covering several items anchors all of them', () async {
    final container = containerWith(
      maintenance: FakeMaintenanceRepository(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 10000,
          ),
          const ReminderRule(
            id: 'r2',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_filter',
            intervalKm: 10000,
          ),
        ],
        entries: [
          ServiceEntry(
            id: 'bundle',
            vehicleId: 'v1',
            date: DateTime(2026, 1, 1),
            odometerKm: 50000,
            serviceTypeKeys: const ['service_oil_change', 'service_oil_filter'],
            createdBy: 'u1',
          ),
        ],
      ),
      fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
    );

    final projections =
        await container.read(vehicleProjectionsProvider('v1').future);

    expect(projections, hasLength(2));
    expect(projections.every((p) => p.dueOdometerKm == 60000), isTrue);
  });

  test('an inactive rule is not projected', () async {
    final container = containerWith(
      maintenance: FakeMaintenanceRepository(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 10000,
            active: false,
          ),
        ],
      ),
    );

    expect(
      await container.read(vehicleProjectionsProvider('v1').future),
      isEmpty,
    );
  });

  test(
      'a fuel-less vehicle uses its service odometer as the current reading',
      () async {
    // Baseline 45000, no fuel logged, last oil change at 50000, every 15000 km.
    // The car is really at ~50000, so ~15000 km remain — not ~20000 as it would
    // be if the current reading fell back to the 45000 baseline.
    final container = containerWith(
      maintenance: FakeMaintenanceRepository(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalKm: 15000,
          ),
        ],
        entries: [
          ServiceEntry(
            id: 's1',
            vehicleId: 'v1',
            date: DateTime(2026, 1, 1),
            odometerKm: 50000,
            serviceTypeKeys: const ['service_oil_change'],
            createdBy: 'u1',
          ),
        ],
      ),
    );

    final projections =
        await container.read(vehicleProjectionsProvider('v1').future);

    // dueOdometerKm anchors on the last service: 50000 + 15000.
    expect(projections.single.dueOdometerKm, 65000);
    // 15000 km remaining at the 30 km/day fallback = 500 days out. If the
    // current reading had fallen back to the 45000 baseline it would be 20000
    // km / 30 = ~667 days, a different (later) date.
    expect(
      projections.single.projectedDueDate,
      DateTime(2026, 7, 20 + 500),
    );
  });

  test('projections come back soonest first', () async {
    final container = containerWith(
      maintenance: FakeMaintenanceRepository(
        rules: [
          const ReminderRule(
            id: 'later',
            vehicleId: 'v1',
            serviceTypeKey: 'service_timing_belt',
            intervalMonths: 60,
          ),
          const ReminderRule(
            id: 'sooner',
            vehicleId: 'v1',
            serviceTypeKey: 'service_oil_change',
            intervalMonths: 6,
          ),
        ],
        entries: [
          ServiceEntry(
            id: 's1',
            vehicleId: 'v1',
            date: DateTime(2026, 1, 1),
            odometerKm: 50000,
            serviceTypeKeys: const [
              'service_timing_belt',
              'service_oil_change',
            ],
            createdBy: 'u1',
          ),
        ],
      ),
    );

    final projections =
        await container.read(vehicleProjectionsProvider('v1').future);

    expect(projections.first.ruleId, 'sooner');
    expect(projections.first.state, ReminderState.overdue);
  });
}
