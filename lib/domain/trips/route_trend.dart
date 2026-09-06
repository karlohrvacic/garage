import '../entities/trip_entry.dart';

/// How journeys are grouped along the bottom of a chart.
enum RouteGrouping { month, quarter }

/// A time of day to compare like with like.
///
/// Leaving at seven and leaving at eleven are different drives on the same
/// route, and mixing them makes a trend out of a change in habit. The hours
/// are local and the upper bound is exclusive, matching [summariseRoute].
enum DepartureWindow {
  any(null, null),
  morning(5, 10),
  midday(10, 16),
  evening(16, 22);

  const DepartureWindow(this.from, this.to);

  final int? from;
  final int? to;
}

/// Below this, a bucket is drawn as an indication rather than a measurement.
///
/// Not a statistical threshold — there is no honest one at this sample size —
/// but a line has to be drawn somewhere, and a chart that looks identical at
/// three journeys and three hundred is a chart that misleads.
const int sparseBucketBelow = 5;

class RouteBucket {
  const RouteBucket({
    required this.label,
    required this.median,
    required this.low,
    required this.high,
    required this.count,
  });

  final String label;
  final double median;

  /// The middle half of the journeys, so the spread is visible. A median with
  /// no spread beside it reads as far more certain than it is.
  final double low;
  final double high;

  final int count;

  bool get sparse => count < sparseBucketBelow;
}

/// What the recorded journeys on one route actually say.
///
/// **It reports durations and nothing about their cause.** Journeys got
/// longer is a fact about the records; traffic got worse is a claim about the
/// world, and this cannot tell them apart — the departure time, the route or
/// the driver may simply have changed.
class RouteTrend {
  const RouteTrend({
    required this.buckets,
    required this.sampleCount,
    required this.excluded,
    required this.droppedForNoStartTime,
    this.overallMedian,
    this.overallLow,
    this.overallHigh,
  });

  final List<RouteBucket> buckets;

  /// How many journeys the figures rest on, after every filter.
  final int sampleCount;

  /// Journeys marked "not a normal run". Kept so a chart can draw them apart
  /// rather than hide them.
  final List<TripEntry> excluded;

  /// Journeys that could not answer a departure-window question because they
  /// were typed in afterwards and have no start time. Counted so the screen
  /// can say why the sample shrank.
  final int droppedForNoStartTime;

  final double? overallMedian;
  final double? overallLow;
  final double? overallHigh;

  /// The difference between the first and last bucket's median, or null when
  /// there is only one bucket — a single quarter has nothing to be compared
  /// with, and printing a zero would imply it had been.
  double? get changeInMinutes {
    if (buckets.length < 2) {
      return null;
    }
    return buckets.last.median - buckets.first.median;
  }

  /// Whether either end of that comparison is thin. The number is still worth
  /// showing; it is not worth showing silently.
  bool get restsOnSparseData =>
      buckets.length >= 2 && (buckets.first.sparse || buckets.last.sparse);
}

/// Summarises the journeys recorded on one route.
///
/// Every filter narrows the sample rather than adjusting a figure, and the
/// result reports how many journeys survived, because a median over four
/// journeys and a median over four hundred should not look the same.
RouteTrend summariseRoute(
  List<TripEntry> trips, {
  RouteGrouping grouping = RouteGrouping.quarter,
  bool weekdaysOnly = false,
  int? departureFrom,
  int? departureTo,
  String? driver,
}) {
  final wantsWindow = departureFrom != null || departureTo != null;
  final excluded = <TripEntry>[];
  var droppedForNoStartTime = 0;
  final kept = <TripEntry>[];

  for (final trip in trips) {
    // A journey nobody timed cannot be compared on time. Not an exclusion
    // worth reporting — it was never a candidate.
    if (trip.minutes == null) {
      continue;
    }
    if (!trip.comparable) {
      excluded.add(trip);
      continue;
    }
    if (weekdaysOnly && trip.date.weekday > DateTime.friday) {
      continue;
    }
    if (driver != null && trip.driver != driver) {
      continue;
    }
    if (wantsWindow) {
      final startedAt = trip.startedAt;
      if (startedAt == null) {
        // Typed in afterwards, so it cannot say when it set off. Counting it
        // in a window it might not belong to would invent the answer.
        droppedForNoStartTime++;
        continue;
      }
      final hour = startedAt.toLocal().hour;
      if (departureFrom != null && hour < departureFrom) {
        continue;
      }
      if (departureTo != null && hour >= departureTo) {
        continue;
      }
    }
    kept.add(trip);
  }

  final durations = [for (final trip in kept) trip.minutes!.toDouble()];

  final grouped = <String, List<double>>{};
  for (final trip in kept) {
    grouped
        .putIfAbsent(_label(trip.date, grouping), () => <double>[])
        .add(trip.minutes!.toDouble());
  }
  final labels = grouped.keys.toList()..sort();

  return RouteTrend(
    buckets: [
      for (final label in labels)
        RouteBucket(
          label: label,
          median: _median(grouped[label]!)!,
          low: _quartile(grouped[label]!, 0.25)!,
          high: _quartile(grouped[label]!, 0.75)!,
          count: grouped[label]!.length,
        ),
    ],
    sampleCount: kept.length,
    excluded: excluded,
    droppedForNoStartTime: droppedForNoStartTime,
    overallMedian: _median(durations),
    overallLow: _quartile(durations, 0.25),
    overallHigh: _quartile(durations, 0.75),
  );
}

String _label(DateTime date, RouteGrouping grouping) => switch (grouping) {
  RouteGrouping.month =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}',
  RouteGrouping.quarter => '${date.year} Q${((date.month - 1) ~/ 3) + 1}',
};

/// The middle value, or the mean of the middle pair.
///
/// Median rather than mean throughout: one journey stuck behind a crash moves
/// a mean by minutes and a median not at all, and the question being asked is
/// what the drive usually takes.
double? _median(List<double> values) => _quartile(values, 0.5);

double? _quartile(List<double> values, double fraction) {
  if (values.isEmpty) {
    return null;
  }
  final sorted = [...values]..sort();
  final position = (sorted.length - 1) * fraction;
  final low = position.floor();
  final high = position.ceil();
  if (low == high) {
    return sorted[low];
  }
  // Linear interpolation between the two neighbours, so a four-journey sample
  // reports a spread rather than collapsing to two of its own values.
  return sorted[low] + (sorted[high] - sorted[low]) * (position - low);
}
