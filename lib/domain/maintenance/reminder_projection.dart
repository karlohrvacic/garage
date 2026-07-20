import '../entities/reminder_rule.dart';
import 'date_math.dart';

enum ReminderState { upcoming, due, overdue }

/// A rule resolved against a vehicle's history into a concrete due point.
class ReminderProjection {
  const ReminderProjection({
    required this.ruleId,
    required this.vehicleId,
    required this.serviceTypeKey,
    required this.projectedDueDate,
    required this.state,
    this.dueOdometerKm,
  });

  final String ruleId;
  final String vehicleId;
  final String serviceTypeKey;

  /// The calendar date the item is expected to come due. For distance-based
  /// rules this is derived from the vehicle's recent driving rate, so it moves
  /// as driving habits change.
  final DateTime projectedDueDate;

  /// Set only for rules with a distance interval.
  final int? dueOdometerKm;

  final ReminderState state;
}

/// Projects [ReminderRule]s into dated due points.
abstract final class ReminderProjector {
  /// Assumed daily distance when a vehicle has too little history to measure
  /// one. Deliberately modest so early projections read as further out rather
  /// than nagging on day one.
  static const double fallbackKmPerDay = 30;

  /// How far ahead of the due date an item starts reading as "due".
  static const Duration dueWindow = Duration(days: 14);

  /// Average daily distance from a vehicle's odometer history, usually taken
  /// from its recent fuel entries.
  static double kmPerDay({
    required List<int> odometerReadings,
    required List<DateTime> dates,
  }) {
    if (odometerReadings.length < 2 || dates.length != odometerReadings.length) {
      return fallbackKmPerDay;
    }
    final distance = odometerReadings.last - odometerReadings.first;
    final days = DateMath.daysBetween(dates.first, dates.last);
    if (days <= 0 || distance <= 0) {
      return fallbackKmPerDay;
    }
    return distance / days;
  }

  /// Resolves [rule] into a due point, or null when the rule cannot project
  /// (inactive, or no interval set).
  ///
  /// [baselineDate] and [baselineOdometerKm] stand in for a service that has
  /// never happened — normally the date the vehicle was added and its odometer
  /// at the time — so a brand-new rule still produces a sensible first due
  /// point instead of nothing.
  static ReminderProjection? project({
    required ReminderRule rule,
    required DateTime? lastServiceDate,
    required int? lastServiceOdometerKm,
    required int currentOdometerKm,
    required double kmPerDay,
    required DateTime today,
    DateTime? baselineDate,
    int? baselineOdometerKm,
  }) {
    if (!rule.isProjectable) {
      return null;
    }

    final anchorDate = lastServiceDate ?? baselineDate;
    final anchorOdometer = lastServiceOdometerKm ?? baselineOdometerKm;
    final rate = kmPerDay > 0 ? kmPerDay : fallbackKmPerDay;
    final day = DateMath.dateOnly(today);

    int? dueOdometerKm;
    DateTime? dateFromDistance;
    if (rule.intervalKm != null && anchorOdometer != null) {
      dueOdometerKm = anchorOdometer + rule.intervalKm!;
      final remainingKm = dueOdometerKm - currentOdometerKm;
      // Add whole days by calendar reconstruction rather than a raw Duration:
      // adding a Duration to a local DateTime drifts by an hour across a DST
      // boundary, while rebuilding the date keeps it on calendar midnight.
      final daysOut = (remainingKm / rate).round();
      dateFromDistance = DateTime(day.year, day.month, day.day + daysOut);
    }

    DateTime? dateFromTime;
    if (rule.intervalMonths != null && anchorDate != null) {
      dateFromTime = DateMath.addMonths(anchorDate, rule.intervalMonths!);
    }

    final projected = _earliest(dateFromDistance, dateFromTime);
    if (projected == null) {
      return null;
    }

    return ReminderProjection(
      ruleId: rule.id,
      vehicleId: rule.vehicleId,
      serviceTypeKey: rule.serviceTypeKey,
      projectedDueDate: projected,
      dueOdometerKm: dueOdometerKm,
      state: _state(projected: projected, today: day),
    );
  }

  static DateTime? _earliest(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isBefore(b) ? a : b;
  }

  static ReminderState _state({
    required DateTime projected,
    required DateTime today,
  }) {
    if (projected.isBefore(today)) {
      return ReminderState.overdue;
    }
    // Reconstruct the window edge by calendar days rather than adding a raw
    // Duration: adding a Duration to a local DateTime drifts by an hour across
    // a DST boundary, which would misclassify an item due exactly at the edge.
    final dueThreshold =
        DateTime(today.year, today.month, today.day + dueWindow.inDays);
    if (!projected.isAfter(dueThreshold)) {
      return ReminderState.due;
    }
    return ReminderState.upcoming;
  }
}
