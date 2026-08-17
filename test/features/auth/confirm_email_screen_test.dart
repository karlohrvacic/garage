import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/auth/email_link.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:garage/features/auth/screens/confirm_email_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../support/pump_screen.dart';

class FakeAuth implements AuthRepository {
  FakeAuth({this.fails = false});

  final bool fails;
  final List<String> calls = [];

  @override
  Future<void> confirmEmailLink(EmailLink link) async {
    calls.add('confirm:${link.purpose.name}:${link.tokenHash}');
    if (fails) {
      throw Exception('token already used');
    }
  }

  @override
  User? get currentUser => null;
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => false;
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<void> deleteAccount() async {}
}

Future<NavigationLog> pumpConfirm(
  WidgetTester tester,
  FakeAuth auth, {
  EmailLink? link,
}) {
  return pumpScreen(
    tester,
    ConfirmEmailScreen(link: link),
    initialLocation: '/auth/confirm',
    surface: const Size(420, 900),
    extraRoutes: const {'/sign-in'},
    overrides: [authRepositoryProvider.overrideWithValue(auth)],
  );
}

void main() {
  const confirmation = EmailLink(
    purpose: EmailLinkPurpose.confirmSignUp,
    tokenHash: 'abc123',
  );

  testWidgets('the token in the link is spent', (tester) async {
    final auth = FakeAuth();
    await pumpConfirm(tester, auth, link: confirmation);
    await tester.pumpAndSettle();

    expect(auth.calls, ['confirm:confirmSignUp:abc123']);
  });

  testWidgets('a confirmed sign-up is sent into the app', (tester) async {
    final log = await pumpConfirm(tester, FakeAuth(), link: confirmation);
    await tester.pumpAndSettle();

    expect(log.visited, contains('/'));
  });

  testWidgets('a reset lands in the app too, where the prompt appears', (
    tester,
  ) async {
    // The recovery verify signs the user in and raises `passwordRecovery`,
    // which main.dart answers with a dialog on the root navigator. Waiting
    // here to host it would strand the user on this screen once they answered.
    final log = await pumpConfirm(
      tester,
      FakeAuth(),
      link: const EmailLink(
        purpose: EmailLinkPurpose.resetPassword,
        tokenHash: 'abc123',
      ),
    );
    await tester.pumpAndSettle();

    expect(log.visited, contains('/'));
  });

  testWidgets('a link that has been used says so, and offers a way on', (
    tester,
  ) async {
    // Confirmation links are single-use and expire; landing on a blank screen
    // was the reported symptom of exactly this.
    await pumpConfirm(tester, FakeAuth(fails: true), link: confirmation);
    await tester.pumpAndSettle();

    expect(find.text('That link did not work'), findsOneWidget);
    expect(find.byKey(const Key('confirm-to-sign-in')), findsOneWidget);
  });

  testWidgets('the route opened by hand spends nothing', (tester) async {
    final auth = FakeAuth();
    await pumpConfirm(tester, auth);
    await tester.pumpAndSettle();

    expect(auth.calls, isEmpty);
    expect(find.text('There is nothing to confirm here.'), findsOneWidget);
  });

  testWidgets('a rebuild does not spend the token twice', (tester) async {
    // A single-use hash spent a second time always fails, so a confirmation
    // that worked would report itself broken on the next frame.
    final auth = FakeAuth();
    await pumpConfirm(tester, auth, link: confirmation);
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(auth.calls, hasLength(1));
  });
}
