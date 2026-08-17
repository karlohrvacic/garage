import '../../../domain/entities/income_entry.dart';

abstract interface class IncomeRepository {
  Future<List<IncomeEntry>> forVehicle(String vehicleId);

  Future<void> add(IncomeEntry entry);

  Future<void> update(IncomeEntry entry);

  Future<void> delete(String id);
}
