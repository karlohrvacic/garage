import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/service_entry.dart';
import '../data/maintenance_repository.dart';
import '../data/supabase_maintenance_repository.dart';
import '../../../core/sync/queueing_repositories.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../core/sync/sync_providers.dart';

/// Split out of `maintenance_providers.dart` so that anything needing service
/// history — the odometer series, for one — can reach it without importing the
/// projection providers, which in turn need the odometer series. One file per
/// direction is cheaper than a cycle between two.
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  // Wrapped for the service entry only: a workshop is usually a building with
  // a concrete roof, and the record of work done there cannot be recovered by
  // trying again later. Rules are left alone on purpose — a standing
  // arrangement is a preference the user can simply make again. See
  // [QueueingMaintenanceRepository].
  return QueueingMaintenanceRepository(
    inner: SupabaseMaintenanceRepository(
      ref.watch(supabaseClientProvider),
      cache: ref.watch(readCacheProvider),
    ),
    queue: ref.watch(pendingWriteStoreProvider),
    now: () => DateTime.now().toUtc(),
    userId: () => ref.read(currentUserIdProvider),
  );
});

final serviceEntriesProvider =
    FutureProvider.family<List<ServiceEntry>, String>((ref, vehicleId) async {
      final entries = await ref
          .watch(maintenanceRepositoryProvider)
          .serviceEntriesForVehicle(vehicleId);
      return [...entries]..sort((a, b) => b.date.compareTo(a.date));
    });
