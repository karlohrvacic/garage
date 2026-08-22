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

  /// A service-role client, for the one thing a user cannot do to themselves
  /// through the API: the account deletion the edge function performs.
  late SupabaseClient admin;
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
    final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
    if (serviceKey == null || serviceKey.isEmpty) {
      throw StateError(
        'Set SUPABASE_SERVICE_ROLE_KEY (see `supabase status`) as well: the '
        'account-deletion tests exercise what the edge function does.',
      );
    }
    admin = SupabaseClient(url, serviceKey);

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

  // 0008 pinned created_by on vehicles/fuel_entries/service_entries; every
  // table added since that also carries the column needs the same trigger,
  // and it is easy to add a table and forget it — reminder_rules has no
  // created_by column at all, which is why it is not here.
  group('created_by is pinned on every table that carries it', () {
    test('cost entries', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final entry = await alice
          .from('cost_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-01',
            'category': 'parking',
            'amount': 5,
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('cost_entries')
          .update({'created_by': bobId})
          .eq('id', entry['id'] as String);

      final row = await alice
          .from('cost_entries')
          .select('created_by')
          .eq('id', entry['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('tyre sets', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final set = await alice
          .from('tyre_sets')
          .insert({
            'vehicle_id': aliceVehicle,
            'name': 'Provenance check',
            'season': 'summer',
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('tyre_sets')
          .update({'created_by': bobId})
          .eq('id', set['id'] as String);

      final row = await alice
          .from('tyre_sets')
          .select('created_by')
          .eq('id', set['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('trip entries', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final trip = await alice
          .from('trip_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-01',
            'distance_km': 10,
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('trip_entries')
          .update({'created_by': bobId})
          .eq('id', trip['id'] as String);

      final row = await alice
          .from('trip_entries')
          .select('created_by')
          .eq('id', trip['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('income entries', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final income = await alice
          .from('income_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-01',
            'category': 'ride',
            'amount': 5,
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('income_entries')
          .update({'created_by': bobId})
          .eq('id', income['id'] as String);

      final row = await alice
          .from('income_entries')
          .select('created_by')
          .eq('id', income['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('odometer entries', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final reading = await alice
          .from('odometer_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-01',
            'odometer_km': 84100,
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('odometer_entries')
          .update({'created_by': bobId})
          .eq('id', reading['id'] as String);

      final row = await alice
          .from('odometer_entries')
          .select('created_by')
          .eq('id', reading['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('API keys', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final hash = DateTime.now().microsecondsSinceEpoch
          .toRadixString(16)
          .padLeft(64, 'a');
      final key = await alice
          .from('api_keys')
          .insert({
            'household_id': aliceHousehold,
            'name': 'Provenance check',
            'key_hash': hash,
            'key_preview': '…chek',
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('api_keys')
          .update({'created_by': bobId})
          .eq('id', key['id'] as String);

      final row = await alice
          .from('api_keys')
          .select('created_by')
          .eq('id', key['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('webhooks', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final webhook = await alice
          .from('webhooks')
          .insert({
            'household_id': aliceHousehold,
            'url': 'https://example.test/hook',
            'secret': 'sssh',
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('webhooks')
          .update({'created_by': bobId})
          .eq('id', webhook['id'] as String);

      final row = await alice
          .from('webhooks')
          .select('created_by')
          .eq('id', webhook['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });
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

  /// Servicing is the second-biggest thing in the app after fuel, and it was
  /// the last entry kind with policies nobody had pointed a test at.
  group('service entries', () {
    test('a stranger cannot read another household servicing', () async {
      await alice.from('service_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-04',
        'odometer_km': 51000,
        'service_type_keys': ['service_oil_change'],
        'cost': 120.00,
        'shop': 'Alice garage',
        'created_by': alice.auth.currentUser!.id,
      });

      expect(await carol.from('service_entries').select(), isEmpty);
    });

    test(
      'a stranger cannot record servicing on another household car',
      () async {
        await expectLater(
          carol.from('service_entries').insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-05',
            'odometer_km': 51100,
            'service_type_keys': ['service_issue'],
            'created_by': carol.auth.currentUser!.id,
          }),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    // The positive control. Without it every assertion above would still pass
    // if the policies denied the table to everyone, including the household.
    test('a member of the household can record and read servicing', () async {
      await bob.from('service_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-06',
        'odometer_km': 51200,
        'service_type_keys': ['service_brake_pads_front'],
        'shop': 'Bob shop',
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob.from('service_entries').select('shop');

      expect(rows.map((r) => r['shop']), contains('Bob shop'));
    });

    test('a stranger can neither rewrite nor delete it', () async {
      final entry = await alice
          .from('service_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-07',
            'odometer_km': 51300,
            'service_type_keys': ['service_oil_change'],
            'cost': 90.00,
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      final id = entry['id'] as String;

      // Postgres reports a denied update or delete as zero rows affected
      // rather than an error, so the proof is that the row is untouched.
      await carol.from('service_entries').update({'cost': 1}).eq('id', id);
      await carol.from('service_entries').delete().eq('id', id);

      final after = await alice
          .from('service_entries')
          .select('cost')
          .eq('id', id)
          .single();

      expect(double.parse(after['cost'].toString()), 90.00);
    });
  });

  /// Tread depths hang off a tyre set rather than a vehicle, so their policy
  /// reaches through one more join than any other entry kind — which is
  /// exactly the sort of policy worth proving rather than reading.
  group('tyre readings', () {
    late String aliceSet;

    setUpAll(() async {
      final set = await alice
          .from('tyre_sets')
          .insert({
            'vehicle_id': aliceVehicle,
            'name': 'Readings set',
            'season': 'summer',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      aliceSet = set['id'] as String;

      await alice.from('tyre_readings').insert({
        'tyre_set_id': aliceSet,
        'reading_date': '2026-07-01',
        'front_left_mm': 6.5,
        'created_by': alice.auth.currentUser!.id,
      });
    });

    test('a stranger cannot read another household tread depths', () async {
      expect(await carol.from('tyre_readings').select(), isEmpty);
    });

    test('a stranger cannot add a reading to another household set', () async {
      await expectLater(
        carol.from('tyre_readings').insert({
          'tyre_set_id': aliceSet,
          'reading_date': '2026-07-02',
          'front_left_mm': 1.0,
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a member of the household can add and read one', () async {
      await bob.from('tyre_readings').insert({
        'tyre_set_id': aliceSet,
        'reading_date': '2026-07-03',
        'rear_right_mm': 5.5,
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob
          .from('tyre_readings')
          .select('rear_right_mm')
          .eq('tyre_set_id', aliceSet);

      expect(rows.map((r) => r['rear_right_mm']?.toString()), contains('5.5'));
    });
  });

  /// Push tokens are scoped to a *person*, not a household, and that is the
  /// distinction worth pinning: everything else in this schema opens up to
  /// the household, and a token that did the same would let one member push
  /// to another member's phone.
  group('device tokens', () {
    // The token *is* the primary key, and this suite runs against a database
    // that outlives it. A literal here collides with the row the last run
    // left behind — owned by a different user, so RLS refuses the write and
    // the failure reads like a policy bug rather than a test that was only
    // ever going to pass once.
    late String aliceToken;

    setUpAll(() => aliceToken = 'alice-device-${alice.auth.currentUser!.id}');

    test('a token belongs to the person who registered it', () async {
      await alice.from('device_tokens').upsert({
        'token': aliceToken,
        'user_id': alice.auth.currentUser!.id,
        'platform': 'android',
      });

      final rows = await alice.from('device_tokens').select('token');

      expect(rows.map((r) => r['token']), contains(aliceToken));
    });

    test('a fellow household member still cannot read it', () async {
      final rows = await bob.from('device_tokens').select();

      expect(
        rows.where((r) => r['token'] == aliceToken),
        isEmpty,
        reason:
            'Bob is a member of the same garage and can see every car in it. '
            'A push token is not part of that bargain.',
      );
    });

    test('nobody can register a token in somebody else name', () async {
      await expectLater(
        carol.from('device_tokens').insert({
          'token': 'carol-forging-${carol.auth.currentUser!.id}',
          'user_id': alice.auth.currentUser!.id,
          'platform': 'android',
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'otherwise a stranger could redirect somebody else reminders',
      );
    });
  });

  /// The one table that is deliberately *not* private: a garage that cannot
  /// see its members' names cannot show who logged what. The line is drawn at
  /// sharing a household, and this proves it falls in both directions.
  group('profiles', () {
    test('you can read your own', () async {
      final rows = await alice
          .from('profiles')
          .select('display_name')
          .eq('user_id', alice.auth.currentUser!.id);

      expect(rows, hasLength(1));
    });

    test('a fellow member can read yours, which is the point of it', () async {
      final rows = await bob
          .from('profiles')
          .select('display_name')
          .eq('user_id', alice.auth.currentUser!.id);

      expect(
        rows,
        hasLength(1),
        reason:
            'names on entries and on the member list come from here; a policy '
            'that denied this would empty both',
      );
    });

    test('a stranger cannot read yours', () async {
      final rows = await carol
          .from('profiles')
          .select('display_name')
          .eq('user_id', alice.auth.currentUser!.id);

      expect(rows, isEmpty);
    });

    test('nobody can rename anybody else', () async {
      await bob
          .from('profiles')
          .update({'display_name': 'Renamed by Bob'})
          .eq('user_id', alice.auth.currentUser!.id);

      final after = await alice
          .from('profiles')
          .select('display_name')
          .eq('user_id', alice.auth.currentUser!.id)
          .single();

      expect(
        after['display_name'],
        isNot('Renamed by Bob'),
        reason: 'reading a co-member name is not permission to change it',
      );
    });
  });

  group('odometer readings', () {
    test('a stranger cannot read another household readings', () async {
      await alice.from('odometer_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-01',
        'odometer_km': 84000,
        'created_by': alice.auth.currentUser!.id,
      });

      expect(await carol.from('odometer_entries').select(), isEmpty);
    });

    test(
      'a stranger cannot log a reading against another household vehicle',
      () async {
        await expectLater(
          carol.from('odometer_entries').insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-07-01',
            'odometer_km': 999999,
            'created_by': carol.auth.currentUser!.id,
          }),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    // The positive control: a policy that denied everyone would pass every
    // "stranger sees nothing" assertion above.
    test('a member of the household can add and read a reading', () async {
      await bob.from('odometer_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-05',
        'odometer_km': 84500,
        'notes': 'Bob checked',
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob.from('odometer_entries').select('notes');

      expect(rows.map((r) => r['notes']), contains('Bob checked'));
    });
  });

  group('trips and income', () {
    test('a stranger cannot read another household trips', () async {
      await alice.from('trip_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-01',
        'distance_km': 188,
        'purpose': 'business',
        'created_by': alice.auth.currentUser!.id,
      });

      expect(await carol.from('trip_entries').select(), isEmpty);
    });

    test('a stranger cannot read another household income', () async {
      await alice.from('income_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-01',
        'category': 'ride',
        'amount': 25,
        'created_by': alice.auth.currentUser!.id,
      });

      expect(await carol.from('income_entries').select(), isEmpty);
    });

    test('a stranger cannot log either against another household', () async {
      await expectLater(
        carol.from('trip_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-01',
          'distance_km': 1,
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        carol.from('income_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-01',
          'category': 'ride',
          'amount': 1,
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    // The positive control: a policy that denied everyone would pass every
    // "stranger sees nothing" assertion above.
    test('a member can add and read both', () async {
      await bob.from('trip_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-05',
        'title': 'Bob drove',
        'distance_km': 40,
        'purpose': 'private',
        'created_by': bob.auth.currentUser!.id,
      });
      await bob.from('income_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-05',
        'category': 'refund',
        'amount': 12,
        'notes': 'Bob was paid',
        'created_by': bob.auth.currentUser!.id,
      });

      expect(
        (await bob.from('trip_entries').select('title')).map((r) => r['title']),
        contains('Bob drove'),
      );
      expect(
        (await bob.from('income_entries').select('notes')).map(
          (r) => r['notes'],
        ),
        contains('Bob was paid'),
      );
    });

    test('a trip cannot end before it started', () async {
      await expectLater(
        alice.from('trip_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-06',
          'distance_km': 10,
          'start_odometer_km': 90000,
          'end_odometer_km': 89000,
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'a range that runs backwards is a typo, not a journey',
      );
    });
  });

  group('vehicle transfer', () {
    test('a stranger cannot offer somebody else vehicle', () async {
      await expectLater(
        carol.rpc(
          'create_vehicle_transfer',
          params: {'target_vehicle': aliceVehicle},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('an unknown code is refused', () async {
      final carolHousehold =
          await carol.rpc(
                'create_household',
                params: {'household_name': "Carol's garage"},
              )
              as String;

      await expectLater(
        carol.rpc(
          'redeem_vehicle_transfer',
          params: {
            'transfer_code': 'ZZZZZZZZ',
            'target_household': carolHousehold,
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a code cannot be redeemed into a household you are not in', () async {
      final code =
          await alice.rpc(
                'create_vehicle_transfer',
                params: {'target_vehicle': aliceVehicle},
              )
              as String;

      await expectLater(
        carol.rpc(
          'redeem_vehicle_transfer',
          params: {'transfer_code': code, 'target_household': aliceHousehold},
        ),
        throwsA(isA<PostgrestException>()),
        reason: 'the destination has to be a household the caller belongs to',
      );
    });

    test('a code is reused rather than piled up', () async {
      final first =
          await alice.rpc(
                'create_vehicle_transfer',
                params: {'target_vehicle': aliceVehicle},
              )
              as String;
      final second =
          await alice.rpc(
                'create_vehicle_transfer',
                params: {'target_vehicle': aliceVehicle},
              )
              as String;

      expect(second, first);
    });

    // The real thing, end to end. Deliberately last in this group: it moves
    // the vehicle out of Alice's household, so anything after it that assumes
    // she still owns it would fail.
    test('redeeming moves the car and its history, and only once', () async {
      final moved = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': 'For sale',
            'fuel_type_key': 'fuel_petrol',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      final movedId = moved['id'] as String;

      await alice.from('fuel_entries').insert({
        'vehicle_id': movedId,
        'entry_date': '2026-06-01',
        'odometer_km': 1000,
        'volume_l': 40,
        'full_tank': true,
        'created_by': alice.auth.currentUser!.id,
      });

      final carolHousehold =
          await carol.rpc(
                'create_household',
                params: {'household_name': "Carol's second garage"},
              )
              as String;
      final code =
          await alice.rpc(
                'create_vehicle_transfer',
                params: {'target_vehicle': movedId},
              )
              as String;

      await carol.rpc(
        'redeem_vehicle_transfer',
        params: {'transfer_code': code, 'target_household': carolHousehold},
      );

      // The history came with it…
      final carolFuel = await carol
          .from('fuel_entries')
          .select('odometer_km')
          .eq('vehicle_id', movedId);
      expect(carolFuel.map((r) => r['odometer_km']), contains(1000));

      // …and the seller no longer sees the car at all.
      final aliceView = await alice
          .from('vehicles')
          .select('id')
          .eq('id', movedId);
      expect(aliceView, isEmpty);

      await expectLater(
        carol.rpc(
          'redeem_vehicle_transfer',
          params: {'transfer_code': code, 'target_household': carolHousehold},
        ),
        throwsA(isA<PostgrestException>()),
        reason: 'a used code must not move a second car',
      );
    });
  });

  group('bi-fuel', () {
    test('a second fuel that is the same as the first is refused', () async {
      await expectLater(
        alice.from('vehicles').insert({
          'household_id': aliceHousehold,
          'nickname': 'Confused',
          'fuel_type_key': 'fuel_petrol',
          'secondary_fuel_type_key': 'fuel_petrol',
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
        reason: 'a second fuel that is the first one is not a second fuel',
      );
    });

    test('a fill-up can name which fuel went in', () async {
      await alice.from('fuel_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-07-10',
        'odometer_km': 70000,
        'volume_l': 30,
        'fuel_type_key': 'fuel_lpg',
        'full_tank': true,
        'created_by': alice.auth.currentUser!.id,
      });

      final rows = await alice
          .from('fuel_entries')
          .select('fuel_type_key')
          .eq('vehicle_id', aliceVehicle);

      expect(rows.map((r) => r['fuel_type_key']), contains('fuel_lpg'));
    });
  });

  group('deleting an account', () {
    // Play requires in-app deletion to work, and GDPR erasure has to be real.
    // For a *solo* household it always did, by accident: household_members
    // cascades, the cleanup trigger drops the empty household, and that
    // cascades through vehicles to every entry before any created_by is
    // checked. Sharing the household is what exposed it.
    late SupabaseClient leaver;
    late String sharedVehicle;

    setUp(() async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      leaver = await signUp('leaver-$stamp@example.com');
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;
      await leaver.rpc(
        'join_household_with_code',
        params: {'invite_code': code},
      );

      final vehicle = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': 'Shared car',
            'fuel_type_key': 'fuel_petrol',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      sharedVehicle = vehicle['id'] as String;

      await leaver.from('fuel_entries').insert({
        'vehicle_id': sharedVehicle,
        'entry_date': '2026-07-01',
        'odometer_km': 4242,
        'volume_l': 40,
        'full_tank': true,
        'created_by': leaver.auth.currentUser!.id,
      });
    });

    test('a member of a shared household can be deleted at all', () async {
      await expectLater(
        admin.auth.admin.deleteUser(leaver.auth.currentUser!.id),
        completes,
        reason: 'every created_by used to refuse the delete outright',
      );
    });

    test(
      'their entries stay with the household that still owns them',
      () async {
        await admin.auth.admin.deleteUser(leaver.auth.currentUser!.id);

        final rows = await alice
            .from('fuel_entries')
            .select('odometer_km, created_by')
            .eq('vehicle_id', sharedVehicle);

        expect(
          rows.map((r) => r['odometer_km']),
          contains(4242),
          reason:
              'cascading would take a departing member\'s history with them',
        );
        expect(
          rows.single['created_by'],
          isNull,
          reason: 'the attribution goes, because it is what stopped being true',
        );
      },
    );

    test('nothing is left pointing at a user who no longer exists', () async {
      // The trap this closes: `pin_created_by` reverts any update of
      // created_by, and `on delete set null` *is* an update — so the delete
      // reported success and quietly left a dangling reference.
      await admin.auth.admin.deleteUser(leaver.auth.currentUser!.id);

      final rows = await alice
          .from('fuel_entries')
          .select('created_by')
          .eq('vehicle_id', sharedVehicle)
          .not('created_by', 'is', null);

      for (final row in rows) {
        expect(row['created_by'], isNot(equals(leaver.auth.currentUser?.id)));
      }
    });

    test('a live member still cannot erase their own authorship', () async {
      // The trigger was loosened by exactly one case; this is the case it must
      // still refuse.
      final entry = await leaver
          .from('fuel_entries')
          .select('id')
          .eq('vehicle_id', sharedVehicle)
          .limit(1)
          .single();

      await leaver
          .from('fuel_entries')
          .update({'created_by': null})
          .eq('id', entry['id'] as String);

      final after = await leaver
          .from('fuel_entries')
          .select('created_by')
          .eq('id', entry['id'] as String)
          .single();

      expect(after['created_by'], leaver.auth.currentUser!.id);
    });
  });

  /// Deleting a vehicle takes its whole history with it by cascade, and the
  /// app now offers it from the vehicle screen — so the admin-only rule stops
  /// being theoretical the moment a garage has two members.
  group('deleting a vehicle', () {
    test('a member who is not an admin cannot delete one', () async {
      final doomed = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': 'Not Bob to delete',
            'fuel_type_key': 'fuel_petrol',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      final id = doomed['id'] as String;

      // Bob joined by code, so he is a member and not an admin.
      await bob.from('vehicles').delete().eq('id', id);

      final rows = await alice.from('vehicles').select('id').eq('id', id);
      expect(
        rows,
        hasLength(1),
        reason: 'a member deleting a car would take the garage history with it',
      );

      await alice.from('vehicles').delete().eq('id', id);
    });

    test('an admin can, and the history goes with it', () async {
      final doomed = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': 'Scrapped',
            'fuel_type_key': 'fuel_petrol',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      final id = doomed['id'] as String;
      await alice.from('fuel_entries').insert({
        'vehicle_id': id,
        'entry_date': '2026-07-01',
        'odometer_km': 1000,
        'volume_l': 30,
        'full_tank': true,
        'created_by': alice.auth.currentUser!.id,
      });

      await alice.from('vehicles').delete().eq('id', id);

      expect(await alice.from('vehicles').select('id').eq('id', id), isEmpty);
      expect(
        await alice.from('fuel_entries').select('id').eq('vehicle_id', id),
        isEmpty,
        reason: 'the cascade is the whole reason this needs confirming twice',
      );
    });
  });

  /// The one table with policies and no test until now, and the app started
  /// reading it directly when the transfer screen learned to show a code it
  /// had already handed out.
  group('vehicle transfer codes', () {
    test(
      'the seller can read the code outstanding on their own vehicle',
      () async {
        await alice.rpc(
          'create_vehicle_transfer',
          params: {'target_vehicle': aliceVehicle},
        );

        final rows = await alice
            .from('vehicle_transfers')
            .select('code')
            .eq('vehicle_id', aliceVehicle);

        expect(rows, isNotEmpty);
      },
    );

    test('a stranger cannot read it', () async {
      final rows = await carol
          .from('vehicle_transfers')
          .select('code')
          .eq('vehicle_id', aliceVehicle);

      expect(
        rows,
        isEmpty,
        reason: 'a readable code is a car anyone can claim',
      );
    });

    test('the code records which vehicle it was, by name', () async {
      // The seller cannot read the vehicle once it moves, so the name is
      // captured here at offer time. Without it the only thing the app can
      // tell a seller is that "a vehicle" has gone, which for a garage of
      // four is not much of a notice.
      final rows = await alice
          .from('vehicle_transfers')
          .select('vehicle_nickname')
          .eq('vehicle_id', aliceVehicle);

      expect(rows.first['vehicle_nickname'], 'Golf');
    });
  });

  /// The name is the garage's identity, shown to every member and on every
  /// invite. Units and currency stay open to members; renaming does not.
  group('renaming a garage', () {
    test('an admin can', () async {
      await alice
          .from('households')
          .update({'name': 'Alice renamed it'})
          .eq('id', aliceHousehold);

      final row = await alice
          .from('households')
          .select('name')
          .eq('id', aliceHousehold)
          .single();

      expect(row['name'], 'Alice renamed it');
    });

    test('a member who is not an admin cannot', () async {
      await expectLater(
        bob
            .from('households')
            .update({'name': 'Bob renamed it'})
            .eq('id', aliceHousehold),
        throwsA(isA<PostgrestException>()),
        reason: 'a UI check alone would be decoration; this is the boundary',
      );
    });

    test(
      'but a member may still change the settings that are theirs',
      () async {
        // The trigger guards the name and nothing else — taking units away from
        // members would be a bigger change than the one being made.
        await bob
            .from('households')
            .update({'distance_unit': 'mi'})
            .eq('id', aliceHousehold);

        final row = await alice
            .from('households')
            .select('distance_unit, name')
            .eq('id', aliceHousehold)
            .single();

        expect(row['distance_unit'], 'mi');
        expect(row['name'], 'Alice renamed it');

        await alice
            .from('households')
            .update({'distance_unit': 'km'})
            .eq('id', aliceHousehold);
      },
    );

    test('the settlement is off for a garage nobody switched it on for', () {
      // A feature that makes a claim about somebody's money is asked for, not
      // assumed. The default lives in the column, so a household created by
      // any path — sign-up, invite, import — starts without it.
      expect(
        alice
            .from('households')
            .select('settlement_enabled')
            .eq('id', aliceHousehold)
            .single()
            .then((row) => row['settlement_enabled']),
        completion(isFalse),
      );
    });

    test(
      'and any member may switch it on, as with the other settings',
      () async {
        // Not admin-only: it changes what the garage screen shows, not who may
        // do what, and the units beside it are already every member's to set.
        await bob
            .from('households')
            .update({'settlement_enabled': true})
            .eq('id', aliceHousehold);

        final row = await alice
            .from('households')
            .select('settlement_enabled')
            .eq('id', aliceHousehold)
            .single();

        expect(row['settlement_enabled'], isTrue);

        await alice
            .from('households')
            .update({'settlement_enabled': false})
            .eq('id', aliceHousehold);
      },
    );
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
