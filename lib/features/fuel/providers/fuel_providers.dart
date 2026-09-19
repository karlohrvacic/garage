import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../../domain/fuel/full_tank_range.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/fuel_repository.dart';
import '../data/supabase_fuel_repository.dart';
import '../../../core/sync/queueing_repositories.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../core/sync/sync_providers.dart';

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  // Wrapped, so a fill-up typed where there is no signal is kept rather than
  // lost. The decorator is transparent: it queues only what the network could
  // not carry, and passes every other failure straight through.
  return QueueingFuelRepository(
    inner: SupabaseFuelRepository(
      ref.watch(supabaseClientProvider),
      cache: ref.watch(readCacheProvider),
    ),
    queue: ref.watch(pendingWriteStoreProvider),
    now: () => DateTime.now().toUtc(),
    userId: () => ref.read(currentUserIdProvider),
  );
});

/// Raw entries in odometer order — the order the economy algorithm expects.
final rawFuelEntriesProvider = FutureProvider.family<List<FuelEntry>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(fuelRepositoryProvider).forVehicle(vehicleId);
});

/// The ledger as displayed: newest first.
final fuelEntriesProvider = FutureProvider.family<List<FuelEntry>, String>((
  ref,
  vehicleId,
) async {
  final entries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  return entries.reversed.toList(growable: false);
});

final economyPointsProvider = FutureProvider.family<List<EconomyPoint>, String>(
  (ref, vehicleId) async {
    final entries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
    final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
    // The vehicle's own fuel is what an unnamed fill is taken to be, so a car
    // that gains a second tank does not split its existing history into a
    // chain of unnamed fills and a chain of named ones.
    return FuelEconomy.compute(
      entries,
      primaryFuelKey: vehicle?.isBiFuel ?? false ? vehicle!.fuelTypeKey : null,
    );
  },
);

/// A vehicle's economy split by fuel, for a car that takes more than one.
/// Empty for the ordinary single-fuel car, where the split is the whole log.
final economyByFuelProvider =
    FutureProvider.family<Map<String, List<EconomyPoint>>, String>((
      ref,
      vehicleId,
    ) async {
      final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
      if (!(vehicle?.isBiFuel ?? false)) {
        return const {};
      }
      final points = await ref.watch(economyPointsProvider(vehicleId).future);
      final byFuel = <String, List<EconomyPoint>>{};
      for (final point in points) {
        final key = point.fuelTypeKey;
        if (key != null) {
          (byFuel[key] ??= []).add(point);
        }
      }
      return byFuel;
    });

/// The car's lifetime economy, in what it mainly takes.
///
/// Over the tanks of that energy alone. A plug-in hybrid kept as petrol logs
/// its charges beside its fills, and every reader of this figure — the fuel
/// log, the vehicle page, the fleet strip, the calculator — reads it in the
/// car's own units: averaged in, the charges added kilowatt-hours to litres.
/// Petrol and LPG are both litres and stay blended, as the vehicle page says
/// above its split by fuel.
final averageEconomyProvider = FutureProvider.family<double?, String>((
  ref,
  vehicleId,
) async {
  final points = await ref.watch(economyPointsProvider(vehicleId).future);
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  final energy = vehicle == null
      ? EnergyType.liquid
      : EnergyType.forFuelKey(vehicle.fuelTypeKey);
  return FuelEconomy.average([
    for (final point in points)
      if (EnergyType.forEntry(point.fuelTypeKey, vehicle: energy) == energy)
        point,
  ]);
});

/// How far a full tank goes on this car, measured over its closed tanks.
///
/// Null for a car with no tank capacity recorded, no closed tank to measure,
/// or no tank at all: [Vehicle.tankCapacityL] is litres, and a battery's
/// capacity is not modelled anywhere, so an electric car has nothing here.
final fullTankRangeProvider = FutureProvider.family<FullTankRange?, String>((
  ref,
  vehicleId,
) async {
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  if (vehicle == null ||
      EnergyType.forFuelKey(vehicle.fuelTypeKey).isElectric) {
    return null;
  }
  final points = await ref.watch(economyPointsProvider(vehicleId).future);
  return fullTankRange(
    tankCapacityL: vehicle.tankCapacityL,
    // One fuel only, on a car that takes two. `economyPointsProvider` returns
    // both chains merged, and a tank capacity belongs to one of them: blended,
    // the best and worst tanks would be reporting which fuel was in the car
    // rather than how it was driven, and both would be divided into a
    // capacity that is only the petrol tank's.
    points: vehicle.isBiFuel
        ? points
              .where((point) => point.fuelTypeKey == vehicle.fuelTypeKey)
              .toList(growable: false)
        : points,
  );
});
