import '../entities/vehicle.dart';

/// What a "log a fill-up" tap from outside the app should do once it lands.
///
/// The launcher's shortcut and home-screen widget carry no context: they are
/// tapped from a home screen, by someone who may have no account, no garage,
/// no car, or five. The rule that turns a garage into a destination is this,
/// and it is here rather than in the screen so it can be reasoned about
/// without a widget test.
sealed class QuickFuelTarget {
  const QuickFuelTarget();

  /// Reads a household's [vehicles] — archived ones included, which is what
  /// the repository returns — and says where the tap should go.
  ///
  /// Archived cars are filtered here rather than at the caller. The caller is
  /// a launcher intent and there is nobody to correct a wrong guess: a garage
  /// holding one live car and one sold one must resolve to the live one, not
  /// silently offer to fill up a car that has been sold.
  static QuickFuelTarget forGarage(List<Vehicle> vehicles) {
    final live = vehicles.where((v) => !v.archived).toList(growable: false);
    return switch (live.length) {
      0 => const NoVehicleToFuel(),
      1 => FuelThisVehicle(live.single.id),
      _ => AskWhichVehicle(live),
    };
  }
}

/// Nothing to log against. The caller falls back to the app's ordinary
/// start-up destination, which for a garage with no car is the screen that
/// explains how to add one.
final class NoVehicleToFuel extends QuickFuelTarget {
  const NoVehicleToFuel();
}

/// One car, so no question worth asking.
final class FuelThisVehicle extends QuickFuelTarget {
  const FuelThisVehicle(this.vehicleId);

  final String vehicleId;
}

/// More than one car, so ask.
///
/// The fuel sheet does not name the vehicle it is writing to, so a guess here
/// is not a guess the user can catch: they would find out by reading the
/// timeline later. One tap is cheaper than a fill-up logged against the wrong
/// car, in the order the caller supplied — which is the garage's own order,
/// by name.
final class AskWhichVehicle extends QuickFuelTarget {
  const AskWhichVehicle(this.vehicles);

  final List<Vehicle> vehicles;
}
