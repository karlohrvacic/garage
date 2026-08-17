import 'stats_period.dart';

/// A total, and the two things worth dividing it by.
///
/// A number on its own — "€1,699" — is not comparable to anything. The same
/// total over a year and over a month are different facts, and so are the same
/// total over 3,000 km and over 30,000. Both divisors travel with the total so
/// no screen can show one without the other being available.
class SpendRate {
  const SpendRate({
    required this.total,
    required this.days,
    required this.distanceKm,
  });

  final double total;

  /// Days the total is spread across, normally the length of the report's
  /// period rather than the span between the first and last entry: a month
  /// with one bill in it is still a month.
  final int days;

  /// Distance covered in the same period, from the merged odometer series.
  final double distanceKm;

  /// Null when no time has passed, rather than zero or infinity.
  double? get perDay => days <= 0 ? null : total / days;

  /// Null when the car has not moved. A household that logs registration and
  /// insurance but never an odometer reading has a real total and nothing to
  /// divide it by; zero would be a lie.
  double? get perKm => distanceKm <= 0 ? null : total / distanceKm;

  /// Sums the amounts dated inside [from]…[to] and pairs them with the period's
  /// own length and the distance covered in it.
  static SpendRate of({
    required Iterable<(DateTime, double)> amounts,
    required DateTime from,
    required DateTime to,
    required double distanceKm,
  }) {
    final range = DateRange(from: from, to: to);
    var total = 0.0;
    for (final (date, amount) in amounts) {
      if (range.contains(date)) {
        total += amount;
      }
    }
    return SpendRate(total: total, days: range.days, distanceKm: distanceKm);
  }
}
