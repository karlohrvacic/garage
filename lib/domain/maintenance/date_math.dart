/// Calendar arithmetic for maintenance intervals.
abstract final class DateMath {
  /// Adds [months], clamping the day to the last valid day of the target
  /// month. 31 January plus one month is 28 (or 29) February, not 3 March —
  /// Dart's `DateTime` would otherwise silently roll over.
  static DateTime addMonths(DateTime from, int months) {
    final totalMonths = from.month - 1 + months;
    // Floor-divide toward negative infinity so the year and month agree for
    // negative month counts: `~/` truncates toward zero while `%` is always
    // non-negative in Dart, so the two disagree once `totalMonths` is negative.
    final year = from.year + ((totalMonths - (totalMonths % 12)) ~/ 12);
    final month = totalMonths % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = from.day < lastDayOfMonth ? from.day : lastDayOfMonth;
    return DateTime(year, month, day);
  }

  /// Midnight on the same calendar day.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Whole calendar days from [start] to [end]; negative when [end] is earlier.
  ///
  /// Rebuilt in UTC before differencing: a span across the spring-forward DST
  /// jump is N days minus an hour in local time, and `inDays` would truncate
  /// that to N-1.
  static int daysBetween(DateTime start, DateTime end) =>
      DateTime.utc(end.year, end.month, end.day)
          .difference(DateTime.utc(start.year, start.month, start.day))
          .inDays;
}
