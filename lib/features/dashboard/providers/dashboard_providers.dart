import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/maintenance/bundling.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';

/// Maintenance items across the whole fleet, clustered into suggested single
/// visits using the household's own proximity settings.
final bundlesProvider = FutureProvider<List<MaintenanceBundle>>((ref) async {
  final projections = await ref.watch(householdProjectionsProvider.future);
  final household = await ref.watch(currentHouseholdProvider.future);
  final today = ref.watch(todayProvider);

  return BundlingEngine.bundle(
    projections: projections,
    today: today,
    window: household == null
        ? BundlingWindow.defaults
        : BundlingWindow(
            proximity: Duration(days: household.bundlingWindowDays),
            proximityKm: household.bundlingWindowKm,
          ),
  );
});

/// The one bundle worth putting at the top of the dashboard.
final topBundleProvider = FutureProvider<MaintenanceBundle?>((ref) async {
  final bundles = await ref.watch(bundlesProvider.future);
  return bundles.isEmpty ? null : bundles.first;
});

/// Total logged spend across the fleet: every fuel fill plus every service.
/// In canonical currency (the household's), summed from stored values.
final fleetSpendProvider = FutureProvider<double>((ref) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  var total = 0.0;
  for (final vehicle in vehicles) {
    final fuel = await ref.watch(rawFuelEntriesProvider(vehicle.id).future);
    for (final entry in fuel) {
      total += entry.total ?? 0;
    }
    final services = await ref.watch(serviceEntriesProvider(vehicle.id).future);
    for (final entry in services) {
      total += entry.cost ?? 0;
    }
  }
  return total;
});

/// The fleet's average economy: the mean of each vehicle's own average, so a
/// van and a hatchback contribute equally rather than by distance driven.
final fleetAverageEconomyProvider = FutureProvider<double?>((ref) async {
  final vehicles = await ref.watch(vehiclesProvider.future);
  final values = <double>[];
  for (final vehicle in vehicles) {
    final average = await ref.watch(averageEconomyProvider(vehicle.id).future);
    if (average != null) {
      values.add(average);
    }
  }
  if (values.isEmpty) {
    return null;
  }
  return values.reduce((a, b) => a + b) / values.length;
});
