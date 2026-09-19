import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/features/trips/data/supabase_route_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> row({Object? by = 'u1'}) {
  return {
    'id': 'r1',
    'household_id': 'h1',
    'name': 'Home → Work',
    'created_by': ?by,
    'created_at': '2026-09-01T07:10:00Z',
  };
}

void main() {
  test('reading a row maps every column onto the entity', () {
    final route = routeFromRow(row());

    expect(route.id, 'r1');
    expect(route.householdId, 'h1');
    expect(route.name, 'Home → Work');
    expect(route.createdBy, 'u1');
    expect(route.createdAt, DateTime.utc(2026, 9, 1, 7, 10));
  });

  test('a route whose author has since been deleted still reads', () {
    // 0061 keeps the row and nulls the author, the same way 0059 does for a
    // guest pass. A crash here would take the whole picker with it.
    expect(routeFromRow(row(by: null)).createdBy, '');
  });

  // A driver reads the garage's routes and holds no write on them (migration
  // 0080), and Postgres answers a write the policy filters out with zero
  // rows rather than an error. A rename and a delete read the id back and
  // treat none as the refusal it is.
  group('a write the policy filtered', () {
    SupabaseRouteRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseRouteRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('a rename reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'r1'},
          ],
        ),
      );

      await repositoryOver(server).rename('r1', 'Home → Office');

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/routes');
      expect(sent.url.queryParameters['id'], 'eq.r1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a rename that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).rename('r1', 'Home → Office'),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });

    test('a delete reads back the row it took', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'r1'},
          ],
        ),
      );

      await repositoryOver(server).delete('r1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.r1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).delete('r1'),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });
  });
}
