import '../../../domain/entities/trip_route.dart';

abstract interface class RouteRepository {
  /// Every named journey in the garage, in the order a picker should show
  /// them.
  Future<List<TripRoute>> forHousehold(String householdId);

  /// Names a new one and returns it with the id the database minted, which
  /// the caller needs to file the drive it is about to open.
  Future<TripRoute> add({required String householdId, required String name});

  Future<void> rename(String id, String name);

  /// Forgets the name. The journeys stay: `on delete set null` in 0061 keeps
  /// every drive that used it, unfiled.
  Future<void> delete(String id);
}
