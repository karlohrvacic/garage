import '../../../domain/entities/household.dart';
import '../../../domain/entities/vehicle.dart';

/// Everything the app needs before it can draw a dashboard: which garages the
/// signed-in user belongs to, and every vehicle they can reach.
///
/// The two used to arrive as chained requests, and the second could not start
/// until the first had returned — the household's id was its argument. On a
/// cold start that was a visible wait at the pump, which is the one place this
/// app is used and the one place it cannot afford one.
class GarageBootstrap {
  const GarageBootstrap({
    required this.households,
    required this.vehiclesByHousehold,
    this.borrowedVehicles = const [],
    this.rolesByHousehold = const {},
  });

  /// Signed out, or signed in and not yet in a garage. Both are ordinary
  /// states rather than errors, so they are the same value.
  static const GarageBootstrap empty = GarageBootstrap(
    households: [],
    vehiclesByHousehold: {},
  );

  final List<Household> households;

  /// Keyed by household id. Archived vehicles are included: the callers that
  /// want only the active ones filter, and the ones that want the archive
  /// would otherwise need a second fetch to get it back.
  final Map<String, List<Vehicle>> vehiclesByHousehold;

  /// Cars reachable through a guest pass rather than through membership.
  ///
  /// They belong to a garage the holder is not in, so they appear under none
  /// of [households] and must not be counted as part of one — a borrowed car
  /// is not yours, and its costs are not your garage's costs.
  final List<Vehicle> borrowedVehicles;

  /// The signed-in user's role in each garage, by household id.
  ///
  /// Fetched with the garages rather than derived from the member list: a
  /// driver's whole presentation — "My cars" instead of the garage, no
  /// owner menu on a car — hangs on the role, and it has to be known before
  /// the first frame, from the cache as much as from the network. A garage
  /// missing from here reads as `member`, which is what every garage was
  /// before roles were fetched.
  final Map<String, String> rolesByHousehold;

  String roleIn(String? householdId) =>
      rolesByHousehold[householdId] ?? 'member';

  /// The vehicles of one garage, already sorted. Null is accepted because the
  /// current household is null until it is chosen, and asking for the vehicles
  /// of no garage is a state the dashboard passes through rather than a bug.
  List<Vehicle> vehiclesFor(String? householdId) {
    if (householdId == null) {
      return const [];
    }
    return vehiclesByHousehold[householdId] ?? const [];
  }
}

/// The app's startup fetch.
abstract interface class GarageBootstrapRepository {
  Future<GarageBootstrap> load();
}
