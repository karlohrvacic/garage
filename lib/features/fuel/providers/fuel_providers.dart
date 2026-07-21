import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/fuel_entry.dart';
import '../../../domain/fuel/fuel_economy.dart';
import '../data/fuel_repository.dart';
import '../data/supabase_fuel_repository.dart';

final fuelRepositoryProvider = Provider<FuelRepository>((ref) {
  return SupabaseFuelRepository(ref.watch(supabaseClientProvider));
});

/// Raw entries in odometer order — the order the economy algorithm expects.
final rawFuelEntriesProvider =
    FutureProvider.family<List<FuelEntry>, String>((ref, vehicleId) async {
  return ref.watch(fuelRepositoryProvider).forVehicle(vehicleId);
});

/// The ledger as displayed: newest first.
final fuelEntriesProvider =
    FutureProvider.family<List<FuelEntry>, String>((ref, vehicleId) async {
  final entries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  return entries.reversed.toList(growable: false);
});

final economyPointsProvider =
    FutureProvider.family<List<EconomyPoint>, String>((ref, vehicleId) async {
  final entries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  return FuelEconomy.compute(entries);
});

final averageEconomyProvider =
    FutureProvider.family<double?, String>((ref, vehicleId) async {
  final points = await ref.watch(economyPointsProvider(vehicleId).future);
  return FuelEconomy.average(points);
});

/// The highest odometer reading logged, used to catch typos on entry.
final latestOdometerProvider =
    FutureProvider.family<int?, String>((ref, vehicleId) async {
  final entries = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
  return entries.isEmpty ? null : entries.last.odometerKm;
});
