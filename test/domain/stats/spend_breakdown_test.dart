import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stats/spend_breakdown.dart';

void main() {
  group('grouping amounts by their label', () {
    test('sums repeats and orders biggest first', () {
      final slices = SpendBreakdown.group([
        ('INA', 40.0),
        ('Petrol', 100.0),
        ('INA', 20.0),
      ]);

      expect(slices.map((s) => s.label), ['Petrol', 'INA']);
      expect(slices.map((s) => s.amount), [100, 60]);
    });

    test('drops anything that adds up to nothing', () {
      // A zero slice is invisible in a donut but still takes a legend row and
      // a colour, which reads as a category that cost nothing rather than as
      // one that was never used.
      final slices = SpendBreakdown.group([('INA', 0.0), ('Petrol', 10.0)]);

      expect(slices.map((s) => s.label), ['Petrol']);
    });

    test('groups everything unlabelled together', () {
      final slices = SpendBreakdown.group([
        (null, 10.0),
        ('INA', 5.0),
        ('', 15.0),
      ]);

      expect(slices.first.label, isNull);
      expect(slices.first.amount, 25);
    });
  });

  group('keeping a chart legible', () {
    /// Already ordered biggest first, the way [SpendBreakdown.group] returns
    /// them — [SpendBreakdown.topN] trims a list, it does not sort one.
    List<SpendSlice> descending(int count) => [
      for (var i = count; i >= 1; i--) SpendSlice(label: 'S$i', amount: i * 10),
    ];

    test('keeps the biggest few and rolls the tail into one slice', () {
      final capped = SpendBreakdown.topN(descending(8), 4);

      expect(capped.map((s) => s.label), ['S8', 'S7', 'S6', 'S5', null]);
      // 40 + 30 + 20 + 10 for the four that were rolled up.
      expect(capped.last.amount, 100);
      expect(capped.last.isOthers, isTrue);
    });

    test('leaves a short list exactly as it is', () {
      final capped = SpendBreakdown.topN(descending(3), 4);

      expect(capped.map((s) => s.label), ['S3', 'S2', 'S1']);
      expect(capped.any((s) => s.isOthers), isFalse);
    });

    test('does not roll up a single leftover into an Others of one', () {
      // "Others — €10" beside four named slices, where Others *is* one named
      // thing, hides a name for no gain.
      final capped = SpendBreakdown.topN(descending(5), 4);

      expect(capped, hasLength(5));
      expect(capped.any((s) => s.isOthers), isFalse);
    });
  });
}
