import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/queueing_repositories.dart';
import 'package:garage/core/sync/replay.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';
import 'package:garage/features/fuel/data/supabase_fuel_repository.dart';

/// A server that can be switched off, so a test can put a phone under a
/// canopy and take it out again.
class SwitchableServer implements FuelRepository {
  bool online = true;
  final List<FuelEntry> rows = [];

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async {
    if (!online) {
      throw const AppFailure(kind: AppFailureKind.network);
    }
    return [
      for (final row in rows)
        if (row.vehicleId == vehicleId) row,
    ];
  }

  @override
  Future<void> add(FuelEntry entry) async {
    if (!online) {
      throw const AppFailure(kind: AppFailureKind.network);
    }
    if (rows.any((it) => it.id == entry.id)) {
      throw const AppFailure(kind: AppFailureKind.conflict);
    }
    rows.add(entry);
  }

  @override
  Future<void> update(FuelEntry entry) async {}

  @override
  Future<void> delete(String id) async {}
}

FuelEntry fill(String id, {int odometerKm = 50000}) => FuelEntry(
  id: id,
  vehicleId: 'v1',
  date: DateTime.utc(2026, 9, 5),
  odometerKm: odometerKm,
  volumeL: 40,
  total: 65,
  fullTank: true,
  missedFill: false,
  createdBy: 'u1',
);

void main() {
  late SwitchableServer server;
  late InMemoryPendingWriteStore queue;
  late QueueingFuelRepository repository;

  setUp(() {
    server = SwitchableServer();
    queue = InMemoryPendingWriteStore();
    repository = QueueingFuelRepository(
      inner: server,
      queue: queue,
      now: () => DateTime.utc(2026, 9, 5, 7),
      userId: () => 'u1',
    );
  });

  Future<ReplayReport> sync() => replayQueue(
    queue: queue,
    send: (write) => server.add(fuelEntryFromRow(write.row)),
  );

  test(
    'a fill-up typed at a pump reaches the garage when the signal does',
    () async {
      server.online = false;
      await repository.add(fill('e1'));
      expect(server.rows, isEmpty, reason: 'nothing left the phone yet');

      server.online = true;
      final report = await sync();

      expect(report.sent, 1);
      expect(server.rows.single.id, 'e1');
      expect(await queue.all(), isEmpty);
      expect((await repository.forVehicle('v1')).single.id, 'e1');
    },
  );

  test('it is visible before it syncs, and not twice afterwards', () async {
    server.online = false;
    await repository.add(fill('e1'));

    // Signal returns; the list is read before the queue has been replayed.
    server.online = true;
    expect((await repository.forVehicle('v1')).single.id, 'e1');

    await sync();

    expect(
      await repository.forVehicle('v1'),
      hasLength(1),
      reason: 'the queued row and the server row are the same row',
    );
  });

  test('what it recorded survives the round trip intact', () async {
    server.online = false;
    await repository.add(fill('e1', odometerKm: 51234));
    server.online = true;

    await sync();

    final landed = server.rows.single;
    expect(landed.odometerKm, 51234);
    expect(landed.volumeL, 40);
    expect(landed.total, 65);
    expect(landed.fullTank, isTrue);
    expect(landed.date, DateTime.utc(2026, 9, 5));
  });

  test('a replay that races an earlier attempt still lands once', () async {
    // The timeout case: the first write arrived after the sheet stopped
    // waiting, so the row is already there when the queue tries again.
    server.online = false;
    await repository.add(fill('e1'));
    server
      ..online = true
      ..rows.add(fill('e1'));

    final report = await sync();

    expect(report.sent, 1);
    expect(server.rows, hasLength(1));
    expect(await queue.all(), isEmpty);
  });

  test('several fill-ups queue and go in the order they were typed', () async {
    server.online = false;
    for (final id in ['a', 'b', 'c']) {
      await repository.add(fill(id, odometerKm: 50000));
    }
    server.online = true;

    final report = await sync();

    expect(report.sent, 3);
    expect(server.rows.map((it) => it.id), ['a', 'b', 'c']);
  });

  test('still no signal leaves everything exactly where it was', () async {
    server.online = false;
    await repository.add(fill('e1'));

    final report = await sync();

    expect(report.sent, 0);
    expect(report.stillWaiting, 1);
    expect(await queue.all(), hasLength(1));
  });
}
