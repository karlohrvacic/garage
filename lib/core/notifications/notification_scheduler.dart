import '../../domain/maintenance/bundling.dart';
import '../../domain/maintenance/date_math.dart';
import '../../domain/maintenance/reminder_projection.dart';

/// One notification to be fired.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.when,
    required this.serviceTypeKeys,
    required this.vehicleId,
  });

  final int id;
  final DateTime when;
  final List<String> serviceTypeKeys;
  final String vehicleId;

  int get itemCount => serviceTypeKeys.length;
}

/// How far ahead of the due date a reminder fires — enough notice to book a
/// shop visit, not so much that it is forgotten again by the time it matters.
const Duration notificationLeadTime = Duration(days: 7);

/// What makes two notifications the same notification.
///
/// Derived from the reminder itself — which car, which work, due when — rather
/// than from the order things happened to be planned in. Two consequences,
/// both wanted: a resync replaces the notification it already showed instead
/// of numbering a new one, and a reminder that arrives as a push lands on the
/// same id the device would have used itself, so the two can never stack up as
/// a pair of identical nudges.
///
/// FNV-1a, masked to 31 bits: the notification plugin takes a 32-bit signed
/// int, and `Object.hash` is neither stable across runs nor bounded.
int notificationId({
  required String vehicleId,
  required Iterable<String> serviceTypeKeys,
  required DateTime dueDate,
}) {
  final keys = [...serviceTypeKeys]..sort();
  final day = DateMath.dateOnly(dueDate);
  final identity =
      '$vehicleId|${keys.join(',')}|'
      '${day.year}-${day.month}-${day.day}';

  var hash = 0x811c9dc5;
  for (final unit in identity.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}

/// Turns due items into notifications.
///
/// A bundle becomes a single notification rather than one per item: the whole
/// point of bundling is to replace several scattered nudges with one, and
/// firing both would undo it.
List<ScheduledReminder> plan({
  required List<MaintenanceBundle> bundles,
  required List<ReminderProjection> loose,
  required DateTime today,
}) {
  final day = DateMath.dateOnly(today);
  final planned = <ScheduledReminder>[];
  final bundledRuleIds = <String>{};

  DateTime fireDate(DateTime dueDate) {
    // Calendar subtraction, not Duration subtraction: a lead window crossing
    // the spring-forward DST change would otherwise land at 23:00 a day early.
    final target = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day - notificationLeadTime.inDays,
    );
    return target.isBefore(day) ? day : target;
  }

  for (final bundle in bundles) {
    for (final item in bundle.items) {
      bundledRuleIds.add(item.projection.ruleId);
    }
    final keys = bundle.items
        .map((item) => item.projection.serviceTypeKey)
        .toList(growable: false);
    final vehicleId = bundle.items.first.projection.vehicleId;
    planned.add(
      ScheduledReminder(
        id: notificationId(
          vehicleId: vehicleId,
          serviceTypeKeys: keys,
          dueDate: bundle.visitDate,
        ),
        when: fireDate(bundle.visitDate),
        serviceTypeKeys: keys,
        vehicleId: vehicleId,
      ),
    );
  }

  for (final projection in loose) {
    if (bundledRuleIds.contains(projection.ruleId)) {
      continue;
    }
    final dueDate = DateMath.dateOnly(projection.projectedDueDate);
    planned.add(
      ScheduledReminder(
        id: notificationId(
          vehicleId: projection.vehicleId,
          serviceTypeKeys: [projection.serviceTypeKey],
          dueDate: dueDate,
        ),
        when: fireDate(dueDate),
        serviceTypeKeys: [projection.serviceTypeKey],
        vehicleId: projection.vehicleId,
      ),
    );
  }

  return planned;
}
