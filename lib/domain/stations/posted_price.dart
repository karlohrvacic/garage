import 'fuel_station.dart';

/// Today's posted price for [fuelTypeId] at the station called [stationName].
///
/// The pump match ([StationAtThePump]) only fires for someone standing on a
/// forecourt, which is the wrong moment for most people: a fill-up is usually
/// logged later, at home, where the sheet fell back to the price of the *last*
/// fill-up — a number that can be weeks stale. The dataset holds today's price
/// for every station regardless of where the phone is, so the station name the
/// last fill-up already recorded is enough to offer a current number instead.
///
/// Null whenever the answer would be a guess: no name remembered, a name the
/// dataset does not carry, a fuel that station does not sell, or a car the
/// dataset does not price. Each is silent — the caller keeps whatever it had.
double? postedPriceAt({
  required List<FuelStation> stations,
  required String? stationName,
  required int? fuelTypeId,
}) {
  if (fuelTypeId == null) {
    return null;
  }
  final wanted = stationName?.trim().toLowerCase();
  if (wanted == null || wanted.isEmpty) {
    return null;
  }

  double? price;
  for (final station in stations) {
    if (!station.answersTo(wanted)) {
      continue;
    }
    final posted = station.cheapestFor(fuelTypeId);
    if (posted == null) {
      continue;
    }
    // Chains repeat a name across forecourts that charge differently. Same
    // price at both is still one answer; two prices is not an answer at all,
    // and a wrong number typed into a receipt is worse than an empty field.
    if (price != null && price != posted) {
      return null;
    }
    price = posted;
  }
  return price;
}
