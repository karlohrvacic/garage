import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/trip_entry.dart';
import '../data/supabase_trip_repository.dart';
import '../data/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return SupabaseTripRepository(ref.watch(supabaseClientProvider));
});

/// A vehicle's trips, newest first.
final tripEntriesProvider = FutureProvider.family<List<TripEntry>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(tripRepositoryProvider).forVehicle(vehicleId);
});
