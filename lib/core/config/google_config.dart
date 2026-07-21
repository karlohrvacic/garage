abstract final class GoogleConfig {
  /// The *web* client ID, even on Android: Supabase verifies the ID token
  /// against it, and it is what the dashboard's "Authorized Client IDs" field
  /// expects. The Android client ID is never referenced in code.
  static const String webClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get isConfigured => webClientId.isNotEmpty;
}
