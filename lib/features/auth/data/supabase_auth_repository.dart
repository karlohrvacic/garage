import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/google_config.dart';
import '../../../core/links/url_opener.dart';
import '../../../domain/auth/email_link.dart';
import 'auth_repository.dart';

/// What the app asks Google for: who you are, nothing else. No Drive, no
/// contacts, no calendar — which is also why the consent screen needs no
/// verification review.
const _googleScopes = ['email', 'profile'];

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
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    // The display name rides along in user metadata so the handle_new_user
    // trigger can create the profile row without a second round trip.
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
      // Where the confirmation link comes back to. Named explicitly rather
      // than left to the project's Site URL, so the destination is visible
      // here instead of only in a dashboard nobody reads. It must also be in
      // the project's redirect allow-list — see RUNBOOK-update.md.
      emailRedirectTo: kIsWeb ? null : GarageLinks.confirmEmail.toString(),
    );
    // No session means the project requires a confirmed address. The account
    // exists; the user simply cannot use it yet, and needs telling.
    return response.session == null;
  }

  @override
  Future<void> confirmEmailLink(EmailLink link) async {
    await _client.auth.verifyOTP(
      tokenHash: link.tokenHash,
      type: switch (link.purpose) {
        EmailLinkPurpose.confirmSignUp => OtpType.email,
        EmailLinkPurpose.resetPassword => OtpType.recovery,
      },
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    // google_sign_in's authenticate() throws UnsupportedError on web; there the
    // browser redirect flow is the supported path.
    if (kIsWeb) {
      await _client.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: GoogleConfig.webClientId);

    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in returned no ID token');
    }

    // Asking for no scopes is not "ask for nothing" — the platform rejects an
    // empty authorization request, which is what made this fail after the
    // account picker had already succeeded. `authorizationForScopes` returns
    // null when there is no *existing* grant, so `authorizeScopes` is what
    // actually prompts the first time.
    final authorization =
        await account.authorizationClient.authorizationForScopes(
          _googleScopes,
        ) ??
        await account.authorizationClient.authorizeScopes(_googleScopes);

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> sendPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<void> updatePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));

  @override
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await _client.auth.signOut();
  }
}
