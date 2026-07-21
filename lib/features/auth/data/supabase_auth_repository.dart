import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/google_config.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  User? get currentUser => _client.auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    // The display name rides along in user metadata so the handle_new_user
    // trigger can create the profile row without a second round trip.
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: GoogleConfig.webClientId);

    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in returned no ID token');
    }
    final authorization =
        await account.authorizationClient.authorizationForScopes([]);

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut();
  }
}
