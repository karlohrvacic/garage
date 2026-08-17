import 'fuel_station.dart';

/// A station with how far away it is, when that is known.
class RankedStation {
  const RankedStation({required this.station, this.distanceKm});

  final FuelStation station;

  /// Null when no device position was available — the web often has none, and
  /// a price list is still worth reading.
  final double? distanceKm;
}

/// The three stations worth naming out of a list of hundreds.
class StationPicks {
  const StationPicks({this.nearest, this.cheapest, this.bestValue});

  final RankedStation? nearest;
  final RankedStation? cheapest;

  /// The cheapest station **after** paying for the fuel burned getting there
  /// and back.
  ///
  /// This is the one that is actually useful and the one the competition does
  /// not do: driving 20 km to save three cents a litre is a loss, and a
  /// "best price" pick that says otherwise is telling the reader something
  /// untrue. Without a consumption figure to price the detour with, this is
  /// simply the cheapest — inventing a rate to look clever would be worse.
  final RankedStation? bestValue;

  /// [litres] and [litersPer100Km] are what make [bestValue] mean anything.
  /// Both come from the vehicle: its tank size and its measured consumption.
  static StationPicks from(
    List<RankedStation> stations, {
    required int fuelTypeId,
    double? litres,
    double? litersPer100Km,
  }) {
    final candidates = [
      for (final ranked in stations)
        if (ranked.station.cheapestFor(fuelTypeId) != null) ranked,
    ];
    if (candidates.isEmpty) {
      return const StationPicks();
    }

    RankedStation? nearest;
    RankedStation? cheapest;
    RankedStation? bestValue;
    double? bestEffectiveCost;

    for (final ranked in candidates) {
      final price = ranked.station.cheapestFor(fuelTypeId)!;
      final distance = ranked.distanceKm;

      if (distance != null &&
          (nearest == null || distance < nearest.distanceKm!)) {
        nearest = ranked;
      }
      if (cheapest == null ||
          price < cheapest.station.cheapestFor(fuelTypeId)!) {
        cheapest = ranked;
      }

      // What this fill would really cost: the fuel bought, plus the fuel
      // burned on the round trip valued at what it costs here.
      final effective = _effectiveCost(
        price: price,
        distanceKm: distance,
        litres: litres,
        litersPer100Km: litersPer100Km,
      );
      if (bestEffectiveCost == null || effective < bestEffectiveCost) {
        bestEffectiveCost = effective;
        bestValue = ranked;
      }
    }

    return StationPicks(
      nearest: nearest,
      cheapest: cheapest,
      bestValue: bestValue,
    );
  }

  static double _effectiveCost({
    required double price,
    required double? distanceKm,
    required double? litres,
    required double? litersPer100Km,
  }) {
    final volume = litres ?? 1;
    final fill = price * volume;
    if (distanceKm == null || litersPer100Km == null || litres == null) {
      // Nothing to price the detour with; rank by price alone.
      return fill;
    }
    final detourLitres = distanceKm * 2 * litersPer100Km / 100;
    return fill + detourLitres * price;
  }

  /// What each grade costs around here, commonest grade first.
  ///
  /// By grade rather than by coarse fuel type, because 95 and 100 are
  /// different fuels sold at different prices and averaging them together
  /// produces a figure nobody can act on.
  static List<AreaAverage> areaAverages(
    List<RankedStation> stations, {
    double radiusKm = 25,
  }) {
    final totals = <String, ({double sum, int count})>{};
    for (final ranked in stations) {
      final distance = ranked.distanceKm;
      if (distance != null && distance > radiusKm) {
        continue;
      }
      // One reading per grade per station: a station listing the same grade
      // twice must not count twice.
      final seen = <String>{};
      for (final price in ranked.station.prices) {
        if (!seen.add(price.fuelName)) {
          continue;
        }
        final existing = totals[price.fuelName];
        totals[price.fuelName] = (
          sum: (existing?.sum ?? 0) + price.price,
          count: (existing?.count ?? 0) + 1,
        );
      }
    }

    final averages = [
      for (final entry in totals.entries)
        AreaAverage(
          fuelName: entry.key,
          averagePrice: entry.value.sum / entry.value.count,
          stations: entry.value.count,
        ),
    ];
    averages.sort((a, b) {
      final byCount = b.stations.compareTo(a.stations);
      return byCount != 0 ? byCount : a.fuelName.compareTo(b.fuelName);
    });
    return averages;
  }
}

class AreaAverage {
  const AreaAverage({
    required this.fuelName,
    required this.averagePrice,
    required this.stations,
  });

  final String fuelName;
  final double averagePrice;

  /// How many stations that average is over — the difference between a figure
  /// and a rumour.
  final int stations;
}
