import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_log.dart';
import '../../../domain/entities/vehicle.dart';
import '../../vehicles/data/supabase_vehicle_repository.dart';
import 'garage_bootstrap.dart';
import 'garage_bootstrap_cache.dart';
import 'supabase_household_repository.dart';

class SupabaseGarageBootstrapRepository implements GarageBootstrapRepository {
  SupabaseGarageBootstrapRepository(this._client, {GarageBootstrapCache? cache})
    : _cache = cache ?? const NoGarageBootstrapCache();

  final SupabaseClient _client;

  /// Written to on every successful fetch, so the *next* cold start has
  /// something to draw. Never read here: what to do with a cached garage is
  /// the provider's decision, not a repository's.
  final GarageBootstrapCache _cache;

  /// Three requests, issued together: the garages, their cars, and the cars
  /// a guest pass lends this account.
  ///
  /// This was one embedded select — `households` with `vehicles(*)` nested —
  /// which is a single round trip and was wrong. An embed only nests rows
  /// under parents the outer query returned, so a car reachable through a
  /// **guest pass** never came back: its garage is not one of yours.
  ///
  /// The table answers for the garages this account belongs to, and
  /// [_lentVehicles] for everything lent to it. None of the three depends on
  /// another, so `Future.wait` keeps the cost at one round trip's latency.
  /// The table's rows come first, so a car both return keeps the copy that
  /// carries a member's figures (see [garageBootstrapFromRows]).
  @override
  Future<GarageBootstrap> load() async {
    try {
      final results = await Future.wait([
        _client.from('households').select(),
        _client.from('vehicles').select(),
        _lentVehicles(),
      ]);
      final households = results[0];
      final vehicles = [...results[1], ...results[2]];
      if (_client.auth.currentUser?.id case final userId?) {
        // Not awaited: a disk write must not stand between the app and the
        // frame this fetch was for. A failure inside is swallowed by the
        // cache itself.
        unawaited(
          _cache.write(userId, households: households, vehicles: vehicles),
        );
      }
      return garageBootstrapFromRows(
        households: households,
        vehicles: vehicles,
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  /// The cars a guest pass lends this account.
  ///
  /// Not from `vehicles`: since migration 0072 a borrower has no read on the
  /// table at all, because the row carries what the owner paid for the car.
  /// `guest_vehicles` returns what a borrower needs and nothing else.
  ///
  /// A failure here is recorded and costs nothing else. The web app and the
  /// migration ship on the same push in no fixed order, so for a few minutes
  /// the function may not exist, and an account's own garage must not go dark
  /// because a borrowed car could not be fetched.
  Future<List<Map<String, dynamic>>> _lentVehicles() async {
    try {
      final rows = await _client.rpc('guest_vehicles') as List<dynamic>;
      return rows.cast<Map<String, dynamic>>();
    } catch (error) {
      reportFailure(AppFailure.from(error));
      return const [];
    }
  }
}

/// Splits what came back into the shapes the app reads.
///
/// A vehicle whose household is not among [households] is one the caller
/// reaches through a guest pass. Deriving that here rather than trusting which
/// request a row came from keeps the rule in one place: **borrowed is simply
/// "visible, but not in a garage of mine".**
///
/// A car listed twice is kept as it first appears, so the caller lists the
/// member's copy first.
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
  // A car can come back from both reads — somebody who joined the lender's
  // garage after being lent the car — and is one car either way.
  final seen = <String>{};

  for (final row in vehicles) {
    final vehicle = vehicleFromRow(row);
    if (!seen.add(vehicle.id)) {
      continue;
    }
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
