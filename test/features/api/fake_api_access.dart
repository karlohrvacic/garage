import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/api/api_access.dart';
import 'package:garage/features/api/data/api_access_repository.dart';

/// Records what the screens ask for, and answers from what it was given.
class FakeApiAccessRepository implements ApiAccessRepository {
  FakeApiAccessRepository({
    this.storedKeys = const [],
    this.storedWebhooks = const [],
    this.storedDeliveries = const [],
  });

  List<ApiKeyRecord> storedKeys;
  List<Webhook> storedWebhooks;
  List<WebhookDelivery> storedDeliveries;
  final List<String> calls = [];

  /// Set to make the list of hooks fail to load, as it does with no signal.
  AppFailure? webhooksFailure;

  @override
  Future<List<ApiKeyRecord>> keys(String householdId) async => storedKeys;

  @override
  Future<String> createKey({
    required String householdId,
    required String name,
  }) async {
    calls.add('createKey:$name');
    storedKeys = [
      ...storedKeys,
      ApiKeyRecord(
        id: 'new',
        name: name,
        preview: '…wxyz',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    ];
    return 'grg_abcdefghijklmnopqrstuvwxyz012345';
  }

  @override
  Future<void> revokeKey(String id) async => calls.add('revokeKey:$id');

  @override
  Future<List<Webhook>> webhooks(String householdId) async {
    if (webhooksFailure case final failure?) {
      throw failure;
    }
    return storedWebhooks;
  }

  @override
  Future<void> addWebhook({
    required String householdId,
    required Uri url,
    required Set<WebhookEvent> events,
    WebhookFormat format = WebhookFormat.auto,
    String? name,
    List<String>? vehicleIds,
    WebhookLanguage language = WebhookLanguage.en,
  }) async {
    calls.add('addWebhook:$url:${format.key}:${language.name}');
    addedEvents = events;
    addedName = name;
    addedVehicleIds = vehicleIds;
  }

  /// What the last added hook was subscribed to, called, and narrowed to.
  Set<WebhookEvent>? addedEvents;
  String? addedName;
  List<String>? addedVehicleIds;

  @override
  Future<void> updateWebhook(String id, WebhookChanges changes) async {
    lastChanges = changes;
    calls.add('updateWebhook:$id:${describeChanges(changes)}');
  }

  WebhookChanges? lastChanges;

  @override
  Future<void> deleteWebhook(String id) async => calls.add('deleteWebhook:$id');

  @override
  Future<List<WebhookDelivery>> deliveries(String webhookId) async {
    calls.add('deliveries:$webhookId');
    return storedDeliveries;
  }

  @override
  Future<void> sendTest({required String householdId}) async =>
      calls.add('sendTest:$householdId');
}

/// The change as one line, so a test can say what it expects in full.
String describeChanges(WebhookChanges changes) {
  return [
    if (changes.name case final name?) 'name=$name',
    if (changes.events case final events?)
      'events=${(events.map((e) => e.key).toList()..sort()).join(',')}',
    if (changes.vehicleIds case final ids?) 'vehicleIds=${ids.join(',')}',
    if (changes.clearVehicleIds) 'clearVehicleIds',
    if (changes.language case final language?) 'language=${language.name}',
    if (changes.active case final active?) 'active=$active',
  ].join(';');
}

ApiKeyRecord key({
  String id = 'k1',
  String name = 'Home Assistant',
  DateTime? lastUsedAt,
  DateTime? revokedAt,
}) {
  return ApiKeyRecord(
    id: id,
    name: name,
    preview: '…mnop',
    createdAt: DateTime.utc(2026, 7, 24),
    lastUsedAt: lastUsedAt,
    revokedAt: revokedAt,
  );
}

Webhook webhook({
  String id = 'w1',
  String url = 'https://home.example/garage',
  Set<WebhookEvent> events = const {WebhookEvent.entryCreated},
  int? status,
  DateTime? lastDeliveryAt,
  bool active = true,
  String? name,
  List<String>? vehicleIds,
  WebhookLanguage language = WebhookLanguage.en,
  String? pausedReason,
}) {
  return Webhook(
    id: id,
    url: Uri.parse(url),
    events: events,
    active: active,
    createdAt: DateTime.utc(2026, 7, 24),
    lastDeliveryAt:
        lastDeliveryAt ??
        (status == null ? null : DateTime.utc(2026, 9, 18, 7)),
    lastDeliveryStatus: status,
    name: name,
    vehicleIds: vehicleIds,
    language: language,
    pausedReason: pausedReason,
  );
}

/// A delivery queued at eight in the morning, local time, so what the screen
/// prints does not depend on the zone the test runs in.
WebhookDelivery delivery({
  String id = 'd1',
  String event = 'entry.created',
  int attempts = 1,
  int? lastStatus = 200,
  DateTime? deliveredAt,
  DateTime? givenUpAt,
}) {
  return WebhookDelivery(
    id: id,
    event: event,
    createdAt: DateTime(2026, 9, 19, 8),
    attempts: attempts,
    lastStatus: lastStatus,
    deliveredAt: deliveredAt,
    givenUpAt: givenUpAt,
  );
}
