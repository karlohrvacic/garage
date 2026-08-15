import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/data/supabase_household_repository.dart';

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
}
