import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stats/stats_math.dart';

class _Dated {
  const _Dated(this.date, this.value, [this.odometer = 0]);

  final DateTime date;
  final double value;
  final int odometer;
}

void main() {
  final today = DateTime.utc(2026, 7, 28);

  group('compare', () {
    test('buckets sums into year and month windows', () {
      final items = [
        _Dated(DateTime.utc(2026, 7, 1), 10),
        _Dated(DateTime.utc(2026, 7, 27), 5),
        _Dated(DateTime.utc(2026, 6, 15), 7),
        _Dated(DateTime.utc(2026, 1, 2), 3),
        _Dated(DateTime.utc(2025, 12, 31), 20),
        _Dated(DateTime.utc(2024, 7, 1), 100),
      ];

      final result = StatsMath.compare<_Dated>(
        items: items,
        date: (i) => i.date,
        value: (i) => i.value,
        today: today,
      );

      expect(result.thisYear, 25);
      expect(result.previousYear, 20);
      expect(result.thisMonth, 15);
      expect(result.previousMonth, 7);
    });

    test('january rolls the previous month into the prior year', () {
      final january = DateTime.utc(2026, 1, 15);
      final items = [
        _Dated(DateTime.utc(2025, 12, 20), 8),
        _Dated(DateTime.utc(2026, 1, 3), 2),
      ];

      final result = StatsMath.compare<_Dated>(
        items: items,
        date: (i) => i.date,
        value: (i) => i.value,
        today: january,
      );

      expect(result.thisMonth, 2);
      expect(result.previousMonth, 8);
    });
  });

  group('distanceCovered', () {
    test('spans min to max regardless of order', () {
      expect(StatsMath.distanceCovered([46818, 47006, 46500]), 506);
    });

    test('needs at least two distinct readings', () {
      expect(StatsMath.distanceCovered([47006]), isNull);
      expect(StatsMath.distanceCovered([47006, 47006]), isNull);
      expect(StatsMath.distanceCovered(const []), isNull);
    });
  });

  group('distanceInPeriod', () {
    test('only counts readings dated inside the period', () {
      final items = [
        _Dated(DateTime.utc(2026, 7, 1), 0, 46500),
        _Dated(DateTime.utc(2026, 7, 27), 0, 47006),
        _Dated(DateTime.utc(2025, 3, 1), 0, 30000),
      ];

      final distance = StatsMath.distanceInPeriod<_Dated>(
        items: items,
        date: (i) => i.date,
        odometer: (i) => i.odometer,
        inPeriod: (d) => d.year == 2026,
      );

      expect(distance, 506);
    });
  });

  group('spanDays', () {
    test('floors at one day for same-day activity', () {
      expect(StatsMath.spanDays([DateTime.utc(2026, 7, 1)]), 1);
    });

    test('measures first to last', () {
      expect(
        StatsMath.spanDays([
          DateTime.utc(2026, 7, 1),
          DateTime.utc(2026, 7, 11),
          DateTime.utc(2026, 7, 5),
        ]),
        10,
      );
    });

    test('empty input yields zero', () {
      expect(StatsMath.spanDays(const []), 0);
    });
  });
}
