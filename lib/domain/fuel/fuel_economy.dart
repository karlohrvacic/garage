import '../entities/fuel_entry.dart';

/// One computed economy figure, anchored to the full-tank fill that closes the
/// span it measures.
class EconomyPoint {
  const EconomyPoint({
    required this.entryId,
    required this.date,
    required this.odometerKm,
    required this.litersPer100Km,
    required this.distanceKm,
    required this.volumeL,
    this.costPerKm,
  });

  final String entryId;
  final DateTime date;
  final int odometerKm;
  final double litersPer100Km;
  final double distanceKm;
  final double volumeL;
  final double? costPerKm;
}

/// The full-tank economy algorithm.
///
/// Economy is only meaningful between two fills that both brought the tank to
/// full: the fuel burned over that span is exactly what was put in after the
/// first full tank, up to and including the second. Partial fills in between
/// contribute their volume to the span. An entry flagged [FuelEntry.missedFill]
/// means fuel went in unlogged, so the span ending at it is discarded rather
/// than reported as an implausibly good figure.
abstract final class FuelEconomy {
  static List<EconomyPoint> compute(List<FuelEntry> entries) {
    final sorted = [...entries]
      ..sort((a, b) {
        final byOdometer = a.odometerKm.compareTo(b.odometerKm);
        if (byOdometer != 0) {
          return byOdometer;
        }
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) {
          return byDate;
        }
        // Total order: at an identical (odometer, date) a full tank sorts
        // before a partial one. Without this tie-break, two fills at the same
        // point can come out in an input-dependent order and flip the economy
        // computed across a degenerate zero-distance span.
        if (a.fullTank == b.fullTank) {
          return 0;
        }
        return a.fullTank ? -1 : 1;
      });

    final points = <EconomyPoint>[];

    FuelEntry? spanStart;
    var spanVolumeL = 0.0;
    var spanCost = 0.0;
    var spanCostKnown = true;
    var spanBroken = false;

    for (final entry in sorted) {
      if (spanStart == null) {
        if (entry.fullTank) {
          spanStart = entry;
        }
        continue;
      }

      spanVolumeL += entry.volumeL;
      if (entry.total == null) {
        spanCostKnown = false;
      } else {
        spanCost += entry.total!;
      }
      if (entry.missedFill) {
        spanBroken = true;
      }

      if (!entry.fullTank) {
        continue;
      }

      final distanceKm = (entry.odometerKm - spanStart.odometerKm).toDouble();
      if (!spanBroken && distanceKm > 0) {
        points.add(
          EconomyPoint(
            entryId: entry.id,
            date: entry.date,
            odometerKm: entry.odometerKm,
            litersPer100Km: spanVolumeL / distanceKm * 100,
            distanceKm: distanceKm,
            volumeL: spanVolumeL,
            costPerKm: spanCostKnown ? spanCost / distanceKm : null,
          ),
        );
      }

      spanStart = entry;
      spanVolumeL = 0;
      spanCost = 0;
      spanCostKnown = true;
      spanBroken = false;
    }

    return points;
  }

  /// Distance-weighted mean economy — the honest lifetime figure. Averaging
  /// the points directly would let a single short tank outweigh a long one.
  static double? average(List<EconomyPoint> points) {
    if (points.isEmpty) {
      return null;
    }
    var distance = 0.0;
    var volume = 0.0;
    for (final point in points) {
      distance += point.distanceKm;
      volume += point.volumeL;
    }
    return distance == 0 ? null : volume / distance * 100;
  }
}
