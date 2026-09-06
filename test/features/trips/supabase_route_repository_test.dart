import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/trips/data/supabase_route_repository.dart';

Map<String, dynamic> row({Object? by = 'u1'}) {
  return {
    'id': 'r1',
    'household_id': 'h1',
    'name': 'Home → Work',
    'created_by': ?by,
    'created_at': '2026-09-01T07:10:00Z',
  };
}

void main() {
  test('reading a row maps every column onto the entity', () {
    final route = routeFromRow(row());

    expect(route.id, 'r1');
    expect(route.householdId, 'h1');
    expect(route.name, 'Home → Work');
    expect(route.createdBy, 'u1');
    expect(route.createdAt, DateTime.utc(2026, 9, 1, 7, 10));
  });

  test('a route whose author has since been deleted still reads', () {
    // 0061 keeps the row and nulls the author, the same way 0059 does for a
    // guest pass. A crash here would take the whole picker with it.
    expect(routeFromRow(row(by: null)).createdBy, '');
  });
}
