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

  test(
    'a member can set the timing drive and gearbox on their vehicle',
    () async {
      await alice
          .from('vehicles')
          .update({'timing_drive': 'chain', 'transmission': 'manual'})
          .eq('id', aliceVehicle);

      final row = await alice
          .from('vehicles')
          .select('timing_drive, transmission')
          .eq('id', aliceVehicle)
          .single();

      expect(row['timing_drive'], 'chain');
      expect(row['transmission'], 'manual');
    },
  );

  test('a member can make their vehicle a motorcycle with a chain', () async {
    await alice
        .from('vehicles')
        .update({'kind': 'motorcycle', 'final_drive': 'chain'})
        .eq('id', aliceVehicle);

    final row = await alice
        .from('vehicles')
        .select('kind, final_drive')
        .eq('id', aliceVehicle)
        .single();

    expect(row['kind'], 'motorcycle');
    expect(row['final_drive'], 'chain');
  });

  test('a vehicle is a car unless told otherwise', () async {
    final row = await bob
        .from('vehicles')
        .insert({
          'household_id':
              (await bob.from('households').select('id').limit(1)).first['id'],
          'nickname': 'Van',
          'fuel_type_key': 'fuel_diesel',
          'created_by': bob.auth.currentUser!.id,
        })
        .select('kind')
        .single();

    expect(row['kind'], 'car');
  });

  test('the database refuses a kind it does not know', () async {
    await expectLater(
      alice.from('vehicles').update({'kind': 'boat'}).eq('id', aliceVehicle),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('the database refuses a timing drive it does not know', () async {
    await expectLater(
      alice
          .from('vehicles')
          .update({'timing_drive': 'rubber band'})
          .eq('id', aliceVehicle),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('a stranger cannot read the timing drive either', () async {
    final rows = await carol
        .from('vehicles')
        .select('timing_drive')
        .eq('id', aliceVehicle);

    expect(rows, isEmpty);
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

  /// Paperwork is the newest table and the one whose leak would be the most
  /// personal: a policy number and a registration certificate are exactly the
  /// pair somebody would use to impersonate a car's owner.
  group('vehicle documents', () {
    test('a stranger cannot read another household paperwork', () async {
      await alice.from('vehicle_documents').insert({
        'vehicle_id': aliceVehicle,
        'doc_type': 'registration',
        'number': 'HR-SECRET-1',
        'expires_on': '2027-06-03',
        'created_by': alice.auth.currentUser!.id,
      });

      expect(await carol.from('vehicle_documents').select(), isEmpty);
    });

    test('a stranger cannot file one against another household car', () async {
      await expectLater(
        carol.from('vehicle_documents').insert({
          'vehicle_id': aliceVehicle,
          'doc_type': 'green_card',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    /// The positive control. A policy that denies everyone passes every
    /// "stranger sees nothing" assertion above and is still broken.
    test('a member of the household can add and read one', () async {
      await bob.from('vehicle_documents').insert({
        'vehicle_id': aliceVehicle,
        'doc_type': 'insurance_liability',
        'issuer': 'Croatia osiguranje',
        'expires_on': '2027-01-31',
        'created_by': bob.auth.currentUser!.id,
      });

      final rows = await bob.from('vehicle_documents').select('issuer');

      expect(rows.map((r) => r['issuer']), contains('Croatia osiguranje'));
    });

    test('a member can correct one and delete it', () async {
      final row = await bob
          .from('vehicle_documents')
          .insert({
            'vehicle_id': aliceVehicle,
            'doc_type': 'insurance_comprehensive',
            'expires_on': '2027-02-01',
            'created_by': bob.auth.currentUser!.id,
          })
          .select()
          .single();

      await alice
          .from('vehicle_documents')
          .update({'expires_on': '2028-02-01'})
          .eq('id', row['id'] as String);
      final updated = await alice
          .from('vehicle_documents')
          .select('expires_on')
          .eq('id', row['id'] as String)
          .single();

      expect(updated['expires_on'], '2028-02-01');

      await alice
          .from('vehicle_documents')
          .delete()
          .eq('id', row['id'] as String);
    });

    /// The app never plain-UPDATEs a document: `SupabaseDocumentRepository.save`
    /// upserts the whole row, so a correction is an INSERT ... ON CONFLICT DO
    /// UPDATE. That statement is checked against the *insert* policy as well
    /// as the update one, and the insert policy demands
    /// `created_by = auth.uid()` — so a member editing a document somebody
    /// else in the household filed is the case a plain-update test cannot
    /// reach.
    test('a member can correct a document another member filed', () async {
      final row = await alice
          .from('vehicle_documents')
          .insert({
            'vehicle_id': aliceVehicle,
            'doc_type': 'green_card',
            'expires_on': '2027-04-01',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();

      // Exactly what `SupabaseDocumentRepository.save` sends: the caller's
      // own id, because the insert policy demands it.
      await bob.from('vehicle_documents').upsert({
        'id': row['id'],
        'vehicle_id': aliceVehicle,
        'doc_type': 'green_card',
        'expires_on': '2028-04-01',
        'created_by': bob.auth.currentUser!.id,
      });

      final updated = await bob
          .from('vehicle_documents')
          .select('expires_on, created_by')
          .eq('id', row['id'] as String)
          .single();

      expect(updated['expires_on'], '2028-04-01');
      expect(
        updated['created_by'],
        alice.auth.currentUser!.id,
        reason: 'correcting a row must not reattribute it',
      );

      await alice
          .from('vehicle_documents')
          .delete()
          .eq('id', row['id'] as String);
    });

    test('and cannot rewrite who filed it', () async {
      final row = await alice
          .from('vehicle_documents')
          .insert({
            'vehicle_id': aliceVehicle,
            'doc_type': 'roadworthiness',
            'expires_on': '2027-04-01',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();

      await bob
          .from('vehicle_documents')
          .update({'created_by': bob.auth.currentUser!.id})
          .eq('id', row['id'] as String);

      final after = await bob
          .from('vehicle_documents')
          .select('created_by')
          .eq('id', row['id'] as String)
          .single();

      expect(
        after['created_by'],
        alice.auth.currentUser!.id,
        reason: 'created_by is attribution and is pinned by a trigger',
      );

      await alice
          .from('vehicle_documents')
          .delete()
          .eq('id', row['id'] as String);
    });

    test(
      'one of each kind per car, so a renewal edits rather than piles up',
      () async {
        await expectLater(
          alice.from('vehicle_documents').insert({
            'vehicle_id': aliceVehicle,
            'doc_type': 'registration',
            'number': 'HR-SECOND-1',
            'created_by': alice.auth.currentUser!.id,
          }),
          throwsA(isA<PostgrestException>()),
          reason: 'a car holds one registration certificate at a time',
        );
      },
    );

    test('and "other" is exempt, because it names nothing', () async {
      for (final label in ['Lease agreement', 'Border permit']) {
        await alice.from('vehicle_documents').insert({
          'vehicle_id': aliceVehicle,
          'doc_type': 'other',
          'label': label,
          'created_by': alice.auth.currentUser!.id,
        });
      }

      final rows = await alice
          .from('vehicle_documents')
          .select('label')
          .eq('doc_type', 'other');

      expect(
        rows.map((r) => r['label']),
        containsAll(['Lease agreement', 'Border permit']),
      );
    });

    test('an expiry before the issue date is refused', () async {
      await expectLater(
        alice.from('vehicle_documents').insert({
          'vehicle_id': aliceVehicle,
          'doc_type': 'green_card',
          'issued_on': '2027-01-01',
          'expires_on': '2026-01-01',
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a photo of the paper can hang off it', () async {
      // The attachments check constraint had to learn a fourth entry kind,
      // and a constraint that did not would have failed only in the field.
      final document = await alice
          .from('vehicle_documents')
          .select('id')
          .eq('doc_type', 'registration')
          .single();

      await alice.from('attachments').insert({
        'vehicle_id': aliceVehicle,
        'entry_kind': 'document',
        'entry_id': document['id'],
        'storage_path': '$aliceVehicle/doc-scan.jpg',
        'file_name': 'doc-scan.jpg',
        'created_by': alice.auth.currentUser!.id,
      });

      final rows = await alice
          .from('attachments')
          .select('file_name')
          .eq('entry_kind', 'document');

      expect(rows.map((r) => r['file_name']), contains('doc-scan.jpg'));
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

    test(
      'a fill-up can record what the cheapest station nearby charged',
      () async {
        await alice.from('fuel_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-11',
          'odometer_km': 70500,
          'volume_l': 40,
          'price_per_l': 1.66,
          'full_tank': true,
          'cheapest_nearby_price': 1.54,
          'cheapest_nearby_km': 3.2,
          'cheapest_nearby_station': 'Petrol Ilica',
          'prices_seen_on': '2026-07-11',
          'created_by': alice.auth.currentUser!.id,
        });

        final rows = await alice
            .from('fuel_entries')
            .select('cheapest_nearby_price, cheapest_nearby_station')
            .eq('vehicle_id', aliceVehicle)
            .eq('odometer_km', 70500);

        expect(rows.single['cheapest_nearby_station'], 'Petrol Ilica');
        expect((rows.single['cheapest_nearby_price'] as num).toDouble(), 1.54);
      },
    );

    // All four columns or none: a price with no date it was read on is a
    // number nobody can interpret later.
    test('half a price snapshot is refused by the table', () async {
      await expectLater(
        alice.from('fuel_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-07-12',
          'odometer_km': 71000,
          'volume_l': 40,
          'full_tank': true,
          'cheapest_nearby_price': 1.54,
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
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

      // One row in the newest table too, and this is the point of it: `0033`
      // was a one-shot pass over the `created_by` constraints that existed
      // when it ran, so a table added afterwards can reintroduce the exact
      // refusal it removed. A fuel entry alone would keep passing while
      // in-app deletion was broken again for anyone who filed a document —
      // which is the Play requirement, failing silently, for shared garages
      // only. Every table added from here should get a row in this setup.
      await leaver.from('vehicle_documents').insert({
        'vehicle_id': sharedVehicle,
        'doc_type': 'registration',
        'expires_on': '2027-07-01',
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
  /// The one table in the schema that is deliberately readable by nobody.
  ///
  /// It holds the dispatcher's endpoint and its bearer token — operator
  /// configuration, not household data — so `0025_webhook_dispatch_config.sql`
  /// enables RLS and then writes no policy at all, and revokes the grants on
  /// top. The trigger that needs it runs `security definer` and is not subject
  /// to policies.
  ///
  /// Deny-all is the whole contract here, which is why this group breaks the
  /// rule the rest of this file follows: there is no positive control to write,
  /// because there is no legitimate reader. Untested until now, which meant a
  /// later migration adding a policy or re-granting `authenticated` would have
  /// gone unnoticed — and what leaks is a token, not a fuel entry.
  group('the webhook dispatch config', () {
    // Asserting the *code*, not merely that something threw. PostgREST answers
    // a table nobody may read with 42501 and a table that does not exist with
    // PGRST205, and both arrive as a PostgrestException — so a test that only
    // checks the type would keep passing if this table were renamed away or
    // the name here were mistyped, which is the failure mode a deny-all test
    // is most exposed to.
    Matcher deniedByPrivilege() => throwsA(
      isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
    );

    test('a signed-in user cannot read it', () async {
      await expectLater(
        alice.from('webhook_dispatch_config').select('endpoint'),
        deniedByPrivilege(),
        reason: 'the dispatcher bearer token is not household data',
      );
    });

    test('a signed-in user cannot write one either', () async {
      await expectLater(
        alice.from('webhook_dispatch_config').insert({
          'endpoint': 'https://attacker.test/collect',
          'auth_token': 'stolen',
        }),
        deniedByPrivilege(),
        reason: 'a writable endpoint redirects every household entry',
      );
    });
  });

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

    test(
      'a seller can withdraw an unredeemed transfer, a stranger cannot',
      () async {
        // A delete refused by RLS returns success with zero rows, so the app
        // cannot tell a policy regression from a working cancel.
        final code =
            await alice.rpc(
                  'create_vehicle_transfer',
                  params: {'target_vehicle': aliceVehicle},
                )
                as String;

        await carol.from('vehicle_transfers').delete().eq('code', code);
        final afterStranger = await alice
            .from('vehicle_transfers')
            .select('code')
            .eq('code', code);
        expect(
          afterStranger,
          hasLength(1),
          reason: 'a stranger deletes nothing',
        );

        await alice.from('vehicle_transfers').delete().eq('code', code);
        final afterSeller = await alice
            .from('vehicle_transfers')
            .select('code')
            .eq('code', code);
        expect(afterSeller, isEmpty);
      },
    );

    test('a one-time rule upserted twice by its own id is one row', () async {
      // The sheet chooses the id, so a save retried after a timeout lands
      // once (decision 80).
      const id = '7d2c1c5e-3f0a-4b4e-9c2b-1d2e3f4a5b6c';
      for (final due in ['2030-01-01', '2030-02-01']) {
        await alice.from('reminder_rules').upsert({
          'id': id,
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_vignette',
          'one_time': true,
          'due_date': due,
          'active': true,
        });
      }

      final rows = await alice
          .from('reminder_rules')
          .select('id, due_date')
          .eq('vehicle_id', aliceVehicle)
          .eq('service_type_key', 'service_vignette');
      expect(rows, hasLength(1));
      expect(rows.single['due_date'], '2030-02-01');

      // A stranger upserting the same id must not take the row over. (Bob
      // has joined this garage by now; Carol never does.) Whether Postgres
      // refuses loudly or resolves the conflict to nothing is the policy's
      // business; the row is what is asserted.
      try {
        await carol.from('reminder_rules').upsert({
          'id': id,
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_vignette',
          'one_time': true,
          'due_date': '2031-01-01',
          'active': true,
        });
      } on PostgrestException {
        // Refused: also fine.
      }
      final after = await alice
          .from('reminder_rules')
          .select('due_date')
          .eq('id', id);
      expect(after.single['due_date'], '2030-02-01');
      final seenByCarol = await carol
          .from('reminder_rules')
          .select('id')
          .eq('id', id);
      expect(seenByCarol, isEmpty);
    });

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

  group('the startup bootstrap', () {
    // The app fetches households and their vehicles in one embedded select
    // now. PostgREST applies row level security to an embedded table as well
    // as to the parent, but "should" is not a test: an embed that ignored the
    // vehicles policy would hand every garage's cars to anyone who could see
    // any household row, and it would look exactly like a working app.
    //
    // Written as the read the app actually makes, and — because everything to
    // do with `created_by` looks fine when the author is the caller — also as
    // the member who did not create the rows.
    Future<List<Map<String, dynamic>>> bootstrapAs(SupabaseClient who) async {
      return (await who.from('households').select('*, vehicles(*)'))
          .cast<Map<String, dynamic>>();
    }

    List<Map<String, dynamic>> vehiclesOf(Map<String, dynamic> household) {
      return (household['vehicles'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
    }

    test('the creator gets her garage with its cars embedded', () async {
      // The positive control. A policy that denies everybody passes every
      // "a stranger sees nothing" assertion in this file.
      final rows = await bootstrapAs(alice);

      final household = rows.singleWhere((it) => it['id'] == aliceHousehold);
      expect(
        vehiclesOf(household).map((it) => it['id']),
        contains(aliceVehicle),
      );
    });

    test('a member who created none of it sees the same cars', () async {
      final erin = await signUp(
        'erin-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(erin.dispose);
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;
      await erin.rpc('join_household_with_code', params: {'invite_code': code});

      final rows = await bootstrapAs(erin);

      final household = rows.singleWhere((it) => it['id'] == aliceHousehold);
      expect(
        vehiclesOf(household).map((it) => it['id']),
        contains(aliceVehicle),
        reason: 'a member is an equal owner of the garage, not a guest in it',
      );
    });

    test('a stranger gets neither the garage nor its cars', () async {
      final frank = await signUp(
        'frank-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(frank.dispose);

      final rows = await bootstrapAs(frank);

      expect(rows.where((it) => it['id'] == aliceHousehold), isEmpty);
      expect(
        rows.expand(vehiclesOf).map((it) => it['id']),
        isNot(contains(aliceVehicle)),
        reason: 'the embed must not reach past the policy on vehicles',
      );
    });

    test('each garage carries only its own cars', () async {
      // Somebody in two garages is the case where a leak would be invisible:
      // both rows come back legitimately, and the vehicles could be pooled
      // across them without any of them being a row the caller may not see.
      final gina = await signUp(
        'gina-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(gina.dispose);
      final ownHousehold =
          await gina.rpc(
                'create_household',
                params: {'household_name': "Gina's garage"},
              )
              as String;
      final ownVehicle =
          (await gina
                  .from('vehicles')
                  .insert({
                    'household_id': ownHousehold,
                    'nickname': 'Punto',
                    'fuel_type_key': 'fuel_petrol',
                    'created_by': gina.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;
      await gina.rpc('join_household_with_code', params: {'invite_code': code});

      final rows = await bootstrapAs(gina);

      expect(rows, hasLength(2));
      final own = rows.singleWhere((it) => it['id'] == ownHousehold);
      final alices = rows.singleWhere((it) => it['id'] == aliceHousehold);
      expect(vehiclesOf(own).map((it) => it['id']), [ownVehicle]);
      expect(vehiclesOf(alices).map((it) => it['id']), contains(aliceVehicle));
      expect(
        vehiclesOf(alices).map((it) => it['id']),
        isNot(contains(ownVehicle)),
      );
    });
  });

  group('trip drafts', () {
    // A draft is a trip whose distance is not known yet (migration 0054).
    // The policies on trip_entries are table-level and already cover it, which
    // is exactly why it needs testing: "the existing policy applies" is an
    // assumption until a draft row has actually been pushed through it.
    Future<String> startDraft(
      SupabaseClient who, {
      required String vehicleId,
      int? odometer,
    }) async {
      final row = await who
          .from('trip_entries')
          .insert({
            'vehicle_id': vehicleId,
            'entry_date': '2026-09-05',
            'started_at': DateTime.now().toUtc().toIso8601String(),
            'start_odometer_km': odometer ?? 142300,
            'created_by': who.auth.currentUser!.id,
          })
          .select()
          .single();
      return row['id'] as String;
    }

    test('a member can open a drive, and it has no distance yet', () async {
      final id = await startDraft(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('trip_entries').delete().eq('id', id));

      final rows = await alice.from('trip_entries').select().eq('id', id);

      expect(rows.single['distance_km'], isNull);
      expect(rows.single['started_at'], isNotNull);
    });

    test('a stranger cannot open a drive on somebody else\'s car', () async {
      await expectLater(
        carol.from('trip_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-05',
          'started_at': DateTime.now().toUtc().toIso8601String(),
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a car cannot be on two journeys at once', () async {
      final id = await startDraft(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('trip_entries').delete().eq('id', id));

      await expectLater(
        startDraft(alice, vehicleId: aliceVehicle),
        throwsA(isA<PostgrestException>()),
        reason: 'the partial unique index is what stops a double tap',
      );
    });

    test('a trip with no distance and no start is refused outright', () async {
      // The constraint exists so the draft state cannot be entered by
      // accident: an insert that simply forgot the distance is a bug, not an
      // open drive.
      await expectLater(
        alice.from('trip_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-05',
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'another member can finish the drive, and does not become its author',
      () async {
        // The shared-garage case: one person takes the car, another closes the
        // logbook. `created_by` is pinned by the trigger from 0041, so finishing
        // somebody else's drive must not quietly reassign who made the journey.
        final helen = await signUp(
          'helen-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        addTearDown(helen.dispose);
        final code =
            await alice.rpc(
                  'create_invite',
                  params: {'target_household': aliceHousehold},
                )
                as String;
        await helen.rpc(
          'join_household_with_code',
          params: {'invite_code': code},
        );

        final id = await startDraft(alice, vehicleId: aliceVehicle);
        addTearDown(() => alice.from('trip_entries').delete().eq('id', id));

        await helen
            .from('trip_entries')
            .update({
              'distance_km': 42.5,
              'end_odometer_km': 142343,
              'minutes': 55,
              'created_by': helen.auth.currentUser!.id,
            })
            .eq('id', id);

        final row =
            (await alice.from('trip_entries').select().eq('id', id)).single;
        expect(row['distance_km'], 42.5);
        expect(
          row['created_by'],
          alice.auth.currentUser!.id,
          reason: 'the trigger from 0041 pins the author through the finish',
        );
      },
    );

    test('a stranger cannot see a drive in progress', () async {
      final id = await startDraft(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('trip_entries').delete().eq('id', id));

      final rows = await carol.from('trip_entries').select().eq('id', id);

      expect(rows, isEmpty);
    });

    test('finishing frees the car for the next drive', () async {
      final first = await startDraft(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('trip_entries').delete().eq('id', first));
      await alice
          .from('trip_entries')
          .update({'distance_km': 12.0})
          .eq('id', first);

      final second = await startDraft(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('trip_entries').delete().eq('id', second));

      expect(second, isNotEmpty);
    });
  });

  group('guest passes', () {
    // A second tenancy model: scoped, expiring access to ONE vehicle, for
    // somebody who is deliberately not a member of the garage. Every policy
    // behind it is additive, so these tests have two jobs — prove a guest can
    // do the narrow thing, and prove they can do nothing else.
    late SupabaseClient guest;
    late String guestId;

    setUp(() async {
      guest = await signUp(
        'guest-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      guestId = guest.auth.currentUser!.id;
    });

    tearDown(() async => guest.dispose());

    Future<String> mintPass({
      bool fuel = true,
      bool trips = true,
      bool costs = true,
      bool history = false,
      int days = 7,
    }) async {
      return await alice.rpc(
            'create_guest_pass',
            params: {
              'target_vehicle': aliceVehicle,
              'valid_days': days,
              'allow_fuel': fuel,
              'allow_trips': trips,
              'allow_costs': costs,
              'allow_history': history,
            },
          )
          as String;
    }

    Future<String> redeemed({
      bool fuel = true,
      bool trips = true,
      bool costs = true,
      bool history = false,
    }) async {
      final code = await mintPass(
        fuel: fuel,
        trips: trips,
        costs: costs,
        history: history,
      );
      await guest.rpc('redeem_guest_pass', params: {'pass_code': code});
      return code;
    }

    test('an owner can mint a pass for their own car', () async {
      final code = await mintPass();

      expect(code, hasLength(8));
    });

    test(
      'a stranger cannot mint a pass for a car that is not theirs',
      () async {
        await expectLater(
          carol.rpc(
            'create_guest_pass',
            params: {'target_vehicle': aliceVehicle, 'valid_days': 7},
          ),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('a pass has to last somewhere between a day and a year', () async {
      await expectLater(
        alice.rpc(
          'create_guest_pass',
          params: {'target_vehicle': aliceVehicle, 'valid_days': 0},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('before redeeming, the holder is simply a stranger', () async {
      await mintPass();

      final vehicles = await guest.from('vehicles').select();

      expect(vehicles, isEmpty);
    });

    test('redeeming opens the one car and nothing else', () async {
      // The positive control, and the containment test in one: Alice has a
      // second vehicle that the pass says nothing about.
      final other =
          (await alice
                  .from('vehicles')
                  .insert({
                    'household_id': aliceHousehold,
                    'nickname': 'Not lent',
                    'fuel_type_key': 'fuel_petrol',
                    'created_by': alice.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      addTearDown(() => alice.from('vehicles').delete().eq('id', other));

      await redeemed();

      final vehicles = await guest.from('vehicles').select();
      expect(vehicles.map((it) => it['id']), [aliceVehicle]);
    });

    test('a guest can log a fill-up against the car they were lent', () async {
      await redeemed();

      await guest.from('fuel_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-09-05',
        'odometer_km': 60000,
        'volume_l': 40.0,
        'total': 65.0,
        'full_tank': true,
        'created_by': guestId,
      });

      final mine = await guest.from('fuel_entries').select();
      expect(mine, hasLength(1));
      expect(mine.single['created_by'], guestId);
    });

    test('and cannot log one as somebody else', () async {
      await redeemed();

      await expectLater(
        guest.from('fuel_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-05',
          'odometer_km': 60000,
          'volume_l': 40.0,
          'total': 65.0,
          'full_tank': true,
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('the car\'s earlier history stays private by default', () async {
      // Alice logged a fill-up in setUpAll. A borrower sees what they wrote and
      // nothing before it.
      await redeemed();

      final rows = await guest.from('fuel_entries').select();

      expect(rows, isEmpty);
    });

    test('unless the pass says otherwise', () async {
      await redeemed(history: true);

      final rows = await guest.from('fuel_entries').select();

      expect(rows, isNotEmpty);
    });

    test('a guest cannot change what somebody else logged', () async {
      await redeemed(history: true);
      final theirs = (await guest.from('fuel_entries').select()).first;

      await guest
          .from('fuel_entries')
          .update({'total': 999.0})
          .eq('id', theirs['id'] as String);

      final after = await alice
          .from('fuel_entries')
          .select()
          .eq('id', theirs['id'] as String);
      expect(
        (after.single['total'] as num).toDouble(),
        isNot(999.0),
        reason: 'read access is not write access',
      );
    });

    test('a guest cannot delete what somebody else logged', () async {
      await redeemed(history: true);
      final theirs = (await guest.from('fuel_entries').select()).first;

      await guest
          .from('fuel_entries')
          .delete()
          .eq('id', theirs['id'] as String);

      final after = await alice
          .from('fuel_entries')
          .select()
          .eq('id', theirs['id'] as String);
      expect(after, hasLength(1));
    });

    test('a permission the pass withholds is genuinely withheld', () async {
      await redeemed(trips: false);

      await expectLater(
        guest.from('trip_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-05',
          'distance_km': 20.0,
          'created_by': guestId,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('and one it grants works', () async {
      await redeemed();

      await guest.from('trip_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-09-05',
        'distance_km': 20.0,
        'created_by': guestId,
      });

      expect(await guest.from('trip_entries').select(), hasLength(1));
    });

    test('an expired pass grants nothing at all', () async {
      final code = await redeemed();
      // The owner's own update path, rather than reaching past the policies.
      await alice
          .from('vehicle_guest_passes')
          .update({
            'expires_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          })
          .eq('code', code);

      expect(await guest.from('vehicles').select(), isEmpty);
      await expectLater(
        guest.from('fuel_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-05',
          'odometer_km': 60000,
          'volume_l': 40.0,
          'total': 65.0,
          'full_tank': true,
          'created_by': guestId,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a pass withdrawn early stops working immediately', () async {
      final code = await redeemed();
      await alice
          .from('vehicle_guest_passes')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('code', code);

      expect(await guest.from('vehicles').select(), isEmpty);
    });

    test('a pass that has not started yet grants nothing', () async {
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {
                  'target_vehicle': aliceVehicle,
                  'valid_days': 7,
                  'starts_on': DateTime.now()
                      .toUtc()
                      .add(const Duration(days: 2))
                      .toIso8601String(),
                },
              )
              as String;
      await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

      expect(await guest.from('vehicles').select(), isEmpty);
    });

    test('what the guest logged outlives their access', () async {
      // The confirmed product choice: expiry ends access, it does not remove
      // the fill-up from the car's history.
      final code = await redeemed();
      await guest.from('fuel_entries').insert({
        'vehicle_id': aliceVehicle,
        'entry_date': '2026-09-05',
        'odometer_km': 60001,
        'volume_l': 41.0,
        'total': 66.0,
        'full_tank': true,
        'created_by': guestId,
      });
      await alice
          .from('vehicle_guest_passes')
          .update({
            'expires_at': DateTime.now()
                .toUtc()
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          })
          .eq('code', code);

      final owners = await alice
          .from('fuel_entries')
          .select()
          .eq('created_by', guestId);
      expect(owners, hasLength(1));
      expect(await guest.from('fuel_entries').select(), isEmpty);
    });

    test('a code already in somebody else\'s hands is refused', () async {
      final code = await mintPass();
      await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

      final other = await signUp(
        'other-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(other.dispose);

      await expectLater(
        other.rpc('redeem_guest_pass', params: {'pass_code': code}),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'but the holder may redeem their own again, after a reinstall',
      () async {
        final code = await mintPass();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        expect(await guest.from('vehicles').select(), hasLength(1));
      },
    );

    test('a member of the garage is refused a pass to their own car', () async {
      final code = await mintPass();

      await expectLater(
        alice.rpc('redeem_guest_pass', params: {'pass_code': code}),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'an unknown, expired or withdrawn code is refused on redemption',
      () async {
        await expectLater(
          guest.rpc('redeem_guest_pass', params: {'pass_code': 'ZZZZZZZZ'}),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('a guest sees their own pass and nobody else\'s', () async {
      await redeemed();
      // A pass on Alice's car that this guest has nothing to do with.
      await mintPass();

      final mine = await guest.from('vehicle_guest_passes').select();

      expect(mine, hasLength(1));
      expect(mine.single['redeemed_by'], guestId);
    });

    test('the owner sees every pass on their car', () async {
      await redeemed();

      final theirs = await alice
          .from('vehicle_guest_passes')
          .select()
          .eq('vehicle_id', aliceVehicle);

      expect(theirs, isNotEmpty);
    });

    test('a stranger sees no passes at all', () async {
      await redeemed();

      expect(await carol.from('vehicle_guest_passes').select(), isEmpty);
    });

    test('a guest cannot mint a pass of their own', () async {
      // Otherwise a borrowed car could be lent onward indefinitely.
      await redeemed();

      await expectLater(
        guest.rpc(
          'create_guest_pass',
          params: {'target_vehicle': aliceVehicle, 'valid_days': 7},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'the fetch the app makes on startup returns the borrowed car',
      () async {
        // Written as the read the app actually makes. The first version of the
        // startup fetch asked for `households` with `vehicles(*)` nested, which
        // is a single round trip and silently lost every borrowed car: an embed
        // only nests rows under parents the outer query returned, and the
        // lender's garage is not one of the borrower's. The policies were right
        // and the app was asking the wrong question.
        final ownHousehold =
            await guest.rpc(
                  'create_household',
                  params: {'household_name': "Guest's own garage"},
                )
                as String;
        final ownVehicle =
            (await guest
                    .from('vehicles')
                    .insert({
                      'household_id': ownHousehold,
                      'nickname': 'Own car',
                      'fuel_type_key': 'fuel_petrol',
                      'created_by': guestId,
                    })
                    .select()
                    .single())['id']
                as String;
        await redeemed();

        final vehicles = await guest.from('vehicles').select();
        final households = await guest.from('households').select();

        expect(
          vehicles.map((it) => it['id']),
          containsAll([ownVehicle, aliceVehicle]),
          reason: 'both the guest\'s own car and the borrowed one',
        );
        expect(
          households.map((it) => it['id']),
          [ownHousehold],
          reason:
              'the lender\'s garage stays invisible; only the car is shared',
        );
      },
    );

    test('a guest never becomes a member of the garage', () async {
      await redeemed();

      expect(await guest.from('households').select(), isEmpty);
    });
  });

  group('admin succession', () {
    // A garage must never be left without an admin. Creating one made you its
    // admin and that was the only route, so an admin leaving — or deleting
    // their account, which removes their membership — stranded the garage:
    // cars and history intact, and nobody who could rename it, remove a
    // member or delete it, with no way back.
    Future<(SupabaseClient, String)> newUser(String prefix) async {
      final client = await signUp(
        '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(client.dispose);
      return (client, client.auth.currentUser!.id);
    }

    Future<String?> roleOf(
      SupabaseClient reader,
      String household,
      String userId,
    ) async {
      final rows = await reader
          .from('household_members')
          .select('role')
          .eq('household_id', household)
          .eq('user_id', userId);
      return rows.isEmpty ? null : rows.single['role'] as String?;
    }

    /// A garage of its own, so nothing here mutates the one the rest of this
    /// file relies on Alice administering.
    Future<(SupabaseClient, String, SupabaseClient, String)> pairedGarage(
      String name,
    ) async {
      // The name reaches an email address, so it cannot carry spaces.
      final slug = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '-');
      final (owner, ownerId) = await newUser('owner-$slug');
      final (partner, _) = await newUser('partner-$slug');
      final household =
          await owner.rpc('create_household', params: {'household_name': name})
              as String;
      final code =
          await owner.rpc(
                'create_invite',
                params: {'target_household': household},
              )
              as String;
      await partner.rpc(
        'join_household_with_code',
        params: {'invite_code': code},
      );
      return (owner, ownerId, partner, household);
    }

    test('the remaining member is promoted when the admin leaves', () async {
      final (owner, ownerId, partner, household) = await pairedGarage(
        'Left behind',
      );
      final partnerId = partner.auth.currentUser!.id;
      expect(await roleOf(owner, household, partnerId), 'member');

      await owner
          .from('household_members')
          .delete()
          .eq('household_id', household)
          .eq('user_id', ownerId);

      expect(await roleOf(partner, household, partnerId), 'admin');
    });

    test('and the promoted one can actually act as admin', () async {
      // The point of the promotion is the powers, not the label.
      final (owner, ownerId, partner, household) = await pairedGarage(
        'Successor',
      );

      await owner
          .from('household_members')
          .delete()
          .eq('household_id', household)
          .eq('user_id', ownerId);
      await partner
          .from('households')
          .update({'name': 'Renamed by the successor'})
          .eq('id', household);

      final rows = await partner
          .from('households')
          .select('name')
          .eq('id', household);
      expect(rows.single['name'], 'Renamed by the successor');
    });

    test('the longest-standing member is the one promoted', () async {
      // Not the newest. The person who has been in the garage longest has the
      // most history in it.
      final (owner, ownerId) = await newUser('owner');
      final (first, firstId) = await newUser('first');
      final (second, secondId) = await newUser('second');
      final household =
          await owner.rpc(
                'create_household',
                params: {'household_name': 'Succession'},
              )
              as String;

      for (final joiner in [first, second]) {
        final code =
            await owner.rpc(
                  'create_invite',
                  params: {'target_household': household},
                )
                as String;
        await joiner.rpc(
          'join_household_with_code',
          params: {'invite_code': code},
        );
      }

      await owner
          .from('household_members')
          .delete()
          .eq('household_id', household)
          .eq('user_id', ownerId);

      expect(await roleOf(first, household, firstId), 'admin');
      expect(await roleOf(first, household, secondId), 'member');
    });

    test('a garage that still has an admin is left alone', () async {
      final (owner, ownerId) = await newUser('two-admins');
      final (other, otherId) = await newUser('other');
      final household =
          await owner.rpc(
                'create_household',
                params: {'household_name': 'Two admins'},
              )
              as String;
      final code =
          await owner.rpc(
                'create_invite',
                params: {'target_household': household},
              )
              as String;
      await other.rpc(
        'join_household_with_code',
        params: {'invite_code': code},
      );
      // A second admin, the way the app would make one. Asserted rather than
      // assumed: before migration 0058 there was no update policy at all, so
      // this silently changed nothing and the test below still passed.
      await owner
          .from('household_members')
          .update({'role': 'admin'})
          .eq('household_id', household)
          .eq('user_id', otherId);
      expect(
        await roleOf(owner, household, otherId),
        'admin',
        reason: 'the promotion has to have actually happened',
      );

      final (third, thirdId) = await newUser('third');
      final code2 =
          await owner.rpc(
                'create_invite',
                params: {'target_household': household},
              )
              as String;
      await third.rpc(
        'join_household_with_code',
        params: {'invite_code': code2},
      );

      await owner
          .from('household_members')
          .delete()
          .eq('household_id', household)
          .eq('user_id', ownerId);

      expect(
        await roleOf(other, household, thirdId),
        'member',
        reason: 'an admin was still present, so nobody needed promoting',
      );
    });

    test('the last member leaving still takes the garage with it', () async {
      // The promotion must not resurrect a household the cleanup trigger is
      // in the middle of deleting.
      final (solo, soloId) = await newUser('solo');
      final household =
          await solo.rpc('create_household', params: {'household_name': 'Solo'})
              as String;

      await solo
          .from('household_members')
          .delete()
          .eq('household_id', household)
          .eq('user_id', soloId);

      expect(
        await solo.from('households').select().eq('id', household),
        isEmpty,
      );
    });

    test('a sole member demoting themselves keeps the role anyway', () async {
      // Nobody else to give it to, and a garage cannot be adminless.
      final (solo, soloId) = await newUser('sole-admin');
      final household =
          await solo.rpc(
                'create_household',
                params: {'household_name': 'Alone'},
              )
              as String;

      await solo
          .from('household_members')
          .update({'role': 'member'})
          .eq('household_id', household)
          .eq('user_id', soloId);

      expect(await roleOf(solo, household, soloId), 'admin');
    });

    test('a member cannot promote themselves', () async {
      final (owner, _, partner, household) = await pairedGarage(
        'No self serve',
      );
      final partnerId = partner.auth.currentUser!.id;

      await partner
          .from('household_members')
          .update({'role': 'admin'})
          .eq('household_id', household)
          .eq('user_id', partnerId);

      expect(
        await roleOf(owner, household, partnerId),
        'member',
        reason: 'only an admin may change roles',
      );
    });

    test('an admin can promote a member, so a garage can have two', () async {
      // Two parents as admins, a teenager as a member who can log fuel but
      // cannot delete the garage.
      final (owner, ownerId, partner, household) = await pairedGarage(
        'Two admins',
      );
      final partnerId = partner.auth.currentUser!.id;

      await owner
          .from('household_members')
          .update({'role': 'admin'})
          .eq('household_id', household)
          .eq('user_id', partnerId);

      expect(await roleOf(owner, household, ownerId), 'admin');
      expect(await roleOf(owner, household, partnerId), 'admin');
    });

    test('and the newly promoted one really has the powers', () async {
      final (owner, _, partner, household) = await pairedGarage('Real powers');
      final partnerId = partner.auth.currentUser!.id;
      await owner
          .from('household_members')
          .update({'role': 'admin'})
          .eq('household_id', household)
          .eq('user_id', partnerId);

      await partner
          .from('households')
          .update({'name': 'Renamed by the new admin'})
          .eq('id', household);

      final rows = await partner
          .from('households')
          .select('name')
          .eq('id', household);
      expect(rows.single['name'], 'Renamed by the new admin');
    });

    test('stepping down hands the role on rather than keeping it', () async {
      // Reachable without any new UI: the grants allow a member row update.
      final (owner, ownerId) = await newUser('demoter');
      final (mate, mateId) = await newUser('mate');
      final household =
          await owner.rpc(
                'create_household',
                params: {'household_name': 'Demotion'},
              )
              as String;
      final code =
          await owner.rpc(
                'create_invite',
                params: {'target_household': household},
              )
              as String;
      await mate.rpc('join_household_with_code', params: {'invite_code': code});

      await owner
          .from('household_members')
          .update({'role': 'member'})
          .eq('household_id', household)
          .eq('user_id', ownerId);
      expect(
        await roleOf(mate, household, ownerId),
        'member',
        reason:
            'the demotion has to have actually happened for this to mean '
            'anything — an update RLS filtered out would leave the original '
            'admin in place and the assertion below would pass regardless',
      );

      final roles = await owner
          .from('household_members')
          .select('user_id, role')
          .eq('household_id', household);
      expect(
        roles.where((it) => it['role'] == 'admin').map((it) => it['user_id']),
        [mateId],
        reason:
            'the role goes to the other member, not straight back to the '
            'person who just gave it up — they are the longest-standing, so a '
            'naive rule hands it back and "step down" silently does nothing',
      );
    });
  });

  group('merging two garages', () {
    // Two people who each had a garage before they had one together. The
    // absorbed garage is emptied into the survivor and deleted; there is no
    // third garage, and nothing records afterwards which car came from where.
    Future<(SupabaseClient, String)> newUser(String prefix) async {
      final client = await signUp(
        '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(client.dispose);
      return (client, client.auth.currentUser!.id);
    }

    Future<String> garageFor(
      SupabaseClient owner,
      String name, {
      String currency = 'EUR',
    }) async {
      final id =
          await owner.rpc('create_household', params: {'household_name': name})
              as String;
      if (currency != 'EUR') {
        await owner
            .from('households')
            .update({'currency_code': currency})
            .eq('id', id);
      }
      return id;
    }

    Future<String> carIn(
      SupabaseClient owner,
      String household,
      String nickname,
    ) async {
      final row = await owner
          .from('vehicles')
          .insert({
            'household_id': household,
            'nickname': nickname,
            'fuel_type_key': 'fuel_petrol',
            'created_by': owner.auth.currentUser!.id,
          })
          .select()
          .single();
      return row['id'] as String;
    }

    /// Both garages, with the caller an admin of each — the arrangement a
    /// merge requires, reached the way the app reaches it.
    Future<(SupabaseClient, String, String, SupabaseClient, String)>
    twoGarages({String absorbedCurrency = 'EUR'}) async {
      final (me, myId) = await newUser('merger');
      final (them, _) = await newUser('merged');
      final mine = await garageFor(me, 'Mine');
      final theirs = await garageFor(
        them,
        'Theirs',
        currency: absorbedCurrency,
      );
      final code =
          await them.rpc('create_invite', params: {'target_household': theirs})
              as String;
      await me.rpc('join_household_with_code', params: {'invite_code': code});
      // Joining makes you a member; a merge needs admin of both.
      await them
          .from('household_members')
          .update({'role': 'admin'})
          .eq('household_id', theirs)
          .eq('user_id', myId);
      return (me, mine, theirs, them, myId);
    }

    test('the cars arrive, and the old garage is gone', () async {
      final (me, mine, theirs, them, _) = await twoGarages();
      final theirCar = await carIn(them, theirs, 'Their Clio');
      await carIn(me, mine, 'My Golf');

      final result = await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      expect(result['vehicles_moved'], 1);
      final cars = await me.from('vehicles').select('id, household_id');
      expect(cars, hasLength(2));
      expect(
        cars.every((it) => it['household_id'] == mine),
        isTrue,
        reason: 'every car now belongs to the surviving garage',
      );
      expect(cars.map((it) => it['id']), contains(theirCar));
      expect(await me.from('households').select().eq('id', theirs), isEmpty);
    });

    test('the history comes with the car, still attributed', () async {
      final (me, mine, theirs, them, _) = await twoGarages();
      final theirCar = await carIn(them, theirs, 'Their Clio');
      final theirId = them.auth.currentUser!.id;
      await them.from('fuel_entries').insert({
        'vehicle_id': theirCar,
        'entry_date': '2026-08-01',
        'odometer_km': 12000,
        'volume_l': 38.0,
        'total': 61.0,
        'full_tank': true,
        'created_by': theirId,
      });

      await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      final fills = await me
          .from('fuel_entries')
          .select()
          .eq('vehicle_id', theirCar);
      expect(fills, hasLength(1));
      expect(
        fills.single['created_by'],
        theirId,
        reason: 'who logged it survives the move',
      );
    });

    test('the people come too, keeping the role they had', () async {
      final (me, mine, theirs, them, myId) = await twoGarages();
      final theirId = them.auth.currentUser!.id;

      final result = await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      expect(result['members_moved'], 1);
      final members = await me
          .from('household_members')
          .select('user_id, role')
          .eq('household_id', mine);
      expect(members.map((it) => it['user_id']), containsAll([myId, theirId]));
      expect(
        members.firstWhere((it) => it['user_id'] == theirId)['role'],
        'admin',
        reason: 'they administered their own garage and still do',
      );
    });

    test('a garage in another currency is refused, not converted', () async {
      // Amounts are bare numbers; the currency is on the garage. Merging
      // across them would reinterpret a whole history at a stroke.
      final (me, mine, theirs, them, _) = await twoGarages(
        absorbedCurrency: 'USD',
      );
      await carIn(them, theirs, 'Their Clio');

      await expectLater(
        me.rpc(
          'merge_households',
          params: {'absorbed_household': theirs, 'surviving_household': mine},
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        await me.from('households').select().eq('id', theirs),
        hasLength(1),
      );
    });

    test('a member who is not an admin of both is refused', () async {
      final (me, myId) = await newUser('plain-member');
      final (them, _) = await newUser('the-other');
      final mine = await garageFor(me, 'Mine');
      final theirs = await garageFor(them, 'Theirs');
      final code =
          await them.rpc('create_invite', params: {'target_household': theirs})
              as String;
      await me.rpc('join_household_with_code', params: {'invite_code': code});

      await expectLater(
        me.rpc(
          'merge_households',
          params: {'absorbed_household': theirs, 'surviving_household': mine},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a stranger cannot merge away somebody else\'s garage', () async {
      final (me, _) = await newUser('outsider');
      final mine = await garageFor(me, 'Mine');

      await expectLater(
        me.rpc(
          'merge_households',
          params: {
            'absorbed_household': aliceHousehold,
            'surviving_household': mine,
          },
        ),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        await alice.from('households').select().eq('id', aliceHousehold),
        hasLength(1),
      );
    });

    test('a garage cannot be merged into itself', () async {
      final (me, mine, _, _, _) = await twoGarages();

      await expectLater(
        me.rpc(
          'merge_households',
          params: {'absorbed_household': mine, 'surviving_household': mine},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('custom service types move, and duplicates are dropped', () async {
      final (me, mine, theirs, them, _) = await twoGarages();
      for (final (client, household, key) in [
        (me, mine, 'service_shared'),
        (them, theirs, 'service_shared'),
        (them, theirs, 'service_only_theirs'),
      ]) {
        await client.from('service_types').insert({
          'household_id': household,
          'key': key,
        });
      }

      await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      final keys =
          (await me
                  .from('service_types')
                  .select('key')
                  .eq('household_id', mine))
              .map((it) => it['key']);
      expect(keys, containsAll(['service_shared', 'service_only_theirs']));
      expect(
        keys.where((it) => it == 'service_shared'),
        hasLength(1),
        reason: 'both garages defined it; the survivor keeps its own',
      );
    });

    test(
      'the absorbed garage\'s API keys are revoked, not inherited',
      () async {
        // A key minted to read one garage must not quietly come to read every
        // car in the combined one.
        final (me, mine, theirs, them, _) = await twoGarages();
        await them.from('api_keys').insert({
          'household_id': theirs,
          'name': 'Their script',
          'key_hash': 'a' * 64,
          'key_preview': 'grg_aaaa',
          'created_by': them.auth.currentUser!.id,
        });

        final result = await me.rpc(
          'merge_households',
          params: {'absorbed_household': theirs, 'surviving_household': mine},
        );

        expect(result['keys_revoked'], 1);
        expect(
          await me.from('api_keys').select().eq('household_id', mine),
          isEmpty,
        );
      },
    );

    test('outstanding invites to the old garage stop working', () async {
      final (me, mine, theirs, them, _) = await twoGarages();
      final stale =
          await them.rpc('create_invite', params: {'target_household': theirs})
              as String;

      await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      final (latecomer, _) = await newUser('latecomer');
      await expectLater(
        latecomer.rpc(
          'join_household_with_code',
          params: {'invite_code': stale},
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a car lent out stays lent after the merge', () async {
      // A guest pass keys off the vehicle, so it should be untouched by the
      // car changing garages.
      final (me, mine, theirs, them, _) = await twoGarages();
      final theirCar = await carIn(them, theirs, 'Their Clio');
      final code =
          await them.rpc(
                'create_guest_pass',
                params: {'target_vehicle': theirCar, 'valid_days': 7},
              )
              as String;
      final (borrower, _) = await newUser('borrower');
      await borrower.rpc('redeem_guest_pass', params: {'pass_code': code});

      await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      final seen = await borrower.from('vehicles').select('id');
      expect(seen.map((it) => it['id']), [theirCar]);
    });
  });
}
