import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/stats/time_axis.dart';

void main() {
  // The chart used to label its axis at the first reading, the last, and the
  // day halfway between — "7/25", "2/26", "9/26" — which read as three dates
  // somebody picked at random. A reader wants to know where the years and
  // the quarters are, and those are calendar facts, not properties of the
  // data.
  group('a time axis', () {
    final fourteenMonths = TimeAxis(
      first: DateTime.utc(2025, 7, 20),
      last: DateTime.utc(2026, 9, 15),
    );

    test('puts its ticks on the calendar, not on the data', () {
      expect(fourteenMonths.unitMonths, 3);
      expect(fourteenMonths.ticks, [
        DateTime.utc(2025, 10),
        DateTime.utc(2026, 1),
        DateTime.utc(2026, 4),
        DateTime.utc(2026, 7),
      ]);
    });

    test('lines its unit up with the calendar, not with the first reading', () {
      final fromAugust = TimeAxis(
        first: DateTime.utc(2025, 8, 20),
        last: DateTime.utc(2026, 10, 15),
      );

      expect(fromAugust.ticks.first, DateTime.utc(2025, 10));
      expect(fromAugust.ticks, contains(DateTime.utc(2026, 1)));
    });

    test('picks the finest unit that gives at most five ticks', () {
      int unitOver({required int months}) => TimeAxis(
        first: DateTime.utc(2020, 1, 15),
        last: DateTime.utc(2020, 1 + months, 15),
      ).unitMonths;

      expect(unitOver(months: 2), 1);
      expect(unitOver(months: 5), 1);
      expect(unitOver(months: 14), 3);
      expect(unitOver(months: 24), 6);
      expect(unitOver(months: 48), 12);
      expect(unitOver(months: 120), 24);
      expect(unitOver(months: 300), 60);
    });

    test('a month boundary is a whole number, with the day inside it', () {
      expect(TimeAxis.x(DateTime.utc(2026, 1, 1)), 312);
      expect(TimeAxis.x(DateTime.utc(2026, 1, 16)), 312 + 15 / 31);
      expect(
        TimeAxis.x(DateTime.utc(2026, 2, 28)),
        closeTo(313 + 27 / 28, 1e-9),
      );
    });

    test(
      'a tick is a multiple of its unit, so a January is a multiple of 12',
      () {
        expect(TimeAxis.x(DateTime.utc(2026, 1, 1)) % 12, 0);
        expect(TimeAxis.x(DateTime.utc(2025, 10, 1)) % 3, 0);
      },
    );

    test('reads a month back from a value a hair off the boundary', () {
      // fl_chart walks the axis by adding the interval, so what comes back is
      // never quite the integer that went in.
      expect(fourteenMonths.monthAt(309.0000000001), DateTime.utc(2025, 10));
      expect(fourteenMonths.monthAt(311.9999999999), DateTime.utc(2026, 1));
    });

    test('spans the data exactly', () {
      expect(fourteenMonths.minX, TimeAxis.x(DateTime.utc(2025, 7, 20)));
      expect(fourteenMonths.maxX, TimeAxis.x(DateTime.utc(2026, 9, 15)));
    });

    test('a boundary on the first or last day is not a tick', () {
      // The chart draws those two as the ends of the axis; a label there
      // would hang half outside the plot.
      final axis = TimeAxis(
        first: DateTime.utc(2025, 10, 1),
        last: DateTime.utc(2026, 4, 1),
      );

      expect(axis.unitMonths, 1);
      expect(axis.ticks.first, DateTime.utc(2025, 11));
      expect(axis.ticks.last, DateTime.utc(2026, 3));
    });

    test('a span inside one month has no ticks at all', () {
      final axis = TimeAxis(
        first: DateTime.utc(2026, 1, 3),
        last: DateTime.utc(2026, 1, 23),
      );

      expect(axis.ticks, isEmpty);
    });
  });
}
