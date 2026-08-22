import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/maintenance/providers/maintenance_providers.dart';
import '../../features/maintenance/service_type_labels.dart';
import '../../features/household/providers/household_providers.dart';
import '../../features/vehicles/providers/vehicle_providers.dart';
import '../../domain/maintenance/winter_tyre_period.dart';
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

/// What to call a seasonal tyre swap, or null to keep the generic name.
///
/// "Seasonal tyre swap" says a swap is due and not which way it goes — which
/// is the only part anyone acts on, since the tyres to dig out of the cellar
/// are winter ones in November and summer ones in April. The direction is a
/// property of the calendar rather than of the reminder, so it comes from
/// [swap] and not from the notification.
///
/// Null in three cases, all deliberate: a country with no dated window has no
/// direction to name, another kind of reminder is not a swap, and a **bundle**
/// keeps its own title because renaming a two-item visit after one of its
/// items would hide the other.
String? seasonalSwapTitle(
  AppLocalizations l10n,
  ScheduledReminder reminder,
  SeasonalSwap? swap,
) {
  if (swap == null ||
      reminder.itemCount != 1 ||
      reminder.serviceTypeKeys.first != 'service_tire_swap_seasonal') {
    return null;
  }
  return switch (swap.direction) {
    SwapDirection.toWinter => l10n.notificationSwapToWinter,
    SwapDirection.toSummer => l10n.notificationSwapToSummer,
  };
}

/// Cancels every scheduled reminder and reschedules from current data, so the
/// notification set is always a pure function of what is due — a completed
/// service silently drops its nudge. A no-op on unsupported platforms.
///
/// Two halves, and they answer to different things. The **dated** half is a
/// schedule, so it stands down when the server owns the schedule. The
/// **distance** half is a response to something that just happened on this
/// device — somebody logged a reading — and runs either way: nobody else can
/// know a car reached 59,700 km at the moment it did.
Future<void> syncNotifications(WidgetRef ref, AppLocalizations l10n) async {
  if (!notificationsSupported) {
    return;
  }
  final service = ref.read(notificationServiceProvider);
  await service.initialize();
  await service.requestPermission();

  final today = ref.read(todayProvider);
  final loose = ref.read(householdProjectionsProvider).value ?? const [];
  final vehicles = ref.read(allVehiclesProvider).value ?? const [];
  final names = {for (final vehicle in vehicles) vehicle.id: vehicle.nickname};

  final swap = nextSeasonalSwap(
    countryCode: ref.read(currentHouseholdProvider).value?.countryCode ?? 'HR',
    today: today,
  );

  String titleFor(ScheduledReminder reminder) =>
      seasonalSwapTitle(l10n, reminder, swap) ??
      (reminder.itemCount > 1
          ? l10n.notificationBundleTitle(reminder.itemCount)
          : l10n.notificationDueTitle(
              serviceTypeLabel(l10n, reminder.serviceTypeKeys.first),
            ));

  /// The car and the detail, never the title again. A body repeating its own
  /// title is the shape of a notification nobody wrote on purpose.
  String bodyFor(ScheduledReminder reminder, String when) {
    final name = names[reminder.vehicleId];
    return name == null || name.isEmpty ? when : '$name · $when';
  }

  // When push is on, the server is the only thing that *schedules* reminders.
  //
  // Not because local scheduling stopped working, but because the two cannot
  // be made to agree: the server projects a due date from a fallback driving
  // rate while this device measures the real one, so the same oil change can
  // fall on different days and would arrive as two notifications rather than
  // one. One source, one nudge — and the one that reaches the whole household
  // is the one worth keeping.
  if (!ref.read(pushRemindersActiveProvider)) {
    final bundles = ref.read(bundlesProvider).value ?? const [];
    await service.cancelAll();
    for (final reminder in plan(bundles: bundles, loose: loose, today: today)) {
      await service.schedule(
        id: reminder.id,
        title: titleFor(reminder),
        body: bodyFor(reminder, l10n.notificationDueIn(reminder.leadDays!)),
        when: reminder.when,
      );
    }
  }

  final currentKm = <String, int>{
    for (final vehicle in vehicles)
      if (ref.read(currentOdometerProvider(vehicle.id)).value case final int km)
        vehicle.id: km,
  };
  for (final reminder in planByDistance(
    projections: loose,
    currentKm: currentKm,
    today: today,
  )) {
    final remaining = reminder.remainingKm!;
    await service.show(
      id: reminder.id,
      title: titleFor(reminder),
      body: bodyFor(
        reminder,
        remaining >= 0
            ? l10n.notificationDueInKm(remaining)
            : l10n.notificationOverdueByKm(-remaining),
      ),
      // Every reading recomputes this, so the same item is re-posted as the
      // car closes on it. Alerting once means the notification quietly counts
      // down instead of buzzing at every fill-up.
      onlyAlertOnce: true,
    );
  }
}
