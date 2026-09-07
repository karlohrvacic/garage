import '../../../domain/entities/vehicle_part.dart';

abstract interface class VehiclePartRepository {
  Future<List<VehiclePart>> forVehicle(String vehicleId);

  /// Writes the spec for one job. An upsert, because "one answer per job per
  /// car" is a unique constraint in the table and a correction is the common
  /// case: somebody looked the viscosity up again and got a better answer.
  Future<void> save(VehiclePart part);

  Future<void> delete(String id);
}
