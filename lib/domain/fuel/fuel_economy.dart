import 'dart:math' as math;

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
    this.fuelTypeKey,
    this.station,
  });

  final String entryId;
  final DateTime date;
  final int odometerKm;
  final double litersPer100Km;
  final double distanceKm;
  final double volumeL;
  final double? costPerKm;

  /// Which fuel this figure is about, on a car that takes more than one. Null
  /// for a car that takes one, where the question does not arise.
  final String? fuelTypeKey;

  /// Where the fuel this span burned was bought, when that is one place.
  ///
  /// A span's fuel is what went in *after* the opening full tank, up to and
  /// including the closing one — so the closing fill's station is what bought
  /// it, and the opening tank's station is irrelevant because its fuel was
  /// burned before the span began.
  ///
  /// Null when a partial fill inside the span came from somewhere else, or
  /// when any contributing fill named no station at all. Two stations' fuel
  /// burned together measures neither of them, and guessing which to credit
  /// would put a number on the screen that nothing supports.
  final String? station;
}

/// The full-tank economy algorithm.
///
/// Economy is only meaningful between two fills that both brought the tank to
/// full: the fuel burned over that span is exactly what was put in after the
/// first full tank, up to and including the second. Partial fills in between
/// contribute their volume to the span. An entry flagged [FuelEntry.missedFill]
/// means fuel went in unlogged, so the span ending at it is discarded rather
/// than reported as an implausibly good figure.
///
/// **A car running two fuels gets one chain per fuel.** Averaging petrol and
/// LPG fills together produced a figure that was neither, which is the defect
/// this splitting fixes. What it cannot fix is that the two chains overlap in
/// distance: an LPG span from 1000 to 1500 km includes whatever was driven on
/// petrol in between, so each figure is an approximation of that fuel's
/// consumption over a period rather than a measurement of it. Every app that
/// tracks a second tank has the same limitation; the alternative is asking the
/// driver to record every switch of the changeover valve.
abstract final class FuelEconomy {
  /// [primaryFuelKey] is what an entry with no fuel of its own is taken to be.
  /// Rows written before the column existed carry null, and on a car that has
  /// since gained a second tank those belong to the fuel it mainly runs on
  /// rather than to a chain of their own.
  static List<EconomyPoint> compute(
    List<FuelEntry> entries, {
    String? primaryFuelKey,
  }) {
    final byFuel = <String?, List<FuelEntry>>{};
    for (final entry in entries) {
      final key = entry.fuelTypeKey ?? primaryFuelKey;
      (byFuel[key] ??= []).add(entry);
    }
    if (byFuel.length <= 1) {
      return _computeChain(entries, byFuel.keys.firstOrNull);
    }
    return [
      for (final fuel in byFuel.keys) ..._computeChain(byFuel[fuel]!, fuel),
    ]..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
  }

  /// One fuel's chain of full tanks.
  static List<EconomyPoint> _computeChain(
    List<FuelEntry> entries,
    String? fuelTypeKey,
  ) {
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
    // Every station that put fuel into this span. One name means the span is
    // attributable; anything else — two names, or a fill that named none —
    // means it is not.
    var spanStations = <String>{};
    var spanStationsKnown = true;

    for (final entry in sorted) {
      if (spanStart == null) {
        if (entry.fullTank) {
          spanStart = entry;
        }
        continue;
      }

      spanVolumeL += entry.volumeL;
      final station = (entry.station ?? '').trim();
      if (station.isEmpty) {
        spanStationsKnown = false;
      } else {
        spanStations.add(station);
      }
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
            fuelTypeKey: fuelTypeKey,
            station: spanStationsKnown && spanStations.length == 1
                ? spanStations.first
                : null,
          ),
        );
      }

      spanStart = entry;
      spanVolumeL = 0;
      spanCost = 0;
      spanCostKnown = true;
      spanBroken = false;
      spanStations = <String>{};
      spanStationsKnown = true;
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

/// The span between a vehicle's best and worst recorded economy.
///
/// The economy ring needs a scale, and a fixed one cannot serve every vehicle:
/// 4 to 12 l/100km flatters a small diesel, pins a large petrol car at empty,
/// and means nothing at all for an electric one measured in kWh. A car's own
/// history is true for all of them, and it answers the question a driver
/// actually has: is this tank good *for this car*.
class EconomyRange {
  const EconomyRange({required this.best, required this.worst});

  /// The lowest consumption recorded, which is the best.
  final double best;

  /// The highest consumption recorded.
  final double worst;

  /// The narrowest spread worth scaling against, in the same units as the
  /// figures themselves.
  ///
  /// Economy is printed to one decimal, so a range narrower than that is one
  /// the reader cannot see: the caption reads "Best 6.0 · Worst 6.0" while the
  /// ring swings on the difference. Exact equality was not enough of a guard,
  /// because these figures come out of floating-point division: twelve tanks
  /// that all worked out to 6.0 differed by 9e-16, and the ring scaled that.
  static const double _minimumSpread = 0.05;

  /// Null until there is something to compare: one tank has no range, and a
  /// car whose tanks were all but identical has no scale to place anything on.
  static EconomyRange? of(List<EconomyPoint> points) {
    if (points.length < 2) {
      return null;
    }
    var best = points.first.litersPer100Km;
    var worst = best;
    for (final point in points) {
      best = math.min(best, point.litersPer100Km);
      worst = math.max(worst, point.litersPer100Km);
    }
    if (worst - best < _minimumSpread) {
      return null;
    }
    return EconomyRange(best: best, worst: worst);
  }

  /// Where [economy] sits in the range, 1 at the best end and 0 at the worst.
  double fractionFor(double economy) =>
      ((worst - economy) / (worst - best)).clamp(0.0, 1.0).toDouble();
}
