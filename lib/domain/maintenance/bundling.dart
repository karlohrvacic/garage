import 'date_math.dart';
import 'reminder_projection.dart';

/// How close two maintenance items must fall to be worth doing in one visit.
class BundlingWindow {
  const BundlingWindow({required this.proximity, required this.proximityKm});

  final Duration proximity;
  final int proximityKm;

  static const BundlingWindow defaults = BundlingWindow(
    proximity: Duration(days: 21),
    proximityKm: 500,
  );
}

/// A projection paired with the date used for grouping, which differs from the
/// projected date for overdue items.
class BundleItem {
  const BundleItem({required this.projection, required this.effectiveDate});

  final ReminderProjection projection;
  final DateTime effectiveDate;
}

/// Two or more items worth doing in a single shop visit.
class MaintenanceBundle {
  MaintenanceBundle(List<BundleItem> items)
      : items = List.unmodifiable(
          [...items]..sort((a, b) {
            final byDate = a.effectiveDate.compareTo(b.effectiveDate);
            if (byDate != 0) {
              return byDate;
            }
            // Tie-break on ruleId so items sharing an effective date come out
            // in a deterministic order rather than one that depends on the
            // caller's input ordering.
            return a.projection.ruleId.compareTo(b.projection.ruleId);
          }),
        );

  final List<BundleItem> items;

  /// The earliest deadline in the group. Anchoring here rather than at the
  /// latest date guarantees no item — least of all a statutory one — is
  /// scheduled past its own deadline.
  DateTime get visitDate => items.first.effectiveDate;

  /// How far apart the first and last items in the group fall.
  Duration get span =>
      items.last.effectiveDate.difference(items.first.effectiveDate);

  /// Drops one item and recomputes, so the displayed date and span never quote
  /// stale figures. Returns null when fewer than two items would remain, since
  /// a single item is not a bundle.
  MaintenanceBundle? exclude(String ruleId) {
    final remaining = items
        .where((item) => item.projection.ruleId != ruleId)
        .toList(growable: false);
    if (remaining.length < 2) {
      return null;
    }
    return MaintenanceBundle(remaining);
  }
}

/// Clusters maintenance items that fall due near each other in time or
/// distance, so they can be done in one shop visit instead of several.
abstract final class BundlingEngine {
  static List<MaintenanceBundle> bundle({
    required List<ReminderProjection> projections,
    required DateTime today,
    BundlingWindow window = BundlingWindow.defaults,
  }) {
    final day = DateMath.dateOnly(today);

    // Overdue items are clamped to today. Their original date is in the past,
    // which would otherwise push them out of range of everything upcoming and
    // defeat the whole point: a late oil change should absolutely be bundled
    // with the plugs due in three weeks.
    final items = projections
        .map(
          (projection) => BundleItem(
            projection: projection,
            effectiveDate: projection.projectedDueDate.isBefore(day)
                ? day
                : DateMath.dateOnly(projection.projectedDueDate),
          ),
        )
        .toList()
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    final bundles = <MaintenanceBundle>[];
    var group = <BundleItem>[];

    for (final item in items) {
      if (group.isEmpty) {
        group = [item];
        continue;
      }
      // Measured against the group's anchor, not its previous member, so a
      // chain of near-neighbours cannot stretch a group beyond the window.
      if (_withinWindow(group.first, item, window)) {
        group.add(item);
        continue;
      }
      _flush(group, bundles);
      group = [item];
    }
    _flush(group, bundles);

    return bundles;
  }

  static bool _withinWindow(
    BundleItem anchor,
    BundleItem candidate,
    BundlingWindow window,
  ) {
    final dayGap = DateMath.daysBetween(
      anchor.effectiveDate,
      candidate.effectiveDate,
    ).abs();
    if (dayGap <= window.proximity.inDays) {
      return true;
    }

    final anchorKm = anchor.projection.dueOdometerKm;
    final candidateKm = candidate.projection.dueOdometerKm;
    if (anchorKm == null || candidateKm == null) {
      return false;
    }
    return (candidateKm - anchorKm).abs() <= window.proximityKm;
  }

  static void _flush(List<BundleItem> group, List<MaintenanceBundle> into) {
    if (group.length >= 2) {
      into.add(MaintenanceBundle(group));
    }
  }
}
