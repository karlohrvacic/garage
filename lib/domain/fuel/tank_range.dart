import '../entities/fuel_entry.dart';

/// Why there is no estimate. Each one is a silence rather than a message: the
/// surfaces that show a range simply show nothing, because "we cannot tell"
/// on four screens is noise, not information.
enum TankRangeUnknown {
  /// [Vehicle.tankCapacityL] is optional, and most cars in the app will not
  /// have it. Without it there is no ceiling to count down from.
  noTankCapacity,

  /// No closed full-tank span yet, so there is no litres-per-100km to burn at.
  noEconomy,

  /// Nothing to count down *from*. A car whose every entry is a partial fill
  /// has never been at a known quantity.
  noFullTank,

  /// A fill-up the driver knows went unlogged since the last full tank. The
  /// arithmetic below would be wrong by however much went in, and a confident
  /// wrong number is worse than a blank.
  missedFill,

  /// The same thing, undeclared: the car has covered more since its last full
  /// tank than a tankful goes. Fuel went in that nobody logged — a car cannot
  /// be driven past empty — so the count-down has lost its footing.
  ///
  /// Without this the clamp at zero was reported as a *measurement*: a device
  /// showed "142,322 km · ≈0 km left" on a car whose last full tank was
  /// 92,000 km earlier, which reads as an empty tank rather than as a gap in
  /// the records.
  unrecordedFill,
}

/// How much fuel is left, how far that goes, and when it runs out.
class TankRange {
  const TankRange.known({
    required this.litersLeft,
    required this.kmLeft,
    this.emptyOn,
  }) : reason = null;

  const TankRange.unknown(TankRangeUnknown this.reason)
    : litersLeft = null,
      kmLeft = null,
      emptyOn = null;

  final double? litersLeft;
  final double? kmLeft;

  /// Null whenever the car's daily distance is unmeasurable. Projections
  /// elsewhere fall back to an assumed 30 km/day, but printing a calendar date
  /// off a guessed rate invents a fact — km left is arithmetic, a date is a
  /// promise.
  final DateTime? emptyOn;

  final TankRangeUnknown? reason;

  bool get isKnown => reason == null;
}

/// Works out what is in the tank by counting down from the last full one.
///
/// The app never knows the level directly; it knows the tank was full at a
/// known odometer reading, and what has happened since. So the estimate is the
/// capacity, less the fuel burned over the distance driven, plus any partial
/// fills along the way — clamped at both ends, because a tank cannot hold more
/// than it holds nor less than nothing.
///
/// [entries] must be in odometer order, which is what `rawFuelEntriesProvider`
/// already gives.
TankRange estimateTankRange({
  required double? tankCapacityL,
  required double? litersPer100Km,
  required double? kmPerDay,
  required int currentOdometerKm,
  required List<FuelEntry> entries,
  required DateTime today,
}) {
  if (tankCapacityL == null || tankCapacityL <= 0) {
    return const TankRange.unknown(TankRangeUnknown.noTankCapacity);
  }
  if (litersPer100Km == null || litersPer100Km <= 0) {
    return const TankRange.unknown(TankRangeUnknown.noEconomy);
  }

  final lastFull = entries.lastIndexWhere((entry) => entry.fullTank);
  if (lastFull < 0) {
    return const TankRange.unknown(TankRangeUnknown.noFullTank);
  }

  final since = entries.sublist(lastFull + 1);
  if (since.any((entry) => entry.missedFill)) {
    return const TankRange.unknown(TankRangeUnknown.missedFill);
  }

  var liters = tankCapacityL;
  var odometer = entries[lastFull].odometerKm;
  var ranDry = false;

  void burnTo(int reading) {
    // A reading below where we already are is not a car driving backwards, it
    // is a typo or an out-of-order entry. Burning nothing is the safe reading.
    final distance = (reading - odometer).clamp(0, 1 << 31);
    final remaining = liters - distance * litersPer100Km / 100;
    // A litre of tolerance: the bottom of the tank is where rounding lives,
    // and a car sitting on empty is a reading worth printing. Below that the
    // arithmetic has gone somewhere a car cannot.
    if (remaining < -1) {
      ranDry = true;
    }
    liters = remaining.clamp(0.0, tankCapacityL);
    odometer = reading;
  }

  for (final entry in since) {
    burnTo(entry.odometerKm);
    liters = (liters + entry.volumeL).clamp(0.0, tankCapacityL);
  }
  burnTo(currentOdometerKm);

  if (ranDry) {
    return const TankRange.unknown(TankRangeUnknown.unrecordedFill);
  }

  final kmLeft = liters * 100 / litersPer100Km;
  return TankRange.known(
    litersLeft: liters,
    kmLeft: kmLeft,
    emptyOn: kmPerDay == null || kmPerDay <= 0
        ? null
        : today.add(Duration(days: (kmLeft / kmPerDay).round())),
  );
}
