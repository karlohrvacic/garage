import '../../../domain/entities/trip_draft.dart';
import '../../../domain/entities/trip_entry.dart';

abstract interface class TripRepository {
  /// Finished journeys only. A drive still under way is not a trip yet and
  /// would have no distance to show.
  Future<List<TripEntry>> forVehicle(String vehicleId);

  Future<void> add(TripEntry entry);

  Future<void> update(TripEntry entry);

  Future<void> delete(String id);

  /// The vehicle's drive in progress, or null. At most one can exist — the
  /// database holds a car to one journey at a time.
  Future<TripDraft?> openDraft(String vehicleId);

  /// Opens a drive. Fails if the car already has one open.
  Future<void> startDraft(TripDraft draft);

  /// Abandons a drive without recording a journey. Distinct from [delete] only
  /// in intent, which is worth naming at the call site.
  Future<void> discardDraft(String id);
}
