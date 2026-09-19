import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/features/maintenance/data/supabase_maintenance_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> serviceRow({Object? cost = 210.5, Object? shop = 'Auto'}) {
  return {
    'id': 's1',
    'vehicle_id': 'v1',
    'entry_date': '2026-04-02',
    'odometer_km': 120000,
    'service_type_keys': <dynamic>['service_oil_change', 'service_oil_filter'],
    'cost': cost,
    'shop': shop,
    'notes': null,
    'created_by': 'u1',
    'diy': false,
    'parts_cost': null,
    'labor_cost': null,
    'parts_detail': null,
    'warranty_until': null,
    'measurements': null,
    'fault_codes': null,
    'created_at': '2026-04-02T10:00:00Z',
  };
}

ServiceEntry service({double? cost = 210.5, String? shop = 'Auto'}) {
  return ServiceEntry(
    id: 's1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 4, 2),
    odometerKm: 120000,
    serviceTypeKeys: const ['service_oil_change', 'service_oil_filter'],
    createdBy: 'u1',
    cost: cost,
    shop: shop,
    createdAt: DateTime.utc(2026, 4, 2, 10),
  );
}

Map<String, dynamic> ruleRow({
  Object? intervalKm = 15000,
  bool oneTime = false,
  Object? dueDate,
  Object? active = true,
}) {
  return {
    'id': 'r1',
    'vehicle_id': 'v1',
    'service_type_key': 'service_oil_change',
    'interval_km': intervalKm,
    'interval_months': 12,
    'one_time': oneTime,
    'due_date': dueDate,
    'due_odometer_km': null,
    'active': active,
    'issued_date': null,
  };
}

ReminderRule rule({int? intervalKm = 15000}) {
  return ReminderRule(
    id: 'r1',
    vehicleId: 'v1',
    serviceTypeKey: 'service_oil_change',
    intervalKm: intervalKm,
    intervalMonths: 12,
  );
}

void main() {
  group('service entries', () {
    test('a row maps onto the entity', () {
      expect(serviceEntryFromRow(serviceRow()), service());
    });

    test('the key list is read as strings, not dynamics', () {
      expect(
        serviceEntryFromRow(serviceRow()).serviceTypeKeys,
        isA<List<String>>(),
      );
    });

    test('a shopless, costless service reads as nulls', () {
      final read = serviceEntryFromRow(serviceRow(cost: null, shop: null));

      expect(read.cost, isNull);
      expect(read.shop, isNull);
    });

    test('an integer cost widens to double', () {
      expect(serviceEntryFromRow(serviceRow(cost: 210)).cost, 210.0);
    });

    test('writing names the columns the table has', () {
      expect(serviceEntryToRow(service()).keys, {
        'vehicle_id',
        'entry_date',
        'odometer_km',
        'service_type_keys',
        'cost',
        'shop',
        'notes',
        'diy',
        'parts_cost',
        'labor_cost',
        'parts_detail',
        'warranty_until',
        'measurements',
        'fault_codes',
        'paid_with',
      });
    });

    test('the payment method and the paid-back stamp ride along', () {
      final entry = serviceEntryFromRow({
        ...serviceRow(),
        'paid_with': 'own_money',
        'reimbursed_at': '2026-09-10T08:00:00+00:00',
      });

      expect(entry.paidWith, PaymentMethod.ownMoney);
      expect(entry.reimbursedAt, DateTime.utc(2026, 9, 10, 8));
      expect(serviceEntryToRow(entry)['paid_with'], 'own_money');
      expect(
        serviceEntryToRow(entry).containsKey('reimbursed_at'),
        isFalse,
        reason: 'the console writes that column, never a sheet',
      );
    });

    test('a method the app does not know reads as none', () {
      expect(
        serviceEntryFromRow({...serviceRow(), 'paid_with': 'crypto'}).paidWith,
        isNull,
      );
    });

    test('the deeper fields read back off a row', () {
      final read = serviceEntryFromRow({
        ...serviceRow(),
        'diy': true,
        'parts_cost': 42.5,
        'labor_cost': 0,
        'parts_detail': 'Castrol 5W-30, filter W712/95',
        'warranty_until': '2028-04-02',
        'measurements': {'brake_pad_front_mm': 6.5},
      });

      expect(read.diy, isTrue);
      expect(read.partsCost, 42.5);
      expect(read.laborCost, 0);
      expect(read.partsDetail, 'Castrol 5W-30, filter W712/95');
      expect(read.warrantyUntil, DateTime.utc(2028, 4, 2));
      expect(read.measurements, {'brake_pad_front_mm': 6.5});
    });

    test('a row from before the deeper fields existed still reads', () {
      final bare = Map<String, dynamic>.from(serviceRow())
        ..remove('diy')
        ..remove('parts_cost')
        ..remove('measurements');

      final read = serviceEntryFromRow(bare);

      expect(read.diy, isFalse);
      expect(read.partsCost, isNull);
      expect(read.measurements, isEmpty);
    });

    test('fault codes read back as typed', () {
      final read = serviceEntryFromRow({
        ...serviceRow(),
        'fault_codes': 'P0301, P0171',
      });

      expect(read.faultCodes, 'P0301, P0171');
    });

    test('a measurement this version does not know is dropped', () {
      final read = serviceEntryFromRow({
        ...serviceRow(),
        'measurements': {'brake_pad_front_mm': 6.5, 'flux_capacitor': 88},
      });

      expect(read.measurements, {'brake_pad_front_mm': 6.5});
    });

    test('no readings write as null rather than an empty object', () {
      expect(serviceEntryToRow(service())['measurements'], isNull);
    });

    test('a row survives the round trip unchanged', () {
      final written = serviceEntryToRow(service());
      final reread = serviceEntryFromRow({
        ...written,
        'id': 's1',
        'created_by': 'u1',
        'created_at': '2026-04-02T10:00:00Z',
      });

      expect(reread, service());
    });
  });

  group('reminder rules', () {
    test('a row maps onto the entity', () {
      expect(reminderRuleFromRow(ruleRow()), rule());
    });

    test('a one-off rule keeps its due date as UTC midnight', () {
      final read = reminderRuleFromRow(
        ruleRow(oneTime: true, intervalKm: null, dueDate: '2026-09-30'),
      );

      expect(read.oneTime, isTrue);
      expect(read.dueDate, DateTime.utc(2026, 9, 30));
      expect(read.dueDate!.isUtc, isTrue);
    });

    test('a rule with no due date reads as null rather than throwing', () {
      expect(reminderRuleFromRow(ruleRow()).dueDate, isNull);
    });

    test('writing names the columns the table has', () {
      expect(reminderRuleToRow(rule()).keys, {
        'vehicle_id',
        'service_type_key',
        'interval_km',
        'interval_months',
        'one_time',
        'due_date',
        'due_odometer_km',
        'active',
        'issued_date',
      });
    });

    test('a row survives the round trip unchanged', () {
      final written = reminderRuleToRow(rule());
      final reread = reminderRuleFromRow({...written, 'id': 'r1'});

      expect(reread, rule());
    });

    test('an issued date round-trips through the row unchanged', () {
      final written = reminderRuleToRow(
        rule().copyWith(
          oneTime: true,
          dueDate: DateTime.utc(2027, 5, 20),
          issuedDate: DateTime.utc(2026, 5, 20),
        ),
      );

      expect(written['issued_date'], '2026-05-20');

      final reread = reminderRuleFromRow({...written, 'id': 'r1'});

      expect(reread.issuedDate, DateTime.utc(2026, 5, 20));
    });
  });

  group('service types', () {
    test('a preset row maps onto the type', () {
      final type = serviceTypeFromRow({
        'key': 'service_timing_belt',
        'default_interval_km': 120000,
        'default_interval_months': 72,
        'is_statutory': false,
        'country_code': null,
      });

      expect(type.key, 'service_timing_belt');
      expect(type.defaultIntervalKm, 120000);
      expect(type.defaultIntervalMonths, 72);
      expect(type.isStatutory, isFalse);
      expect(type.countryCode, isNull);
    });

    test('a statutory row carries its country', () {
      final type = serviceTypeFromRow({
        'key': 'service_technical_inspection',
        'default_interval_km': null,
        'default_interval_months': 24,
        'is_statutory': true,
        'country_code': 'HR',
      });

      expect(type.isStatutory, isTrue);
      expect(type.countryCode, 'HR');
    });

    test('a missing statutory flag defaults to false', () {
      final type = serviceTypeFromRow({'key': 'service_wipers'});

      expect(type.isStatutory, isFalse);
    });
  });

  // A driver sees every service on the assigned car and may edit only their
  // own (migration 0080). Postgres answers the edit the policy filters out
  // with zero rows rather than an error, so the repository reads the id back
  // and treats none as the refusal it is.
  group('a service write the policy filtered', () {
    SupabaseMaintenanceRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseMaintenanceRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('an edit reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 's1'},
          ],
        ),
      );

      await repositoryOver(server).updateServiceEntry(service());

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/service_entries');
      expect(sent.url.queryParameters['id'], 'eq.s1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).updateServiceEntry(service()),
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
            {'id': 's1'},
          ],
        ),
      );

      await repositoryOver(server).deleteServiceEntry('s1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/rest/v1/service_entries');
      expect(sent.url.queryParameters['id'], 'eq.s1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).deleteServiceEntry('s1'),
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

  // The same for a rule's delete: a driver reads the assigned car's
  // intervals and holds no write on them. Not for `completeOneTimeRules`,
  // which runs after a driver's service entry has landed and must not report
  // a failure over an entry that was saved.
  group('a rule delete the policy filtered', () {
    SupabaseMaintenanceRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseMaintenanceRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('reads back the row it took', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'r1'},
          ],
        ),
      );

      await repositoryOver(server).deleteRule('r1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.path, '/rest/v1/reminder_rules');
      expect(sent.url.queryParameters['id'], 'eq.r1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).deleteRule('r1'),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });

    test('an edit of a recurring rule reads back the row it changed', () async {
      // The same menu offers a driver the edit and the delete.
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'r1'},
          ],
        ),
      );

      await repositoryOver(server).upsertRule(rule());

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.queryParameters['id'], 'eq.r1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).upsertRule(rule()),
        throwsA(
          isA<AppFailure>().having(
            (it) => it.kind,
            'kind',
            AppFailureKind.permission,
          ),
        ),
      );
    });

    test('completing one-off rules after a service stays quiet', () async {
      // A 204 with nothing in it, as PostgREST answers an update the policy
      // filtered — and as it answers one that matched no rule at all.
      final server = FakeSupabaseServer((request) => (204, null));

      await repositoryOver(
        server,
      ).completeOneTimeRules('v1', const ['service_oil_change']);

      expect(
        server.requests.single.url.queryParameters.containsKey('select'),
        isFalse,
      );
    });
  });
}
