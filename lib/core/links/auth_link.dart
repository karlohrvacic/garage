/// What an authentication redirect is trying to tell us.
///
/// Supabase sends a confirmation or recovery link to its own `/auth/v1/verify`
/// endpoint, which then redirects to the app. When it works there is a session
/// and nothing to read here. When it does not — an expired link, one already
/// used, one opened after the token was rotated — it redirects with the reason
/// in the URL and no session, and the app simply showed the sign-in screen
/// with nothing on it. The user is told nothing at all, having done the one
/// thing the email asked.
library;

/// The human-readable reason an auth redirect failed, or null when the URL
/// carries no error.
///
/// Reads the fragment as well as the query: the implicit flow puts everything
/// after `#`, the PKCE flow uses `?`, and which one a project uses is a
/// setting rather than something this can assume.
String? authErrorFromUrl(Uri url) {
  final fromQuery = _errorIn(url.queryParameters);
  if (fromQuery != null) {
    return fromQuery;
  }
  if (url.fragment.isEmpty) {
    return null;
  }
  // The fragment is query-shaped but is not parsed as a query by Uri, since
  // as far as it is concerned a fragment is an opaque string.
  return _errorIn(Uri.splitQueryString(url.fragment));
}

String? _errorIn(Map<String, String> parameters) {
  final description = parameters['error_description'];
  if (description != null && description.trim().isNotEmpty) {
    // Supabase sends these plus-encoded and sentence-shaped already.
    return description.replaceAll('+', ' ').trim();
  }
  // `error` alone is a code like `access_denied`, which is not a sentence but
  // is still better than silence.
  final code = parameters['error'] ?? parameters['error_code'];
  return (code != null && code.trim().isNotEmpty) ? code.trim() : null;
}
