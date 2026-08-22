import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/winter_tyre_period.dart';

DateTime day(int year, int month, int dayOfMonth) =>
    DateTime.utc(year, month, dayOfMonth);

void main() {
  group('what a country requires', () {
    test('Croatia is dated and does not care about the weather', () {
      final period = winterTyrePeriodFor('HR');

      expect(period.rule, WinterTyreRule.dated);
      expect(period.start, const MonthDay(11, 15));
      expect(period.end, const MonthDay(4, 15));
    });

    test('Austria is dated but only binds when the road is wintry', () {
      final period = winterTyrePeriodFor('AT');

      expect(period.rule, WinterTyreRule.datedWhenWintry);
      expect(period.start, const MonthDay(11, 1));
      expect(period.end, const MonthDay(4, 15));
    });

    test('Germany has no dates at all', () {
      final period = winterTyrePeriodFor('DE');

      expect(period.rule, WinterTyreRule.whenWintryOnly);
      expect(period.start, isNull);
      expect(period.end, isNull);
    });

    test('a country the app has not verified claims nothing', () {
      for (final code in ['GB', 'US', 'IT', 'ZZ', '']) {
        expect(
          winterTyrePeriodFor(code).rule,
          WinterTyreRule.none,
          reason: '$code should not be given a window nobody checked',
        );
      }
    });

    test('the country code is read case-insensitively', () {
      expect(winterTyrePeriodFor('hr').rule, WinterTyreRule.dated);
    });
  });

  group('the next swap in Croatia', () {
    SeasonalSwap? next(DateTime today) =>
        nextSeasonalSwap(countryCode: 'HR', today: today);

    test('autumn points at the winter date', () {
      final swap = next(day(2026, 10, 1))!;

      expect(swap.date, day(2026, 11, 15));
      expect(swap.direction, SwapDirection.toWinter);
    });

    test('the first day of the window is the swap, not a missed one', () {
      // The tyres have to be on *by* the 15th, so on the 15th the swap is due
      // today rather than six months away.
      final swap = next(day(2026, 11, 15))!;

      expect(swap.date, day(2026, 11, 15));
      expect(swap.direction, SwapDirection.toWinter);
    });

    test('the day after, the next thing to do is the spring swap', () {
      final swap = next(day(2026, 11, 16))!;

      expect(swap.date, day(2027, 4, 15));
      expect(swap.direction, SwapDirection.toSummer);
    });

    test('midwinter crosses the year end into spring', () {
      final swap = next(day(2026, 12, 31))!;

      expect(swap.date, day(2027, 4, 15));
      expect(swap.direction, SwapDirection.toSummer);
    });

    test('after the spring date the next is the following winter', () {
      final swap = next(day(2026, 4, 16))!;

      expect(swap.date, day(2026, 11, 15));
      expect(swap.direction, SwapDirection.toWinter);
    });
  });

  test('Slovenia comes out of winter a month before Croatia', () {
    final swap = nextSeasonalSwap(countryCode: 'SI', today: day(2026, 12, 1))!;

    expect(swap.date, day(2027, 3, 15));
    expect(swap.direction, SwapDirection.toSummer);
  });

  test('a country with no window has no swap to point at', () {
    for (final code in ['DE', 'GB', 'US', 'IT']) {
      expect(
        nextSeasonalSwap(countryCode: code, today: day(2026, 10, 1)),
        isNull,
        reason: '$code has no statutory date to pin a reminder to',
      );
    }
  });
}
