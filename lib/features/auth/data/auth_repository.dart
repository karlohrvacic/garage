import 'package:supabase_flutter/supabase_flutter.dart';

/// The app's view of authentication. Screens depend on this, never on
/// Supabase directly, so the backend can be swapped or faked in tests.
abstract interface class AuthRepository {
  User? get currentUser;

  Future<void> signIn({required String email, required String password});

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Native Google sign-in. Throws [UnsupportedError] where Google sign-in is
  /// not configured for the platform.
  Future<void> signInWithGoogle();

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Permanently deletes the account and everything it owns. Not reversible.
  Future<void> deleteAccount();
}
