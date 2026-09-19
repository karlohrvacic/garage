import '../../../domain/entities/incident.dart';

abstract interface class IncidentRepository {
  Future<List<Incident>> forVehicle(String vehicleId);

  Future<void> add(Incident incident);

  Future<void> update(Incident incident);

  Future<void> delete(String id);
}
