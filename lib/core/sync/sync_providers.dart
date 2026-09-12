import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/fuel/data/supabase_fuel_repository.dart';
import '../../features/fuel/providers/fuel_providers.dart';
import '../../features/costs/data/supabase_cost_repository.dart';
import '../../features/maintenance/data/supabase_maintenance_repository.dart';
import '../../features/observations/data/supabase_observation_repository.dart';
import '../../features/trips/data/supabase_trip_repository.dart';
import '../../features/odometer/data/supabase_odometer_repository.dart';
import '../../features/odometer/providers/odometer_providers.dart';
import '../../domain/entities/attachment.dart';
import '../../features/attachments/data/supabase_attachment_repository.dart';
import '../errors/app_failure.dart';
import '../supabase/supabase_client_provider.dart';
import 'pending_write.dart';
import 'queued_files.dart';
import 'replay.dart';
import 'write_queue.dart';

/// Where a photo waits. A seam, so a test can hold one without a disk.
final queuedFileStoreProvider = Provider<QueuedFileStore>((ref) {
  return const PlatformQueuedFileStore();
});

final pendingWriteStoreProvider = Provider<PendingWriteStore>((ref) {
  return SharedPreferencesPendingWriteStore();
});

/// What is waiting to be sent, for the banner and the list.
///
/// Watches the queue rather than reading it once: the decorator keeps a write
/// silently, so without this the banner appears only after something else
/// happened to refresh it — and an entry that is safe but invisible reads to
/// the person holding the phone exactly like one that was lost.
final pendingWritesProvider = FutureProvider<List<PendingWrite>>((ref) async {
  final store = ref.watch(pendingWriteStoreProvider);
  final subscription = store.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);
  return store.all();
});

/// Sends one queued write, by asking the repository that would have sent it.
///
/// Goes to the **Supabase** repositories directly rather than through the
/// queueing decorators: a replay that failed would otherwise re-queue what it
/// is in the middle of replaying.
final pendingWriteSenderProvider =
    Provider<Future<void> Function(PendingWrite)>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return (write) async {
        switch (write.kind) {
          case PendingWriteKind.fuel:
            await SupabaseFuelRepository(
              client,
            ).add(fuelEntryFromRow(write.row));
          case PendingWriteKind.odometer:
            await SupabaseOdometerRepository(
              client,
            ).add(odometerEntryFromRow(write.row));
          case PendingWriteKind.trip:
            await SupabaseTripRepository(
              client,
            ).add(tripEntryFromRow(write.row));
          case PendingWriteKind.cost:
            await SupabaseCostRepository(
              client,
            ).add(costEntryFromRow(write.row));
          case PendingWriteKind.service:
            await SupabaseMaintenanceRepository(
              client,
            ).addServiceEntry(serviceEntryFromRow(write.row));
          case PendingWriteKind.observation:
            await SupabaseObservationRepository(
              client,
            ).add(observationFromRow(write.row));
          case PendingWriteKind.attachment:
            final kept = write.attachment;
            final files = ref.read(queuedFileStoreProvider);
            final bytes = kept == null ? null : await files.read(kept.path);
            if (kept == null || bytes == null) {
              // The file is gone — cleared storage, a reinstall. Nothing can
              // ever send it, so treat it the way the server treats a row it
              // will never accept rather than retrying forever.
              throw const AppFailure(kind: AppFailureKind.notFound);
            }
            await SupabaseAttachmentRepository(client).upload(
              vehicleId: write.row['vehicle_id'] as String,
              kind: AttachmentEntryKind.fromKey(
                write.row['entry_kind'] as String,
              ),
              entryId: write.row['entry_id'] as String,
              fileName: kept.fileName,
              bytes: bytes,
              contentType: kept.contentType,
            );
            await files.discard(kept.path);
        }
      };
    });

final syncControllerProvider = AsyncNotifierProvider<SyncController, void>(
  SyncController.new,
);

class SyncController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// One pass over the queue.
  ///
  /// Safe to call from anywhere and often — resume, a successful read, the
  /// button — because `replayQueue` holds the guard against overlapping runs
  /// itself.
  Future<ReplayReport> run() async {
    final report = await replayQueue(
      queue: ref.read(pendingWriteStoreProvider),
      send: ref.read(pendingWriteSenderProvider),
    );
    if (report.anythingHappened) {
      // Everything an entry could be showing in: the lists it belongs to are
      // refetched rather than patched, which is the same choice realtime
      // already makes and for the same reason.
      ref
        ..invalidate(pendingWritesProvider)
        ..invalidate(rawFuelEntriesProvider)
        ..invalidate(odometerEntriesProvider);
    }
    return report;
  }
}
