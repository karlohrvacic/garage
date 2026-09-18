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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    final scheduled = tz.TZDateTime.from(when, tz.local);
    // A moment already gone, or about to be, is shown now. The plugin refuses
    // a date in the past, and this used to clamp one to "now", which is in
    // the past again by the time the plugin checks it: every overdue nudge
    // threw.
    final soon = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 1));
    if (!scheduled.isAfter(soon)) {
      return show(id: id, title: title, body: body);
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
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

  /// Shows a notification now, rather than scheduling one.
  ///
  /// What a push turns into: the server decided the moment, so there is
  /// nothing left to schedule. The id is the reminder's own
  /// ([notificationId]), so a second delivery of the same reminder replaces
  /// the first instead of stacking.
  Future<void> show({
    required int id,
    required String title,
    required String body,
    bool onlyAlertOnce = false,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          onlyAlertOnce: onlyAlertOnce,
        ),
      ),
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
