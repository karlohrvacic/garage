import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/vehicle.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/household_providers.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../data/supabase_vehicle_photo_repository.dart';
import '../data/supabase_vehicle_repository.dart';
import '../data/vehicle_photo_repository.dart';
import '../../../domain/fuel/energy_type.dart';
import '../data/recall_lookup.dart';
import '../data/vin_decoder.dart';
import '../data/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return SupabaseVehicleRepository(ref.watch(supabaseClientProvider));
});

/// VIN lookups against the free government registry. A provider so the vehicle
/// form can be tested without reaching the network.
final vinDecoderProvider = Provider<VinDecoder>((ref) => VinDecoder());

final recallLookupProvider = Provider<RecallLookup>((ref) => RecallLookup());

final vehiclePhotoRepositoryProvider = Provider<VehiclePhotoRepository>((ref) {
  return SupabaseVehiclePhotoRepository(ref.watch(supabaseClientProvider));
});

/// A link for showing this vehicle's photo, or null when it has none. The
/// bucket is private, so the link is signed and short-lived.
final vehiclePhotoUrlProvider = FutureProvider.family<Uri?, String>((
  ref,
  vehicleId,
) async {
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  if (vehicle?.photoUrl == null) {
    return null;
  }
  return ref.watch(vehiclePhotoRepositoryProvider).viewUrl(vehicle!.photoUrl);
});

/// Open safety recalls for a vehicle, or an empty list when it is not
/// identified well enough to ask. A failed lookup is an error state the
/// maintenance tab renders quietly — recalls are a bonus, not the screen.
final vehicleRecallsProvider = FutureProvider.family<List<Recall>, String>((
  ref,
  vehicleId,
) async {
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  if (vehicle == null) {
    return const [];
  }
  return ref
      .watch(recallLookupProvider)
      .forVehicle(make: vehicle.make, model: vehicle.model, year: vehicle.year);
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

/// What the vehicle takes on: litres at a pump, or kilowatt-hours at a
/// charger. Drives the units every fuel surface shows.
final vehicleEnergyProvider = Provider.family<EnergyType, String>((
  ref,
  vehicleId,
) {
  final vehicle = ref.watch(vehicleProvider(vehicleId)).value;
  return vehicle == null
      ? EnergyType.liquid
      : EnergyType.forFuelKey(vehicle.fuelTypeKey);
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
