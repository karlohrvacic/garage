import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stations/price_trend.dart';

TrendPoint point(int day, double price, {int fuelTypeId = 2}) {
  return TrendPoint(
    date: DateTime.utc(2026, 8, day),
    fuelTypeId: fuelTypeId,
    avgPrice: price,
  );
}

void main() {
  group('picking one fuel out of the feed', () {
    test('keeps only that fuel', () {
      final series = PriceTrend.forFuel([
        point(1, 1.80, fuelTypeId: 1),
        point(1, 1.90, fuelTypeId: 2),
        point(2, 0.70, fuelTypeId: 3),
      ], 2);

      expect(series.map((p) => p.avgPrice), [1.90]);
    });

    // The feed arrives in whatever order it likes, and the screen's existing
    // "national average" trusts the last element to be the newest.
    test('sorts by date rather than trusting the order it arrived in', () {
      final series = PriceTrend.forFuel([
        point(3, 1.93),
        point(1, 1.90),
        point(2, 1.91),
      ], 2);

      expect(series.map((p) => p.avgPrice), [1.90, 1.91, 1.93]);
    });

    test('keeps one reading per day when the feed repeats one', () {
      final series = PriceTrend.forFuel([point(1, 1.90), point(1, 1.90)], 2);

      expect(series, hasLength(1));
    });

    test('a fuel the feed does not carry is an empty series, not an error', () {
      expect(PriceTrend.forFuel([point(1, 1.90)], 9), isEmpty);
    });
  });

  group('smoothing, because a single day is mostly noise', () {
    // Real figures: the national petrol average moved 5 cents a day on median
    // and once jumped 43, which is how many stations reported, not the market.
    test('averages each day with the days before it', () {
      final smoothed = PriceTrend.smoothed([
        point(1, 1.00),
        point(2, 2.00),
        point(3, 3.00),
      ], windowDays: 3);

      expect(smoothed.map((p) => p.avgPrice), [1.0, 1.5, 2.0]);
    });

    test('a spike is rejected outright, not merely diluted', () {
      final smoothed = PriceTrend.smoothed([
        point(1, 1.90),
        point(2, 1.90),
        point(3, 2.20),
      ], windowDays: 3);

      expect(
        smoothed.last.avgPrice,
        1.90,
        reason: 'a mean would have said 2.00 and invented a ten cent rise',
      );
    });

    // Straight from the feed: 30 July 2026 read 2.20 and 31 July read 1.89,
    // because barely any station reported on the Thursday. A week either side
    // of it sat at 1.88.
    test('a thin day and its bounce leave the week where it was', () {
      final series = [
        for (var day = 1; day <= 5; day++) point(day, 1.88),
        point(6, 2.20),
        point(7, 1.89),
      ];

      final smoothed = PriceTrend.smoothed(series);

      expect(smoothed.last.avgPrice, 1.88);
    });

    test('the window is days, not readings, so gaps do not stretch it', () {
      final smoothed = PriceTrend.smoothed([
        point(1, 1.00),
        point(20, 2.00),
      ], windowDays: 7);

      expect(
        smoothed.last.avgPrice,
        2.0,
        reason: 'a reading 19 days earlier is not part of a 7 day window',
      );
    });

    test('keeps the dates it was given', () {
      final smoothed = PriceTrend.smoothed([point(1, 1.0), point(2, 2.0)]);

      expect(smoothed.map((p) => p.date), [
        DateTime.utc(2026, 8, 1),
        DateTime.utc(2026, 8, 2),
      ]);
    });

    test('an empty series smooths to an empty one', () {
      expect(PriceTrend.smoothed(const []), isEmpty);
    });
  });

  group('which way prices moved', () {
    List<TrendPoint> fortnight(double first, double second) {
      return [
        for (var day = 1; day <= 7; day++) point(day, first),
        for (var day = 8; day <= 14; day++) point(day, second),
      ];
    }

    test('a rise is positive', () {
      final change = PriceTrend.change(fortnight(1.90, 1.93))!;

      expect(change.delta, closeTo(0.03, 1e-9));
      expect(change.rising, isTrue);
      expect(change.percent, closeTo(0.0158, 1e-3));
    });

    test('a fall is negative', () {
      final change = PriceTrend.change(fortnight(1.93, 1.90))!;

      expect(change.delta, closeTo(-0.03, 1e-9));
      expect(change.rising, isFalse);
    });

    test('a flat fortnight is steady rather than a rise of nothing', () {
      final change = PriceTrend.change(fortnight(1.90, 1.90))!;

      expect(change.steady, isTrue);
    });

    // Median daily movement is 5 cents, so a two-cent difference between two
    // weekly means is not a direction anybody should act on.
    test('a move smaller than the noise floor is steady', () {
      final change = PriceTrend.change(fortnight(1.90, 1.905))!;

      expect(change.steady, isTrue);
    });

    test('compares weekly means, not two individual days', () {
      final series = [
        for (var day = 1; day <= 7; day++) point(day, 1.90),
        for (var day = 8; day <= 13; day++) point(day, 1.93),
        // One wild day at the end must not become the whole answer.
        point(14, 2.60),
      ];

      final change = PriceTrend.change(series)!;

      expect(change.delta, lessThan(0.15));
    });
  });

  group('when it will not say', () {
    test('nothing at all', () {
      expect(PriceTrend.change(const []), isNull);
    });

    test(
      'only one week of history, so there is nothing to compare against',
      () {
        expect(
          PriceTrend.change([
            for (var day = 8; day <= 14; day++) point(day, 1.9),
          ]),
          isNull,
        );
      },
    );

    test('too few readings in a week to mean anything', () {
      final change = PriceTrend.change([
        point(1, 1.90),
        point(2, 1.90),
        point(13, 1.93),
        point(14, 1.93),
      ]);

      expect(change, isNull);
    });
  });

  group('the feed\'s thin days', () {
    // The failure this guards against: a mean would spread a 30 cent spike
    // across seven days as four cents of "rise", double the noise floor, and
    // the screen would announce a price movement that never happened.
    test('one wild day does not become a week-on-week movement', () {
      final series = [
        for (var day = 1; day <= 7; day++) point(day, 1.88),
        for (var day = 8; day <= 13; day++) point(day, 1.88),
        point(14, 2.20),
      ];

      final change = PriceTrend.change(series)!;

      expect(change.steady, isTrue);
      expect(change.delta, 0);
    });

    test('a real move still gets through', () {
      final series = [
        for (var day = 1; day <= 7; day++) point(day, 1.88),
        for (var day = 8; day <= 14; day++) point(day, 1.96),
      ];

      final change = PriceTrend.change(series)!;

      expect(change.rising, isTrue);
      expect(change.delta, closeTo(0.08, 1e-9));
    });
  });
}
