import '../../../domain/entities/vehicle_assignment.dart';

/// The company layer above the car: who has which one, and what the
/// administrator does about money and receipts. Screens depend on this,
/// never on Supabase, so the console can be tested without a network.
abstract interface class CompanyRepository {
  /// The whole log for these cars, newest window first. Empty for no cars,
  /// without a request.
  Future<List<VehicleAssignment>> assignmentsForVehicles(
    List<String> vehicleIds,
  );

  /// The signed-in driver's own windows, which is all the policy shows them.
  Future<List<VehicleAssignment>> mine();

  /// Closes the open assignment the day before [on], writes the reading as
  /// an odometer entry, and opens the next for [toUserId] — or, with no
  /// driver, only takes the car back. One call, one transaction
  /// (`hand_over_vehicle`, migration 0080). Returns the new assignment's id,
  /// or null when the car was only taken back.
  Future<String?> handOver({
    required String vehicleId,
    required DateTime on,
    int? odometerKm,
    String? toUserId,
    String? note,
  });

  /// The driver's sign-off on their own assignment.
  Future<void> confirm(String assignmentId);

  /// Removes a window from the log. Admins only, enforced by the database;
  /// the readings the handover wrote stay, since they are readings.
  Future<void> deleteAssignment(String id);

  /// Stamps entries paid back. [table] is `fuel_entries`, `service_entries`
  /// or `cost_entries`; the trigger refuses anybody but an admin.
  Future<void> markReimbursed({
    required String table,
    required List<String> ids,
    required DateTime at,
  });

  /// Asks the server to push "receipt missing" to the driver's phones.
  Future<void> requestReceiptReminder({
    required String vehicleId,
    required String kind,
    required String entryId,
    required String driverId,
  });
}
