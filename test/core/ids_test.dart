import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/ids.dart';

void main() {
  test('an entry id is a version-4 UUID, and never the same twice', () {
    final ids = {for (var i = 0; i < 200; i++) newEntryId()};
    expect(ids, hasLength(200));
    for (final id in ids) {
      expect(
        id,
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
    }
  });
}
