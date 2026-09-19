import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/features/household/data/supabase_garage_bootstrap_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_supabase_http.dart';
import 'garage_bootstrap_test.dart' show householdRow, vehicleRow;

/// The startup fetch against a server that answers like PostgREST, so what is
/// tested is the requests the repository really makes, not a stand-in for
/// them. The table answers with the caller's own cars only: a borrower has had
/// no read on `vehicles` since migration 0072, and a lent car arrives from
/// `guest_vehicles` instead.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearRecordedFailures();
  });

  SupabaseClient serverAnswering({
    required List<Map<String, dynamic>> households,
    required List<Map<String, dynamic>> vehicles,
    (int, Object)? lent,
    List<String>? asked,
  }) {
    final client = MockClient((request) async {
      asked?.add(request.url.path);
      // The client reads the request back off the response.
      http.Response json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
      return switch (request.url.path) {
        '/rest/v1/households' => json(households),
        '/rest/v1/vehicles' => json(vehicles),
        '/rest/v1/rpc/guest_vehicles' => json(
          lent?.$2 ?? const [],
          lent?.$1 ?? 200,
        ),
        _ => json(const {'message': 'not found'}, 404),
      };
    });
    return SupabaseClient(
      'http://127.0.0.1:54321',
      'anon-key',
      httpClient: client,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  }

  test('a lent car comes from the lending function', () async {
    final asked = <String>[];
    final repository = SupabaseGarageBootstrapRepository(
      serverAnswering(
        households: [householdRow(id: 'h1')],
        vehicles: [vehicleRow(id: 'v1', nickname: 'My Golf')],
        lent: (
          200,
          [vehicleRow(id: 'v9', nickname: 'Sister Clio', householdId: 'hers')],
        ),
        asked: asked,
      ),
    );

    final bootstrap = await repository.load();

    expect(bootstrap.vehiclesFor('h1').map((it) => it.id), ['v1']);
    expect(bootstrap.borrowedVehicles.map((it) => it.id), ['v9']);
    expect(asked, contains('/rest/v1/rpc/guest_vehicles'));
  });

  test('a lending function that fails costs the garage nothing', () async {
    // The web app and the migration ship on the same push in no fixed order,
    // so for a few minutes the function may not exist yet. An account's own
    // garage must not go dark because a borrowed car could not be fetched.
    final repository = SupabaseGarageBootstrapRepository(
      serverAnswering(
        households: [householdRow(id: 'h1')],
        vehicles: [vehicleRow(id: 'v1', nickname: 'My Golf')],
        lent: (404, {'code': 'PGRST202', 'message': 'function not found'}),
      ),
    );

    final bootstrap = await repository.load();

    expect(bootstrap.vehiclesFor('h1').map((it) => it.id), ['v1']);
    expect(bootstrap.borrowedVehicles, isEmpty);
    expect(
      recordedFailures,
      isNotEmpty,
      reason: 'a missing borrowed car is still worth a line in diagnostics',
    );
  });

  test(
    'a car both reads return is counted once, as the member reads it',
    () async {
      // A holder who has since joined the lender's garage sees the car as a
      // member; the function leaves such cars out, and the app does not trust
      // that alone. The copy kept is the table's, which carries what the
      // function withholds: a member is owed the price.
      final repository = SupabaseGarageBootstrapRepository(
        serverAnswering(
          households: [householdRow(id: 'h1')],
          vehicles: [
            {
              ...vehicleRow(id: 'v1', nickname: 'My Golf'),
              'purchase_price': 18500,
            },
          ],
          lent: (200, [vehicleRow(id: 'v1', nickname: 'My Golf')]),
        ),
      );

      final bootstrap = await repository.load();

      expect(bootstrap.vehiclesFor('h1').map((it) => it.id), ['v1']);
      expect(bootstrap.vehiclesFor('h1').single.purchasePrice, 18500);
      expect(bootstrap.borrowedVehicles, isEmpty);
    },
  );

  group("the caller's role", () {
    /// The same server as [serverAnswering], with sign-in: the role is read
    /// off the caller's own membership rows, which needs a caller.
    FakeSupabaseServer server({(int, Object)? memberships}) {
      return FakeSupabaseServer((request) {
        return switch (request.url.path) {
          '/rest/v1/households' => (200, [householdRow(id: 'h1')]),
          '/rest/v1/vehicles' => (200, const []),
          '/rest/v1/rpc/guest_vehicles' => (200, const []),
          '/rest/v1/household_members' =>
            memberships ??
                (
                  200,
                  const [
                    {'household_id': 'h1', 'role': 'driver'},
                  ],
                ),
          _ => null,
        };
      });
    }

    test('comes back with the garage', () async {
      final fake = server();
      await fake.signIn();
      final repository = SupabaseGarageBootstrapRepository(fake.client);

      final bootstrap = await repository.load();

      expect(bootstrap.roleIn('h1'), 'driver');
      final asked = fake.requests.singleWhere(
        (it) => it.url.path == '/rest/v1/household_members',
      );
      expect(asked.url.queryParameters['user_id'], 'eq.u1');
      expect(asked.url.queryParameters['select'], 'household_id,role');
    });

    test('that cannot be read costs the garage nothing', () async {
      // A build that predates the role-carrying policy must not lose its
      // garage over a request that only decides which list a driver sees.
      final fake = server(
        memberships: (401, {'code': '42501', 'message': 'permission denied'}),
      );
      await fake.signIn();
      final repository = SupabaseGarageBootstrapRepository(fake.client);

      final bootstrap = await repository.load();

      expect(bootstrap.households.single.id, 'h1');
      expect(bootstrap.roleIn('h1'), 'member');
      expect(recordedFailures, isNotEmpty);
    });

    test('is not asked for when nobody is signed in', () async {
      final fake = server();
      final repository = SupabaseGarageBootstrapRepository(fake.client);

      final bootstrap = await repository.load();

      expect(bootstrap.roleIn('h1'), 'member');
      expect(
        fake.requests.map((it) => it.url.path),
        isNot(contains('/rest/v1/household_members')),
      );
    });
  });
}
