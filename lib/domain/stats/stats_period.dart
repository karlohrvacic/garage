/// A closed range of calendar days, both ends included.
///
/// Comparison is by calendar day rather than by instant. Entries are stored at
/// UTC midnight but a range built from a date picker carries whatever time of
/// day the picker handed back, and comparing instants would silently drop the
/// last day of every range a user chose by hand.
class DateRange {
  const DateRange({required this.from, required this.to});

  /// Everything, ever. Used by [StatsPeriod.allTime] so the rest of the code
  /// never has to special-case "no filter".
  static final unbounded = DateRange(
    from: DateTime.utc(1900),
    to: DateTime.utc(2200),
  );

  final DateTime from;
  final DateTime to;

  bool contains(DateTime date) {
    final day = _day(date);
    return !day.isBefore(_day(from)) && !day.isAfter(_day(to));
  }

  /// Days covered, counting both ends. Never zero: a single-day range is one
  /// day, or every per-day average across it would divide by zero.
  int get days => _day(to).difference(_day(from)).inDays + 1;

  /// Narrowed to the days that could actually have held an entry.
  ///
  /// Only [unbounded] is narrowed, and that is the point. "All time" resolves
  /// to 1900–2200 so nothing is filtered out, and using those ends as a real
  /// span makes every per-day figure a total divided by three centuries and
  /// puts the monthly bar chart in the year 2200. A *chosen* month is left
  /// alone: a month with one bill in it is still a month, and "what does this
  /// car cost me a month" divides by the month.
  DateRange clampedTo(DateTime? first, DateTime? last) {
    if (this != unbounded || first == null || last == null) {
      return this;
    }
    return DateRange(from: first, to: last);
  }

  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'DateRange(from: $from, to: $to)';
}

/// The periods a report can be taken over.
///
/// Named periods rather than only a free date picker: "this year against last"
/// is the question people actually ask of a car, and making them pick two dates
/// to ask it is a tax. [custom] exists for everything else and carries its own
/// range, which is why [resolve] takes one.
enum StatsPeriod {
  allTime,
  thisYear,
  previousYear,
  thisMonth,
  previousMonth,
  lastTwelveMonths,
  custom;

  /// The range this period covers relative to [today]. [custom] resolves to
  /// [customRange] if given, and to everything if not — a custom period with no
  /// range chosen yet should show the whole log rather than nothing.
  DateRange resolve(DateTime today, {DateRange? customRange}) {
    return switch (this) {
      StatsPeriod.allTime => DateRange.unbounded,
      StatsPeriod.thisYear => DateRange(
        from: DateTime.utc(today.year, 1, 1),
        to: DateTime.utc(today.year, 12, 31),
      ),
      StatsPeriod.previousYear => DateRange(
        from: DateTime.utc(today.year - 1, 1, 1),
        to: DateTime.utc(today.year - 1, 12, 31),
      ),
      StatsPeriod.thisMonth => DateRange(
        from: DateTime.utc(today.year, today.month, 1),
        // Day zero of the next month is the last day of this one, which is how
        // this avoids a table of month lengths and gets February right.
        to: DateTime.utc(today.year, today.month + 1, 0),
      ),
      StatsPeriod.previousMonth => DateRange(
        from: DateTime.utc(today.year, today.month - 1, 1),
        to: DateTime.utc(today.year, today.month, 0),
      ),
      StatsPeriod.lastTwelveMonths => DateRange(
        from: DateTime.utc(today.year - 1, today.month, today.day),
        to: DateTime.utc(today.year, today.month, today.day),
      ),
      StatsPeriod.custom => customRange ?? DateRange.unbounded,
    };
  }
}
