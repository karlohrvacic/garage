import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/observation.dart';

final _now = DateTime.utc(2026, 9, 20);

Observation seen({
  String id = 'o1',
  String note = 'Rattles when cold',
  DateTime? noticedOn,
  DateTime? resolvedOn,
  String? addressedBy,
  String? tripId,
}) {
  return Observation(
    id: id,
    vehicleId: 'v1',
    noticedOn: noticedOn ?? DateTime.utc(2026, 9, 1),
    note: note,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 9, 1, 8),
    resolvedOn: resolvedOn,
    addressedBy: addressedBy,
    tripId: tripId,
  );
}

void main() {
  group('where an observation stands', () {
    test('one nobody has settled is open', () {
      expect(seen().isOpen, isTrue);
      expect(seen().state, ObservationState.open);
    });

    test('one with a resolution date is closed', () {
      final it = seen(resolvedOn: DateTime.utc(2026, 9, 10));

      expect(it.isOpen, isFalse);
      expect(it.state, ObservationState.resolved);
    });

    test('work performed does not by itself resolve anything', () {
      // The case the two fields exist for: the garage replaced a bush and the
      // noise is still there. A single "done" flag would call this finished.
      final it = seen(addressedBy: 's1');

      expect(it.addressed, isTrue);
      expect(it.isOpen, isTrue);
      expect(it.state, ObservationState.stillThere);
    });

    test('work performed and then settled is resolved', () {
      final it = seen(addressedBy: 's1', resolvedOn: DateTime.utc(2026, 9, 10));

      expect(it.state, ObservationState.resolved);
    });

    test('an observation on a journey knows which one', () {
      expect(seen(tripId: 't1').happenedOnATrip, isTrue);
      expect(seen().happenedOnATrip, isFalse);
    });
  });

  group('how long it has been going on', () {
    test('an open one is measured to today', () {
      expect(seen().openForAt(_now), const Duration(days: 19));
    });

    test('a resolved one is measured to when it stopped', () {
      final it = seen(resolvedOn: DateTime.utc(2026, 9, 6));

      expect(it.openForAt(_now), const Duration(days: 5));
    });

    test('never negative, whatever the dates say', () {
      final it = seen(noticedOn: DateTime.utc(2026, 10, 1));

      expect(it.openForAt(_now), Duration.zero);
    });
  });

  group('what to show first', () {
    test('open ones lead, and the oldest complaint leads those', () {
      // The rattle somebody has lived with for two months is the one to
      // mention at the counter, not the one noticed yesterday.
      final old = seen(id: 'old', noticedOn: DateTime.utc(2026, 7, 1));
      final recent = seen(id: 'recent', noticedOn: DateTime.utc(2026, 9, 15));
      final done = seen(
        id: 'done',
        noticedOn: DateTime.utc(2026, 6, 1),
        resolvedOn: DateTime.utc(2026, 6, 5),
      );

      final sorted = Observations.forDisplay([recent, done, old]);

      expect(sorted.map((it) => it.id), ['old', 'recent', 'done']);
    });

    test('among resolved ones the most recently settled leads', () {
      final older = seen(
        id: 'older',
        noticedOn: DateTime.utc(2026, 5, 1),
        resolvedOn: DateTime.utc(2026, 5, 4),
      );
      final newer = seen(
        id: 'newer',
        noticedOn: DateTime.utc(2026, 6, 1),
        resolvedOn: DateTime.utc(2026, 8, 1),
      );

      expect(Observations.forDisplay([older, newer]).map((it) => it.id), [
        'newer',
        'older',
      ]);
    });

    test('the still-there ones are what a mechanic is handed', () {
      // Work was done and it did not help. That is the most useful line on a
      // handover sheet, so it is worth being able to ask for on its own.
      final plain = seen(id: 'plain');
      final stillThere = seen(id: 'still', addressedBy: 's1');
      final done = seen(id: 'done', resolvedOn: DateTime.utc(2026, 9, 9));

      expect(Observations.open([plain, stillThere, done]).map((it) => it.id), [
        'plain',
        'still',
      ]);
      expect(
        Observations.stillThereAfterWork([
          plain,
          stillThere,
          done,
        ]).map((it) => it.id),
        ['still'],
      );
    });

    test('nothing recorded is an empty list, not a surprise', () {
      expect(Observations.forDisplay(const []), isEmpty);
      expect(Observations.open(const []), isEmpty);
    });
  });
}
