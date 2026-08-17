import '../../../domain/entities/trip_entry.dart';

abstract interface class TripRepository {
  Future<List<TripEntry>> forVehicle(String vehicleId);

  Future<void> add(TripEntry entry);

  Future<void> update(TripEntry entry);

  Future<void> delete(String id);
}
