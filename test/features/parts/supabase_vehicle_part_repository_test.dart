import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/vehicle_part.dart';
import 'package:garage/features/parts/data/supabase_vehicle_part_repository.dart';

import '../../support/fake_supabase_http.dart';

void main() {
  final row = {
    'id': 'p1',
    'vehicle_id': 'v1',
    'service_type_key': 'service_oil_change',
    'spec': '5W-30 ACEA C3',
    'notes': 'Castrol Edge, 4.3 l with filter',
    'created_by': 'u1',
    'created_at': '2026-09-07T10:00:00Z',
  };

  test('maps every column onto the entity', () {
    expect(
      vehiclePartFromRow(row),
      VehiclePart(
        id: 'p1',
        vehicleId: 'v1',
        serviceTypeKey: 'service_oil_change',
        spec: '5W-30 ACEA C3',
        notes: 'Castrol Edge, 4.3 l with filter',
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 9, 7, 10),
      ),
    );
  });

  test('an author since deleted still reads', () {
    expect(vehiclePartFromRow({...row, 'created_by': null}).createdBy, '');
  });

  test('writes only the columns an edit may change, trimmed', () {
    final written = vehiclePartToRow(
      const VehiclePart(
        id: 'p1',
        vehicleId: 'v1',
        serviceTypeKey: 'service_oil_change',
        spec: '  5W-30 ACEA C3 ',
        createdBy: 'u1',
      ),
    );

    expect(written.keys, {'service_type_key', 'spec', 'notes'});
    expect(written['spec'], '5W-30 ACEA C3');
  });

  // A driver reads the assigned car's parts and holds no write on them
  // (migration 0080), and Postgres answers a write the policy filters out
  // with zero rows rather than an error. An edit and a delete read the id
  // back and treat none as the refusal it is; a new part is an upsert, which
  // the insert policy refuses out loud.
  group('a write the policy filtered', () {
    const part = VehiclePart(
      id: 'p1',
      vehicleId: 'v1',
      serviceTypeKey: 'service_oil_change',
      spec: '5W-30 ACEA C3',
      createdBy: 'u1',
    );

    SupabaseVehiclePartRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseVehiclePartRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('an edit reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'p1'},
          ],
        ),
      );

      await repositoryOver(server).save(part);

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/vehicle_parts');
      expect(sent.url.queryParameters['id'], 'eq.p1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).save(part),
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
            {'id': 'p1'},
          ],
        ),
      );

      await repositoryOver(server).delete('p1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.p1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).delete('p1'),
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
