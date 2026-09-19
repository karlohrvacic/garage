import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/features/odometer/data/supabase_odometer_repository.dart';

import '../../support/fake_supabase_http.dart';

/// The mapping is the only part of a repository a unit test can reach, and it
/// is also the part that fails on a user's phone rather than in CI: a renamed
/// column compiles, passes analysis, and throws on the first read.
Map<String, dynamic> row({Object? notes = 'after the service', Object? by}) {
  return {
    'id': 'o1',
    'vehicle_id': 'v1',
    'entry_date': '2026-06-01',
    'odometer_km': 84000,
    'notes': notes,
    'created_by': ?by,
    'created_at': '2026-06-01T10:00:00Z',
  };
}

OdometerEntry reading({String? notes = 'after the service'}) {
  return OdometerEntry(
    id: 'o1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    odometerKm: 84000,
    notes: notes,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 6, 1, 10),
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(odometerEntryFromRow(row(by: 'u1')), reading());
    });

    test('reads the date-only column as UTC midnight', () {
      final date = odometerEntryFromRow(row(by: 'u1')).date;

      expect(
        date.isUtc,
        isTrue,
        reason: 'the UTC flag is load-bearing for entity equality',
      );
      expect(date, DateTime.utc(2026, 6, 1));
    });

    test('a reading recorded without a note reads as null', () {
      expect(odometerEntryFromRow(row(notes: null, by: 'u1')).notes, isNull);
    });

    test('an entry whose author has since been deleted still reads', () {
      // Account deletion nulls `created_by` rather than removing the row, so
      // this is a real shape rather than a defensive one.
      expect(odometerEntryFromRow(row()).createdBy, '');
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(odometerEntryToRow(reading()).keys, {
        'entry_date',
        'odometer_km',
        'notes',
      });
    });

    test('writes the date as a date-only string', () {
      expect(odometerEntryToRow(reading())['entry_date'], '2026-06-01');
    });

    test('never sends id or created_by, which the server owns', () {
      final written = odometerEntryToRow(reading());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
      expect(
        written.containsKey('vehicle_id'),
        isFalse,
        reason: 'an edit must not be able to move an entry to another car',
      );
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = odometerEntryToRow(reading());
    final reread = odometerEntryFromRow({
      ...written,
      'id': 'o1',
      'vehicle_id': 'v1',
      'created_by': 'u1',
      'created_at': '2026-06-01T10:00:00Z',
    });

    expect(reread, reading());
  });

  // A driver sees every reading on the assigned car and may edit only their
  // own (migration 0080). Postgres answers the edit the policy filters out
  // with zero rows rather than an error, so the repository reads the id back
  // and treats none as the refusal it is.
  group('a write the policy filtered', () {
    SupabaseOdometerRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseOdometerRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('an edit reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'o1'},
          ],
        ),
      );

      await repositoryOver(server).update(reading());

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/odometer_entries');
      expect(sent.url.queryParameters['id'], 'eq.o1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).update(reading()),
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
            {'id': 'o1'},
          ],
        ),
      );

      await repositoryOver(server).delete('o1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.o1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).delete('o1'),
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
