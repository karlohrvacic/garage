import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/cost_entry.dart';
import '../data/cost_repository.dart';
import '../data/supabase_cost_repository.dart';
import '../../../core/sync/queueing_repositories.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../core/sync/sync_providers.dart';

final costRepositoryProvider = Provider<CostRepository>((ref) {
  // Wrapped: a receipt is taken where the work was done, which is often a
  // building with a concrete roof. See [QueueingCostRepository].
  return QueueingCostRepository(
    inner: SupabaseCostRepository(
      ref.watch(supabaseClientProvider),
      cache: ref.watch(readCacheProvider),
    ),
    queue: ref.watch(pendingWriteStoreProvider),
    now: () => DateTime.now().toUtc(),
    userId: () => ref.read(currentUserIdProvider),
  );
});

/// A vehicle's cost entries, newest first.
final costEntriesProvider = FutureProvider.family<List<CostEntry>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(costRepositoryProvider).forVehicle(vehicleId);
});
