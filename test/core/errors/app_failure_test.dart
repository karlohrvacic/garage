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
      const PostgrestException(message: 'invite code has expired', code: 'P0003'),
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

  test('an AppFailure passes through unchanged', () {
    const original = AppFailure(kind: AppFailureKind.notFound);

    expect(AppFailure.from(original), same(original));
  });
}
