import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/auth/screens/sign_in_screen.dart';
import 'package:garage/features/auth/screens/sign_up_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../support/pump_screen.dart';

class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({this.fails = false});

  final bool fails;
  final List<String> calls = [];

  void _record(String call) {
    calls.add(call);
    if (fails) {
      throw Exception('nope');
    }
  }

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => _record('signIn:$email:$password');

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => _record('signUp:$email:$displayName');

  @override
  Future<void> signInWithGoogle() async => _record('google');

  @override
  Future<void> signOut() async => _record('signOut');

  @override
  Future<void> sendPasswordReset(String email) async => _record('reset:$email');

  @override
  Future<void> updatePassword(String newPassword) async =>
      _record('updatePassword');

  @override
  Future<void> deleteAccount() async => _record('deleteAccount');
}

Future<NavigationLog> pumpSignIn(
  WidgetTester tester,
  RecordingAuthRepository auth,
) {
  return pumpScreen(
    tester,
    const SignInScreen(),
    initialLocation: '/sign-in',
    surface: const Size(420, 900),
    extraRoutes: const {'/sign-up'},
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
}

Future<NavigationLog> pumpSignUp(
  WidgetTester tester,
  RecordingAuthRepository auth,
) {
  return pumpScreen(
    tester,
    const SignUpScreen(),
    initialLocation: '/sign-up',
    surface: const Size(420, 900),
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
}

Future<void> fillField(WidgetTester tester, int index, String value) async {
  await tester.enterText(find.byType(TextFormField).at(index), value);
}

void main() {
  group('signing in', () {
    testWidgets('valid credentials reach the repository', (tester) async {
      final auth = RecordingAuthRepository();
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'karlo@example.com');
      await fillField(tester, 1, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signIn:karlo@example.com:hunter2hunter2']);
    });

    testWidgets('an address without an @ is refused before any call', (
      tester,
    ) async {
      final auth = RecordingAuthRepository();
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'not-an-address');
      await fillField(tester, 1, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.calls, isEmpty);
      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('a short password is refused before any call', (tester) async {
      final auth = RecordingAuthRepository();
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'karlo@example.com');
      await fillField(tester, 1, 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.calls, isEmpty);
      expect(find.textContaining('at least 8'), findsOneWidget);
    });

    testWidgets('a rejected sign-in is reported, not swallowed', (
      tester,
    ) async {
      final auth = RecordingAuthRepository(fails: true);
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'karlo@example.com');
      await fillField(tester, 1, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });

    testWidgets('a password reset needs an address first', (tester) async {
      final auth = RecordingAuthRepository();
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(auth.calls, isEmpty);
      expect(find.text('Enter a valid email address'), findsWidgets);
    });

    testWidgets('a password reset with an address is sent', (tester) async {
      final auth = RecordingAuthRepository();
      await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'karlo@example.com');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['reset:karlo@example.com']);
      expect(find.textContaining('reset link'), findsOneWidget);
    });

    testWidgets('signing up is one tap away', (tester) async {
      final auth = RecordingAuthRepository();
      final log = await pumpSignIn(tester, auth);
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Create one'));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/sign-up'));
    });
  });

  group('signing up', () {
    testWidgets('a complete form reaches the repository', (tester) async {
      final auth = RecordingAuthRepository();
      await pumpSignUp(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'Karlo');
      await fillField(tester, 1, 'karlo@example.com');
      await fillField(tester, 2, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(auth.calls, ['signUp:karlo@example.com:Karlo']);
    });

    testWidgets('a missing name is refused before any call', (tester) async {
      final auth = RecordingAuthRepository();
      await pumpSignUp(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 1, 'karlo@example.com');
      await fillField(tester, 2, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(auth.calls, isEmpty);
      expect(find.text('Enter your name'), findsOneWidget);
    });
  });
}
