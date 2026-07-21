import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/vehicle.dart';
import '../../household/providers/household_providers.dart';
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
  final vehicles =
      await ref.watch(vehicleRepositoryProvider).forHousehold(household.id);
  return [...vehicles]
    ..sort(
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

final vehicleProvider =
    FutureProvider.family<Vehicle?, String>((ref, id) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  for (final vehicle in vehicles) {
    if (vehicle.id == id) {
      return vehicle;
    }
  }
  return null;
});
