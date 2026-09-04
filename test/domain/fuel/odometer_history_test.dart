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
      expect(OdometerHistory.kmPerDay([sample(1, 1000), sample(15, 1700)]), 50);
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

  group('the rate follows recent driving, not a lifetime average', () {
    test('a car that started driving more projects at the new rate', () {
      // Fourteen months at 20 km/day, then three months at 80. The lifetime
      // average is 28, which would put a 30,000 km service most of a year
      // later than this car is actually going to get there.
      final rate = OdometerHistory.kmPerDay([
        sample(1, 0),
        sample(100, 1980),
        sample(400, 7980),
        sample(430, 10380),
        sample(460, 12780),
      ]);

      expect(rate, closeTo(80, 0.001));
    });

    test('a window exactly as long as the minimum span counts', () {
      final rate = OdometerHistory.kmPerDay([
        sample(1, 0),
        sample(400, 7980),
        sample(421, 9660),
      ]);

      expect(rate, closeTo(80, 0.001));
    });

    test('a burst of readings over a few days does not set the rate', () {
      // Two fills a week apart on a road trip say nothing about how this car
      // is normally driven, and a window that short would let them treble
      // every projection. Too little to trust falls back to the whole series.
      final rate = OdometerHistory.kmPerDay([
        sample(1, 0),
        sample(301, 12000),
        sample(311, 13000),
      ]);

      expect(rate, closeTo(13000 / 310, 0.001));
    });

    test('three days of readings is not a rate', () {
      // One fill and one guessed "last service" reading three days apart
      // gave 1,873 km a day and a due date next week.
      expect(
        OdometerHistory.kmPerDay([sample(1, 140000), sample(4, 145620)]),
        isNull,
      );
    });

    test('says how many days it measured over', () {
      expect(
        OdometerHistory.rateMeasurement([sample(1, 1000), sample(15, 1700)]),
        (kmPerDay: 50.0, days: 14),
      );
    });

    test('a car with only a fortnight of history is still measurable', () {
      // The minimum span applies to choosing the window, never to the series
      // itself: a car added last week has nothing else to measure.
      expect(OdometerHistory.kmPerDay([sample(1, 1000), sample(15, 1700)]), 50);
    });
  });

  // A date decades out is a typo — a year fat-fingered on a date picker, or a
  // bad row in an imported file — and it does real damage on the way through.
  // [_window] anchors the rate to the newest reading, so one future sample
  // drags the 90-day window into the future and leaves the real recent driving
  // outside it; and `currentKm` takes the highest reading whatever its date, so
  // "where the car stands" jumps forward too.
  //
  // Guarded here rather than at the date picker because the sheet is not the
  // only door: the Fuelio and CSV importers and a restored backup all write
  // entries without passing one.
  group('a reading dated in the future', () {
    final today = DateTime.utc(2026, 1, 31);

    test('is left out of the series', () {
      final merged = OdometerHistory.sorted([
        sample(1, 1000),
        sample(20, 2000),
        OdometerSample(date: DateTime.utc(2027, 6, 1), km: 90000),
      ], asOf: today);

      expect(merged.map((s) => s.km), [1000, 2000]);
    });

    test('does not move where the car stands', () {
      final merged = OdometerHistory.sorted([
        sample(20, 2000),
        OdometerSample(date: DateTime.utc(2027, 6, 1), km: 90000),
      ], asOf: today);

      expect(OdometerHistory.currentKm(baselineKm: 0, samples: merged), 2000);
    });

    // The damage the guard exists to stop: without it the window anchors to
    // 2027 and the two real readings fall outside it entirely.
    test('does not drag the rate window off the real driving', () {
      final samples = [
        sample(1, 1000),
        sample(31, 2000),
        OdometerSample(date: DateTime.utc(2027, 6, 1), km: 90000),
      ];

      expect(
        OdometerHistory.kmPerDay(OdometerHistory.sorted(samples, asOf: today)),
        closeTo(1000 / 30, 0.001),
      );
    });

    // Today's own entry is not the future. Both sides are reduced to a
    // calendar date and compared as UTC, so a household east of UTC logging
    // its own today is not quietly ignored.
    test('but today itself is kept', () {
      final merged = OdometerHistory.sorted([
        sample(1, 1000),
        sample(31, 2000),
      ], asOf: DateTime(2026, 1, 31, 23, 30));

      expect(merged.map((s) => s.km), [1000, 2000]);
    });

    // Without a clock there is nothing to judge against, and the function
    // stays pure for callers that have none.
    test('is kept when no date is given to judge against', () {
      final merged = OdometerHistory.sorted([
        sample(1, 1000),
        OdometerSample(date: DateTime.utc(2027, 6, 1), km: 90000),
      ]);

      expect(merged.map((s) => s.km), [1000, 90000]);
    });
  });
}
