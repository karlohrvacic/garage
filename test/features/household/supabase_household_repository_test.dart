import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/data/supabase_household_repository.dart';

import '../../support/fake_supabase_http.dart';

Map<String, dynamic> row() {
  return {
    'id': 'h1',
    'name': 'Hrvačić',
    'currency_code': 'EUR',
    'distance_unit': 'km',
    'volume_unit': 'liter',
    'bundling_window_days': 21,
    'bundling_window_km': 500,
    'tracking_level': 'beginner',
    'country_code': 'HR',
    'settlement_enabled': false,
  };
}

const _household = Household(
  id: 'h1',
  name: 'Hrvačić',
  currencyCode: 'EUR',
  distanceUnit: 'km',
  volumeUnit: 'liter',
  bundlingWindowDays: 21,
  bundlingWindowKm: 500,
);

void main() {
  group('households', () {
    test('a row maps onto the entity', () {
      expect(householdFromRow(row()), _household);
    });

    test('the settings row carries only what settings may change', () {
      expect(householdSettingsToRow(_household).keys, {
        'name',
        'currency_code',
        'distance_unit',
        'volume_unit',
        'bundling_window_days',
        'bundling_window_km',
        'tracking_level',
        'country_code',
        'settlement_enabled',
        'company_name',
        'company_oib',
        'company_address',
      });
    });

    test('the settings row never rewrites the id', () {
      expect(householdSettingsToRow(_household).containsKey('id'), isFalse);
    });

    test('a settings row survives the round trip unchanged', () {
      final reread = householdFromRow({
        ...householdSettingsToRow(_household),
        'id': 'h1',
      });

      expect(reread, _household);
    });

    test('the plan is read and never written', () {
      final household = householdFromRow({
        ...row(),
        'plan': 'company',
        'plan_until': '2027-01-01T00:00:00+00:00',
        'company_name': 'Prijevoz d.o.o.',
        'company_oib': '12345678901',
      });

      expect(household.isOnCompanyPlan, isTrue);
      expect(household.companyEnabledAt(DateTime.utc(2026, 9, 19)), isTrue);
      expect(household.companyEnabledAt(DateTime.utc(2027, 1, 2)), isFalse);
      expect(household.companyName, 'Prijevoz d.o.o.');
      expect(householdSettingsToRow(household).containsKey('plan'), isFalse);
      expect(
        householdSettingsToRow(household).containsKey('plan_until'),
        isFalse,
      );
    });

    test('the plan end is read as an instant in UTC', () {
      // A timestamptz column comes back with an offset; the entity compares
      // instants, so the flag has to be UTC for equality to hold.
      final household = householdFromRow({
        ...row(),
        'plan': 'company',
        'plan_until': '2027-01-01T01:00:00+01:00',
      });

      expect(household.planUntil, DateTime.utc(2027, 1, 1));
      expect(household.planUntil!.isUtc, isTrue);
    });

    test('a row from before the plan existed is a free garage', () {
      expect(householdFromRow(row()).isOnCompanyPlan, isFalse);
      expect(householdFromRow(row()).planUntil, isNull);
    });

    test('an emptied letterhead field reaches the database as null', () {
      final household = householdFromRow({
        ...row(),
        'company_oib': '12345678901',
      }).copyWith(companyOib: null);

      expect(householdSettingsToRow(household)['company_oib'], isNull);
    });
  });

  // A driver reads the garage and holds no update policy on it (migration
  // 0080), so their change of a unit preference is filtered to zero rows and
  // answered without an error. The repository reads the id back and treats
  // none as the refusal it is.
  group('a settings write the policy filtered', () {
    SupabaseHouseholdRepository repositoryOver(FakeSupabaseServer server) =>
        SupabaseHouseholdRepository(
          server.client,
          cache: ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
        );

    test('a change reads back the row it changed', () async {
      final server = FakeSupabaseServer(
        (request) => (
          200,
          const [
            {'id': 'h1'},
          ],
        ),
      );

      await repositoryOver(server).updateSettings(_household);

      final sent = server.requests.single;
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/rest/v1/households');
      expect(sent.url.queryParameters['id'], 'eq.h1');
      expect(sent.url.queryParameters['select'], 'id');
    });

    test('a change that touched no row is the permission failure', () async {
      final server = FakeSupabaseServer((request) => (200, const []));

      await expectLater(
        repositoryOver(server).updateSettings(_household),
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

  group('tracking level', () {
    test('reads the level the household chose', () {
      final household = householdFromRow({
        ...row(),
        'tracking_level': 'advanced',
      });

      expect(household.trackingLevel, 'advanced');
    });

    test('a household saved before the setting existed reads as beginner', () {
      final withoutColumn = Map<String, dynamic>.from(row())
        ..remove('tracking_level');

      expect(householdFromRow(withoutColumn).trackingLevel, 'beginner');
    });
  });

  group('members', () {
    test('the joined profile supplies the display name', () {
      final member = householdMemberFromRow({
        'user_id': 'u1',
        'role': 'admin',
        'profiles': {'display_name': 'Karlo'},
      });

      expect(member.userId, 'u1');
      expect(member.role, 'admin');
      expect(member.displayName, 'Karlo');
    });

    test(
      'carries when they joined, which is what the succession rule ranks by',
      () {
        final member = householdMemberFromRow({
          'user_id': 'u1',
          'role': 'admin',
          'joined_at': '2026-01-05T10:00:00+00:00',
          'profiles': {'display_name': 'Karlo'},
        });

        expect(member.joinedAt, DateTime.utc(2026, 1, 5, 10));
      },
    );

    test('a member whose profile row is missing reads as unnamed', () {
      final member = householdMemberFromRow({
        'user_id': 'u2',
        'role': 'member',
        'profiles': null,
      });

      expect(member.displayName, '');
    });

    test('a profile without a name reads as unnamed rather than throwing', () {
      final member = householdMemberFromRow({
        'user_id': 'u3',
        'role': 'member',
        'profiles': <String, dynamic>{'display_name': null},
      });

      expect(member.displayName, '');
    });
  });

  group('invite rows', () {
    test('a row becomes an invite with its dates', () {
      final invite = inviteFromRow({
        'id': 'i1',
        'code': 'ABCD2345',
        'created_at': '2026-08-01T10:00:00Z',
        'expires_at': '2026-08-15T10:00:00Z',
        'redeemed_at': null,
      });

      expect(invite.id, 'i1');
      expect(invite.code, 'ABCD2345');
      expect(invite.createdAt, DateTime.utc(2026, 8, 1, 10));
      expect(invite.expiresAt, DateTime.utc(2026, 8, 15, 10));
      expect(invite.redeemedAt, isNull);
    });

    test('a redeemed row carries when it was used', () {
      final invite = inviteFromRow({
        'id': 'i1',
        'code': 'ABCD2345',
        'created_at': '2026-08-01T10:00:00Z',
        'expires_at': '2026-08-15T10:00:00Z',
        'redeemed_at': '2026-08-03T09:30:00Z',
      });

      expect(invite.redeemedAt, DateTime.utc(2026, 8, 3, 9, 30));
    });
  });
}
