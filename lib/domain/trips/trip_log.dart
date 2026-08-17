import '../entities/trip_entry.dart';

/// What a set of trips adds up to.
class TripSummary {
  const TripSummary({
    required this.trips,
    required this.distanceKm,
    required this.minutes,
    required this.businessKm,
    required this.privateKm,
    required this.timedDistanceKm,
  });

  final int trips;
  final double distanceKm;

  /// Total time over the trips that were timed at all.
  final int minutes;

  final double businessKm;
  final double privateKm;

  /// Distance covered by the timed trips only. Kept so the average speed is
  /// taken over the same trips the time came from.
  final double timedDistanceKm;

  /// Average speed across the timed trips, or null when none were timed.
  ///
  /// Deliberately not distance-over-total-time: counting untimed trips as
  /// zero minutes would report a speed far above anything actually driven.
  double? get kmPerHour =>
      minutes <= 0 ? null : timedDistanceKm / (minutes / 60);
}

abstract final class TripLog {
  static TripSummary summarise(Iterable<TripEntry> trips) {
    var count = 0;
    var distance = 0.0;
    var minutes = 0;
    var business = 0.0;
    var private = 0.0;
    var timedDistance = 0.0;

    for (final trip in trips) {
      count++;
      distance += trip.distanceKm;
      switch (trip.purpose) {
        case TripPurpose.business:
          business += trip.distanceKm;
        case TripPurpose.private:
          private += trip.distanceKm;
      }
      final timed = trip.minutes;
      if (timed != null && timed > 0) {
        minutes += timed;
        timedDistance += trip.distanceKm;
      }
    }

    return TripSummary(
      trips: count,
      distanceKm: distance,
      minutes: minutes,
      businessKm: business,
      privateKm: private,
      timedDistanceKm: timedDistance,
    );
  }

  /// The distance an odometer range implies, or null when it implies nothing:
  /// a missing end, or readings that go backwards. Null rather than a negative
  /// number, which would subtract from every total it landed in.
  static double? distanceBetween({required int? start, required int? end}) {
    if (start == null || end == null || end < start) {
      return null;
    }
    return (end - start).toDouble();
  }
}
