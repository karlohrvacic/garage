import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_scheduler.dart';
import 'package:garage/core/notifications/push_reminder.dart';
import 'package:garage/l10n/app_localizations.dart';

Map<String, dynamic> message({
  String type = 'reminder_due',
  String vehicleId = 'v1',
  String? nickname = 'Golf',
  String keys = 'service_oil_change',
  String dueDate = '2026-09-01',
  String daysUntilDue = '7',
  String? swapDirection,
}) {
  return {
    'type': type,
    'vehicle_id': vehicleId,
    'vehicle_nickname': ?nickname,
    'service_type_keys': keys,
    'due_date': dueDate,
    'days_until_due': daysUntilDue,
    'swap_direction': ?swapDirection,
  };
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('reading what arrived', () {
    test('a reminder push becomes something showable', () {
      final reminder = PushReminder.from(message());

      expect(reminder, isNotNull);
      expect(reminder!.vehicleId, 'v1');
      expect(reminder.vehicleNickname, 'Golf');
      expect(reminder.serviceTypeKeys, ['service_oil_change']);
      expect(reminder.dueDate, DateTime.utc(2026, 9, 1));
    });

    test('several items in one visit arrive as one push', () {
      final reminder = PushReminder.from(
        message(keys: 'service_oil_change,service_brakes'),
      );

      expect(reminder!.serviceTypeKeys, [
        'service_oil_change',
        'service_brakes',
      ]);
    });

    test('a message that is not a reminder is ignored, not guessed at', () {
      // Anything else the project ever sends through FCM lands in the same
      // handler, and showing a notification for it would be worse than
      // silence.
      expect(PushReminder.from(message(type: 'something_else')), isNull);
      expect(PushReminder.from(const {}), isNull);
    });

    test('a malformed payload is ignored rather than shown half-read', () {
      expect(PushReminder.from(message(dueDate: 'soon')), isNull);
      expect(PushReminder.from(message(keys: '')), isNull);
      expect(PushReminder.from(message(vehicleId: '')), isNull);
    });
  });

  group('what it turns into on screen', () {
    test('it lands on the id this device would have used itself', () {
      // The whole point: a push and a locally scheduled reminder for the same
      // visit are one notification, not two identical ones.
      final reminder = PushReminder.from(message())!;

      expect(
        reminder.notificationId,
        notificationId(
          vehicleId: 'v1',
          serviceTypeKeys: const ['service_oil_change'],
          dueDate: DateTime.utc(2026, 9, 1),
          leadDays: 7,
        ),
      );
    });

    test('the month\'s notice is not the week\'s notice', () {
      // Same visit, same car, two nudges. Sharing an id would mean the second
      // silently replaced the first in the shade.
      final early = PushReminder.from(message(daysUntilDue: '30'))!;
      final late = PushReminder.from(message(daysUntilDue: '7'))!;

      expect(early.notificationId, isNot(late.notificationId));
    });

    test('it says how far off the visit is, and which car', () {
      final reminder = PushReminder.from(message(daysUntilDue: '30'))!;

      expect(reminder.body(en), 'Golf · Due in 30 days');
    });

    test('one item names the work, and the car it is for', () {
      final reminder = PushReminder.from(message())!;

      expect(reminder.title(en), en.notificationDueTitle('Oil change'));
      expect(reminder.body(en), 'Golf · Due in 7 days');
    });

    test('a visit with several items says how many', () {
      final reminder = PushReminder.from(
        message(keys: 'service_oil_change,service_brakes'),
      )!;

      expect(reminder.title(en), en.notificationBundleTitle(2));
    });

    test('a car with no name leaves just the when', () {
      final reminder = PushReminder.from(message(nickname: null))!;

      expect(reminder.body(en), 'Due in 7 days');
    });

    test('a push with no lead on it is not shown half-read', () {
      expect(PushReminder.from(message(daysUntilDue: 'soon')), isNull);
    });

    test('it reads in the language of the device, not of the sender', () {
      // The server has no idea what language anyone reads; it sends keys.
      final hr = lookupAppLocalizations(const Locale('hr'));
      final reminder = PushReminder.from(message())!;

      expect(reminder.title(hr), isNot(reminder.title(en)));
    });
  });

  // The server carries the direction because the device cannot work it out: a
  // push is handled in a background isolate with no provider container, so it
  // has no idea which country the household is in and therefore no idea
  // whether 1 April is the start of anything.
  group('a seasonal swap that arrived as a push', () {
    final hr = lookupAppLocalizations(const Locale('hr'));

    test('says which tyres to fit', () {
      final reminder = PushReminder.from(
        message(keys: 'service_tire_swap_seasonal', swapDirection: 'to_winter'),
      );

      expect(reminder!.title(en), en.notificationSwapToWinter);
    });

    test('says the other thing in spring', () {
      final reminder = PushReminder.from(
        message(keys: 'service_tire_swap_seasonal', swapDirection: 'to_summer'),
      );

      expect(reminder!.title(en), en.notificationSwapToSummer);
    });

    test('is translated like everything else', () {
      final reminder = PushReminder.from(
        message(keys: 'service_tire_swap_seasonal', swapDirection: 'to_winter'),
      );

      expect(reminder!.title(hr), hr.notificationSwapToWinter);
    });

    test('without a direction it keeps the generic name', () {
      // An older server, or a country with no verified window.
      final reminder = PushReminder.from(
        message(keys: 'service_tire_swap_seasonal'),
      );

      expect(reminder!.title(en), isNot(en.notificationSwapToWinter));
    });

    test('a direction nobody recognises is ignored, not guessed at', () {
      final reminder = PushReminder.from(
        message(keys: 'service_tire_swap_seasonal', swapDirection: 'sideways'),
      );

      expect(reminder, isNotNull);
      expect(reminder!.title(en), isNot(en.notificationSwapToWinter));
    });

    test('a bundle keeps the visit title', () {
      final reminder = PushReminder.from(
        message(
          keys: 'service_tire_swap_seasonal,service_oil_change',
          swapDirection: 'to_winter',
        ),
      );

      expect(reminder!.title(en), en.notificationBundleTitle(2));
    });
  });
}
