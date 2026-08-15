import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/api/api_access.dart';
import 'package:garage/features/api/data/supabase_api_access_repository.dart';

Map<String, dynamic> keyRow({Object? revokedAt, Object? lastUsedAt}) {
  return {
    'id': 'k1',
    'household_id': 'h1',
    'name': 'Home Assistant',
    'key_preview': '…mnop',
    'created_at': '2026-07-24T10:30:00Z',
    'last_used_at': lastUsedAt,
    'revoked_at': revokedAt,
  };
}

Map<String, dynamic> webhookRow({bool active = true}) {
  return {
    'id': 'w1',
    'household_id': 'h1',
    'url': 'https://home.example/garage',
    'secret': 's3cret',
    'events': <dynamic>['entry.created', 'reminder.due'],
    'active': active,
    'created_at': '2026-07-24T10:30:00Z',
    'last_delivery_at': null,
    'last_delivery_status': null,
  };
}

void main() {
  group('api keys', () {
    test('a row maps onto the record', () {
      final key = apiKeyFromRow(keyRow());

      expect(key.id, 'k1');
      expect(key.name, 'Home Assistant');
      expect(key.preview, '…mnop');
      expect(key.createdAt, DateTime.utc(2026, 7, 24, 10, 30));
      expect(key.lastUsedAt, isNull);
      expect(key.isRevoked, isFalse);
    });

    test('a revoked key says so', () {
      final key = apiKeyFromRow(keyRow(revokedAt: '2026-08-01T09:00:00Z'));

      expect(key.isRevoked, isTrue);
      expect(key.revokedAt, DateTime.utc(2026, 8, 1, 9));
    });

    test('a key that has been used carries when', () {
      final key = apiKeyFromRow(keyRow(lastUsedAt: '2026-08-02T06:15:00Z'));

      expect(key.lastUsedAt, DateTime.utc(2026, 8, 2, 6, 15));
    });

    test('the hash and preview are what a new key writes', () {
      final row = apiKeyToRow(
        householdId: 'h1',
        name: 'Home Assistant',
        keyHash: 'a' * 64,
        preview: '…mnop',
      );

      expect(row.keys, {'household_id', 'name', 'key_hash', 'key_preview'});
      expect(row['key_hash'], 'a' * 64);
    });

    test('a written row never carries the key itself', () {
      final row = apiKeyToRow(
        householdId: 'h1',
        name: 'Home Assistant',
        keyHash: 'a' * 64,
        preview: '…mnop',
      );

      expect(row.values.join(), isNot(contains('grg_')));
    });
  });

  group('webhooks', () {
    test('a row maps onto the entity', () {
      final hook = webhookFromRow(webhookRow());

      expect(hook.id, 'w1');
      expect(hook.url, Uri.parse('https://home.example/garage'));
      expect(hook.events, {
        WebhookEvent.entryCreated,
        WebhookEvent.reminderDue,
      });
      expect(hook.active, isTrue);
    });

    test('an inactive hook says so', () {
      expect(webhookFromRow(webhookRow(active: false)).active, isFalse);
    });

    test('an event the app does not know is ignored, not fatal', () {
      final hook = webhookFromRow({
        ...webhookRow(),
        'events': <dynamic>['entry.created', 'something.new'],
      });

      expect(hook.events, {WebhookEvent.entryCreated});
    });

    test('writing names the columns the table has', () {
      final row = webhookToRow(
        householdId: 'h1',
        url: Uri.parse('https://home.example/garage'),
        secret: 's3cret',
        events: {WebhookEvent.reminderDue},
      );

      expect(row.keys, {'household_id', 'url', 'secret', 'events'});
      expect(row['events'], ['reminder.due']);
    });
  });
}
