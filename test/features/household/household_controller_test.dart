import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/invite.dart';
import 'package:garage/features/household/data/garage_bootstrap_cache.dart';
import 'package:garage/features/household/data/garage_bootstrap.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A stand-in for a signed-in user. currentHouseholdProvider depends on
/// currentUserProvider (so it refetches on an account switch), so the tests
/// supply one rather than booting a real Supabase client.
final _fakeUser = User(
  id: 'u1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

class FakeHouseholdRepository implements HouseholdRepository {
  @override
  Future<void> deleteHousehold(String householdId) async {}

  FakeHouseholdRepository({this.households = const []});

  List<Household> households;
  final List<String> calls = [];
  Object? throwOnJoin;

  @override
  Future<List<Household>> myHouseholds() async {
    calls.add('myHouseholds');
    return households;
  }

  @override
  Future<String> create(String name) async {
    calls.add('create:$name');
    households = [...households, Household(id: 'h1', name: name)];
    return 'h1';
  }

  @override
  Future<String> joinWithCode(String code) async {
    calls.add('join:$code');
    if (throwOnJoin != null) {
      throw throwOnJoin!;
    }
    households = [...households, const Household(id: 'h2', name: 'Joined')];
    return 'h2';
  }

  @override
  Future<String> createInvite(String householdId) async {
    calls.add('invite:$householdId');
    return 'ABCD2345';
  }

  @override
  Future<List<Invite>> invites(String householdId) async => const [];

  @override
  Future<void> revokeInvite(String inviteId) async {}

  @override
  Future<List<HouseholdMember>> members(String householdId) async {
    calls.add('members:$householdId');
    return const [];
  }

  @override
  Future<void> leave(String householdId) async =>
      calls.add('leave:$householdId');

  @override
  Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {}

  @override
  Future<void> updateSettings(Household household) async =>
      calls.add('updateSettings:${household.id}');

  @override
  Future<void> setRole({
    required String householdId,
    required String userId,
    required String role,
  }) async => calls.add('setRole:$userId:$role');

  @override
  Future<MergeOutcome> merge({
    required String absorbedHouseholdId,
    required String survivingHouseholdId,
  }) async {
    calls.add('merge:$absorbedHouseholdId->$survivingHouseholdId');
    return const MergeOutcome(
      vehiclesMoved: 0,
      membersMoved: 0,
      keysRevoked: 0,
    );
  }
}

/// Startup fetches the garages, so the controller's refresh is now a rebuild
/// of the bootstrap rather than of a households-only call. It reads the fake's
/// list on each load rather than a copy, which is what makes a garage created
/// or joined mid-test show up in the refetch.
class FakeBootstrapRepository implements GarageBootstrapRepository {
  FakeBootstrapRepository(this.source);

  final FakeHouseholdRepository source;

  @override
  Future<GarageBootstrap> load() async {
    source.calls.add('myHouseholds');
    return GarageBootstrap(
      households: source.households,
      vehiclesByHousehold: const {},
    );
  }
}

ProviderContainer containerWith(FakeHouseholdRepository fake) {
  final container = ProviderContainer(
    overrides: [
      householdRepositoryProvider.overrideWithValue(fake),
      // The startup cache reads the device's preferences, which hang in
      // a test with no mock values set.
      garageBootstrapCacheProvider.overrideWithValue(
        const NoGarageBootstrapCache(),
      ),
      garageBootstrapRepositoryProvider.overrideWithValue(
        FakeBootstrapRepository(fake),
      ),
      currentUserProvider.overrideWithValue(_fakeUser),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // Which garage this device is showing is a stored preference, so the
  // provider that reads it needs a store even in a test that never switches.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a user with no household resolves to null', () async {
    final container = containerWith(FakeHouseholdRepository());

    final household = await container.read(currentHouseholdProvider.future);

    expect(household, isNull);
  });

  test('a user with a household resolves to it', () async {
    final container = containerWith(
      FakeHouseholdRepository(
        households: const [Household(id: 'h1', name: 'Hrvačić')],
      ),
    );

    final household = await container.read(currentHouseholdProvider.future);

    expect(household!.name, 'Hrvačić');
  });

  test('creating a household refreshes the current household', () async {
    final fake = FakeHouseholdRepository();
    final container = containerWith(fake);
    await container.read(currentHouseholdProvider.future);

    await container
        .read(householdControllerProvider.notifier)
        .createHousehold('Hrvačić');

    expect(fake.calls, contains('create:Hrvačić'));
    final household = await container.read(currentHouseholdProvider.future);
    expect(household!.name, 'Hrvačić');
  });

  test('an invalid code leaves a mapped failure in the controller', () async {
    final fake = FakeHouseholdRepository()
      ..throwOnJoin = const AppFailure(kind: AppFailureKind.notFound);
    final container = containerWith(fake);

    await container
        .read(householdControllerProvider.notifier)
        .joinHousehold('ZZZZZZZZ');

    final state = container.read(householdControllerProvider);
    expect(state.hasError, isTrue);
    expect((state.error! as AppFailure).kind, AppFailureKind.notFound);
  });

  test('codes are normalised to upper case before being sent', () async {
    final fake = FakeHouseholdRepository();
    final container = containerWith(fake);

    await container
        .read(householdControllerProvider.notifier)
        .joinHousehold(' abcd2345 ');

    expect(fake.calls, contains('join:ABCD2345'));
  });

  test('joining a second garage makes it the one being shown', () async {
    // The schema always permitted several memberships; until now every screen
    // read whichever came back first, so a second one was invisible.
    final fake = FakeHouseholdRepository(
      households: const [Household(id: 'h1', name: 'Family')],
    );
    final container = containerWith(fake);
    await container.read(currentHouseholdProvider.future);

    await container
        .read(householdControllerProvider.notifier)
        .joinHousehold('abcd2345');

    expect((await container.read(myHouseholdsProvider.future)), hasLength(2));
    expect((await container.read(currentHouseholdProvider.future))!.id, 'h2');
  });

  test('switching garages changes what every screen reads', () async {
    final fake = FakeHouseholdRepository(
      households: const [
        Household(id: 'h1', name: 'Family'),
        Household(id: 'h2', name: 'Work'),
      ],
    );
    final container = containerWith(fake);
    expect((await container.read(currentHouseholdProvider.future))!.id, 'h1');

    await container.read(householdControllerProvider.notifier).switchTo('h2');

    expect((await container.read(currentHouseholdProvider.future))!.id, 'h2');
  });

  test('the chosen garage outlives a restart', () async {
    final fake = FakeHouseholdRepository(
      households: const [
        Household(id: 'h1', name: 'Family'),
        Household(id: 'h2', name: 'Work'),
      ],
    );
    await containerWith(
      fake,
    ).read(householdControllerProvider.notifier).switchTo('h2');

    final second = containerWith(fake);
    await second.read(selectedHouseholdIdProvider.notifier).loaded;

    expect((await second.read(currentHouseholdProvider.future))!.id, 'h2');
  });
}
