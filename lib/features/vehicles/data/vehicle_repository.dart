import '../../../domain/entities/vehicle.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> forHousehold(String householdId);

  Future<Vehicle> create(Vehicle vehicle);

  Future<void> update(Vehicle vehicle);

  /// Archiving keeps history intact for a vehicle no longer in active use,
  /// which is why vehicles are never hard-deleted from the UI.
  Future<void> setArchived(String id, bool archived);

  /// Removes every vehicle in a household, and with them, by cascade, all the
  /// fuel, services, costs, attachments and rules hanging off them.
  ///
  /// The way to start over after a bad import. Admin only, enforced by the
  /// database rather than here.
  Future<void> deleteAllForHousehold(String householdId);

  /// Offers this vehicle to another garage and returns the code to hand over.
  ///
  /// An outstanding offer is reused rather than a second one minted, so a
  /// seller who taps twice hands out one code.
  Future<String> offerTransfer(String vehicleId);

  /// Redeems a transfer code, moving the vehicle and its whole history into
  /// [householdId]. Returns the vehicle's id.
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  });
}
