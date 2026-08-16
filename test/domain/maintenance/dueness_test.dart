import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';

final today = DateTime.utc(2026, 8, 16);

ReminderProjection projection({
  double? fractionConsumed,
  DateTime? due,
  ReminderState state = ReminderState.upcoming,
}) {
  return ReminderProjection(
    ruleId: 'r1',
    vehicleId: 'v1',
    serviceTypeKey: 'service_tire_swap_seasonal',
    projectedDueDate: due ?? DateTime.utc(2026, 12, 1),
    state: state,
    fractionConsumed: fractionConsumed,
  );
}

void main() {
  group('dueness', () {
    // One number, one meaning, everywhere it is shown: 0 is freshly done, 1 is
    // due now. Two screens previously showed the same item as 100% and 26%
    // because one meant "time left" and the other meant "interval used".
    test('is how much of the interval is used, when there is an interval', () {
      expect(projection(fractionConsumed: 0.26).dueness(today), 0.26);
    });

    test('is full for something already overdue', () {
      final subject = projection(
        fractionConsumed: 1.4,
        due: DateTime.utc(2026, 7, 1),
      );

      expect(subject.dueness(today), 1);
    });

    test('never exceeds full, so a gauge cannot overflow', () {
      expect(projection(fractionConsumed: 3).dueness(today), 1);
    });

    group('without an interval to measure', () {
      test('a due date far off reads as barely due', () {
        final subject = projection(due: DateTime.utc(2027, 8, 16));

        expect(subject.dueness(today), lessThan(0.1));
      });

      test('a due date today reads as due', () {
        final subject = projection(due: today);

        expect(subject.dueness(today), 1);
      });

      test('a date inside the notice window reads as nearly due', () {
        // The projector calls something due within 14 days; the gauge should
        // agree rather than looking relaxed.
        final subject = projection(due: DateTime.utc(2026, 8, 23));

        expect(subject.dueness(today), greaterThan(0.8));
      });

      test('rises as the date approaches', () {
        final far = projection(due: DateTime.utc(2026, 11, 1)).dueness(today);
        final near = projection(due: DateTime.utc(2026, 9, 1)).dueness(today);

        expect(near, greaterThan(far));
      });
    });
  });
}
