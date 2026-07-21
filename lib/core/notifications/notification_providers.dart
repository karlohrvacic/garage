import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/maintenance/providers/maintenance_providers.dart';
import '../../features/maintenance/service_type_labels.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

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
