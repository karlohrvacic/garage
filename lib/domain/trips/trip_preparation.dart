import '../entities/vehicle_document.dart';
import '../maintenance/reminder_projection.dart';

/// A dated obligation that falls inside the journey: a registration or an
/// insurance policy that runs out while the car is away.
///
/// Kept apart from [ForecastItem] deliberately. This is a date written on a
/// piece of paper; that is a projection from how the car has lately been
/// driven, and presenting them as one list would give a guess the authority of
/// a deadline.
class TripDeadline {
  const TripDeadline({required this.document, required this.expiresOn});

  final VehicleDocument document;
  final DateTime expiresOn;
}

/// A service the car is expected to reach during the journey.
class ForecastItem {
  const ForecastItem({required this.projection, required this.kmAway});

  final ReminderProjection projection;

  /// How far off it is now. Zero or negative when the car is already past it.
  final int kmAway;
}

/// What a journey runs into, in three groups that must not be merged.
class TripPlan {
  const TripPlan({
    required this.deadlines,
    required this.forecast,
    required this.odometerUnknown,
  });

  /// Dates that are recorded facts.
  final List<TripDeadline> deadlines;

  /// Distances that are predictions from observed driving.
  final List<ForecastItem> forecast;

  /// No current reading, so nothing could be measured against the distance.
  /// Said out loud rather than silently returning an empty forecast, which
  /// would read as "nothing is due".
  final bool odometerUnknown;

  bool get anything => deadlines.isNotEmpty || forecast.isNotEmpty;
}

/// What the garage's own records say falls due over a planned journey.
///
/// **This is not a roadworthiness check and must never be presented as one.**
/// It reports what is already written down: papers with a date on them, and
/// service intervals the car is expected to reach at the distance given. It
/// knows nothing about the tyres, the lights or the brakes, and a checklist
/// that started listing those would imply an inspection nobody carried out.
TripPlan prepareForTrip({
  required DateTime today,
  required DateTime departOn,
  required double distanceKm,
  required int? currentOdometerKm,
  required List<ReminderProjection> projections,
  required List<VehicleDocument> documents,
  DateTime? returnOn,
}) {
  // With no return date the departure day is the horizon: a paper valid when
  // you set off is the least the question is asking.
  final until = returnOn ?? departOn;

  final deadlines = <TripDeadline>[
    for (final document in documents)
      if (document.expiresOn case final expires?)
        // A document with no expiry recorded says nothing either way, and
        // guessing one would be inventing an obligation.
        if (!expires.isAfter(until))
          TripDeadline(document: document, expiresOn: expires),
  ]..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));

  final forecast = <ForecastItem>[];
  if (currentOdometerKm != null) {
    final reach = currentOdometerKm + distanceKm;
    for (final projection in projections) {
      // Only a rule with a distance interval can be measured in kilometres.
      // A purely calendar-based one is answered by the deadline half, or by
      // the planner, and forcing it into this list would need a distance the
      // rule does not have.
      final dueAt = projection.dueOdometerKm;
      if (dueAt == null || dueAt > reach) {
        continue;
      }
      forecast.add(
        ForecastItem(projection: projection, kmAway: dueAt - currentOdometerKm),
      );
    }
    forecast.sort((a, b) => a.kmAway.compareTo(b.kmAway));
  }

  return TripPlan(
    deadlines: deadlines,
    forecast: forecast,
    odometerUnknown: currentOdometerKm == null,
  );
}
