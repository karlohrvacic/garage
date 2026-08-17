import '../../domain/entities/vehicle.dart';

/// Which vehicle a screen should act on, given what it last chose.
///
/// A screen holds the chosen id in its own state, and the fleet can change
/// underneath it: another member transfers a car away, deletes it, or the
/// device switches garage. A dropdown whose value is no longer one of its
/// items throws rather than degrading, so a car that has gone reads as "all
/// vehicles" — which is what the screen showed before anything was chosen.
String? chosenVehicleId(List<Vehicle> vehicles, String? chosen) {
  return vehicles.any((vehicle) => vehicle.id == chosen) ? chosen : null;
}
