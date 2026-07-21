import '../../../domain/entities/fuel_entry.dart';

abstract interface class FuelRepository {
  Future<List<FuelEntry>> forVehicle(String vehicleId);

  Future<void> add(FuelEntry entry);

  Future<void> update(FuelEntry entry);

  Future<void> delete(String id);
}
