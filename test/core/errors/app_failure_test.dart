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
