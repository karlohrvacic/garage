import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/cost_entry.dart';
import '../data/cost_repository.dart';
import '../data/supabase_cost_repository.dart';

final costRepositoryProvider = Provider<CostRepository>((ref) {
  return SupabaseCostRepository(ref.watch(supabaseClientProvider));
});

/// A vehicle's cost entries, newest first.
final costEntriesProvider = FutureProvider.family<List<CostEntry>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(costRepositoryProvider).forVehicle(vehicleId);
});
