import '../../domain/entities/fuel_entry.dart';
import '../../domain/entities/odometer_entry.dart';
import '../../features/fuel/data/fuel_repository.dart';
import '../../features/fuel/data/supabase_fuel_repository.dart';
import '../../features/odometer/data/odometer_repository.dart';
import '../../features/odometer/data/supabase_odometer_repository.dart';
import '../errors/app_failure.dart';
import 'pending_write.dart';
import 'write_queue.dart';

/// A repository that keeps a write the network could not carry.
///
/// Written as a decorator over the Supabase repository rather than as
/// something the sheets call, because every screen in this app already reads
/// providers over a repository *interface*. Nothing above the data layer has
/// to learn that a queue exists — the entry sheet saves, closes, and is right
/// to.
///
/// **A read is not cached.** Offline, `forVehicle` fails exactly as it did
/// before. Returning only the unsent entries would hand back a list that looks
/// like a vehicle's history and is not, which is a worse lie than an error.
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
  Future<void> update(FuelEntry entry) => inner.update(entry);

  @override
  Future<void> delete(String id) => inner.delete(id);
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
  Future<void> update(OdometerEntry entry) => inner.update(entry);

  @override
  Future<void> delete(String id) => inner.delete(id);
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
