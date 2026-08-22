import '../entities/tyre_set.dart';
import 'date_math.dart';
import 'reminder_projection.dart';

/// How much life a tyre set has left, estimated from how it has actually
/// worn — never a reminder, only a number to look at.
///
/// A vignette or a service has a deadline someone can be nagged about; tread
/// wear has no such date, only a rate, and a household that has never
/// measured it twice has given the app nothing to measure a rate from. This
/// is deliberately passive: nothing pushes it, nothing marks it overdue.
class TyreWearProjection {
  const TyreWearProjection({
    required this.remainingKm,
    required this.projectedReplacementDate,
    required this.wearRatePerKm,
  });

  /// Kilometres left before the shallowest corner reaches
  /// [TyreSet.legalMinimumMm], clamped at zero rather than going negative for
  /// a set already at or under it.
  final int remainingKm;

  /// When [remainingKm] is expected to pass, at the vehicle's own driving
  /// rate — a forecast, not a deadline, exactly like a distance-based
  /// maintenance projection.
  final DateTime projectedReplacementDate;

  /// Millimetres of tread lost per kilometre, always positive: a
  /// [TyreWearProjection] never exists without measurable wear behind it.
  final double wearRatePerKm;
}

/// Projects [TyreSet]s into an estimated remaining life.
abstract final class TyreWearProjector {
  /// Estimates [set]'s remaining life from its own measured wear, or null
  /// when there is not enough to measure one from.
  ///
  /// Needs two dated readings with both a tread depth and an odometer: a
  /// single reading says what a set looked like once, not how fast it is
  /// wearing, and guessing a "new tyre" starting depth would invent an
  /// assumption nobody typed in. The earliest and latest such readings are
  /// used regardless of list order, the way [TyreSet.readings] is not
  /// guaranteed to be sorted.
  static TyreWearProjection? project({
    required TyreSet set,
    required DateTime today,
    required double kmPerDay,
  }) {
    final measured = [
      for (final reading in set.readings)
        if (reading.odometerKm != null && reading.shallowestMm != null) reading,
    ]..sort((a, b) => a.odometerKm!.compareTo(b.odometerKm!));
    if (measured.length < 2) {
      return null;
    }

    final earliest = measured.first;
    final latest = measured.last;
    final kmSpan = latest.odometerKm! - earliest.odometerKm!;
    final wornMm = earliest.shallowestMm! - latest.shallowestMm!;
    if (kmSpan <= 0 || wornMm <= 0) {
      return null;
    }

    final wearRatePerKm = wornMm / kmSpan;
    final remainingMm = (latest.shallowestMm! - TyreSet.legalMinimumMm).clamp(
      0.0,
      double.infinity,
    );
    final remainingKm = (remainingMm / wearRatePerKm).round();

    final rate = kmPerDay > 0 ? kmPerDay : ReminderProjector.fallbackKmPerDay;
    final daysOut = (remainingKm / rate).round();
    final day = DateMath.dateOnly(today);

    return TyreWearProjection(
      remainingKm: remainingKm,
      projectedReplacementDate: DateTime(
        day.year,
        day.month,
        day.day + daysOut,
      ),
      wearRatePerKm: wearRatePerKm,
    );
  }
}
