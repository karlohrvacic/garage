import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/domain/entities/vehicle_transfer.dart';
import 'package:garage/features/vehicles/data/vehicle_repository.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';

class FakeVehicleRepository implements VehicleRepository {
  @override
  Future<List<VehicleTransfer>> transfersOffered(String householdId) async =>
      const [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> cancelTransfer(String vehicleId) async {}

  @override
  Future<String?> outstandingTransferCode(String vehicleId) async => null;

  FakeVehicleRepository(this.vehicles);

  List<Vehicle> vehicles;
  final List<String> calls = [];

  @override
  Future<List<Vehicle>> forHousehold(String householdId) async {
    calls.add('forHousehold:$householdId');
    return vehicles;
  }

  @override
  Future<Vehicle> create(Vehicle vehicle) async {
    calls.add('create:${vehicle.nickname}');
    vehicles = [...vehicles, vehicle];
    return vehicle;
  }

  @override
  Future<void> update(Vehicle vehicle) async =>
      calls.add('update:${vehicle.id}');

  @override
  Future<void> setArchived(String id, bool archived) async =>
      calls.add('archive:$id:$archived');

  @override
  Future<void> deleteAllForHousehold(String householdId) async =>
      calls.add('deleteAll:$householdId');

  @override
  Future<String> offerTransfer(String vehicleId) async {
    calls.add('offerTransfer:$vehicleId');
    return 'TRANSFER';
  }

  @override
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  }) async {
    calls.add('redeemTransfer:$code:$householdId');
    return 'v1';
  }
}

Vehicle vehicle(String id, String nickname, {bool archived = false}) {
  return Vehicle(
    id: id,
    householdId: 'h1',
    nickname: nickname,
    fuelTypeKey: 'fuel_petrol',
    baselineOdometerKm: 0,
    baselineDate: DateTime.utc(2026, 1, 1),
    archived: archived,
  );
}

/// The vehicles arrive with the households now, in startup's one fetch, so
/// this is the seam these providers read through.
class FakeBootstrapRepository implements GarageBootstrapRepository {
  FakeBootstrapRepository(this.vehicles);

  final List<Vehicle> vehicles;

  @override
  Future<GarageBootstrap> load() async {
    return GarageBootstrap(
      households: const [Household(id: 'h1', name: 'Test')],
      vehiclesByHousehold: {
        'h1': [...vehicles]
          ..sort(
            (a, b) =>
                a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
          ),
      },
    );
  }
}

ProviderContainer containerWith(List<Vehicle> vehicles) {
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue('u1'),
      garageBootstrapRepositoryProvider.overrideWithValue(
        FakeBootstrapRepository(vehicles),
      ),
      currentHouseholdProvider.overrideWith(
        (ref) async => const Household(id: 'h1', name: 'Test'),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('active vehicles come back sorted by name', () async {
    final container = containerWith([
      vehicle('2', 'Zastava'),
      vehicle('1', 'Alfa'),
    ]);

    final vehicles = await container.read(vehiclesProvider.future);

    expect(vehicles.map((v) => v.nickname), ['Alfa', 'Zastava']);
  });

  test('archived vehicles are excluded from the active list', () async {
    final container = containerWith([
      vehicle('1', 'Daily'),
      vehicle('2', 'Old banger', archived: true),
    ]);

    final vehicles = await container.read(vehiclesProvider.future);

    expect(vehicles.map((v) => v.nickname), ['Daily']);
  });

  test('archived vehicles are available in their own list', () async {
    final container = containerWith([
      vehicle('1', 'Daily'),
      vehicle('2', 'Old banger', archived: true),
    ]);

    final archived = await container.read(archivedVehiclesProvider.future);

    expect(archived.map((v) => v.nickname), ['Old banger']);
  });

  test('a single vehicle is addressable by id', () async {
    final container = containerWith([vehicle('1', 'Daily')]);

    final found = await container.read(vehicleProvider('1').future);

    expect(found!.nickname, 'Daily');
  });

  test('an unknown vehicle id resolves to null', () async {
    final container = containerWith([vehicle('1', 'Daily')]);

    expect(await container.read(vehicleProvider('nope').future), isNull);
  });
}
