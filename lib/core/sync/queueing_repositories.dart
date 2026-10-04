import '../../domain/entities/cost_entry.dart';
import '../../domain/entities/fuel_entry.dart';
import '../../domain/entities/observation.dart';
import '../../domain/entities/reminder_rule.dart';
import '../../domain/entities/service_entry.dart';
import '../../domain/entities/trip_draft.dart';
import '../../domain/entities/trip_entry.dart';
import '../../domain/entities/odometer_entry.dart';
import '../../features/costs/data/cost_repository.dart';
import '../../features/costs/data/supabase_cost_repository.dart';
import '../../features/fuel/data/fuel_repository.dart';
import '../../features/fuel/data/supabase_fuel_repository.dart';
import '../../features/odometer/data/odometer_repository.dart';
import '../../features/maintenance/data/maintenance_repository.dart';
import '../../features/maintenance/data/supabase_maintenance_repository.dart';
import '../../features/observations/data/observation_repository.dart';
import '../../features/observations/data/supabase_observation_repository.dart';
import '../../features/odometer/data/supabase_odometer_repository.dart';
import '../../features/trips/data/supabase_trip_repository.dart';
import '../../features/trips/data/trip_repository.dart';
import '../errors/app_failure.dart';
import 'pending_write.dart';
import 'replay.dart';
import 'write_queue.dart';

/// A repository that keeps a write the network could not carry.
///
/// Written as a decorator over the Supabase repository rather than as
/// something the sheets call, because every screen in this app already reads
/// providers over a repository *interface*. Nothing above the data layer has
/// to learn that a queue exists — the entry sheet saves, closes, and is right
/// to.
///
/// **A read is merged, not cached here.** The repository beneath may serve its
/// last good rows when the network is gone (`ReadCache`), and the queued
/// entries are merged over whatever it returns, deduped on id. This class
/// keeps no copy of its own: the unsent entries alone would look like a
/// vehicle's history and not be one, which is a worse lie than an error.
class QueueingFuelRepository implements FuelRepository {
  QueueingFuelRepository({
    required this.inner,
    required this.queue,
    required this.now,
    required this.userId,
  });

  final FuelRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final String? Function() userId;

  @override
  Future<void> add(FuelEntry entry) async {
    try {
      await inner.add(entry);
    } on AppFailure catch (failure) {
      if (!shouldQueue(failure)) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: entry.id,
          kind: PendingWriteKind.fuel,
          vehicleId: entry.vehicleId,
          row: rowForQueue(
            fuelEntryToRow(entry),
            id: entry.id,
            vehicleId: entry.vehicleId,
            userId: userId(),
            at: now(),
          ),
          queuedAt: now(),
        ),
      );
    }
  }

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async {
    final stored = await inner.forVehicle(vehicleId);
    final pending = await pendingEntries(
      queue: queue,
      kind: PendingWriteKind.fuel,
      vehicleId: vehicleId,
      known: {for (final entry in stored) entry.id},
      read: fuelEntryFromRow,
    );
    if (pending.isEmpty) {
      return stored;
    }
    // The list the app reads is ordered by odometer, and a fill-up typed at a
    // pump belongs where its reading puts it, not on the end.
    return [...stored, ...pending]
      ..sort((a, b) => a.odometerKm.compareTo(b.odometerKm));
  }

  @override
  Future<void> update(FuelEntry entry) => updateEntry(
    queue,
    id: entry.id,
    vehicleId: entry.vehicleId,
    row: fuelEntryToRow(entry),
    server: () => inner.update(entry),
  );

  @override
  Future<void> delete(String id) =>
      deleteEntry(queue, id, server: () => inner.delete(id));
}

class QueueingOdometerRepository implements OdometerRepository {
  QueueingOdometerRepository({
    required this.inner,
    required this.queue,
    required this.now,
    required this.userId,
  });

  final OdometerRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final String? Function() userId;

  @override
  Future<void> add(OdometerEntry entry) async {
    try {
      await inner.add(entry);
    } on AppFailure catch (failure) {
      if (!shouldQueue(failure)) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: entry.id,
          kind: PendingWriteKind.odometer,
          vehicleId: entry.vehicleId,
          row: rowForQueue(
            odometerEntryToRow(entry),
            id: entry.id,
            vehicleId: entry.vehicleId,
            userId: userId(),
            at: now(),
          ),
          queuedAt: now(),
        ),
      );
    }
  }

  @override
  Future<List<OdometerEntry>> forVehicle(String vehicleId) async {
    final stored = await inner.forVehicle(vehicleId);
    final pending = await pendingEntries(
      queue: queue,
      kind: PendingWriteKind.odometer,
      vehicleId: vehicleId,
      known: {for (final entry in stored) entry.id},
      read: odometerEntryFromRow,
    );
    if (pending.isEmpty) {
      return stored;
    }
    return [...stored, ...pending]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> update(OdometerEntry entry) => updateEntry(
    queue,
    id: entry.id,
    vehicleId: entry.vehicleId,
    row: odometerEntryToRow(entry),
    server: () => inner.update(entry),
  );

  @override
  Future<void> delete(String id) =>
      deleteEntry(queue, id, server: () => inner.delete(id));
}

/// The row a queued write replays, which is the row the repository would have
/// sent plus the three columns the server would have filled in.
///
/// `created_at` is the moment the person made the entry rather than the moment
/// it eventually lands. A fill-up typed at 07:00 with no signal did happen at
/// 07:00, and dating it from the drive home would be the app inventing a fact
/// about the day.
Map<String, dynamic> rowForQueue(
  Map<String, dynamic> row, {
  required String id,
  required String vehicleId,
  required String? userId,
  required DateTime at,
}) => {
  ...row,
  'id': id,
  'vehicle_id': vehicleId,
  'created_by': userId ?? '',
  'created_at': at.toIso8601String(),
};

/// The queued entries for one vehicle that the server has not returned.
///
/// Deduped on the entry's own id, so the merge is exact: the moment a replay
/// lands, the server row and the queued row are the same row and only one
/// survives.
Future<List<T>> pendingEntries<T>({
  required PendingWriteStore queue,
  required PendingWriteKind kind,
  required String vehicleId,
  required Set<String> known,
  required T Function(Map<String, dynamic>) read,
}) async {
  final writes = await queue.all();
  return [
    for (final write in writes)
      if (write.kind == kind &&
          write.vehicleId == vehicleId &&
          !known.contains(write.id))
        read(write.row),
  ];
}

/// Deletes an entry, wherever it is: in the queue, on the server, or both.
///
/// A queued entry is in its list like any other, so it gets deleted like any
/// other. Sent only to the server, the delete matched no row and
/// `refusedIfNone` reported a refusal: the person was told they may not delete
/// the fill-up they had just typed, and it sent itself later anyway. So the
/// queued insert is dropped — and the server is still asked, because a save
/// that timed out is queued too and may have landed after the app stopped
/// waiting.
Future<void> deleteEntry(
  PendingWriteStore queue,
  String id, {
  required Future<void> Function() server,
}) async {
  if (await _queued(queue, id) == null) {
    return server();
  }
  await betweenReplays(() async {
    if (await _queued(queue, id) == null) {
      // Sent by the replay this waited for.
      return server();
    }
    await queue.remove(id);
    await _ifItLanded(server);
  });
}

/// Edits an entry, wherever it is. A queued one has the edit put into its
/// queued insert: not queued as a write of its own (decision 153), so there is
/// still only the one insert, carrying what the person corrected. The rest of
/// the queued row — id, author, when it was made — stays as it was.
///
/// [row] is the writable half the repository would have sent. As with a
/// delete, the server is asked first in case the insert landed; if it had, the
/// edit is there and the queued insert would only be refused as a duplicate.
Future<void> updateEntry(
  PendingWriteStore queue, {
  required String id,
  required String vehicleId,
  required Map<String, dynamic> row,
  required Future<void> Function() server,
}) async {
  if (await _queued(queue, id) == null) {
    return server();
  }
  await betweenReplays(() async {
    final waiting = await _queued(queue, id);
    if (waiting == null) {
      return server();
    }
    if (await _ifItLanded(server)) {
      await queue.remove(id);
      return;
    }
    await queue.put(
      PendingWrite(
        id: waiting.id,
        kind: waiting.kind,
        vehicleId: vehicleId,
        row: {...waiting.row, ...row, 'id': id, 'vehicle_id': vehicleId},
        queuedAt: waiting.queuedAt,
        attempts: waiting.attempts,
        attachment: waiting.attachment,
      ),
    );
  });
}

/// Looked up outside the replay's turn first, so a change to an entry the
/// server already has never waits behind a backlog: a replay only ever takes
/// an entry *out* of the queue, so one that is not there is settled.
Future<PendingWrite?> _queued(PendingWriteStore queue, String id) async =>
    (await queue.all()).where((write) => write.id == id).firstOrNull;

/// Sends a change to a queued entry's row, and says whether the row was
/// there. No row is `refusedIfNone`'s permission failure; no connection
/// leaves the queue to carry it. Anything else is the server answering.
///
/// Offline, a change to an entry whose insert did land is lost: the delete
/// leaves the row, and the edit goes with the insert the replay is refused.
/// That needs a time-out and then no signal at the next change, together.
Future<bool> _ifItLanded(Future<void> Function() server) async {
  try {
    await server();
    return true;
  } on AppFailure catch (failure) {
    if (failure.kind == AppFailureKind.permission ||
        failure.isConnectionFailure) {
      return false;
    }
    rethrow;
  }
}

/// A journey, kept when the network could not take it.
///
/// Same shape as [QueueingFuelRepository] and for the same reason, with one
/// difference that matters to the reader: the log is ordered by date, so a
/// pending trip belongs on its own day rather than on the end of the list.
class QueueingTripRepository implements TripRepository {
  QueueingTripRepository({
    required this.inner,
    required this.queue,
    required this.now,
    required this.userId,
  });

  final TripRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final String? Function() userId;

  @override
  Future<void> add(TripEntry entry) async {
    try {
      await inner.add(entry);
    } on AppFailure catch (failure) {
      if (!shouldQueue(failure)) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: entry.id,
          kind: PendingWriteKind.trip,
          vehicleId: entry.vehicleId,
          row: rowForQueue(
            tripEntryToRow(entry),
            id: entry.id,
            vehicleId: entry.vehicleId,
            userId: userId(),
            at: now(),
          ),
          queuedAt: now(),
        ),
      );
    }
  }

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async {
    final stored = await inner.forVehicle(vehicleId);
    final pending = await pendingEntries(
      queue: queue,
      kind: PendingWriteKind.trip,
      vehicleId: vehicleId,
      known: {for (final entry in stored) entry.id},
      read: tripEntryFromRow,
    );
    if (pending.isEmpty) {
      return stored;
    }
    return [...stored, ...pending]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> update(TripEntry entry) => updateEntry(
    queue,
    id: entry.id,
    vehicleId: entry.vehicleId,
    row: tripEntryToRow(entry),
    server: () => inner.update(entry),
  );

  @override
  Future<void> delete(String id) =>
      deleteEntry(queue, id, server: () => inner.delete(id));

  // A draft is an open journey, not a record of one: it is rewritten as the
  // car moves and is worthless once stale, so queueing it would replay a
  // position from an hour ago over the one the car is at.
  @override
  Future<TripDraft?> openDraft(String vehicleId) => inner.openDraft(vehicleId);

  @override
  Future<void> startDraft(TripDraft draft) => inner.startDraft(draft);

  @override
  Future<void> discardDraft(String id) => inner.discardDraft(id);
}

/// A cost, kept when the network could not take it. A receipt is taken where
/// the work was done, which is often a building with a concrete roof.
class QueueingCostRepository implements CostRepository {
  QueueingCostRepository({
    required this.inner,
    required this.queue,
    required this.now,
    required this.userId,
  });

  final CostRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final String? Function() userId;

  @override
  Future<void> add(CostEntry entry) async {
    try {
      await inner.add(entry);
    } on AppFailure catch (failure) {
      if (!shouldQueue(failure)) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: entry.id,
          kind: PendingWriteKind.cost,
          vehicleId: entry.vehicleId,
          row: rowForQueue(
            costEntryToRow(entry),
            id: entry.id,
            vehicleId: entry.vehicleId,
            userId: userId(),
            at: now(),
          ),
          queuedAt: now(),
        ),
      );
    }
  }

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async {
    final stored = await inner.forVehicle(vehicleId);
    final pending = await pendingEntries(
      queue: queue,
      kind: PendingWriteKind.cost,
      vehicleId: vehicleId,
      known: {for (final entry in stored) entry.id},
      read: costEntryFromRow,
    );
    if (pending.isEmpty) {
      return stored;
    }
    return [...stored, ...pending]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<void> update(CostEntry entry) => updateEntry(
    queue,
    id: entry.id,
    vehicleId: entry.vehicleId,
    row: costEntryToRow(entry),
    server: () => inner.update(entry),
  );

  @override
  Future<void> delete(String id) =>
      deleteEntry(queue, id, server: () => inner.delete(id));
}

/// Something noticed about the car, kept when the network could not take it.
///
/// The one most worth keeping: an observation is a thing you noticed once,
/// while driving, and the whole point of logging it there and then is that you
/// will not remember it later. A write that threw took the memory with it.
class QueueingObservationRepository implements ObservationRepository {
  QueueingObservationRepository({
    required this.inner,
    required this.queue,
    required this.now,
    required this.userId,
  });

  final ObservationRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final String? Function() userId;

  @override
  Future<void> add(Observation observation) async {
    try {
      await inner.add(observation);
    } on AppFailure catch (failure) {
      if (!shouldQueue(failure)) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: observation.id,
          kind: PendingWriteKind.observation,
          vehicleId: observation.vehicleId,
          row: rowForQueue(
            observationToRow(observation),
            id: observation.id,
            vehicleId: observation.vehicleId,
            userId: userId(),
            at: now(),
          ),
          queuedAt: now(),
        ),
      );
    }
  }

  @override
  Future<List<Observation>> forVehicle(String vehicleId) async {
    final stored = await inner.forVehicle(vehicleId);
    final pending = await pendingEntries(
      queue: queue,
      kind: PendingWriteKind.observation,
      vehicleId: vehicleId,
      known: {for (final entry in stored) entry.id},
      read: observationFromRow,
    );
    if (pending.isEmpty) {
      return stored;
    }
    return [...stored, ...pending]
      ..sort((a, b) => a.noticedOn.compareTo(b.noticedOn));
  }

  @override
  Future<void> update(Observation observation) => updateEntry(
    queue,
    id: observation.id,
    vehicleId: observation.vehicleId,
    row: observationToRow(observation),
    server: () => inner.update(observation),
  );

  @override
  Future<void> delete(String id) =>
      deleteEntry(queue, id, server: () => inner.delete(id));
}

/// A service entry, kept when the network could not take it.
///
/// Only the entry. A rule is a standing arrangement rather than a thing that
/// happened, so an offline change to one is a preference the user can make
/// again; the record of work done at a workshop is not recoverable by trying
/// later. `completeOneTimeRules` is deliberately *not* queued either — it is
/// bookkeeping that follows a service entry, and replaying it out of order
/// against a rule that has since changed would deactivate the wrong thing.
class QueueingMaintenanceRepository implements MaintenanceRepository {
  QueueingMaintenanceRepository({
    required this.inner,
    required this.queue,
    required this.now,
    required this.userId,
  });

  final MaintenanceRepository inner;
  final PendingWriteStore queue;
  final DateTime Function() now;
  final String? Function() userId;

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async {
    try {
      await inner.addServiceEntry(entry);
    } on AppFailure catch (failure) {
      if (!shouldQueue(failure)) {
        rethrow;
      }
      await queue.put(
        PendingWrite(
          id: entry.id,
          kind: PendingWriteKind.service,
          vehicleId: entry.vehicleId,
          row: rowForQueue(
            serviceEntryToRow(entry),
            id: entry.id,
            vehicleId: entry.vehicleId,
            userId: userId(),
            at: now(),
          ),
          queuedAt: now(),
        ),
      );
    }
  }

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async {
    final stored = await inner.serviceEntriesForVehicle(vehicleId);
    final pending = await pendingEntries(
      queue: queue,
      kind: PendingWriteKind.service,
      vehicleId: vehicleId,
      known: {for (final entry in stored) entry.id},
      read: serviceEntryFromRow,
    );
    if (pending.isEmpty) {
      return stored;
    }
    return [...stored, ...pending]..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<ServiceType>> serviceTypes() => inner.serviceTypes();

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) =>
      inner.rulesForVehicle(vehicleId);

  @override
  Future<void> upsertRule(ReminderRule rule) => inner.upsertRule(rule);

  @override
  Future<void> deleteRule(String id) => inner.deleteRule(id);

  @override
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) => inner.completeOneTimeRules(vehicleId, serviceTypeKeys);

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) => updateEntry(
    queue,
    id: entry.id,
    vehicleId: entry.vehicleId,
    row: serviceEntryToRow(entry),
    server: () => inner.updateServiceEntry(entry),
  );

  @override
  Future<void> deleteServiceEntry(String id) =>
      deleteEntry(queue, id, server: () => inner.deleteServiceEntry(id));
}
