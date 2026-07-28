/// Pure arithmetic behind the trip calculator. Inputs are canonical units
/// (km, litres); callers convert display units at the edge.
abstract final class TripMath {
  /// Litres needed to cover [distanceKm] at [litersPer100Km].
  static double? requiredFuel({
    required double? distanceKm,
    required double? litersPer100Km,
  }) {
    if (distanceKm == null || litersPer100Km == null) {
      return null;
    }
    return distanceKm * litersPer100Km / 100;
  }

  /// Cost of covering [distanceKm] at [litersPer100Km] and [pricePerLiter].
  static double? tripCost({
    required double? distanceKm,
    required double? litersPer100Km,
    required double? pricePerLiter,
  }) {
    final fuel = requiredFuel(
      distanceKm: distanceKm,
      litersPer100Km: litersPer100Km,
    );
    if (fuel == null || pricePerLiter == null) {
      return null;
    }
    return fuel * pricePerLiter;
  }

  /// Distance coverable with [fuelLiters] at [litersPer100Km].
  static double? reachableDistance({
    required double? fuelLiters,
    required double? litersPer100Km,
  }) {
    if (fuelLiters == null || litersPer100Km == null || litersPer100Km <= 0) {
      return null;
    }
    return fuelLiters / litersPer100Km * 100;
  }

  /// Consumption implied by covering [distanceKm] on [fuelLiters].
  static double? consumption({
    required double? distanceKm,
    required double? fuelLiters,
  }) {
    if (distanceKm == null || fuelLiters == null || distanceKm <= 0) {
      return null;
    }
    return fuelLiters / distanceKm * 100;
  }
}
