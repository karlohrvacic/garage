import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/core/notifications/push_registration.dart';
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

  test(
    'a failed sign-in surfaces a mapped AppFailure, not a raw exception',
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
    },
  );

  test('signing up passes the display name through', () async {
    final fake = FakeAuthRepository();
    final container = containerWith(fake);

    await container
        .read(authControllerProvider.notifier)
        .signUp(
          email: 'b@example.com',
          password: 'password123',
          displayName: 'Karlo',
        );

    expect(fake.calls, ['signUp:b@example.com:Karlo']);
  });

  // Reminders are delivered to devices, so the set of devices has to follow the
  // account. Registering on the way in is what makes a second household member
  // hear about anything at all; withdrawing on the way out is what stops a
  // shared phone receiving the previous account's reminders.
  group('push registration follows the session', () {
    test('signing in registers this device', () async {
      final push = RecordingPushRegistration();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pushRegistrationProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.c', password: 'password123');

      expect(push.calls, ['register']);
    });

    test('signing up registers it too', () async {
      final push = RecordingPushRegistration();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pushRegistrationProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signUp(email: 'a@b.c', password: 'password123', displayName: 'A');

      expect(push.calls, ['register']);
    });

    test('signing out withdraws it before the session goes', () async {
      final push = RecordingPushRegistration();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pushRegistrationProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(push.calls, ['withdraw']);
    });

    // A sign-in that worked is a sign-in that worked. Push is a convenience on
    // top, and a device that cannot register for it must not be told its
    // password was wrong.
    test('a failure to register does not fail the sign-in', () async {
      final push = ThrowingPushRegistration();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pushRegistrationProvider.overrideWithValue(push),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'a@b.c', password: 'password123');

      expect(container.read(authControllerProvider).hasError, isFalse);
    });
  });
}

class RecordingPushRegistration implements PushRegistration {
  final List<String> calls = [];

  @override
  Future<void> register() async => calls.add('register');

  @override
  Future<void> withdraw() async => calls.add('withdraw');
}

class ThrowingPushRegistration implements PushRegistration {
  @override
  Future<void> register() async => throw Exception('no firebase');

  @override
  Future<void> withdraw() async => throw Exception('no firebase');
}
