import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/features/observations/data/supabase_observation_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> row({String? resolvedOn}) {
  return {
    'id': 'ob1',
    'vehicle_id': 'v1',
    'trip_id': null,
    'noticed_on': '2026-09-11',
    'odometer_km': 60200,
    'note': 'Squeal from the front left',
    'addressed_by': null,
    'resolved_on': resolvedOn,
    'created_by': 'u1',
    'created_at': '2026-09-11T08:00:00Z',
  };
}

void main() {
  test('a row maps onto the entity, the day as UTC midnight', () {
    final observation = observationFromRow(row());

    expect(observation.id, 'ob1');
    expect(observation.noticedOn, DateTime.utc(2026, 9, 11));
    expect(observation.odometerKm, 60200);
    expect(observation.note, 'Squeal from the front left');
    expect(observation.isOpen, isTrue);
    expect(observation.createdBy, 'u1');
  });

  test(
    'the writable row carries what an edit may change, and nothing else',
    () {
      expect(
        observationToRow(observationFromRow(row(resolvedOn: '2026-09-15'))),
        {
          'trip_id': null,
          'noticed_on': '2026-09-11',
          'odometer_km': 60200,
          'note': 'Squeal from the front left',
          'addressed_by': null,
          'resolved_on': '2026-09-15',
        },
      );
    },
  );

  // A driver sees every note on the assigned car and may edit only their own
  // (migration 0080). Postgres answers the edit the policy filters out with
  // zero rows rather than an error, so the repository reads the id back and
  // treats none as the refusal it is.
  group('a write the policy filtered', () {
    SupabaseObservationRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseObservationRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('an edit reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'ob1'},
          ],
        ),
      );

      await repositoryOver(server).update(observationFromRow(row()));

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/observations');
      expect(sent.url.queryParameters['id'], 'eq.ob1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).update(observationFromRow(row())),
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
            {'id': 'ob1'},
          ],
        ),
      );

      await repositoryOver(server).delete('ob1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.ob1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).delete('ob1'),
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
