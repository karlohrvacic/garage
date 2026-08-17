import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/features/household/providers/current_household.dart';

Household garage(String id) => Household(id: id, name: id);

void main() {
  group('choosing which garage to show', () {
    test('shows the one this device last picked', () {
      final chosen = chooseHousehold([garage('a'), garage('b')], 'b');

      expect(chosen?.id, 'b');
    });

    test('shows the first when nothing has been picked', () {
      final chosen = chooseHousehold([garage('a'), garage('b')], null);

      expect(chosen?.id, 'a');
    });

    test('falls back when the pick is no longer one of them', () {
      // What leaving a garage, or being removed from one, looks like from
      // here. Showing nothing would send the user back through onboarding as
      // though they had no garage at all.
      final chosen = chooseHousehold([garage('a')], 'gone');

      expect(chosen?.id, 'a');
    });

    test('shows nothing when the user is in no garage', () {
      expect(chooseHousehold(const [], 'b'), isNull);
    });
  });
}
