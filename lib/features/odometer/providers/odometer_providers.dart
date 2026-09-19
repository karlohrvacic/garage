import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/odometer_entry.dart';
import '../../../domain/fuel/odometer_history.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../income/providers/income_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../trips/providers/trip_providers.dart';
import '../data/odometer_repository.dart';
import '../data/supabase_odometer_repository.dart';
import '../../../core/sync/queueing_repositories.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../core/sync/sync_providers.dart';

final odometerRepositoryProvider = Provider<OdometerRepository>((ref) {
  return QueueingOdometerRepository(
    inner: SupabaseOdometerRepository(
      ref.watch(supabaseClientProvider),
      cache: ref.watch(readCacheProvider),
    ),
    queue: ref.watch(pendingWriteStoreProvider),
    now: () => DateTime.now().toUtc(),
    userId: () => ref.read(currentUserIdProvider),
  );
});

/// A vehicle's standalone odometer readings, newest first.
final odometerEntriesProvider =
    FutureProvider.family<List<OdometerEntry>, String>((ref, vehicleId) async {
      return ref.watch(odometerRepositoryProvider).forVehicle(vehicleId);
    });

/// Every odometer sighting a vehicle has, from every source that records one,
/// as one series. This is what distance and rate should be read from — reading only
/// fill-ups is the defect [OdometerHistory] exists to fix.
/// Every odometer reading this vehicle has, exactly as entered.
///
/// Raw on purpose. [odometerSamplesProvider] runs these through
/// [OdometerHistory.sorted], which keeps one reading per day and **drops
/// anything that goes backwards** — right for measuring a rate, and wrong for
/// checking whether a new entry is plausible, because the reading that
/// contradicts the log is precisely the one that gets filtered out. Validation
/// needs to see the contradiction.
final rawOdometerSamplesProvider =
    FutureProvider.family<List<OdometerSample>, String>((ref, vehicleId) async {
      final fuel = await ref.watch(rawFuelEntriesProvider(vehicleId).future);
      final services = await ref.watch(
        serviceEntriesProvider(vehicleId).future,
      );
      final costs = await ref.watch(costEntriesProvider(vehicleId).future);
      final readings = await ref.watch(
        odometerEntriesProvider(vehicleId).future,
      );
      final trips = await ref.watch(tripEntriesProvider(vehicleId).future);
      final income = await ref.watch(incomeEntriesProvider(vehicleId).future);

      return [
        for (final entry in fuel)
          OdometerSample(date: entry.date, km: entry.odometerKm),
        for (final entry in services)
          OdometerSample(date: entry.date, km: entry.odometerKm),
        for (final entry in costs)
          if (entry.odometerKm != null)
            OdometerSample(date: entry.date, km: entry.odometerKm!),
        for (final entry in readings)
          OdometerSample(date: entry.date, km: entry.odometerKm),
        // A trip that ended at a reading has moved the odometer just as surely
        // as a fill-up did; the start reading is redundant with the end.
        for (final entry in trips)
          if (entry.endOdometerKm != null)
            OdometerSample(date: entry.date, km: entry.endOdometerKm!),
        for (final entry in income)
          if (entry.odometerKm != null)
            OdometerSample(date: entry.date, km: entry.odometerKm!),
      ];
    });

final odometerSamplesProvider =
    FutureProvider.family<List<OdometerSample>, String>((ref, vehicleId) async {
      // Judged against today, so a reading dated years out — a fat-fingered
      // year, a bad row in an imported file — cannot drag the rate window into
      // the future or move where the car stands. Every consumer of the series
      // comes through here, which is why the guard sits at this one point.
      return OdometerHistory.sorted(
        await ref.watch(rawOdometerSamplesProvider(vehicleId).future),
        asOf: ref.watch(todayProvider),
      );
    });
