import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/trip_draft.dart';
import '../../../domain/entities/trip_entry.dart';
import '../data/supabase_trip_repository.dart';
import '../data/trip_repository.dart';
import 'fleet_trip_providers.dart';

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

/// The drive this vehicle currently has open, or null.
///
/// A separate fetch from [tripEntriesProvider] rather than a filter over it:
/// the trip list deliberately excludes drafts, and a screen that shows the
/// list does not always care about the drive, nor the other way round.
final openTripDraftProvider = FutureProvider.family<TripDraft?, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(tripRepositoryProvider).openDraft(vehicleId);
});

final tripDraftControllerProvider =
    AsyncNotifierProvider<TripDraftController, void>(TripDraftController.new);

class TripDraftController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> start({
    required String vehicleId,
    required DateTime startedAt,
    int? startOdometerKm,
    String? driver,
    String? fromPlace,
  }) {
    return _run(vehicleId, () async {
      await ref
          .read(tripRepositoryProvider)
          .startDraft(
            TripDraft(
              // Empty: the repository lets the database mint the id. A drive
              // is opened once, from one device, so there is no retry to make
              // idempotent the way a saved entry sheet has.
              id: '',
              vehicleId: vehicleId,
              startedAt: startedAt,
              // Filled in by the database from the session; the domain object
              // only needs it to be non-null here.
              createdBy: '',
              startOdometerKm: startOdometerKm,
              driver: driver,
              fromPlace: fromPlace,
            ),
          );
    });
  }

  /// Turns the open drive into a journey. The row keeps its id and its author.
  Future<bool> finish(
    TripDraft draft, {
    required DateTime endedAt,
    int? endOdometerKm,
    double? distanceKm,
    int? minutes,
    TripPurpose purpose = TripPurpose.private,
    String? toPlace,
    String? notes,
  }) {
    return _run(draft.vehicleId, () async {
      final trip = finishDraft(
        draft,
        endedAt: endedAt,
        endOdometerKm: endOdometerKm,
        distanceKm: distanceKm,
        minutes: minutes,
        purpose: purpose,
        toPlace: toPlace,
        notes: notes,
      );
      await ref.read(tripRepositoryProvider).update(trip);
    });
  }

  Future<bool> discard(TripDraft draft) {
    return _run(draft.vehicleId, () async {
      await ref.read(tripRepositoryProvider).discardDraft(draft.id);
    });
  }

  /// Returns whether the write landed, so a caller can hold a sheet open on
  /// failure instead of closing over an error nobody read.
  Future<bool> _run(String vehicleId, Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      ref
        ..invalidate(openTripDraftProvider(vehicleId))
        ..invalidate(tripEntriesProvider(vehicleId))
        ..invalidate(allTripsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }
}
