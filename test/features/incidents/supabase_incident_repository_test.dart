import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/incident.dart';
import 'package:garage/features/incidents/data/supabase_incident_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> row({String status = 'open', String? resolvedOn}) {
  return {
    'id': 'i1',
    'vehicle_id': 'v1',
    'kind': 'fine',
    'happened_on': '2026-09-12',
    'odometer_km': 61200,
    'description': 'Parking fine, Vukovarska',
    'amount': 40,
    'status': status,
    'resolved_on': resolvedOn,
    'created_by': 'u2',
    'created_at': '2026-09-12T18:00:00+00:00',
  };
}

ReadCache cache() =>
    ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1');

void main() {
  test('a row maps onto the entity, dates as UTC days', () {
    final incident = incidentFromRow(row());

    expect(incident.kind, IncidentKind.fine);
    expect(incident.happenedOn, DateTime.utc(2026, 9, 12));
    expect(incident.odometerKm, 61200);
    expect(incident.amount, 40);
    expect(incident.status, IncidentStatus.open);
    expect(incident.isOpen, isTrue);
    expect(incident.createdBy, 'u2');
  });

  test('a settled one reads as settled', () {
    final incident = incidentFromRow(
      row(status: 'paid', resolvedOn: '2026-09-15'),
    );

    expect(incident.status, IncidentStatus.paid);
    expect(incident.resolvedOn, DateTime.utc(2026, 9, 15));
    expect(incident.isOpen, isFalse);
  });

  test(
    'the writable row carries what an edit may change, and nothing else',
    () {
      final written = incidentToRow(incidentFromRow(row()));

      expect(written, {
        'kind': 'fine',
        'happened_on': '2026-09-12',
        'odometer_km': 61200,
        'description': 'Parking fine, Vukovarska',
        'amount': 40.0,
        'status': 'open',
        'resolved_on': null,
      });
    },
  );

  group('the requests', () {
    test('a car\'s incidents are read newest first', () async {
      final server = FakeSupabaseServer((request) {
        if (request.url.path == '/rest/v1/incidents') {
          return (200, [row()]);
        }
        return null;
      });
      final repository = SupabaseIncidentRepository(
        server.client,
        cache: cache(),
      );

      final incidents = await repository.forVehicle('v1');

      expect(incidents.single.id, 'i1');
      final sent = server.requests.single;
      expect(sent.method, 'GET');
      expect(sent.url.queryParameters['vehicle_id'], 'eq.v1');
      expect(sent.url.queryParameters['order'], 'happened_on.desc.nullslast');
    });

    test('a new report is inserted with its own id and the reporter', () async {
      final server = FakeSupabaseServer((request) => (201, const []));
      await server.signIn(userId: 'u2');
      final repository = SupabaseIncidentRepository(
        server.client,
        cache: cache(),
      );

      await repository.add(incidentFromRow(row()));

      final sent = server.requests.last;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/rest/v1/incidents');
      expect(jsonDecode(sent.body), {
        'id': 'i1',
        'kind': 'fine',
        'happened_on': '2026-09-12',
        'odometer_km': 61200,
        'description': 'Parking fine, Vukovarska',
        'amount': 40.0,
        'status': 'open',
        'resolved_on': null,
        'vehicle_id': 'v1',
        'created_by': 'u2',
      });
    });

    test('an edit reads back the row it changed', () async {
      final server = FakeSupabaseServer((request) {
        if (request.url.path == '/rest/v1/incidents') {
          return (
            200,
            const [
              {'id': 'i1'},
            ],
          );
        }
        return null;
      });
      final repository = SupabaseIncidentRepository(
        server.client,
        cache: cache(),
      );

      await repository.update(incidentFromRow(row()));

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.queryParameters['id'], 'eq.i1');
      expect(sent.url.queryParameters['select'], 'id');
      expect(jsonDecode(sent.body), isNot(contains('vehicle_id')));
    });

    test('an edit the policy filters is the permission failure', () async {
      // A driver editing another driver's report: the row is readable, the
      // update policy's `using` clause says no, and Postgres answers with
      // zero rows rather than an error. Reading the ids back is what tells
      // the sheet nothing changed.
      final server = FakeSupabaseServer((request) => (200, const []));
      final repository = SupabaseIncidentRepository(
        server.client,
        cache: cache(),
      );

      await expectLater(
        repository.update(incidentFromRow(row())),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });

    test('a delete the policy filters is the permission failure too', () async {
      final server = FakeSupabaseServer((request) => (200, const []));
      final repository = SupabaseIncidentRepository(
        server.client,
        cache: cache(),
      );

      await expectLater(
        repository.delete('i1'),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.i1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that took the row is quiet', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'i1'},
          ],
        ),
      );
      final repository = SupabaseIncidentRepository(
        server.client,
        cache: cache(),
      );

      await repository.delete('i1');

      expect(server.requests, hasLength(1));
    });
  });
}
