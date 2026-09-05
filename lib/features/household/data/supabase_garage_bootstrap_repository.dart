import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/vehicle.dart';
import '../../vehicles/data/supabase_vehicle_repository.dart';
import 'garage_bootstrap.dart';
import 'supabase_household_repository.dart';

class SupabaseGarageBootstrapRepository implements GarageBootstrapRepository {
  SupabaseGarageBootstrapRepository(this._client);

  final SupabaseClient _client;

  /// Two selects, issued together.
  ///
  /// This was one embedded select — `households` with `vehicles(*)` nested —
  /// which is a single round trip and was wrong. An embed only nests rows
  /// under parents the outer query returned, so a car reachable through a
  /// **guest pass** never came back: its garage is not one of yours. The
  /// database was returning it and the app was not asking.
  ///
  /// Fetching `vehicles` in its own right asks the question the policies
  /// actually answer — every vehicle this caller may see, however they may see
  /// it. The two requests do not depend on each other, so `Future.wait` keeps
  /// the cost at one round trip's latency, which is the point of doing this at
  /// all.
  @override
  Future<GarageBootstrap> load() async {
    try {
      final results = await Future.wait([
        _client.from('households').select(),
        _client.from('vehicles').select(),
      ]);
      return garageBootstrapFromRows(
        households: results[0],
        vehicles: results[1],
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

/// Splits what came back into the shapes the app reads.
///
/// A vehicle whose household is not among [households] is one the caller
/// reaches through a guest pass. Deriving that here rather than asking the
/// database a third time keeps the rule in one place: **borrowed is simply
/// "visible, but not in a garage of mine".**
GarageBootstrap garageBootstrapFromRows({
  required List<Map<String, dynamic>> households,
  required List<Map<String, dynamic>> vehicles,
}) {
  int byNickname(Vehicle a, Vehicle b) =>
      a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase());

  final mapped = households.map(householdFromRow).toList(growable: false);
  final mine = {for (final household in mapped) household.id};

  final byHousehold = <String, List<Vehicle>>{
    for (final household in mapped) household.id: <Vehicle>[],
  };
  final borrowed = <Vehicle>[];

  for (final row in vehicles) {
    final vehicle = vehicleFromRow(row);
    if (mine.contains(vehicle.householdId)) {
      byHousehold[vehicle.householdId]!.add(vehicle);
    } else {
      borrowed.add(vehicle);
    }
  }

  for (final list in byHousehold.values) {
    list.sort(byNickname);
  }
  borrowed.sort(byNickname);

  return GarageBootstrap(
    households: mapped,
    vehiclesByHousehold: byHousehold,
    borrowedVehicles: borrowed,
  );
}
