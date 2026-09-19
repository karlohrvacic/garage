/// Where a chart over time puts its ticks: on the calendar, not on the data.
///
/// fl_chart places a tick at every multiple of one interval, counted from
/// zero. Months are not one length, so an axis in days can put a tick near
/// 1 January but not on it. This axis is in months instead, counted from
/// January 2000 with the day interpolated inside its month: every month
/// boundary is a whole number, a quarter is a multiple of three and a January
/// a multiple of twelve, so a tick lands exactly on the boundary and its label
/// is the month it names. The cost is that a day in February is a tenth wider
/// than a day in July, which a mileage curve at phone width cannot show.
class TimeAxis {
  TimeAxis({required this.first, required this.last, this.mostTicks = 5});

  final DateTime first;
  final DateTime last;

  /// The most labels the axis carries. Five is what stays legible on a plot
  /// two hundred pixels wide, which is what a 320px phone leaves after the
  /// card's padding and the y-axis.
  final int mostTicks;

  static const _epochYear = 2000;

  /// A month, a quarter, a half-year, a year, two and five.
  static const _units = [1, 3, 6, 12, 24, 60];

  /// [date] in months since January 2000, the day interpolated inside its
  /// month: 1 January 2026 is exactly 312.
  static double x(DateTime date) {
    final daysInMonth = DateTime.utc(date.year, date.month + 1, 0).day;
    return (date.year - _epochYear) * 12 +
        (date.month - 1) +
        (date.day - 1) / daysInMonth;
  }

  double get minX => x(first);

  double get maxX => x(last);

  /// Months between ticks: the finest unit that keeps to [mostTicks].
  late final int unitMonths = _units.firstWhere(
    (unit) => _ticksEvery(unit).length <= mostTicks,
    orElse: () => _units.last,
  );

  /// The month starts strictly inside the span that fall on the unit's
  /// boundaries. A boundary on the first or last day is the end of the axis,
  /// not a tick, and a span inside one month has none.
  late final List<DateTime> ticks = _ticksEvery(unitMonths);

  List<DateTime> _ticksEvery(int unit) {
    final min = minX;
    final max = maxX;
    var index = (min / unit).floor() * unit;
    if (index <= min) {
      index += unit;
    }
    return [for (; index < max; index += unit) monthAt(index.toDouble())];
  }

  /// The month a tick at [x] stands for. fl_chart walks the axis by adding
  /// the interval, so what it hands back is never quite the whole number
  /// that went in.
  DateTime monthAt(double x) {
    final index = x.round();
    final year = _epochYear + (index - index % 12) ~/ 12;
    return DateTime.utc(year, index % 12 + 1);
  }
}
