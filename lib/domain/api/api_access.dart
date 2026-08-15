/// What a webhook can be told about.
enum WebhookEvent {
  /// A fill-up, service, or cost was logged.
  entryCreated('entry.created'),

  /// A maintenance item came due.
  reminderDue('reminder.due');

  const WebhookEvent(this.key);

  final String key;

  /// The event for a stored key, or null when the row names something this
  /// version of the app does not know — a newer client may have written it.
  static WebhookEvent? fromKey(String key) {
    for (final event in values) {
      if (event.key == key) {
        return event;
      }
    }
    return null;
  }
}

/// A key the household issued to itself for the read-only API. The key itself
/// is shown once at creation and never stored — this is the record of it.
class ApiKeyRecord {
  const ApiKeyRecord({
    required this.id,
    required this.name,
    required this.preview,
    required this.createdAt,
    this.lastUsedAt,
    this.revokedAt,
  });

  final String id;
  final String name;

  /// The tail of the key, for telling two keys apart in a list.
  final String preview;

  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
}

/// A URL the household wants told when something happens.
class Webhook {
  const Webhook({
    required this.id,
    required this.url,
    required this.events,
    required this.active,
    required this.createdAt,
    this.lastDeliveryAt,
    this.lastDeliveryStatus,
  });

  final String id;
  final Uri url;
  final Set<WebhookEvent> events;
  final bool active;
  final DateTime createdAt;
  final DateTime? lastDeliveryAt;

  /// HTTP status of the last attempt, so a household can see a hook that has
  /// been failing rather than wonder why nothing arrives.
  final int? lastDeliveryStatus;

  bool get isDelivering =>
      lastDeliveryStatus == null ||
      (lastDeliveryStatus! >= 200 && lastDeliveryStatus! < 300);
}
