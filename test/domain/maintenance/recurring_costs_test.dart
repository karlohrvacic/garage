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

    // Comprehensive cover is bought yearly like the mandatory policy, usually
    // from a different insurer on a different date. It had its own category
    // but no renewal, so the one people actually forget was the one the app
    // said nothing about.
    test('comprehensive cover is due again a year later too', () {
      final next = RecurringCosts.nextDue(
        category: CostCategories.insuranceComprehensive,
        paidOn: DateTime.utc(2026, 3, 14),
      );

      expect(next?.serviceTypeKey, 'service_insurance_comprehensive');
      expect(next?.dueDate, DateTime.utc(2027, 3, 14));
    });

    // A vignette is bought for a period, not for a year: Slovenia sells seven
    // days, a month and a year, and what matters is the day it stops being
    // valid. A Croatian motorway toll is paid per journey and expires with the
    // journey, which is why it is not one of these.
    group('a vignette', () {
      test('is valid through the last day of the period bought', () {
        final next = RecurringCosts.nextDue(
          category: CostCategories.vignette,
          paidOn: DateTime.utc(2026, 3, 14),
          validity: VignetteValidity.days7,
        );

        expect(next?.serviceTypeKey, 'service_vignette');
        // 14th through 20th is seven days including the first.
        expect(next?.dueDate, DateTime.utc(2026, 3, 20));
      });

      // Slovenia and Hungary sell a *thirty-day* vignette, not a calendar
      // month, so this is thirty days from the day it started.
      test('a thirty-day one runs thirty days from the day it started', () {
        final next = RecurringCosts.nextDue(
          category: CostCategories.vignette,
          paidOn: DateTime.utc(2026, 1, 31),
          validity: VignetteValidity.days30,
        );

        expect(next?.dueDate, DateTime.utc(2026, 3, 1));
      });

      // Austria's two-month vignette is the one sold by the month, and a month
      // from 31 December is 28 February, not 3 March.
      test('a two-month one clamps to the end of a shorter month', () {
        final next = RecurringCosts.nextDue(
          category: CostCategories.vignette,
          paidOn: DateTime.utc(2025, 12, 31),
          validity: VignetteValidity.months2,
        );

        // Two months on from 31 December clamps to 28 February; the last valid
        // day is the one before that.
        expect(next?.dueDate, DateTime.utc(2026, 2, 27));
      });

      test('bought for a year, runs to the day before the anniversary', () {
        final next = RecurringCosts.nextDue(
          category: CostCategories.vignette,
          paidOn: DateTime.utc(2026, 3, 14),
          validity: VignetteValidity.year,
        );

        expect(next?.dueDate, DateTime.utc(2027, 3, 13));
      });

      test('with no period chosen there is no expiry to warn about', () {
        expect(
          RecurringCosts.nextDue(
            category: CostCategories.vignette,
            paidOn: DateTime.utc(2026, 3, 14),
          ),
          isNull,
        );
      });
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
