import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/providers/fuel_providers.dart';

class FakeFuelRepository implements FuelRepository {
  FakeFuelRepository(this.entries);

  List<FuelEntry> entries;

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async => entries;

  @override
  Future<void> add(FuelEntry entry) async => entries = [...entries, entry];

  @override
  Future<void> update(FuelEntry entry) async {}

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
    overrides: [fuelRepositoryProvider.overrideWithValue(fake)],
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

  test('the latest odometer reading is exposed for validation', () async {
    final container = containerWith(
      FakeFuelRepository([fill('1', 1000, 40), fill('2', 1500, 35)]),
    );

    expect(await container.read(latestOdometerProvider('v1').future), 1500);
  });
}
