import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stats/stats_period.dart';

final today = DateTime.utc(2026, 8, 17);

void main() {
  group('resolving a period to a range', () {
    test('all time has no bounds, so nothing is filtered out', () {
      final range = StatsPeriod.allTime.resolve(today);

      expect(range.contains(DateTime.utc(1999, 1, 1)), isTrue);
      expect(range.contains(DateTime.utc(2099, 1, 1)), isTrue);
    });

    test('this year runs from January to the end of December', () {
      final range = StatsPeriod.thisYear.resolve(today);

      expect(range.from, DateTime.utc(2026, 1, 1));
      expect(range.to, DateTime.utc(2026, 12, 31));
    });

    test('previous year is the whole of last year', () {
      final range = StatsPeriod.previousYear.resolve(today);

      expect(range.from, DateTime.utc(2025, 1, 1));
      expect(range.to, DateTime.utc(2025, 12, 31));
    });

    test('this month ends on the last day of the month, not the 30th', () {
      final range = StatsPeriod.thisMonth.resolve(today);

      expect(range.from, DateTime.utc(2026, 8, 1));
      expect(range.to, DateTime.utc(2026, 8, 31));
    });

    test('previous month rolls back across a year boundary', () {
      final range = StatsPeriod.previousMonth.resolve(DateTime.utc(2026, 1, 9));

      expect(range.from, DateTime.utc(2025, 12, 1));
      expect(range.to, DateTime.utc(2025, 12, 31));
    });

    test('the last twelve months ends today and starts a year back', () {
      final range = StatsPeriod.lastTwelveMonths.resolve(today);

      expect(range.from, DateTime.utc(2025, 8, 17));
      expect(range.to, DateTime.utc(2026, 8, 17));
    });
  });

  group('what a range contains', () {
    final range = DateRange(
      from: DateTime.utc(2026, 3, 1),
      to: DateTime.utc(2026, 3, 31),
    );

    test('includes both of its own ends', () {
      expect(range.contains(DateTime.utc(2026, 3, 1)), isTrue);
      expect(range.contains(DateTime.utc(2026, 3, 31)), isTrue);
    });

    test('excludes the day either side', () {
      expect(range.contains(DateTime.utc(2026, 2, 28)), isFalse);
      expect(range.contains(DateTime.utc(2026, 4, 1)), isFalse);
    });

    test('compares by calendar day, not by instant', () {
      // Entries are stored at UTC midnight but a range built from a local
      // picker can carry a time of day; comparing instants would drop the
      // last day of the range.
      final withTime = DateRange(
        from: DateTime.utc(2026, 3, 1, 14, 30),
        to: DateTime.utc(2026, 3, 31, 14, 30),
      );

      expect(withTime.contains(DateTime.utc(2026, 3, 31)), isTrue);
      expect(withTime.contains(DateTime.utc(2026, 3, 1)), isTrue);
    });
  });

  group('how many days a range covers', () {
    test('counts both ends', () {
      expect(
        DateRange(
          from: DateTime.utc(2026, 3, 1),
          to: DateTime.utc(2026, 3, 31),
        ).days,
        31,
      );
    });

    test('a single day is one day, never zero', () {
      // Zero would make every per-day average a division by zero.
      expect(
        DateRange(
          from: DateTime.utc(2026, 3, 1),
          to: DateTime.utc(2026, 3, 1),
        ).days,
        1,
      );
    });
  });

  group('narrowing a range to the days that could have had entries', () {
    test('leaves a real range alone', () {
      final march = DateRange(
        from: DateTime.utc(2026, 3, 1),
        to: DateTime.utc(2026, 3, 31),
      );

      // A month with one bill in it is still a month: "what does this car cost
      // me a month" divides by the month, not by the one day something
      // happened.
      expect(
        march.clampedTo(DateTime.utc(2026, 3, 10), DateTime.utc(2026, 3, 12)),
        march,
      );
    });

    test('narrows an unbounded range to the data it covers', () {
      // Otherwise "all time" is 1900 to 2200 and every per-day figure is a
      // total divided by three hundred years.
      final clamped = DateRange.unbounded.clampedTo(
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 3, 31),
      );

      expect(clamped.from, DateTime.utc(2026, 3, 1));
      expect(clamped.to, DateTime.utc(2026, 3, 31));
      expect(clamped.days, 31);
    });

    test('stays unbounded when there is no data to narrow it to', () {
      expect(DateRange.unbounded.clampedTo(null, null), DateRange.unbounded);
    });
  });
}
