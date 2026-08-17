import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_scheduler.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/core/notifications/push_receiver.dart';

class RecordingNotifications implements NotificationService {
  final List<({int id, String title, String body})> shown = [];
  var initialized = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool onlyAlertOnce = false,
  }) async {
    shown.add((id: id, title: title, body: body));
  }

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}

Map<String, dynamic> reminderMessage({String keys = 'service_oil_change'}) => {
  'type': 'reminder_due',
  'vehicle_id': 'v1',
  'vehicle_nickname': 'Golf',
  'service_type_keys': keys,
  'due_date': '2026-09-01',
  'days_until_due': '7',
};

void main() {
  test(
    'a reminder push is shown, and only after the plugin is ready',
    () async {
      final notifications = RecordingNotifications();

      await showPushReminder(
        reminderMessage(),
        notifications: notifications,
        locale: const Locale('en'),
      );

      expect(notifications.initialized, isTrue);
      expect(notifications.shown.single.title, 'Oil change is due');
      expect(notifications.shown.single.body, 'Golf · Due in 7 days');
    },
  );

  test('it carries the id the local schedule would have used', () async {
    // Which is what stops a push and a local reminder for the same visit from
    // arriving as two identical notifications.
    final notifications = RecordingNotifications();

    await showPushReminder(
      reminderMessage(),
      notifications: notifications,
      locale: const Locale('en'),
    );

    expect(
      notifications.shown.single.id,
      notificationId(
        vehicleId: 'v1',
        serviceTypeKeys: const ['service_oil_change'],
        dueDate: DateTime.utc(2026, 9, 1),
        leadDays: 7,
      ),
    );
  });

  test('it speaks the language of the device that received it', () async {
    final notifications = RecordingNotifications();

    await showPushReminder(
      reminderMessage(),
      notifications: notifications,
      locale: const Locale('hr'),
    );

    expect(notifications.shown.single.title, isNot(contains('is due')));
  });

  test('a language the app does not have reads as English', () async {
    final notifications = RecordingNotifications();

    await showPushReminder(
      reminderMessage(),
      notifications: notifications,
      locale: const Locale('de'),
    );

    expect(notifications.shown.single.title, 'Oil change is due');
  });

  test('anything that is not a reminder shows nothing at all', () async {
    final notifications = RecordingNotifications();

    await showPushReminder(
      const {'type': 'something_else'},
      notifications: notifications,
      locale: const Locale('en'),
    );

    expect(notifications.shown, isEmpty);
    expect(
      notifications.initialized,
      isFalse,
      reason: 'a message we do not understand should not even wake the plugin',
    );
  });

  test(
    'push being off is a receiver that does nothing rather than a crash',
    () {
      expect(const PushReceiverOff().start(), completes);
    },
  );
}
