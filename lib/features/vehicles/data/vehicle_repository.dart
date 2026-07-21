import '../../../domain/entities/vehicle.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> forHousehold(String householdId);

  Future<Vehicle> create(Vehicle vehicle);

  Future<void> update(Vehicle vehicle);

  /// Archiving keeps history intact for a vehicle no longer in active use,
  /// which is why vehicles are never hard-deleted from the UI.
  Future<void> setArchived(String id, bool archived);
}
