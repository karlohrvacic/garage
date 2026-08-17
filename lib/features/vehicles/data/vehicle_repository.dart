import '../../../domain/entities/vehicle.dart';
import '../../../domain/entities/vehicle_transfer.dart';

abstract interface class VehicleRepository {
  Future<List<Vehicle>> forHousehold(String householdId);

  Future<Vehicle> create(Vehicle vehicle);

  Future<void> update(Vehicle vehicle);

  /// Archiving keeps history intact for a vehicle no longer in active use.
  ///
  /// The reversible half of getting a vehicle off the lists, and the one to
  /// reach for: [delete] takes the history with it.
  Future<void> setArchived(String id, bool archived);

  /// Removes one vehicle, and by cascade every fill-up, service, cost,
  /// reading, trip, attachment and rule hanging off it.
  ///
  /// Admin only, enforced by the database
  /// (`supabase/migrations/0020_admin_actions.sql:32`) rather than here.
  Future<void> delete(String id);

  /// Removes every vehicle in a household, and with them, by cascade, all the
  /// fuel, services, costs, attachments and rules hanging off them.
  ///
  /// The way to start over after a bad import. Admin only, enforced by the
  /// database rather than here.
  Future<void> deleteAllForHousehold(String householdId);

  /// Offers this vehicle to another garage and returns the code to hand over.
  ///
  /// An outstanding offer is reused rather than a second one minted, so a
  /// seller who taps twice hands out one code.
  Future<String> offerTransfer(String vehicleId);

  /// Every transfer this household has offered, claimed or not.
  ///
  /// The only record a seller keeps of a vehicle that has left: the vehicle
  /// row moved to the buyer and is unreadable, so nothing else can say a car
  /// was ever here.
  Future<List<VehicleTransfer>> transfersOffered(String householdId);

  /// The transfer code already outstanding for [vehicleId], or null when there
  /// is none live.
  ///
  /// A read, unlike [offerTransfer], which mints one when none exists. The
  /// screen needs to know what is outstanding without creating anything by the
  /// act of looking.
  Future<String?> outstandingTransferCode(String vehicleId);

  /// Redeems a transfer code, moving the vehicle and its whole history into
  /// [householdId]. Returns the vehicle's id.
  Future<String> redeemTransfer({
    required String code,
    required String householdId,
  });
}
