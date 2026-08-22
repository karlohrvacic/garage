import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/costs/prorated_spend.dart';
import 'package:garage/domain/entities/cost_entry.dart';

CostEntry entry({
  required String category,
  required double amount,
  required DateTime date,
}) {
  return CostEntry(
    id: 'c1',
    vehicleId: 'v1',
    date: date,
    category: category,
    amount: amount,
    createdBy: 'u1',
  );
}

void main() {
  group('a cost for a moment, not a period', () {
    test('counts in full, wherever it falls in the window', () {
      final total = proratedSpend(
        [
          entry(
            category: CostCategories.parking,
            amount: 12,
            date: DateTime.utc(2026, 3, 1),
          ),
        ],
        since: DateTime.utc(2026, 1, 1),
        until: DateTime.utc(2026, 12, 31),
      );

      expect(total, 12);
    });

    test('a vignette is not prorated, even though it also has a period', () {
      final total = proratedSpend(
        [
          entry(
            category: CostCategories.vignette,
            amount: 15,
            date: DateTime.utc(2026, 6, 1),
          ),
        ],
        since: DateTime.utc(2026, 1, 1),
        until: DateTime.utc(2026, 6, 3),
      );

      expect(total, 15);
    });
  });

  group('a periodic cost, insurance or registration', () {
    test('entirely inside the window counts in full', () {
      final total = proratedSpend(
        [
          entry(
            category: CostCategories.insurance,
            amount: 600,
            date: DateTime.utc(2025, 1, 1),
          ),
        ],
        since: DateTime.utc(2024, 1, 1),
        until: DateTime.utc(2026, 1, 1),
      );

      expect(total, 600);
    });

    test('still mid-cycle contributes only the days consumed so far', () {
      // Paid on 1 Jan, covers a year: 1 Jan through 31 Jan inclusive is 31
      // of the 365 days consumed.
      final total = proratedSpend(
        [
          entry(
            category: CostCategories.insuranceComprehensive,
            amount: 365,
            date: DateTime.utc(2026, 1, 1),
          ),
        ],
        since: DateTime.utc(2020, 1, 1),
        until: DateTime.utc(2026, 1, 31),
      );

      expect(total, closeTo(31, 0.01));
    });

    test(
      'two consecutive premiums no longer double-count the year between them',
      () {
        // Ownership since 13 months ago. Two annual premiums: one that has
        // fully run its course, one just paid. Raw summing would report
        // ~2 years of premium for 13 months of ownership.
        final total = proratedSpend(
          [
            entry(
              category: CostCategories.insurance,
              amount: 600,
              date: DateTime.utc(2025, 6, 20),
            ),
            entry(
              category: CostCategories.insurance,
              amount: 600,
              date: DateTime.utc(2026, 6, 20),
            ),
          ],
          since: DateTime.utc(2025, 6, 20),
          until: DateTime.utc(2026, 7, 20),
        );

        // First premium fully consumed (600) plus 31 of 365 days of the
        // second (~51): nowhere near the raw 1200.
        expect(total, closeTo(651, 1));
        expect(total, lessThan(700));
      },
    );

    test('coverage bought before the window only counts what overlaps it', () {
      // Paid 2 months before the window starts, covers a year: 10 of 365
      // days of that year fall inside the window.
      final total = proratedSpend(
        [
          entry(
            category: CostCategories.registration,
            amount: 365,
            date: DateTime.utc(2025, 11, 1),
          ),
        ],
        since: DateTime.utc(2026, 1, 1),
        until: DateTime.utc(2026, 1, 10),
      );

      expect(total, closeTo(10, 0.01));
    });

    test(
      'coverage that ended before the window starts contributes nothing',
      () {
        final total = proratedSpend(
          [
            entry(
              category: CostCategories.insurance,
              amount: 600,
              date: DateTime.utc(2020, 1, 1),
            ),
          ],
          since: DateTime.utc(2026, 1, 1),
          until: DateTime.utc(2026, 6, 1),
        );

        expect(total, 0);
      },
    );
  });
}
