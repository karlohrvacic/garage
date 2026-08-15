import '../../../domain/entities/tyre_set.dart';

/// The tyre sets a vehicle's household owns, and their tread history.
abstract interface class TyreRepository {
  Future<List<TyreSet>> forVehicle(String vehicleId);

  Future<void> addSet({
    required String vehicleId,
    required String name,
    required TyreSeason season,
    String? size,
    String? storageLocation,
  });

  /// Puts a set on the car and takes off whatever was on it. One set at a
  /// time is what the vehicle physically allows, and the database enforces it.
  Future<void> fitSet({required String vehicleId, required String setId});

  Future<void> retireSet(String setId);

  Future<void> deleteSet(String setId);

  Future<void> addReading({
    required String tyreSetId,
    required DateTime date,
    int? odometerKm,
    double? frontLeftMm,
    double? frontRightMm,
    double? rearLeftMm,
    double? rearRightMm,
  });
}
