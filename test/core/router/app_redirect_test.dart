import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/router/app_redirect.dart';
import 'package:garage/domain/entities/household.dart';

const _household = AsyncValue<Household?>.data(
  Household(id: 'h1', name: 'Test'),
);
const _noHousehold = AsyncValue<Household?>.data(null);
const _loading = AsyncValue<Household?>.loading();
final _failed = AsyncValue<Household?>.error('offline', StackTrace.empty);

void main() {
  group('the sign-in gate', () {
    test('sends a signed-out visitor to sign-in', () {
      expect(
        garageRedirect(
          location: '/vehicles',
          signedIn: false,
          household: _loading,
        ),
        '/sign-in',
      );
    });

    test('leaves a signed-out visitor on the auth screens', () {
      for (final location in ['/sign-in', '/sign-up']) {
        expect(
          garageRedirect(
            location: location,
            signedIn: false,
            household: _loading,
          ),
          isNull,
        );
      }
    });

    test('sends a signed-in user off the auth screens', () {
      expect(
        garageRedirect(
          location: '/sign-in',
          signedIn: true,
          household: _household,
        ),
        '/',
      );
    });
  });

  group('the household gate', () {
    test('holds still while the household is loading', () {
      expect(
        garageRedirect(
          location: '/vehicles',
          signedIn: true,
          household: _loading,
        ),
        isNull,
      );
    });

    test('holds still when the household lookup failed', () {
      // An offline cold start must not read as "no household" and walk an
      // existing user into onboarding.
      expect(
        garageRedirect(
          location: '/vehicles',
          signedIn: true,
          household: _failed,
        ),
        isNull,
      );
    });

    test('sends a user with no household to onboarding', () {
      expect(
        garageRedirect(
          location: '/vehicles',
          signedIn: true,
          household: _noHousehold,
        ),
        '/onboarding',
      );
    });

    test('leaves a user with no household on onboarding', () {
      expect(
        garageRedirect(
          location: '/onboarding',
          signedIn: true,
          household: _noHousehold,
        ),
        isNull,
      );
    });

    test('sends a user who has a household off onboarding', () {
      expect(
        garageRedirect(
          location: '/onboarding',
          signedIn: true,
          household: _household,
        ),
        '/',
      );
    });

    test('leaves a fully set-up user where they asked to go', () {
      expect(
        garageRedirect(
          location: '/vehicles/v1/fuel',
          signedIn: true,
          household: _household,
        ),
        isNull,
      );
    });
  });

  // An invite link is opened by someone who, by definition, has no household
  // yet and often no account. Both gates would bounce them: to sign-in, which
  // loses the code, and then to onboarding, which asks them to type it. The
  // join screen is the one place that can explain and finish the job, so it
  // sits outside both gates and handles every case itself.
  group('an invite link', () {
    test('opens for a signed-out visitor instead of bouncing to sign-in', () {
      expect(
        garageRedirect(
          location: '/join/ABC12345',
          signedIn: false,
          household: _loading,
        ),
        isNull,
      );
    });

    test('opens for a signed-in user who has no household yet', () {
      expect(
        garageRedirect(
          location: '/join/ABC12345',
          signedIn: true,
          household: _noHousehold,
        ),
        isNull,
      );
    });

    test('opens for a member too, so it can say they already have one', () {
      expect(
        garageRedirect(
          location: '/join/ABC12345',
          signedIn: true,
          household: _household,
        ),
        isNull,
      );
    });

    // Signing in navigates to "/", which would strand the invite. Carrying the
    // code back is what makes the link a link rather than a code to retype.
    test('is returned to once the visitor signs in', () {
      expect(
        garageRedirect(
          location: '/',
          signedIn: true,
          household: _noHousehold,
          pendingInvite: 'ABC12345',
        ),
        '/join/ABC12345',
      );
    });

    test('does not redirect onto itself once it is showing', () {
      expect(
        garageRedirect(
          location: '/join/ABC12345',
          signedIn: true,
          household: _noHousehold,
          pendingInvite: 'ABC12345',
        ),
        isNull,
      );
    });

    test('is not carried anywhere while still signed out', () {
      expect(
        garageRedirect(
          location: '/vehicles',
          signedIn: false,
          household: _loading,
          pendingInvite: 'ABC12345',
        ),
        '/sign-in',
      );
    });
  });
}
