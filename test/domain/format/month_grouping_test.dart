import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/format/month_grouping.dart';

void main() {
  group('MonthGrouping.of', () {
    test('one item is one group', () {
      final groups = MonthGrouping.of([DateTime.utc(2026, 8, 3)], (d) => d);

      expect(groups, hasLength(1));
      expect(groups.single.month, DateTime.utc(2026, 8));
      expect(groups.single.items, [DateTime.utc(2026, 8, 3)]);
    });

    test('items in the same month join one group, in their given order', () {
      final groups = MonthGrouping.of([
        DateTime.utc(2026, 8, 20),
        DateTime.utc(2026, 8, 3),
      ], (d) => d);

      expect(groups, hasLength(1));
      expect(groups.single.items, [
        DateTime.utc(2026, 8, 20),
        DateTime.utc(2026, 8, 3),
      ]);
    });

    test('a new month starts a new group even if items are not pre-sorted', () {
      // Grouping does not sort — every caller already has a sort order (newest
      // first, oldest first) that it does not want disturbed. Two visits to
      // the same month that are not adjacent produce two groups, which is the
      // caller's list telling the truth about its own order.
      final groups = MonthGrouping.of([
        DateTime.utc(2026, 8, 3),
        DateTime.utc(2026, 7, 20),
        DateTime.utc(2026, 8, 1),
      ], (d) => d);

      expect(groups.map((g) => g.month), [
        DateTime.utc(2026, 8),
        DateTime.utc(2026, 7),
        DateTime.utc(2026, 8),
      ]);
    });

    test('an empty list groups to nothing', () {
      expect(MonthGrouping.of(<DateTime>[], (d) => d), isEmpty);
    });

    test('groups by calendar month regardless of day or time', () {
      final groups = MonthGrouping.of([
        DateTime.utc(2026, 8, 1, 23, 59),
        DateTime.utc(2026, 8, 31, 0, 1),
      ], (d) => d);

      expect(groups, hasLength(1));
    });

    test('works over any type via the date selector', () {
      final groups = MonthGrouping.of(['a', 'b'], (s) => DateTime.utc(2026, 1));

      expect(groups.single.items, ['a', 'b']);
    });
  });

  group('flattening for a lazy list', () {
    // A builder-backed list wants one flat index space: header, items,
    // header, items. The groups stay as they were; this only lays them out.
    test('interleaves a header before each month', () {
      final groups = MonthGrouping.of([
        DateTime.utc(2026, 3, 5),
        DateTime.utc(2026, 3, 1),
        DateTime.utc(2026, 2, 9),
      ], (d) => d);

      final slots = MonthGrouping.flatten(groups);

      expect(slots, hasLength(5));
      expect(slots[0], isA<MonthHeaderSlot<DateTime>>());
      expect(
        (slots[0] as MonthHeaderSlot<DateTime>).group.month,
        DateTime.utc(2026, 3),
      );
      expect(
        (slots[1] as MonthItemSlot<DateTime>).item,
        DateTime.utc(2026, 3, 5),
      );
      expect(
        (slots[2] as MonthItemSlot<DateTime>).item,
        DateTime.utc(2026, 3, 1),
      );
      expect(slots[3], isA<MonthHeaderSlot<DateTime>>());
      expect(
        (slots[4] as MonthItemSlot<DateTime>).item,
        DateTime.utc(2026, 2, 9),
      );
    });

    test('nothing flattens to nothing', () {
      expect(MonthGrouping.flatten<DateTime>(const []), isEmpty);
    });
  });
}
