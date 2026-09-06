import '../../../domain/entities/observation.dart';

abstract interface class ObservationRepository {
  Future<List<Observation>> forVehicle(String vehicleId);

  Future<void> add(Observation observation);

  Future<void> update(Observation observation);

  Future<void> delete(String id);
}
