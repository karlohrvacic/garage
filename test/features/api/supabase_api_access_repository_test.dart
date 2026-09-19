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

      expect(row.keys, {
        'household_id',
        'url',
        'secret',
        'events',
        'format',
        'language',
      });
      expect(row['events'], ['reminder.due']);
      expect(row['language'], 'en');
    });

    test('a named hook for some cars in Croatian writes all three', () {
      final row = webhookToRow(
        householdId: 'h1',
        url: Uri.parse('https://home.example/garage'),
        secret: 's3cret',
        events: {WebhookEvent.reminderDue},
        name: 'Kitchen display',
        vehicleIds: ['v1', 'v2'],
        language: WebhookLanguage.hr,
      );

      expect(row['name'], 'Kitchen display');
      expect(row['vehicle_ids'], ['v1', 'v2']);
      expect(row['language'], 'hr');
    });

    test('every car is the column left alone, not an empty list', () {
      // Null in the column means every car; an empty array would mean no
      // car, and the hook would go quiet the day it was added.
      final row = webhookToRow(
        householdId: 'h1',
        url: Uri.parse('https://home.example/garage'),
        secret: 's3cret',
        events: {WebhookEvent.reminderDue},
      );

      expect(row.containsKey('vehicle_ids'), isFalse);
      expect(row.containsKey('name'), isFalse);
    });

    test('a row with a name, cars, language and a pause maps', () {
      final hook = webhookFromRow({
        ...webhookRow(active: false),
        'name': 'Kitchen display',
        'vehicle_ids': <dynamic>['v1'],
        'language': 'hr',
        'paused_reason': 'failing',
      });

      expect(hook.name, 'Kitchen display');
      expect(hook.vehicleIds, ['v1']);
      expect(hook.language, WebhookLanguage.hr);
      expect(hook.pausedReason, 'failing');
      expect(hook.isPaused, isTrue);
    });

    test('a row from before those columns maps to the defaults', () {
      final hook = webhookFromRow(webhookRow());

      expect(hook.name, isNull);
      expect(hook.vehicleIds, isNull);
      expect(hook.language, WebhookLanguage.en);
      expect(hook.pausedReason, isNull);
      expect(hook.isPaused, isFalse);
    });

    test('a null vehicle_ids column is every car', () {
      final hook = webhookFromRow({...webhookRow(), 'vehicle_ids': null});

      expect(hook.vehicleIds, isNull);
    });

    test('every key the server can write reads back', () {
      final hook = webhookFromRow({
        ...webhookRow(),
        'events': <dynamic>[for (final event in WebhookEvent.values) event.key],
      });

      expect(hook.events, WebhookEvent.values.toSet());
    });
  });

  group('changing a hook', () {
    test('touches only the columns named', () {
      expect(webhookChangesToRow(const WebhookChanges()), isEmpty);
      expect(webhookChangesToRow(const WebhookChanges(name: 'Kitchen')), {
        'name': 'Kitchen',
      });
    });

    test('an emptied name is stored as none', () {
      expect(webhookChangesToRow(const WebhookChanges(name: '')), {
        'name': null,
      });
    });

    test('events are written as their keys', () {
      expect(
        webhookChangesToRow(
          const WebhookChanges(
            events: {WebhookEvent.entryCreated, WebhookEvent.memberLeft},
          ),
        ),
        {
          'events': ['entry.created', 'member.left'],
        },
      );
    });

    test('some cars is the list and every car is null', () {
      expect(webhookChangesToRow(const WebhookChanges(vehicleIds: ['v1'])), {
        'vehicle_ids': ['v1'],
      });
      expect(webhookChangesToRow(const WebhookChanges(clearVehicleIds: true)), {
        'vehicle_ids': null,
      });
    });

    test('resuming also forgets why it was paused', () {
      expect(webhookChangesToRow(const WebhookChanges(active: true)), {
        'active': true,
        'paused_reason': null,
      });
      expect(webhookChangesToRow(const WebhookChanges(active: false)), {
        'active': false,
      });
    });

    test('a language is written as its code', () {
      expect(
        webhookChangesToRow(const WebhookChanges(language: WebhookLanguage.it)),
        {'language': 'it'},
      );
    });
  });

  group('deliveries', () {
    Map<String, dynamic> deliveryRow({
      Object? deliveredAt,
      Object? givenUpAt,
      Object? lastStatus = 200,
      int attempts = 1,
    }) {
      return {
        'id': 'd1',
        'event': 'entry.created',
        'created_at': '2026-09-19T08:00:00Z',
        'attempts': attempts,
        'last_status': lastStatus,
        'delivered_at': deliveredAt,
        'given_up_at': givenUpAt,
      };
    }

    test('a delivered row maps', () {
      final delivery = webhookDeliveryFromRow(
        deliveryRow(deliveredAt: '2026-09-19T08:00:02Z'),
      );

      expect(delivery.id, 'd1');
      expect(delivery.event, 'entry.created');
      expect(delivery.createdAt, DateTime.utc(2026, 9, 19, 8));
      expect(delivery.attempts, 1);
      expect(delivery.lastStatus, 200);
      expect(delivery.deliveredAt, DateTime.utc(2026, 9, 19, 8, 0, 2));
      expect(delivery.delivered, isTrue);
      expect(delivery.givenUp, isFalse);
    });

    test('a given-up row maps', () {
      final delivery = webhookDeliveryFromRow(
        deliveryRow(
          givenUpAt: '2026-09-19T09:11:00Z',
          lastStatus: 503,
          attempts: 4,
        ),
      );

      expect(delivery.attempts, 4);
      expect(delivery.lastStatus, 503);
      expect(delivery.givenUpAt, DateTime.utc(2026, 9, 19, 9, 11));
      expect(delivery.delivered, isFalse);
      expect(delivery.givenUp, isTrue);
    });

    test('a row still in flight has no status yet', () {
      final delivery = webhookDeliveryFromRow(
        deliveryRow(lastStatus: null, attempts: 0),
      );

      expect(delivery.lastStatus, isNull);
      expect(delivery.delivered, isFalse);
      expect(delivery.givenUp, isFalse);
    });
  });
}
