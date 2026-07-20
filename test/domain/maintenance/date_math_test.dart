import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/date_math.dart';

void main() {
  group('addMonths', () {
    test('adds whole months within a year', () {
      expect(DateMath.addMonths(DateTime(2026, 1, 15), 3), DateTime(2026, 4, 15));
    });

    test('rolls over the year boundary', () {
      expect(DateMath.addMonths(DateTime(2026, 11, 10), 3), DateTime(2027, 2, 10));
    });

    test('clamps a day that the target month does not have', () {
      expect(DateMath.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('clamps to 29 February in a leap year', () {
      expect(DateMath.addMonths(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    });

    test('handles a 24-month interval', () {
      expect(DateMath.addMonths(DateTime(2026, 6, 1), 24), DateTime(2028, 6, 1));
    });

    test('subtracts a single month across the year boundary', () {
      expect(
        DateMath.addMonths(DateTime(2026, 1, 15), -1),
        DateTime(2025, 12, 15),
      );
    });

    test('subtracts more than a year', () {
      expect(
        DateMath.addMonths(DateTime(2026, 1, 15), -13),
        DateTime(2024, 12, 15),
      );
    });

    test('subtracts an exact multiple of twelve months', () {
      expect(
        DateMath.addMonths(DateTime(2026, 1, 15), -12),
        DateTime(2025, 1, 15),
      );
      expect(
        DateMath.addMonths(DateTime(2026, 1, 15), -24),
        DateTime(2024, 1, 15),
      );
    });

    test('clamps the day when subtracting a month', () {
      expect(
        DateMath.addMonths(DateTime(2026, 3, 31), -1),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('dateOnly', () {
    test('strips the time component', () {
      expect(
        DateMath.dateOnly(DateTime(2026, 5, 4, 13, 45, 12)),
        DateTime(2026, 5, 4),
      );
    });
  });

  group('daysBetween', () {
    test('counts forward days', () {
      expect(
        DateMath.daysBetween(DateTime(2026, 1, 1), DateTime(2026, 1, 31)),
        30,
      );
    });

    test('is negative when the end precedes the start', () {
      expect(
        DateMath.daysBetween(DateTime(2026, 1, 31), DateTime(2026, 1, 1)),
        -30,
      );
    });

    test('ignores the time of day', () {
      expect(
        DateMath.daysBetween(
          DateTime(2026, 1, 1, 23, 59),
          DateTime(2026, 1, 2, 0, 1),
        ),
        1,
      );
    });
  });
}
