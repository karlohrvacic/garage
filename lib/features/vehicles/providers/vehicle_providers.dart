import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/vehicle.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../data/supabase_vehicle_repository.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return SupabaseVehicleRepository(ref.watch(supabaseClientProvider));
});

/// Every vehicle in the household, archived included. Feature lists filter
/// from here so one fetch serves them all.
final allVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) {
    return const [];
  }
  final vehicles = await ref
      .watch(vehicleRepositoryProvider)
      .forHousehold(household.id);
  return [...vehicles]..sort(
    (a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
  );
});

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  return vehicles.where((v) => !v.archived).toList(growable: false);
});

final archivedVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  return vehicles.where((v) => v.archived).toList(growable: false);
});

final vehicleProvider = FutureProvider.family<Vehicle?, String>((
  ref,
  id,
) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  for (final vehicle in vehicles) {
    if (vehicle.id == id) {
      return vehicle;
    }
  }
  return null;
});

/// The vehicle's current odometer as best the log knows it: the highest of
/// the manual baseline and every logged fuel, service, and cost reading.
/// Updating it manually is editing the vehicle's odometer; logging anything
/// with a higher reading moves it automatically.
final currentOdometerProvider = FutureProvider.family<int?, String>((
  ref,
  vehicleId,
) async {
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  if (vehicle == null) {
    return null;
  }
  var current = vehicle.baselineOdometerKm;
  final fuel = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  for (final entry in fuel) {
    if (entry.odometerKm > current) {
      current = entry.odometerKm;
    }
  }
  final services = await ref.watch(serviceEntriesProvider(vehicleId).future);
  for (final entry in services) {
    if (entry.odometerKm > current) {
      current = entry.odometerKm;
    }
  }
  final costs = await ref.watch(costEntriesProvider(vehicleId).future);
  for (final entry in costs) {
    if ((entry.odometerKm ?? 0) > current) {
      current = entry.odometerKm!;
    }
  }
  return current;
});
