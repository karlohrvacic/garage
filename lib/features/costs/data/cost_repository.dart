import '../../../domain/entities/cost_entry.dart';

abstract interface class CostRepository {
  Future<List<CostEntry>> forVehicle(String vehicleId);

  Future<void> add(CostEntry entry);

  Future<void> update(CostEntry entry);

  Future<void> delete(String id);
}
