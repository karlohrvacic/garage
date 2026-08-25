import '../../../domain/api/api_access.dart';

/// The household's API keys and webhooks. Screens depend on this, never on
/// Supabase directly, so the backend can be faked in tests.
abstract interface class ApiAccessRepository {
  Future<List<ApiKeyRecord>> keys(String householdId);

  /// Issues a key and returns it in full — the only time it exists outside the
  /// household's own notes.
  Future<String> createKey({required String householdId, required String name});

  Future<void> revokeKey(String id);

  Future<List<Webhook>> webhooks(String householdId);

  Future<void> addWebhook({
    required String householdId,
    required Uri url,
    required Set<WebhookEvent> events,

    /// Only needed for a receiver the URL cannot identify — a self-hosted
    /// ntfy, Gotify or Mattermost. Everything else reads from the host.
    WebhookFormat format = WebhookFormat.auto,
  });

  Future<void> deleteWebhook(String id);
}
