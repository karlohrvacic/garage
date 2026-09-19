import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/household/admin_succession.dart';
import 'package:garage/features/household/data/household_repository.dart';

HouseholdMember member(
  String id, {
  String role = 'member',
  int? joinedYear = 2025,
}) {
  return HouseholdMember(
    userId: id,
    displayName: id,
    role: role,
    joinedAt: joinedYear == null ? null : DateTime.utc(joinedYear),
  );
}

void main() {
  // The database decides this after the fact (`ensure_household_has_admin`,
  // migration 0058); the app mirrors the rule so it can say the name before
  // somebody steps down. The two have to agree, so the cases here are the
  // ones the migration's own comments name.
  group('who inherits the garage', () {
    test('is the longest-standing other member', () {
      final heir = successorOf([
        member('u1', role: 'admin', joinedYear: 2023),
        member('u2', joinedYear: 2025),
        member('u3', joinedYear: 2024),
      ], steppingDown: 'u1');

      expect(heir?.userId, 'u3');
    });

    test(
      'is never the one stepping down, however long they have been there',
      () {
        final heir = successorOf([
          member('u1', role: 'admin', joinedYear: 2020),
          member('u2', joinedYear: 2026),
        ], steppingDown: 'u1');

        expect(heir?.userId, 'u2');
      },
    );

    test('is settled by user id when two joined at once', () {
      final heir = successorOf([
        member('u1', role: 'admin', joinedYear: 2023),
        member('u3', joinedYear: 2024),
        member('u2', joinedYear: 2024),
      ], steppingDown: 'u1');

      expect(heir?.userId, 'u2');
    });

    test('is nobody in a garage of one', () {
      expect(
        successorOf([member('u1', role: 'admin')], steppingDown: 'u1'),
        isNull,
      );
    });

    test('prefers a member it can date', () {
      final heir = successorOf([
        member('u1', role: 'admin', joinedYear: 2023),
        member('u2', joinedYear: null),
        member('u3', joinedYear: 2026),
      ], steppingDown: 'u1');

      expect(heir?.userId, 'u3');
    });
  });
}
