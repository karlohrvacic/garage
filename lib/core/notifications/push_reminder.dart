import 'package:garage/l10n/app_localizations.dart';

import '../../features/maintenance/service_type_labels.dart';
import 'notification_scheduler.dart' as scheduler;

/// A due reminder as it arrives from the server.
///
/// The message is **data-only** on purpose: no `notification` block, so nothing
/// is displayed until this device decides what it says. The server knows which
/// service types are due; it has no idea what language anyone reads, and
/// guessing would mean storing a language per device and keeping it true.
///
/// Nothing here touches a plugin, so what a push turns into is testable
/// without a Firebase project.
class PushReminder {
  const PushReminder({
    required this.vehicleId,
    required this.serviceTypeKeys,
    required this.dueDate,
    required this.daysUntilDue,
    this.vehicleNickname,
  });

  /// The only message type this app sends. Anything else lands in the same
  /// handler and is ignored rather than shown as a maintenance reminder.
  static const String messageType = 'reminder_due';

  final String vehicleId;
  final List<String> serviceTypeKeys;

  /// UTC date-only, like every domain date.
  final DateTime dueDate;

  /// Which of the two nudges this is — the month's notice or the week's. Part
  /// of the notification's identity, so the second does not replace the first,
  /// and part of what it says, so they do not read identically.
  final int daysUntilDue;

  final String? vehicleNickname;

  /// Reads a payload, or returns null when it is not a reminder this build
  /// understands. Half-read is worse than ignored: a notification naming the
  /// wrong work on the wrong day costs more trust than a missing one.
  static PushReminder? from(Map<String, dynamic> data) {
    if (data['type'] != messageType) {
      return null;
    }
    final vehicleId = data['vehicle_id'];
    final keys = data['service_type_keys'];
    if (vehicleId is! String || vehicleId.isEmpty || keys is! String) {
      return null;
    }
    final serviceTypeKeys = [
      for (final key in keys.split(','))
        if (key.trim().isNotEmpty) key.trim(),
    ];
    final dueDate = DateTime.tryParse('${data['due_date']}');
    final daysUntilDue = int.tryParse('${data['days_until_due']}');
    if (serviceTypeKeys.isEmpty || dueDate == null || daysUntilDue == null) {
      return null;
    }
    final nickname = data['vehicle_nickname'];
    return PushReminder(
      vehicleId: vehicleId,
      serviceTypeKeys: serviceTypeKeys,
      dueDate: DateTime.utc(dueDate.year, dueDate.month, dueDate.day),
      daysUntilDue: daysUntilDue,
      vehicleNickname: nickname is String && nickname.isNotEmpty
          ? nickname
          : null,
    );
  }

  /// The same id this device would have used had it scheduled the reminder
  /// itself, so the two can never show up as a pair of identical nudges.
  int get notificationId => scheduler.notificationId(
    vehicleId: vehicleId,
    serviceTypeKeys: serviceTypeKeys,
    dueDate: dueDate,
    leadDays: daysUntilDue,
  );

  String title(AppLocalizations l10n) => serviceTypeKeys.length > 1
      ? l10n.notificationBundleTitle(serviceTypeKeys.length)
      : l10n.notificationDueTitle(
          serviceTypeLabel(l10n, serviceTypeKeys.first),
        );

  /// Which car, and how far off it is.
  ///
  /// The car because a push can reach somebody who did not log the work and
  /// owns more than one; the distance in days because the same visit is
  /// announced twice, a month out and a week out, and two identical
  /// notifications a fortnight apart are worse than one.
  String body(AppLocalizations l10n) {
    final when = l10n.notificationDueIn(daysUntilDue);
    return vehicleNickname == null ? when : '$vehicleNickname · $when';
  }
}
