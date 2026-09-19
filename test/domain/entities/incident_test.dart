import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/incident.dart';

Incident incident(
  String id, {
  IncidentKind kind = IncidentKind.damage,
  DateTime? happenedOn,
  DateTime? resolvedOn,
  IncidentStatus status = IncidentStatus.open,
  double? amount,
  int? odometerKm,
}) {
  return Incident(
    id: id,
    vehicleId: 'v1',
    kind: kind,
    happenedOn: happenedOn ?? DateTime.utc(2026, 9, 1),
    description: 'Scratched the bumper',
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 9, 1),
    status: status,
    resolvedOn: resolvedOn,
    amount: amount,
    odometerKm: odometerKm,
  );
}

/// Settled on [on]: the word and the day together, as the controller
/// writes them.
Incident settled(
  String id, {
  required DateTime on,
  IncidentStatus status = IncidentStatus.closed,
}) {
  return incident(id, resolvedOn: on, status: status);
}

void main() {
  test('keys round-trip and an unknown one falls back rather than throws', () {
    for (final kind in IncidentKind.values) {
      expect(IncidentKind.fromKey(kind.key), kind);
    }
    for (final status in IncidentStatus.values) {
      expect(IncidentStatus.fromKey(status.key), status);
    }
    expect(IncidentKind.fromKey('meteorite'), IncidentKind.damage);
    expect(IncidentStatus.fromKey('lost'), IncidentStatus.open);
  });

  test(
    'open ones lead, newest first; closed ones follow by when they closed',
    () {
      final ordered = Incidents.forDisplay([
        settled('old-closed', on: DateTime.utc(2026, 8, 1)),
        incident('new-open', happenedOn: DateTime.utc(2026, 9, 10)),
        settled('newer-closed', on: DateTime.utc(2026, 9, 5)),
        incident('older-open', happenedOn: DateTime.utc(2026, 9, 2)),
      ]);

      expect(ordered.map((it) => it.id), [
        'new-open',
        'older-open',
        'newer-closed',
        'old-closed',
      ]);
    },
  );

  test('the mechanic gets what is still open and is theirs to act on', () {
    final sheet = Incidents.forMechanic([
      incident('dent', happenedOn: DateTime.utc(2026, 9, 3)),
      incident('fine', kind: IncidentKind.fine),
      settled(
        'done',
        on: DateTime.utc(2026, 9, 5),
        status: IncidentStatus.paid,
      ),
      incident(
        'rattle',
        kind: IncidentKind.fault,
        happenedOn: DateTime.utc(2026, 8, 20),
      ),
      incident(
        'insurer',
        kind: IncidentKind.accident,
        status: IncidentStatus.atInsurer,
      ),
    ]);

    expect(sheet.map((it) => it.id), [
      'rattle',
      'insurer',
      'dent',
    ], reason: 'oldest first, no fines, nothing closed');
  });

  test('closing records the day, reopening clears it', () {
    final closed = incident('a').copyWith(
      status: IncidentStatus.closed,
      resolvedOn: DateTime.utc(2026, 9, 9),
    );
    expect(closed.isOpen, isFalse);

    final again = closed.copyWith(
      status: IncidentStatus.open,
      clearResolved: true,
    );
    expect(again.isOpen, isTrue);
    expect(again.resolvedOn, isNull);
  });

  test('the status says whether it is still anybody\'s problem', () {
    // With the insurer is open: somebody is still waiting on it. Repaired,
    // paid and closed are the three ways it stops being anybody's.
    expect(IncidentStatus.open.isSettled, isFalse);
    expect(IncidentStatus.atInsurer.isSettled, isFalse);
    expect(IncidentStatus.settled, [
      IncidentStatus.repaired,
      IncidentStatus.paid,
      IncidentStatus.closed,
    ]);
    expect(incident('a', status: IncidentStatus.atInsurer).isOpen, isTrue);
    expect(
      settled(
        'b',
        on: DateTime.utc(2026, 9, 9),
        status: IncidentStatus.paid,
      ).isOpen,
      isFalse,
    );
  });

  test('an edit can clear the amount and the reading', () {
    // Emptying the field has to reach the row as null: a fine that was
    // waived is not a fine of forty euros.
    final priced = incident('a', amount: 40, odometerKm: 61200);

    final cleared = priced.copyWith(amount: null, odometerKm: null);
    expect(cleared.amount, isNull);
    expect(cleared.odometerKm, isNull);

    final untouched = priced.copyWith(description: 'Reworded');
    expect(untouched.amount, 40);
    expect(untouched.odometerKm, 61200);
  });
}
