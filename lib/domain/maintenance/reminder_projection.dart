import '../entities/reminder_rule.dart';
import 'date_math.dart';
import 'winter_tyre_period.dart';

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
    this.fractionConsumed,
    this.dateFromDistance,
    this.dateFromTime,
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

  /// When this car reaches the due odometer at the rate it is being driven,
  /// and when the calendar interval runs out. [projectedDueDate] is the
  /// earlier of the two; both are kept because the loser is the more
  /// interesting half of the answer.
  ///
  /// A rule reading "every 30,000 km or 24 months" has two deadlines, and
  /// which one binds is the thing a driver plans around. Collapsing them to
  /// one date and discarding the other left a row that could not say "the
  /// calendar says 2028, but you will be there in autumn 2027" — the very
  /// prediction the odometer history exists to make.
  final DateTime? dateFromDistance;
  final DateTime? dateFromTime;

  /// How much of the interval is already used up, 0…1. When a rule has both a
  /// distance and a time interval this is the more-consumed of the two — the
  /// dimension that will come due first. Null when no anchor exists to
  /// measure from.
  final double? fractionConsumed;

  final ReminderState state;

  /// Whether [projectedDueDate] is a **prediction** rather than a deadline.
  ///
  /// A distance-based date is remaining kilometres divided by how fast this
  /// car is actually being driven, so it moves every time somebody logs a
  /// reading — it is a forecast, and a good one, but not a date anybody
  /// promised. A month interval and a one-off's own date are deadlines: they
  /// are what they say.
  ///
  /// The row used to state both the same way ("Due 12 Jun 2027"), which
  /// quietly presented an extrapolation as a fact. Two deadlines landing on
  /// the same day read as the deadline: nothing is gained by hedging a date
  /// the calendar also guarantees.
  bool get isPredicted {
    final byDistance = dateFromDistance;
    if (byDistance == null) {
      return false;
    }
    final byTime = dateFromTime;
    return byTime == null || byDistance.isBefore(byTime);
  }

  /// How close this item is to being due, 0 to 1. Zero is freshly done, one is
  /// due now or overdue.
  ///
  /// One meaning for every surface that shows a proportion. The dashboard used
  /// to show *time remaining* over a 90-day horizon while the maintenance list
  /// showed *interval consumed*, so the same tyre swap read as 100% in one
  /// place and 26% in the other, and a full arc meant "nothing to do" on one
  /// screen and "due now" on the other.
  ///
  /// [fractionConsumed] is the honest measure and is used whenever a rule has
  /// an interval to measure against. A one-off with only a date has no
  /// interval, so its closeness is taken over a 90-day approach instead, in
  /// the same direction: far away is near zero, today is one.
  double dueness(DateTime today) {
    final consumed = fractionConsumed;
    if (consumed != null) {
      return consumed.clamp(0.0, 1.0).toDouble();
    }
    final daysRemaining = DateMath.daysBetween(today, projectedDueDate);
    if (daysRemaining <= 0) {
      return 1;
    }
    return (1 - daysRemaining / _approachDays).clamp(0.0, 1.0).toDouble();
  }
}

/// The horizon over which a dateless item ramps up to due. Three months, so
/// the projector's own 14-day notice window lands in the gauge's last sixth
/// rather than looking relaxed until the morning it expires.
const int _approachDays = 90;

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
    if (odometerReadings.length < 2 ||
        dates.length != odometerReadings.length) {
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

    if (rule.oneTime) {
      return _projectOneTime(
        rule: rule,
        currentOdometerKm: currentOdometerKm,
        anchorDate: anchorDate,
        anchorOdometer: anchorOdometer,
        rate: rate,
        day: day,
      );
    }

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

    double? fraction;
    if (rule.intervalKm != null && anchorOdometer != null) {
      fraction = (currentOdometerKm - anchorOdometer) / rule.intervalKm!;
    }
    if (dateFromTime != null && anchorDate != null) {
      final totalDays = DateMath.daysBetween(anchorDate, dateFromTime);
      if (totalDays > 0) {
        final timeFraction = DateMath.daysBetween(anchorDate, day) / totalDays;
        fraction = fraction == null || timeFraction > fraction
            ? timeFraction
            : fraction;
      }
    }

    return ReminderProjection(
      ruleId: rule.id,
      vehicleId: rule.vehicleId,
      serviceTypeKey: rule.serviceTypeKey,
      projectedDueDate: projected,
      dueOdometerKm: dueOdometerKm,
      fractionConsumed: fraction?.clamp(0.0, 1.0).toDouble(),
      dateFromDistance: dateFromDistance,
      dateFromTime: dateFromTime,
      state: _state(projected: projected, today: day),
    );
  }

  /// Re-dates a seasonal tyre swap onto its country's statutory date.
  ///
  /// The swap ships as a six-month interval, which anchors on whenever the
  /// last one was logged and drifts from there: a swap done in late June puts
  /// the next one just before Christmas, a date nothing in the world happens
  /// on. The window is national and fixed, so the honest projection is the
  /// statutory date and not an interval measured from a habit.
  ///
  /// The result reads as a **dated** item rather than an interval one — no
  /// fraction, no due odometer. A fixed calendar date is not "half consumed"
  /// in January in any sense a reader would recognise, and [dueness] already
  /// has the right behaviour for dated items: a 90-day approach.
  static ReminderProjection pinToSeasonalSwap({
    required ReminderProjection projection,
    required SeasonalSwap swap,
    required DateTime today,
  }) {
    final day = DateMath.dateOnly(today);
    return ReminderProjection(
      ruleId: projection.ruleId,
      vehicleId: projection.vehicleId,
      serviceTypeKey: projection.serviceTypeKey,
      projectedDueDate: swap.date,
      dateFromTime: swap.date,
      state: _state(projected: swap.date, today: day),
    );
  }

  /// A one-time rule has its target fixed: the due date is taken as-is, and a
  /// due odometer extrapolates to a date through the driving rate. When both
  /// are set the earlier wins, like the recurring dimensions.
  static ReminderProjection? _projectOneTime({
    required ReminderRule rule,
    required int currentOdometerKm,
    required DateTime? anchorDate,
    required int? anchorOdometer,
    required double rate,
    required DateTime day,
  }) {
    DateTime? dateFromDistance;
    if (rule.dueOdometerKm != null) {
      final remainingKm = rule.dueOdometerKm! - currentOdometerKm;
      final daysOut = (remainingKm / rate).round();
      dateFromDistance = DateTime(day.year, day.month, day.day + daysOut);
    }
    final projected = _earliest(dateFromDistance, rule.dueDate);
    if (projected == null) {
      return null;
    }

    double? fraction;
    if (rule.dueOdometerKm != null &&
        anchorOdometer != null &&
        rule.dueOdometerKm! > anchorOdometer) {
      fraction =
          (currentOdometerKm - anchorOdometer) /
          (rule.dueOdometerKm! - anchorOdometer);
    }
    if (rule.dueDate != null && anchorDate != null) {
      final totalDays = DateMath.daysBetween(anchorDate, rule.dueDate!);
      if (totalDays > 0) {
        final timeFraction = DateMath.daysBetween(anchorDate, day) / totalDays;
        fraction = fraction == null || timeFraction > fraction
            ? timeFraction
            : fraction;
      }
    }

    return ReminderProjection(
      ruleId: rule.id,
      vehicleId: rule.vehicleId,
      serviceTypeKey: rule.serviceTypeKey,
      projectedDueDate: projected,
      dueOdometerKm: rule.dueOdometerKm,
      // A one-off's fixed date is its time dimension, and its odometer target
      // extrapolates just as a recurring interval does.
      dateFromDistance: dateFromDistance,
      dateFromTime: rule.dueDate,
      fractionConsumed: fraction?.clamp(0.0, 1.0).toDouble(),
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
    final dueThreshold = DateTime(
      today.year,
      today.month,
      today.day + dueWindow.inDays,
    );
    if (!projected.isAfter(dueThreshold)) {
      return ReminderState.due;
    }
    return ReminderState.upcoming;
  }
}
