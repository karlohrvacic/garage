import '../../../domain/entities/guest_pass.dart';

abstract interface class GuestPassRepository {
  /// Every pass ever minted for this vehicle, live or finished. The owner's
  /// view: "who has this car been lent to" is the question it answers.
  Future<List<GuestPass>> forVehicle(String vehicleId);

  /// Mints a pass and returns its code.
  Future<String> create({
    required String vehicleId,
    required int validDays,
    String? label,
    DateTime? startsAt,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
  });

  /// Takes a pass back. The rows its holder logged stay where they are.
  Future<void> revoke(String id);

  /// Claims a pass. Returns the id of the vehicle it opens.
  Future<String> redeem(String code);

  /// The passes the signed-in user holds, rather than the ones they issued.
  Future<List<GuestPass>> mine();
}
