import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over the local-notifications plugin. Keeps plugin types out of
/// the rest of the app so the scheduling logic ([plan]) stays pure and testable.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _channelId = 'maintenance_reminders';
  static const _channelName = 'Maintenance reminders';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    tz.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Android 13+ requires an explicit POST_NOTIFICATIONS grant.
  Future<bool> requestPermission() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    // Never schedule in the past; fire immediately if the moment has passed.
    final now = tz.TZDateTime.now(tz.local);
    final target = scheduled.isBefore(now) ? now : scheduled;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: target,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      // Inexact avoids the exact-alarm permission entirely: a maintenance
      // reminder does not need to fire at a precise second.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
