import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/observation.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../data/observation_repository.dart';
import '../data/supabase_observation_repository.dart';
import '../../../core/sync/queueing_repositories.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../core/sync/sync_providers.dart';

final observationRepositoryProvider = Provider<ObservationRepository>((ref) {
  // Wrapped, and this is the one it matters most for: you notice a rattle
  // once, while driving, and logging it there and then is the whole point. A
  // write that threw took the memory with it. See
  // [QueueingObservationRepository].
  return QueueingObservationRepository(
    inner: SupabaseObservationRepository(
      ref.watch(supabaseClientProvider),
      cache: ref.watch(readCacheProvider),
    ),
    queue: ref.watch(pendingWriteStoreProvider),
    now: () => DateTime.now().toUtc(),
    userId: () => ref.read(currentUserIdProvider),
  );
});

/// Everything ever noticed about a vehicle, ordered for a screen: what is
/// still going on first, oldest complaint leading.
final observationsProvider = FutureProvider.family<List<Observation>, String>((
  ref,
  vehicleId,
) async {
  final all = await ref
      .watch(observationRepositoryProvider)
      .forVehicle(vehicleId);
  return Observations.forDisplay(all);
});

final observationControllerProvider =
    AsyncNotifierProvider<ObservationController, void>(
      ObservationController.new,
    );

class ObservationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save(Observation observation, {required bool isNew}) {
    return _run(observation.vehicleId, () async {
      final repository = ref.read(observationRepositoryProvider);
      if (isNew) {
        await repository.add(observation);
      } else {
        await repository.update(observation);
      }
    });
  }

  /// Marks the symptom gone. Distinct from recording that a garage did work,
  /// which is [addressedBy] on the entry itself.
  Future<bool> resolve(Observation observation, DateTime on) {
    return _run(observation.vehicleId, () async {
      await ref
          .read(observationRepositoryProvider)
          .update(observation.copyWith(resolvedOn: on));
    });
  }

  /// Puts a settled one back. A noise that came back is the same complaint,
  /// not a new one, and reopening keeps its history in one row.
  Future<bool> reopen(Observation observation) {
    return _run(observation.vehicleId, () async {
      await ref
          .read(observationRepositoryProvider)
          .update(observation.copyWith(clearResolved: true));
    });
  }

  Future<bool> delete(Observation observation) {
    return _run(observation.vehicleId, () async {
      await ref.read(observationRepositoryProvider).delete(observation.id);
      // The photo goes with the note, like every other entry's receipt
      // (decision 129). After the deletion, never before.
      await sweepAttachments(
        ref.read(attachmentRepositoryProvider),
        kind: AttachmentEntryKind.observation,
        entryId: observation.id,
      );
    });
  }

  Future<bool> _run(String vehicleId, Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      ref.invalidate(observationsProvider(vehicleId));
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }
}
