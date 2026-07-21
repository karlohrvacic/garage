import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/domain/entities/household.dart';
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
}

ProviderContainer containerWith(FakeHouseholdRepository fake) {
  final container = ProviderContainer(
    overrides: [
      householdRepositoryProvider.overrideWithValue(fake),
      currentUserProvider.overrideWithValue(_fakeUser),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
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
}
