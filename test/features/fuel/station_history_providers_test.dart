import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/fuel/providers/station_history_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

FuelEntry fill({
  required String id,
  required String vehicleId,
  required DateTime date,
  String? station,
}) {
  return FuelEntry(
    id: id,
    vehicleId: vehicleId,
    date: date,
    odometerKm: 1000,
    volumeL: 40,
    fullTank: true,
    missedFill: false,
    station: station,
    createdBy: 'u1',
  );
}

Vehicle vehicle(String id, {bool archived = false}) {
  return Vehicle(
    id: id,
    householdId: 'h1',
    nickname: id,
    fuelTypeKey: 'fuel_petrol',
    baselineOdometerKm: 0,
    baselineDate: DateTime.utc(2026, 1, 1),
    archived: archived,
  );
}

ProviderContainer containerWith({
  required List<Vehicle> vehicles,
  required Map<String, List<FuelEntry>> logs,
}) {
  final container = ProviderContainer(
    overrides: [
      allVehiclesProvider.overrideWith((ref) async => vehicles),
      for (final vehicle in vehicles)
        rawFuelEntriesProvider(
          vehicle.id,
        ).overrideWith((ref) async => logs[vehicle.id] ?? const []),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('stations are pooled across the whole fleet', () async {
    final container = containerWith(
      vehicles: [vehicle('v1'), vehicle('v2')],
      logs: {
        'v1': [
          fill(
            id: '1',
            vehicleId: 'v1',
            date: DateTime.utc(2026, 1, 1),
            station: 'Shell',
          ),
        ],
        'v2': [
          fill(
            id: '2',
            vehicleId: 'v2',
            date: DateTime.utc(2026, 2, 1),
            station: 'INA',
          ),
          fill(
            id: '3',
            vehicleId: 'v2',
            date: DateTime.utc(2026, 3, 1),
            station: 'INA',
          ),
        ],
      },
    );

    expect(await container.read(knownStationsProvider.future), [
      'INA',
      'Shell',
    ]);
  });

  test('an archived vehicle still contributes its stations', () async {
    final container = containerWith(
      vehicles: [vehicle('v1'), vehicle('v2', archived: true)],
      logs: {
        'v2': [
          fill(
            id: '1',
            vehicleId: 'v2',
            date: DateTime.utc(2026, 1, 1),
            station: 'Petrol',
          ),
        ],
      },
    );

    expect(await container.read(knownStationsProvider.future), ['Petrol']);
  });

  test('a household with no fuel history offers nothing', () async {
    final container = containerWith(vehicles: [vehicle('v1')], logs: {});

    expect(await container.read(knownStationsProvider.future), isEmpty);
  });
}
