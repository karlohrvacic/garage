import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

/// Drives the auth screens. Every method leaves the provider in either a data
/// or an error state — never silently swallowing a failure — so the UI always
/// has something concrete to render.
class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({required String email, required String password}) async {
    await _run(
      () => ref.read(authRepositoryProvider).signIn(
            email: email.trim(),
            password: password,
          ),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _run(
      () => ref.read(authRepositoryProvider).signUp(
            email: email.trim(),
            password: password,
            displayName: displayName.trim(),
          ),
    );
  }

  Future<void> signInWithGoogle() async {
    await _run(() => ref.read(authRepositoryProvider).signInWithGoogle());
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
    await _run(() => ref.read(authRepositoryProvider).signOut());
  }

  Future<void> deleteAccount() async {
    await _run(() => ref.read(authRepositoryProvider).deleteAccount());
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
