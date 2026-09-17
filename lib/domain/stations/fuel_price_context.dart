/// What the market around a fill-up looked like on the day it was logged.
///
/// The price dataset is fetched live and stored nowhere, so this is the only
/// record that survives: without it, "did I pay over the odds?" is a question
/// the app can never answer about its own history, however long that history
/// gets.
class FuelPriceContext {
  const FuelPriceContext({
    required this.station,
    required this.pricePerUnit,
    required this.distanceKm,
    required this.seenOn,
  });

  /// The cheapest station within reach of the one the fill-up was at, by
  /// the name the log uses for it: the brand, for a chain. Entries saved
  /// before that carry the forecourt's own name.
  final String station;
  final double pricePerUnit;

  /// Zero when the pump used was itself the cheapest around — a result worth
  /// keeping, not a missing value.
  final double distanceKm;

  /// The day the prices were read, UTC and date-only. The feed carries no
  /// timestamp of its own, so without this there is no telling a same-day
  /// snapshot from one taken a week after the fill-up it describes.
  final DateTime seenOn;

  /// What this fill-up's unit price cost above the cheapest nearby, per unit.
  /// Zero or negative means the driver did as well as, or better than, the
  /// cheapest posted price.
  double? overpaidPerUnit(double? paidPerUnit) {
    return paidPerUnit == null ? null : paidPerUnit - pricePerUnit;
  }

  @override
  bool operator ==(Object other) {
    return other is FuelPriceContext &&
        other.station == station &&
        other.pricePerUnit == pricePerUnit &&
        other.distanceKm == distanceKm &&
        other.seenOn == seenOn;
  }

  @override
  int get hashCode => Object.hash(station, pricePerUnit, distanceKm, seenOn);

  @override
  String toString() {
    return 'FuelPriceContext(station: $station, pricePerUnit: $pricePerUnit, '
        'distanceKm: $distanceKm, seenOn: $seenOn)';
  }
}
