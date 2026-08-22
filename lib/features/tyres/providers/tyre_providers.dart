import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../../domain/maintenance/tyre_wear_projection.dart';
import '../../maintenance/providers/maintenance_providers.dart';
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

/// Estimated remaining life for every set on a vehicle that has been
/// measured enough to project, keyed by [TyreSet.id]. A set missing from the
/// map has not been measured twice, not zero life left.
final tyreWearProjectionsProvider =
    FutureProvider.family<Map<String, TyreWearProjection>, String>((
      ref,
      vehicleId,
    ) async {
      final sets = await ref.watch(tyreSetsProvider(vehicleId).future);
      final rate = await ref.watch(drivingRateProvider(vehicleId).future);
      final today = ref.watch(todayProvider);

      final projections = <String, TyreWearProjection>{};
      for (final set in sets) {
        final projection = TyreWearProjector.project(
          set: set,
          today: today,
          kmPerDay: rate ?? 0,
        );
        if (projection != null) {
          projections[set.id] = projection;
        }
      }
      return projections;
    });
