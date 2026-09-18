import '../../../domain/entities/code_description.dart';
import '../../../domain/entities/guest_pass.dart';
import '../../../domain/entities/service_entry.dart';
import '../../../domain/entities/vehicle_briefing.dart';

abstract interface class GuestPassRepository {
  /// Every pass ever minted for this vehicle, live or finished. The owner's
  /// view: "who has this car been lent to" is the question it answers.
  Future<List<GuestPass>> forVehicle(String vehicleId);

  /// The passes on [vehicleIds] in one request, for whatever shows several
  /// cars at once: the dashboard and the car list mark the ones on loan.
  Future<List<GuestPass>> forVehicles(List<String> vehicleIds);

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
    bool canLogCosts = false,
    bool canViewHistory = false,
    bool canViewPrices = false,
  });

  /// Moves a pass's end. Keeps the code its holder already has, and keeps
  /// what they logged attached to one loan — which reissuing would not.
  Future<void> extend(String id, DateTime endsAt);

  /// Takes a pass back. The rows its holder logged stay where they are.
  Future<void> revoke(String id);

  /// The holder's own end of it: handing the car back before the pass runs
  /// out. Distinct from the owner withdrawing it, and from expiry.
  Future<void> giveBack(String id);

  /// Claims a pass. Returns the id of the vehicle it opens.
  Future<String> redeem(String code);

  /// What a code is, without spending it. Null when no code like it
  /// exists — which is also the answer for a wrong guess.
  Future<CodeDescription?> describe(String code);

  /// Changes what a pass allows, on the code its holder already has.
  Future<void> updatePermissions(GuestPass pass);

  /// The passes the signed-in user holds, rather than the ones they issued.
  Future<List<GuestPass>> mine();

  /// What was done to this vehicle, as the caller is allowed to see it.
  ///
  /// Costs come back null for a guest whose pass does not carry prices. That
  /// decision is the database's — see `guest_service_history` — because a row
  /// policy cannot hide a column, and hiding it here would be a suggestion
  /// rather than a rule.
  Future<List<ServiceEntry>> serviceHistory(String vehicleId);

  /// What a borrower is always shown: the real odometer, the papers that run
  /// out, what is known to be wrong, and the tyres on it. Null when the caller
  /// may not see the car at all — including a pass that ran out mid-session,
  /// which is an ending rather than an error.
  Future<VehicleBriefing?> briefing(String vehicleId);
}
