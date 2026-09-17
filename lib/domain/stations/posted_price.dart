import '../entities/fuel_entry.dart';
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
///
/// [stationRefs] are the forecourts earlier fill-ups under this name were
/// recognised at, newest first ([recognisedForecourts]), and the first one
/// that can be trusted is asked before the name: the name is a brand now, and
/// a brand answers for every forecourt a chain runs. See [recognisedStation]
/// for when one is not trusted.
double? postedPriceAt({
  required List<FuelStation> stations,
  required String? stationName,
  required int? fuelTypeId,
  Iterable<int> stationRefs = const [],
}) {
  if (fuelTypeId == null) {
    return null;
  }
  final wanted = stationName?.trim().toLowerCase();
  if (wanted == null || wanted.isEmpty) {
    return null;
  }

  for (final ref in stationRefs) {
    final known = recognisedStation(
      stations: stations,
      stationRef: ref,
      stationName: wanted,
    );
    if (known != null) {
      // That forecourt's price or none: another forecourt of the brand
      // selling the fuel is not where the car was filled.
      return known.cheapestFor(fuelTypeId);
    }
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

/// The forecourts earlier fill-ups logged under [stationName] were recognised
/// at, newest first, for [postedPriceAt] to ask.
///
/// [history] is a car's log in the order it is kept, oldest first. A fill-up
/// logged at home keeps no forecourt, so the one before it that was logged at
/// the pump is what still says where "INA" is for this household. A fill-up
/// under another name lends its id to nothing: the id describes the station
/// text it was saved with.
List<int> recognisedForecourts(List<FuelEntry> history, String stationName) {
  final wanted = stationName.trim().toLowerCase();
  return [
    for (final entry in history.reversed)
      if (entry.stationRef case final ref?)
        if (entry.station?.trim().toLowerCase() == wanted) ref,
  ];
}
