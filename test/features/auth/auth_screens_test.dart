import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/auth/email_link.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/auth/screens/sign_in_screen.dart';
import 'package:garage/features/auth/screens/sign_up_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../support/pump_screen.dart';

class RecordingAuthRepository implements AuthRepository {
  RecordingAuthRepository({
    this.fails = false,
    this.needsEmailConfirmation = false,
  });

  final bool fails;

  /// Whether the project requires a confirmed address, as Supabase reports it
  /// by handing back no session.
  final bool needsEmailConfirmation;
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
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _record('signUp:$email:$displayName');
    return needsEmailConfirmation;
  }

  @override
  Future<void> signInWithGoogle() async => _record('google');

  @override
  Future<void> signOut() async => _record('signOut');

  @override
  Future<void> confirmEmailLink(EmailLink link) async =>
      calls.add('confirmEmailLink:${link.purpose.name}');

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

/// Every input on screen sits in one autofill group and declares what it is.
///
/// Both halves matter: a hint without a group is not offered for saving, and a
/// group with an unhinted field is filled only in part.
void expectFullyHinted(WidgetTester tester) {
  expect(find.byType(AutofillGroup), findsOneWidget, reason: 'no group');

  final fields = tester.widgetList<EditableText>(find.byType(EditableText));
  expect(fields, isNotEmpty);
  for (final field in fields) {
    expect(
      field.autofillHints ?? const <String>[],
      isNotEmpty,
      reason: 'a field in the group declares nothing about itself',
    );
  }
}

void main() {
  // Proton Pass could fill neither form: sign-up had no AutofillGroup and no
  // hints at all, sign-in had the hints but no group. A credential form a
  // password manager cannot use pushes people toward a password they can type
  // from memory, which is the opposite of what it should do.
  group('password managers', () {
    testWidgets('the sign-in form is one autofill group, every field hinted', (
      tester,
    ) async {
      await pumpSignIn(tester, RecordingAuthRepository());
      await tester.pumpAndSettle();

      expectFullyHinted(tester);
    });

    testWidgets('and so is the sign-up form', (tester) async {
      await pumpSignUp(tester, RecordingAuthRepository());
      await tester.pumpAndSettle();

      expectFullyHinted(tester);
    });

    testWidgets('sign-up asks for a new password, not an existing one', (
      tester,
    ) async {
      await pumpSignUp(tester, RecordingAuthRepository());
      await tester.pumpAndSettle();

      final hints = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .expand((field) => field.autofillHints ?? const <String>[]);

      // This is the hint that makes a manager offer to *generate* one here
      // rather than suggest a credential that does not exist yet.
      expect(hints, contains(AutofillHints.newPassword));
    });
  });

  group('arriving from an email link', () {
    testWidgets('a link that failed says so instead of showing a bare form', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SignInScreen(),
        initialLocation: '/sign-in',
        surface: const Size(420, 900),
        overrides: [
          authRepositoryProvider.overrideWithValue(RecordingAuthRepository()),
          launchUrlProvider.overrideWithValue(
            Uri.parse(
              'https://garage.hrva.cc/#error=access_denied'
              '&error_description=Email+link+is+invalid+or+has+expired',
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('That link has expired'), findsOneWidget);
    });

    testWidgets('a normal visit says nothing about links', (tester) async {
      await pumpSignIn(tester, RecordingAuthRepository());
      await tester.pumpAndSettle();

      expect(find.textContaining('That link has expired'), findsNothing);
    });

    testWidgets('the raw backend wording never reaches the screen', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const SignInScreen(),
        initialLocation: '/sign-in',
        surface: const Size(420, 900),
        overrides: [
          authRepositoryProvider.overrideWithValue(RecordingAuthRepository()),
          launchUrlProvider.overrideWithValue(
            Uri.parse(
              'https://garage.hrva.cc/#error_description=Email+link+is+invalid',
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Email link is invalid'),
        findsNothing,
        reason: 'it goes to the failure log, not to the user',
      );
    });
  });

  testWidgets('a visitor can find out what the app is before signing up', (
    tester,
  ) async {
    // The web app redirects an unauthenticated visitor straight here, so
    // without this the entire public face of Garage is a password box.
    final opened = <Uri>[];
    await pumpScreen(
      tester,
      const SignInScreen(),
      initialLocation: '/sign-in',
      surface: const Size(420, 900),
      overrides: [
        authRepositoryProvider.overrideWithValue(RecordingAuthRepository()),
        urlOpenerProvider.overrideWithValue((url) async => opened.add(url)),
      ],
    );
    await tester.pumpAndSettle();

    final link = find.byKey(const Key('what-garage-does'));
    await tester.ensureVisible(link);
    await tester.pumpAndSettle();
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(opened, [GarageLinks.features]);
  });

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
    // A sign-up that needs a confirmed address succeeds and hands back no
    // session, so nothing on screen changed: the form sat there looking as
    // though the button had done nothing, and the confirmation email went
    // unmentioned and often unopened.
    testWidgets('says to check your email when confirmation is required', (
      tester,
    ) async {
      final auth = RecordingAuthRepository(needsEmailConfirmation: true);
      await pumpSignUp(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'Karlo');
      await fillField(tester, 1, 'karlo@example.com');
      await fillField(tester, 2, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.textContaining('karlo@example.com'),
        findsOneWidget,
        reason: 'which address it went to is the useful half',
      );
      expect(
        find.widgetWithText(FilledButton, 'Create account'),
        findsNothing,
        reason: 'the form is done with; offering it again invites a duplicate',
      );
    });

    testWidgets('a project without confirmation just signs you in', (
      tester,
    ) async {
      final auth = RecordingAuthRepository();
      await pumpSignUp(tester, auth);
      await tester.pumpAndSettle();

      await fillField(tester, 0, 'Karlo');
      await fillField(tester, 1, 'karlo@example.com');
      await fillField(tester, 2, 'hunter2hunter2');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsNothing);
    });

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
