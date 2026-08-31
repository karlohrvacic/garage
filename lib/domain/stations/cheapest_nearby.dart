import 'fuel_station.dart';

/// The cheapest station near the one a fill-up happened at, as it stood that
/// day.
class CheapestNearby {
  const CheapestNearby({
    required this.station,
    required this.pricePerUnit,
    required this.distanceKm,
  });

  final String station;
  final double pricePerUnit;

  /// Zero when the pump used was itself the cheapest one around, which is
  /// worth recording rather than discarding: "you already picked the best"
  /// is an answer.
  final double distanceKm;
}

/// How far a driver could reasonably have gone instead.
///
/// A forecourt across town at three cents less is not an alternative — the
/// detour costs more than the saving, which is the same reasoning
/// `StationPicks` best-value already applies before a fill-up.
const double defaultNearbyRadiusKm = 5;

/// What the cheapest nearby station charged, anchored on the station the
/// fill-up names rather than on where the phone happens to be.
///
/// Anchoring on the name is what makes this work at all: fill-ups are usually
/// logged later and elsewhere, so a position-based comparison would answer
/// "what is cheap near my sofa". It also needs no location permission, and the
/// name is already on the entry.
///
/// Null whenever the answer would be a guess — no name, a name the dataset
/// does not carry, a fuel it does not price, nothing priced within
/// [radiusKm], or a chain name pointing at two different neighbourhoods.
CheapestNearby? cheapestNear({
  required List<FuelStation> stations,
  required String? stationName,
  required int? fuelTypeId,
  double radiusKm = defaultNearbyRadiusKm,
}) {
  if (fuelTypeId == null) {
    return null;
  }
  final wanted = stationName?.trim().toLowerCase();
  if (wanted == null || wanted.isEmpty) {
    return null;
  }

  final anchors = [
    for (final station in stations)
      if (station.name.trim().toLowerCase() == wanted) station,
  ];
  if (anchors.isEmpty) {
    return null;
  }

  // Same name, same forecourt — a duplicate row, not an ambiguity. Same name
  // fifty kilometres apart is a chain, and choosing between them would be a
  // coin toss written down as a fact.
  final anchor = anchors.first;
  final ambiguous = anchors
      .skip(1)
      .any(
        (other) =>
            haversineKm(
              lat1: anchor.lat,
              lng1: anchor.lng,
              lat2: other.lat,
              lng2: other.lng,
            ) >
            radiusKm,
      );
  if (ambiguous) {
    return null;
  }

  CheapestNearby? best;
  for (final station in stations) {
    final price = station.cheapestFor(fuelTypeId);
    if (price == null) {
      continue;
    }
    final distance = haversineKm(
      lat1: anchor.lat,
      lng1: anchor.lng,
      lat2: station.lat,
      lng2: station.lng,
    );
    if (distance > radiusKm) {
      continue;
    }
    if (best == null || price < best.pricePerUnit) {
      best = CheapestNearby(
        station: station.name,
        pricePerUnit: price,
        distanceKm: distance,
      );
    }
  }
  return best;
}
