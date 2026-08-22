import '../fuel/fuel_economy.dart';

/// One station's measured economy, and how much evidence stands behind it.
class StationEconomySample {
  const StationEconomySample({
    required this.station,
    required this.litersPer100Km,
    required this.tanks,
    required this.distanceKm,
  });

  final String station;

  /// Distance-weighted, like every other economy figure in the app.
  final double litersPer100Km;

  /// How many full-tank spans this rests on. Shown, not hidden: the reader
  /// deserves to weigh four tanks differently from forty.
  final int tanks;

  final double distanceKm;
}

/// Economy grouped by where the fuel was bought.
///
/// This is the app's most easily-misread statistic, so the rules are strict.
/// Fuel brand is a small effect and driving, weather, season and tyre pressure
/// are large ones — a difference between two stations is far more likely to be
/// what the driver was doing that month than what came out of the pump. So
/// this reports an **observation**, never a recommendation, and stays silent
/// rather than dressing noise up as a finding.
abstract final class StationEconomy {
  /// How many full-tank spans a station needs before it is reported at all.
  ///
  /// Three is not statistical significance and nothing here pretends it is.
  /// It is the point below which a single unusual tank *is* the average, which
  /// is the difference between a thin figure and a meaningless one.
  static const int defaultMinimumTanks = 3;

  /// The gap below which two stations are treated as the same.
  ///
  /// Five per cent, which for a car around 6 l/100km is 0.3 — comfortably
  /// inside the spread one driver produces between a motorway week and a
  /// city one. Below this the honest answer is "no difference worth naming".
  static const double meaningfulDifference = 0.05;

  /// Each qualifying station, most frugal first.
  static List<StationEconomySample> compare(
    List<EconomyPoint> points, {
    int minimumTanks = defaultMinimumTanks,
  }) {
    final byStation = <String, List<EconomyPoint>>{};
    for (final point in points) {
      final station = (point.station ?? '').trim();
      if (station.isEmpty) {
        // Unattributable: a span whose fuel came from more than one place, or
        // from a fill that named none. Counting it anywhere would be inventing
        // evidence.
        continue;
      }
      (byStation[station] ??= []).add(point);
    }

    final samples = <StationEconomySample>[];
    for (final entry in byStation.entries) {
      if (entry.value.length < minimumTanks) {
        continue;
      }
      final distance = entry.value.fold<double>(
        0,
        (sum, point) => sum + point.distanceKm,
      );
      final volume = entry.value.fold<double>(
        0,
        (sum, point) => sum + point.volumeL,
      );
      if (distance <= 0) {
        continue;
      }
      samples.add(
        StationEconomySample(
          station: entry.key,
          // Distance-weighted, so a 100 km tank cannot outweigh a 900 km one.
          litersPer100Km: volume / distance * 100,
          tanks: entry.value.length,
          distanceKm: distance,
        ),
      );
    }

    return samples
      ..sort((a, b) => a.litersPer100Km.compareTo(b.litersPer100Km));
  }

  /// Whether [samples] say anything worth putting on screen.
  ///
  /// Two conditions, both necessary. **Something to compare against**: "you do
  /// better at INA" is meaningless with only INA measured. **A gap larger than
  /// the noise**: below [meaningfulDifference] the two stations are the same
  /// and saying otherwise would be the app inventing a pattern.
  static bool worthShowing(List<StationEconomySample> samples) {
    if (samples.length < 2) {
      return false;
    }
    final best = samples.first.litersPer100Km;
    final worst = samples.last.litersPer100Km;
    if (best <= 0) {
      return false;
    }
    return (worst - best) / best >= meaningfulDifference;
  }
}
