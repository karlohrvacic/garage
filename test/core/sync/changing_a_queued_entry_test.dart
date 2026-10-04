import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/queueing_repositories.dart';
import 'package:garage/core/sync/replay.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/observation.dart';
import 'package:garage/domain/entities/odometer_entry.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/observations/data/observation_repository.dart';
import 'package:garage/features/odometer/data/odometer_repository.dart';
import 'package:garage/features/trips/data/trip_repository.dart';

/// An entry saved with no signal is shown in its list straight away, so it
/// can be opened, edited and deleted like any other. Until October 2026 the
/// edit and the delete went to the server, which had never heard of the row:
/// zero rows matched, `refusedIfNone` called that a refusal, and the person
/// was told they were not allowed to delete the fill-up they had just typed —
/// four times in a row on one phone. The entry stayed, and sent itself later.

/// The server as the Supabase repositories see it: a write that matches no
/// row is refused, the way `refusedIfNone` reports it.
class _Server {
  bool offline = false;
  final Set<String> rows = {};
  final List<String> calls = [];

  Future<void> add(String id) async {
    calls.add('add:$id');
    _reachable();
    rows.add(id);
  }

  Future<void> update(String id) async {
    calls.add('update:$id');
    _reachable();
    if (!rows.contains(id)) {
      throw const AppFailure(kind: AppFailureKind.permission);
    }
  }

  Future<void> delete(String id) async {
    calls.add('delete:$id');
    _reachable();
    if (!rows.remove(id)) {
      throw const AppFailure(kind: AppFailureKind.permission);
    }
  }

  void _reachable() {
    if (offline) {
      throw const AppFailure(kind: AppFailureKind.network);
    }
  }
}

class _Fuel implements FuelRepository {
  _Fuel(this.server);
  final _Server server;

  @override
  Future<void> add(FuelEntry entry) => server.add(entry.id);
  @override
  Future<void> update(FuelEntry entry) => server.update(entry.id);
  @override
  Future<void> delete(String id) => server.delete(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Odometer implements OdometerRepository {
  _Odometer(this.server);
  final _Server server;

  @override
  Future<void> add(OdometerEntry entry) => server.add(entry.id);
  @override
  Future<void> update(OdometerEntry entry) => server.update(entry.id);
  @override
  Future<void> delete(String id) => server.delete(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Trips implements TripRepository {
  _Trips(this.server);
  final _Server server;

  @override
  Future<void> add(TripEntry entry) => server.add(entry.id);
  @override
  Future<void> update(TripEntry entry) => server.update(entry.id);
  @override
  Future<void> delete(String id) => server.delete(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Costs implements CostRepository {
  _Costs(this.server);
  final _Server server;

  @override
  Future<void> add(CostEntry entry) => server.add(entry.id);
  @override
  Future<void> update(CostEntry entry) => server.update(entry.id);
  @override
  Future<void> delete(String id) => server.delete(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Observations implements ObservationRepository {
  _Observations(this.server);
  final _Server server;

  @override
  Future<void> add(Observation observation) => server.add(observation.id);
  @override
  Future<void> update(Observation observation) => server.update(observation.id);
  @override
  Future<void> delete(String id) => server.delete(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Maintenance implements MaintenanceRepository {
  _Maintenance(this.server);
  final _Server server;

  @override
  Future<void> addServiceEntry(ServiceEntry entry) => server.add(entry.id);
  @override
  Future<void> updateServiceEntry(ServiceEntry entry) =>
      server.update(entry.id);
  @override
  Future<void> deleteServiceEntry(String id) => server.delete(id);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// One kind of entry, saved, edited and deleted through its queueing
/// repository. [column] is where the edit shows in the queued row.
typedef _Entry = ({
  Future<void> Function() add,
  Future<void> Function(String notes) edit,
  Future<void> Function() delete,
  String column,
});

DateTime _now() => DateTime.utc(2026, 9, 20, 1, 15);
String _user() => 'u1';
final _day = DateTime.utc(2026, 9, 20);
const _id = '27068c84-ac75-4da8-ab1b-405590c05624';

final _kinds = <String, _Entry Function(_Server, PendingWriteStore)>{
  'a fill-up': (server, queue) {
    final repo = QueueingFuelRepository(
      inner: _Fuel(server),
      queue: queue,
      now: _now,
      userId: _user,
    );
    FuelEntry entry([String? notes]) => FuelEntry(
      id: _id,
      vehicleId: 'v1',
      date: _day,
      odometerKm: 50000,
      volumeL: 40,
      total: 65,
      fullTank: true,
      missedFill: false,
      createdBy: 'u1',
      notes: notes,
    );
    return (
      add: () => repo.add(entry()),
      edit: (notes) => repo.update(entry(notes)),
      delete: () => repo.delete(_id),
      column: 'notes',
    );
  },
  'a reading': (server, queue) {
    final repo = QueueingOdometerRepository(
      inner: _Odometer(server),
      queue: queue,
      now: _now,
      userId: _user,
    );
    OdometerEntry entry([String? notes]) => OdometerEntry(
      id: _id,
      vehicleId: 'v1',
      date: _day,
      odometerKm: 50000,
      createdBy: 'u1',
      notes: notes,
    );
    return (
      add: () => repo.add(entry()),
      edit: (notes) => repo.update(entry(notes)),
      delete: () => repo.delete(_id),
      column: 'notes',
    );
  },
  'a journey': (server, queue) {
    final repo = QueueingTripRepository(
      inner: _Trips(server),
      queue: queue,
      now: _now,
      userId: _user,
    );
    TripEntry entry([String? notes]) => TripEntry(
      id: _id,
      vehicleId: 'v1',
      date: _day,
      distanceKm: 32,
      purpose: TripPurpose.private,
      createdBy: 'u1',
      notes: notes,
    );
    return (
      add: () => repo.add(entry()),
      edit: (notes) => repo.update(entry(notes)),
      delete: () => repo.delete(_id),
      column: 'notes',
    );
  },
  'a cost': (server, queue) {
    final repo = QueueingCostRepository(
      inner: _Costs(server),
      queue: queue,
      now: _now,
      userId: _user,
    );
    CostEntry entry([String? notes]) => CostEntry(
      id: _id,
      vehicleId: 'v1',
      date: _day,
      amount: 120,
      category: 'parking',
      createdBy: 'u1',
      notes: notes,
    );
    return (
      add: () => repo.add(entry()),
      edit: (notes) => repo.update(entry(notes)),
      delete: () => repo.delete(_id),
      column: 'notes',
    );
  },
  'an observation': (server, queue) {
    final repo = QueueingObservationRepository(
      inner: _Observations(server),
      queue: queue,
      now: _now,
      userId: _user,
    );
    Observation entry([String? note]) => Observation(
      id: _id,
      vehicleId: 'v1',
      noticedOn: _day,
      note: note ?? 'Rattle over bumps',
      createdBy: 'u1',
      createdAt: _day,
    );
    return (
      add: () => repo.add(entry()),
      edit: (note) => repo.update(entry(note)),
      delete: () => repo.delete(_id),
      column: 'note',
    );
  },
  'a service': (server, queue) {
    final repo = QueueingMaintenanceRepository(
      inner: _Maintenance(server),
      queue: queue,
      now: _now,
      userId: _user,
    );
    ServiceEntry entry([String? notes]) => ServiceEntry(
      id: _id,
      vehicleId: 'v1',
      date: _day,
      odometerKm: 50000,
      serviceTypeKeys: const ['oil_change'],
      createdBy: 'u1',
      notes: notes,
    );
    return (
      add: () => repo.addServiceEntry(entry()),
      edit: (notes) => repo.updateServiceEntry(entry(notes)),
      delete: () => repo.deleteServiceEntry(_id),
      column: 'notes',
    );
  },
};

void main() {
  for (final MapEntry(key: kind, value: build) in _kinds.entries) {
    group('$kind saved with no signal', () {
      late _Server server;
      late PendingWriteStore queue;
      late _Entry entry;

      setUp(() async {
        server = _Server()..offline = true;
        queue = InMemoryPendingWriteStore();
        entry = build(server, queue);
        await entry.add();
        server.calls.clear();
      });

      test('can be deleted, and is not called a refusal', () async {
        server.offline = false;

        await entry.delete();

        expect(await queue.all(), isEmpty);
        expect(server.rows, isEmpty);
      });

      test('can be deleted while there is still no signal', () async {
        await entry.delete();

        expect(await queue.all(), isEmpty);
      });

      test('can be edited, and the edit is what gets sent', () async {
        final before = (await queue.all()).single;
        server.offline = false;

        await entry.edit('Pump 4');

        final after = (await queue.all()).single;
        expect(after.row[entry.column], 'Pump 4');
        // Still the entry the person made, when they made it.
        expect(after.queuedAt, before.queuedAt);
        expect(after.row['created_at'], before.row['created_at']);
        expect(after.row['created_by'], before.row['created_by']);
        expect(after.row['id'], _id);
        expect(after.row['vehicle_id'], 'v1');
      });

      test('can be edited while there is still no signal', () async {
        await entry.edit('Pump 4');

        expect((await queue.all()).single.row[entry.column], 'Pump 4');
      });

      // A save that timed out is queued too, and may have reached the
      // server after the app stopped waiting. Changing only the queued copy
      // would leave a deleted entry on the server, or an edit that the
      // insert's replay then drops as a duplicate.
      group('whose insert landed after the app stopped waiting', () {
        setUp(() {
          server
            ..rows.add(_id)
            ..offline = false;
        });

        test('is deleted on the server too', () async {
          await entry.delete();

          expect(server.rows, isEmpty);
          expect(await queue.all(), isEmpty);
        });

        test('is edited on the server, and not sent again', () async {
          await entry.edit('Pump 4');

          expect(server.calls, ['update:$_id']);
          expect(await queue.all(), isEmpty);
        });
      });
    });

    test('$kind the server has is changed on the server', () async {
      final server = _Server();
      final queue = InMemoryPendingWriteStore();
      final entry = build(server, queue);
      await entry.add();

      await entry.edit('Pump 4');
      await entry.delete();

      expect(server.calls, ['add:$_id', 'update:$_id', 'delete:$_id']);
    });
  }

  test('a delete waits for a replay in flight instead of racing it', () async {
    // The replay has already read the queue and is sending the entry. Taking
    // it off the queue now would not stop that send, and the entry the person
    // deleted would land on the server a moment later.
    final server = _Server()..offline = true;
    final queue = InMemoryPendingWriteStore();
    final entry = _kinds['a fill-up']!(server, queue);
    await entry.add();
    server.offline = false;

    final sending = Completer<void>();
    final replay = replayQueue(
      queue: queue,
      send: (write) async {
        await sending.future;
        await server.add(write.id);
      },
    );
    await pumpEventQueue();
    final deleting = entry.delete();
    await pumpEventQueue();
    sending.complete();
    await replay;
    await deleting;

    expect(server.rows, isEmpty);
    expect(await queue.all(), isEmpty);
  });

  test(
    'a change to an entry nobody queued does not wait for a replay',
    () async {
      // On resume with a backlog and one bar, a replay can take a while. An
      // edit to an entry the server already has has nothing to wait for.
      final server = _Server();
      final queue = InMemoryPendingWriteStore();
      final entry = _kinds['a fill-up']!(server, queue);
      await entry.add();
      await queue.put(
        PendingWrite(
          id: 'someone-else',
          kind: PendingWriteKind.odometer,
          vehicleId: 'v1',
          row: const {'id': 'someone-else'},
          queuedAt: _now(),
        ),
      );

      final sending = Completer<void>();
      addTearDown(() => sending.isCompleted ? null : sending.complete());
      final replay = replayQueue(queue: queue, send: (write) => sending.future);
      await pumpEventQueue();
      var edited = false;
      unawaited(entry.edit('Pump 4').then((_) => edited = true));
      await pumpEventQueue();

      expect(edited, isTrue);
      sending.complete();
      await replay;
    },
  );

  test('a replay waits for a change to the queue to finish', () async {
    final server = _Server()..offline = true;
    final queue = _SlowQueue();
    final entry = _kinds['a fill-up']!(server, queue);
    await entry.add();
    server.offline = false;

    queue.hold = Completer<void>();
    final deleting = entry.delete();
    await pumpEventQueue();
    final sent = <String>[];
    final replay = replayQueue(
      queue: queue,
      send: (write) async => sent.add(write.id),
    );
    await pumpEventQueue();
    queue.hold!.complete();
    await deleting;
    await replay;

    expect(sent, isEmpty);
  });
}

/// A queue whose removals can be held open, to start a replay in the middle
/// of one.
class _SlowQueue extends InMemoryPendingWriteStore {
  Completer<void>? hold;

  @override
  Future<void> remove(String id) async {
    await hold?.future;
    await super.remove(id);
  }
}
