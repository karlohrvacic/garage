import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';
import 'package:garage/features/household/data/garage_bootstrap_cache.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_repositories.dart';
import 'package:flutter_riverpod/legacy.dart';

Map<String, dynamic> householdRow(String id, String name) => {
  'id': id,
  'name': name,
  'distance_unit': 'km',
  'volume_unit': 'l',
  'currency_code': 'EUR',
  'bundling_window_days': 14,
  'bundling_window_km': 500,
};

Map<String, dynamic> vehicleRow(String id, {String household = 'h1'}) => {
  'id': id,
  'household_id': household,
  'nickname': id,
  'fuel_type_key': 'fuel_diesel',
  'baseline_odometer_km': 1,
  'baseline_date': '2026-01-01',
  'archived': false,
};

class SlowRepository implements GarageBootstrapRepository {
  SlowRepository(this.result, {this.failWith});

  final GarageBootstrap result;
  final Object? failWith;
  int loads = 0;

  @override
  Future<GarageBootstrap> load() async {
    loads++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (failWith case final error?) {
      throw error;
    }
    return result;
  }
}

final fetched = GarageBootstrap(
  households: const [Household(id: 'h1', name: 'From the network')],
  vehiclesByHousehold: const {},
);

final cached = GarageBootstrap(
  households: const [Household(id: 'h1', name: 'From last time')],
  vehiclesByHousehold: const {},
);

ProviderContainer containerWith(
  GarageBootstrapRepository repository,
  GarageBootstrapCache cache, {
  String? userId = 'u1',
}) {
  final container = ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      garageBootstrapCacheProvider.overrideWithValue(cache),
      garageBootstrapRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('what a cold start draws', () {
    test(
      'the garage this device saw last, before the network answers',
      () async {
        // The whole point: a dashboard drawn from something true a moment ago
        // beats a spinner drawn from nothing.
        final repository = SlowRepository(fetched);
        final container = containerWith(
          repository,
          FakeBootstrapCache(cached: cached),
        );

        final first = await container.read(garageBootstrapProvider.future);

        expect(first.households.single.name, 'From last time');
      },
    );

    test('and then the network, without anybody waiting for it', () async {
      final repository = SlowRepository(fetched);
      final container = containerWith(
        repository,
        FakeBootstrapCache(cached: cached),
      );

      await container.read(garageBootstrapProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container
            .read(garageBootstrapProvider)
            .requireValue
            .households
            .single
            .name,
        'From the network',
      );
      expect(repository.loads, 1);
    });

    test(
      'a refresh that fails leaves the cached garage on the screen',
      () async {
        // An offline cold start is the ordinary case. Replacing a garage that is
        // right with an error page would be a downgrade on the one occasion the
        // cache is worth the most.
        final repository = SlowRepository(
          fetched,
          failWith: const AppFailure(kind: AppFailureKind.network),
        );
        final container = containerWith(
          repository,
          FakeBootstrapCache(cached: cached),
        );

        await container.read(garageBootstrapProvider.future);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        final state = container.read(garageBootstrapProvider);
        expect(state.hasError, isFalse);
        expect(state.requireValue.households.single.name, 'From last time');
      },
    );

    test('with no cache it waits for the fetch, as it always did', () async {
      final repository = SlowRepository(fetched);
      final container = containerWith(repository, FakeBootstrapCache());

      final bootstrap = await container.read(garageBootstrapProvider.future);

      expect(bootstrap.households.single.name, 'From the network');
      expect(repository.loads, 1);
    });

    test('signed out, nothing is read and nothing is fetched', () async {
      final repository = SlowRepository(fetched);
      final cache = FakeBootstrapCache(cached: cached);
      final container = containerWith(repository, cache, userId: null);

      final bootstrap = await container.read(garageBootstrapProvider.future);

      expect(bootstrap.households, isEmpty);
      expect(repository.loads, 0);
    });
  });

  group('what is kept on the device', () {
    test('a garage written back comes out the same', () async {
      final cache = PrefsGarageBootstrapCache();
      await cache.write(
        'u1',
        households: [householdRow('h1', 'Hrvačić')],
        vehicles: [vehicleRow('v1')],
      );

      final read = await cache.read('u1');

      expect(read!.households.single.name, 'Hrvačić');
      expect(read.vehiclesFor('h1').single.id, 'v1');
    });

    test('another account on the same phone gets nothing', () async {
      // A shared device must not open into the previous person's garage, and
      // "the provider would not show it" is not the same as "it is not there".
      final cache = PrefsGarageBootstrapCache();
      await cache.write(
        'u1',
        households: [householdRow('h1', 'Hrvačić')],
        vehicles: const [],
      );

      expect(await cache.read('u2'), isNull);
    });

    test('a garage from a month ago is not shown as current', () async {
      var now = DateTime.utc(2026, 1, 1);
      final cache = PrefsGarageBootstrapCache(now: () => now);
      await cache.write(
        'u1',
        households: [householdRow('h1', 'Hrvačić')],
        vehicles: const [],
      );

      now = DateTime.utc(2026, 1, 1).add(bootstrapCacheMaxAge);
      expect(await cache.read('u1'), isNotNull);

      now = DateTime.utc(
        2026,
        1,
        1,
      ).add(bootstrapCacheMaxAge + const Duration(days: 1));
      expect(await cache.read('u1'), isNull);
    });

    test('clearing it means the next start has nothing to draw', () async {
      final cache = PrefsGarageBootstrapCache();
      await cache.write(
        'u1',
        households: [householdRow('h1', 'Hrvačić')],
        vehicles: const [],
      );

      await cache.clear();

      expect(await cache.read('u1'), isNull);
    });

    test('nonsense on disk is treated as no cache at all', () async {
      SharedPreferences.setMockInitialValues({
        'garage.bootstrap.v1': 'not json',
      });

      expect(await PrefsGarageBootstrapCache().read('u1'), isNull);
    });
  });

  group('a refresh that lands late', () {
    test('does not put the previous account back on screen', () async {
      // A shared phone: one person signs out while the background fetch is
      // still in flight. The notifier is still alive, so `ref.mounted` says
      // nothing useful — the question is whether the answer still belongs to
      // the question that was asked.
      final signedIn = StateProvider<String?>((ref) => 'u1');
      final repository = SlowRepository(fetched);
      final cache = FakeBootstrapCache(cached: cached);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(signedIn)),
          garageBootstrapCacheProvider.overrideWithValue(cache),
          garageBootstrapRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(garageBootstrapProvider.future);
      container.read(signedIn.notifier).state = null;
      await container.read(garageBootstrapProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(garageBootstrapProvider).requireValue.households,
        isEmpty,
        reason:
            "signed out is signed out — the previous account's garage must "
            'not arrive afterwards',
      );
    });
  });
}
