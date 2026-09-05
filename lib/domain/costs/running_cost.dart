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
    double? otherPaid,
  }) : otherPaid = otherPaid ?? other;

  final double fuel;
  final double service;

  /// Other costs with yearly cover spread over its year: the figure the
  /// per-month and per-year rates rest on.
  final double other;

  /// Other costs as paid, in full, on the day. A €600 premium is €600 out
  /// of the household's account whatever the year ahead holds, and a total
  /// that showed it as €1.64 read as a bug.
  final double otherPaid;

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
    double? otherPaid,
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
      otherPaid: otherPaid,
      distanceKm: distanceKm,
      months: (wholeMonths + dayFraction).clamp(0.0, double.infinity),
    );
  }

  double get total => fuel + service + other;

  /// Everything paid since the car was added, nothing spread.
  double get paid => fuel + service + otherPaid;

  /// Whether spreading changed anything worth a sentence.
  bool get spreads => (otherPaid - other).abs() >= 0.005;

  /// Whether anything has been spent at all. A car with distance but no logged
  /// spending costs "0.000 per km" arithmetically, which is not a fact about
  /// the car, only about how little has been entered.
  /// Both figures, because the card built on this shows rates *and* totals.
  /// Spending that prorates to nothing — a policy whose cover falls entirely
  /// before the car was added — would otherwise print €0.00 a month and
  /// 0.000 per kilometre directly above a four-figure total, which is the
  /// internally inconsistent card this guard exists to prevent.
  bool get hasSpending => paid > 0 && total > 0;

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

  /// What owning the car has cost altogether: what it took to buy, plus what
  /// it has taken to run since. Null whenever [purchasePrice] is — most
  /// households importing history will not know or care to enter it — rather
  /// than silently reporting running cost alone as the whole answer.
  ///
  /// Deliberately not folded into [total]: a one-time capital cost blended
  /// into a per-kilometre running figure would move [perKm] every time
  /// someone typed in a number that has nothing to do with driving.
  /// Built on [paid] rather than [total]: this sits directly under the
  /// "since you added it" figure on the vehicle page, and the two disagreeing
  /// by the amount that was spread reads as an arithmetic error.
  double? costOfOwnership(double? purchasePrice) =>
      purchasePrice == null ? null : purchasePrice + paid;

  /// What the car has cost to *own*, per kilometre: everything it took to run
  /// over the same distance, plus the value it lost.
  ///
  /// The honest number, and the one people actually decide on. "€0.31/km to
  /// run" is true and incomplete — depreciation is the largest cost of owning
  /// a car and appeared in no figure this app printed.
  ///
  /// Null unless both the price and a current valuation are known, rather
  /// than falling back to the running figure: an ownership cost that quietly
  /// omits depreciation is the exact mistake this exists to correct.
  ///
  /// Measured over the distance covered *since the household added the car*,
  /// which is the only span this app has readings for. A car bought years
  /// before it was logged has lost value over kilometres nobody here recorded,
  /// so its figure reads high; the alternative is not printing one at all.
  double? ownPerKm({double? purchasePrice, double? currentValue}) {
    final lost = depreciation(
      purchasePrice: purchasePrice,
      currentValue: currentValue,
    );
    if (lost == null || distanceKm <= 0) {
      return null;
    }
    return (total + lost) / distanceKm;
  }
}

/// What a vehicle has lost in value: what it cost to buy, less what it is
/// worth now.
///
/// Negative for a car that gained value, which is a real thing a well-kept
/// classic does. Clamping it to zero would make ownership look more expensive
/// than it was, and this app does not round in its own favour.
double? depreciation({double? purchasePrice, double? currentValue}) {
  if (purchasePrice == null || currentValue == null) {
    return null;
  }
  return purchasePrice - currentValue;
}

/// Whether a valuation is old enough that quoting it as current would be
/// misleading.
///
/// A year, because that is roughly how often a used-car market moves enough
/// to matter and how often somebody is willing to look one up. A figure with
/// no date at all counts as stale: a number of unknown age presented as
/// today's is the failure this guards against.
bool valuationIsStale({required DateTime? valuedOn, required DateTime today}) {
  if (valuedOn == null) {
    return true;
  }
  final year = DateTime.utc(today.year - 1, today.month, today.day);
  return valuedOn.isBefore(year);
}
