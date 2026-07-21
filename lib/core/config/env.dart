/// Compile-time configuration, supplied by
/// `--dart-define-from-file=env/local.json`. Nothing here is a secret in the
/// security sense — the anon key is public by design and RLS is what protects
/// the data — but keeping it out of the source tree keeps environments
/// switchable without code edits.
abstract final class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void assertConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_ANON_KEY. Run with '
        '--dart-define-from-file=env/local.json',
      );
    }
  }
}
