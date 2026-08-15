import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/tyre_set.dart';
import '../data/supabase_tyre_repository.dart';
import '../data/tyre_repository.dart';

final tyreRepositoryProvider = Provider<TyreRepository>((ref) {
  return SupabaseTyreRepository(ref.watch(supabaseClientProvider));
});

/// The tyre sets a vehicle owns, oldest first, each with its tread history.
final tyreSetsProvider = FutureProvider.family<List<TyreSet>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(tyreRepositoryProvider).forVehicle(vehicleId);
});

/// The set currently on the car, if the household tracks any.
final fittedTyreSetProvider = FutureProvider.family<TyreSet?, String>((
  ref,
  vehicleId,
) async {
  final sets = await ref.watch(tyreSetsProvider(vehicleId).future);
  for (final set in sets) {
    if (set.fitted) {
      return set;
    }
  }
  return null;
});
