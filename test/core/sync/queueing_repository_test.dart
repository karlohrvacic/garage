import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/queueing_repositories.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/features/fuel/data/fuel_repository.dart';

class FlakyFuelRepository implements FuelRepository {
  FlakyFuelRepository({this.failWith, this.stored = const []});

  AppFailureKind? failWith;
  List<FuelEntry> stored;
  final List<String> added = [];

  @override
  Future<List<FuelEntry>> forVehicle(String vehicleId) async {
    if (failWith != null) {
      throw AppFailure(kind: failWith!);
    }
    return stored;
  }

  @override
  Future<void> add(FuelEntry entry) async {
    if (failWith != null) {
      throw AppFailure(kind: failWith!);
    }
    added.add(entry.id);
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

({
  QueueingFuelRepository repo,
  FlakyFuelRepository inner,
  PendingWriteStore queue,
})
setUpRepo({AppFailureKind? failWith, List<FuelEntry> stored = const []}) {
  final inner = FlakyFuelRepository(failWith: failWith, stored: stored);
  final queue = InMemoryPendingWriteStore();
  return (
    repo: QueueingFuelRepository(
      inner: inner,
      queue: queue,
      now: () => DateTime.utc(2026, 9, 5, 12),
      userId: () => 'u1',
    ),
    inner: inner,
    queue: queue,
  );
}

void main() {
  group('saving', () {
    test('an online save goes straight through and queues nothing', () async {
      final it = setUpRepo();

      await it.repo.add(fill('e1'));

      expect(it.inner.added, ['e1']);
      expect(await it.queue.all(), isEmpty);
    });

    test('a save with no connection is kept, and does not throw', () async {
      // The sheet must be able to close. An entry the person typed at a pump
      // is not lost because the canopy ate the signal.
      final it = setUpRepo(failWith: AppFailureKind.network);

      await it.repo.add(fill('e1'));

      final queued = await it.queue.all();
      expect(queued.single.id, 'e1');
      expect(queued.single.kind, PendingWriteKind.fuel);
      expect(queued.single.vehicleId, 'v1');
    });

    test('a save that timed out is kept too', () async {
      final it = setUpRepo(failWith: AppFailureKind.timeout);

      await it.repo.add(fill('e1'));

      expect(await it.queue.all(), hasLength(1));
    });

    test('a rejection still reaches the person', () async {
      // Being told "saved" for a write the server refused is the worst
      // outcome available: the entry never arrives and nobody knows.
      final it = setUpRepo(failWith: AppFailureKind.permission);

      await expectLater(it.repo.add(fill('e1')), throwsA(isA<AppFailure>()));
      expect(await it.queue.all(), isEmpty);
    });

    test('saving the same entry twice queues it once', () async {
      final it = setUpRepo(failWith: AppFailureKind.network);

      await it.repo.add(fill('e1'));
      await it.repo.add(fill('e1', odometerKm: 50010));

      final queued = await it.queue.all();
      expect(queued, hasLength(1));
      expect(
        queued.single.row['odometer_km'],
        50010,
        reason: 'the correction replaces what was queued, not adds to it',
      );
    });
  });

  group('reading', () {
    test('a queued entry appears in the list once the read works', () async {
      final it = setUpRepo(stored: [fill('server1', odometerKm: 49000)]);
      it.inner.failWith = AppFailureKind.network;
      await it.repo.add(fill('pending1', odometerKm: 50000));
      it.inner.failWith = null;

      final list = await it.repo.forVehicle('v1');

      expect(list.map((it) => it.id), ['server1', 'pending1']);
    });

    test('and is not doubled once the server has it too', () async {
      // The entry carries its own id, so the merge is exact rather than a
      // guess at which rows are the same.
      final it = setUpRepo();
      it.inner.failWith = AppFailureKind.network;
      await it.repo.add(fill('e1'));
      it.inner
        ..failWith = null
        ..stored = [fill('e1')];

      final list = await it.repo.forVehicle('v1');

      expect(list, hasLength(1));
    });

    test('entries stay in odometer order, wherever they came from', () async {
      final it = setUpRepo(stored: [fill('a', odometerKm: 49000)]);
      it.inner.failWith = AppFailureKind.network;
      await it.repo.add(fill('b', odometerKm: 48000));
      it.inner.failWith = null;

      final list = await it.repo.forVehicle('v1');

      expect(list.map((it) => it.id), ['b', 'a']);
    });

    test('another vehicle\'s queued entries stay out of it', () async {
      final it = setUpRepo();
      it.inner.failWith = AppFailureKind.network;
      await it.repo.add(fill('mine'));
      it.inner.failWith = null;

      expect(await it.repo.forVehicle('v2'), isEmpty);
    });

    test('a read with no connection fails as it always did', () async {
      // There is no read cache. Returning only the unsent entries would be a
      // list that looks like the whole history and is not.
      final it = setUpRepo(failWith: AppFailureKind.network);
      await it.repo.add(fill('e1'));

      await expectLater(it.repo.forVehicle('v1'), throwsA(isA<AppFailure>()));
    });
  });
}
