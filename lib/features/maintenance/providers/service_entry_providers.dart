import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/service_entry.dart';
import '../data/maintenance_repository.dart';
import '../data/supabase_maintenance_repository.dart';

/// Split out of `maintenance_providers.dart` so that anything needing service
/// history — the odometer series, for one — can reach it without importing the
/// projection providers, which in turn need the odometer series. One file per
/// direction is cheaper than a cycle between two.
final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  return SupabaseMaintenanceRepository(ref.watch(supabaseClientProvider));
});

final serviceEntriesProvider =
    FutureProvider.family<List<ServiceEntry>, String>((ref, vehicleId) async {
      final entries = await ref
          .watch(maintenanceRepositoryProvider)
          .serviceEntriesForVehicle(vehicleId);
      return [...entries]..sort((a, b) => b.date.compareTo(a.date));
    });
