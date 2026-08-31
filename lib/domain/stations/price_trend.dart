/// One day's national average price for one coarse fuel type.
///
/// Lives in the domain rather than beside the repository that parses it, for
/// the same reason `RankedStation` moved: the arithmetic below is the
/// interesting part and it has no business importing a feature package.
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.fuelTypeId,
    required this.avgPrice,
  });

  /// UTC, day-of-month precision — the feed publishes a date, not a time.
  final DateTime date;

  /// MZOE `tip_goriva` id: 1 petrol, 2 diesel, 3 LPG.
  final int fuelTypeId;

  final double avgPrice;
}

/// Which way prices have moved, over the window [PriceTrend.change] compared.
class PriceChange {
  const PriceChange({required this.before, required this.after});

  final double before;
  final double after;

  double get delta => after - before;
  double get percent => before == 0 ? 0 : delta / before;

  /// Below this, the difference between two weeks is the feed's own sampling
  /// wobble rather than the market. Two cents is noise wearing a direction's
  /// clothes.
  static const double noiseFloor = 0.02;

  bool get steady => delta.abs() < noiseFloor;
  bool get rising => !steady && delta > 0;
}

abstract final class PriceTrend {
  /// How many days each figure is taken over.
  ///
  /// Seven, and not adjustable in practice: the feed's coverage varies by
  /// weekday — Thursdays carry one to three fuel types where Mondays carry
  /// five or six — so any window that is not a whole number of weeks samples
  /// some weekdays more than others and inherits that bias. A whole week
  /// contains each weekday exactly once, on both sides of a comparison.
  static const int defaultWindowDays = 7;

  /// The fewest readings a window may hold and still stand for a week. Two
  /// days standing in for a week is how a public holiday becomes a price
  /// movement.
  static const int minimumReadings = 3;

  /// One fuel's series, oldest first, one reading per day.
  ///
  /// The feed interleaves every fuel type in whatever order it likes, and
  /// nothing downstream should inherit an assumption about that order.
  static List<TrendPoint> forFuel(List<TrendPoint> points, int fuelTypeId) {
    final byDay = <DateTime, TrendPoint>{};
    for (final point in points) {
      if (point.fuelTypeId == fuelTypeId) {
        byDay[point.date] = point;
      }
    }
    return byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Each day replaced by the trailing **median** of the [windowDays] up to it.
  ///
  /// Drawn raw, this series is misleading: single days swing by tens of cents
  /// depending on how many stations reported, so a chart of it shows spikes
  /// that never happened. They come in pairs — 1.88 to 2.20 on a Thursday and
  /// back to 1.89 on the Friday — which is the shape of a thin sample, not of
  /// a price.
  ///
  /// Median rather than mean, because a mean only dilutes such a day: a 30
  /// cent spike inside a seven day window still shifts the average by four,
  /// which is more than [PriceChange.noiseFloor] and would be reported as a
  /// movement. A median discards it outright.
  static List<TrendPoint> smoothed(
    List<TrendPoint> series, {
    int windowDays = defaultWindowDays,
  }) {
    return [
      for (final point in series)
        TrendPoint(
          date: point.date,
          fuelTypeId: point.fuelTypeId,
          avgPrice: _median(
            _within(series, until: point.date, days: windowDays),
          )!,
        ),
    ];
  }

  /// The last [windowDays] against the [windowDays] before them, or null when
  /// either side is too thin to stand for a week.
  ///
  /// Deliberately not the difference between two individual days: the noise in
  /// this feed is larger than a week's real movement, so two points would
  /// mostly report their own sampling error.
  static PriceChange? change(
    List<TrendPoint> series, {
    int windowDays = defaultWindowDays,
    DateTime? asOf,
  }) {
    if (series.isEmpty) {
      return null;
    }
    final end = asOf ?? series.last.date;
    final midpoint = end.subtract(Duration(days: windowDays));

    final recent = _within(series, until: end, days: windowDays);
    final previous = _within(series, until: midpoint, days: windowDays);
    if (recent.length < minimumReadings || previous.length < minimumReadings) {
      return null;
    }
    return PriceChange(before: _median(previous)!, after: _median(recent)!);
  }

  /// The readings falling in the [days]-long window ending at [until].
  ///
  /// A window of days rather than of readings, so a gap in the feed shortens
  /// the sample instead of quietly reaching further back in time for one.
  static List<TrendPoint> _within(
    List<TrendPoint> series, {
    required DateTime until,
    required int days,
  }) {
    final from = until.subtract(Duration(days: days - 1));
    return [
      for (final point in series)
        if (!point.date.isBefore(from) && !point.date.isAfter(until)) point,
    ];
  }

  static double? _median(List<TrendPoint> points) {
    if (points.isEmpty) {
      return null;
    }
    final prices = [for (final point in points) point.avgPrice]..sort();
    final middle = prices.length ~/ 2;
    return prices.length.isOdd
        ? prices[middle]
        : (prices[middle - 1] + prices[middle]) / 2;
  }
}
