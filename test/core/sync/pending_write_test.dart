import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/pending_write.dart';

PendingWrite write({
  String id = 'e1',
  PendingWriteKind kind = PendingWriteKind.fuel,
  DateTime? queuedAt,
  int attempts = 0,
}) {
  return PendingWrite(
    id: id,
    kind: kind,
    vehicleId: 'v1',
    row: {'id': id, 'vehicle_id': 'v1', 'odometer_km': 50000},
    queuedAt: queuedAt ?? DateTime.utc(2026, 9, 5, 12),
    attempts: attempts,
  );
}

void main() {
  group('what gets queued', () {
    test('a write with no connection is kept for later', () {
      expect(
        shouldQueue(const AppFailure(kind: AppFailureKind.network)),
        isTrue,
      );
    });

    test('so is one that got no answer in time', () {
      // The request may still have landed. Queueing it is safe because the
      // entry carries its own id, so a replay is the same row — the rule
      // `writeNew` already relies on.
      expect(
        shouldQueue(const AppFailure(kind: AppFailureKind.timeout)),
        isTrue,
      );
    });

    test('a rejection is not a connection problem and must be shown', () {
      for (final kind in [
        AppFailureKind.permission,
        AppFailureKind.auth,
        AppFailureKind.invalid,
        AppFailureKind.notFound,
        AppFailureKind.conflict,
        AppFailureKind.unknown,
      ]) {
        expect(
          shouldQueue(AppFailure(kind: kind)),
          isFalse,
          reason: '$kind is the server answering, not the network failing',
        );
      }
    });
  });

  group('what happens on replay', () {
    test('a connection problem leaves it in the queue', () {
      for (final kind in [AppFailureKind.network, AppFailureKind.timeout]) {
        expect(replayOutcome(AppFailure(kind: kind)), ReplayOutcome.keep);
      }
    });

    test('a conflict means it already landed', () {
      // The id is the entry's own, so a duplicate key is the previous attempt
      // arriving after the app stopped waiting. The row exists, once.
      expect(
        replayOutcome(const AppFailure(kind: AppFailureKind.conflict)),
        ReplayOutcome.done,
      );
    });

    test('a refusal can never succeed and is dropped, loudly', () {
      // The car was handed to another garage, the pass expired, the row is
      // malformed. Retrying forever is how a queue becomes a bug that grinds
      // a battery flat.
      for (final kind in [
        AppFailureKind.permission,
        AppFailureKind.auth,
        AppFailureKind.notFound,
        AppFailureKind.invalid,
      ]) {
        expect(
          replayOutcome(AppFailure(kind: kind)),
          ReplayOutcome.discard,
          reason: '$kind will fail identically on every future attempt',
        );
      }
    });

    test('an unknown failure is kept, but not forever', () {
      expect(
        replayOutcome(const AppFailure(kind: AppFailureKind.unknown)),
        ReplayOutcome.keep,
      );
    });

    test('a write that has failed too many times is given up on', () {
      // Something unforeseen, failing in a way that looks retryable and is
      // not. Better to surface it than to carry it silently for months.
      expect(write(attempts: maxReplayAttempts - 1).exhausted, isFalse);
      expect(write(attempts: maxReplayAttempts).exhausted, isTrue);
    });
  });

  group('the queue survives a restart', () {
    test('a write round-trips through JSON unchanged', () {
      final original = write(attempts: 2);

      final restored = PendingWrite.fromJson(original.toJson())!;

      expect(restored.id, original.id);
      expect(restored.kind, original.kind);
      expect(restored.vehicleId, original.vehicleId);
      expect(restored.row, original.row);
      expect(restored.queuedAt, original.queuedAt);
      expect(restored.attempts, 2);
    });

    test('the stored kind is a key, not the enum name', () {
      // Renaming the Dart value must not reinterpret what is already sitting
      // in storage on somebody's phone — the rule every stored enum in this
      // app follows.
      expect(write().toJson()['kind'], 'fuel');
      expect(PendingWriteKind.values.map((it) => it.key).toSet(), {
        'fuel',
        'odometer',
        'trip',
        'cost',
        'service',
        'observation',
        'attachment',
      });
    });

    test('a kind this build does not know is dropped, not fatal', () {
      // A queue written by a newer version, opened by an older one.
      expect(
        PendingWrite.fromJson({...write().toJson(), 'kind': 'spaceship'}),
        isNull,
      );
    });
  });
}
