import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/features/tyres/data/supabase_tyre_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> setRow({
  bool fitted = true,
  Object? retiredAt,
  List<dynamic>? readings,
}) {
  return {
    'id': 't1',
    'vehicle_id': 'v1',
    'name': 'Winter — studded',
    'season': 'winter',
    'size': '205/55 R16',
    'storage_location': 'Cellar',
    'fitted': fitted,
    'fitted_at': '2026-11-01',
    'retired_at': retiredAt,
    'created_by': 'u1',
    'tyre_readings': readings,
  };
}

Map<String, dynamic> readingRow({Object? frontLeft = 6.5}) {
  return {
    'id': 'r1',
    'reading_date': '2026-10-01',
    'odometer_km': 51000,
    'front_left_mm': frontLeft,
    'front_right_mm': 6.4,
    'rear_left_mm': 7.0,
    'rear_right_mm': 7.1,
  };
}

void main() {
  group('reading a set', () {
    test('maps every column onto the entity', () {
      final set = tyreSetFromRow(setRow());

      expect(set.id, 't1');
      expect(set.name, 'Winter — studded');
      expect(set.season, TyreSeason.winter);
      expect(set.size, '205/55 R16');
      expect(set.storageLocation, 'Cellar');
      expect(set.fitted, isTrue);
      expect(set.fittedAt, DateTime.utc(2026, 11, 1));
      expect(set.isRetired, isFalse);
    });

    test('a retired set carries when it was retired', () {
      final set = tyreSetFromRow(setRow(retiredAt: '2027-03-01'));

      expect(set.retiredAt, DateTime.utc(2027, 3, 1));
      expect(set.isRetired, isTrue);
    });

    test('its readings come along when the query joined them', () {
      final set = tyreSetFromRow(setRow(readings: [readingRow()]));

      expect(set.readings, hasLength(1));
      expect(set.readings.single.date, DateTime.utc(2026, 10, 1));
      expect(set.readings.single.frontLeftMm, 6.5);
      expect(set.latestReading?.shallowestMm, 6.4);
    });

    test('a set queried without readings simply has none', () {
      expect(tyreSetFromRow(setRow()).readings, isEmpty);
    });

    test('a corner nobody measured stays null', () {
      final set = tyreSetFromRow(
        setRow(readings: [readingRow(frontLeft: null)]),
      );

      expect(set.readings.single.frontLeftMm, isNull);
      expect(set.readings.single.shallowestMm, 6.4);
    });
  });

  group('writing a set', () {
    test('names the columns the table has', () {
      final row = tyreSetToRow(
        vehicleId: 'v1',
        name: 'Winter',
        season: TyreSeason.winter,
        size: '205/55 R16',
        storageLocation: 'Cellar',
      );

      expect(row.keys, {
        'vehicle_id',
        'name',
        'season',
        'size',
        'storage_location',
        'manufactured_on',
        'manufactured_front_left',
        'manufactured_front_right',
        'manufactured_rear_left',
        'manufactured_rear_right',
      });
      expect(row['season'], 'winter');
    });
  });

  group('writing a reading', () {
    test('names the columns the table has', () {
      final row = tyreReadingToRow(
        tyreSetId: 't1',
        date: DateTime.utc(2026, 10, 1),
        odometerKm: 51000,
        frontLeftMm: 6.5,
        frontRightMm: null,
        rearLeftMm: null,
        rearRightMm: null,
      );

      expect(row.keys, {
        'tyre_set_id',
        'reading_date',
        'odometer_km',
        'front_left_mm',
        'front_right_mm',
        'rear_left_mm',
        'rear_right_mm',
      });
      expect(row['reading_date'], '2026-10-01');
      expect(row['front_right_mm'], isNull);
    });
  });

  // A driver reads the assigned car's tyres and holds no write on them
  // (migration 0080), and Postgres answers a write the policy filters out
  // with zero rows rather than an error. Every write on a set reads the id
  // back and treats none as the refusal it is.
  group('a write the policy filtered', () {
    SupabaseTyreRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseTyreRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    FakeSupabaseServer admitting() => FakeSupabaseServer(
      (request) => (
        200,
        const [
          {'id': 't1'},
        ],
      ),
    );

    FakeSupabaseServer refusing() =>
        FakeSupabaseServer((request) => (200, const []));

    test('an edit reads back the row it changed', () async {
      final server = admitting();

      await repositoryOver(
        server,
      ).updateSet(setId: 't1', name: 'Winter', season: TyreSeason.winter);

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/tyre_sets');
      expect(sent.url.queryParameters['id'], 'eq.t1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      await expectLater(
        repositoryOver(
          refusing(),
        ).updateSet(setId: 't1', name: 'Winter', season: TyreSeason.winter),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });

    test(
      'fitting reads back the set it put on, not the one it took off',
      () async {
        final server = admitting();

        await repositoryOver(server).fitSet(vehicleId: 'v1', setId: 't1');

        expect(server.requests, hasLength(2));
        final off = server.requests.first;
        expect(off.url.queryParameters['fitted'], 'eq.true');
        expect(
          off.url.queryParameters.containsKey('select'),
          isFalse,
          reason: 'no set may be fitted, and that is not a refusal',
        );
        final on = server.requests.last;
        expect(on.url.queryParameters['id'], 'eq.t1');
        expect(on.url.queryParameters['select'], 'id');
      },
    );

    test(
      'fitting a set the policy filters is the permission failure',
      () async {
        await expectLater(
          repositoryOver(refusing()).fitSet(vehicleId: 'v1', setId: 't1'),
          throwsA(
            isA<AppFailure>().having(
              (it) => it.kind,
              'kind',
              AppFailureKind.permission,
            ),
          ),
        );
      },
    );

    test('taking off, retiring and bringing back read back too', () async {
      for (final write in [
        (SupabaseTyreRepository r) => r.unfitSet('t1'),
        (SupabaseTyreRepository r) => r.retireSet('t1'),
        (SupabaseTyreRepository r) => r.unretireSet('t1'),
      ]) {
        final server = admitting();
        await write(repositoryOver(server));
        expect(server.requests.single.url.queryParameters['select'], 'id');

        await expectLater(
          write(repositoryOver(refusing())),
          throwsA(
            isA<AppFailure>().having(
              (it) => it.kind,
              'kind',
              AppFailureKind.permission,
            ),
          ),
        );
      }
    });

    test('a delete reads back the row it took', () async {
      final server = admitting();

      await repositoryOver(server).deleteSet('t1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.t1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      await expectLater(
        repositoryOver(refusing()).deleteSet('t1'),
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
