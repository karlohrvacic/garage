import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/maintenance/providers/maintenance_providers.dart';
import '../../features/maintenance/service_type_labels.dart';
import '../config/push_config.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Whether reminders come from the server rather than from this device.
///
/// A build with Firebase configured gets its reminders pushed, and the push
/// reaches **everyone in the household** — which is the entire reason push
/// exists, since a local schedule lives on the phone that made it and cannot.
///
/// A provider rather than a bare constant so a test can say which world it is
/// in; the value itself is a compile-time dart-define.
final pushRemindersActiveProvider = Provider<bool>(
  (ref) => PushConfig.isConfigured,
);

/// True only where local notifications are supported. On web and desktop the
/// plugin is a no-op, so the app skips scheduling entirely rather than risk a
/// platform exception.
bool get notificationsSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Cancels every scheduled reminder and reschedules from current data, so the
/// notification set is always a pure function of what is due — a completed
/// service silently drops its nudge. A no-op on unsupported platforms.
Future<void> syncNotifications(WidgetRef ref, AppLocalizations l10n) async {
  if (!notificationsSupported) {
    return;
  }
  // When push is on, the server is the only thing that schedules reminders.
  //
  // Not because local scheduling stopped working, but because the two cannot
  // be made to agree: the server projects a due date from a fallback driving
  // rate while this device measures the real one, so the same oil change can
  // fall on different days and would arrive as two notifications rather than
  // one. One source, one nudge — and the one that reaches the whole household
  // is the one worth keeping.
  if (ref.read(pushRemindersActiveProvider)) {
    return;
  }
  final bundles = ref.read(bundlesProvider).value ?? const [];
  final loose = ref.read(householdProjectionsProvider).value ?? const [];
  final today = ref.read(todayProvider);

  final reminders = plan(bundles: bundles, loose: loose, today: today);
  final service = ref.read(notificationServiceProvider);

  await service.initialize();
  await service.requestPermission();
  await service.cancelAll();
  for (final reminder in reminders) {
    final title = reminder.itemCount > 1
        ? l10n.notificationBundleTitle(reminder.itemCount)
        : l10n.notificationDueTitle(
            serviceTypeLabel(l10n, reminder.serviceTypeKeys.first),
          );
    final body = reminder.itemCount > 1 ? l10n.notificationBundleBody : title;
    await service.schedule(
      id: reminder.id,
      title: title,
      body: body,
      when: reminder.when,
    );
  }
}
