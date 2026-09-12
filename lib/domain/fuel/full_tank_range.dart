import 'fuel_economy.dart';

/// How far a full tank goes on this car, at its own measured consumption.
///
/// The honest half of what "range" used to promise. The old estimate counted
/// down from the last full tank towards empty, which made it depend on the
/// odometer being current — and between fill-ups it never is, because the
/// reading only moves when somebody logs something. A tank filled a fortnight
/// and six hundred kilometres ago still read as full. This asks a question the
/// records can actually answer: not *how much is left*, which nothing on the
/// phone knows, but *how far a tankful goes*, which every closed tank in the
/// history is a measurement of.
///
/// Nothing here decays, so nothing here goes stale.
class FullTankRange {
  const FullTankRange({
    required this.tankCapacityL,
    required this.typicalKm,
    required this.bestKm,
    required this.worstKm,
    required this.typicalLitersPer100Km,
    required this.bestLitersPer100Km,
    required this.worstLitersPer100Km,
    required this.tanks,
  });

  final double tankCapacityL;

  /// The tank at the car's usual consumption, distance-weighted.
  final double typicalKm;

  /// The furthest and the shortest a tankful has worked out to. Equal to
  /// [typicalKm] on a car with one closed tank, which is a spread of nothing
  /// rather than a missing answer.
  final double bestKm;
  final double worstKm;

  final double typicalLitersPer100Km;

  /// The *lowest* consumption recorded, which is the *longest* range. The two
  /// run opposite ways, which is the easiest thing in this file to get
  /// backwards.
  final double bestLitersPer100Km;
  final double worstLitersPer100Km;

  /// How many closed full-to-full tanks the figures rest on. A range from two
  /// tanks and a range from forty deserve different confidence, and only the
  /// card can say so.
  final int tanks;
}

/// Null when the car cannot answer: no tank capacity, which most cars in the
/// app have never been told, or no closed tank to measure consumption over.
///
/// Null rather than a figure with an em dash in it. A permanent "—" under a
/// label is a claim that the app tried and failed; showing nothing is quieter
/// and just as true.
FullTankRange? fullTankRange({
  required double? tankCapacityL,
  required List<EconomyPoint> points,
}) {
  if (tankCapacityL == null || tankCapacityL <= 0 || points.isEmpty) {
    return null;
  }
  final typical = FuelEconomy.average(points);
  if (typical == null || typical <= 0) {
    return null;
  }

  // Seeded from nothing, not from the first point: the loop skips a tank that
  // worked out to zero, and seeding from one that it would have skipped left
  // `best` at zero — and a range of `60 * 100 / 0` is infinity, printed as a
  // distance. A stored row cannot be zero (`volume_l > 0`), but a queued
  // offline entry is merged into a read before the database ever sees it.
  double? best;
  double? worst;
  for (final point in points) {
    if (point.litersPer100Km <= 0) {
      continue;
    }
    best = best == null || point.litersPer100Km < best
        ? point.litersPer100Km
        : best;
    worst = worst == null || point.litersPer100Km > worst
        ? point.litersPer100Km
        : worst;
  }
  if (best == null || worst == null) {
    return null;
  }

  double rangeAt(double litersPer100Km) => tankCapacityL * 100 / litersPer100Km;

  return FullTankRange(
    tankCapacityL: tankCapacityL,
    typicalKm: rangeAt(typical),
    // Best consumption, longest range: the division turns one into the other.
    bestKm: rangeAt(best),
    worstKm: rangeAt(worst),
    typicalLitersPer100Km: typical,
    bestLitersPer100Km: best,
    worstLitersPer100Km: worst,
    tanks: points.length,
  );
}
