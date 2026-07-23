import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  final List<String> calls = [];
  Object? throwOnSignIn;

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({required String email, required String password}) async {
    calls.add('signIn:$email');
    if (throwOnSignIn != null) {
      throw throwOnSignIn!;
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    calls.add('signUp:$email:$displayName');
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('reset:$email');

  @override
  Future<void> updatePassword(String newPassword) async =>
      calls.add('updatePassword');

  @override
  Future<void> deleteAccount() async => calls.add('deleteAccount');
}

ProviderContainer containerWith(FakeAuthRepository fake) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('signing in delegates to the repository', () async {
    final fake = FakeAuthRepository();
    final container = containerWith(fake);

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@example.com', password: 'password123');

    expect(fake.calls, ['signIn:a@example.com']);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('a failed sign-in surfaces a mapped AppFailure, not a raw exception',
      () async {
    final fake = FakeAuthRepository()
      ..throwOnSignIn = const AuthException('Invalid login credentials');
    final container = containerWith(fake);

    await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@example.com', password: 'wrong');

    final state = container.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<AppFailure>());
    expect((state.error! as AppFailure).kind, AppFailureKind.auth);
  });

  test('signing up passes the display name through', () async {
    final fake = FakeAuthRepository();
    final container = containerWith(fake);

    await container.read(authControllerProvider.notifier).signUp(
          email: 'b@example.com',
          password: 'password123',
          displayName: 'Karlo',
        );

    expect(fake.calls, ['signUp:b@example.com:Karlo']);
  });
}
