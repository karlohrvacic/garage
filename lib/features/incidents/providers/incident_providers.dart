import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/clock.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/sync/read_cache_providers.dart';
import '../../../domain/entities/attachment.dart';
import '../../../domain/entities/incident.dart';
import '../../attachments/providers/attachment_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/incident_repository.dart';
import '../data/supabase_incident_repository.dart';

/// Not wrapped in the offline queue, unlike an observation: a queued write
/// needs a `PendingWriteKind`, a sender and a row in the retry screen, and
/// an incident is reported from the office or the depot far more often than
/// from a car park with no signal. Recorded as a known gap.
final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return SupabaseIncidentRepository(
    ref.watch(supabaseClientProvider),
    cache: ref.watch(readCacheProvider),
  );
});

/// Everything reported about a vehicle, ordered for a screen.
final incidentsProvider = FutureProvider.family<List<Incident>, String>((
  ref,
  vehicleId,
) async {
  final all = await ref.watch(incidentRepositoryProvider).forVehicle(vehicleId);
  return Incidents.forDisplay(all);
});

/// Every car's incidents, for the console. Archived cars included, as the
/// reimbursements and the pack include them: a fine that arrives after the
/// sale is still the fleet's to settle.
final fleetIncidentsProvider = FutureProvider<List<Incident>>((ref) async {
  final vehicles = await ref.watch(allVehiclesProvider.future);
  final perVehicle = await Future.wait([
    for (final vehicle in vehicles)
      ref.watch(incidentsProvider(vehicle.id).future),
  ]);
  return Incidents.forDisplay([for (final list in perVehicle) ...list]);
});

final incidentControllerProvider =
    AsyncNotifierProvider<IncidentController, void>(IncidentController.new);

class IncidentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> save(Incident incident, {required bool isNew}) {
    return _run(incident.vehicleId, () async {
      final repository = ref.read(incidentRepositoryProvider);
      if (isNew) {
        await repository.add(incident);
      } else {
        await repository.update(incident);
      }
    });
  }

  /// Settles it as [status], today: the word and the day are written
  /// together, so a settled report never carries an open status and an
  /// open one never carries a day. The clock seam, not `DateTime.now()`,
  /// so a test can say which day it is; the calendar day of the local
  /// moment, so an admin closing one late in the evening files it under
  /// the day they saw.
  Future<bool> close(Incident incident, {required IncidentStatus status}) {
    assert(status.isSettled, 'close settles; reopen is the other way');
    return _run(incident.vehicleId, () async {
      final now = ref.read(clockProvider)();
      await ref
          .read(incidentRepositoryProvider)
          .update(
            incident.copyWith(
              status: status,
              resolvedOn: DateTime.utc(now.year, now.month, now.day),
            ),
          );
    });
  }

  /// Puts it back on the list: open, with no day.
  Future<bool> reopen(Incident incident) {
    return _run(incident.vehicleId, () async {
      await ref
          .read(incidentRepositoryProvider)
          .update(
            incident.copyWith(status: IncidentStatus.open, clearResolved: true),
          );
    });
  }

  Future<bool> delete(Incident incident) {
    return _run(incident.vehicleId, () async {
      await ref.read(incidentRepositoryProvider).delete(incident.id);
      // The photos go with the report, like every other entry's receipt
      // (decision 129). After the deletion, never before.
      await sweepAttachments(
        ref.read(attachmentRepositoryProvider),
        kind: AttachmentEntryKind.incident,
        entryId: incident.id,
      );
    });
  }

  Future<bool> _run(String vehicleId, Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      ref
        ..invalidate(incidentsProvider(vehicleId))
        ..invalidate(fleetIncidentsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }
}
