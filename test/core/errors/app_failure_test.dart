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
