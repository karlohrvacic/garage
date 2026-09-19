@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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

  /// The cars a pass lends [who], as the app reads them at startup.
  ///
  /// Not `vehicles`: a borrower has no read on that table at all, because the
  /// row carries what the owner paid for the car. Every "can they reach the
  /// car" question below is asked here, so that a pass that stopped working
  /// cannot pass for one that was never allowed to.
  Future<List<Map<String, dynamic>>> carsLentTo(SupabaseClient who) async {
    final rows = await who.rpc('guest_vehicles') as List<dynamic>;
    return rows.cast<Map<String, dynamic>>();
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
    // On the plan from the start. The suite adds cars to this garage in a
    // dozen groups and never counts them, and the free cap (0080) would stop
    // the sixth in whichever group happened to run sixth. Only the service
    // role may write the column, which the company group checks.
    await admin
        .from('households')
        .update({'plan': 'company'})
        .eq('id', aliceHousehold);

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

    test('vehicle assignments', () async {
      // Alice's garage is on the plan, which the insert policy requires; a
      // car of its own, so the window cannot collide with the one the
      // company group opens on the Golf.
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final car = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': 'Provenance check',
            'fuel_type_key': 'fuel_petrol',
            'created_by': aliceId,
          })
          .select('id')
          .single();
      addTearDown(() => alice.from('vehicles').delete().eq('id', car['id']));
      final assignment = await alice
          .from('vehicle_assignments')
          .insert({
            'vehicle_id': car['id'],
            'user_id': aliceId,
            'from_date': '2026-07-01',
            'created_by': aliceId,
          })
          .select()
          .single();

      await alice
          .from('vehicle_assignments')
          .update({'created_by': bobId})
          .eq('id', assignment['id'] as String);

      final row = await alice
          .from('vehicle_assignments')
          .select('created_by')
          .eq('id', assignment['id'] as String)
          .single();
      expect(row['created_by'], aliceId);
    });

    test('incidents', () async {
      final aliceId = alice.auth.currentUser!.id;
      final bobId = bob.auth.currentUser!.id;
      final incident = await alice
          .from('incidents')
          .insert({
            'vehicle_id': aliceVehicle,
            'kind': 'fault',
            'happened_on': '2026-07-01',
            'description': 'Provenance check',
            'created_by': aliceId,
          })
          .select()
          .single();
      addTearDown(
        () => alice.from('incidents').delete().eq('id', incident['id']),
      );

      await alice
          .from('incidents')
          .update({'created_by': bobId})
          .eq('id', incident['id'] as String);

      final row = await alice
          .from('incidents')
          .select('created_by')
          .eq('id', incident['id'] as String)
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

    test(
      'a member who did not add a hook can choose what it is sent',
      () async {
        // The update the app makes when a row's events are changed, by Bob,
        // who did not create the hook: every member manages the garage's hooks.
        final hook = await alice
            .from('webhooks')
            .insert({
              'household_id': aliceHousehold,
              'url': 'https://example.test/events',
              'secret': 'sssh',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        final id = hook['id'] as String;
        addTearDown(() => alice.from('webhooks').delete().eq('id', id));

        await bob
            .from('webhooks')
            .update({
              'events': ['entry.created'],
            })
            .eq('id', id);
        await carol
            .from('webhooks')
            .update({
              'events': ['reminder.due'],
            })
            .eq('id', id);

        final row = await alice
            .from('webhooks')
            .select('events')
            .eq('id', id)
            .single();
        expect(
          row['events'],
          ['entry.created'],
          reason: 'the member\'s change lands and the stranger\'s does not',
        );
      },
    );

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

  group('webhook outbox and deliveries', () {
    Future<Map<String, dynamic>> hookFor(
      SupabaseClient owner,
      String household,
    ) async => await owner
        .from('webhooks')
        .insert({
          'household_id': household,
          'url': 'https://example.test/outbox',
          'secret': 'sssh',
          'created_by': owner.auth.currentUser!.id,
        })
        .select('id')
        .single();

    test('a member reads the log of their own garage and no other', () async {
      final hook = await hookFor(alice, aliceHousehold);
      addTearDown(() => alice.from('webhooks').delete().eq('id', hook['id']));
      final outbox = await admin
          .from('webhook_outbox')
          .insert({'household_id': aliceHousehold, 'event': 'entry.created'})
          .select('id')
          .single();
      await admin.from('webhook_deliveries').insert({
        'outbox_id': outbox['id'],
        'webhook_id': hook['id'],
        'household_id': aliceHousehold,
        'event': 'entry.created',
        'body': '{}',
        'message': 'hello',
      });

      expect(
        await bob
            .from('webhook_deliveries')
            .select()
            .eq('webhook_id', hook['id']),
        hasLength(1),
        reason: 'the log is the garage\'s, not the creator\'s',
      );
      expect(
        await bob.from('webhook_outbox').select().eq('id', outbox['id']),
        hasLength(1),
        reason: 'and so is the outbox',
      );
      // Scoped to Alice's garage: Carol's own has a `member.joined` row from
      // the moment she created it, which is hers to read.
      expect(
        await carol
            .from('webhook_deliveries')
            .select()
            .eq('household_id', aliceHousehold),
        isEmpty,
      );
      expect(
        await carol
            .from('webhook_outbox')
            .select()
            .eq('household_id', aliceHousehold),
        isEmpty,
      );
    });

    test('a member may ask for a test, and for nothing else', () async {
      await alice.from('webhook_outbox').insert({
        'household_id': aliceHousehold,
        'event': 'test.ping',
      });

      await expectLater(
        alice.from('webhook_outbox').insert({
          'household_id': aliceHousehold,
          'event': 'entry.created',
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        carol.from('webhook_outbox').insert({
          'household_id': aliceHousehold,
          'event': 'test.ping',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a ping is two columns, and a member sets no other', () async {
      // The column grant, not the policy: a ping that chose its payload or
      // its place in the queue would be a member's row at the head of every
      // drain.
      await expectLater(
        alice.from('webhook_outbox').insert({
          'household_id': aliceHousehold,
          'event': 'test.ping',
          'payload': {'note': 'x' * 10000},
        }),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        alice.from('webhook_outbox').insert({
          'household_id': aliceHousehold,
          'event': 'test.ping',
          'created_at': '2020-01-01T00:00:00Z',
        }),
        throwsA(isA<PostgrestException>()),
      );

      final ping = await alice
          .from('webhook_outbox')
          .insert({'household_id': aliceHousehold, 'event': 'test.ping'})
          .select('id, payload')
          .single();
      expect(ping['payload'], {}, reason: 'the two-column ping still works');
    });

    test('nobody writes a delivery through the API', () async {
      final hook = await hookFor(alice, aliceHousehold);
      addTearDown(() => alice.from('webhooks').delete().eq('id', hook['id']));
      final outbox = await admin
          .from('webhook_outbox')
          .insert({'household_id': aliceHousehold, 'event': 'test.ping'})
          .select('id')
          .single();

      await expectLater(
        alice.from('webhook_deliveries').insert({
          'outbox_id': outbox['id'],
          'webhook_id': hook['id'],
          'household_id': aliceHousehold,
          'event': 'test.ping',
          'body': '{}',
          'message': '',
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a member neither changes nor removes a delivery', () async {
      final hook = await hookFor(alice, aliceHousehold);
      addTearDown(() => alice.from('webhooks').delete().eq('id', hook['id']));
      final outbox = await admin
          .from('webhook_outbox')
          .insert({'household_id': aliceHousehold, 'event': 'test.ping'})
          .select('id')
          .single();
      final delivery = await admin
          .from('webhook_deliveries')
          .insert({
            'outbox_id': outbox['id'],
            'webhook_id': hook['id'],
            'household_id': aliceHousehold,
            'event': 'test.ping',
            'body': '{}',
            'message': '',
          })
          .select('id')
          .single();

      // Refused outright, not filtered to no rows: the role holds no update
      // or delete privilege on the table at all.
      await expectLater(
        bob
            .from('webhook_deliveries')
            .update({'last_status': 500})
            .eq('id', delivery['id']),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        bob.from('webhook_deliveries').delete().eq('id', delivery['id']),
        throwsA(isA<PostgrestException>()),
      );

      final row = await admin
          .from('webhook_deliveries')
          .select('last_status')
          .eq('id', delivery['id'])
          .single();
      expect(row['last_status'], isNull, reason: 'unchanged, and still there');
    });

    test(
      'the member who did not add a hook can name, filter and translate it',
      () async {
        final hook = await hookFor(alice, aliceHousehold);
        final id = hook['id'] as String;
        addTearDown(() => alice.from('webhooks').delete().eq('id', id));

        await bob
            .from('webhooks')
            .update({
              'name': 'Kitchen display',
              'vehicle_ids': [aliceVehicle],
              'language': 'hr',
            })
            .eq('id', id);
        await carol.from('webhooks').update({'name': 'Mine now'}).eq('id', id);

        final row = await alice
            .from('webhooks')
            .select('name, vehicle_ids, language')
            .eq('id', id)
            .single();
        expect(row['name'], 'Kitchen display');
        expect(row['vehicle_ids'], [aliceVehicle]);
        expect(row['language'], 'hr');
      },
    );

    test(
      'a hook may take one of the new body shapes, and nothing made up',
      () async {
        final hook = await alice
            .from('webhooks')
            .insert({
              'household_id': aliceHousehold,
              'url': 'https://example.test/plain',
              'secret': 'sssh',
              'format': 'text',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id, format')
            .single();
        addTearDown(() => alice.from('webhooks').delete().eq('id', hook['id']));
        expect(hook['format'], 'text');

        await expectLater(
          alice.from('webhooks').insert({
            'household_id': aliceHousehold,
            'url': 'https://example.test/plain',
            'secret': 'sssh',
            'format': 'nonsense',
            'created_by': alice.auth.currentUser!.id,
          }),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('a fill-up logged, edited and deleted leaves three events', () async {
      final entry = await alice
          .from('fuel_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-09-19',
            'odometer_km': 60000,
            'volume_l': 40,
            'full_tank': true,
            'created_by': alice.auth.currentUser!.id,
          })
          .select('id')
          .single();
      await alice
          .from('fuel_entries')
          .update({'volume_l': 41})
          .eq('id', entry['id']);
      await alice.from('fuel_entries').delete().eq('id', entry['id']);

      final events = await admin
          .from('webhook_outbox')
          .select('event, payload')
          .eq('household_id', aliceHousehold)
          .contains('payload', {
            'record': {'id': entry['id']},
          })
          .order('created_at', ascending: true);
      expect(
        [for (final row in events) row['event']],
        ['entry.created', 'entry.updated', 'entry.deleted'],
      );
      expect(events[1]['payload']['old_record']['volume_l'], 40);
    });

    test('archiving a car is announced, and so is adding one', () async {
      final car = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': 'Outbox car',
            'fuel_type_key': 'fuel_petrol',
            'created_by': alice.auth.currentUser!.id,
          })
          .select('id')
          .single();
      await alice
          .from('vehicles')
          .update({'archived': true})
          .eq('id', car['id']);

      final events = await admin
          .from('webhook_outbox')
          .select('event')
          .eq('household_id', aliceHousehold)
          .contains('payload', {'vehicle_id': car['id']})
          .order('created_at', ascending: true);
      expect(
        [for (final row in events) row['event']],
        ['vehicle.added', 'vehicle.archived'],
      );
    });

    test('a member joining is announced to the garage', () async {
      final events = await admin
          .from('webhook_outbox')
          .select('event, payload')
          .eq('household_id', aliceHousehold)
          .eq('event', 'member.joined');
      expect([
        for (final row in events) row['payload']['user_id'],
      ], containsAll([alice.auth.currentUser!.id, bob.auth.currentUser!.id]));
    });

    /// A car of Alice's that no other test knows about, so a sale or a loan
    /// here leaves the rest of the suite alone.
    Future<String> aliceCar(String nickname) async {
      final row = await alice
          .from('vehicles')
          .insert({
            'household_id': aliceHousehold,
            'nickname': nickname,
            'fuel_type_key': 'fuel_petrol',
            'created_by': alice.auth.currentUser!.id,
          })
          .select('id')
          .single();
      return row['id'] as String;
    }

    /// A fresh buyer with a garage of their own. Not Carol: a bought car
    /// brings its ended loans with it (0070), and Carol has to stay the
    /// stranger who sees no pass at all.
    Future<(SupabaseClient, String)> buyerWithGarage() async {
      final buyer = await signUp(
        'buyer-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(buyer.dispose);
      final garage =
          await buyer.rpc(
                'create_household',
                params: {'household_name': "Buyer's garage"},
              )
              as String;
      return (buyer, garage);
    }

    Future<List<Map<String, dynamic>>> eventsFor(String vehicleId) async =>
        await admin
            .from('webhook_outbox')
            .select('event, household_id')
            .contains('payload', {'vehicle_id': vehicleId})
            .order('created_at', ascending: true);

    test('losing the author is not an edit', () async {
      // Deleting an account nulls created_by on every row the person authored
      // (0033), which is an update of each of them. In a garage of its own,
      // with a member who stays, so the rows outlive the account.
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final stayer = await signUp('stayer-$stamp@example.com');
      addTearDown(stayer.dispose);
      final leaver = await signUp('leaver-$stamp@example.com');
      addTearDown(leaver.dispose);
      final garage =
          await stayer.rpc(
                'create_household',
                params: {'household_name': "Stayer's garage"},
              )
              as String;
      final invite =
          await stayer.rpc(
                'create_invite',
                params: {'target_household': garage},
              )
              as String;
      await leaver.rpc(
        'join_household_with_code',
        params: {'invite_code': invite},
      );
      final car =
          (await stayer
                  .from('vehicles')
                  .insert({
                    'household_id': garage,
                    'nickname': 'Shared',
                    'fuel_type_key': 'fuel_petrol',
                    'created_by': stayer.auth.currentUser!.id,
                  })
                  .select('id')
                  .single())['id']
              as String;
      final entry = await leaver
          .from('fuel_entries')
          .insert({
            'vehicle_id': car,
            'entry_date': '2026-09-18',
            'odometer_km': 1200,
            'volume_l': 35,
            'full_tank': true,
            'created_by': leaver.auth.currentUser!.id,
          })
          .select('id')
          .single();

      await admin.auth.admin.deleteUser(leaver.auth.currentUser!.id);

      final row = await admin
          .from('fuel_entries')
          .select('created_by')
          .eq('id', entry['id'])
          .single();
      expect(row['created_by'], isNull, reason: 'the update did happen');
      final events = await admin
          .from('webhook_outbox')
          .select('event')
          .contains('payload', {
            'record': {'id': entry['id']},
          });
      expect([for (final row in events) row['event']], ['entry.created']);
    });

    test('an archived car sold is handed over, not restored', () async {
      final car = await aliceCar('Sold from the shed');
      await alice.from('vehicles').update({'archived': true}).eq('id', car);
      final (buyer, garage) = await buyerWithGarage();
      final code =
          await alice.rpc(
                'create_vehicle_transfer',
                params: {'target_vehicle': car},
              )
              as String;

      await buyer.rpc(
        'redeem_vehicle_transfer',
        params: {'transfer_code': code, 'target_household': garage},
      );

      final events = await eventsFor(car);
      expect(
        [for (final row in events) row['event']],
        ['vehicle.added', 'vehicle.archived', 'vehicle.handed_over'],
        reason: 'the sale clears `archived`, and that is not a restore',
      );
      expect(
        events.last['household_id'],
        aliceHousehold,
        reason: 'the seller\'s hooks are the ones that knew the car',
      );
    });

    test('a loan ended by a sale is returned to the seller', () async {
      final borrower = await signUp(
        'borrower-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(borrower.dispose);
      final car = await aliceCar('Lent, then sold');
      final pass =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': car, 'valid_days': 7},
              )
              as String;
      await borrower.rpc('redeem_guest_pass', params: {'pass_code': pass});
      final (buyer, garage) = await buyerWithGarage();
      final code =
          await alice.rpc(
                'create_vehicle_transfer',
                params: {'target_vehicle': car},
              )
              as String;

      await buyer.rpc(
        'redeem_vehicle_transfer',
        params: {'transfer_code': code, 'target_household': garage},
      );

      // The sale writes its two rows in one transaction; created_at is
      // clock_timestamp() so that they still read in the order they happened:
      // the loan ends, then the car goes.
      final events = await eventsFor(car);
      expect(
        [for (final row in events) row['event']],
        [
          'vehicle.added',
          'vehicle.lent',
          'vehicle.returned',
          'vehicle.handed_over',
        ],
      );
      expect(
        {for (final row in events) row['household_id']},
        {aliceHousehold},
        reason: 'the loan ended in the seller\'s garage, not the buyer\'s',
      );
    });

    test('a borrower giving the car back is a return', () async {
      final borrower = await signUp(
        'borrower-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(borrower.dispose);
      final car = await aliceCar('Borrowed and back');
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': car, 'valid_days': 7},
              )
              as String;
      await borrower.rpc('redeem_guest_pass', params: {'pass_code': code});
      final pass =
          (await alice
                  .from('vehicle_guest_passes')
                  .select('id')
                  .eq('code', code))
              .single;

      await borrower.rpc('return_guest_pass', params: {'pass_id': pass['id']});

      final events = await eventsFor(car);
      expect(
        [for (final row in events) row['event']],
        ['vehicle.added', 'vehicle.lent', 'vehicle.returned'],
      );
      expect({for (final row in events) row['household_id']}, {aliceHousehold});
    });

    test('a car given back and then withdrawn was returned once', () async {
      final borrower = await signUp(
        'borrower-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(borrower.dispose);
      final car = await aliceCar('Back, then withdrawn');
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': car, 'valid_days': 7},
              )
              as String;
      await borrower.rpc('redeem_guest_pass', params: {'pass_code': code});
      final pass =
          (await alice
                  .from('vehicle_guest_passes')
                  .select('id')
                  .eq('code', code))
              .single;

      await borrower.rpc('return_guest_pass', params: {'pass_id': pass['id']});
      // The owner's withdrawal, as the app writes it (revoke in
      // supabase_guest_pass_repository.dart), of a pass already over.
      await alice
          .from('vehicle_guest_passes')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', pass['id']);

      final returned = await admin
          .from('webhook_outbox')
          .select('event')
          .eq('event', 'vehicle.returned')
          .contains('payload', {
            'record': {'id': pass['id']},
          });
      expect(returned, hasLength(1), reason: 'the loan ended once');
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
    late String sharedAssignment;

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

      // The three tables 0080 added, for the same reason the document is
      // here. The assignment and the reminder both name the leaver as the
      // driver, which is the column a company row points at a person by.
      // The leaver signs the assignment off too: `confirmed_by` is guarded
      // by a trigger, and `on delete set null` is an update it has to let
      // through, or the delete is refused and reports success (0033).
      sharedAssignment =
          await alice.rpc(
                'hand_over_vehicle',
                params: {
                  'target_vehicle': sharedVehicle,
                  'on_date': '2026-07-01',
                  'odometer_km': 4242,
                  'to_user': leaver.auth.currentUser!.id,
                },
              )
              as String;
      await leaver.rpc(
        'confirm_vehicle_assignment',
        params: {'assignment_id': sharedAssignment},
      );
      await leaver.from('incidents').insert({
        'vehicle_id': sharedVehicle,
        'kind': 'damage',
        'happened_on': '2026-07-02',
        'description': 'Scratched the bumper',
        'created_by': leaver.auth.currentUser!.id,
      });
      final fill = await leaver
          .from('fuel_entries')
          .select('id')
          .eq('vehicle_id', sharedVehicle)
          .single();
      await alice.rpc(
        'request_receipt_reminder',
        params: {
          'target_vehicle': sharedVehicle,
          'kind': 'fuel',
          'entry': fill['id'],
          'driver': leaver.auth.currentUser!.id,
        },
      );
    });

    test('an owner who has lent a car can still delete their account', () async {
      // `0033` was a one-shot pass over the constraints that existed then, and
      // `vehicle_guest_passes` was added long afterwards with
      // `created_by not null references auth.users` — the exact refusal 0033
      // removed, reintroduced. It cannot be caught by the setup above because
      // only an admin may mint a pass, and the leaver there is a member.
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final owner = await signUp('lender-$stamp@example.com');
      addTearDown(owner.dispose);
      final household =
          await owner.rpc(
                'create_household',
                params: {'household_name': 'Lender'},
              )
              as String;
      final vehicle =
          (await owner
                  .from('vehicles')
                  .insert({
                    'household_id': household,
                    'nickname': 'Lent',
                    'fuel_type_key': 'fuel_petrol',
                    'created_by': owner.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      await owner.rpc(
        'create_guest_pass',
        params: {'target_vehicle': vehicle, 'valid_days': 7},
      );

      await expectLater(
        admin.auth.admin.deleteUser(owner.auth.currentUser!.id),
        completes,
        reason: 'a minted pass must not refuse the delete',
      );
    });

    test('a guest who borrowed a car can still delete theirs', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final borrower = await signUp('borrower-$stamp@example.com');
      addTearDown(borrower.dispose);
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 7},
              )
              as String;
      await borrower.rpc('redeem_guest_pass', params: {'pass_code': code});

      await expectLater(
        admin.auth.admin.deleteUser(borrower.auth.currentUser!.id),
        completes,
        reason: 'a redeemed pass must not refuse it either',
      );
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
      // The same trap, twice over, on the assignment: the driver and the
      // sign-off are both the leaver, and the sign-off has its own guard.
      final window = await admin
          .from('vehicle_assignments')
          .select('user_id, confirmed_by, confirmed_at')
          .eq('id', sharedAssignment)
          .single();
      expect(window['user_id'], isNull);
      expect(window['confirmed_by'], isNull);
      expect(window['confirmed_at'], isNotNull, reason: 'the fact stays');
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

  group('a fill-up remembers its forecourt', () {
    // `station_ref` (0073) is the price feed's id for the station the app
    // recognised. Written the way the app writes a fill-up: an insert that
    // carries the sheet's own id, then an update of every writable column.
    Map<String, dynamic> writable(Object? ref, {String station = 'Petrol'}) => {
      'vehicle_id': aliceVehicle,
      'entry_date': '2026-09-15',
      'odometer_km': 50600,
      'volume_l': 38.0,
      'full_tank': true,
      'station': station,
      'station_ref': ref,
    };

    String newId() {
      final random = Random.secure();
      final bytes = [for (var i = 0; i < 16; i++) random.nextInt(256)];
      bytes[6] = (bytes[6] & 0x0f) | 0x40;
      bytes[8] = (bytes[8] & 0x3f) | 0x80;
      final hex = [
        for (final byte in bytes) byte.toRadixString(16).padLeft(2, '0'),
      ].join();
      return [
        hex.substring(0, 8),
        hex.substring(8, 12),
        hex.substring(12, 16),
        hex.substring(16, 20),
        hex.substring(20),
      ].join('-');
    }

    Future<String> fillUp(SupabaseClient who, Object? ref) async {
      final id = newId();
      final row = await who
          .from('fuel_entries')
          .insert({
            'id': id,
            ...writable(ref),
            'created_by': who.auth.currentUser!.id,
          })
          .select('station_ref')
          .single();
      addTearDown(() => alice.from('fuel_entries').delete().eq('id', id));
      expect(row['station_ref'], ref);
      return id;
    }

    test('a member writes it, and changes it with the row', () async {
      final id = await fillUp(alice, 1042);

      await alice
          .from('fuel_entries')
          .update(writable(null, station: 'INA'))
          .eq('id', id);

      final row = await alice
          .from('fuel_entries')
          .select('station, station_ref')
          .eq('id', id)
          .single();
      expect(row['station'], 'INA');
      expect(row['station_ref'], isNull);
    });

    test('an id is a positive number or nothing', () async {
      await expectLater(
        fillUp(alice, 0),
        throwsA(
          isA<PostgrestException>().having((e) => e.code, 'code', '23514'),
        ),
      );
    });

    test('a stranger still cannot write one', () async {
      await expectLater(
        fillUp(carol, 1042),
        throwsA(isA<PostgrestException>()),
      );
    });
  });

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

    test(
      'nobody outside the schedule can start the daily reminder run',
      () async {
        // 0027 revoked the function from anon and authenticated by name and
        // left PUBLIC's default grant in place, so anyone holding the key that
        // ships in every app could start the run — and where the run is
        // configured, resend the day's pushes and reminder webhooks at will.
        final anonymous = SupabaseClient(url, anonKey);
        addTearDown(anonymous.dispose);

        for (final (who, client) in [('anon', anonymous), ('member', alice)]) {
          await expectLater(
            client.rpc('run_due_reminders_push'),
            deniedByPrivilege(),
            reason: '$who may not start the run',
          );
        }
      },
    );
  });

  /// Somebody who is not signed in has no business in any of this schema's
  /// functions: every policy is for `authenticated`, and nothing the app does
  /// before sign-in calls one. Supabase's default privileges granted `anon`
  /// every function the migrations created, on top of PUBLIC's, so the
  /// migrations' own `revoke ... from public` never took it away (0077).
  group('a caller who is not signed in', () {
    late SupabaseClient anonymous;

    setUp(() => anonymous = SupabaseClient(url, anonKey));
    tearDown(() => anonymous.dispose());

    /// The functions the API offers whoever holds [token], read from its own
    /// description, which lists only what that role may call. Complete in a
    /// way a list of calls here could never be: a function added next month
    /// shows up without anybody remembering to test it.
    Future<Set<String>> offeredTo(String token) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse('$url/rest/v1/'));
        request.headers
          ..set('apikey', anonKey)
          ..set('Authorization', 'Bearer $token')
          ..set('Accept', 'application/openapi+json');
        final response = await request.close();
        final body =
            jsonDecode(await response.transform(utf8.decoder).join())
                as Map<String, dynamic>;
        return {
          for (final path in (body['paths'] as Map<String, dynamic>).keys)
            if (path.startsWith('/rpc/')) path.substring('/rpc/'.length),
        };
      } finally {
        client.close();
      }
    }

    test('is offered no function at all', () async {
      expect(await offeredTo(anonKey), isEmpty);
    });

    test('while a member is still offered the ones the app calls', () async {
      final offered = await offeredTo(alice.auth.currentSession!.accessToken);

      expect(
        offered,
        containsAll([
          'create_household',
          'guest_vehicles',
          'describe_code',
          'join_household_with_code',
        ]),
      );
      // Not the two only the server calls: the API key lookup, which the
      // public API makes with the service role, and a trigger's helper.
      expect(offered, isNot(contains('household_for_api_key')));
      expect(offered, isNot(contains('ensure_household_has_admin')));
    });

    test('and is refused when calling one anyway', () async {
      for (final (name, params) in [
        ('describe_code', {'candidate': 'ABCDEFGH'}),
        ('create_household', {'household_name': 'Nobody'}),
        ('guest_vehicles', <String, dynamic>{}),
        ('household_for_api_key', {'key_hash_input': 'a' * 64}),
      ]) {
        await expectLater(
          anonymous.rpc(name, params: params),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
          reason: name,
        );
      }
      // The positive control: the same call, signed in, is answered.
      expect(
        await alice.rpc('describe_code', params: {'candidate': 'ABCDEFGH'}),
        isNull,
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

    group('what a borrower is told about the car itself', () {
      // A pass holder has to see what they are logging against, but not the
      // whole row: it carries what the owner paid for the car and what they
      // think it is worth. Postgres cannot hide a column from a policy, so the
      // table is closed to borrowers and a function hands them the rest.
      setUp(() async {
        await alice
            .from('vehicles')
            .update({
              'purchase_price': 18500,
              'current_value': 9200,
              'valued_on': '2026-09-01',
            })
            .eq('id', aliceVehicle);
      });

      tearDown(() async {
        await alice
            .from('vehicles')
            .update({
              'purchase_price': null,
              'current_value': null,
              'valued_on': null,
            })
            .eq('id', aliceVehicle);
      });

      test('the owner still reads every figure', () async {
        final row = await alice
            .from('vehicles')
            .select('purchase_price, current_value, valued_on')
            .eq('id', aliceVehicle)
            .single();

        expect(row['purchase_price'], 18500);
        expect(row['current_value'], 9200);
      });

      test('a borrower reads the car, without what it cost', () async {
        await redeemed(history: true);

        final cars = await carsLentTo(guest);
        expect(cars, hasLength(1));
        final car = cars.single;
        expect(car['id'], aliceVehicle);
        expect(car['nickname'], 'Golf');
        expect(car['fuel_type_key'], 'fuel_diesel');
        for (final withheld in [
          'purchase_price',
          'current_value',
          'valued_on',
          'photo_path',
          'created_by',
        ]) {
          expect(car.containsKey(withheld), isFalse, reason: withheld);
        }
      });

      test('and cannot read the row behind it', () async {
        await redeemed(history: true);

        expect(
          await guest
              .from('vehicles')
              .select('purchase_price, current_value')
              .eq('id', aliceVehicle),
          isEmpty,
        );
      });

      test('a stranger is lent nothing', () async {
        expect(await carsLentTo(carol), isEmpty);
      });

      test('an owner is not lent their own cars', () async {
        await redeemed();

        expect(await carsLentTo(alice), isEmpty);
      });

      test(
        'a borrower who joins the garage reads the car as a member',
        () async {
          // The pass outlives the invite, so both answer for the same car. The
          // function leaves out a car the caller is a member for, and the table
          // hands it back whole: the app keeps the table's row, figures and all.
          await redeemed();
          final code =
              await alice.rpc(
                    'create_invite',
                    params: {'target_household': aliceHousehold},
                  )
                  as String;
          await guest.rpc(
            'join_household_with_code',
            params: {'invite_code': code},
          );
          addTearDown(
            () => alice
                .from('household_members')
                .delete()
                .eq('household_id', aliceHousehold)
                .eq('user_id', guestId),
          );

          expect(await carsLentTo(guest), isEmpty);
          final row = await guest
              .from('vehicles')
              .select('purchase_price, current_value')
              .eq('id', aliceVehicle)
              .single();
          expect(row['purchase_price'], 18500);
          expect(row['current_value'], 9200);
        },
      );
    });

    test('before redeeming, the holder is simply a stranger', () async {
      await mintPass();

      final vehicles = await carsLentTo(guest);

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

      final vehicles = await carsLentTo(guest);
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

      expect(await carsLentTo(guest), isEmpty);
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

      expect(await carsLentTo(guest), isEmpty);
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

      expect(await carsLentTo(guest), isEmpty);
    });

    // A loan is a window, an extension is a window moved, and a mechanic may
    // be shown the work without the money. The last of those is the only one
    // that cannot be done in the app: Postgres has no column masking, so
    // "history without prices" is not a narrower row grant — it is no row
    // grant at all, plus a function that decides column by column.
    group('a window, an extension, and prices held back', () {
      // Its own row, not another group's leftovers: a partial run that leaves
      // the table empty must not turn "the masked history says what was done"
      // into a test that passes by finding nothing.
      setUp(() async {
        await alice.from('service_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-03-04',
          'odometer_km': 180000,
          'service_type_keys': ['service_timing_belt'],
          'cost': 240.0,
          'shop': 'Autoservis Kovač',
          'created_by': alice.auth.currentUser!.id,
        });
      });

      Future<String> mintBetween({
        DateTime? startsOn,
        DateTime? endsOn,
        bool history = false,
        bool prices = false,
      }) async {
        return await alice.rpc(
              'create_guest_pass_between',
              params: {
                'target_vehicle': aliceVehicle,
                'ends_on':
                    (endsOn ??
                            DateTime.now().toUtc().add(const Duration(days: 4)))
                        .toIso8601String(),
                'starts_on': startsOn?.toIso8601String(),
                'allow_history': history,
                'allow_prices': prices,
              },
            )
            as String;
      }

      test('a window that ends before it starts is refused', () async {
        await expectLater(
          mintBetween(
            startsOn: DateTime.now().toUtc().add(const Duration(days: 5)),
            endsOn: DateTime.now().toUtc().add(const Duration(days: 2)),
          ),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('a window longer than a year is refused', () async {
        await expectLater(
          mintBetween(
            endsOn: DateTime.now().toUtc().add(const Duration(days: 400)),
          ),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('a pass booked for later grants nothing until it opens', () async {
        final code = await mintBetween(
          startsOn: DateTime.now().toUtc().add(const Duration(days: 2)),
          endsOn: DateTime.now().toUtc().add(const Duration(days: 5)),
        );
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        expect(await carsLentTo(guest), isEmpty);
      });

      test(
        'the owner can move the end, and the holder keeps the code',
        () async {
          final code = await mintBetween(
            endsOn: DateTime.now().toUtc().add(const Duration(hours: 1)),
          );
          await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

          await alice
              .from('vehicle_guest_passes')
              .update({
                'expires_at': DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 3))
                    .toIso8601String(),
              })
              .eq('code', code);

          // The positive control: still the same pass, still working.
          expect(await carsLentTo(guest), hasLength(1));
          final pass = await guest.from('vehicle_guest_passes').select();
          expect(pass.single['code'], code);
        },
      );

      test('a stranger cannot extend somebody else\'s pass', () async {
        final code = await mintBetween();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});
        final before =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single['expires_at'];

        await carol
            .from('vehicle_guest_passes')
            .update({
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 300))
                  .toIso8601String(),
            })
            .eq('code', code);

        final after =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single['expires_at'];
        expect(after, before);
      });

      test('the holder cannot extend their own pass either', () async {
        final code = await mintBetween();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});
        final before =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single['expires_at'];

        await guest
            .from('vehicle_guest_passes')
            .update({
              'expires_at': DateTime.now()
                  .toUtc()
                  .add(const Duration(days: 300))
                  .toIso8601String(),
            })
            .eq('code', code);

        final after =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single['expires_at'];
        expect(after, before, reason: 'a borrower does not extend their loan');
      });

      test('prices without history are dropped rather than granted', () async {
        final code = await mintBetween(history: false, prices: true);

        final row =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single;
        expect(row['can_view_prices'], isFalse);
      });

      test('a pass that hides prices grants no rows at all', () async {
        final code = await mintBetween(history: true, prices: false);
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        // Not a UI choice: the rows carrying the money are not readable.
        expect(await guest.from('fuel_entries').select(), isEmpty);
        expect(await guest.from('service_entries').select(), isEmpty);
      });

      test('but the masked history still says what was done', () async {
        final code = await mintBetween(history: true, prices: false);
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        final rows =
            await guest.rpc(
                  'guest_service_history',
                  params: {'target_vehicle': aliceVehicle},
                )
                as List<dynamic>;

        expect(rows, isNotEmpty, reason: 'the positive control');
        for (final row in rows.cast<Map<String, dynamic>>()) {
          expect(row['cost'], isNull, reason: 'the money is the masked part');
          expect(row['service_type_keys'], isNotEmpty);
        }
      });

      test('a pass that carries prices carries the figures', () async {
        final code = await mintBetween(history: true, prices: true);
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        final rows =
            await guest.rpc(
                  'guest_service_history',
                  params: {'target_vehicle': aliceVehicle},
                )
                as List<dynamic>;

        expect(
          rows.cast<Map<String, dynamic>>().any((row) => row['cost'] != null),
          isTrue,
        );
      });

      test(
        'the owner reads their own history through it, prices and all',
        () async {
          final rows =
              await alice.rpc(
                    'guest_service_history',
                    params: {'target_vehicle': aliceVehicle},
                  )
                  as List<dynamic>;

          expect(rows, isNotEmpty);
          expect(
            rows.cast<Map<String, dynamic>>().any((row) => row['cost'] != null),
            isTrue,
          );
        },
      );

      test('a stranger gets nothing from it', () async {
        final rows =
            await carol.rpc(
                  'guest_service_history',
                  params: {'target_vehicle': aliceVehicle},
                )
                as List<dynamic>;

        expect(rows, isEmpty);
      });
    });

    // A borrower saw the vehicle's baseline odometer, because they cannot read
    // the tables the real reading lives in. One function answers the whole
    // question — how far, what paperwork runs out, what is wrong, what it
    // stands on — and grants no rows to do it.
    group('what a borrower is always shown', () {
      setUp(() async {
        // Idempotent: one document of each capped type per vehicle is a
        // unique index, so a second run of this group's fixtures would fail
        // on the paperwork rather than on anything it set out to test.
        await alice
            .from('vehicle_documents')
            .delete()
            .eq('vehicle_id', aliceVehicle);
        await alice
            .from('observations')
            .delete()
            .eq('vehicle_id', aliceVehicle);
        await alice.from('odometer_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-01',
          'odometer_km': 184320,
          'created_by': alice.auth.currentUser!.id,
        });
        await alice.from('vehicle_documents').insert({
          'vehicle_id': aliceVehicle,
          'doc_type': 'green_card',
          'number': 'GC-99887766',
          'issuer': 'Croatia osiguranje',
          'expires_on': '2027-03-03',
          'created_by': alice.auth.currentUser!.id,
        });
        await alice.from('observations').insert({
          'vehicle_id': aliceVehicle,
          'noticed_on': '2026-08-14',
          'note': 'Rattle at the front when cold',
          'created_by': alice.auth.currentUser!.id,
        });
      });

      Future<Map<String, dynamic>?> briefingFor(SupabaseClient who) async {
        final result = await who.rpc(
          'guest_vehicle_briefing',
          params: {'target_vehicle': aliceVehicle},
        );
        return result as Map<String, dynamic>?;
      }

      test('the odometer is the real one, not the baseline', () async {
        final code = await mintPass();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        final briefing = await briefingFor(guest);

        expect(briefing!['odometer_km'], 184320);
        // The positive control on the other side: the rows themselves stay
        // out of reach, which is the whole reason this function exists.
        expect(await guest.from('odometer_entries').select(), isEmpty);
      });

      test('a paper is a type and a date, never its number', () async {
        final code = await mintPass();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        final briefing = await briefingFor(guest);
        final papers = (briefing!['documents'] as List).cast<Map>();

        expect(papers, hasLength(1));
        expect(papers.single['type'], 'green_card');
        expect(papers.single['expires_on'], '2027-03-03');
        expect(papers.single.containsKey('number'), isFalse);
        expect(papers.single.containsKey('issuer'), isFalse);
        expect(await guest.from('vehicle_documents').select(), isEmpty);
      });

      test('what is known to be wrong with it comes across', () async {
        final code = await mintPass();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        final briefing = await briefingFor(guest);
        final problems = (briefing!['problems'] as List).cast<Map>();

        expect(problems, hasLength(1));
        expect(problems.single['note'], 'Rattle at the front when cold');
      });

      test('a stranger is told nothing at all', () async {
        expect(await briefingFor(carol), isNull);
      });

      test('an expired pass stops answering, without an error', () async {
        final code = await mintPass();
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});
        await alice
            .from('vehicle_guest_passes')
            .update({
              'expires_at': DateTime.now()
                  .toUtc()
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
            })
            .eq('code', code);

        expect(await briefingFor(guest), isNull);
      });

      test(
        'the owner asks the same question and gets the same shape',
        () async {
          final briefing = await briefingFor(alice);

          expect(briefing!['odometer_km'], 184320);
        },
      );
    });

    // The borrower's own way out. Withdrawing belongs to the owner and expiry
    // belongs to the clock; handing the keys back belongs to whoever has them.
    group('giving the car back', () {
      test('ends access at once, and keeps what they logged', () async {
        final code = await redeemed();
        await guest.from('fuel_entries').insert({
          'vehicle_id': aliceVehicle,
          'entry_date': '2026-09-08',
          'odometer_km': 60050,
          'volume_l': 30.0,
          'total': 50.0,
          'full_tank': true,
          'created_by': guestId,
        });
        final pass =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single;

        await guest.rpc('return_guest_pass', params: {'pass_id': pass['id']});

        expect(await carsLentTo(guest), isEmpty);
        expect(
          await alice.from('fuel_entries').select().eq('created_by', guestId),
          isNotEmpty,
          reason: 'what they logged stays with the car',
        );
      });

      test('a stranger cannot give somebody else\'s pass back', () async {
        final code = await redeemed();
        final pass =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single;

        await expectLater(
          carol.rpc('return_guest_pass', params: {'pass_id': pass['id']}),
          throwsA(isA<PostgrestException>()),
        );
        // The positive control: still working for the person it belongs to.
        expect(await carsLentTo(guest), hasLength(1));
      });

      test('the owner cannot give it back on their behalf', () async {
        // They have `revoke` for that, and the two mean different things.
        final code = await redeemed();
        final pass =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single;

        await expectLater(
          alice.rpc('return_guest_pass', params: {'pass_id': pass['id']}),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('giving it back twice is refused rather than silent', () async {
        final code = await redeemed();
        final pass =
            (await alice.from('vehicle_guest_passes').select().eq('code', code))
                .single;
        await guest.rpc('return_guest_pass', params: {'pass_id': pass['id']});

        await expectLater(
          guest.rpc('return_guest_pass', params: {'pass_id': pass['id']}),
          throwsA(isA<PostgrestException>()),
        );
      });
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

        expect(await carsLentTo(guest), hasLength(1));
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

        final own = await guest.from('vehicles').select();
        final lent = await carsLentTo(guest);
        final households = await guest.from('households').select();

        expect(
          [...own, ...lent].map((it) => it['id']),
          containsAll([ownVehicle, aliceVehicle]),
          reason: 'both the guest\'s own car and the borrowed one',
        );
        expect(
          own.map((it) => it['id']),
          [ownVehicle],
          reason: 'the table is the guest\'s own garage and nothing else',
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

    group('the car is sold while it is on loan', () {
      // A pass is keyed to the vehicle, and a sale changes the vehicle's
      // garage and nothing else. Left alone, somebody the seller lent the car
      // to would go on holding the buyer's car: a garage's data reachable by a
      // person that garage never let in. A merge keeps its passes on purpose,
      // because the people who issued them come along; a sale does not.
      late String soldCar;
      late String buyerGarage;

      setUp(() async {
        soldCar =
            (await alice
                    .from('vehicles')
                    .insert({
                      'household_id': aliceHousehold,
                      'nickname': 'Lent, then sold',
                      'fuel_type_key': 'fuel_petrol',
                      'created_by': alice.auth.currentUser!.id,
                    })
                    .select()
                    .single())['id']
                as String;
        final pass =
            await alice.rpc(
                  'create_guest_pass',
                  params: {
                    'target_vehicle': soldCar,
                    'valid_days': 365,
                    'allow_fuel': true,
                    'allow_trips': true,
                    'allow_costs': true,
                    'allow_history': true,
                  },
                )
                as String;
        await guest.rpc('redeem_guest_pass', params: {'pass_code': pass});

        buyerGarage =
            await carol.rpc(
                  'create_household',
                  params: {'household_name': "The buyer's garage"},
                )
                as String;
      });

      Future<void> sell() async {
        final code =
            await alice.rpc(
                  'create_vehicle_transfer',
                  params: {'target_vehicle': soldCar},
                )
                as String;
        await carol.rpc(
          'redeem_vehicle_transfer',
          params: {'transfer_code': code, 'target_household': buyerGarage},
        );
      }

      test('the borrower loses the car the moment it changes hands', () async {
        // The positive control: without it, a pass that never worked would
        // pass every assertion below.
        final before = await carsLentTo(guest);
        expect(before.map((it) => it['id']), [soldCar]);

        await sell();

        expect(await carsLentTo(guest), isEmpty);
        expect(
          await guest.rpc(
            'guest_vehicle_briefing',
            params: {'target_vehicle': soldCar},
          ),
          isNull,
        );
      });

      test('and reads nothing the buyer goes on to log', () async {
        await sell();
        await carol.from('fuel_entries').insert({
          'vehicle_id': soldCar,
          'entry_date': '2026-09-10',
          'odometer_km': 2000,
          'volume_l': 41.0,
          'total': 66.0,
          'full_tank': true,
          'created_by': carol.auth.currentUser!.id,
        });

        final seen = await guest
            .from('fuel_entries')
            .select('id')
            .eq('vehicle_id', soldCar);

        expect(
          seen,
          isEmpty,
          reason: 'history was on, and the car is not theirs',
        );
      });

      test('and can no longer log against it', () async {
        await sell();

        await expectLater(
          guest.from('fuel_entries').insert({
            'vehicle_id': soldCar,
            'entry_date': '2026-09-11',
            'odometer_km': 2100,
            'volume_l': 12.0,
            'full_tank': false,
            'created_by': guestId,
          }),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('a code handed out and never claimed dies with the sale', () async {
        // Otherwise it opens the buyer's car the day somebody types it in.
        final unclaimed =
            await alice.rpc(
                  'create_guest_pass',
                  params: {'target_vehicle': soldCar, 'valid_days': 30},
                )
                as String;
        final latecomer = await signUp(
          'late-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        addTearDown(latecomer.dispose);

        await sell();

        await expectLater(
          latecomer.rpc('redeem_guest_pass', params: {'pass_code': unclaimed}),
          throwsA(isA<PostgrestException>()),
        );
      });

      test('a pass booked ahead is withdrawn before it ever starts', () async {
        await alice.rpc(
          'create_guest_pass',
          params: {
            'target_vehicle': soldCar,
            'valid_days': 30,
            'starts_on': DateTime.now()
                .toUtc()
                .add(const Duration(days: 10))
                .toIso8601String(),
          },
        );

        await sell();

        final passes = await carol
            .from('vehicle_guest_passes')
            .select('revoked_at, starts_at')
            .eq('vehicle_id', soldCar)
            .not('starts_at', 'is', null);
        expect(passes.single['revoked_at'], isNotNull);
      });

      test('a loan that was already over keeps the ending it had', () async {
        // Lending shows how each pass ended. One handed back last week should
        // go on saying so, not turn into "withdrawn" on the day of the sale.
        final mine = await guest
            .from('vehicle_guest_passes')
            .select('id')
            .eq('vehicle_id', soldCar)
            .single();
        await guest.rpc('return_guest_pass', params: {'pass_id': mine['id']});

        await sell();

        final pass = await carol
            .from('vehicle_guest_passes')
            .select('revoked_at, returned_at')
            .eq('id', mine['id'] as String)
            .single();
        expect(pass['returned_at'], isNotNull);
        expect(pass['revoked_at'], isNull);
      });

      test('the buyer finds the pass already withdrawn, not live', () async {
        await sell();

        final passes = await carol
            .from('vehicle_guest_passes')
            .select('revoked_at')
            .eq('vehicle_id', soldCar);

        expect(passes, hasLength(1));
        expect(
          passes.single['revoked_at'],
          isNotNull,
          reason:
              'a buyer should not have to find Lending to end a loan '
              'they never made',
        );
      });
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

      final seen = await carsLentTo(borrower);
      expect(seen.map((it) => it['id']), [theirCar]);
    });

    // Routes belong to the garage, not to a car, so moving the cars does not
    // move them, and deleting the absorbed garage cascades them away. The
    // trips survive with `route_id` set to null: a commute's whole trend gone,
    // in an operation that cannot be undone.
    Future<String> routeIn(
      SupabaseClient who,
      String household,
      String name,
    ) async {
      final row = await who
          .from('routes')
          .insert({
            'household_id': household,
            'name': name,
            'created_by': who.auth.currentUser!.id,
          })
          .select()
          .single();
      return row['id'] as String;
    }

    Future<String> tripOn(
      SupabaseClient who,
      String vehicle,
      String route,
    ) async {
      final row = await who
          .from('trip_entries')
          .insert({
            'vehicle_id': vehicle,
            'entry_date': '2026-09-01',
            'distance_km': 22.0,
            'minutes': 35,
            'route_id': route,
            'created_by': who.auth.currentUser!.id,
          })
          .select()
          .single();
      return row['id'] as String;
    }

    test('named routes come along, and their journeys stay on them', () async {
      final (me, mine, theirs, them, _) = await twoGarages();
      final theirCar = await carIn(them, theirs, 'Their Clio');
      final commute = await routeIn(them, theirs, 'Home to work');
      final trip = await tripOn(them, theirCar, commute);

      await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      final routes = await me.from('routes').select('id, household_id');
      expect(routes.map((it) => it['id']), contains(commute));
      expect(routes.every((it) => it['household_id'] == mine), isTrue);
      final moved = await me
          .from('trip_entries')
          .select('route_id')
          .eq('id', trip)
          .single();
      expect(moved['route_id'], commute);
    });

    test('a route both garages named becomes one route', () async {
      // `routes_unique_name` allows one name per garage whatever the case, so
      // the absorbed one cannot simply be re-homed beside its namesake.
      final (me, mine, theirs, them, _) = await twoGarages();
      final myCar = await carIn(me, mine, 'My Golf');
      final theirCar = await carIn(them, theirs, 'Their Clio');
      final kept = await routeIn(me, mine, 'Home to work');
      final folded = await routeIn(them, theirs, 'home to WORK');
      final myTrip = await tripOn(me, myCar, kept);
      final theirTrip = await tripOn(them, theirCar, folded);

      await me.rpc(
        'merge_households',
        params: {'absorbed_household': theirs, 'surviving_household': mine},
      );

      final routes = await me.from('routes').select('id');
      expect(routes.map((it) => it['id']), [kept]);
      final trips = await me
          .from('trip_entries')
          .select('id, route_id')
          .inFilter('id', [myTrip, theirTrip]);
      expect(
        trips.map((it) => it['route_id']),
        everyElement(kept),
        reason: 'both commutes now share the one history the name promised',
      );
    });
  });

  group('observations', () {
    // Something noticed and not yet settled. The interesting column pair is
    // `addressed_by` (a mechanic did work) and `resolved_on` (the noise
    // actually stopped), because a repair can be recorded while the symptom
    // continues.
    Future<String> notice(
      SupabaseClient who, {
      required String vehicleId,
      String note = 'Rattles at the front when cold',
      String noticedOn = '2026-09-01',
    }) async {
      final row = await who
          .from('observations')
          .insert({
            'vehicle_id': vehicleId,
            'noticed_on': noticedOn,
            'note': note,
            'odometer_km': 142300,
            'created_by': who.auth.currentUser!.id,
          })
          .select()
          .single();
      return row['id'] as String;
    }

    test('a member can record one, and it starts open', () async {
      final id = await notice(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      final row =
          (await alice.from('observations').select().eq('id', id)).single;
      expect(row['resolved_on'], isNull);
      expect(row['addressed_by'], isNull);
      expect(row['note'], 'Rattles at the front when cold');
    });

    test('a stranger cannot see it, or add one', () async {
      final id = await notice(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      expect(await carol.from('observations').select().eq('id', id), isEmpty);
      await expectLater(
        carol.from('observations').insert({
          'vehicle_id': aliceVehicle,
          'noticed_on': '2026-09-01',
          'note': 'Not mine to report',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('another member can see and settle it', () async {
      // One person hears the rattle, another takes the car in. Both are in the
      // garage, and the observation belongs to the car.
      final helper = await signUp(
        'noticer-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(helper.dispose);
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;
      await helper.rpc(
        'join_household_with_code',
        params: {'invite_code': code},
      );
      final id = await notice(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      await helper
          .from('observations')
          .update({'resolved_on': '2026-09-10'})
          .eq('id', id);

      final row =
          (await alice.from('observations').select().eq('id', id)).single;
      expect(row['resolved_on'], '2026-09-10');
      expect(
        row['created_by'],
        alice.auth.currentUser!.id,
        reason: 'settling somebody else\'s observation does not claim it',
      );
    });

    test('work performed and symptom gone are recorded separately', () async {
      // The case that matters: the garage did the work and the noise is still
      // there. A single "done" flag cannot say that.
      final service =
          (await alice
                  .from('service_entries')
                  .insert({
                    'vehicle_id': aliceVehicle,
                    'entry_date': '2026-09-08',
                    'odometer_km': 142500,
                    'service_type_keys': ['service_brake_fluid'],
                    'created_by': alice.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      addTearDown(
        () => alice.from('service_entries').delete().eq('id', service),
      );
      final id = await notice(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      await alice
          .from('observations')
          .update({'addressed_by': service})
          .eq('id', id);

      final row =
          (await alice.from('observations').select().eq('id', id)).single;
      expect(row['addressed_by'], service);
      expect(
        row['resolved_on'],
        isNull,
        reason: 'the work happened; the rattle has not been declared gone',
      );
    });

    test('a resolution before the sighting is refused', () async {
      await expectLater(
        alice.from('observations').insert({
          'vehicle_id': aliceVehicle,
          'noticed_on': '2026-09-10',
          'resolved_on': '2026-09-01',
          'note': 'Backwards',
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('an empty note is refused', () async {
      await expectLater(
        alice.from('observations').insert({
          'vehicle_id': aliceVehicle,
          'noticed_on': '2026-09-01',
          'note': '',
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('deleting the trip it happened on keeps the observation', () async {
      final trip =
          (await alice
                  .from('trip_entries')
                  .insert({
                    'vehicle_id': aliceVehicle,
                    'entry_date': '2026-09-01',
                    'distance_km': 40.0,
                    'created_by': alice.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      final row = await alice
          .from('observations')
          .insert({
            'vehicle_id': aliceVehicle,
            'trip_id': trip,
            'noticed_on': '2026-09-01',
            'note': 'Pothole, then a vibration',
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      final id = row['id'] as String;
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      await alice.from('trip_entries').delete().eq('id', trip);

      final after =
          (await alice.from('observations').select().eq('id', id)).single;
      expect(after['trip_id'], isNull);
      expect(
        after['note'],
        'Pothole, then a vibration',
        reason: 'the journey went; the fact that something started did not',
      );
    });

    test('a photo can be attached to one', () async {
      final id = await notice(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      await alice.from('attachments').insert({
        'vehicle_id': aliceVehicle,
        'entry_kind': 'observation',
        'entry_id': id,
        'storage_path': '$aliceVehicle/photo.jpg',
        'file_name': 'photo.jpg',
        'created_by': alice.auth.currentUser!.id,
      });

      final rows = await alice.from('attachments').select().eq('entry_id', id);
      expect(rows, hasLength(1));
    });

    test('a guest cannot record one', () async {
      // Deliberately not granted: it is a permission question the pass has no
      // column for, and guessing at it would widen a borrower's reach.
      final guest = await signUp(
        'obs-guest-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(guest.dispose);
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 7},
              )
              as String;
      await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

      await expectLater(
        guest.from('observations').insert({
          'vehicle_id': aliceVehicle,
          'noticed_on': '2026-09-01',
          'note': 'Borrowed and rattling',
          'created_by': guest.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
      expect(await guest.from('observations').select(), isEmpty);
    });

    test('a photo of what was noticed can hang off it', () async {
      // The check constraint learned a fifth entry kind in 0060 and the app
      // could not write one until September 6th — the Dart enum had never been
      // widened with it. A constraint nobody exercises is a promise nobody
      // checked.
      final id = await notice(alice, vehicleId: aliceVehicle);
      addTearDown(() => alice.from('observations').delete().eq('id', id));

      await alice.from('attachments').insert({
        'vehicle_id': aliceVehicle,
        'entry_kind': 'observation',
        'entry_id': id,
        'storage_path': '$aliceVehicle/crack.jpg',
        'file_name': 'crack.jpg',
        'created_by': alice.auth.currentUser!.id,
      });
      addTearDown(() => alice.from('attachments').delete().eq('entry_id', id));

      final rows = await alice
          .from('attachments')
          .select('file_name')
          .eq('entry_id', id);
      expect(rows.single['file_name'], 'crack.jpg');

      expect(
        await carol.from('attachments').select().eq('entry_id', id),
        isEmpty,
        reason: 'a photo is visible to whoever can see the car it hangs off',
      );
    });
  });

  // Three kinds of eight-character code exist and whoever holds one cannot
  // tell which it is. This says what a code is without spending it, so the app
  // can describe what redeeming will do before somebody agrees to it.
  group('what is this code', () {
    Future<Map<String, dynamic>?> describe(
      SupabaseClient who,
      String code,
    ) async {
      final result = await who.rpc(
        'describe_code',
        params: {'candidate': code},
      );
      return result as Map<String, dynamic>?;
    }

    test('a lending code names the car and when it ends', () async {
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 3},
              )
              as String;
      final other = await signUp(
        'code-reader-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(other.dispose);

      final described = await describe(other, code);

      expect(described!['kind'], 'lending');
      expect(described['subject'], isNotEmpty);
      expect(described['spent'], isFalse);
    });

    test('lowercase and spaces are the same code', () async {
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 3},
              )
              as String;

      final described = await describe(carol, '  ${code.toLowerCase()} ');

      expect(described!['kind'], 'lending');
    });

    test('a garage invite is told apart from a lending pass', () async {
      final invite =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;

      final described = await describe(carol, invite);

      expect(described!['kind'], 'invite');
      expect(
        described['member'],
        isFalse,
        reason: 'carol is not in the garage the invite is for',
      );
    });

    // The same link opened twice. The join would be accepted and change
    // nothing, so the app needs to know not to offer it — and only about the
    // caller, never about anybody else.
    test(
      'an invite says whether the caller is already in that garage',
      () async {
        final invite =
            await alice.rpc(
                  'create_invite',
                  params: {'target_household': aliceHousehold},
                )
                as String;

        final described = await describe(alice, invite);

        expect(described!['member'], isTrue);
      },
    );

    test('a lending code never claims membership', () async {
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 3},
              )
              as String;

      final described = await describe(alice, code);

      expect(described!['member'], isFalse);
    });

    test('a code nobody issued is simply unknown', () async {
      expect(await describe(carol, 'ZZZZ9999'), isNull);
    });

    test('a code of the wrong length is unknown, not an error', () async {
      expect(await describe(carol, 'ABC'), isNull);
    });

    test('a spent pass says so rather than pretending', () async {
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 3},
              )
              as String;
      await alice
          .from('vehicle_guest_passes')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('code', code);

      final described = await describe(carol, code);

      expect(described!['spent'], isTrue);
    });
  });

  group('what a car takes', () {
    // Roadmap item 12, the half that needs no data: a household looks a part
    // number up once and the app remembers. Scoped to the vehicle like
    // everything else, and readable by a guest holding the car, who is
    // exactly the person about to buy the wrong filter.
    test('a member can record one, and read it back', () async {
      await alice.from('vehicle_parts').insert({
        'vehicle_id': aliceVehicle,
        'service_type_key': 'service_oil_change',
        'spec': '5W-30 ACEA C3',
        'created_by': alice.auth.currentUser!.id,
      });

      final rows = await alice
          .from('vehicle_parts')
          .select()
          .eq('vehicle_id', aliceVehicle);
      expect(rows.any((r) => r['spec'] == '5W-30 ACEA C3'), isTrue);
    });

    test('a stranger sees none, and cannot add one', () async {
      expect(await carol.from('vehicle_parts').select(), isEmpty);
      await expectLater(
        carol.from('vehicle_parts').insert({
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_oil_filter',
          'spec': 'W 712/95',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('one answer per job per car', () async {
      await alice.from('vehicle_parts').upsert({
        'vehicle_id': aliceVehicle,
        'service_type_key': 'service_wipers',
        'spec': '600 mm / 400 mm',
        'created_by': alice.auth.currentUser!.id,
      }, onConflict: 'vehicle_id,service_type_key');
      // The correction path the app uses: same job, better answer.
      await alice.from('vehicle_parts').upsert({
        'vehicle_id': aliceVehicle,
        'service_type_key': 'service_wipers',
        'spec': '650 mm / 400 mm',
        'created_by': alice.auth.currentUser!.id,
      }, onConflict: 'vehicle_id,service_type_key');

      final rows = await alice
          .from('vehicle_parts')
          .select()
          .eq('vehicle_id', aliceVehicle)
          .eq('service_type_key', 'service_wipers');
      expect(rows, hasLength(1));
      expect(rows.single['spec'], '650 mm / 400 mm');
    });

    test('an empty spec is refused', () async {
      await expectLater(
        alice.from('vehicle_parts').insert({
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_bulbs',
          'spec': '   ',
          'created_by': alice.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test(
      'a guest holding the car can read them, and cannot change them',
      () async {
        await alice.from('vehicle_parts').upsert({
          'vehicle_id': aliceVehicle,
          'service_type_key': 'service_cabin_filter',
          'spec': 'CUK 2939',
          'created_by': alice.auth.currentUser!.id,
        }, onConflict: 'vehicle_id,service_type_key');
        final guest = await signUp(
          'parts-guest-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        addTearDown(guest.dispose);
        final code =
            await alice.rpc(
                  'create_guest_pass',
                  params: {'target_vehicle': aliceVehicle, 'valid_days': 3},
                )
                as String;
        await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

        final seen = await guest.from('vehicle_parts').select();
        expect(
          seen.any((r) => r['spec'] == 'CUK 2939'),
          isTrue,
          reason: 'the positive control',
        );

        await guest
            .from('vehicle_parts')
            .update({'spec': 'wrong'})
            .eq('vehicle_id', aliceVehicle);
        final after = await alice
            .from('vehicle_parts')
            .select()
            .eq('service_type_key', 'service_cabin_filter');
        expect(after.single['spec'], 'CUK 2939');
      },
    );
  });

  group('routes', () {
    // A named journey, so the same commute can be recognised as the same
    // commute. Household-scoped rather than per vehicle: it is the same drive
    // whichever car is taken.
    Future<String> route(
      SupabaseClient who,
      String household,
      String name,
    ) async {
      final row = await who
          .from('routes')
          .insert({
            'household_id': household,
            'name': name,
            'created_by': who.auth.currentUser!.id,
          })
          .select()
          .single();
      return row['id'] as String;
    }

    test('a member can name one, and read it back', () async {
      final id = await route(alice, aliceHousehold, 'Home to work');
      addTearDown(() => alice.from('routes').delete().eq('id', id));

      final rows = await alice.from('routes').select().eq('id', id);
      expect(rows.single['name'], 'Home to work');
    });

    test('a stranger sees none of them, and cannot add one', () async {
      final id = await route(alice, aliceHousehold, 'Private commute');
      addTearDown(() => alice.from('routes').delete().eq('id', id));

      expect(await carol.from('routes').select().eq('id', id), isEmpty);
      await expectLater(
        carol.from('routes').insert({
          'household_id': aliceHousehold,
          'name': 'Not mine',
          'created_by': carol.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('one name per garage, so a history cannot split in two', () async {
      final id = await route(alice, aliceHousehold, 'To the coast');
      addTearDown(() => alice.from('routes').delete().eq('id', id));

      await expectLater(
        route(alice, aliceHousehold, 'to the coast'),
        throwsA(isA<PostgrestException>()),
        reason: 'the same name in a different case is the same route',
      );
    });

    test('but two garages may each have their own', () async {
      final id = await route(alice, aliceHousehold, 'Shared name');
      addTearDown(() => alice.from('routes').delete().eq('id', id));

      final theirs =
          await carol.rpc(
                'create_household',
                params: {'household_name': 'Carol routes'},
              )
              as String;
      final other = await route(carol, theirs, 'Shared name');

      expect(other, isNotEmpty);
    });

    test('a trip can be filed under one, and remembers it', () async {
      final id = await route(alice, aliceHousehold, 'Work run');
      addTearDown(() => alice.from('routes').delete().eq('id', id));

      final trip = await alice
          .from('trip_entries')
          .insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-09-01',
            'distance_km': 22.0,
            'minutes': 35,
            'route_id': id,
            'created_by': alice.auth.currentUser!.id,
          })
          .select()
          .single();
      addTearDown(
        () =>
            alice.from('trip_entries').delete().eq('id', trip['id'] as String),
      );

      expect(trip['route_id'], id);
      expect(
        trip['comparable'],
        isTrue,
        reason: 'an ordinary run counts unless somebody says otherwise',
      );
    });

    test('deleting a route keeps the journeys that used it', () async {
      // The drives happened. Losing them because a label was tidied away
      // would be data loss dressed up as housekeeping.
      final id = await route(alice, aliceHousehold, 'Doomed label');
      final trip =
          (await alice
                  .from('trip_entries')
                  .insert({
                    'vehicle_id': aliceVehicle,
                    'entry_date': '2026-09-01',
                    'distance_km': 22.0,
                    'minutes': 35,
                    'route_id': id,
                    'created_by': alice.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      addTearDown(() => alice.from('trip_entries').delete().eq('id', trip));

      await alice.from('routes').delete().eq('id', id);

      final after =
          (await alice.from('trip_entries').select().eq('id', trip)).single;
      expect(after['route_id'], isNull);
      expect(after['minutes'], 35);
    });

    test('a run can be marked as not a normal one', () async {
      final id = await route(alice, aliceHousehold, 'Detour route');
      addTearDown(() => alice.from('routes').delete().eq('id', id));

      final trip =
          (await alice
                  .from('trip_entries')
                  .insert({
                    'vehicle_id': aliceVehicle,
                    'entry_date': '2026-09-01',
                    'distance_km': 40.0,
                    'minutes': 95,
                    'route_id': id,
                    'comparable': false,
                    'created_by': alice.auth.currentUser!.id,
                  })
                  .select()
                  .single())['id']
              as String;
      addTearDown(() => alice.from('trip_entries').delete().eq('id', trip));

      final rows = await alice.from('trip_entries').select().eq('id', trip);
      expect(rows.single['comparable'], isFalse);
    });

    test('a guest cannot see the household\'s routes', () async {
      // A route label says where somebody lives and works. A borrowed car
      // does not come with that.
      final id = await route(alice, aliceHousehold, 'Home to work private');
      addTearDown(() => alice.from('routes').delete().eq('id', id));
      final guest = await signUp(
        'route-guest-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      addTearDown(guest.dispose);
      final code =
          await alice.rpc(
                'create_guest_pass',
                params: {'target_vehicle': aliceVehicle, 'valid_days': 7},
              )
              as String;
      await guest.rpc('redeem_guest_pass', params: {'pass_code': code});

      expect(await guest.from('routes').select(), isEmpty);
    });
  });

  group('what storage accepts', () {
    // Both buckets take files a member picked, and a stranger with an account
    // can fill them as easily as anyone: the only limits are the bucket's own.
    // Attachments are receipts, invoices and papers — images and PDFs — and a
    // vehicle photo is a photo, so each bucket refuses everything else, and
    // neither takes a file past 10 MB (migration 0075).
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ...List.filled(64, 0),
    ]);
    final pdf = Uint8List.fromList([
      ...'%PDF-1.7'.codeUnits,
      ...List.filled(64, 0),
    ]);
    final text = Uint8List.fromList('just some notes'.codeUnits);

    Future<void> put(
      String bucket,
      String path,
      Uint8List bytes,
      String type,
    ) async {
      await alice.storage
          .from(bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: type, upsert: true),
          );
      addTearDown(() => alice.storage.from(bucket).remove([path]));
    }

    test('a receipt photo and a PDF are attachments', () async {
      await put(
        'attachments',
        '$aliceVehicle/probe-receipt.png',
        png,
        'image/png',
      );
      await put(
        'attachments',
        '$aliceVehicle/probe-invoice.pdf',
        pdf,
        'application/pdf',
      );
    });

    test('anything else is not', () async {
      await expectLater(
        put('attachments', '$aliceVehicle/probe-notes.txt', text, 'text/plain'),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        put('attachments', '$aliceVehicle/probe.svg', text, 'image/svg+xml'),
        throwsA(isA<StorageException>()),
        reason: 'an SVG can carry script, and opens like a page',
      );
    });

    test('a vehicle photo is a photo', () async {
      final path =
          '$aliceHousehold/probe-${DateTime.now().microsecondsSinceEpoch}';
      await put('vehicle-photos', path, png, 'image/png');
      await expectLater(
        put('vehicle-photos', '$path-notes', text, 'text/plain'),
        throwsA(isA<StorageException>()),
      );
    });

    test('and no bigger than 10 MB', () async {
      final big = Uint8List(10 * 1024 * 1024 + 1)..setAll(0, png);
      await expectLater(
        put('vehicle-photos', '$aliceHousehold/probe-big', big, 'image/png'),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        put('attachments', '$aliceVehicle/probe-big.png', big, 'image/png'),
        throwsA(isA<StorageException>()),
        reason: 'the attachments cap, which already existed, still holds',
      );
    });
  });
  group('company: roles, assignments and drivers', () {
    // The third way to reach a car, after membership and a guest pass. A
    // driver is a member of the garage whose role names the cars it may see,
    // and every policy behind it is additive: these prove what a driver can
    // do, what they cannot, and that a member still cannot see a stranger's.
    late SupabaseClient dana; // the driver, assigned Alice's Golf
    late String danaId;
    late SupabaseClient dino; // a driver with no car today
    late SupabaseClient eva; // a plain member
    late String evaId;
    late String otherCar; // in Alice's garage, never Dana's

    /// A refusal the database reported as [code]: a policy's `42501`, a
    /// constraint's `23514`, or the code a function raises with. A bare
    /// `isA<PostgrestException>()` would also pass a typo in the insert.
    Matcher refusedWith(String code) =>
        throwsA(isA<PostgrestException>().having((e) => e.code, 'code', code));

    Future<SupabaseClient> joinAs(String label) async {
      final who = await signUp(
        '$label-${DateTime.now().microsecondsSinceEpoch}@example.com',
      );
      final code =
          await alice.rpc(
                'create_invite',
                params: {'target_household': aliceHousehold},
              )
              as String;
      await who.rpc('join_household_with_code', params: {'invite_code': code});
      return who;
    }

    Future<void> setRole(String userId, String role) async {
      await alice
          .from('household_members')
          .update({'role': role})
          .eq('household_id', aliceHousehold)
          .eq('user_id', userId);
    }

    Future<String> roleOf(String userId) async {
      final row = await admin
          .from('household_members')
          .select('role')
          .eq('household_id', aliceHousehold)
          .eq('user_id', userId)
          .single();
      return row['role'] as String;
    }

    Future<Map<String, dynamic>?> openAssignment(String vehicleId) async {
      final rows = await admin
          .from('vehicle_assignments')
          .select()
          .eq('vehicle_id', vehicleId)
          .isFilter('to_date', null);
      return rows.isEmpty ? null : rows.single;
    }

    Future<String> carOf(
      SupabaseClient who,
      String household,
      String nickname,
    ) async {
      final row = await who
          .from('vehicles')
          .insert({
            'household_id': household,
            'nickname': nickname,
            'fuel_type_key': 'fuel_diesel',
            'created_by': who.auth.currentUser!.id,
          })
          .select('id')
          .single();
      return row['id'] as String;
    }

    Future<String> newCar(String nickname) =>
        carOf(alice, aliceHousehold, nickname);

    /// Today in UTC as a date, [offsetDays] away: the day
    /// `driver_vehicle_ids()` and a sale reckon with, since `current_date`
    /// on the server is UTC.
    String utcDay([int offsetDays = 0]) {
      final day = DateTime.now().toUtc().add(Duration(days: offsetDays));
      return '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
    }

    setUpAll(() async {
      dana = await joinAs('dana');
      danaId = dana.auth.currentUser!.id;
      await setRole(danaId, 'driver');
      dino = await joinAs('dino');
      await setRole(dino.auth.currentUser!.id, 'driver');
      eva = await joinAs('eva');
      evaId = eva.auth.currentUser!.id;
      otherCar = await newCar('Van, never Dana\'s');
      // From the past, so a handover *today* has a day before it to close on.
      await alice.rpc(
        'hand_over_vehicle',
        params: {
          'target_vehicle': aliceVehicle,
          'on_date': '2026-01-01',
          'odometer_km': 58000,
          'to_user': danaId,
        },
      );
    });

    tearDownAll(() async {
      await admin
          .from('vehicle_assignments')
          .delete()
          .eq('vehicle_id', aliceVehicle);
      await alice.from('vehicles').delete().eq('id', otherCar);
      for (final who in [dana, dino, eva]) {
        await admin
            .from('household_members')
            .delete()
            .eq('household_id', aliceHousehold)
            .eq('user_id', who.auth.currentUser!.id);
        await who.dispose();
      }
    });

    group('the role', () {
      test('an admin of a garage on the plan makes a driver', () async {
        expect(await roleOf(danaId), 'driver');
      });

      test('a member cannot change roles', () async {
        await eva
            .from('household_members')
            .update({'role': 'driver'})
            .eq('household_id', aliceHousehold)
            .eq('user_id', danaId);

        expect(await roleOf(danaId), 'driver');
      });

      test('a stranger cannot either', () async {
        await carol
            .from('household_members')
            .update({'role': 'admin'})
            .eq('household_id', aliceHousehold)
            .eq('user_id', danaId);

        expect(await roleOf(danaId), 'driver');
      });

      test('the database refuses a role it does not know', () async {
        await expectLater(
          alice
              .from('household_members')
              .update({'role': 'manager'})
              .eq('household_id', aliceHousehold)
              .eq('user_id', evaId),
          refusedWith('23514'),
        );
      });

      test('nobody puts their own garage on the plan', () async {
        await expectLater(
          alice
              .from('households')
              .update({'plan': 'company'})
              .eq('id', aliceHousehold),
          refusedWith('42501'),
        );
        await expectLater(
          alice
              .from('households')
              .update({'plan_until': '2030-01-01T00:00:00Z'})
              .eq('id', aliceHousehold),
          refusedWith('42501'),
        );
        // The positive control: the settings the app writes still land.
        await alice
            .from('households')
            .update({
              'company_name': 'Prijevoz d.o.o.',
              'company_oib': '12345678901',
            })
            .eq('id', aliceHousehold);
        final row = await alice
            .from('households')
            .select('company_name, company_oib')
            .eq('id', aliceHousehold)
            .single();
        expect(row['company_name'], 'Prijevoz d.o.o.');
        expect(row['company_oib'], '12345678901');
      });

      test('an OIB is eleven digits or nothing', () async {
        await expectLater(
          alice
              .from('households')
              .update({'company_oib': 'HR12345'})
              .eq('id', aliceHousehold),
          refusedWith('23514'),
        );
      });

      test('only an admin writes the letterhead', () async {
        // The rename guard of 0036, three columns wider: the pack's header
        // is the garage's identity, not one member's preference. The
        // settings row a member saves carries the letterhead unchanged, and
        // that still lands.
        for (final change in [
          {'company_name': 'Evin prijevoz'},
          {'company_oib': '98765432109'},
          {'company_address': 'Ilica 1'},
        ]) {
          await expectLater(
            eva.from('households').update(change).eq('id', aliceHousehold),
            refusedWith('42501'),
            reason: change.keys.single,
          );
        }
        final before = await eva
            .from('households')
            .select('company_name, company_oib, bundling_window_days')
            .eq('id', aliceHousehold)
            .single();
        addTearDown(
          () => alice
              .from('households')
              .update({'bundling_window_days': before['bundling_window_days']})
              .eq('id', aliceHousehold),
        );

        await eva
            .from('households')
            .update({
              'bundling_window_days': 30,
              'company_name': before['company_name'],
              'company_oib': before['company_oib'],
            })
            .eq('id', aliceHousehold);
        final after = await eva
            .from('households')
            .select('company_name, bundling_window_days')
            .eq('id', aliceHousehold)
            .single();
        expect(after['bundling_window_days'], 30);
        expect(after['company_name'], before['company_name']);
      });
    });

    group('the free plan', () {
      // A garage that never heard of the plan: five cars, and the sixth
      // waits. The tests run in order and each leaves the garage exactly
      // full, so every later one starts from a known count.
      late SupabaseClient frank;
      late String frankHousehold;
      late List<String> ids;

      setUpAll(() async {
        frank = await signUp(
          'frank-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        frankHousehold =
            await frank.rpc(
                  'create_household',
                  params: {'household_name': 'Free garage'},
                )
                as String;
      });

      tearDownAll(() => frank.dispose());

      Future<String> frankCar(String nickname) =>
          carOf(frank, frankHousehold, nickname);

      Future<void> archive(String vehicleId, {required bool archived}) async {
        await frank
            .from('vehicles')
            .update({'archived': archived})
            .eq('id', vehicleId);
      }

      test('holds five cars and refuses the sixth', () async {
        ids = [for (var i = 1; i <= 5; i++) await frankCar('Car $i')];

        // By name, from the insert trigger, which runs ahead of the policy:
        // a restore or an import that never asked first is told the cap
        // rather than "no access".
        await expectLater(frankCar('Car 6'), refusedWith('P0008'));
        // Reading is never gated: all five are there.
        expect(await frank.from('vehicles').select(), hasLength(5));

        // An archived car is out of the garage, and makes room.
        await archive(ids[0], archived: true);
        ids.add(await frankCar('Car 6'));
        expect(await frank.from('vehicles').select(), hasLength(6));
      });

      test('an archived car comes back only when there is room', () async {
        // Five active, one archived: the archived one is refused the way a
        // sixth insert is, and an edit of an active car is not an insert.
        await expectLater(
          archive(ids[0], archived: false),
          refusedWith('P0008'),
        );
        await frank
            .from('vehicles')
            .update({'nickname': 'Car 2, renamed'})
            .eq('id', ids[1]);

        await archive(ids[1], archived: true);
        await archive(ids[0], archived: false);
        final row = await frank
            .from('vehicles')
            .select('archived')
            .eq('id', ids[0])
            .single();
        expect(row['archived'], isFalse);
      });

      test('a car sold into a full garage waits at the door', () async {
        final sold = await newCar('For sale to Frank');
        final code =
            await alice.rpc(
                  'create_vehicle_transfer',
                  params: {'target_vehicle': sold},
                )
                as String;

        await expectLater(
          frank.rpc(
            'redeem_vehicle_transfer',
            params: {'transfer_code': code, 'target_household': frankHousehold},
          ),
          refusedWith('P0008'),
        );
        final still = await alice
            .from('vehicles')
            .select('household_id')
            .eq('id', sold)
            .single();
        expect(still['household_id'], aliceHousehold, reason: 'not moved');

        await archive(ids[2], archived: true);
        await frank.rpc(
          'redeem_vehicle_transfer',
          params: {'transfer_code': code, 'target_household': frankHousehold},
        );
        final moved = await frank
            .from('vehicles')
            .select('household_id')
            .eq('id', sold)
            .single();
        expect(moved['household_id'], frankHousehold);
      });

      test('a merge that would overfill the survivor is refused', () async {
        final other =
            await frank.rpc(
                  'create_household',
                  params: {'household_name': 'The other free garage'},
                )
                as String;
        await carOf(frank, other, 'Overflow');

        await expectLater(
          frank.rpc(
            'merge_households',
            params: {
              'absorbed_household': other,
              'surviving_household': frankHousehold,
            },
          ),
          refusedWith('P0008'),
        );
        expect(
          await frank.from('households').select().eq('id', other),
          hasLength(1),
          reason: 'a refused merge leaves both garages as they were',
        );

        await archive(ids[3], archived: true);
        final result = await frank.rpc(
          'merge_households',
          params: {
            'absorbed_household': other,
            'surviving_household': frankHousehold,
          },
        );
        expect(result['vehicles_moved'], 1);
      });

      test('cannot make a driver', () async {
        // The row passes `using` — Frank is its admin — and fails the
        // policy's `with check`, which Postgres reports as a refusal rather
        // than as zero rows.
        await expectLater(
          frank
              .from('household_members')
              .update({'role': 'driver'})
              .eq('household_id', frankHousehold)
              .eq('user_id', frank.auth.currentUser!.id),
          refusedWith('42501'),
        );

        final row = await frank
            .from('household_members')
            .select('role')
            .eq('household_id', frankHousehold)
            .single();
        expect(row['role'], 'admin', reason: 'the plan gates the driver role');
      });

      test('cannot assign a car', () async {
        await expectLater(
          frank.rpc(
            'hand_over_vehicle',
            params: {
              'target_vehicle': ids[0],
              'on_date': '2026-09-01',
              'to_user': frank.auth.currentUser!.id,
            },
          ),
          refusedWith('42501'),
        );
        await expectLater(
          frank.from('vehicle_assignments').insert({
            'vehicle_id': ids[0],
            'user_id': frank.auth.currentUser!.id,
            'from_date': '2026-09-01',
            'created_by': frank.auth.currentUser!.id,
          }),
          refusedWith('42501'),
        );
      });

      test(
        'and once on the plan, the sixth car and the assignment land',
        () async {
          await admin
              .from('households')
              .update({'plan': 'company'})
              .eq('id', frankHousehold);
          addTearDown(
            () => admin
                .from('households')
                .update({'plan': 'free'})
                .eq('id', frankHousehold),
          );

          final seventh = await frankCar('Car 7');
          final assignment = await frank.rpc(
            'hand_over_vehicle',
            params: {
              'target_vehicle': seventh,
              'on_date': '2026-09-01',
              'to_user': frank.auth.currentUser!.id,
            },
          );
          expect(assignment, isNotNull);
        },
      );

      test('a lapsed plan still lets the car come back', () async {
        await admin
            .from('households')
            .update({'plan': 'company', 'plan_until': '2026-01-01T00:00:00Z'})
            .eq('id', frankHousehold);
        addTearDown(
          () => admin
              .from('households')
              .update({'plan': 'free', 'plan_until': null})
              .eq('id', frankHousehold),
        );
        final car =
            (await frank
                        .from('vehicle_assignments')
                        .select('vehicle_id')
                        .isFilter('to_date', null)
                        .limit(1))
                    .first['vehicle_id']
                as String;

        // Handing on is refused; taking back is not.
        await expectLater(
          frank.rpc(
            'hand_over_vehicle',
            params: {
              'target_vehicle': car,
              'on_date': '2026-09-10',
              'to_user': frank.auth.currentUser!.id,
            },
          ),
          refusedWith('42501'),
        );
        final closed = await frank.rpc(
          'hand_over_vehicle',
          params: {'target_vehicle': car, 'on_date': '2026-09-10'},
        );
        expect(closed, isNull);
        final rows = await frank
            .from('vehicle_assignments')
            .select('to_date')
            .eq('vehicle_id', car);
        expect(rows.single['to_date'], '2026-09-09');
      });
    });

    group('succession never crowns a driver', () {
      // The rule from 0056 promotes the longest-standing member when the
      // last admin goes. A driver sees one car and must not inherit the
      // console, whatever their tenure; and a garage of drivers keeps its
      // admin by refusing to let them leave.
      Future<(SupabaseClient, String)> newUser(String prefix) async {
        final client = await signUp(
          '$prefix-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        addTearDown(client.dispose);
        return (client, client.auth.currentUser!.id);
      }

      /// A garage on the plan, owned by [owner], with one more person in
      /// each of [roles], joined in that order.
      Future<(String, List<(SupabaseClient, String)>)> fleet(
        SupabaseClient owner,
        List<String> roles,
      ) async {
        final household =
            await owner.rpc(
                  'create_household',
                  params: {'household_name': 'Fleet'},
                )
                as String;
        await admin
            .from('households')
            .update({'plan': 'company'})
            .eq('id', household);
        final people = <(SupabaseClient, String)>[];
        for (final role in roles) {
          final (who, whoId) = await newUser(role);
          final code =
              await owner.rpc(
                    'create_invite',
                    params: {'target_household': household},
                  )
                  as String;
          await who.rpc(
            'join_household_with_code',
            params: {'invite_code': code},
          );
          await owner
              .from('household_members')
              .update({'role': role})
              .eq('household_id', household)
              .eq('user_id', whoId);
          people.add((who, whoId));
        }
        return (household, people);
      }

      Future<String> roleIn(String household, String userId) async {
        final row = await admin
            .from('household_members')
            .select('role')
            .eq('household_id', household)
            .eq('user_id', userId)
            .single();
        return row['role'] as String;
      }

      test(
        'the member is promoted, however long the driver has been there',
        () async {
          final (owner, ownerId) = await newUser('owner');
          // The driver joined first: by tenure alone they would be the heir.
          final (household, [(_, driverId), (_, memberId)]) = await fleet(
            owner,
            ['driver', 'member'],
          );

          await owner
              .from('household_members')
              .delete()
              .eq('household_id', household)
              .eq('user_id', ownerId);

          expect(await roleIn(household, memberId), 'admin');
          expect(await roleIn(household, driverId), 'driver');
        },
      );

      test('a garage of drivers refuses to lose its admin', () async {
        final (owner, ownerId) = await newUser('owner');
        final (household, [(_, driverId)]) = await fleet(owner, ['driver']);

        await expectLater(
          owner
              .from('household_members')
              .delete()
              .eq('household_id', household)
              .eq('user_id', ownerId),
          refusedWith('P0007'),
        );
        expect(await roleIn(household, ownerId), 'admin');
        expect(await roleIn(household, driverId), 'driver');

        // Stepping down is the other route, and there the role stays put
        // rather than the garage going without (0058).
        await owner
            .from('household_members')
            .update({'role': 'member'})
            .eq('household_id', household)
            .eq('user_id', ownerId);
        expect(await roleIn(household, ownerId), 'admin');
        expect(await roleIn(household, driverId), 'driver');
      });

      test('but deleting that admin\'s account still goes through', () async {
        // Erasure has to be real (0033), so the refusal is only for a leave:
        // the cascade from auth.users carries no caller to refuse, and the
        // garage is left with its drivers and no admin, which is recorded
        // rather than prevented.
        final (owner, ownerId) = await newUser('owner');
        final (household, [(_, driverId)]) = await fleet(owner, ['driver']);

        await expectLater(
          admin.auth.admin.deleteUser(ownerId),
          completes,
          reason: 'a garage of drivers must not hold its admin\'s account',
        );

        expect(
          await admin.from('households').select().eq('id', household),
          hasLength(1),
          reason: 'the garage stays, with its cars and its history',
        );
        final members = await admin
            .from('household_members')
            .select('user_id, role')
            .eq('household_id', household);
        expect(members.map((it) => it['user_id']), [driverId]);
        expect(members.single['role'], 'driver');
      });

      test('and a driver can leave the garage that was left to them', () async {
        // The refusal is for an admin's leave only. Two drivers, so that the
        // one leaving is not the last member, which is the case the rule
        // would otherwise catch.
        final (owner, ownerId) = await newUser('owner');
        final (household, [(first, firstId), (_, secondId)]) = await fleet(
          owner,
          ['driver', 'driver'],
        );
        await admin.auth.admin.deleteUser(ownerId);

        await first
            .from('household_members')
            .delete()
            .eq('household_id', household)
            .eq('user_id', firstId);

        final members = await admin
            .from('household_members')
            .select('user_id, role')
            .eq('household_id', household);
        expect(members.map((it) => it['user_id']), [secondId]);
        expect(members.single['role'], 'driver', reason: 'still not crowned');
      });
    });

    group('what a driver sees', () {
      test('the assigned car, and no other', () async {
        final cars = await dana.from('vehicles').select('id');

        expect(cars.map((it) => it['id']), [aliceVehicle]);
      });

      test('a driver with no assignment today sees no car', () async {
        expect(await dino.from('vehicles').select(), isEmpty);
      });

      test('a stranger still sees nothing', () async {
        expect(
          await carol.from('vehicles').select().eq('id', aliceVehicle),
          isEmpty,
        );
      });

      test('the garage, its people and their names', () async {
        final households = await dana.from('households').select('id');
        expect(households.map((it) => it['id']), [aliceHousehold]);

        final members = await dana
            .from('household_members')
            .select('user_id')
            .eq('household_id', aliceHousehold);
        expect(
          members.map((it) => it['user_id']),
          containsAll([alice.auth.currentUser!.id, danaId, evaId]),
        );

        final profiles = await dana
            .from('profiles')
            .select('user_id')
            .eq('user_id', alice.auth.currentUser!.id);
        expect(profiles, hasLength(1), reason: 'attribution needs the name');
      });

      test('but cannot change the garage', () async {
        final before = await alice
            .from('households')
            .select('name')
            .eq('id', aliceHousehold)
            .single();

        await dana
            .from('households')
            .update({'name': 'Renamed by the driver'})
            .eq('id', aliceHousehold);

        final after = await alice
            .from('households')
            .select('name')
            .eq('id', aliceHousehold)
            .single();
        expect(after['name'], before['name']);
      });

      test('nor the car', () async {
        // No update or delete policy names a driver, so PostgREST reports
        // both as zero rows rather than as an error; the row is the proof.
        final before = await alice
            .from('vehicles')
            .select('nickname, archived')
            .eq('id', aliceVehicle)
            .single();

        await dana
            .from('vehicles')
            .update({'nickname': 'Renamed by the driver', 'archived': true})
            .eq('id', aliceVehicle);
        await dana.from('vehicles').delete().eq('id', aliceVehicle);

        final after = await alice
            .from('vehicles')
            .select('nickname, archived')
            .eq('id', aliceVehicle)
            .single();
        expect(after['nickname'], before['nickname']);
        expect(after['archived'], before['archived']);
      });

      test(
        'the history on the assigned car, including what others logged',
        () async {
          // Alice's fill-up from setUpAll is on the Golf.
          final fills = await dana
              .from('fuel_entries')
              .select('created_by')
              .eq('vehicle_id', aliceVehicle);

          expect(fills, isNotEmpty);
          expect(
            fills.map((it) => it['created_by']),
            contains(alice.auth.currentUser!.id),
          );
        },
      );

      test('papers and routes, read-only', () async {
        final document = await alice
            .from('vehicle_documents')
            .insert({
              'vehicle_id': aliceVehicle,
              'doc_type': 'other',
              'label': 'Fleet card',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        addTearDown(
          () =>
              alice.from('vehicle_documents').delete().eq('id', document['id']),
        );
        final route = await alice
            .from('routes')
            .insert({
              'household_id': aliceHousehold,
              'name': 'Depot to port',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        addTearDown(() => alice.from('routes').delete().eq('id', route['id']));

        expect(
          await dana
              .from('vehicle_documents')
              .select()
              .eq('id', document['id']),
          hasLength(1),
        );
        expect(
          await dana.from('routes').select().eq('id', route['id']),
          hasLength(1),
        );
      });

      test(
        'tyres, parts and intervals on the assigned car, and not the other',
        () async {
          // One of each on both cars, so that "sees it" and "does not see the
          // other car's" are the same rows told apart by the car alone.
          final seen = <String, String>{};
          final hidden = <String, String>{};
          for (final (car, into) in [
            (aliceVehicle, seen),
            (otherCar, hidden),
          ]) {
            final set = await alice
                .from('tyre_sets')
                .insert({
                  'vehicle_id': car,
                  'name': 'Winter',
                  'created_by': alice.auth.currentUser!.id,
                })
                .select('id')
                .single();
            addTearDown(
              () => alice.from('tyre_sets').delete().eq('id', set['id']),
            );
            final reading = await alice
                .from('tyre_readings')
                .insert({
                  'tyre_set_id': set['id'],
                  'reading_date': '2026-09-01',
                  'front_left_mm': 6.5,
                  'created_by': alice.auth.currentUser!.id,
                })
                .select('id')
                .single();
            final part = await alice
                .from('vehicle_parts')
                .insert({
                  'vehicle_id': car,
                  'service_type_key': 'service_tachograph_calibration',
                  'spec': 'VDO 1381',
                  'created_by': alice.auth.currentUser!.id,
                })
                .select('id')
                .single();
            addTearDown(
              () => alice.from('vehicle_parts').delete().eq('id', part['id']),
            );
            final rule = await alice
                .from('reminder_rules')
                .insert({
                  'vehicle_id': car,
                  'service_type_key': 'service_tachograph_calibration',
                  'interval_months': 24,
                })
                .select('id')
                .single();
            addTearDown(
              () => alice.from('reminder_rules').delete().eq('id', rule['id']),
            );
            into
              ..['tyre_sets'] = set['id'] as String
              ..['tyre_readings'] = reading['id'] as String
              ..['vehicle_parts'] = part['id'] as String
              ..['reminder_rules'] = rule['id'] as String;
          }

          for (final table in seen.keys) {
            expect(
              await dana.from(table).select('id').eq('id', seen[table]!),
              hasLength(1),
              reason: '$table on the assigned car',
            );
            expect(
              await dana.from(table).select('id').eq('id', hidden[table]!),
              isEmpty,
              reason: '$table on the other car',
            );
          }
        },
      );

      test('the garage\'s own service types, and no other garage\'s', () async {
        final bobHousehold =
            (await bob
                        .from('households')
                        .select('id')
                        .eq('name', "Bob's garage"))
                    .single['id']
                as String;
        final ours = await alice
            .from('service_types')
            .insert({
              'household_id': aliceHousehold,
              'key': 'service_fleet_wash',
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('service_types').delete().eq('id', ours['id']),
        );
        final theirs = await bob
            .from('service_types')
            .insert({
              'household_id': bobHousehold,
              'key': 'service_bob_private',
            })
            .select('id')
            .single();
        addTearDown(
          () => bob.from('service_types').delete().eq('id', theirs['id']),
        );

        final keys = (await dana.from('service_types').select('key'))
            .map((it) => it['key'])
            .toSet();
        expect(keys, contains('service_fleet_wash'));
        expect(keys, contains('service_oil_change'), reason: 'presets too');
        expect(keys, isNot(contains('service_bob_private')));
      });

      test('and may write none of them', () async {
        final set = await alice
            .from('tyre_sets')
            .insert({
              'vehicle_id': aliceVehicle,
              'name': 'Summer',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        addTearDown(() => alice.from('tyre_sets').delete().eq('id', set['id']));

        for (final (table, row) in [
          (
            'vehicle_documents',
            {
              'vehicle_id': aliceVehicle,
              'doc_type': 'other',
              'label': 'Not mine to add',
              'created_by': danaId,
            },
          ),
          (
            'reminder_rules',
            {
              'vehicle_id': aliceVehicle,
              'service_type_key': 'service_oil_change',
              'interval_km': 15000,
            },
          ),
          (
            'tyre_sets',
            {
              'vehicle_id': aliceVehicle,
              'name': 'Winter',
              'created_by': danaId,
            },
          ),
          (
            'tyre_readings',
            {
              'tyre_set_id': set['id'],
              'reading_date': '2026-09-02',
              'front_left_mm': 6,
              'created_by': danaId,
            },
          ),
          (
            'vehicle_parts',
            {
              'vehicle_id': aliceVehicle,
              'service_type_key': 'service_oil_change',
              'spec': '5W-30',
              'created_by': danaId,
            },
          ),
          (
            'routes',
            {
              'household_id': aliceHousehold,
              'name': 'Not mine to name',
              'created_by': danaId,
            },
          ),
          (
            'service_types',
            {'household_id': aliceHousehold, 'key': 'service_not_mine'},
          ),
        ]) {
          await expectLater(
            dana.from(table).insert(row),
            refusedWith('42501'),
            reason: table,
          );
        }
      });

      test(
        'and an edit or a delete of them is filtered, not refused',
        () async {
          // Only an insert has a new row for `with check` to fail on. With no
          // driver write policy at all, an update or a delete is filtered to
          // zero rows and answered with no error — the shape the entry tables
          // had — so the app's write reads the id back, and this is the answer
          // it gets: nothing, and the row untouched.
          final part = await alice
              .from('vehicle_parts')
              .insert({
                'vehicle_id': aliceVehicle,
                // A job no earlier test answered on this car: one part per
                // job, and the wipers were answered a group ago.
                'service_type_key': 'service_coolant',
                'spec': 'G12 evo, 5 l',
                'created_by': alice.auth.currentUser!.id,
              })
              .select('id')
              .single();
          addTearDown(
            () => alice.from('vehicle_parts').delete().eq('id', part['id']),
          );
          final route = await alice
              .from('routes')
              .insert({
                'household_id': aliceHousehold,
                'name': 'Not Dana\'s to rename',
                'created_by': alice.auth.currentUser!.id,
              })
              .select('id')
              .single();
          addTearDown(
            () => alice.from('routes').delete().eq('id', route['id']),
          );
          final set = await alice
              .from('tyre_sets')
              .insert({
                'vehicle_id': aliceVehicle,
                'name': 'Summer, the admin\'s',
                'created_by': alice.auth.currentUser!.id,
              })
              .select('id')
              .single();
          addTearDown(
            () => alice.from('tyre_sets').delete().eq('id', set['id']),
          );

          for (final (table, id, change, column) in [
            ('vehicle_parts', part['id'], {'spec': 'Cheap ones'}, 'spec'),
            ('routes', route['id'], {'name': 'Renamed by Dana'}, 'name'),
            ('tyre_sets', set['id'], {'name': 'Renamed by Dana'}, 'name'),
          ]) {
            expect(
              await dana.from(table).update(change).eq('id', id).select('id'),
              isEmpty,
              reason: '$table update',
            );
            expect(
              await dana.from(table).delete().eq('id', id).select('id'),
              isEmpty,
              reason: '$table delete',
            );
            final after = await alice
                .from(table)
                .select(column)
                .eq('id', id)
                .single();
            expect(after[column], isNot(change[column]), reason: table);
          }
        },
      );

      test(
        'nothing of invites, keys, hooks, transfers, passes or income',
        () async {
          for (final table in [
            'invites',
            'api_keys',
            'webhooks',
            'webhook_outbox',
            'webhook_deliveries',
            'vehicle_transfers',
            'vehicle_guest_passes',
            'income_entries',
          ]) {
            expect(await dana.from(table).select(), isEmpty, reason: table);
          }
          await expectLater(
            dana.from('income_entries').insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-01',
              'category': 'sale',
              'amount': 100,
              'created_by': danaId,
            }),
            refusedWith('42501'),
          );
          await expectLater(
            dana.from('api_keys').insert({
              'household_id': aliceHousehold,
              'name': 'Not mine',
              // Sixty-four hex characters, fresh per run, so the refusal is
              // the policy's and not a collision with a row a previous run
              // left behind.
              'key_hash':
                  '${'d' * 32}'
                  '${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0')}',
              'key_preview': '…none',
              'created_by': danaId,
            }),
            refusedWith('42501'),
          );
          // Both mint functions check membership through user_household_ids()
          // and refuse with a bare raise, which is P0001.
          await expectLater(
            dana.rpc(
              'create_invite',
              params: {'target_household': aliceHousehold},
            ),
            refusedWith('P0001'),
          );
          await expectLater(
            dana.rpc(
              'create_guest_pass',
              params: {'target_vehicle': aliceVehicle, 'valid_days': 7},
            ),
            refusedWith('P0001'),
          );
        },
      );
    });

    group('what a driver logs', () {
      test('a fill-up on the assigned car, as themselves', () async {
        final row = await dana
            .from('fuel_entries')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-10',
              'odometer_km': 60100,
              'volume_l': 38,
              'total': 60,
              'full_tank': true,
              'created_by': danaId,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('fuel_entries').delete().eq('id', row['id']),
        );

        // Edits their own, and deletes their own.
        await dana
            .from('fuel_entries')
            .update({'total': 61})
            .eq('id', row['id']);
        final after = await alice
            .from('fuel_entries')
            .select('total')
            .eq('id', row['id'])
            .single();
        expect((after['total'] as num).toDouble(), 61);
      });

      test('not as somebody else, and not on the other car', () async {
        await expectLater(
          dana.from('fuel_entries').insert({
            'vehicle_id': aliceVehicle,
            'entry_date': '2026-09-10',
            'odometer_km': 60100,
            'volume_l': 38,
            'full_tank': true,
            'created_by': alice.auth.currentUser!.id,
          }),
          refusedWith('42501'),
        );
        await expectLater(
          dana.from('fuel_entries').insert({
            'vehicle_id': otherCar,
            'entry_date': '2026-09-10',
            'odometer_km': 100,
            'volume_l': 38,
            'full_tank': true,
            'created_by': danaId,
          }),
          refusedWith('42501'),
        );
      });

      test('cannot change what the admin logged', () async {
        final theirs =
            (await dana
                    .from('fuel_entries')
                    .select('id, total')
                    .eq('vehicle_id', aliceVehicle)
                    .eq('created_by', alice.auth.currentUser!.id))
                .first;

        await dana
            .from('fuel_entries')
            .update({'total': 999})
            .eq('id', theirs['id']);
        await dana.from('fuel_entries').delete().eq('id', theirs['id']);

        final after = await alice
            .from('fuel_entries')
            .select('total')
            .eq('id', theirs['id'])
            .single();
        expect((after['total'] as num).toDouble(), isNot(999));
      });

      group('what the phone is told', () {
        // The case above proves the row is untouched and says nothing about
        // what the phone showed: PostgREST answers a write the policy filters
        // out with 204 and no error. So every entry repository ends its
        // update and delete in `.select('id')` and refuses on an empty answer
        // (`lib/core/supabase/refused_if_none.dart`). These are that write,
        // as the app makes it, on a row somebody else wrote and on the
        // driver's own.
        Future<void> readsBackOnlyTheirOwn(
          String table, {
          required Map<String, Object?> theirs,
          required Map<String, Object?> own,
          required Map<String, Object?> change,
        }) async {
          final alices = await alice
              .from(table)
              .insert({...theirs, 'created_by': alice.auth.currentUser!.id})
              .select('id')
              .single();
          addTearDown(() => alice.from(table).delete().eq('id', alices['id']));
          final danas = await dana
              .from(table)
              .insert({...own, 'created_by': danaId})
              .select('id')
              .single();
          addTearDown(() => alice.from(table).delete().eq('id', danas['id']));

          expect(
            await dana
                .from(table)
                .update(change)
                .eq('id', alices['id'])
                .select('id'),
            isEmpty,
            reason: 'an edit of somebody else\'s $table row reads back none',
          );
          expect(
            await dana.from(table).delete().eq('id', alices['id']).select('id'),
            isEmpty,
            reason: 'a delete of somebody else\'s $table row reads back none',
          );
          final column = change.keys.single;
          final after = await alice
              .from(table)
              .select(column)
              .eq('id', alices['id'])
              .single();
          expect(after[column], isNot(change[column]));

          expect(
            await dana
                .from(table)
                .update(change)
                .eq('id', danas['id'])
                .select('id'),
            [
              {'id': danas['id']},
            ],
            reason: 'an edit of their own $table row reads back its id',
          );
          expect(
            await dana.from(table).delete().eq('id', danas['id']).select('id'),
            [
              {'id': danas['id']},
            ],
            reason: 'a delete of their own $table row reads back its id',
          );
        }

        test('a fill-up', () async {
          await readsBackOnlyTheirOwn(
            'fuel_entries',
            theirs: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-14',
              'odometer_km': 60300,
              'volume_l': 40,
              'total': 60,
              'full_tank': true,
            },
            own: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-15',
              'odometer_km': 60400,
              'volume_l': 41,
              'total': 62,
              'full_tank': true,
            },
            change: {'total': 999},
          );
        });

        test('a service', () async {
          await readsBackOnlyTheirOwn(
            'service_entries',
            theirs: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-14',
              'odometer_km': 60300,
              'service_type_keys': ['service_wipers'],
              'cost': 30,
            },
            own: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-15',
              'odometer_km': 60400,
              'service_type_keys': ['service_oil_change'],
              'cost': 120,
            },
            change: {'cost': 999},
          );
        });

        test('a cost', () async {
          await readsBackOnlyTheirOwn(
            'cost_entries',
            theirs: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-14',
              'category': 'parking',
              'amount': 12,
            },
            own: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-15',
              'category': 'parking',
              'amount': 8,
            },
            change: {'amount': 999},
          );
        });

        test('a reading', () async {
          await readsBackOnlyTheirOwn(
            'odometer_entries',
            theirs: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-14',
              'odometer_km': 60300,
              'notes': 'Before the trip',
            },
            own: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-15',
              'odometer_km': 60400,
              'notes': 'After the trip',
            },
            change: {'notes': 'Nothing happened'},
          );
        });

        test('a journey, which is also a drive being finished', () async {
          await readsBackOnlyTheirOwn(
            'trip_entries',
            theirs: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-14',
              'distance_km': 30,
              'purpose': 'business',
              'notes': 'Client visit',
            },
            own: {
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-15',
              'distance_km': 42,
              'purpose': 'business',
              'notes': 'Site visit',
            },
            change: {'notes': 'Nothing happened'},
          );
        });

        test('a note about the car', () async {
          await readsBackOnlyTheirOwn(
            'observations',
            theirs: {
              'vehicle_id': aliceVehicle,
              'noticed_on': '2026-09-14',
              'note': 'Wipers smear',
            },
            own: {
              'vehicle_id': aliceVehicle,
              'noticed_on': '2026-09-15',
              'note': 'Squeal from the front left',
            },
            change: {'note': 'Nothing happened'},
          );
        });
      });

      test('a service, edited and then deleted, as their own', () async {
        final row = await dana
            .from('service_entries')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-10',
              'odometer_km': 60150,
              'service_type_keys': ['service_oil_change'],
              'cost': 120,
              'created_by': danaId,
            })
            .select('id')
            .single();
        addTearDown(
          () => admin.from('service_entries').delete().eq('id', row['id']),
        );

        await dana
            .from('service_entries')
            .update({'cost': 125})
            .eq('id', row['id']);
        final edited = await alice
            .from('service_entries')
            .select('cost')
            .eq('id', row['id'])
            .single();
        expect((edited['cost'] as num).toDouble(), 125);

        await dana.from('service_entries').delete().eq('id', row['id']);
        expect(
          await alice.from('service_entries').select().eq('id', row['id']),
          isEmpty,
        );
      });

      test('not a service on the other car, and not the admin\'s', () async {
        await expectLater(
          dana.from('service_entries').insert({
            'vehicle_id': otherCar,
            'entry_date': '2026-09-10',
            'odometer_km': 100,
            'service_type_keys': ['service_oil_change'],
            'created_by': danaId,
          }),
          refusedWith('42501'),
        );
        final theirs = await alice
            .from('service_entries')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-11',
              'odometer_km': 60160,
              'service_type_keys': ['service_wipers'],
              'cost': 30,
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('service_entries').delete().eq('id', theirs['id']),
        );

        await dana
            .from('service_entries')
            .update({'cost': 999})
            .eq('id', theirs['id']);
        await dana.from('service_entries').delete().eq('id', theirs['id']);

        final after = await alice
            .from('service_entries')
            .select('cost')
            .eq('id', theirs['id'])
            .single();
        expect((after['cost'] as num).toDouble(), 30);
      });

      test('a reading, a drive, a problem, and a receipt', () async {
        final reading = await dana
            .from('odometer_entries')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-11',
              'odometer_km': 60200,
              'created_by': danaId,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('odometer_entries').delete().eq('id', reading['id']),
        );
        final trip = await dana
            .from('trip_entries')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-11',
              'distance_km': 42,
              'purpose': 'business',
              'created_by': danaId,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('trip_entries').delete().eq('id', trip['id']),
        );
        final problem = await dana
            .from('observations')
            .insert({
              'vehicle_id': aliceVehicle,
              'noticed_on': '2026-09-11',
              'note': 'Squeal from the front left',
              'created_by': danaId,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('observations').delete().eq('id', problem['id']),
        );
        final receipt = await dana
            .from('attachments')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_kind': 'fuel',
              'entry_id': reading['id'],
              'storage_path': '$aliceVehicle/${reading['id']}-receipt.jpg',
              'file_name': 'receipt.jpg',
              'created_by': danaId,
            })
            .select('id')
            .single();

        expect(
          await alice.from('attachments').select().eq('id', receipt['id']),
          hasLength(1),
        );
        // Their own receipt comes down with an abandoned sheet (decision 90).
        await dana.from('attachments').delete().eq('id', receipt['id']);
        expect(
          await alice.from('attachments').select().eq('id', receipt['id']),
          isEmpty,
        );
      });
    });

    group('what storage lets a driver reach', () {
      // The files behind the rows: a receipt lives under the car's id in the
      // attachments bucket and a car's photo under <household>/<vehicle>.
      // One case per policy, and the delete keyed on who uploaded the file.
      final png = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        ...List.filled(64, 0),
      ]);

      Future<void> upload(
        SupabaseClient who,
        String bucket,
        String path,
      ) async {
        await who.storage
            .from(bucket)
            .uploadBinary(
              path,
              png,
              fileOptions: const FileOptions(
                contentType: 'image/png',
                upsert: true,
              ),
            );
        addTearDown(() => admin.storage.from(bucket).remove([path]));
      }

      /// Storage reports a policy refusal as 403 with the policy's message,
      /// and an object a policy hides as 404 "Object not found".
      Matcher storageRefused(String status) => throwsA(
        isA<StorageException>().having(
          (e) => e.statusCode,
          'statusCode',
          status,
        ),
      );

      test(
        'a receipt goes up under the assigned car, and nowhere else',
        () async {
          await upload(dana, 'attachments', '$aliceVehicle/dana-probe.png');

          await expectLater(
            upload(dana, 'attachments', '$otherCar/dana-probe.png'),
            storageRefused('403'),
          );
          await expectLater(
            upload(carol, 'attachments', '$aliceVehicle/carol-probe.png'),
            storageRefused('403'),
          );
        },
      );

      test('and is read back from the assigned car only', () async {
        await upload(alice, 'attachments', '$aliceVehicle/alice-probe.png');
        await upload(alice, 'attachments', '$otherCar/alice-probe.png');

        expect(
          await dana.storage
              .from('attachments')
              .createSignedUrl('$aliceVehicle/alice-probe.png', 60),
          isNotEmpty,
        );
        await expectLater(
          dana.storage
              .from('attachments')
              .createSignedUrl('$otherCar/alice-probe.png', 60),
          storageRefused('404'),
        );
      });

      test('a driver takes down their own upload, not the admin\'s', () async {
        await upload(dana, 'attachments', '$aliceVehicle/dana-own.png');
        await upload(alice, 'attachments', '$aliceVehicle/alice-own.png');

        // A delete the policy filters out is not an error: storage removes
        // what it may and lists what it removed.
        final removed = await dana.storage.from('attachments').remove([
          '$aliceVehicle/dana-own.png',
          '$aliceVehicle/alice-own.png',
        ]);

        expect(removed.map((it) => it.name), ['$aliceVehicle/dana-own.png']);
        final left =
            (await admin.storage.from('attachments').list(path: aliceVehicle))
                .map((it) => it.name);
        expect(left, contains('alice-own.png'));
        expect(left, isNot(contains('dana-own.png')));
      });

      test('the car\'s photo, and not the other car\'s', () async {
        await upload(alice, 'vehicle-photos', '$aliceHousehold/$aliceVehicle');
        await upload(alice, 'vehicle-photos', '$aliceHousehold/$otherCar');

        expect(
          await dana.storage
              .from('vehicle-photos')
              .createSignedUrl('$aliceHousehold/$aliceVehicle', 60),
          isNotEmpty,
        );
        await expectLater(
          dana.storage
              .from('vehicle-photos')
              .createSignedUrl('$aliceHousehold/$otherCar', 60),
          storageRefused('404'),
        );
      });
    });

    group('the assignment log', () {
      test('a driver reads their own row and not the next driver\'s', () async {
        final evaOnVan = await alice.rpc(
          'hand_over_vehicle',
          params: {
            'target_vehicle': otherCar,
            'on_date': '2026-02-01',
            'to_user': evaId,
          },
        );
        addTearDown(
          () => admin.from('vehicle_assignments').delete().eq('id', evaOnVan),
        );

        final mine = await dana.from('vehicle_assignments').select('user_id');
        expect(mine, hasLength(1));
        expect(mine.single['user_id'], danaId);
        expect(await carol.from('vehicle_assignments').select(), isEmpty);
        expect(
          await alice.from('vehicle_assignments').select(),
          hasLength(greaterThanOrEqualTo(2)),
          reason: 'the admin reads the whole log',
        );
      });

      test('a removed driver reads none of their old windows', () async {
        // The log outlives the membership, so nothing resolves to a
        // stranger; what the departed driver may read of it is nothing, the
        // handover note and the readings included.
        final gita = await joinAs('gita');
        final gitaId = gita.auth.currentUser!.id;
        addTearDown(() async {
          await admin
              .from('household_members')
              .delete()
              .eq('household_id', aliceHousehold)
              .eq('user_id', gitaId);
          await gita.dispose();
        });
        await setRole(gitaId, 'driver');
        final car = await newCar('Once Gita\'s');
        addTearDown(() => alice.from('vehicles').delete().eq('id', car));
        final window = await alice.rpc(
          'hand_over_vehicle',
          params: {
            'target_vehicle': car,
            'on_date': '2026-03-01',
            'odometer_km': 1200,
            'to_user': gitaId,
            'handover_note': 'Keys in the office',
          },
        );

        final mine = await gita
            .from('vehicle_assignments')
            .select('note, handover_odometer_km')
            .eq('id', window);
        expect(mine.single['note'], 'Keys in the office');

        await admin
            .from('household_members')
            .delete()
            .eq('household_id', aliceHousehold)
            .eq('user_id', gitaId);

        expect(await gita.from('vehicle_assignments').select(), isEmpty);
        final kept = await alice
            .from('vehicle_assignments')
            .select('user_id')
            .eq('id', window);
        expect(kept.single['user_id'], gitaId, reason: 'the log keeps it');
      });

      test('one driver per car at a time', () async {
        await expectLater(
          alice.from('vehicle_assignments').insert({
            'vehicle_id': aliceVehicle,
            'user_id': evaId,
            'from_date': '2026-06-01',
            'created_by': alice.auth.currentUser!.id,
          }),
          refusedWith('23P01'),
        );
      });

      test(
        'a driver cannot write the log, and a member cannot either',
        () async {
          await expectLater(
            dana.from('vehicle_assignments').insert({
              'vehicle_id': aliceVehicle,
              'user_id': danaId,
              'from_date': '2020-01-01',
              'to_date': '2020-01-02',
              'created_by': danaId,
            }),
            refusedWith('42501'),
          );
          await expectLater(
            eva.rpc(
              'hand_over_vehicle',
              params: {
                'target_vehicle': otherCar,
                'on_date': '2026-09-01',
                'to_user': evaId,
              },
            ),
            refusedWith('42501'),
          );
          final open = (await openAssignment(aliceVehicle))!;
          await dana
              .from('vehicle_assignments')
              .update({'from_date': '2020-01-01'})
              .eq('id', open['id']);
          await dana.from('vehicle_assignments').delete().eq('id', open['id']);
          expect(
            (await openAssignment(aliceVehicle))!['from_date'],
            '2026-01-01',
          );
        },
      );

      test('a handover writes both readings and one odometer entry', () async {
        final day = utcDay();
        final before = (await openAssignment(aliceVehicle))!;

        final next = await alice.rpc(
          'hand_over_vehicle',
          params: {
            'target_vehicle': aliceVehicle,
            'on_date': day,
            'odometer_km': 62000,
            'to_user': evaId,
            'handover_note': 'Keys in the office',
          },
        );
        addTearDown(() async {
          // Dana gets the car back for the tests after this one.
          await admin.from('vehicle_assignments').delete().eq('id', next);
          await admin
              .from('vehicle_assignments')
              .update({'to_date': null, 'return_odometer_km': null})
              .eq('id', before['id']);
          await admin
              .from('odometer_entries')
              .delete()
              .eq('vehicle_id', aliceVehicle)
              .eq('odometer_km', 62000);
        });

        final closed = await admin
            .from('vehicle_assignments')
            .select('to_date, return_odometer_km')
            .eq('id', before['id'])
            .single();
        final opened = await admin
            .from('vehicle_assignments')
            .select('user_id, from_date, handover_odometer_km, note')
            .eq('id', next)
            .single();
        final readings = await admin
            .from('odometer_entries')
            .select('odometer_km, entry_date, created_by')
            .eq('vehicle_id', aliceVehicle)
            .eq('odometer_km', 62000);

        expect(closed['return_odometer_km'], 62000);
        expect(
          DateTime.parse(closed['to_date'] as String),
          DateTime.parse(day).subtract(const Duration(days: 1)),
        );
        expect(opened['user_id'], evaId);
        expect(opened['from_date'], day);
        expect(opened['handover_odometer_km'], 62000);
        expect(opened['note'], 'Keys in the office');
        expect(readings, hasLength(1));
        expect(readings.single['entry_date'], day);
        expect(readings.single['created_by'], alice.auth.currentUser!.id);
        // Dana no longer has the car; Eva does.
        expect(await dana.from('vehicles').select(), isEmpty);
        expect(
          (await eva.from('vehicles').select('id')).map((it) => it['id']),
          contains(aliceVehicle),
        );
      });

      test('a second handover on the same day is refused', () async {
        final open = (await openAssignment(aliceVehicle))!;
        await expectLater(
          alice.rpc(
            'hand_over_vehicle',
            params: {
              'target_vehicle': aliceVehicle,
              'on_date': open['from_date'],
              'to_user': evaId,
            },
          ),
          refusedWith('P0006'),
        );
      });

      test(
        'the driver confirms their own assignment, nobody else\'s',
        () async {
          // Nothing resets the sign-off afterwards: nothing may, and no
          // later test needs the window unsigned.
          final open = (await openAssignment(aliceVehicle))!;

          await expectLater(
            eva.rpc(
              'confirm_vehicle_assignment',
              params: {'assignment_id': open['id']},
            ),
            refusedWith('P0002'),
          );
          // The admin may edit the window, but the sign-off is not theirs
          // to write, not even in the driver's name.
          await expectLater(
            alice
                .from('vehicle_assignments')
                .update({
                  'confirmed_at': '2026-09-01T08:00:00Z',
                  'confirmed_by': danaId,
                })
                .eq('id', open['id']),
            refusedWith('42501'),
          );
          await alice
              .from('vehicle_assignments')
              .update({'note': 'Keys under the mat'})
              .eq('id', open['id']);
          // Unsigned, the window is the admin's to point at whom they like.
          await alice
              .from('vehicle_assignments')
              .update({'user_id': evaId})
              .eq('id', open['id']);
          await alice
              .from('vehicle_assignments')
              .update({'user_id': danaId})
              .eq('id', open['id']);

          await dana.rpc(
            'confirm_vehicle_assignment',
            params: {'assignment_id': open['id']},
          );
          final row = await admin
              .from('vehicle_assignments')
              .select('confirmed_by, note')
              .eq('id', open['id'])
              .single();
          expect(row['confirmed_by'], danaId);
          expect(row['note'], 'Keys under the mat');

          // Signed, it is evidence for a fine, and stays about the person
          // who gave it: it cannot be re-pointed at another member. (The
          // deletion group shows the cascade may still null the driver.)
          await expectLater(
            alice
                .from('vehicle_assignments')
                .update({'user_id': bob.auth.currentUser!.id})
                .eq('id', open['id']),
            refusedWith('42501'),
          );
          final kept = await admin
              .from('vehicle_assignments')
              .select('user_id')
              .eq('id', open['id'])
              .single();
          expect(kept['user_id'], danaId);

          // Nor is it anybody's to take back, the service role included.
          await expectLater(
            alice
                .from('vehicle_assignments')
                .update({'confirmed_at': null, 'confirmed_by': null})
                .eq('id', open['id']),
            refusedWith('42501'),
          );
          await expectLater(
            admin
                .from('vehicle_assignments')
                .update({'confirmed_at': null, 'confirmed_by': null})
                .eq('id', open['id']),
            refusedWith('42501'),
          );
        },
      );

      test('a window is created unsigned, whoever creates it', () async {
        // The sign-off guarantees that the driver wrote it: an admin can
        // neither write one onto a row nor create a row with one on it.
        final car = await newCar('Signed on arrival');
        addTearDown(() => alice.from('vehicles').delete().eq('id', car));

        await expectLater(
          alice.from('vehicle_assignments').insert({
            'vehicle_id': car,
            'user_id': danaId,
            'from_date': '2026-04-01',
            'confirmed_at': '2026-04-01T08:00:00Z',
            'confirmed_by': danaId,
            'created_by': alice.auth.currentUser!.id,
          }),
          refusedWith('42501'),
        );
        final row = await alice
            .from('vehicle_assignments')
            .insert({
              'vehicle_id': car,
              'user_id': danaId,
              'from_date': '2026-04-01',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('confirmed_at, confirmed_by')
            .single();
        expect(row['confirmed_at'], isNull);
        expect(row['confirmed_by'], isNull);
      });

      test('a day a closed window covers is refused the same way', () async {
        // No open window, so the function's own check has nothing to say;
        // the exclusion constraint refuses, and its code is turned into the
        // one the app already understands.
        final car = await newCar('Once Dana\'s');
        addTearDown(() => alice.from('vehicles').delete().eq('id', car));
        await admin.from('vehicle_assignments').insert({
          'vehicle_id': car,
          'user_id': danaId,
          'from_date': '2026-03-01',
          'to_date': '2026-03-31',
          'created_by': alice.auth.currentUser!.id,
        });

        await expectLater(
          alice.rpc(
            'hand_over_vehicle',
            params: {
              'target_vehicle': car,
              'on_date': '2026-03-15',
              'to_user': evaId,
            },
          ),
          refusedWith('P0006'),
        );
        expect(
          await admin
              .from('vehicle_assignments')
              .select()
              .eq('vehicle_id', car),
          hasLength(1),
          reason: 'the refused handover wrote nothing',
        );
      });

      test('a sale closes the seller\'s driver out of the car', () async {
        // The car leaves the garage the driver is a member of, so the
        // membership check in driver_vehicle_ids() already shuts them out;
        // the log is cut as well, on the day before the sale, so that
        // driver_on() never names them to the buyer: an open window, and a
        // closed one that still reaches today because a handover was dated
        // ahead. A window that never covered a day is deleted rather than
        // closed before it began.
        final buyer = await signUp(
          'buyer-${DateTime.now().microsecondsSinceEpoch}@example.com',
        );
        addTearDown(buyer.dispose);
        final buyerHousehold =
            await buyer.rpc(
                  'create_household',
                  params: {'household_name': 'The buyer'},
                )
                as String;
        final since = await newCar('Sold with a driver');
        final today = await newCar('Sold on the day');
        final planned = await newCar('Sold with a handover planned');
        addTearDown(() async {
          for (final car in [since, today, planned]) {
            await buyer.from('vehicles').delete().eq('id', car);
          }
        });
        for (final (car, day) in [
          (since, '2026-03-01'),
          (today, utcDay()),
          (planned, '2026-03-01'),
        ]) {
          await alice.rpc(
            'hand_over_vehicle',
            params: {'target_vehicle': car, 'on_date': day, 'to_user': danaId},
          );
        }
        // Dated ahead: Dana's window on the planned car now ends today, and
        // Eva's opens tomorrow.
        await alice.rpc(
          'hand_over_vehicle',
          params: {
            'target_vehicle': planned,
            'on_date': utcDay(1),
            'to_user': evaId,
          },
        );
        expect(
          (await dana.from('vehicles').select('id')).map((it) => it['id']),
          containsAll([since, today, planned]),
        );

        for (final car in [since, today, planned]) {
          final code =
              await alice.rpc(
                    'create_vehicle_transfer',
                    params: {'target_vehicle': car},
                  )
                  as String;
          await buyer.rpc(
            'redeem_vehicle_transfer',
            params: {'transfer_code': code, 'target_household': buyerHousehold},
          );
        }

        expect(
          await dana.from('vehicles').select('id').inFilter('id', [
            since,
            today,
            planned,
          ]),
          isEmpty,
        );
        final log = await admin
            .from('vehicle_assignments')
            .select('vehicle_id, user_id, to_date')
            .inFilter('vehicle_id', [since, today, planned]);
        expect(
          [
            for (final row in log)
              (row['vehicle_id'], row['user_id'], row['to_date']),
          ],
          unorderedEquals([
            (since, danaId, utcDay(-1)),
            (planned, danaId, utcDay(-1)),
          ]),
          reason:
              'the window opened on the day of the sale and the one planned '
              'for tomorrow never covered a day; the two that did end '
              'yesterday',
        );
        for (final car in [since, today, planned]) {
          for (final day in [utcDay(), utcDay(1)]) {
            expect(
              await buyer.rpc(
                'driver_on',
                params: {'target_vehicle': car, 'on_date': day},
              ),
              isNull,
              reason: 'nobody the seller named drives the sold car on $day',
            );
          }
        }
      });

      test('driver_on() answers the fixture', () async {
        final fixture =
            jsonDecode(
                  File(
                    'test/fixtures/assignment_resolution.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final carA = await newCar('Fixture v1');
        final carB = await newCar('Fixture v2');
        addTearDown(() async {
          await alice.from('vehicles').delete().eq('id', carA);
          await alice.from('vehicles').delete().eq('id', carB);
        });
        final vehicles = {'v1': carA, 'v2': carB, 'v3': otherCar};
        final users = {'ana': danaId, 'marko': evaId};

        for (final row
            in (fixture['assignments'] as List).cast<Map<String, dynamic>>()) {
          await admin.from('vehicle_assignments').insert({
            'vehicle_id': vehicles[row['vehicle_id']],
            'user_id': users[row['user_id']],
            'from_date': row['from_date'],
            'to_date': row['to_date'],
            'created_by': alice.auth.currentUser!.id,
          });
        }

        for (final testCase
            in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
          final answer = await alice.rpc(
            'driver_on',
            params: {
              'target_vehicle': vehicles[testCase['vehicle_id']],
              'on_date': testCase['on'],
            },
          );
          expect(
            answer,
            testCase['expected'] == null ? isNull : users[testCase['expected']],
            reason: testCase['name'] as String,
          );
        }
      });
    });

    group('incidents', () {
      test('a driver reports one on the assigned car', () async {
        final row = await dana
            .from('incidents')
            .insert({
              'vehicle_id': aliceVehicle,
              'kind': 'fine',
              'happened_on': '2026-09-12',
              'description': 'Parking fine, Vukovarska',
              'amount': 40,
              'created_by': danaId,
            })
            .select('id')
            .single();
        addTearDown(() => alice.from('incidents').delete().eq('id', row['id']));

        expect(
          await dana.from('incidents').select().eq('id', row['id']),
          hasLength(1),
        );
        // The admin manages it; a stranger sees nothing.
        await alice
            .from('incidents')
            .update({'status': 'paid', 'resolved_on': '2026-09-15'})
            .eq('id', row['id']);
        final after = await alice
            .from('incidents')
            .select('status')
            .eq('id', row['id'])
            .single();
        expect(after['status'], 'paid');
        expect(await carol.from('incidents').select(), isEmpty);
      });

      test('not on the other car, and not the admin\'s to edit', () async {
        await expectLater(
          dana.from('incidents').insert({
            'vehicle_id': otherCar,
            'kind': 'damage',
            'happened_on': '2026-09-12',
            'description': 'Not my car',
            'created_by': danaId,
          }),
          refusedWith('42501'),
        );
        final theirs = await alice
            .from('incidents')
            .insert({
              'vehicle_id': aliceVehicle,
              'kind': 'damage',
              'happened_on': '2026-09-12',
              'description': 'Dent on the tailgate',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('incidents').delete().eq('id', theirs['id']),
        );

        await dana
            .from('incidents')
            .update({'description': 'Nothing happened'})
            .eq('id', theirs['id']);
        final after = await alice
            .from('incidents')
            .select('description')
            .eq('id', theirs['id'])
            .single();
        expect(after['description'], 'Dent on the tailgate');
      });

      test('a photo of one is an attachment of kind incident', () async {
        final incident = await alice
            .from('incidents')
            .insert({
              'vehicle_id': aliceVehicle,
              'kind': 'accident',
              'happened_on': '2026-09-12',
              'description': 'Rear-ended at the lights',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('id')
            .single();
        addTearDown(
          () => alice.from('incidents').delete().eq('id', incident['id']),
        );

        final photo = await alice
            .from('attachments')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_kind': 'incident',
              'entry_id': incident['id'],
              'storage_path': '$aliceVehicle/${incident['id']}-photo.jpg',
              'file_name': 'photo.jpg',
              'created_by': alice.auth.currentUser!.id,
            })
            .select('entry_kind')
            .single();
        addTearDown(
          () => alice
              .from('attachments')
              .delete()
              .eq('storage_path', '$aliceVehicle/${incident['id']}-photo.jpg'),
        );
        expect(photo['entry_kind'], 'incident');
        // The check constraint is still there for what it does not name.
        await expectLater(
          alice.from('attachments').insert({
            'vehicle_id': aliceVehicle,
            'entry_kind': 'complaint',
            'entry_id': incident['id'],
            'storage_path': '$aliceVehicle/${incident['id']}-nope.jpg',
            'file_name': 'nope.jpg',
            'created_by': alice.auth.currentUser!.id,
          }),
          refusedWith('23514'),
        );
      });
    });

    group('paid with, and paid back', () {
      late String entry;

      setUp(() async {
        final row = await dana
            .from('cost_entries')
            .insert({
              'vehicle_id': aliceVehicle,
              'entry_date': '2026-09-13',
              'category': 'parking',
              'amount': 12,
              'paid_with': 'own_money',
              'created_by': danaId,
            })
            .select('id')
            .single();
        entry = row['id'] as String;
      });

      tearDown(() => alice.from('cost_entries').delete().eq('id', entry));

      test('the method is one of three or nothing', () async {
        await expectLater(
          alice
              .from('cost_entries')
              .update({'paid_with': 'bitcoin'})
              .eq('id', entry),
          refusedWith('23514'),
        );
        await alice
            .from('cost_entries')
            .update({'paid_with': null})
            .eq('id', entry);
      });

      test('only an admin marks an entry paid back', () async {
        await expectLater(
          dana
              .from('cost_entries')
              .update({'reimbursed_at': '2026-09-14T10:00:00Z'})
              .eq('id', entry),
          refusedWith('42501'),
        );
        // The driver's other edits still land.
        await dana.from('cost_entries').update({'amount': 13}).eq('id', entry);

        await alice
            .from('cost_entries')
            .update({'reimbursed_at': '2026-09-14T10:00:00Z'})
            .eq('id', entry);
        final row = await alice
            .from('cost_entries')
            .select('reimbursed_at, amount')
            .eq('id', entry)
            .single();
        expect(row['reimbursed_at'], isNotNull);
        expect((row['amount'] as num).toDouble(), 13);
      });

      test('an admin asks for a receipt reminder; nobody else can', () async {
        // The row is what is asserted. The push behind it reads the Vault,
        // which holds no endpoint here, so the function returns quietly.
        final id = await alice.rpc(
          'request_receipt_reminder',
          params: {
            'target_vehicle': aliceVehicle,
            'kind': 'cost',
            'entry': entry,
            'driver': danaId,
          },
        );
        addTearDown(
          () => admin.from('receipt_reminders').delete().eq('id', id),
        );

        final rows = await alice
            .from('receipt_reminders')
            .select('user_id, entry_date, sent_at')
            .eq('id', id);
        expect(rows.single['user_id'], danaId);
        expect(rows.single['entry_date'], '2026-09-13');
        expect(rows.single['sent_at'], isNull);
        expect(await dana.from('receipt_reminders').select(), isEmpty);
        await expectLater(
          eva.rpc(
            'request_receipt_reminder',
            params: {
              'target_vehicle': aliceVehicle,
              'kind': 'cost',
              'entry': entry,
              'driver': danaId,
            },
          ),
          refusedWith('42501'),
        );
        await expectLater(
          alice.rpc(
            'request_receipt_reminder',
            params: {
              'target_vehicle': otherCar,
              'kind': 'cost',
              'entry': entry,
              'driver': danaId,
            },
          ),
          refusedWith('P0002'),
          reason: 'the entry is not on that car',
        );
      });
    });
  });
}
