import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('a socket-level error maps to a network failure', () {
    final failure = AppFailure.from(
      const SocketException('Failed host lookup'),
    );

    expect(failure.kind, AppFailureKind.network);
  });

  test('an auth exception maps to an auth failure', () {
    final failure = AppFailure.from(
      const AuthException('Invalid login credentials'),
    );

    expect(failure.kind, AppFailureKind.auth);
  });

  test('an RLS violation maps to a permission failure', () {
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      ),
    );

    expect(failure.kind, AppFailureKind.permission);
  });

  test('a check-constraint violation maps to an invalid failure', () {
    // A VIN outside 11–17 characters used to land here as "something went
    // wrong", which told the person nothing about what to change.
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'new row violates check constraint "vehicles_vin_check"',
        code: '23514',
      ),
    );

    expect(failure.kind, AppFailureKind.invalid);
  });

  test('a unique violation maps to a conflict failure', () {
    final failure = AppFailure.from(
      const PostgrestException(message: 'duplicate key', code: '23505'),
    );

    expect(failure.kind, AppFailureKind.conflict);
  });

  test('an expired invite code maps to an expired failure', () {
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'invite code has expired',
        code: 'P0003',
      ),
    );

    expect(failure.kind, AppFailureKind.expired);
  });

  test('an already-used invite code maps to an alreadyUsed failure', () {
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'invite code has already been used',
        code: 'P0004',
      ),
    );

    expect(failure.kind, AppFailureKind.alreadyUsed);
  });

  test('an invalid invite code maps to a notFound failure', () {
    final failure = AppFailure.from(
      const PostgrestException(message: 'invalid invite code', code: 'P0002'),
    );

    expect(failure.kind, AppFailureKind.notFound);
  });

  test('a second handover on one day maps to a handoverClash failure', () {
    // hand_over_vehicle (migration 0080) refuses a day a window already
    // covers; the console names the clash rather than "something went
    // wrong", because the fix is to remove the wrong row and try again.
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'the car was already handed over on that date',
        code: 'P0006',
      ),
    );

    expect(failure.kind, AppFailureKind.handoverClash);
  });

  test('a garage at its free limit maps to a planLimit failure', () {
    // Raised by the unarchive guard, a transfer redeemed into a full garage
    // and a merge that would overflow one (migration 0080).
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'the garage has reached its free limit',
        code: 'P0008',
      ),
    );

    expect(failure.kind, AppFailureKind.planLimit);
  });

  test('the last admin leaving a garage of drivers maps to its own kind', () {
    // promote_after_member_left (migration 0080) refuses the leave rather
    // than leave the garage without anybody who can run it; the sentence
    // has to say to make somebody an admin first, not "something went
    // wrong".
    final failure = AppFailure.from(
      const PostgrestException(
        message: 'a garage of drivers needs an admin',
        code: 'P0007',
      ),
    );

    expect(failure.kind, AppFailureKind.driversNeedAdmin);
  });

  group('a file storage refuses', () {
    // Storage answers 400 and puts the real status in the body, which the
    // client copies to `statusCode`. A type or a size the bucket refuses is
    // refused on every attempt, so a queued photo must not be retried.
    test('for its type is invalid', () {
      final failure = AppFailure.from(
        const StorageException(
          'mime type text/plain is not supported',
          error: 'invalid_mime_type',
          statusCode: '415',
        ),
      );

      expect(failure.kind, AppFailureKind.invalid);
      expect(failure.debugMessage, contains('text/plain'));
    });

    test('for its size is invalid', () {
      final failure = AppFailure.from(
        const StorageException(
          'The object exceeded the maximum allowed size',
          error: 'Payload too large',
          statusCode: '413',
        ),
      );

      expect(failure.kind, AppFailureKind.invalid);
    });

    test('for anything else is not decided here', () {
      // A 403 can be an expired token as well as a policy, and a queued
      // photo thrown away for a token the app was about to refresh is lost.
      for (final status in ['403', '404', '500']) {
        expect(
          AppFailure.from(StorageException('no', statusCode: status)).kind,
          AppFailureKind.unknown,
          reason: status,
        );
      }
    });
  });

  test('an unrecognised error maps to unknown but keeps the detail', () {
    final failure = AppFailure.from(StateError('something odd'));

    expect(failure.kind, AppFailureKind.unknown);
    expect(failure.debugMessage, contains('something odd'));
  });

  test('an unconfirmed email is not a wrong password', () {
    // Supabase refuses the sign-in with an AuthApiException like any other,
    // and everything AuthException collapsed to "Sign-in failed. Check your
    // email and password." — which is false and unhelpable: the credentials
    // are right, and no amount of retyping them will work.
    final failure = AppFailure.from(
      const AuthApiException(
        'Email not confirmed',
        code: 'email_not_confirmed',
      ),
    );

    expect(failure.kind, AppFailureKind.emailNotConfirmed);
  });

  test(
    'an unconfirmed email is recognised by message when there is no code',
    () {
      // Older projects answer without a `code`, so the message is the only
      // signal. Matched loosely on purpose: getting this wrong sends someone
      // back to retype a password that was never the problem.
      final failure = AppFailure.from(
        const AuthApiException('Email not confirmed'),
      );

      expect(failure.kind, AppFailureKind.emailNotConfirmed);
    },
  );

  test('a genuinely wrong password still maps to auth', () {
    final failure = AppFailure.from(
      const AuthApiException('Invalid login credentials'),
    );

    expect(failure.kind, AppFailureKind.auth);
  });

  test('an AppFailure passes through unchanged', () {
    const original = AppFailure(kind: AppFailureKind.notFound);

    expect(AppFailure.from(original), same(original));
  });
}
