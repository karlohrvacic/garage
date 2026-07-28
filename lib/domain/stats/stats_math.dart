/// Pure aggregation helpers for the Stats screen. All dates are UTC, matching
/// the domain-layer convention.
class YearMonthComparison {
  const YearMonthComparison({
    required this.thisYear,
    required this.previousYear,
    required this.thisMonth,
    required this.previousMonth,
  });

  final double thisYear;
  final double previousYear;
  final double thisMonth;
  final double previousMonth;
}

abstract final class StatsMath {
  /// Sums [value] over items falling in this/previous year and month relative
  /// to [today]. "Previous month" is the calendar month before [today]'s, with
  /// January rolling back into December of the prior year.
  static YearMonthComparison compare<T>({
    required Iterable<T> items,
    required DateTime Function(T) date,
    required double Function(T) value,
    required DateTime today,
  }) {
    var thisYear = 0.0;
    var previousYear = 0.0;
    var thisMonth = 0.0;
    var previousMonth = 0.0;
    final prevMonthAnchor = DateTime.utc(today.year, today.month - 1);

    for (final item in items) {
      final d = date(item);
      final v = value(item);
      if (d.year == today.year) {
        thisYear += v;
      } else if (d.year == today.year - 1) {
        previousYear += v;
      }
      if (d.year == today.year && d.month == today.month) {
        thisMonth += v;
      } else if (d.year == prevMonthAnchor.year &&
          d.month == prevMonthAnchor.month) {
        previousMonth += v;
      }
    }
    return YearMonthComparison(
      thisYear: thisYear,
      previousYear: previousYear,
      thisMonth: thisMonth,
      previousMonth: previousMonth,
    );
  }

  /// Distance covered by a set of odometer readings: the span between the
  /// lowest and highest. Below two readings there is no span to measure.
  static double? distanceCovered(Iterable<int> odometerReadings) {
    int? min;
    int? max;
    for (final reading in odometerReadings) {
      if (min == null || reading < min) {
        min = reading;
      }
      if (max == null || reading > max) {
        max = reading;
      }
    }
    if (min == null || max == null || max == min) {
      return null;
    }
    return (max - min).toDouble();
  }

  /// Distance covered within a calendar period, from the readings dated
  /// inside it.
  static double? distanceInPeriod<T>({
    required Iterable<T> items,
    required DateTime Function(T) date,
    required int Function(T) odometer,
    required bool Function(DateTime) inPeriod,
  }) {
    return distanceCovered([
      for (final item in items)
        if (inPeriod(date(item))) odometer(item),
    ]);
  }

  /// Days between the earliest and latest date, inclusive floor of 1 so a
  /// single busy day still yields a per-day average.
  static int spanDays(Iterable<DateTime> dates) {
    DateTime? first;
    DateTime? last;
    for (final d in dates) {
      if (first == null || d.isBefore(first)) {
        first = d;
      }
      if (last == null || d.isAfter(last)) {
        last = d;
      }
    }
    if (first == null || last == null) {
      return 0;
    }
    final days = last.difference(first).inDays;
    return days < 1 ? 1 : days;
  }
}
