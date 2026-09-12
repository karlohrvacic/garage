import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';
import 'package:garage/domain/fuel/full_tank_range.dart';

EconomyPoint tank(
  double litersPer100Km, {
  DateTime? on,
  double distance = 500,
}) => EconomyPoint(
  entryId: 'e$litersPer100Km',
  date: on ?? DateTime.utc(2026, 3, 9),
  odometerKm: 100000,
  litersPer100Km: litersPer100Km,
  distanceKm: distance,
  volumeL: distance * litersPer100Km / 100,
);

void main() {
  group('how far a full tank goes', () {
    test('the typical figure is the tank at the car\'s usual consumption', () {
      // 60 litres at 8.5 l/100km is 705 km, which is the number a driver can
      // plan a journey against — unlike "range left", it does not depend on
      // anybody having logged an odometer reading lately.
      final range = fullTankRange(
        tankCapacityL: 60,
        points: [tank(8.0), tank(9.0)],
      );

      expect(range!.typicalKm, closeTo(705.88, 0.01));
      expect(range.typicalLitersPer100Km, closeTo(8.5, 0.01));
    });

    test('the best tank is the one that used the LEAST fuel', () {
      // The inversion this test exists for: best economy is the *lowest*
      // l/100km, which is the *longest* range. Reading it the other way round
      // swaps the two figures on the card and nothing else complains.
      final range = fullTankRange(
        tankCapacityL: 60,
        points: [tank(9.4), tank(7.7), tank(8.5)],
      );

      expect(range!.bestLitersPer100Km, 7.7);
      expect(range.worstLitersPer100Km, 9.4);
      expect(range.bestKm, greaterThan(range.worstKm));
      expect(range.bestKm, closeTo(779.22, 0.01));
      expect(range.worstKm, closeTo(638.30, 0.01));
    });

    test('the typical figure is weighted by distance, not by tank count', () {
      // One short thirsty tank should not count as much as a long frugal one.
      // `FuelEconomy.average` already does this; the range inherits it rather
      // than averaging the averages, which would say something different.
      final range = fullTankRange(
        tankCapacityL: 50,
        points: [tank(20, distance: 10), tank(5, distance: 1000)],
      );

      expect(range!.typicalLitersPer100Km, closeTo(5.15, 0.01));
    });

    test('one tank has no spread, and says so by agreeing with itself', () {
      final range = fullTankRange(tankCapacityL: 60, points: [tank(8.5)]);

      expect(range!.tanks, 1);
      expect(range.bestKm, range.typicalKm);
      expect(range.worstKm, range.typicalKm);
    });

    test('tanks that came out the same are a spread of nothing', () {
      // `EconomyRange` calls this "no scale to place anything on" and returns
      // null, because a ring needs a spread to swing on. A range card does
      // not: "every tank went about this far" is a perfectly good answer.
      final range = fullTankRange(
        tankCapacityL: 60,
        points: [tank(8.5), tank(8.5), tank(8.5)],
      );

      expect(range!.tanks, 3);
      expect(range.bestKm, closeTo(range.worstKm, 0.001));
    });
  });

  group('when there is nothing honest to say', () {
    test('a car with no tank capacity has no range', () {
      // Most cars in the app have never been told their tank size. The card
      // shows nothing rather than an em dash: the old range row proved that a
      // permanent "—" under a label reads as a broken feature.
      expect(fullTankRange(tankCapacityL: null, points: [tank(8.5)]), isNull);
      expect(fullTankRange(tankCapacityL: 0, points: [tank(8.5)]), isNull);
    });

    test('a car with no closed tank has no economy to work from', () {
      expect(fullTankRange(tankCapacityL: 60, points: []), isNull);
    });

    test('a nonsensical consumption is refused rather than divided by', () {
      expect(fullTankRange(tankCapacityL: 60, points: [tank(0)]), isNull);
    });

    test('and it is refused even when it is only the first of several', () {
      // The seeding bug: the loop skips a tank that worked out to zero, but
      // best and worst were seeded from `points.first` *before* the loop, so
      // one zero tank at the front left best at zero and a best range of
      // `60 * 100 / 0` — infinity, printed as a distance. A stored row cannot
      // be zero, but a queued offline entry reaches a read before the
      // database sees it.
      final range = fullTankRange(
        tankCapacityL: 60,
        points: [tank(0), tank(8.5)],
      );

      expect(range!.bestKm, closeTo(705.88, 0.01));
      expect(range.bestKm.isFinite, isTrue);
      expect(range.worstKm.isFinite, isTrue);
    });

    test('a history of nothing but zero tanks has no range at all', () {
      expect(
        fullTankRange(tankCapacityL: 60, points: [tank(0), tank(0)]),
        isNull,
      );
    });
  });
}
