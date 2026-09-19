import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/auth/email_link.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/features/auth/data/auth_repository.dart';
import 'package:garage/core/notifications/push_registration.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_providers.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/features/auth/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_repositories.dart';
import 'package:garage/features/household/providers/household_providers.dart';

class FakeAuthRepository implements AuthRepository {
  final List<String> calls = [];
  Object? throwOnSignIn;
  Object? throwOnDeleteAccount;

  /// Whether the project requires a confirmed address, as Supabase reports it
  /// by handing back no session.
  bool needsEmailConfirmation = false;

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
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    calls.add('signUp:$email:$displayName');
    return needsEmailConfirmation;
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<void> confirmEmailLink(EmailLink link) async =>
      calls.add('confirmEmailLink:${link.purpose.name}');

  @override
  Future<void> sendPasswordReset(String email) async =>
      calls.add('reset:$email');

  @override
  Future<void> updateDisplayName(String name) async =>
      calls.add('updateDisplayName:$name');

  @override
  Future<void> updatePassword(String newPassword) async =>
      calls.add('updatePassword');

  @override
  Future<void> deleteAccount() async {
    calls.add('deleteAccount');
    if (throwOnDeleteAccount != null) {
      throw throwOnDeleteAccount!;
    }
  }
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
          garageBootstrapCacheProvider.overrideWithValue(FakeBootstrapCache()),
          readCacheProvider.overrideWithValue(
            ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(push.calls, ['withdraw']);
    });

    test('signing out forgets the garage kept on the device', () async {
      // A shared phone must not open into the previous account's garage. The
      // provider would refuse to show it — the cache is keyed by user — but
      // refusing to show it is not the same as not having it.
      final cache = FakeBootstrapCache();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pushRegistrationProvider.overrideWithValue(
            RecordingPushRegistration(),
          ),
          garageBootstrapCacheProvider.overrideWithValue(cache),
          readCacheProvider.overrideWithValue(
            ReadCache(store: InMemoryReadCacheStore(), userId: () => 'u1'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(cache.cleared, 1);
    });

    test('signing out forgets the entries kept on the device too', () async {
      // Keyed by user, so the next account would never be shown them — and
      // still on the disk of a phone that account now holds.
      final store = InMemoryReadCacheStore();
      await store.write('u1/fuel/v1', '{"rows":[]}');
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          pushRegistrationProvider.overrideWithValue(
            RecordingPushRegistration(),
          ),
          garageBootstrapCacheProvider.overrideWithValue(FakeBootstrapCache()),
          readCacheProvider.overrideWithValue(
            ReadCache(store: store, userId: () => 'u1'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(store.keys, isEmpty);
    });

    test(
      'deleting the account forgets both copies kept on the device',
      () async {
        // The policy promises the copies go with the account, and a deletion
        // ends the session without the sign-out that would have cleared them.
        final bootstrap = FakeBootstrapCache();
        final store = InMemoryReadCacheStore();
        await store.write('u1/fuel/v1', '{"rows":[]}');
        final fake = FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fake),
            garageBootstrapCacheProvider.overrideWithValue(bootstrap),
            readCacheProvider.overrideWithValue(
              ReadCache(store: store, userId: () => 'u1'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.notifier).deleteAccount();

        expect(fake.calls, ['deleteAccount']);
        expect(bootstrap.cleared, 1);
        expect(store.keys, isEmpty);
      },
    );

    test('a deletion that fails keeps both copies with the account', () async {
      // No signal, or the function refused: the account still exists, and so
      // must the garage the next launch opens on.
      final bootstrap = FakeBootstrapCache();
      final store = InMemoryReadCacheStore();
      await store.write('u1/fuel/v1', '{"rows":[]}');
      final fake = FakeAuthRepository()
        ..throwOnDeleteAccount = Exception('no route to host');
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fake),
          garageBootstrapCacheProvider.overrideWithValue(bootstrap),
          readCacheProvider.overrideWithValue(
            ReadCache(store: store, userId: () => 'u1'),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).deleteAccount();

      expect(container.read(authControllerProvider).hasError, isTrue);
      expect(bootstrap.cleared, 0);
      expect(store.keys, ['u1/fuel/v1']);
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
