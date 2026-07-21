import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/features/maintenance/widgets/maintenance_calendar.dart';

ReminderProjection at(DateTime date, String id) {
  return ReminderProjection(
    ruleId: id,
    vehicleId: 'v1',
    serviceTypeKey: 'service_oil_change',
    projectedDueDate: date,
    state: ReminderState.upcoming,
  );
}

void main() {
  test('items on the same day share one entry', () {
    final grouped = groupByDay([
      at(DateTime(2026, 8, 1), 'a'),
      at(DateTime(2026, 8, 1), 'b'),
      at(DateTime(2026, 8, 5), 'c'),
    ]);

    expect(grouped[DateTime(2026, 8, 1)], hasLength(2));
    expect(grouped[DateTime(2026, 8, 5)], hasLength(1));
  });

  test('the time of day does not split a group', () {
    final grouped = groupByDay([
      at(DateTime(2026, 8, 1, 9), 'a'),
      at(DateTime(2026, 8, 1, 17), 'b'),
    ]);

    expect(grouped.keys, [DateTime(2026, 8, 1)]);
  });

  test('no projections groups to nothing', () {
    expect(groupByDay([]), isEmpty);
  });
}
