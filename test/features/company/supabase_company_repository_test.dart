import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/features/company/data/supabase_company_repository.dart';

import '../../support/fake_supabase_http.dart';

/// A row as Postgrest returns it: the two dates are date-only strings, the
/// stamps carry an offset, and the server-owned columns are always present.
Map<String, dynamic> assignmentRow({
  String id = 'a1',
  String? toDate,
  String? confirmedAt,
}) {
  return {
    'id': id,
    'vehicle_id': 'v1',
    'user_id': 'u2',
    'from_date': '2026-09-01',
    'to_date': toDate,
    'handover_odometer_km': 61000,
    'return_odometer_km': null,
    'note': 'Keys in the office',
    'confirmed_at': confirmedAt,
    'confirmed_by': confirmedAt == null ? null : 'u2',
    'created_by': 'u1',
    'created_at': '2026-09-01T08:00:00+00:00',
  };
}

ReadCache cache() =>
    ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1');

void main() {
  group('a row', () {
    test('maps onto the entity, dates as UTC days', () {
      final assignment = vehicleAssignmentFromRow(assignmentRow());

      expect(assignment.id, 'a1');
      expect(assignment.vehicleId, 'v1');
      expect(assignment.userId, 'u2');
      expect(assignment.fromDate, DateTime.utc(2026, 9, 1));
      expect(assignment.fromDate.isUtc, isTrue);
      expect(assignment.isOpen, isTrue);
      expect(assignment.isConfirmed, isFalse);
      expect(assignment.handoverOdometerKm, 61000);
      expect(assignment.returnOdometerKm, isNull);
      expect(assignment.note, 'Keys in the office');
      expect(assignment.createdBy, 'u1');
      expect(assignment.createdAt, DateTime.utc(2026, 9, 1, 8));
    });

    test('a closed, confirmed window reads as such', () {
      final assignment = vehicleAssignmentFromRow(
        assignmentRow(
          toDate: '2026-09-15',
          confirmedAt: '2026-09-01T09:00:00+00:00',
        ),
      );

      expect(assignment.toDate, DateTime.utc(2026, 9, 15));
      expect(assignment.isOpen, isFalse);
      expect(assignment.isConfirmed, isTrue);
      expect(assignment.confirmedAt, DateTime.utc(2026, 9, 1, 9));
      expect(assignment.confirmedBy, 'u2');
    });

    test('a window whose driver deleted their account has no driver', () {
      final assignment = vehicleAssignmentFromRow({
        ...assignmentRow(),
        'user_id': null,
        'created_by': null,
      });

      expect(assignment.userId, isNull);
      expect(assignment.createdBy, '');
    });
  });

  group('the requests', () {
    test('a handover is one call to the function', () async {
      final server = FakeSupabaseServer((request) {
        if (request.url.path == '/rest/v1/rpc/hand_over_vehicle') {
          return (200, 'a2');
        }
        return null;
      });
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      final id = await repository.handOver(
        vehicleId: 'v1',
        on: DateTime(2026, 9, 19, 23, 30),
        odometerKm: 62000,
        toUserId: 'u3',
        note: 'Keys in the office',
      );

      expect(id, 'a2');
      final sent = server.requests.single;
      expect(sent.method, 'POST');
      expect(sent.url.path, '/rest/v1/rpc/hand_over_vehicle');
      expect(jsonDecode(sent.body), {
        'target_vehicle': 'v1',
        // The day the sheet showed, not the UTC instant of a late evening.
        'on_date': '2026-09-19',
        'odometer_km': 62000,
        'to_user': 'u3',
        'handover_note': 'Keys in the office',
      });
    });

    test('taking a car back sends no driver', () async {
      // A function returning a null uuid answers with the JSON literal null,
      // which the client reads back as no id.
      final server = FakeSupabaseServer((request) => (200, null));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      final id = await repository.handOver(
        vehicleId: 'v1',
        on: DateTime.utc(2026, 9, 19),
      );

      expect(id, isNull);
      expect(jsonDecode(server.requests.single.body), {
        'target_vehicle': 'v1',
        'on_date': '2026-09-19',
        'odometer_km': null,
        'to_user': null,
        'handover_note': null,
      });
    });

    test('a second handover on a day is the failure the console names', () {
      final server = FakeSupabaseServer(
        (request) => (
          400,
          const {
            'code': 'P0006',
            'message': 'the car was already handed over on that date',
          },
        ),
      );
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      expect(
        () =>
            repository.handOver(vehicleId: 'v1', on: DateTime.utc(2026, 9, 19)),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.handoverClash,
          ),
        ),
      );
    });

    test('the fleet\'s log is read for the cars given', () async {
      final server = FakeSupabaseServer((request) {
        if (request.url.path == '/rest/v1/vehicle_assignments') {
          return (200, [assignmentRow()]);
        }
        return null;
      });
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      final assignments = await repository.assignmentsForVehicles(['v1', 'v2']);

      expect(assignments.single.id, 'a1');
      final sent = server.requests.single;
      expect(sent.method, 'GET');
      expect(sent.url.queryParameters['vehicle_id'], 'in.("v1","v2")');
      expect(sent.url.queryParameters['order'], 'from_date.desc.nullslast');
    });

    test('no cars, no request', () async {
      final server = FakeSupabaseServer((request) => (200, const []));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      expect(await repository.assignmentsForVehicles(const []), isEmpty);
      expect(server.requests, isEmpty);
    });

    test('the log is kept for when there is no signal', () async {
      // The same copy whatever order the garage listed its cars in.
      final store = InMemoryReadCacheStore();
      final server = FakeSupabaseServer((request) => (200, [assignmentRow()]));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: ReadCache(store: store, userId: () => 'u1'),
      );

      await repository.assignmentsForVehicles(['v2', 'v1']);

      expect(await store.read('u1/assignments/v1,v2'), isNotNull);
    });

    test('a driver reads their own windows', () async {
      final server = FakeSupabaseServer((request) {
        if (request.url.path == '/rest/v1/vehicle_assignments') {
          return (200, [assignmentRow()]);
        }
        return null;
      });
      await server.signIn(userId: 'u2');
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      final mine = await repository.mine();

      expect(mine.single.userId, 'u2');
      final sent = server.requests.last;
      expect(sent.url.path, '/rest/v1/vehicle_assignments');
      expect(sent.url.queryParameters['user_id'], 'eq.u2');
      expect(sent.url.queryParameters['order'], 'from_date.desc.nullslast');
    });

    test('a sign-off is one call to the function', () async {
      final server = FakeSupabaseServer((request) => (204, const []));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      await repository.confirm('a1');

      final sent = server.requests.single;
      expect(sent.url.path, '/rest/v1/rpc/confirm_vehicle_assignment');
      expect(jsonDecode(sent.body), {'assignment_id': 'a1'});
    });

    test('removing a window deletes its row', () async {
      final server = FakeSupabaseServer((request) => (204, const []));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      await repository.deleteAssignment('a1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/rest/v1/vehicle_assignments');
      expect(sent.url.queryParameters['id'], 'eq.a1');
    });

    test('marking entries paid back writes one update per table', () async {
      final server = FakeSupabaseServer((request) => (204, const []));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      await repository.markReimbursed(
        table: 'cost_entries',
        ids: ['c1', 'c2'],
        at: DateTime.utc(2026, 9, 19, 10),
      );

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/cost_entries');
      expect(sent.url.queryParameters['id'], 'in.("c1","c2")');
      expect(jsonDecode(sent.body), {
        'reimbursed_at': '2026-09-19T10:00:00.000Z',
      });
    });

    test('a receipt reminder is one call to the function', () async {
      final server = FakeSupabaseServer((request) => (200, 'r1'));
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      await repository.requestReceiptReminder(
        vehicleId: 'v1',
        kind: 'fuel',
        entryId: 'f1',
        driverId: 'u2',
      );

      final sent = server.requests.single;
      expect(sent.url.path, '/rest/v1/rpc/request_receipt_reminder');
      expect(jsonDecode(sent.body), {
        'target_vehicle': 'v1',
        'kind': 'fuel',
        'entry': 'f1',
        'driver': 'u2',
      });
    });

    test('a refusal arrives as a failure, never as the raw exception', () {
      final server = FakeSupabaseServer(
        (request) => (
          401,
          const {'code': '42501', 'message': 'only an admin hands a car over'},
        ),
      );
      final repository = SupabaseCompanyRepository(
        server.client,
        cache: cache(),
      );

      expect(
        () => repository.deleteAssignment('a1'),
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
