import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/queueing_repositories.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/observation.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/costs/data/cost_repository.dart';
import 'package:garage/features/observations/data/observation_repository.dart';
import 'package:garage/features/trips/data/trip_repository.dart';
import 'package:garage/domain/entities/trip_draft.dart';

/// The four things people log away from a good connection: a journey finished
/// in a car park, a receipt taken at a workshop, the service that workshop
/// did, and a rattle noticed on the way home. All four used to throw and lose
/// the write; fuel and odometer readings never did.

class FlakyTrips implements TripRepository {
  FlakyTrips({this.failWith, this.stored = const []});
  AppFailureKind? failWith;
  List<TripEntry> stored;
  final List<String> added = [];

  @override
  Future<List<TripEntry>> forVehicle(String vehicleId) async {
    if (failWith != null) throw AppFailure(kind: failWith!);
    return stored;
  }

  @override
  Future<void> add(TripEntry entry) async {
    if (failWith != null) throw AppFailure(kind: failWith!);
    added.add(entry.id);
  }

  @override
  Future<void> update(TripEntry entry) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<TripDraft?> openDraft(String vehicleId) async => null;
  @override
  Future<void> startDraft(TripDraft draft) async {}
  @override
  Future<void> discardDraft(String id) async {}
}

class FlakyCosts implements CostRepository {
  FlakyCosts({this.failWith, this.stored = const []});
  AppFailureKind? failWith;
  List<CostEntry> stored;
  final List<String> added = [];

  @override
  Future<List<CostEntry>> forVehicle(String vehicleId) async {
    if (failWith != null) throw AppFailure(kind: failWith!);
    return stored;
  }

  @override
  Future<void> add(CostEntry entry) async {
    if (failWith != null) throw AppFailure(kind: failWith!);
    added.add(entry.id);
  }

  @override
  Future<void> update(CostEntry entry) async {}
  @override
  Future<void> delete(String id) async {}
}

class FlakyObservations implements ObservationRepository {
  FlakyObservations({this.failWith, this.stored = const []});
  AppFailureKind? failWith;
  List<Observation> stored;
  final List<String> added = [];

  @override
  Future<List<Observation>> forVehicle(String vehicleId) async {
    if (failWith != null) throw AppFailure(kind: failWith!);
    return stored;
  }

  @override
  Future<void> add(Observation observation) async {
    if (failWith != null) throw AppFailure(kind: failWith!);
    added.add(observation.id);
  }

  @override
  Future<void> update(Observation observation) async {}
  @override
  Future<void> delete(String id) async {}
}

TripEntry trip(String id, {DateTime? on}) => TripEntry(
  id: id,
  vehicleId: 'v1',
  date: on ?? DateTime.utc(2026, 9, 5),
  distanceKm: 32,
  purpose: TripPurpose.private,
  createdBy: 'u1',
);

CostEntry cost(String id, {DateTime? on}) => CostEntry(
  id: id,
  vehicleId: 'v1',
  date: on ?? DateTime.utc(2026, 9, 5),
  amount: 120,
  category: 'service',
  createdBy: 'u1',
);

Observation observation(String id, {DateTime? on}) => Observation(
  id: id,
  vehicleId: 'v1',
  noticedOn: on ?? DateTime.utc(2026, 9, 5),
  note: 'Rattle over bumps',
  createdBy: 'u1',
  createdAt: DateTime.utc(2026, 9, 5),
);

void main() {
  group('a journey logged where there is no signal', () {
    test('is kept rather than lost', () async {
      final inner = FlakyTrips(failWith: AppFailureKind.network);
      final queue = InMemoryPendingWriteStore();
      final repo = QueueingTripRepository(
        inner: inner,
        queue: queue,
        now: () => DateTime.utc(2026, 9, 5, 12),
        userId: () => 'u1',
      );

      await repo.add(trip('t1'));

      final queued = await queue.all();
      expect(queued.single.id, 't1');
      expect(queued.single.kind, PendingWriteKind.trip);
    });

    test('and shows in the log it belongs to, in date order', () async {
      // Not on the end: a trip typed on Tuesday belongs on Tuesday, or the
      // list it lands in reads as though it were sorted wrong.
      final inner = FlakyTrips(
        stored: [trip('t1', on: DateTime.utc(2026, 9, 1))],
      );
      final queue = InMemoryPendingWriteStore();
      final repo = QueueingTripRepository(
        inner: inner,
        queue: queue,
        now: () => DateTime.utc(2026, 9, 5, 12),
        userId: () => 'u1',
      );
      inner.failWith = AppFailureKind.network;
      await repo.add(trip('t2', on: DateTime.utc(2026, 9, 3)));
      inner.failWith = null;

      final read = await repo.forVehicle('v1');

      expect(read.map((t) => t.id), ['t1', 't2']);
    });

    test('a refusal still reaches the person', () async {
      final inner = FlakyTrips(failWith: AppFailureKind.permission);
      final queue = InMemoryPendingWriteStore();
      final repo = QueueingTripRepository(
        inner: inner,
        queue: queue,
        now: () => DateTime.utc(2026, 9, 5, 12),
        userId: () => 'u1',
      );

      await expectLater(repo.add(trip('t1')), throwsA(isA<AppFailure>()));
      expect(await queue.all(), isEmpty);
    });
  });

  group('a receipt taken at a workshop', () {
    test('is kept rather than lost', () async {
      final inner = FlakyCosts(failWith: AppFailureKind.timeout);
      final queue = InMemoryPendingWriteStore();
      final repo = QueueingCostRepository(
        inner: inner,
        queue: queue,
        now: () => DateTime.utc(2026, 9, 5, 12),
        userId: () => 'u1',
      );

      await repo.add(cost('c1'));

      expect((await queue.all()).single.kind, PendingWriteKind.cost);
    });
  });

  group('a rattle noticed on the way home', () {
    test('is kept rather than lost', () async {
      final inner = FlakyObservations(failWith: AppFailureKind.network);
      final queue = InMemoryPendingWriteStore();
      final repo = QueueingObservationRepository(
        inner: inner,
        queue: queue,
        now: () => DateTime.utc(2026, 9, 5, 12),
        userId: () => 'u1',
      );

      await repo.add(observation('o1'));

      expect((await queue.all()).single.kind, PendingWriteKind.observation);
    });
  });
}
