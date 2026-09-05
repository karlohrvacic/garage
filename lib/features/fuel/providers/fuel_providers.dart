import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/energy_type.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../../../domain/fuel/tank_range.dart';
import '../../maintenance/providers/maintenance_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/fuel_repository.dart';
import '../data/supabase_fuel_repository.dart';
import '../../../core/sync/queueing_repositories.dart';
import '../../../core/sync/sync_providers.dart';

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  // Wrapped, so a fill-up typed where there is no signal is kept rather than
  // lost. The decorator is transparent: it queues only what the network could
  // not carry, and passes every other failure straight through.
  return QueueingFuelRepository(
    inner: SupabaseFuelRepository(ref.watch(supabaseClientProvider)),
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

final averageEconomyProvider = FutureProvider.family<double?, String>((
  ref,
  vehicleId,
) async {
  final points = await ref.watch(economyPointsProvider(vehicleId).future);
  return FuelEconomy.average(points);
});

/// The newest fill-up, or null on a vehicle with no fuel history. The log is
/// in odometer order, so that is the entry at the end of it.
final latestFuelEntryProvider = FutureProvider.family<FuelEntry?, String>((
  ref,
  vehicleId,
) async {
  final entries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  return entries.isEmpty ? null : entries.last;
});

/// What is left in the tank, and when it runs out.
///
/// Null — not an unknown [TankRange] — for a car that does not have a tank:
/// [Vehicle.tankCapacityL] is litres, and a battery's capacity is not modelled
/// anywhere, so an electric car has nothing here to be uncertain about.
final tankRangeProvider = FutureProvider.family<TankRange?, String>((
  ref,
  vehicleId,
) async {
  final vehicle = await ref.watch(vehicleProvider(vehicleId).future);
  if (vehicle == null ||
      EnergyType.forFuelKey(vehicle.fuelTypeKey).isElectric) {
    return null;
  }
  final odometer = await ref.watch(currentOdometerProvider(vehicleId).future);
  if (odometer == null) {
    return null;
  }
  return estimateTankRange(
    tankCapacityL: vehicle.tankCapacityL,
    litersPer100Km: await ref.watch(averageEconomyProvider(vehicleId).future),
    kmPerDay: await ref.watch(drivingRateProvider(vehicleId).future),
    currentOdometerKm: odometer,
    entries: await ref.watch(rawFuelEntriesProvider(vehicleId).future),
    today: DateTime.now().toUtc(),
  );
});
