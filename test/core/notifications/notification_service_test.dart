import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The plugin as far as the service uses it, refusing a scheduled date in the
/// past as `flutter_local_notifications` does ("Must be a date in the
/// future"), which is the check the service's clamp to "now" lost to.
class _Plugin implements FlutterLocalNotificationsPlugin {
  final scheduled = <tz.TZDateTime>[];
  final shown = <int>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #zonedSchedule:
        final date = invocation.namedArguments[#scheduledDate] as tz.TZDateTime;
        if (date.isBefore(DateTime.now())) {
          throw ArgumentError.value(
            date,
            'scheduledDate',
            'Must be a date in the future',
          );
        }
        scheduled.add(date);
      case #show:
        shown.add(invocation.namedArguments[#id] as int);
    }
    return Future<void>.value();
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);

  test('a moment already gone is shown, not handed to the scheduler', () async {
    final plugin = _Plugin();

    await NotificationService(plugin).schedule(
      id: 1,
      title: 'Oil change',
      body: 'Golf · in 7 days',
      when: DateTime.now().subtract(const Duration(hours: 1)),
    );

    expect(plugin.shown, [1]);
    expect(plugin.scheduled, isEmpty);
  });

  test(
    'and so is one set for this instant, past by the time it is checked',
    () async {
      final plugin = _Plugin();

      await NotificationService(plugin).schedule(
        id: 2,
        title: 'Oil change',
        body: 'Golf · in 7 days',
        when: DateTime.now(),
      );

      expect(plugin.shown, [2]);
    },
  );

  test('a moment ahead is scheduled', () async {
    final plugin = _Plugin();

    await NotificationService(plugin).schedule(
      id: 3,
      title: 'Oil change',
      body: 'Golf · in 7 days',
      when: DateTime.now().add(const Duration(hours: 1)),
    );

    expect(plugin.scheduled, hasLength(1));
    expect(plugin.shown, isEmpty);
  });
}
