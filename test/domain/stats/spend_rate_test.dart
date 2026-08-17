import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stats/spend_rate.dart';

void main() {
  group('what a total works out to', () {
    test('per day is the total over the days it was spent across', () {
      const rate = SpendRate(total: 1000, days: 100, distanceKm: 2000);

      expect(rate.perDay, 10);
    });

    test('per unit of distance is the total over the distance covered', () {
      const rate = SpendRate(total: 1000, days: 100, distanceKm: 2000);

      expect(rate.perKm, 0.5);
    });

    test('per day is unknown when no time has passed', () {
      const rate = SpendRate(total: 1000, days: 0, distanceKm: 2000);

      expect(rate.perDay, isNull);
    });

    test('per distance is unknown when the car has not moved', () {
      // A household that logs registration and insurance but no odometer
      // readings has a real total and no distance to divide it by. Zero would
      // be a lie and infinity would be worse.
      const rate = SpendRate(total: 1000, days: 100, distanceKm: 0);

      expect(rate.perKm, isNull);
    });
  });

  group('summing entries into a rate', () {
    test('adds up only what falls inside the range', () {
      final rate = SpendRate.of(
        amounts: [
          (DateTime.utc(2026, 2, 1), 100.0),
          (DateTime.utc(2026, 3, 15), 200.0),
          (DateTime.utc(2026, 4, 1), 400.0),
        ],
        from: DateTime.utc(2026, 3, 1),
        to: DateTime.utc(2026, 3, 31),
        distanceKm: 500,
      );

      expect(rate.total, 200);
      expect(rate.days, 31);
      expect(rate.distanceKm, 500);
    });

    test('an empty range still reports its own length', () {
      // Otherwise "nothing spent in March" would report an unknown per-day
      // rather than zero, which is a different and wrong claim.
      final rate = SpendRate.of(
        amounts: const [],
        from: DateTime.utc(2026, 3, 1),
        to: DateTime.utc(2026, 3, 31),
        distanceKm: 0,
      );

      expect(rate.total, 0);
      expect(rate.perDay, 0);
    });
  });
}
