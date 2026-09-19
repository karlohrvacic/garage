import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/api/api_access.dart';
import '../../../domain/api/api_key.dart';
import 'api_access_repository.dart';

class SupabaseApiAccessRepository implements ApiAccessRepository {
  SupabaseApiAccessRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ApiKeyRecord>> keys(String householdId) async {
    try {
      final rows = await _client
          .from('api_keys')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      return rows.map(apiKeyFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<String> createKey({
    required String householdId,
    required String name,
  }) async {
    final key = ApiKeys.generate();
    try {
      await _client.from('api_keys').insert({
        ...apiKeyToRow(
          householdId: householdId,
          name: name,
          keyHash: ApiKeys.hash(key),
          preview: ApiKeys.preview(key),
        ),
        'created_by': _client.auth.currentUser!.id,
      });
      return key;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> revokeKey(String id) async {
    try {
      // Revoked rather than deleted: a household should be able to see that a
      // key existed and when it was last used.
      await _client
          .from('api_keys')
          .update({'revoked_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<Webhook>> webhooks(String householdId) async {
    try {
      final rows = await _client
          .from('webhooks')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      return rows.map(webhookFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
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
    try {
      await _client.from('webhooks').insert({
        ...webhookToRow(
          householdId: householdId,
          url: url,
          secret: _secret(),
          events: events,
          format: format,
          name: name,
          vehicleIds: vehicleIds,
          language: language,
        ),
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> updateWebhook(String id, WebhookChanges changes) async {
    try {
      await _client
          .from('webhooks')
          .update(webhookChangesToRow(changes))
          .eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> deleteWebhook(String id) async {
    try {
      await _client.from('webhooks').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<List<WebhookDelivery>> deliveries(String webhookId) async {
    try {
      final rows = await _client
          .from('webhook_deliveries')
          .select(
            'id, event, created_at, attempts, last_status, delivered_at, '
            'given_up_at',
          )
          .eq('webhook_id', webhookId)
          .order('created_at', ascending: false)
          .limit(20);
      return rows.map(webhookDeliveryFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> sendTest({required String householdId}) async {
    try {
      // The one insert the outbox policy allows. No poke from here: the
      // table's trigger does it, and the cron drain is the guarantee.
      await _client.from('webhook_outbox').insert({
        'household_id': householdId,
        'event': 'test.ping',
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// What the delivery signs its calls with, so a receiver can tell a real one
  /// from a spoofed one.
  static String _secret() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => '0123456789abcdef'[random.nextInt(16)],
    ).join();
  }
}

Map<String, dynamic> apiKeyToRow({
  required String householdId,
  required String name,
  required String keyHash,
  required String preview,
}) {
  return {
    'household_id': householdId,
    'name': name,
    'key_hash': keyHash,
    'key_preview': preview,
  };
}

ApiKeyRecord apiKeyFromRow(Map<String, dynamic> row) {
  DateTime? at(Object? value) =>
      value == null ? null : DateTime.parse(value as String).toUtc();

  return ApiKeyRecord(
    id: row['id'] as String,
    name: row['name'] as String,
    preview: row['key_preview'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    lastUsedAt: at(row['last_used_at']),
    revokedAt: at(row['revoked_at']),
  );
}

Map<String, dynamic> webhookToRow({
  required String householdId,
  required Uri url,
  required String secret,
  required Set<WebhookEvent> events,
  WebhookFormat format = WebhookFormat.auto,
  String? name,
  List<String>? vehicleIds,
  WebhookLanguage language = WebhookLanguage.en,
}) {
  return {
    'household_id': householdId,
    'url': url.toString(),
    'secret': secret,
    'events': [for (final event in events) event.key],
    'format': format.key,
    'name': ?name,
    // Left out for every car: a null column is every car, an empty array
    // would be none.
    'vehicle_ids': ?vehicleIds,
    'language': language.name,
  };
}

/// Only the columns [changes] names, so an update touches nothing else.
Map<String, dynamic> webhookChangesToRow(WebhookChanges changes) {
  return {
    if (changes.name case final name?) 'name': name.isEmpty ? null : name,
    if (changes.events case final events?)
      'events': [for (final event in events) event.key],
    if (changes.clearVehicleIds)
      'vehicle_ids': null
    else
      'vehicle_ids': ?changes.vehicleIds,
    'language': ?changes.language?.name,
    if (changes.active case final active?) ...{
      'active': active,
      if (active) 'paused_reason': null,
    },
  };
}

DateTime? _at(Object? value) =>
    value == null ? null : DateTime.parse(value as String).toUtc();

Webhook webhookFromRow(Map<String, dynamic> row) {
  return Webhook(
    id: row['id'] as String,
    url: Uri.parse(row['url'] as String),
    events: {
      // An event a newer client wrote reads as null and is simply left out.
      for (final key in row['events'] as List<dynamic>)
        ?WebhookEvent.fromKey(key as String),
    },
    active: row['active'] as bool,
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    lastDeliveryAt: _at(row['last_delivery_at']),
    lastDeliveryStatus: (row['last_delivery_status'] as num?)?.toInt(),
    format: WebhookFormat.fromKey(row['format'] as String?),
    name: row['name'] as String?,
    vehicleIds: (row['vehicle_ids'] as List<dynamic>?)?.cast<String>(),
    language: WebhookLanguage.fromKey(row['language'] as String?),
    pausedReason: row['paused_reason'] as String?,
  );
}

WebhookDelivery webhookDeliveryFromRow(Map<String, dynamic> row) {
  return WebhookDelivery(
    id: row['id'] as String,
    event: row['event'] as String,
    createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
    attempts: (row['attempts'] as num).toInt(),
    lastStatus: (row['last_status'] as num?)?.toInt(),
    deliveredAt: _at(row['delivered_at']),
    givenUpAt: _at(row['given_up_at']),
  );
}
