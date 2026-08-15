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
  }) async {
    try {
      await _client.from('webhooks').insert({
        ...webhookToRow(
          householdId: householdId,
          url: url,
          secret: _secret(),
          events: events,
        ),
        'created_by': _client.auth.currentUser!.id,
      });
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
}) {
  return {
    'household_id': householdId,
    'url': url.toString(),
    'secret': secret,
    'events': [for (final event in events) event.key],
  };
}

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
    lastDeliveryAt: row['last_delivery_at'] == null
        ? null
        : DateTime.parse(row['last_delivery_at'] as String).toUtc(),
    lastDeliveryStatus: (row['last_delivery_status'] as num?)?.toInt(),
  );
}
