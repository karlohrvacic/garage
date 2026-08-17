/// What an emailed link is for.
enum EmailLinkPurpose {
  /// Finishing sign-up by proving the address is real.
  confirmSignUp,

  /// Choosing a new password, having forgotten the old one.
  resetPassword,
}

/// A confirmation link the app was opened with.
///
/// Supabase's default template links to the project's own `/auth/v1/verify`,
/// which then redirects to this app. That extra hop is what stopped Android
/// opening the app at all: an app link is matched against the URL the person
/// *taps*, and theirs was on supabase.co. Building the link against this app's
/// own host instead — carrying the token hash rather than a redirect — makes
/// the tapped URL one the manifest claims, so the app opens directly and the
/// web build still handles it for anyone who has not installed it.
class EmailLink {
  const EmailLink({required this.purpose, required this.tokenHash});

  final EmailLinkPurpose purpose;

  /// The single-use hash from the email. Exchanged for a session; never stored.
  final String tokenHash;

  /// Reads a link's query, or null if it does not carry a usable one.
  ///
  /// Null rather than a throw or a default: this route is reachable by typing
  /// the URL, by a stale bookmark, and by a template whose variables did not
  /// interpolate. None of those is an error worth a stack trace, and all of
  /// them should end up somewhere a person can sign in.
  static EmailLink? fromQuery(Map<String, String> query) {
    final tokenHash = query['token_hash'];
    if (tokenHash == null || tokenHash.isEmpty) {
      return null;
    }
    final purpose = switch (query['type']) {
      // Supabase writes `signup` in its own confirmation template and `email`
      // in the documented one. They mean the same thing here.
      'email' || 'signup' => EmailLinkPurpose.confirmSignUp,
      'recovery' => EmailLinkPurpose.resetPassword,
      _ => null,
    };
    if (purpose == null) {
      return null;
    }
    return EmailLink(purpose: purpose, tokenHash: tokenHash);
  }
}
