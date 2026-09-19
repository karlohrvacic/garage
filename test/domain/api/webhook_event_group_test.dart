import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/api/api_access.dart';

void main() {
  group('event groups', () {
    test('a group is on when every key in it is on', () {
      expect(
        WebhookEventGroup.of({
          WebhookEvent.entryCreated,
          WebhookEvent.reminderDue,
        }),
        {WebhookEventGroup.entries, WebhookEventGroup.reminders},
      );
    });

    test('half a group is no group', () {
      // A hook written by hand with only the update key would otherwise
      // show "changes" on, and saving the sheet would add the delete key
      // that was never asked for.
      expect(WebhookEventGroup.of({WebhookEvent.entryUpdated}), isEmpty);
    });

    test('a group writes every fine key a receiver matches on', () {
      expect(WebhookEventGroup.toEvents({WebhookEventGroup.cars}), {
        WebhookEvent.vehicleAdded,
        WebhookEvent.vehicleArchived,
        WebhookEvent.vehicleRestored,
        WebhookEvent.vehicleHandedOver,
        WebhookEvent.vehicleLent,
        WebhookEvent.vehicleReturned,
      });
    });

    test('the five groups cover the twelve keys, each once', () {
      final all = [
        for (final group in WebhookEventGroup.values) ...group.events,
      ];

      expect(all.toSet(), WebhookEvent.values.toSet());
      expect(all, hasLength(WebhookEvent.values.length));
    });
  });

  group('event keys', () {
    test('a stored key reads back as its event', () {
      expect(WebhookEvent.fromKey('vehicle.lent'), WebhookEvent.vehicleLent);
    });

    test('an unknown key is null, not an error', () {
      expect(WebhookEvent.fromKey('nonsense'), isNull);
    });

    test('the keys are what the server writes', () {
      expect(WebhookEvent.values.map((event) => event.key), [
        'entry.created',
        'entry.updated',
        'entry.deleted',
        'vehicle.added',
        'vehicle.archived',
        'vehicle.restored',
        'vehicle.handed_over',
        'vehicle.lent',
        'vehicle.returned',
        'member.joined',
        'member.left',
        'reminder.due',
      ]);
    });
  });

  group('language', () {
    test('reads the app locale and falls back to English', () {
      expect(WebhookLanguage.fromKey('hr'), WebhookLanguage.hr);
      expect(WebhookLanguage.fromKey('de'), WebhookLanguage.en);
      expect(WebhookLanguage.fromKey(null), WebhookLanguage.en);
    });
  });

  group('formats', () {
    test('the four new shapes keep their stored keys', () {
      expect(WebhookFormat.teams.key, 'teams');
      expect(WebhookFormat.text.key, 'text');
      expect(WebhookFormat.pushover.key, 'pushover');
      expect(WebhookFormat.pushbullet.key, 'pushbullet');
      expect(WebhookFormat.fromKey('pushover'), WebhookFormat.pushover);
    });
  });

  group('a delivery', () {
    WebhookDelivery delivery({DateTime? deliveredAt, DateTime? givenUpAt}) {
      return WebhookDelivery(
        id: 'd1',
        event: 'entry.created',
        createdAt: DateTime.utc(2026, 9, 19, 8),
        attempts: 4,
        deliveredAt: deliveredAt,
        givenUpAt: givenUpAt,
      );
    }

    test('is delivered once it has a delivery time', () {
      final row = delivery(deliveredAt: DateTime.utc(2026, 9, 19, 8, 1));

      expect(row.delivered, isTrue);
      expect(row.givenUp, isFalse);
    });

    test('is given up when it ran out of attempts without arriving', () {
      final row = delivery(givenUpAt: DateTime.utc(2026, 9, 19, 9, 11));

      expect(row.delivered, isFalse);
      expect(row.givenUp, isTrue);
    });

    test('a fourth attempt that succeeded is delivered, not given up', () {
      // The drain marks the last attempt given up before it posts, and
      // clears the mark only after the receiver answered; a row read between
      // the two carries both. What arrived, arrived.
      final row = delivery(
        deliveredAt: DateTime.utc(2026, 9, 19, 9, 11, 2),
        givenUpAt: DateTime.utc(2026, 9, 19, 9, 11),
      );

      expect(row.delivered, isTrue);
      expect(row.givenUp, isFalse);
    });

    test('is still in flight with neither', () {
      final row = delivery();

      expect(row.delivered, isFalse);
      expect(row.givenUp, isFalse);
    });
  });

  group('a paused hook', () {
    Webhook hook({required bool active, String? pausedReason}) {
      return Webhook(
        id: 'w1',
        url: Uri.parse('https://home.example/garage'),
        events: const {WebhookEvent.entryCreated},
        active: active,
        createdAt: DateTime.utc(2026, 7, 24),
        pausedReason: pausedReason,
      );
    }

    test('is one the dispatcher switched off', () {
      expect(hook(active: false, pausedReason: 'failing').isPaused, isTrue);
    });

    test('is not one a member switched off', () {
      expect(hook(active: false).isPaused, isFalse);
    });

    test('is not one that is running', () {
      // A stale reason on a hook a member resumed is not a pause.
      expect(hook(active: true, pausedReason: 'failing').isPaused, isFalse);
    });
  });

  group('credentials in the address', () {
    test('Pushover wants a token and a user key', () {
      expect(
        missingWebhookCredentials(
          Uri.parse('https://api.pushover.net/1/messages.json?token=a'),
          WebhookFormat.auto,
        ),
        isTrue,
      );
      expect(
        missingWebhookCredentials(
          Uri.parse('https://api.pushover.net/1/messages.json?token=a&user=b'),
          WebhookFormat.auto,
        ),
        isFalse,
      );
    });

    test('Pushbullet wants a token', () {
      expect(
        missingWebhookCredentials(
          Uri.parse('https://api.pushbullet.com/v2/pushes'),
          WebhookFormat.auto,
        ),
        isTrue,
      );
      expect(
        missingWebhookCredentials(
          Uri.parse('https://api.pushbullet.com/v2/pushes?token=a'),
          WebhookFormat.auto,
        ),
        isFalse,
      );
    });

    test('the chosen format counts as much as the host', () {
      expect(
        missingWebhookCredentials(
          Uri.parse('https://push.example.org/messages'),
          WebhookFormat.pushover,
        ),
        isTrue,
      );
    });

    test('every other receiver carries no token in its address', () {
      expect(
        missingWebhookCredentials(
          Uri.parse('https://home.example/garage'),
          WebhookFormat.auto,
        ),
        isFalse,
      );
      expect(
        missingWebhookCredentials(
          Uri.parse('https://push.example.org/my-garage'),
          WebhookFormat.ntfy,
        ),
        isFalse,
      );
    });
  });
}
