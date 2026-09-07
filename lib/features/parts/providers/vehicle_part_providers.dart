import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/vehicle_part.dart';
import '../data/supabase_vehicle_part_repository.dart';
import '../data/vehicle_part_repository.dart';

final vehiclePartRepositoryProvider = Provider<VehiclePartRepository>((ref) {
  return SupabaseVehiclePartRepository(ref.watch(supabaseClientProvider));
});

/// What this car takes, for every job somebody has recorded a spec for.
final vehiclePartsProvider = FutureProvider.family<List<VehiclePart>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(vehiclePartRepositoryProvider).forVehicle(vehicleId);
});

final vehiclePartControllerProvider =
    AsyncNotifierProvider<VehiclePartController, void>(
      VehiclePartController.new,
    );

class VehiclePartController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save(VehiclePart part) {
    return _run(part.vehicleId, () async {
      await ref.read(vehiclePartRepositoryProvider).save(part);
    });
  }

  Future<bool> delete(VehiclePart part) {
    return _run(part.vehicleId, () async {
      await ref.read(vehiclePartRepositoryProvider).delete(part.id);
    });
  }

  Future<bool> _run(String vehicleId, Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      ref.invalidate(vehiclePartsProvider(vehicleId));
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }
}
