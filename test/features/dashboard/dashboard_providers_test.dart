import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

ReminderProjection due(String id, DateTime date) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: 'v1',
    serviceTypeKey: 'service_$id',
    projectedDueDate: date,
    state: ReminderState.upcoming,
  );
}

ProviderContainer containerWith({
  required List<ReminderProjection> projections,
  Household household = const Household(id: 'h1', name: 'Test'),
}) {
  final container = ProviderContainer(
    overrides: [
      householdProjectionsProvider.overrideWith((ref) async => projections),
      currentHouseholdProvider.overrideWith((ref) async => household),
      todayProvider.overrideWithValue(DateTime(2026, 7, 20)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('nearby items produce a bundle', () async {
    final container = containerWith(
      projections: [
        due('a', DateTime(2026, 8, 1)),
        due('b', DateTime(2026, 8, 12)),
      ],
    );

    final bundles = await container.read(bundlesProvider.future);

    expect(bundles, hasLength(1));
    expect(bundles.single.items, hasLength(2));
  });

  test('the household window widens the grouping', () async {
    final container = containerWith(
      projections: [
        due('a', DateTime(2026, 8, 1)),
        due('b', DateTime(2026, 9, 20)),
      ],
      household: const Household(
        id: 'h1',
        name: 'Test',
        bundlingWindowDays: 60,
      ),
    );

    final bundles = await container.read(bundlesProvider.future);

    expect(bundles, hasLength(1));
  });

  test('the top bundle is the soonest one', () async {
    final container = containerWith(
      projections: [
        due('c', DateTime(2026, 11, 1)),
        due('d', DateTime(2026, 11, 8)),
        due('a', DateTime(2026, 8, 1)),
        due('b', DateTime(2026, 8, 8)),
      ],
    );

    final top = await container.read(topBundleProvider.future);

    expect(top!.visitDate, DateTime(2026, 8, 1));
  });

  test('the top bundle is null when nothing groups', () async {
    final container = containerWith(
      projections: [due('a', DateTime(2026, 8, 1))],
    );

    expect(await container.read(topBundleProvider.future), isNull);
  });

  group('the fleet consumption figure', () {
    Vehicle vehicle(String id, String fuelTypeKey) {
      return Vehicle(
        id: id,
        householdId: 'h1',
        nickname: id,
        fuelTypeKey: fuelTypeKey,
        baselineOdometerKm: 0,
        baselineDate: DateTime.utc(2026, 1, 1),
      );
    }

    ProviderContainer fleetWith(Map<Vehicle, double?> averages) {
      final container = ProviderContainer(
        overrides: [
          vehiclesProvider.overrideWith((ref) async => averages.keys.toList()),
          for (final entry in averages.entries)
            averageEconomyProvider(
              entry.key.id,
            ).overrideWith((ref) async => entry.value),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('averages the vehicles that burn fuel', () async {
      final container = fleetWith({
        vehicle('v1', 'fuel_petrol'): 6.0,
        vehicle('v2', 'fuel_diesel'): 8.0,
      });

      expect(await container.read(fleetAverageEconomyProvider.future), 7.0);
    });

    test('leaves an electric vehicle out of it', () async {
      // Averaging kWh/100km with l/100km would produce a number that means
      // nothing; the fleet figure is about what the pumps cost.
      final container = fleetWith({
        vehicle('v1', 'fuel_petrol'): 6.0,
        vehicle('v2', 'fuel_electric'): 18.0,
      });

      expect(await container.read(fleetAverageEconomyProvider.future), 6.0);
    });

    test('an all-electric fleet has no litre figure at all', () async {
      final container = fleetWith({vehicle('v1', 'fuel_electric'): 18.0});

      expect(await container.read(fleetAverageEconomyProvider.future), isNull);
    });
  });
}
