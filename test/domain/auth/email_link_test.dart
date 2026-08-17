import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/auth/email_link.dart';

void main() {
  group('what an emailed link asks for', () {
    test('a sign-up confirmation', () {
      final link = EmailLink.fromQuery(const {
        'token_hash': 'abc123',
        'type': 'email',
      });

      expect(link?.purpose, EmailLinkPurpose.confirmSignUp);
      expect(link?.tokenHash, 'abc123');
    });

    test('a password reset', () {
      final link = EmailLink.fromQuery(const {
        'token_hash': 'abc123',
        'type': 'recovery',
      });

      expect(link?.purpose, EmailLinkPurpose.resetPassword);
    });

    // Supabase's own confirmation template sends `signup` where the docs use
    // `email`, and both mean the same thing to `verifyOTP`. Accepting one and
    // not the other would make the flow depend on which page the template was
    // copied from.
    test('signup means the same as email', () {
      final link = EmailLink.fromQuery(const {
        'token_hash': 'abc123',
        'type': 'signup',
      });

      expect(link?.purpose, EmailLinkPurpose.confirmSignUp);
    });

    test('a type nobody sent is not guessed at', () {
      expect(
        EmailLink.fromQuery(const {'token_hash': 'abc', 'type': 'sms'}),
        isNull,
      );
    });

    test('a link with no token is nothing', () {
      expect(EmailLink.fromQuery(const {'type': 'email'}), isNull);
    });

    test('an empty token is nothing either', () {
      // A template variable that did not interpolate leaves the parameter
      // present and blank, which would otherwise reach the server as a
      // pointless round trip.
      expect(
        EmailLink.fromQuery(const {'token_hash': '', 'type': 'email'}),
        isNull,
      );
    });

    test('the landing page opened by hand is nothing', () {
      expect(EmailLink.fromQuery(const {}), isNull);
    });
  });
}
