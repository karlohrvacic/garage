import '../../../domain/entities/odometer_entry.dart';

abstract interface class OdometerRepository {
  Future<List<OdometerEntry>> forVehicle(String vehicleId);

  Future<void> add(OdometerEntry entry);

  Future<void> update(OdometerEntry entry);

  Future<void> delete(String id);
}
