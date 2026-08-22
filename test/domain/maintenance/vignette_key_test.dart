import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';

void main() {
  group('VignetteValidity keys', () {
    test('every value has a stable, storable key', () {
      expect(VignetteValidity.day1.key, 'day1');
      expect(VignetteValidity.days7.key, 'days7');
      expect(VignetteValidity.days10.key, 'days10');
      expect(VignetteValidity.days30.key, 'days30');
      expect(VignetteValidity.days60.key, 'days60');
      expect(VignetteValidity.months2.key, 'months2');
      expect(VignetteValidity.year.key, 'year');
    });

    test('fromKey round-trips every value', () {
      for (final validity in VignetteValidity.values) {
        expect(VignetteValidity.fromKey(validity.key), validity);
      }
    });

    test('an unrecognised key is null, not a guess', () {
      expect(VignetteValidity.fromKey('nonsense'), isNull);
    });
  });

  group('VignetteCountry codes', () {
    test('fromCode round-trips every value', () {
      for (final country in VignetteCountry.values) {
        expect(VignetteCountry.fromCode(country.code), country);
      }
    });

    test('an unrecognised code is null, not a guess', () {
      expect(VignetteCountry.fromCode('ZZ'), isNull);
    });

    test('is read case-insensitively, since it round-trips through SQL', () {
      expect(VignetteCountry.fromCode('si'), VignetteCountry.slovenia);
    });
  });
}
