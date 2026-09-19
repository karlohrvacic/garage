/// What a webhook can be told about: the keys the server writes, which a
/// receiver matches on. Twelve here; `test.ping` is not one, since it is sent
/// to every active hook whatever it chose.
enum WebhookEvent {
  /// A fill-up, service, cost, reading, trip or income was logged.
  entryCreated('entry.created'),
  entryUpdated('entry.updated'),
  entryDeleted('entry.deleted'),
  vehicleAdded('vehicle.added'),
  vehicleArchived('vehicle.archived'),
  vehicleRestored('vehicle.restored'),

  /// Sold: announced to the seller's hooks, the only ones that knew the car.
  vehicleHandedOver('vehicle.handed_over'),
  vehicleLent('vehicle.lent'),
  vehicleReturned('vehicle.returned'),
  memberJoined('member.joined'),
  memberLeft('member.left'),

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

/// What the sheet shows: five switches over twelve keys. A group is on when
/// every key in it is on, and writes all of them, so the stored list stays
/// the fine keys a receiver matches on.
enum WebhookEventGroup {
  entries({WebhookEvent.entryCreated}),
  changes({WebhookEvent.entryUpdated, WebhookEvent.entryDeleted}),
  cars({
    WebhookEvent.vehicleAdded,
    WebhookEvent.vehicleArchived,
    WebhookEvent.vehicleRestored,
    WebhookEvent.vehicleHandedOver,
    WebhookEvent.vehicleLent,
    WebhookEvent.vehicleReturned,
  }),
  members({WebhookEvent.memberJoined, WebhookEvent.memberLeft}),
  reminders({WebhookEvent.reminderDue});

  const WebhookEventGroup(this.events);

  final Set<WebhookEvent> events;

  static Set<WebhookEventGroup> of(Set<WebhookEvent> events) => {
    for (final group in values)
      if (events.containsAll(group.events)) group,
  };

  static Set<WebhookEvent> toEvents(Set<WebhookEventGroup> groups) => {
    for (final group in groups) ...group.events,
  };
}

/// The language a chat receiver reads the message in. The signed JSON is the
/// same in every one.
enum WebhookLanguage {
  en,
  hr,
  it;

  static WebhookLanguage fromKey(String? key) =>
      values.firstWhere((it) => it.name == key, orElse: () => en);
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

/// The body shape a receiver will accept.
///
/// [auto] reads it from the URL's host, which is right for every hosted
/// service — Discord, Slack, Google Chat, Telegram, ntfy.sh, Teams, Pushover,
/// Pushbullet — and for every generic receiver. The rest exist for the ones a
/// household runs itself: a self-hosted ntfy, Gotify, Mattermost or Rocket.Chat
/// answers on a domain of the owner's choosing, and no list of hostnames will
/// ever contain it.
enum WebhookFormat {
  auto,
  generic,
  discord,
  slack,
  googlechat,
  telegram,
  ntfy,
  gotify,
  teams,
  text,
  pushover,
  pushbullet;

  /// The stable stored form, deliberately not [Object.name] so a rename
  /// cannot change what is already sitting in the database.
  String get key => switch (this) {
    auto => 'auto',
    generic => 'generic',
    discord => 'discord',
    slack => 'slack',
    googlechat => 'googlechat',
    telegram => 'telegram',
    ntfy => 'ntfy',
    gotify => 'gotify',
    teams => 'teams',
    text => 'text',
    pushover => 'pushover',
    pushbullet => 'pushbullet',
  };

  /// [auto] for anything unrecognised rather than a guess: an unknown shape
  /// would send a body the receiver has never heard of, and reading the host
  /// is the better fallback.
  static WebhookFormat fromKey(String? key) {
    for (final format in values) {
      if (format.key == key) {
        return format;
      }
    }
    return auto;
  }
}

/// Whether [url] lacks the credentials a push service reads out of its query.
///
/// Pushover and Pushbullet have no per-channel address: the pasted URL has to
/// carry the token (and, for Pushover, the user key) that the dispatcher lifts
/// into the body or a header. Without them every delivery would be refused,
/// and the log would say so only after the first event. The hosts are the two
/// the dispatcher recognises; the format covers a receiver named by hand.
bool missingWebhookCredentials(Uri url, WebhookFormat format) {
  final query = url.queryParameters;
  final pushover =
      format == WebhookFormat.pushover || url.host == 'api.pushover.net';
  if (pushover) {
    return !query.containsKey('token') || !query.containsKey('user');
  }
  final pushbullet =
      format == WebhookFormat.pushbullet || url.host == 'api.pushbullet.com';
  if (pushbullet) {
    return !query.containsKey('token');
  }
  return false;
}

/// A URL the household wants told when something happens.
class Webhook {
  /// The most a name may be, as the column's check constrains it (0079).
  static const nameLength = 80;

  const Webhook({
    required this.id,
    required this.url,
    required this.events,
    required this.active,
    required this.createdAt,
    this.lastDeliveryAt,
    this.lastDeliveryStatus,
    this.format = WebhookFormat.auto,
    this.name,
    this.vehicleIds,
    this.language = WebhookLanguage.en,
    this.pausedReason,
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

  /// What shape to send. Only meaningful for a receiver the URL cannot
  /// identify, which is why it defaults to reading the host.
  final WebhookFormat format;

  /// What the list calls it, instead of the address. Optional.
  final String? name;

  /// The cars it is told about, or null for every car in the garage.
  final List<String>? vehicleIds;

  /// The language a chat receiver gets its text in.
  final WebhookLanguage language;

  /// Why the dispatcher switched it off, when it did: `failing` after twenty
  /// deliveries in a row were given up on. Null on a hook nobody paused.
  final String? pausedReason;

  bool get isDelivering =>
      lastDeliveryStatus == null ||
      (lastDeliveryStatus! >= 200 && lastDeliveryStatus! < 300);

  /// Off because the dispatcher gave up on it, as opposed to off because a
  /// member switched it off.
  bool get isPaused => !active && pausedReason != null;
}

/// One event's journey to one hook: the row the dispatcher writes when it
/// queues the event, and updates on every attempt.
class WebhookDelivery {
  const WebhookDelivery({
    required this.id,
    required this.event,
    required this.createdAt,
    required this.attempts,
    this.lastStatus,
    this.deliveredAt,
    this.givenUpAt,
  });

  /// How many times the dispatcher tries before it gives up on a row: the
  /// first post and three retries, a minute, ten and an hour later.
  static const mostAttempts = 4;

  final String id;

  /// The key as the server wrote it, `entry.created`; a receiver matched on
  /// exactly this, so the log shows it as is.
  final String event;

  final DateTime createdAt;
  final int attempts;
  final int? lastStatus;
  final DateTime? deliveredAt;
  final DateTime? givenUpAt;

  /// Delivered wins: the drain marks a fourth attempt given up before it
  /// posts and clears the mark only once the receiver answered, so a row
  /// read between the two carries both, and what arrived, arrived.
  bool get delivered => deliveredAt != null;

  bool get givenUp => givenUpAt != null && deliveredAt == null;
}

/// A change to a hook, with "no change" distinct from "set to nothing":
/// a null `vehicleIds` means untouched and `clearVehicleIds` means every car.
class WebhookChanges {
  const WebhookChanges({
    this.name,
    this.events,
    this.vehicleIds,
    this.clearVehicleIds = false,
    this.language,
    this.active,
  });

  /// Empty for "no name", which the repository stores as null.
  final String? name;
  final Set<WebhookEvent>? events;
  final List<String>? vehicleIds;
  final bool clearVehicleIds;
  final WebhookLanguage? language;

  /// True also clears the pause reason: a hook a member resumed is not one
  /// the dispatcher paused, whatever it did before.
  final bool? active;
}
