import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/auth/email_link.dart';

/// The app's view of authentication. Screens depend on this, never on
/// Supabase directly, so the backend can be swapped or faked in tests.
abstract interface class AuthRepository {
  User? get currentUser;

  Future<void> signIn({required String email, required String password});

  /// Creates the account, answering whether it is waiting on an emailed
  /// confirmation link.
  ///
  /// True when the project requires confirmation: the sign-up succeeds and
  /// hands back no session, so nothing changes on screen unless somebody says
  /// so. Returning it rather than discarding it is what lets the screen say
  /// "check your email" instead of appearing to have done nothing.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Native Google sign-in. Throws [UnsupportedError] where Google sign-in is
  /// not configured for the platform.
  Future<void> signInWithGoogle();

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Sets a new password for the signed-in user; the recovery link signs the
  /// user in, so this completes the reset flow.
  Future<void> updatePassword(String newPassword);

  /// Exchanges an emailed link's token hash for a session.
  ///
  /// Both kinds go through here. A confirmation signs the new account in; a
  /// recovery signs the user in *and* raises `passwordRecovery`, which is what
  /// puts the new-password prompt on screen (see `main.dart`).
  Future<void> confirmEmailLink(EmailLink link);

  /// Changes the name shown to the rest of the garage.
  ///
  /// Two places hold it: the auth user's metadata, which is where this device
  /// reads its own name from, and the `profiles` row, which is what every
  /// other member sees against the entries you logged. Writing one and not the
  /// other leaves a household where you are called two different things.
  Future<void> updateDisplayName(String name);

  /// Permanently deletes the account and everything it owns. Not reversible.
  Future<void> deleteAccount();
}
