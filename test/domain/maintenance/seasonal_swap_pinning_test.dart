import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/maintenance/reminder_projection.dart';
import 'package:garage/domain/maintenance/winter_tyre_period.dart';

ReminderRule swapRule() => const ReminderRule(
  id: 'r1',
  vehicleId: 'v1',
  serviceTypeKey: 'service_tire_swap_seasonal',
  intervalMonths: 6,
);

ReminderProjection projectSwap({
  required DateTime lastSwap,
  required DateTime today,
}) {
  return ReminderProjector.project(
    rule: swapRule(),
    lastServiceDate: lastSwap,
    lastServiceOdometerKm: null,
    currentOdometerKm: 50000,
    kmPerDay: 30,
    today: today,
  )!;
}

void main() {
  group('a seasonal swap pinned to the statutory date', () {
    final today = DateTime.utc(2026, 10, 1);

    test('takes the statutory date over the six-month interval', () {
      // Swapped in late June, so the interval says late December — a date
      // nothing in the world happens on.
      final loose = projectSwap(
        lastSwap: DateTime.utc(2026, 6, 20),
        today: today,
      );
      expect(loose.projectedDueDate, DateTime(2026, 12, 20));

      final pinned = ReminderProjector.pinToSeasonalSwap(
        projection: loose,
        swap: nextSeasonalSwap(countryCode: 'HR', today: today)!,
        today: today,
      );

      expect(pinned.projectedDueDate, DateTime.utc(2026, 11, 15));
    });

    test('keeps the rule and vehicle it came from', () {
      final loose = projectSwap(
        lastSwap: DateTime.utc(2026, 6, 20),
        today: today,
      );
      final pinned = ReminderProjector.pinToSeasonalSwap(
        projection: loose,
        swap: nextSeasonalSwap(countryCode: 'HR', today: today)!,
        today: today,
      );

      expect(pinned.ruleId, loose.ruleId);
      expect(pinned.vehicleId, loose.vehicleId);
      expect(pinned.serviceTypeKey, 'service_tire_swap_seasonal');
    });

    test('reads as a dated item, not an interval one', () {
      // A fixed calendar date is not "half consumed" in January in any sense a
      // reader would recognise. Dropping the fraction puts it on the same
      // 90-day approach the app already uses for dated one-offs.
      final loose = projectSwap(
        lastSwap: DateTime.utc(2026, 6, 20),
        today: today,
      );
      final pinned = ReminderProjector.pinToSeasonalSwap(
        projection: loose,
        swap: nextSeasonalSwap(countryCode: 'HR', today: today)!,
        today: today,
      );

      expect(pinned.fractionConsumed, isNull);
      expect(pinned.dueOdometerKm, isNull);
      expect(pinned.dateFromDistance, isNull);
      expect(pinned.dateFromTime, DateTime.utc(2026, 11, 15));
    });

    test('is due once it is inside the notice window', () {
      final near = DateTime.utc(2026, 11, 10);
      final loose = projectSwap(
        lastSwap: DateTime.utc(2026, 6, 20),
        today: near,
      );
      final pinned = ReminderProjector.pinToSeasonalSwap(
        projection: loose,
        swap: nextSeasonalSwap(countryCode: 'HR', today: near)!,
        today: near,
      );

      expect(pinned.state, ReminderState.due);
    });

    test('is upcoming while the date is still months out', () {
      final loose = projectSwap(
        lastSwap: DateTime.utc(2026, 6, 20),
        today: today,
      );
      final pinned = ReminderProjector.pinToSeasonalSwap(
        projection: loose,
        swap: nextSeasonalSwap(countryCode: 'HR', today: today)!,
        today: today,
      );

      expect(pinned.state, ReminderState.upcoming);
    });
  });
}
