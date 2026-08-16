/// What a vehicle costs to run, with the three kinds of spending brought
/// together.
///
/// Fuel, servicing and other costs live in three tables because they answer
/// different questions, and "what does this car cost me" was therefore a sum
/// nobody had done. This does it once, in one place, so every screen quotes
/// the same figure.
///
/// Ownership span comes from the vehicle's baseline, which is what that field
/// is for: the point from which this household has been paying for the car.
class RunningCost {
  const RunningCost({
    required this.fuel,
    required this.service,
    required this.other,
    required this.distanceKm,
    required this.months,
  });

  final double fuel;
  final double service;
  final double other;

  /// Distance covered over the same span the money was spent.
  final int distanceKm;

  /// Whole calendar months of ownership. Calendar months rather than an
  /// average day count, because "a year of owning it" should divide into
  /// twelve, not 11.99.
  final double months;

  static RunningCost of({
    required double fuel,
    required double service,
    required double other,
    required int distanceKm,
    required DateTime since,
    required DateTime until,
  }) {
    final wholeMonths =
        (until.year - since.year) * 12 + (until.month - since.month);
    // Part of a month counts proportionally, so a figure does not jump on the
    // day of the month the car happened to be bought.
    final dayFraction = (until.day - since.day) / 30.0;
    return RunningCost(
      fuel: fuel,
      service: service,
      other: other,
      distanceKm: distanceKm,
      months: (wholeMonths + dayFraction).clamp(0.0, double.infinity),
    );
  }

  double get total => fuel + service + other;

  /// Whether anything has been spent at all. A car with distance but no logged
  /// spending costs "0.000 per km" arithmetically, which is not a fact about
  /// the car, only about how little has been entered.
  bool get hasSpending => total > 0;

  /// Everything that is not fuel: servicing, registration, insurance, tyres.
  double get upkeep => service + other;

  /// Null rather than zero when the car has not moved: a cost per kilometre
  /// over no kilometres is not a small number, it is not a number.
  double? get perKm => distanceKm <= 0 ? null : total / distanceKm;

  double? get fuelPerKm => distanceKm <= 0 ? null : fuel / distanceKm;

  double? get upkeepPerKm => distanceKm <= 0 ? null : upkeep / distanceKm;

  /// Null until a month has actually passed. Spreading a week of ownership
  /// across a month reports a figure nobody has spent.
  double? get perMonth => months < 1 ? null : total / months;

  double? get perYear => months <= 0 ? null : total / (months / 12);
}
