import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/notifications/push_registration.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/account/account_identity.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Who is signed in, as a screen wants to show it, or null when nobody is.
///
/// Separate from [currentUserProvider] so screens depend on two strings rather
/// than on Supabase's [User] — which also means a test can say who is signed in
/// without constructing one.
final accountIdentityProvider = Provider<AccountIdentity?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }
  return AccountIdentity.of(
    email: user.email,
    metadata: user.userMetadata ?? const {},
  );
});

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);

/// Drives the auth screens. Every method leaves the provider in either a data
/// or an error state — never silently swallowing a failure — so the UI always
/// has something concrete to render.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email.trim(), password: password);
      await _registerForPush();
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _run(() async {
      await ref
          .read(authRepositoryProvider)
          .signUp(
            email: email.trim(),
            password: password,
            displayName: displayName.trim(),
          );
      await _registerForPush();
    });
  }

  Future<void> signInWithGoogle() async {
    await _run(() async {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      await _registerForPush();
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await _run(
      () => ref.read(authRepositoryProvider).sendPasswordReset(email.trim()),
    );
  }

  Future<void> updatePassword(String newPassword) async {
    await _run(
      () => ref.read(authRepositoryProvider).updatePassword(newPassword),
    );
  }

  Future<void> signOut() async {
    await _run(() async {
      // Before the session goes: withdrawing needs the row this user is still
      // allowed to delete. A shared phone would otherwise keep receiving the
      // previous account's reminders.
      await _withdrawFromPush();
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  Future<void> deleteAccount() async {
    await _run(() => ref.read(authRepositoryProvider).deleteAccount());
  }

  /// Push is a convenience layered on top of a session, so neither of these
  /// may turn a sign-in that worked into an error the user sees. The failure is
  /// still recorded — [PushRegistration] reports it — just not raised here.
  Future<void> _registerForPush() async {
    try {
      await ref.read(pushRegistrationProvider).register();
    } on Object {
      // Deliberately swallowed; see above.
    }
  }

  Future<void> _withdrawFromPush() async {
    try {
      await ref.read(pushRegistrationProvider).withdraw();
    } on Object {
      // Deliberately swallowed; signing out must always proceed.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
    }
  }
}
