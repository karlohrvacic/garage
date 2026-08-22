import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/tyres/providers/tyre_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

import '../../support/vehicle_entries.dart';

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
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) async {}

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> deleteServiceEntry(String id) async {}

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async {}
}

ProviderContainer containerWith({
  FakeMaintenanceRepository? maintenance,
  List<ReminderRule> rules = const [],
  List<FuelEntry> fuelEntries = const [],
  List<OdometerEntry> readings = const [],
  List<TyreSet> tyres = const [],
  String countryCode = 'HR',
  DateTime? today,
}) {
  final container = ProviderContainer(
    overrides: [
      maintenanceRepositoryProvider.overrideWithValue(
        maintenance ?? FakeMaintenanceRepository(rules: rules),
      ),
      tyreSetsProvider('v1').overrideWith((ref) async => tyres),
      // The odometer series merges every entry kind, so all of them have to
      // resolve even when a test only cares about two.
      ...vehicleEntryOverrides(
        'v1',
        fuel: fuelEntries,
        readings: readings,
        // Service history comes from the repository fake in this harness.
        services: null,
      ),
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
      currentHouseholdProvider.overrideWith(
        (ref) async =>
            Household(id: 'h1', name: 'Test', countryCode: countryCode),
      ),
      todayProvider.overrideWithValue(today ?? DateTime(2026, 7, 20)),
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

    final projections = await container.read(
      vehicleProjectionsProvider('v1').future,
    );

    expect(projections, hasLength(1));
    expect(projections.single.dueOdometerKm, 60000);
  });

  test(
    'only the most recent matching service anchors the projection',
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

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      expect(projections.single.dueOdometerKm, 60000);
    },
  );

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

    final projections = await container.read(
      vehicleProjectionsProvider('v1').future,
    );

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

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      // dueOdometerKm anchors on the last service: 50000 + 15000.
      expect(projections.single.dueOdometerKm, 65000);
      // 15000 km remaining at the 30 km/day fallback = 500 days out. If the
      // current reading had fallen back to the 45000 baseline it would be 20000
      // km / 30 = ~667 days, a different (later) date.
      expect(projections.single.projectedDueDate, DateTime(2026, 7, 20 + 500));
    },
  );

  test(
    'a vehicle with no fuel logged still measures its own driving rate',
    () async {
      // The bug this closes: the rate was read from fill-ups alone, so a
      // household that services its car but pays cash at the pump got the
      // assumed 30 km/day for every projection however much it actually drove.
      // Two services 100 days and 10000 km apart is 100 km/day.
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
              id: 's2',
              vehicleId: 'v1',
              date: DateTime(2026, 4, 11),
              odometerKm: 60000,
              serviceTypeKeys: const ['service_tyre_rotation'],
              createdBy: 'u1',
            ),
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

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      // Due at 50000 + 15000 = 65000, the car is at 60000, so 5000 km remain.
      // At the measured 100 km/day that is 50 days, not the 167 the fallback
      // rate would have produced.
      expect(projections.single.dueOdometerKm, 65000);
      expect(projections.single.projectedDueDate, DateTime(2026, 7, 20 + 50));
    },
  );

  test('a standalone odometer reading advances the projection', () async {
    // A reading with no money attached is the whole point of the entry kind:
    // it is how someone says "it is on 60000 now" without inventing a fill-up.
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
      readings: [
        OdometerEntry(
          id: 'o1',
          vehicleId: 'v1',
          date: DateTime(2026, 4, 11),
          odometerKm: 60000,
          createdBy: 'u1',
        ),
      ],
    );

    final projections = await container.read(
      vehicleProjectionsProvider('v1').future,
    );

    expect(projections.single.dueOdometerKm, 65000);
    expect(projections.single.projectedDueDate, DateTime(2026, 7, 20 + 50));
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

    final projections = await container.read(
      vehicleProjectionsProvider('v1').future,
    );

    expect(projections.first.ruleId, 'sooner');
    expect(projections.first.state, ReminderState.overdue);
  });

  group('seasonal tyre swaps', () {
    test(
      'are dropped for a car recorded as running all-season tyres',
      () async {
        final container = containerWith(
          rules: [
            const ReminderRule(
              id: 'r1',
              vehicleId: 'v1',
              serviceTypeKey: 'service_tire_swap_seasonal',
              intervalMonths: 6,
            ),
          ],
          fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
          tyres: [
            TyreSet(
              id: 't1',
              vehicleId: 'v1',
              name: 'All season',
              season: TyreSeason.allSeason,
              fitted: true,
              createdBy: 'u1',
            ),
          ],
        );

        final projections = await container.read(
          vehicleProjectionsProvider('v1').future,
        );

        expect(projections, isEmpty);
      },
    );

    test('are kept for a car with a winter set', () async {
      final container = containerWith(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_tire_swap_seasonal',
            intervalMonths: 6,
          ),
        ],
        fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
        tyres: [
          TyreSet(
            id: 't1',
            vehicleId: 'v1',
            name: 'Winter',
            season: TyreSeason.winter,
            fitted: true,
            createdBy: 'u1',
          ),
        ],
      );

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      expect(projections, hasLength(1));
    });

    test('are kept when tyres were never recorded at all', () async {
      // Absence of tyre data is not evidence of all-season tyres.
      final container = containerWith(
        rules: [
          const ReminderRule(
            id: 'r1',
            vehicleId: 'v1',
            serviceTypeKey: 'service_tire_swap_seasonal',
            intervalMonths: 6,
          ),
        ],
        fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
      );

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      expect(projections, hasLength(1));
    });
  });

  group('the seasonal swap against a statutory window', () {
    ReminderRule swapRule() => const ReminderRule(
      id: 'r1',
      vehicleId: 'v1',
      serviceTypeKey: 'service_tire_swap_seasonal',
      intervalMonths: 6,
    );

    ServiceEntry swappedOn(DateTime date) => ServiceEntry(
      id: 's1',
      vehicleId: 'v1',
      date: date,
      odometerKm: 50000,
      serviceTypeKeys: const ['service_tire_swap_seasonal'],
      createdBy: 'u1',
    );

    test(
      'lands on the statutory date, not six months after the last one',
      () async {
        // Swapped in late June, so the interval alone says 20 December — a date
        // nothing in the world happens on.
        final container = containerWith(
          maintenance: FakeMaintenanceRepository(
            rules: [swapRule()],
            entries: [swappedOn(DateTime.utc(2026, 6, 20))],
          ),
          fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
          today: DateTime(2026, 10, 1),
        );

        final projections = await container.read(
          vehicleProjectionsProvider('v1').future,
        );

        expect(projections.single.projectedDueDate, DateTime.utc(2026, 11, 15));
      },
    );

    test('follows the country, not Croatia', () async {
      // Slovenia comes out of winter a month earlier than Croatia does.
      final container = containerWith(
        maintenance: FakeMaintenanceRepository(
          rules: [swapRule()],
          entries: [swappedOn(DateTime.utc(2026, 11, 15))],
        ),
        fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
        countryCode: 'SI',
        today: DateTime(2026, 12, 1),
      );

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      expect(projections.single.projectedDueDate, DateTime.utc(2027, 3, 15));
    });

    test('a country with no verified window keeps the interval', () async {
      // Germany's obligation follows the road's condition, so there is no date
      // to pin to and inventing one would be worse than the interval.
      final container = containerWith(
        maintenance: FakeMaintenanceRepository(
          rules: [swapRule()],
          entries: [swappedOn(DateTime.utc(2026, 6, 20))],
        ),
        fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
        countryCode: 'DE',
        today: DateTime(2026, 10, 1),
      );

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      expect(projections.single.projectedDueDate, DateTime(2026, 12, 20));
    });

    test(
      'an all-season car gets no swap even where the dates are fixed',
      () async {
        final container = containerWith(
          rules: [swapRule()],
          fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
          tyres: [
            TyreSet(
              id: 't1',
              vehicleId: 'v1',
              name: 'All year',
              season: TyreSeason.allSeason,
              fitted: true,
              createdBy: 'u1',
            ),
          ],
          today: DateTime(2026, 10, 1),
        );

        final projections = await container.read(
          vehicleProjectionsProvider('v1').future,
        );

        expect(projections, isEmpty);
      },
    );

    test('another rule on the same car is left alone', () async {
      final container = containerWith(
        maintenance: FakeMaintenanceRepository(
          rules: [
            swapRule(),
            const ReminderRule(
              id: 'r2',
              vehicleId: 'v1',
              serviceTypeKey: 'service_oil_change',
              intervalMonths: 12,
            ),
          ],
          entries: [swappedOn(DateTime.utc(2026, 6, 20))],
        ),
        fuelEntries: [fill(50000, DateTime(2026, 1, 1))],
        today: DateTime(2026, 10, 1),
      );

      final projections = await container.read(
        vehicleProjectionsProvider('v1').future,
      );

      final oil = projections.firstWhere(
        (p) => p.serviceTypeKey == 'service_oil_change',
      );
      expect(oil.projectedDueDate, isNot(DateTime.utc(2026, 11, 15)));
    });
  });
}
