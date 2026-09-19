import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../domain/entities/trip_entry.dart';
import '../../../domain/entities/trip_route.dart';
import '../../../domain/trips/route_trend.dart';
import '../../household/providers/household_providers.dart';
import '../data/route_repository.dart';
import '../data/supabase_route_repository.dart';
import 'fleet_trip_providers.dart';
import 'trip_providers.dart';

final routeRepositoryProvider = Provider<RouteRepository>((ref) {
  return SupabaseRouteRepository(
    ref.watch(supabaseClientProvider),
    cache: ref.watch(readCacheProvider),
  );
});

/// Every named journey in the current garage, by name.
///
/// Empty rather than an error before a household exists: the picker on the
/// start-drive sheet is built before onboarding is necessarily finished.
final routesProvider = FutureProvider<List<TripRoute>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) {
    return const [];
  }
  return ref.watch(routeRepositoryProvider).forHousehold(household.id);
});

/// The garage's routes, the ones this car has lately taken first.
///
/// Alphabetical is a filing order, not a driving one: at the car, the commute
/// is the route somebody wants at the top of the list, and it is the one they
/// drove yesterday. Ordered by this vehicle's own trips rather than the
/// fleet's, because that is the list the screens showing a drive card have
/// already loaded — and because "last taken in this car" is the better guess
/// anyway. Routes this car has never been on keep their alphabetical order,
/// after the rest.
final routesForVehicleProvider = FutureProvider.family<List<TripRoute>, String>(
  (ref, vehicleId) async {
    final routes = await ref.watch(routesProvider.future);
    if (routes.isEmpty) {
      return routes;
    }
    final trips = await ref.watch(tripEntriesProvider(vehicleId).future);
    final lastUsed = <String, DateTime>{};
    for (final trip in trips) {
      if (trip.routeId case final id?) {
        final seen = lastUsed[id];
        if (seen == null || trip.date.isAfter(seen)) {
          lastUsed[id] = trip.date;
        }
      }
    }
    return [...routes]..sort((a, b) {
      final left = lastUsed[a.id];
      final right = lastUsed[b.id];
      if (left == null && right == null) {
        return TripRoute.byName(a, b);
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return right.compareTo(left);
    });
  },
);

/// Journeys filed under one route, across every car.
///
/// Across the fleet on purpose: the commute is the same commute whichever car
/// is taken, and splitting it per vehicle would break exactly the comparison
/// the feature exists for.
final routeTripsProvider = FutureProvider.family<List<TripEntry>, String>((
  ref,
  routeId,
) async {
  final all = await ref.watch(allTripsProvider.future);
  return [
    for (final trip in all)
      if (trip.routeId == routeId) trip,
  ];
});

/// Who has driven a route, for the per-driver filter. Two people on the same
/// commute drive it differently, and comparing across them reads as a trend.
final routeDriversProvider = FutureProvider.family<List<String>, String>((
  ref,
  routeId,
) async {
  final trips = await ref.watch(routeTripsProvider(routeId).future);
  final names = <String>{
    for (final trip in trips)
      if (trip.driver case final driver?)
        if (driver.trim().isNotEmpty) driver.trim(),
  };
  return names.toList()..sort();
});

/// What a trend chart is being asked. A value, so the family caches per
/// question rather than recomputing on every rebuild.
class RouteTrendQuery {
  const RouteTrendQuery({
    required this.routeId,
    this.grouping = RouteGrouping.quarter,
    this.weekdaysOnly = false,
    this.departure = DepartureWindow.any,
    this.driver,
  });

  final String routeId;
  final RouteGrouping grouping;
  final bool weekdaysOnly;
  final DepartureWindow departure;
  final String? driver;

  @override
  bool operator ==(Object other) =>
      other is RouteTrendQuery &&
      other.routeId == routeId &&
      other.grouping == grouping &&
      other.weekdaysOnly == weekdaysOnly &&
      other.departure == departure &&
      other.driver == driver;

  @override
  int get hashCode =>
      Object.hash(routeId, grouping, weekdaysOnly, departure, driver);
}

final routeTrendProvider = FutureProvider.family<RouteTrend, RouteTrendQuery>((
  ref,
  query,
) async {
  final trips = await ref.watch(routeTripsProvider(query.routeId).future);
  return summariseRoute(
    trips,
    grouping: query.grouping,
    weekdaysOnly: query.weekdaysOnly,
    departureFrom: query.departure.from,
    departureTo: query.departure.to,
    driver: query.driver,
  );
});

final routeControllerProvider = AsyncNotifierProvider<RouteController, void>(
  RouteController.new,
);

class RouteController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// The route this name refers to, naming it first if nobody has.
  ///
  /// Returns null when the write failed, so a sheet can stay open on an error
  /// rather than opening a drive filed under nothing.
  Future<TripRoute?> ensure(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    state = const AsyncValue.loading();
    try {
      final household = await ref.read(currentHouseholdProvider.future);
      if (household == null) {
        state = const AsyncValue.data(null);
        return null;
      }
      final repository = ref.read(routeRepositoryProvider);
      final known = await ref.read(routesProvider.future);
      if (TripRoute.matching(trimmed, known) case final existing?) {
        state = const AsyncValue.data(null);
        return existing;
      }
      final created = await _insert(repository, household.id, trimmed);
      ref.invalidate(routesProvider);
      state = const AsyncValue.data(null);
      return created;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return null;
    }
  }

  /// Names it, and treats the unique index as an answer rather than an error.
  ///
  /// Two phones can open the morning commute at the same time, and the second
  /// one wants the route the first just made — not a failure, and not a
  /// second row it is not allowed to have.
  Future<TripRoute> _insert(
    RouteRepository repository,
    String householdId,
    String name,
  ) async {
    try {
      return await repository.add(householdId: householdId, name: name);
    } on AppFailure catch (failure) {
      if (failure.kind != AppFailureKind.conflict) {
        rethrow;
      }
      final fresh = await repository.forHousehold(householdId);
      if (TripRoute.matching(name, fresh) case final existing?) {
        return existing;
      }
      rethrow;
    }
  }

  Future<bool> rename(TripRoute route, String name) {
    return _run(() => ref.read(routeRepositoryProvider).rename(route.id, name));
  }

  Future<bool> delete(TripRoute route) {
    return _run(() => ref.read(routeRepositoryProvider).delete(route.id));
  }

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      ref
        ..invalidate(routesProvider)
        // The journeys carry the route id; a rename or a deletion changes
        // what every one of them reads as.
        ..invalidate(allTripsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }
}
