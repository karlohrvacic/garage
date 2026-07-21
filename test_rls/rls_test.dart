@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

/// Two users, two households, no overlap. Every assertion here is a claim the
/// Flutter app relies on but cannot enforce: Postgres is the only thing
/// standing between household A and household B.
void main() {
  final url = Platform.environment['SUPABASE_URL'] ?? 'http://127.0.0.1:54321';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY'];

  if (anonKey == null || anonKey.isEmpty) {
    throw StateError(
      'Set SUPABASE_ANON_KEY (see `supabase status`) before running these tests.',
    );
  }

  late SupabaseClient alice;
  late SupabaseClient bob;
  late String aliceHousehold;
  late String aliceVehicle;

  Future<SupabaseClient> signUp(String email) async {
    // Implicit flow: PKCE needs async storage this headless client has none of.
    final client = SupabaseClient(
      url,
      anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    await client.auth.signUp(email: email, password: 'test-password-123');
    return client;
  }

  setUpAll(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    alice = await signUp('alice-$stamp@example.com');
    bob = await signUp('bob-$stamp@example.com');

    aliceHousehold = await alice.rpc(
      'create_household',
      params: {'household_name': "Alice's garage"},
    ) as String;

    await bob.rpc('create_household', params: {'household_name': "Bob's garage"});

    final vehicle = await alice
        .from('vehicles')
        .insert({
          'household_id': aliceHousehold,
          'nickname': 'Golf',
          'fuel_type_key': 'fuel_diesel',
          'created_by': alice.auth.currentUser!.id,
        })
        .select()
        .single();
    aliceVehicle = vehicle['id'] as String;

    await alice.from('fuel_entries').insert({
      'vehicle_id': aliceVehicle,
      'entry_date': '2026-07-01',
      'odometer_km': 50000,
      'volume_l': 45.2,
      'total': 72.30,
      'full_tank': true,
      'created_by': alice.auth.currentUser!.id,
    });
  });

  tearDownAll(() async {
    await alice.dispose();
    await bob.dispose();
  });

  test('the creator is a member of the household they created', () async {
    final rows = await alice.from('households').select();

    expect(rows, hasLength(1));
    expect(rows.single['id'], aliceHousehold);
  });

  test('a stranger cannot read another household', () async {
    final rows =
        await bob.from('households').select().eq('id', aliceHousehold);

    expect(rows, isEmpty);
  });

  test('a stranger cannot read another household vehicles', () async {
    final rows = await bob.from('vehicles').select();

    expect(rows.where((r) => r['id'] == aliceVehicle), isEmpty);
  });

  test('a stranger cannot read another household fuel entries', () async {
    final rows = await bob.from('fuel_entries').select();

    expect(rows, isEmpty);
  });

  test('a stranger cannot write into another household', () async {
    await expectLater(
      bob.from('vehicles').insert({
        'household_id': aliceHousehold,
        'nickname': 'Trojan',
        'fuel_type_key': 'fuel_petrol',
        'created_by': bob.auth.currentUser!.id,
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a stranger cannot log fuel against another household vehicle', () async {
    await expectLater(
      bob.from('fuel_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-02',
        'odometer_km': 51000,
        'volume_l': 40,
        'full_tank': true,
        'created_by': bob.auth.currentUser!.id,
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a stranger cannot delete another household vehicle', () async {
    await bob.from('vehicles').delete().eq('id', aliceVehicle);

    final stillThere =
        await alice.from('vehicles').select().eq('id', aliceVehicle);
    expect(stillThere, hasLength(1), reason: 'delete must not have matched');
  });

  test('a stranger cannot mint an invite for another household', () async {
    await expectLater(
      bob.rpc('create_invite', params: {'target_household': aliceHousehold}),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a valid invite code grants access, and only then', () async {
    final before = await bob.from('vehicles').select();
    expect(before.where((r) => r['id'] == aliceVehicle), isEmpty);

    final code = await alice.rpc(
      'create_invite',
      params: {'target_household': aliceHousehold},
    ) as String;
    await bob.rpc('join_household_with_code', params: {'invite_code': code});

    final after = await bob.from('vehicles').select();
    expect(after.where((r) => r['id'] == aliceVehicle), hasLength(1));
  });

  test('an invite code cannot be redeemed twice', () async {
    final code = await alice.rpc(
      'create_invite',
      params: {'target_household': aliceHousehold},
    ) as String;
    await bob.rpc('join_household_with_code', params: {'invite_code': code});

    await expectLater(
      bob.rpc('join_household_with_code', params: {'invite_code': code}),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('an unknown invite code is rejected', () async {
    await expectLater(
      bob.rpc('join_household_with_code', params: {'invite_code': 'ZZZZZZZZ'}),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('built-in service presets are readable by everyone', () async {
    final rows = await bob.from('service_types').select().isFilter(
          'household_id',
          null,
        );

    expect(rows.length, 18);
  });

  test('built-in service presets are not writable', () async {
    await expectLater(
      bob.from('service_types').insert({
        'household_id': null,
        'key': 'service_malicious',
      }),
      throwsA(isA<PostgrestException>()),
    );
  });
}
