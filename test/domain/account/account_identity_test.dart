import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/account/account_identity.dart';

void main() {
  group('the name shown for an account', () {
    test('is the display name the sign-up form set', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {'display_name': 'Karlo'},
      );

      expect(identity.name, 'Karlo');
    });

    test('falls back to the full name Google supplies', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {'full_name': 'Karlo Hrvačić'},
      );

      expect(identity.name, 'Karlo Hrvačić');
    });

    test('then to the plain name some providers send', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {'name': 'Karlo H'},
      );

      expect(identity.name, 'Karlo H');
    });

    test('and last to the part of the address before the @', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {},
      );

      expect(identity.name, 'karlo');
    });

    test('ignores a blank display name rather than showing nothing', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {'display_name': '   ', 'full_name': 'Karlo Hrvačić'},
      );

      expect(identity.name, 'Karlo Hrvačić');
    });

    test('is trimmed, because a stray space is not part of a name', () {
      final identity = AccountIdentity.of(
        email: 'k@example.com',
        metadata: const {'display_name': ' Karlo '},
      );

      expect(identity.name, 'Karlo');
    });

    // The database picks the profile name with exactly this precedence
    // (migration 0011). Showing a different one would name the same person two
    // ways in the same app.
    test('follows the same order the database used for the profile', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {
          'display_name': 'From form',
          'full_name': 'From Google',
          'name': 'From somewhere else',
        },
      );

      expect(identity.name, 'From form');
    });
  });

  group('the address shown for an account', () {
    test('is the one signed in with', () {
      final identity = AccountIdentity.of(
        email: 'karlo@example.com',
        metadata: const {},
      );

      expect(identity.email, 'karlo@example.com');
    });

    test('is empty when the account has none, rather than crashing', () {
      final identity = AccountIdentity.of(email: null, metadata: const {});

      expect(identity.email, isEmpty);
      expect(identity.name, isEmpty);
    });
  });
}
