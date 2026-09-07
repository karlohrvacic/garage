import '../../../domain/entities/guest_pass.dart';
import '../../../domain/entities/service_entry.dart';

abstract interface class GuestPassRepository {
  /// Every pass ever minted for this vehicle, live or finished. The owner's
  /// view: "who has this car been lent to" is the question it answers.
  Future<List<GuestPass>> forVehicle(String vehicleId);

  /// Mints a pass and returns its code.
  ///
  /// A window rather than a length: a car lent from Friday to Sunday is the
  /// ordinary case, and "for four days" cannot say it.
  Future<String> create({
    required String vehicleId,
    required DateTime endsAt,
    DateTime? startsAt,
    String? label,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
    bool canViewPrices = false,
  });

  /// Moves a pass's end. Keeps the code its holder already has, and keeps
  /// what they logged attached to one loan — which reissuing would not.
  Future<void> extend(String id, DateTime endsAt);

  /// Takes a pass back. The rows its holder logged stay where they are.
  Future<void> revoke(String id);

  /// Claims a pass. Returns the id of the vehicle it opens.
  Future<String> redeem(String code);

  /// The passes the signed-in user holds, rather than the ones they issued.
  Future<List<GuestPass>> mine();

  /// What was done to this vehicle, as the caller is allowed to see it.
  ///
  /// Costs come back null for a guest whose pass does not carry prices. That
  /// decision is the database's — see `guest_service_history` — because a row
  /// policy cannot hide a column, and hiding it here would be a suggestion
  /// rather than a rule.
  Future<List<ServiceEntry>> serviceHistory(String vehicleId);
}
