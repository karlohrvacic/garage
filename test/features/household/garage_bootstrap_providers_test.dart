import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/household/data/garage_bootstrap_cache.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hrvacic = Household(id: 'h1', name: 'Hrvačić');
const _radionica = Household(id: 'h2', name: 'Radionica');

Vehicle _vehicle(
  String id, {
  String householdId = 'h1',
  bool archived = false,
}) {
  return Vehicle(
    id: id,
    householdId: householdId,
    nickname: id,
    fuelTypeKey: 'fuel_diesel',
    baselineOdometerKm: 1,
    baselineDate: DateTime.utc(2026, 1, 1),
    archived: archived,
  );
}

/// Counts its calls: the whole point of the change is that startup makes one
/// request, so a test that did not count could not tell the difference.
class CountingBootstrapRepository implements GarageBootstrapRepository {
  CountingBootstrapRepository(this.bootstrap);

  final GarageBootstrap bootstrap;
  int loads = 0;

  @override
  Future<GarageBootstrap> load() async {
    loads++;
    return bootstrap;
  }
}

ProviderContainer containerWith(
  CountingBootstrapRepository repository, {
  String? userId = 'u1',
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      // The startup cache reads the device's preferences, which hang in
      // a test with no mock values set.
      garageBootstrapCacheProvider.overrideWithValue(
        const NoGarageBootstrapCache(),
      ),
      garageBootstrapRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // The chosen-garage preference is read through SharedPreferences the moment
  // anything asks for the current household.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the households come out of the single bootstrap fetch', () async {
    final repository = CountingBootstrapRepository(
      GarageBootstrap(
        households: const [_hrvacic, _radionica],
        vehiclesByHousehold: const {},
      ),
    );
    final container = containerWith(repository);

    expect(
      (await container.read(myHouseholdsProvider.future)).map((it) => it.id),
      ['h1', 'h2'],
    );
    expect(repository.loads, 1);
  });

  test('the vehicles come out of the same fetch, not a second one', () async {
    final repository = CountingBootstrapRepository(
      GarageBootstrap(
        households: const [_hrvacic],
        vehiclesByHousehold: {
          'h1': [_vehicle('v1'), _vehicle('v2')],
        },
      ),
    );
    final container = containerWith(repository);

    final vehicles = await container.read(allVehiclesProvider.future);

    expect(vehicles.map((it) => it.id), ['v1', 'v2']);
    expect(
      repository.loads,
      1,
      reason: 'households and vehicles must cost one round trip between them',
    );
  });

  test('only the current garage\'s vehicles are shown', () async {
    final repository = CountingBootstrapRepository(
      GarageBootstrap(
        households: const [_hrvacic, _radionica],
        vehiclesByHousehold: {
          'h1': [_vehicle('v1')],
          'h2': [_vehicle('v2', householdId: 'h2')],
        },
      ),
    );
    final container = containerWith(repository);

    expect(
      (await container.read(allVehiclesProvider.future)).map((it) => it.id),
      ['v1'],
    );
  });

  test('archived vehicles are carried but kept off the active list', () async {
    final repository = CountingBootstrapRepository(
      GarageBootstrap(
        households: const [_hrvacic],
        vehiclesByHousehold: {
          'h1': [_vehicle('v1'), _vehicle('v2', archived: true)],
        },
      ),
    );
    final container = containerWith(repository);

    expect((await container.read(vehiclesProvider.future)).map((it) => it.id), [
      'v1',
    ]);
    expect(
      (await container.read(
        archivedVehiclesProvider.future,
      )).map((it) => it.id),
      ['v2'],
    );
    expect(repository.loads, 1);
  });

  test('signed out fetches nothing at all', () async {
    final repository = CountingBootstrapRepository(GarageBootstrap.empty);
    final container = containerWith(repository, userId: null);

    expect(await container.read(myHouseholdsProvider.future), isEmpty);
    expect(await container.read(allVehiclesProvider.future), isEmpty);
    expect(
      repository.loads,
      0,
      reason: 'a signed-out app has nobody to fetch a garage for',
    );
  });

  test('invalidating the bootstrap is what refetches the vehicles', () async {
    final repository = CountingBootstrapRepository(
      GarageBootstrap(
        households: const [_hrvacic],
        vehiclesByHousehold: {
          'h1': [_vehicle('v1')],
        },
      ),
    );
    final container = containerWith(repository);

    await container.read(allVehiclesProvider.future);
    container.invalidate(garageBootstrapProvider);
    await container.read(allVehiclesProvider.future);

    expect(repository.loads, 2);
  });
}
