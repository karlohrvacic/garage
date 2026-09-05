import '../../../domain/entities/vehicle_document.dart';

/// The paperwork held for a vehicle.
///
/// Documents are corrected far more often than entries are: an expiry is
/// retyped every renewal, and the row is meant to be edited rather than
/// replaced, so this interface is upsert-shaped rather than append-shaped.
abstract interface class DocumentRepository {
  Future<List<VehicleDocument>> forVehicle(String vehicleId);

  /// Writes a new document, or corrects one that exists.
  ///
  /// Takes the whole entity rather than a field list: everything on a
  /// document except its type and vehicle is optional, and a dozen named
  /// parameters would drift from the entity the first time one was added.
  Future<void> save(VehicleDocument document);

  Future<void> delete(String id);
}
