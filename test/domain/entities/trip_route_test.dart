import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_route.dart';

TripRoute route(String name) =>
    TripRoute(id: name, householdId: 'h1', name: name);

void main() {
  group('finding the route somebody meant', () {
    final existing = [route('Home → Work'), route('Škola')];

    test('an exact name is the same route', () {
      expect(TripRoute.matching('Home → Work', existing)?.id, 'Home → Work');
    });

    test('a different case is the same route, as the database has it', () {
      // The unique index is on `lower(name)`. If this disagreed with it, a
      // second "home → work" would be offered to the user and then refused.
      expect(TripRoute.matching('home → WORK', existing)?.id, 'Home → Work');
    });

    test('surrounding space is not a new route', () {
      expect(TripRoute.matching('  Home → Work ', existing)?.id, 'Home → Work');
    });

    test('a diacritic is part of the name, not noise', () {
      // "Skola" and "Škola" are different words. Folding them together would
      // merge two commutes that a Croatian speaker typed deliberately.
      expect(TripRoute.matching('Skola', existing), isNull);
    });

    test('a name nobody has used yet matches nothing', () {
      expect(TripRoute.matching('To the coast', existing), isNull);
    });

    test('an empty name matches nothing rather than the first route', () {
      expect(TripRoute.matching('   ', existing), isNull);
    });
  });

  test('routes sort by name, so a picker is in a predictable order', () {
    final routes = [route('Work'), route('Airport'), route('School')]
      ..sort(TripRoute.byName);

    expect([for (final r in routes) r.name], ['Airport', 'School', 'Work']);
  });
}
