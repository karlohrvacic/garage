import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/costs/providers/cost_providers.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
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

FuelEntry fuel(String id, DateTime date, {double? total = 60}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    odometerKm: 51000,
    volumeL: 40,
    total: total,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

ServiceEntry service(String id, DateTime date) {
  return ServiceEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    odometerKm: 52000,
    serviceTypeKeys: const ['service_oil_change'],
    createdBy: 'u1',
    cost: 210,
  );
}

CostEntry cost(String id, DateTime date) {
  return CostEntry(
    id: id,
    vehicleId: 'v1',
    date: date,
    category: CostCategories.parking,
    amount: 12,
    createdBy: 'u1',
  );
}

ProviderContainer containerWith({
  List<Vehicle> vehicles = const [],
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
  test('every kind of entry lands on the timeline', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      fuelLogs: {
        'v1': [fuel('f1', DateTime.utc(2026, 5, 1))],
      },
      services: {
        'v1': [service('s1', DateTime.utc(2026, 5, 2))],
      },
      costs: {
        'v1': [cost('c1', DateTime.utc(2026, 5, 3))],
      },
    );

    final items = await container.read(timelineProvider.future);

    expect(items.map((i) => i.kind), [
      TimelineKind.cost,
      TimelineKind.service,
      TimelineKind.fuel,
    ]);
  });

  test('the newest event comes first', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      fuelLogs: {
        'v1': [
          fuel('old', DateTime.utc(2026, 1, 1)),
          fuel('new', DateTime.utc(2026, 8, 1)),
        ],
      },
    );

    final items = await container.read(timelineProvider.future);

    expect(items.first.date, DateTime.utc(2026, 8, 1));
    expect(items.last.date, DateTime.utc(2026, 1, 1));
  });

  test('items carry what the row needs to render', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      services: {
        'v1': [service('s1', DateTime.utc(2026, 5, 2))],
      },
      costs: {
        'v1': [cost('c1', DateTime.utc(2026, 5, 3))],
      },
    );

    final items = await container.read(timelineProvider.future);
    final serviceItem = items.firstWhere((i) => i.kind == TimelineKind.service);
    final costItem = items.firstWhere((i) => i.kind == TimelineKind.cost);

    expect(serviceItem.serviceTypeKeys, ['service_oil_change']);
    expect(serviceItem.amount, 210);
    expect(serviceItem.odometerKm, 52000);
    expect(costItem.costCategory, CostCategories.parking);
    expect(costItem.vehicleId, 'v1');
  });

  test('a fill-up with no total still appears, with a null amount', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      fuelLogs: {
        'v1': [fuel('f1', DateTime.utc(2026, 5, 1), total: null)],
      },
    );

    final items = await container.read(timelineProvider.future);

    expect(items.single.amount, isNull);
  });

  test('the fleet is merged, not just the first vehicle', () async {
    final container = containerWith(
      vehicles: [vehicle('v1'), vehicle('v2')],
      fuelLogs: {
        'v1': [fuel('f1', DateTime.utc(2026, 5, 1))],
        'v2': [fuel('f2', DateTime.utc(2026, 6, 1))],
      },
    );

    final items = await container.read(timelineProvider.future);

    expect(items.map((i) => i.vehicleId), ['v2', 'v1']);
  });

  test('every item records who logged it', () async {
    final container = containerWith(
      vehicles: [vehicle('v1')],
      fuelLogs: {
        'v1': [fuel('f1', DateTime.utc(2026, 5, 1))],
      },
      services: {
        'v1': [service('s1', DateTime.utc(2026, 5, 2))],
      },
      costs: {
        'v1': [cost('c1', DateTime.utc(2026, 5, 3))],
      },
    );

    final items = await container.read(timelineProvider.future);

    expect(items.map((i) => i.createdBy), ['u1', 'u1', 'u1']);
  });

  test('a household with no vehicles has an empty timeline', () async {
    final container = containerWith();

    expect(await container.read(timelineProvider.future), isEmpty);
  });
}
