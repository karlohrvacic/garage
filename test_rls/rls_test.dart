@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:test/test.dart';

/// Three users, three households, no overlap. Every assertion here is a claim
/// the Flutter app relies on but cannot enforce: Postgres is the only thing
/// standing between household A and household B.
///
/// Alice owns the household under test. Bob is the *invitee*: the invite tests
/// deliberately make him a member, so anything he can reach afterwards proves
/// nothing about isolation. Carol never joins anything and never is invited —
/// she is the stranger every "cannot" below is measured against, which is what
/// keeps these tests honest no matter what order they run in.
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
  late SupabaseClient carol;
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
    carol = await signUp('carol-$stamp@example.com');

    aliceHousehold =
        await alice.rpc(
              'create_household',
              params: {'household_name': "Alice's garage"},
            )
            as String;

    await bob.rpc(
      'create_household',
      params: {'household_name': "Bob's garage"},
    );

    await carol.rpc(
      'create_household',
      params: {'household_name': "Carol's garage"},
    );

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
    await carol.dispose();
  });

  test('the creator is a member of the household they created', () async {
    final rows = await alice.from('households').select();

    expect(rows, hasLength(1));
    expect(rows.single['id'], aliceHousehold);
  });

  test('a stranger cannot read another household', () async {
    final rows = await carol
        .from('households')
        .select()
        .eq('id', aliceHousehold);

    expect(rows, isEmpty);
  });

  test('a stranger cannot read another household vehicles', () async {
    final rows = await carol.from('vehicles').select();

    expect(rows.where((r) => r['id'] == aliceVehicle), isEmpty);
  });

  test('a stranger cannot read another household fuel entries', () async {
    final rows = await carol.from('fuel_entries').select();

    expect(rows, isEmpty);
  });

  test('a stranger cannot read another household cost entries', () async {
    final rows = await carol.from('cost_entries').select();

    expect(rows, isEmpty);
  });

  test(
    'a stranger cannot log a cost against another household vehicle',
    () async {
      await expectLater(
        carol.from('cost_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-02',
          'category': 'parking',
          'amount': 5,
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test('a stranger cannot write into another household', () async {
    await expectLater(
      carol.from('vehicles').insert({
        'household_id': aliceHousehold,
        'nickname': 'Trojan',
        'fuel_type_key': 'fuel_petrol',
        'created_by': carol.auth.currentUser!.id,
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'a stranger cannot log fuel against another household vehicle',
    () async {
      await expectLater(
        carol.from('fuel_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-02',
          'odometer_km': 51000,
          'volume_l': 40,
          'full_tank': true,
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    },
  );

  test('a stranger cannot delete another household vehicle', () async {
    await carol.from('vehicles').delete().eq('id', aliceVehicle);

    final stillThere = await alice
        .from('vehicles')
        .select()
        .eq('id', aliceVehicle);
    expect(stillThere, hasLength(1), reason: 'delete must not have matched');
  });

  test('a stranger cannot mint an invite for another household', () async {
    await expectLater(
      carol.rpc('create_invite', params: {'target_household': aliceHousehold}),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a valid invite code grants access, and only then', () async {
    final before = await bob.from('vehicles').select();
    expect(before.where((r) => r['id'] == aliceVehicle), isEmpty);

    final code =
        await alice.rpc(
              'create_invite',
              params: {'target_household': aliceHousehold},
            )
            as String;
    await bob.rpc('join_household_with_code', params: {'invite_code': code});

    final after = await bob.from('vehicles').select();
    expect(after.where((r) => r['id'] == aliceVehicle), hasLength(1));
  });

  test('a code that let someone in cannot be used again', () async {
    // A fresh account, because the rule below is about a join that actually
    // adds a member. Bob is already one by now and would not consume anything.
    final dave = await signUp(
      'dave-${DateTime.now().microsecondsSinceEpoch}@example.com',
    );
    addTearDown(dave.dispose);

    final code =
        await alice.rpc(
              'create_invite',
              params: {'target_household': aliceHousehold},
            )
            as String;
    await dave.rpc('join_household_with_code', params: {'invite_code': code});

    await expectLater(
      dave.rpc('join_household_with_code', params: {'invite_code': code}),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a code re-entered by a member it already added is not burned', () async {
    // Migration 0010: a join that adds nobody must leave the code usable, or a
    // member re-entering their own code silently spends the household's invite.
    Future<String> mintCode() async =>
        await alice.rpc(
              'create_invite',
              params: {'target_household': aliceHousehold},
            )
            as String;

    // Whatever ran before, this makes Bob a member — the precondition the rule
    // is about — without depending on another test having done it.
    await bob.rpc(
      'join_household_with_code',
      params: {'invite_code': await mintCode()},
    );

    final code = await mintCode();
    await bob.rpc('join_household_with_code', params: {'invite_code': code});

    final invite = await alice
        .from('invites')
        .select('redeemed_at')
        .eq('code', code)
        .single();
    expect(invite['redeemed_at'], isNull, reason: 'the code must still work');
  });

  test('an unknown invite code is rejected', () async {
    await expectLater(
      bob.rpc('join_household_with_code', params: {'invite_code': 'ZZZZZZZZ'}),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('built-in service presets are readable by everyone', () async {
    final rows = await carol
        .from('service_types')
        .select()
        .isFilter('household_id', null);

    // Not a count: every migration that adds a preset would have to edit it,
    // and the claim being tested is readability, not how many there are.
    expect(rows, isNotEmpty);
    expect(
      rows.map((r) => r['key']),
      containsAll(['service_oil_change', 'service_issue']),
      reason: 'presets from the first migration and the latest one alike',
    );
  });

  test('built-in service presets are not writable', () async {
    await expectLater(
      carol.from('service_types').insert({
        'household_id': null,
        'key': 'service_malicious',
      }),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('created_by cannot be rewritten on update', () async {
    final aliceId = alice.auth.currentUser!.id;
    final bobId = bob.auth.currentUser!.id;

    // Alice owns the vehicle; she tries to reassign its authorship to Bob.
    await alice
        .from('vehicles')
        .update({'created_by': bobId})
        .eq('id', aliceVehicle);

    final row = await alice
        .from('vehicles')
        .select('created_by')
        .eq('id', aliceVehicle)
        .single();
    expect(row['created_by'], aliceId, reason: 'attribution must be pinned');
  });

  group('attachments', () {
    test('a stranger cannot read what hangs off another household', () async {
      await alice.from('attachments').insert({
        'vehicle_id': aliceVehicle,
        'entry_kind': 'fuel',
        'entry_id': aliceVehicle, // any uuid; the policy keys on the vehicle
        'storage_path': '$aliceVehicle/receipt.jpg',
        'file_name': 'receipt.jpg',
        'created_by': alice.auth.currentUser!.id,
      });

      final rows = await carol.from('attachments').select();

      expect(rows, isEmpty);
    });

    test('a stranger cannot attach anything to another household', () async {
      await expectLater(
        carol.from('attachments').insert({
          'vehicle_id': aliceVehicle,
          'entry_kind': 'fuel',
          'entry_id': aliceVehicle,
          'storage_path': '$aliceVehicle/planted.jpg',
          'file_name': 'planted.jpg',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    // Without this, a policy that denied everyone would pass the two above.
    test('a member of the household can see and add one', () async {
      await bob.from('attachments').insert({
        'vehicle_id': aliceVehicle,
        'entry_kind': 'service',
        'entry_id': aliceVehicle,
        'storage_path': '$aliceVehicle/invoice.pdf',
        'file_name': 'invoice.pdf',
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob.from('attachments').select();

      expect(rows, isNotEmpty, reason: 'sharing is the point of a household');
      expect(rows.map((r) => r['file_name']), contains('invoice.pdf'));
    });
  });

  group('api keys and webhooks', () {
    // key_hash is globally unique and hex-64. A fixed literal would pass once
    // and then collide with itself on the next run against the same database.
    String freshHash() => DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(64, 'f');

    test('a stranger cannot read another household keys', () async {
      await alice.from('api_keys').insert({
        'household_id': aliceHousehold,
        'name': 'Home Assistant',
        'key_hash': freshHash(),
        'key_preview': '…mnop',
        'created_by': alice.auth.currentUser!.id,
      });

      final rows = await carol.from('api_keys').select();

      expect(rows, isEmpty, reason: 'a key is a credential for one household');
    });

    test('a stranger cannot mint a key for another household', () async {
      await expectLater(
        carol.from('api_keys').insert({
          'household_id': aliceHousehold,
          'name': 'Backdoor',
          'key_hash': freshHash(),
          'key_preview': '…evil',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a stranger cannot point another household data at a URL', () async {
      await expectLater(
        carol.from('webhooks').insert({
          'household_id': aliceHousehold,
          'url': 'https://attacker.example/collect',
          'secret': 'nope',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a member of the household can mint and read a key', () async {
      final hash = freshHash();
      await bob.from('api_keys').insert({
        'household_id': aliceHousehold,
        'name': 'Bob dashboard',
        'key_hash': hash,
        'key_preview': '…bobs',
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob
          .from('api_keys')
          .select('key_hash')
          .eq('household_id', aliceHousehold);

      expect(rows.map((r) => r['key_hash']), contains(hash));
    });
  });

  group('tyre sets', () {
    test('a stranger cannot read another household sets', () async {
      await alice.from('tyre_sets').insert({
        'vehicle_id': aliceVehicle,
        'name': 'Winter',
        'season': 'winter',
        'created_by': alice.auth.currentUser!.id,
      });

      expect(await carol.from('tyre_sets').select(), isEmpty);
    });

    test('a stranger cannot add a set to another household vehicle', () async {
      await expectLater(
        carol.from('tyre_sets').insert({
          'vehicle_id': aliceVehicle,
          'name': 'Planted',
          'season': 'summer',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a member of the household can add and read a set', () async {
      await bob.from('tyre_sets').insert({
        'vehicle_id': aliceVehicle,
        'name': 'Bob spares',
        'season': 'all_season',
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob.from('tyre_sets').select('name');

      expect(rows.map((r) => r['name']), contains('Bob spares'));
    });

    test('one vehicle cannot have two sets fitted at once', () async {
      final first = await alice
          .from('tyre_sets')
          .insert({
            'vehicle_id': aliceVehicle,
            'name': 'Summer A',
            'season': 'summer',
            'fitted': true,
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();

      await expectLater(
        alice.from('tyre_sets').insert({
          'vehicle_id': aliceVehicle,
          'name': 'Summer B',
          'season': 'summer',
          'fitted': true,
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'a car wears one set at a time',
      );

      await alice.from('tyre_sets').delete().eq('id', first['id'] as String);
    });
  });

  group('admin-only actions', () {
    test('the household creator is its admin', () async {
      final row = await alice
          .from('household_members')
          .select('role')
          .eq('household_id', aliceHousehold)
          .eq('user_id', alice.auth.currentUser!.id)
          .single();

      expect(row['role'], 'admin');
    });

    test('someone who joined by code is a member, not an admin', () async {
      final row = await alice
          .from('household_members')
          .select('role')
          .eq('household_id', aliceHousehold)
          .eq('user_id', bob.auth.currentUser!.id)
          .single();

      expect(row['role'], 'member', reason: 'an invite must not grant admin');
    });

    test('a stranger cannot remove another household member', () async {
      final before = await alice
          .from('household_members')
          .select()
          .eq('household_id', aliceHousehold);

      await carol
          .from('household_members')
          .delete()
          .eq('household_id', aliceHousehold);

      final after = await alice
          .from('household_members')
          .select()
          .eq('household_id', aliceHousehold);

      expect(
        after,
        hasLength(before.length),
        reason: 'every membership must survive',
      );
    });
  });

  group('invite codes', () {
    test('a stranger cannot list another household codes', () async {
      await alice.rpc(
        'create_invite',
        params: {'target_household': aliceHousehold},
      );

      final rows = await carol.from('invites').select();

      expect(
        rows.where((row) => row['household_id'] == aliceHousehold),
        isEmpty,
        reason: 'listing codes would be enumerating ways into the household',
      );
    });

    test('a member can list the codes their household issued', () async {
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;

      final rows = await bob
          .from('invites')
          .select('code')
          .eq('household_id', aliceHousehold);

      expect(rows.map((row) => row['code']), contains(code));
    });

    test('a stranger cannot revoke a code', () async {
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;

      await carol.from('invites').delete().eq('code', code);

      final rows = await alice.from('invites').select().eq('code', code);
      expect(rows, hasLength(1), reason: 'the code must survive');
    });

    test('a member can revoke a code, and it stops working', () async {
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;

      await alice.from('invites').delete().eq('code', code);

      await expectLater(
        carol.rpc('join_household_with_code', params: {'invite_code': code}),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

  group('recurring reminder rules', () {
    // Migration 0014 made the per-type uniqueness a *partial* index, so
    // `on conflict (vehicle_id, service_type_key)` no longer resolves and fails
    // with 42P10. That is what stopped a Fuelio import halfway through, after
    // it had already written the fill-ups. These pin the strategy that replaced
    // it: update first, insert only when nothing matched.
    Future<void> upsertRecurring({required int intervalKm}) async {
      final updated = await alice
          .from('reminder_rules')
          .update({'interval_km': intervalKm})
          .eq('vehicle_id', aliceVehicle)
          .eq('service_type_key', 'service_oil_change')
          .eq('one_time', false)
          .select('id');
      if (updated.isEmpty) {
        await alice.from('reminder_rules').insert({
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_oil_change',
          'interval_km': intervalKm,
          'active': true,
        });
      }
    }

    test(
      'importing the same rule twice updates it rather than failing',
      () async {
        await upsertRecurring(intervalKm: 15000);
        await upsertRecurring(intervalKm: 30000);

        final rows = await alice
            .from('reminder_rules')
            .select('interval_km')
            .eq('vehicle_id', aliceVehicle)
            .eq('service_type_key', 'service_oil_change')
            .eq('one_time', false);

        expect(rows, hasLength(1), reason: 'one recurring rule per type');
        expect(rows.single['interval_km'], 30000);
      },
    );

    test(
      'the schema still refuses a second recurring rule of a type',
      () async {
        await expectLater(
          alice.from('reminder_rules').insert({
            'vehicle_id': aliceVehicle,
            'service_type_key': 'service_oil_change',
            'interval_km': 9000,
            'active': true,
          }),
          throwsA(isA<PostgrestException>()),
          reason: 'the partial index is what makes update-then-insert safe',
        );
      },
    );

    test('one-off rules of the same type may coexist', () async {
      for (final due in ['2030-01-01', '2030-06-01']) {
        await alice.from('reminder_rules').insert({
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_tire_swap_seasonal',
          'one_time': true,
          'due_date': due,
          'active': true,
        });
      }

      final rows = await alice
          .from('reminder_rules')
          .select('id')
          .eq('vehicle_id', aliceVehicle)
          .eq('service_type_key', 'service_tire_swap_seasonal')
          .eq('one_time', true);

      expect(rows, hasLength(2), reason: 'two dated tyre swaps are legitimate');
    });
  });
}
