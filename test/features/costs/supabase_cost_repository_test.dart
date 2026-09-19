import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/company/payment_method.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';
import 'package:garage/features/costs/data/supabase_cost_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> row({Object? amount = 120.5, Object? odometer = 51140}) {
  return {
    'id': 'c1',
    'vehicle_id': 'v1',
    'entry_date': '2026-06-01',
    'category': CostCategories.insurance,
    'amount': amount,
    'odometer_km': odometer,
    'notes': 'annual policy',
    'created_by': 'u1',
    'created_at': '2026-06-01T10:00:00Z',
  };
}

CostEntry cost({double amount = 120.5, int? odometerKm = 51140}) {
  return CostEntry(
    id: 'c1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 6, 1),
    category: CostCategories.insurance,
    amount: amount,
    odometerKm: odometerKm,
    notes: 'annual policy',
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 6, 1, 10),
  );
}

void main() {
  group('reading a row', () {
    test('maps every column onto the entity', () {
      expect(costEntryFromRow(row()), cost());
    });

    test('reads the date-only column as UTC midnight', () {
      final date = costEntryFromRow(row()).date;

      expect(date.isUtc, isTrue);
      expect(date, DateTime.utc(2026, 6, 1));
    });

    test('widens an integer amount to double', () {
      expect(costEntryFromRow(row(amount: 120)).amount, 120.0);
    });

    test('an entry logged without an odometer reads as null', () {
      expect(costEntryFromRow(row(odometer: null)).odometerKm, isNull);
    });
  });

  group('writing a row', () {
    test('names the columns the table actually has', () {
      expect(costEntryToRow(cost()).keys, {
        'entry_date',
        'category',
        'amount',
        'odometer_km',
        'notes',
        'vignette_country',
        'vignette_validity',
        'paid_with',
      });
    });

    test('the payment method and the paid-back stamp ride along', () {
      final entry = costEntryFromRow({
        ...row(),
        'paid_with': 'own_money',
        'reimbursed_at': '2026-09-10T08:00:00+00:00',
      });

      expect(entry.paidWith, PaymentMethod.ownMoney);
      expect(entry.reimbursedAt, DateTime.utc(2026, 9, 10, 8));
      expect(costEntryToRow(entry)['paid_with'], 'own_money');
      expect(
        costEntryToRow(entry).containsKey('reimbursed_at'),
        isFalse,
        reason: 'the console writes that column, never a sheet',
      );
    });

    test('a method the app does not know reads as none', () {
      expect(
        costEntryFromRow({...row(), 'paid_with': 'crypto'}).paidWith,
        isNull,
      );
    });

    test('writes the date as a date-only string', () {
      expect(costEntryToRow(cost())['entry_date'], '2026-06-01');
    });

    test('never sends id or created_by, which the server owns', () {
      final written = costEntryToRow(cost());

      expect(written.containsKey('id'), isFalse);
      expect(written.containsKey('created_by'), isFalse);
    });
  });

  test('a row survives the round trip unchanged', () {
    final written = costEntryToRow(cost());
    final reread = costEntryFromRow({
      ...written,
      'id': 'c1',
      'vehicle_id': 'v1',
      'created_by': 'u1',
      'created_at': '2026-06-01T10:00:00Z',
    });

    expect(reread, cost());
  });

  // The sheet has always asked which country's vignette and for how long, and
  // never saved either — the fields lived only in the sheet's own widget
  // state and were gone the moment it closed.
  group('a vignette\'s country and validity', () {
    test('round-trip through the row unchanged', () {
      final written = costEntryToRow(
        cost().copyWith(
          category: CostCategories.vignette,
          vignetteCountry: VignetteCountry.slovenia,
          vignetteValidity: VignetteValidity.days7,
        ),
      );

      expect(written['vignette_country'], 'SI');
      expect(written['vignette_validity'], 'days7');

      final reread = costEntryFromRow({
        ...written,
        'id': 'c1',
        'vehicle_id': 'v1',
        'created_by': 'u1',
        'created_at': '2026-06-01T10:00:00Z',
      });

      expect(reread.vignetteCountry, VignetteCountry.slovenia);
      expect(reread.vignetteValidity, VignetteValidity.days7);
    });

    test('are null for every entry that is not a vignette', () {
      final written = costEntryToRow(cost());

      expect(written['vignette_country'], isNull);
      expect(written['vignette_validity'], isNull);
    });

    test('an unrecognised stored code or key reads as null, not a guess', () {
      final read = costEntryFromRow({
        ...row(),
        'vignette_country': 'ZZ',
        'vignette_validity': 'nonsense',
      });

      expect(read.vignetteCountry, isNull);
      expect(read.vignetteValidity, isNull);
    });
  });

  // A driver sees every cost on the assigned car and may edit only their own
  // (migration 0080). Postgres answers the edit the policy filters out with
  // zero rows rather than an error, so the repository reads the id back and
  // treats none as the refusal it is.
  group('a write the policy filtered', () {
    SupabaseCostRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseCostRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('an edit reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'c1'},
          ],
        ),
      );

      await repositoryOver(server).update(cost());

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/cost_entries');
      expect(sent.url.queryParameters['id'], 'eq.c1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('an edit that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).update(cost()),
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
            {'id': 'c1'},
          ],
        ),
      );

      await repositoryOver(server).delete('c1');

      final sent = server.requests.single;
      expect(sent.method, 'DELETE');
      expect(sent.url.queryParameters['id'], 'eq.c1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a delete that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).delete('c1'),
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
