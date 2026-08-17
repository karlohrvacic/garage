import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/odometer_history.dart';

OdometerSample sample(int day, int km) =>
    OdometerSample(date: DateTime.utc(2026, 1, day), km: km);

void main() {
  group('merging a vehicle\'s odometer sightings', () {
    test('orders them oldest first whatever order they arrived in', () {
      final merged = OdometerHistory.sorted([
        sample(20, 3000),
        sample(1, 1000),
        sample(10, 2000),
      ]);

      expect(merged.map((s) => s.km), [1000, 2000, 3000]);
    });

    test('keeps only the highest reading of any one day', () {
      // A fill-up and the service that prompted it are logged on the same day
      // with the same odometer, or a rounded one. Two points a day apart by
      // zero kilometres would drag the daily rate towards nothing.
      final merged = OdometerHistory.sorted([
        sample(1, 1000),
        sample(1, 1010),
        sample(5, 1200),
      ]);

      expect(merged.map((s) => s.km), [1010, 1200]);
    });

    test('drops a reading that goes backwards, since one of them is wrong', () {
      final merged = OdometerHistory.sorted([
        sample(1, 1000),
        sample(5, 900),
        sample(9, 1200),
      ]);

      expect(merged.map((s) => s.km), [1000, 1200]);
    });
  });

  group('where the car stands now', () {
    test('is the highest reading anything has seen', () {
      expect(
        OdometerHistory.currentKm(
          baselineKm: 50000,
          samples: [sample(1, 51000), sample(5, 52000)],
        ),
        52000,
      );
    });

    test('is the baseline when nothing has been logged since', () {
      expect(
        OdometerHistory.currentKm(baselineKm: 50000, samples: const []),
        50000,
      );
    });

    test('never reads below the baseline', () {
      // Importing history from another app can land readings below where the
      // owner said the car stood when they added it.
      expect(
        OdometerHistory.currentKm(
          baselineKm: 50000,
          samples: [sample(1, 40000)],
        ),
        50000,
      );
    });
  });

  group('daily driving rate', () {
    test('is the span divided by the days it took', () {
      expect(OdometerHistory.kmPerDay([sample(1, 1000), sample(11, 1500)]), 50);
    });

    test('is measured across every source, not only fill-ups', () {
      // The bug this fixes: a household that logs services but pays cash for
      // fuel had no fuel entries to measure, so every projection fell back to
      // the assumed rate.
      expect(
        OdometerHistory.kmPerDay([sample(1, 1000), sample(21, 3000)]),
        100,
      );
    });

    test('is unmeasurable from a single reading', () {
      expect(OdometerHistory.kmPerDay([sample(1, 1000)]), isNull);
    });

    test('is unmeasurable when every reading lands on one day', () {
      expect(
        OdometerHistory.kmPerDay([sample(1, 1000), sample(1, 1200)]),
        isNull,
      );
    });

    test('is unmeasurable when the car has not moved', () {
      expect(
        OdometerHistory.kmPerDay([sample(1, 1000), sample(11, 1000)]),
        isNull,
      );
    });
  });
}
