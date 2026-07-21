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
  var id = 0;

  DateTime fireDate(DateTime dueDate) {
    final target = dueDate.subtract(notificationLeadTime);
    return target.isBefore(day) ? day : target;
  }

  for (final bundle in bundles) {
    for (final item in bundle.items) {
      bundledRuleIds.add(item.projection.ruleId);
    }
    planned.add(
      ScheduledReminder(
        id: id++,
        when: fireDate(bundle.visitDate),
        serviceTypeKeys: bundle.items
            .map((item) => item.projection.serviceTypeKey)
            .toList(growable: false),
        vehicleId: bundle.items.first.projection.vehicleId,
      ),
    );
  }

  for (final projection in loose) {
    if (bundledRuleIds.contains(projection.ruleId)) {
      continue;
    }
    planned.add(
      ScheduledReminder(
        id: id++,
        when: fireDate(DateMath.dateOnly(projection.projectedDueDate)),
        serviceTypeKeys: [projection.serviceTypeKey],
        vehicleId: projection.vehicleId,
      ),
    );
  }

  return planned;
}
