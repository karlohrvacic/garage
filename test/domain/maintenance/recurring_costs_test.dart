import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/maintenance/recurring_costs.dart';

void main() {
  group('costs that come round again', () {
    test('registration is due again a year later', () {
      final next = RecurringCosts.nextDue(
        category: CostCategories.registration,
        paidOn: DateTime.utc(2026, 3, 14),
      );

      expect(next?.serviceTypeKey, 'service_registration');
      expect(next?.dueDate, DateTime.utc(2027, 3, 14));
    });

    test('insurance is due again a year later', () {
      final next = RecurringCosts.nextDue(
        category: CostCategories.insurance,
        paidOn: DateTime.utc(2026, 3, 14),
      );

      expect(next?.serviceTypeKey, 'service_insurance');
      expect(next?.dueDate, DateTime.utc(2027, 3, 14));
    });

    test('a one-off expense does not come round again', () {
      for (final category in [
        CostCategories.parking,
        CostCategories.wash,
        CostCategories.fine,
        CostCategories.equipment,
        CostCategories.other,
        CostCategories.toll,
      ]) {
        expect(
          RecurringCosts.nextDue(
            category: category,
            paidOn: DateTime.utc(2026, 3, 14),
          ),
          isNull,
          reason: category,
        );
      }
    });

    test('a leap day rolls to the 28th rather than into March', () {
      final next = RecurringCosts.nextDue(
        category: CostCategories.insurance,
        paidOn: DateTime.utc(2028, 2, 29),
      );

      expect(next?.dueDate, DateTime.utc(2029, 2, 28));
    });

    test('the due date keeps the domain UTC flag', () {
      final next = RecurringCosts.nextDue(
        category: CostCategories.registration,
        paidOn: DateTime(2026, 3, 14),
      );

      expect(next!.dueDate.isUtc, isTrue);
      expect(next.dueDate, DateTime.utc(2027, 3, 14));
    });

    test('an unknown category is treated as one-off, not guessed at', () {
      expect(
        RecurringCosts.nextDue(
          category: 'something_new',
          paidOn: DateTime.utc(2026, 3, 14),
        ),
        isNull,
      );
    });
  });
}
