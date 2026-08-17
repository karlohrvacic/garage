import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../config/push_config.dart';
import '../errors/app_failure.dart';
import '../errors/failure_log.dart';
import 'notification_service.dart';
import 'push_reminder.dart';

/// Listens for reminder pushes and puts them on screen.
///
/// A seam like [PushRegistration]: the messaging plugin needs a platform
/// channel and a live Firebase project, so the app asks for this rather than
/// calling the plugin, and tests substitute a recorder.
abstract interface class PushReceiver {
  /// Starts listening. Safe to call more than once.
  Future<void> start();
}

/// What a build without Firebase configured gets. Push is off, so there is
/// nothing to listen for.
class PushReceiverOff implements PushReceiver {
  const PushReceiverOff();

  @override
  Future<void> start() async {}
}

class FirebasePushReceiver implements PushReceiver {
  const FirebasePushReceiver();

  @override
  Future<void> start() async {
    try {
      await ensureFirebase();
      // Two paths, because Android delivers a data-only message to a
      // background isolate when the app is not in front and to the stream
      // when it is. Registering only one of them means reminders that appear
      // exactly when the person is already looking at the app, or only when
      // they are not.
      FirebaseMessaging.onBackgroundMessage(garageBackgroundMessage);
      FirebaseMessaging.onMessage.listen((message) {
        showPushReminder(message.data);
      });
    } on Object catch (error) {
      // Never fatal: a device that cannot listen for pushes still has its own
      // local schedule, and a crash at startup would be a far worse trade.
      reportFailure(AppFailure.from(error));
    }
  }
}

/// Brings Firebase up with the dart-defined options, once per isolate.
///
/// The background isolate is a *fresh* one — nothing the app did at startup
/// has happened there — so this runs again inside the handler rather than
/// being assumed.
Future<void> ensureFirebase() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: PushConfig.apiKey,
      appId: PushConfig.appId,
      messagingSenderId: PushConfig.messagingSenderId,
      projectId: PushConfig.projectId,
    ),
  );
}

/// Entry point for a push that arrives while the app is not in front.
///
/// Top-level and `vm:entry-point` because Android calls it in an isolate of
/// its own; a closure or a method would not survive the tree-shaker.
@pragma('vm:entry-point')
Future<void> garageBackgroundMessage(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFirebase();
  await showPushReminder(message.data);
}

/// Turns a payload into a notification, in the language of this device.
///
/// The message carries service-type *keys*, not sentences: the server has no
/// idea what anyone reads, and a language stored per device is one more thing
/// that can be stale. [locale] and [notifications] exist so this is testable
/// without a platform channel.
Future<void> showPushReminder(
  Map<String, dynamic> data, {
  NotificationService? notifications,
  Locale? locale,
}) async {
  final reminder = PushReminder.from(data);
  if (reminder == null) {
    return;
  }
  final l10n = lookupAppLocalizations(
    _supported(locale ?? PlatformDispatcher.instance.locale),
  );
  final service = notifications ?? NotificationService();
  await service.initialize();
  await service.show(
    id: reminder.notificationId,
    title: reminder.title(l10n),
    body: reminder.body(l10n),
  );
}

/// The closest locale the app actually has strings for. Reading a reminder in
/// English is better than not being shown one.
Locale _supported(Locale locale) {
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == locale.languageCode) {
      return Locale(supported.languageCode);
    }
  }
  return const Locale('en');
}

final pushReceiverProvider = Provider<PushReceiver>((ref) {
  return PushConfig.isConfigured
      ? const FirebasePushReceiver()
      : const PushReceiverOff();
});
