import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_screens_test.dart'
    show RecordingAuthRepository, pumpSignIn, pumpSignUp;

/// An auth call that does not finish until the test says so, which is the only
/// way to be *between* the await and what follows it when the screen goes.
class GatedAuthRepository extends RecordingAuthRepository {
  final gate = Completer<void>();

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn');
    await gate.future;
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    calls.add('signUp');
    await gate.future;
    return false;
  }
}

/// Sends the router somewhere else, which is what the redirect does the moment
/// a session appears — the auth screen is torn down with its own call still in
/// flight.
Future<void> navigateAway(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
  await tester.pumpAndSettle();
  expect(find.byType(TextFormField), findsNothing);
}

void main() {
  // Three reports of `Bad state: Using "ref" when a widget is about to or has
  // been unmounted is unsafe` came back from the field with no screen named.
  // This is the shape they had: a successful sign-in is *precisely* the case
  // where the router replaces the screen, so the read after the await lands on
  // an element that is already gone.
  group('an auth screen the router replaces mid-call', () {
    testWidgets('sign-in finishing after the screen is gone does not throw', (
      tester,
    ) async {
      final auth = GatedAuthRepository();
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'hunter22');
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump();
      expect(auth.calls, contains('signIn'));

      await navigateAway(tester);
      auth.gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('sign-up finishing after the screen is gone does not throw', (
      tester,
    ) async {
      final auth = GatedAuthRepository();
      await pumpSignUp(tester, auth);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Karlo');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'hunter22');
      await tester.tap(find.byType(FilledButton).first);
      await tester.pump();
      expect(auth.calls, contains('signUp'));

      await navigateAway(tester);
      auth.gate.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
