import 'dart:async';

import '../errors/app_failure.dart';
import 'pending_write.dart';
import 'write_queue.dart';

/// What one pass over the queue managed to do.
class ReplayReport {
  const ReplayReport({
    this.sent = 0,
    this.discarded = 0,
    this.stillWaiting = 0,
  });

  final int sent;

  /// Writes the server will never accept, or that failed too many times.
  /// Counted separately because somebody has to be told: an entry that
  /// silently disappears is worse than one that never sent.
  final int discarded;

  final int stillWaiting;

  bool get anythingHappened => sent > 0 || discarded > 0;
}

/// Guards against overlapping runs.
///
/// The triggers overlap on purpose — app resume, a read that succeeded, the
/// retry button — so two passes starting together is the normal case rather
/// than a race to be surprised by. Holding the guard here means no caller has
/// to remember it.
Future<ReplayReport>? _running;

/// Sends everything waiting, oldest first.
///
/// Stops at the first sign that the connection is gone: there is one network,
/// and if the first write cannot reach the server neither can the next twenty.
/// Marching through the rest would cost a battery to learn nothing.
Future<ReplayReport> replayQueue({
  required PendingWriteStore queue,
  required Future<void> Function(PendingWrite) send,
}) {
  return _running ??= _replay(queue: queue, send: send).whenComplete(() {
    _running = null;
  });
}

Future<ReplayReport> _replay({
  required PendingWriteStore queue,
  required Future<void> Function(PendingWrite) send,
}) async {
  final writes = [...await queue.all()]
    ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

  var sent = 0;
  var discarded = 0;

  for (final write in writes) {
    try {
      await send(write);
      await queue.remove(write.id);
      sent++;
    } on AppFailure catch (failure) {
      switch (replayOutcome(failure)) {
        case ReplayOutcome.done:
          await queue.remove(write.id);
          sent++;
        case ReplayOutcome.discard:
          await queue.remove(write.id);
          discarded++;
        case ReplayOutcome.keep:
          final attempted = write.withAttempt();
          if (attempted.exhausted) {
            await queue.remove(write.id);
            discarded++;
            continue;
          }
          await queue.put(attempted);
          if (failure.kind == AppFailureKind.network ||
              failure.kind == AppFailureKind.timeout) {
            return ReplayReport(
              sent: sent,
              discarded: discarded,
              stillWaiting: (await queue.all()).length,
            );
          }
      }
    }
  }

  return ReplayReport(
    sent: sent,
    discarded: discarded,
    stillWaiting: (await queue.all()).length,
  );
}
