import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/replay.dart';
import 'package:garage/core/sync/write_queue.dart';

class RecordingSender {
  RecordingSender({this.failures = const {}});

  /// Keyed by entry id: what sending it throws, if anything.
  final Map<String, AppFailureKind> failures;
  final List<String> sent = [];

  Future<void> call(PendingWrite write) async {
    sent.add(write.id);
    final failure = failures[write.id];
    if (failure != null) {
      throw AppFailure(kind: failure);
    }
  }
}

PendingWrite queued(String id, {int attempts = 0}) => PendingWrite(
  id: id,
  kind: PendingWriteKind.fuel,
  vehicleId: 'v1',
  row: {'id': id},
  queuedAt: DateTime.utc(2026, 9, 5, 12),
  attempts: attempts,
);

void main() {
  test('everything waiting is sent, oldest first', () async {
    final queue = InMemoryPendingWriteStore();
    for (final id in ['a', 'b', 'c']) {
      await queue.put(queued(id));
    }
    final sender = RecordingSender();

    final report = await replayQueue(queue: queue, send: sender.call);

    expect(sender.sent, ['a', 'b', 'c']);
    expect(report.sent, 3);
    expect(await queue.all(), isEmpty);
  });

  test('one that already landed is taken off the queue', () async {
    final queue = InMemoryPendingWriteStore();
    await queue.put(queued('a'));

    final report = await replayQueue(
      queue: queue,
      send: RecordingSender(failures: {'a': AppFailureKind.conflict}).call,
    );

    expect(report.sent, 1);
    expect(await queue.all(), isEmpty);
  });

  test('one the server will never accept is dropped and reported', () async {
    final queue = InMemoryPendingWriteStore();
    await queue.put(queued('a'));

    final report = await replayQueue(
      queue: queue,
      send: RecordingSender(failures: {'a': AppFailureKind.permission}).call,
    );

    expect(report.discarded, 1);
    expect(report.sent, 0);
    expect(await queue.all(), isEmpty);
  });

  test('losing the connection stops the run rather than grinding', () async {
    // There is one connection. If the first write cannot reach the server,
    // neither can the next twenty, and trying them all costs a battery.
    final queue = InMemoryPendingWriteStore();
    for (final id in ['a', 'b', 'c']) {
      await queue.put(queued(id));
    }
    final sender = RecordingSender(failures: {'a': AppFailureKind.network});

    final report = await replayQueue(queue: queue, send: sender.call);

    expect(sender.sent, ['a'], reason: 'it stopped after the first');
    expect(report.stillWaiting, 3);
    expect(await queue.all(), hasLength(3));
  });

  test('a failed attempt is counted against the write', () async {
    final queue = InMemoryPendingWriteStore();
    await queue.put(queued('a'));

    await replayQueue(
      queue: queue,
      send: RecordingSender(failures: {'a': AppFailureKind.unknown}).call,
    );

    expect((await queue.all()).single.attempts, 1);
  });

  test('a write that has failed enough times is given up on', () async {
    final queue = InMemoryPendingWriteStore();
    await queue.put(queued('a', attempts: maxReplayAttempts - 1));

    final report = await replayQueue(
      queue: queue,
      send: RecordingSender(failures: {'a': AppFailureKind.unknown}).call,
    );

    expect(report.discarded, 1);
    expect(await queue.all(), isEmpty);
  });

  test('an empty queue does nothing at all', () async {
    final sender = RecordingSender();

    final report = await replayQueue(
      queue: InMemoryPendingWriteStore(),
      send: sender.call,
    );

    expect(sender.sent, isEmpty);
    expect(report.sent, 0);
    expect(report.anythingHappened, isFalse);
  });

  test('two runs at once do not send the same write twice', () async {
    // The triggers overlap by design — resume, a successful read, the button
    // — so the guard has to be in the replay rather than in each caller.
    final queue = InMemoryPendingWriteStore();
    await queue.put(queued('a'));
    final sender = RecordingSender();

    await Future.wait([
      replayQueue(queue: queue, send: sender.call),
      replayQueue(queue: queue, send: sender.call),
    ]);

    expect(sender.sent, ['a']);
  });
}
