import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/economy_deviation.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';

EconomyPoint tank(String id, double litersPer100Km, {double distanceKm = 500}) {
  return EconomyPoint(
    entryId: id,
    date: DateTime.utc(2026, 8, 1),
    odometerKm: 50000,
    litersPer100Km: litersPer100Km,
    distanceKm: distanceKm,
    volumeL: litersPer100Km * distanceKm / 100,
  );
}

/// Five tanks at six litres, which is enough history for a verdict.
List<EconomyPoint> steady({int count = 5, double economy = 6}) {
  return [for (var i = 0; i < count; i++) tank('f$i', economy)];
}

void main() {
  group('how this tank compares with the rest', () {
    test('a thirstier tank is a positive deviation', () {
      final points = [...steady(), tank('odd', 7.5)];

      final deviation = deviationFor('odd', points);

      expect(deviation, closeTo(0.25, 1e-9));
    });

    test('a frugal tank is a negative one', () {
      final points = [...steady(), tank('odd', 4.5)];

      expect(deviationFor('odd', points), closeTo(-0.25, 1e-9));
    });

    test('a tank at the average deviates by nothing', () {
      expect(deviationFor('f0', steady()), 0);
    });

    // A tank compared against an average it is itself inside drags that
    // average towards itself and understates how odd it was.
    test('is measured against the other tanks, not against itself', () {
      final points = [tank('a', 6), tank('b', 6), tank('c', 6), tank('d', 12)];

      expect(
        deviationFor('d', points),
        closeTo(1.0, 1e-9),
        reason: 'twice the others, not 60% above an average it inflated',
      );
    });

    test('weights the others by distance, as the app average does', () {
      final points = [
        tank('short', 10, distanceKm: 100),
        tank('middle', 5, distanceKm: 400),
        tank('long', 5, distanceKm: 500),
        tank('subject', 5.5, distanceKm: 500),
      ];

      // 10 litres over 100 km plus 45 over 900 is 55 litres over 1000 km:
      // 5.5 l/100km weighted, against 6.67 if the three were simply averaged.
      expect(deviationFor('subject', points), closeTo(0, 1e-9));
    });
  });

  group('when there is not enough to compare against', () {
    // The threshold StationEconomy already settled on, for the same reason:
    // below it, one unusual tank simply is the average.
    test('fewer than three other tanks says nothing', () {
      final points = [tank('a', 6), tank('b', 6), tank('subject', 9)];

      expect(deviationFor('subject', points), isNull);
    });

    test('three others is enough', () {
      final points = [tank('a', 6), tank('b', 6), tank('c', 6), tank('s', 9)];

      expect(deviationFor('s', points), isNotNull);
    });

    test('an entry with no economy figure of its own', () {
      expect(deviationFor('missing', steady()), isNull);
    });

    test('nothing at all', () {
      expect(deviationFor('x', const []), isNull);
    });
  });

  group('what counts as worth mentioning', () {
    test('a deviation inside the noise floor is not', () {
      expect(worthMentioning(0.04), isFalse);
      expect(worthMentioning(-0.04), isFalse);
    });

    test('a tenth either way is', () {
      expect(worthMentioning(0.10), isTrue);
      expect(worthMentioning(-0.10), isTrue);
    });

    test('nothing to say about nothing', () {
      expect(worthMentioning(null), isFalse);
    });
  });
}
