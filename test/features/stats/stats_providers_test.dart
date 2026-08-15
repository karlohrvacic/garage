import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/stats/providers/stats_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

Vehicle vehicle(String id) {
  return Vehicle(
    id: id,
    householdId: 'h1',
    nickname: id,
    fuelTypeKey: 'fuel_petrol',
    baselineOdometerKm: 0,
    baselineDate: DateTime.utc(2026, 1, 1),
  );
}

FuelEntry fuel(String id, String vehicleId, int odometerKm) {
  return FuelEntry(
    id: id,
    vehicleId: vehicleId,
    date: DateTime.utc(2026, 5, 1).add(Duration(days: odometerKm ~/ 100)),
    odometerKm: odometerKm,
    volumeL: 40,
    total: 60,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

ServiceEntry service(String id, String vehicleId) {
  return ServiceEntry(
    id: id,
    vehicleId: vehicleId,
    date: DateTime.utc(2026, 5, 10),
    odometerKm: 52000,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: 'u1',
    cost: 210,
  );
}

CostEntry cost(String id, String vehicleId, {int? odometerKm}) {
  return CostEntry(
    id: id,
    vehicleId: vehicleId,
    date: DateTime.utc(2026, 5, 20),
    category: CostCategories.insurance,
    amount: 300,
    odometerKm: odometerKm,
    createdBy: 'u1',
  );
}

ProviderContainer containerWith({
  required List<Vehicle> vehicles,
  Map<String, List<FuelEntry>> fuelLogs = const {},
  Map<String, List<ServiceEntry>> services = const {},
  Map<String, List<CostEntry>> costs = const {},
}) {
  final container = ProviderContainer(
    overrides: [
      vehiclesProvider.overrideWith((ref) async => vehicles),
      for (final vehicle in vehicles) ...[
        rawFuelEntriesProvider(
          vehicle.id,
        ).overrideWith((ref) async => fuelLogs[vehicle.id] ?? const []),
        serviceEntriesProvider(
          vehicle.id,
        ).overrideWith((ref) async => services[vehicle.id] ?? const []),
        costEntriesProvider(
          vehicle.id,
        ).overrideWith((ref) async => costs[vehicle.id] ?? const []),
      ],
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a null vehicle id aggregates the whole fleet', () async {
    final container = containerWith(
      vehicles: [vehicle('v1'), vehicle('v2')],
      fuelLogs: {
        'v1': [fuel('f1', 'v1', 50000)],
        'v2': [fuel('f2', 'v2', 30000)],
      },
    );

    final stats = await container.read(statsDataProvider(null).future);

    expect(stats.fuel, hasLength(2));
    expect(stats.readingsPerVehicle, hasLength(2));
  });

  test('a vehicle id narrows the aggregation to that vehicle', () async {
    final container = containerWith(
      vehicles: [vehicle('v1'), vehicle('v2')],
      fuelLogs: {
        'v1': [fuel('f1', 'v1', 50000)],
        'v2': [fuel('f2', 'v2', 30000)],
      },
    );

    final stats = await container.read(statsDataProvider('v1').future);

    expect(stats.fuel.single.id, 'f1');
    expect(stats.readingsPerVehicle, hasLength(1));
  });

  test('economy comes from the domain algorithm, per vehicle', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      fuelLogs: {
        'v1': [fuel('f1', 'v1', 50000), fuel('f2', 'v1', 50500)],
      },
    );

    final stats = await container.read(statsDataProvider('v1').future);

    expect(stats.economy, hasLength(1));
    expect(stats.economy.single.litersPer100Km, closeTo(8.0, 0.0001));
  });

  test('readings stay grouped per vehicle, never merged', () async {
    final container = containerWith(
      vehicles: [vehicle('v1'), vehicle('v2')],
      fuelLogs: {
        'v1': [fuel('f1', 'v1', 50000)],
        'v2': [fuel('f2', 'v2', 30000)],
      },
    );

    final stats = await container.read(statsDataProvider(null).future);
    final groups = stats.readingsPerVehicle.map((g) => g.single.km).toList()
      ..sort();

    expect(groups, [30000, 50000]);
  });

  test('every source contributes odometer readings', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      fuelLogs: {
        'v1': [fuel('f1', 'v1', 50000)],
      },
      services: {
        'v1': [service('s1', 'v1')],
      },
      costs: {
        'v1': [cost('c1', 'v1', odometerKm: 53000)],
      },
    );

    final stats = await container.read(statsDataProvider(null).future);

    expect(stats.readingsPerVehicle.single.map((r) => r.km), [
      50000,
      52000,
      53000,
    ]);
  });

  test('a cost with no odometer contributes no reading', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      costs: {
        'v1': [cost('c1', 'v1')],
      },
    );

    final stats = await container.read(statsDataProvider(null).future);

    expect(stats.costs, hasLength(1));
    expect(stats.readingsPerVehicle.single, isEmpty);
  });

  test('an unknown vehicle id aggregates nothing', () async {
    final container = containerWith(vehicles: [vehicle('v1')]);

    final stats = await container.read(statsDataProvider('nope').future);

    expect(stats.fuel, isEmpty);
    expect(stats.readingsPerVehicle, isEmpty);
  });
}
