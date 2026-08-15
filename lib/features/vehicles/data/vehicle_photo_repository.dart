import 'dart:typed_data';

/// Where a vehicle's photo lives in the `vehicle-photos` bucket.
abstract final class VehiclePhotos {
  /// `<household id>/<vehicle id>` — household first, because the storage
  /// policy reads the first path segment as the tenancy key.
  ///
  /// One vehicle has one photo, at one fixed path: a new upload replaces the
  /// old rather than piling up orphans nobody can see.
  static String pathFor({
    required String householdId,
    required String vehicleId,
  }) => '$householdId/$vehicleId';
}

/// The photo shown on a vehicle. Screens depend on this, never on Storage
/// directly, so the backend can be faked in tests.
abstract interface class VehiclePhotoRepository {
  /// Stores [bytes] as this vehicle's photo and returns the stored path.
  Future<String> upload({
    required String householdId,
    required String vehicleId,
    required Uint8List bytes,
    String? contentType,
  });

  /// A short-lived link for showing the photo, or null when there is none.
  /// The bucket is private, so nothing is readable without one.
  Future<Uri?> viewUrl(String? path);

  Future<void> delete(String path);
}
