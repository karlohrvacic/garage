import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';

class FakeFuelRepository implements FuelRepository {
  FakeFuelRepository(this.entries);

  List<FuelEntry> entries;

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(FuelEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(FuelEntry entry) async {
    entries = [
      for (final existing in entries)
        if (existing.id == entry.id) entry else existing,
    ];
  }

  @override
  Future<void> delete(String id) async =>
      entries = entries.where((e) => e.id != id).toList();
}

FuelEntry fill(String id, int odometerKm, double volumeL) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 1, 1).add(Duration(days: odometerKm ~/ 100)),
    odometerKm: odometerKm,
    volumeL: volumeL,
    fullTank: true,
    missedFill: false,
    createdBy: 'u1',
  );
}

ProviderContainer containerWith(FakeFuelRepository fake) {
  final container = ProviderContainer(
    overrides: [
      fuelRepositoryProvider.overrideWithValue(fake),
      // Economy asks the vehicle what fuel it mainly takes, so a car that has
      // gained a second tank does not split its older, unnamed fills into a
      // chain of their own.
      vehicleProvider('v1').overrideWith(
        (ref) async => Vehicle(
          id: 'v1',
          householdId: 'h1',
          nickname: 'Golf',
          fuelTypeKey: 'fuel_diesel',
          baselineOdometerKm: 0,
          baselineDate: DateTime.utc(2026, 1, 1),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the ledger is newest first', () async {
    final container = containerWith(
      FakeFuelRepository([fill('1', 1000, 40), fill('2', 1500, 35)]),
    );

    final entries = await container.read(fuelEntriesProvider('v1').future);

    expect(entries.first.id, '2');
  });

  test('economy points come from the domain algorithm', () async {
    final container = containerWith(
      FakeFuelRepository([fill('1', 1000, 40), fill('2', 1500, 35)]),
    );

    final points = await container.read(economyPointsProvider('v1').future);

    expect(points, hasLength(1));
    expect(points.single.litersPer100Km, closeTo(7.0, 0.0001));
  });

  test('the average is null with too little history', () async {
    final container = containerWith(FakeFuelRepository([fill('1', 1000, 40)]));

    expect(await container.read(averageEconomyProvider('v1').future), isNull);
  });

  test('a plug-in hybrid averages its tanks, not its charges', () async {
    // The figure is read in the car's own energy, litres here. Blended with
    // the charges it was litres and kilowatt-hours added together.
    final container = ProviderContainer(
      overrides: [
        fuelRepositoryProvider.overrideWithValue(
          FakeFuelRepository([
            fill('1', 1000, 40),
            fill('2', 1500, 35),
            FuelEntry(
              id: '3',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 1, 11),
              odometerKm: 1100,
              volumeL: 60,
              fullTank: true,
              missedFill: false,
              fuelTypeKey: 'fuel_electric',
              createdBy: 'u1',
            ),
            FuelEntry(
              id: '4',
              vehicleId: 'v1',
              date: DateTime.utc(2026, 1, 14),
              odometerKm: 1400,
              volumeL: 60,
              fullTank: true,
              missedFill: false,
              fuelTypeKey: 'fuel_electric',
              createdBy: 'u1',
            ),
          ]),
        ),
        vehicleProvider('v1').overrideWith(
          (ref) async => Vehicle(
            id: 'v1',
            householdId: 'h1',
            nickname: 'Outlander',
            fuelTypeKey: 'fuel_petrol',
            secondaryFuelTypeKey: 'fuel_electric',
            baselineOdometerKm: 0,
            baselineDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(averageEconomyProvider('v1').future),
      closeTo(7.0, 0.0001),
    );
  });

  test('an electric car averages its charges', () async {
    final container = ProviderContainer(
      overrides: [
        fuelRepositoryProvider.overrideWithValue(
          FakeFuelRepository([fill('1', 1000, 18), fill('2', 1100, 18)]),
        ),
        vehicleProvider('v1').overrideWith(
          (ref) async => Vehicle(
            id: 'v1',
            householdId: 'h1',
            nickname: 'Leaf',
            fuelTypeKey: 'fuel_electric',
            baselineOdometerKm: 0,
            baselineDate: DateTime.utc(2026, 1, 1),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(averageEconomyProvider('v1').future),
      closeTo(18.0, 0.0001),
    );
  });

  test('editing an entry recalculates the economy points', () async {
    final fake = FakeFuelRepository([fill('1', 1000, 40), fill('2', 1500, 35)]);
    final container = containerWith(fake);

    final before = await container.read(economyPointsProvider('v1').future);
    expect(before.single.litersPer100Km, closeTo(7.0, 0.0001));

    await fake.update(fill('2', 1700, 35));
    container.invalidate(rawFuelEntriesProvider('v1'));

    final after = await container.read(economyPointsProvider('v1').future);
    expect(after.single.litersPer100Km, closeTo(5.0, 0.0001));
  });
}
