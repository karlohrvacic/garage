import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/costs/running_cost.dart';

final owned = DateTime.utc(2025, 8, 16);
final today = DateTime.utc(2026, 8, 16);

RunningCost cost({
  double fuel = 0,
  double service = 0,
  double other = 0,
  int distanceKm = 0,
  DateTime? since,
}) {
  return RunningCost.of(
    fuel: fuel,
    service: service,
    other: other,
    distanceKm: distanceKm,
    since: since ?? owned,
    until: today,
  );
}

void main() {
  test('what was paid is separate from what was spread', () {
    // A €600 premium is €600 out of the account whatever the year ahead
    // holds; shown as €1.64 it read as a bug, not as amortisation.
    final cost = RunningCost.of(
      fuel: 100,
      service: 50,
      other: 1.64,
      otherPaid: 600,
      distanceKm: 1000,
      since: DateTime.utc(2026, 9, 1),
      until: DateTime.utc(2026, 9, 30),
    );

    expect(cost.paid, 750);
    expect(cost.total, closeTo(151.64, 0.001));
    expect(cost.spreads, isTrue);
  });

  test('and says nothing about spreading when nothing was spread', () {
    final cost = RunningCost.of(
      fuel: 100,
      service: 50,
      other: 20,
      otherPaid: 20,
      distanceKm: 1000,
      since: DateTime.utc(2026, 9, 1),
      until: DateTime.utc(2026, 9, 30),
    );

    expect(cost.spreads, isFalse);
  });

  group('what a car costs to run', () {
    // The three kinds of spending live in three tables because they answer
    // different questions, so "what does this car cost me" has never had a
    // single figure. This is that figure.
    test('is everything spent on it, whichever table it sits in', () {
      final subject = cost(fuel: 1200, service: 450, other: 430);

      expect(subject.total, 2080);
    });

    test('per kilometre is the whole spend over the distance covered', () {
      final subject = cost(
        fuel: 1200,
        service: 450,
        other: 430,
        distanceKm: 20000,
      );

      expect(subject.perKm, closeTo(0.104, 0.0005));
    });

    test('per month spreads it over how long the car has been owned', () {
      final subject = cost(fuel: 1200, service: 450, other: 430);

      // Twelve months of ownership.
      expect(subject.perMonth, closeTo(2080 / 12, 0.01));
    });

    test('per year follows from the same span', () {
      final subject = cost(fuel: 1200, service: 450, other: 430);

      expect(subject.perYear, closeTo(2080, 0.01));
    });

    test('a car that has not moved has no cost per kilometre', () {
      expect(cost(fuel: 100).perKm, isNull);
    });

    test('a car bought today has no monthly figure yet', () {
      final subject = cost(fuel: 100, since: today);

      expect(
        subject.perMonth,
        isNull,
        reason: 'dividing a day of ownership into a month invents a number',
      );
    });

    test('an empty history costs nothing rather than crashing', () {
      final subject = cost();

      expect(subject.total, 0);
      expect(subject.perKm, isNull);
    });

    test(
      'fuel and upkeep are kept apart, since they are asked about apart',
      () {
        final subject = cost(
          fuel: 1200,
          service: 450,
          other: 430,
          distanceKm: 20000,
        );

        expect(subject.fuelPerKm, closeTo(0.06, 0.0005));
        expect(subject.upkeepPerKm, closeTo(0.044, 0.0005));
      },
    );
  });

  group('a car nobody has spent anything on', () {
    test('has nothing to report, rather than a cost of zero', () {
      final subject = cost(distanceKm: 20000);

      expect(subject.hasSpending, isFalse);
    });

    test('reports as soon as anything is logged', () {
      expect(cost(fuel: 60, distanceKm: 500).hasSpending, isTrue);
    });
  });

  group('cost of ownership', () {
    test('is the purchase price plus everything spent running it since', () {
      final subject = cost(fuel: 1200, service: 450, other: 430);

      expect(subject.costOfOwnership(15000), 17080);
    });

    test('is null when no purchase price is known, not the running total', () {
      final subject = cost(fuel: 1200, service: 450, other: 430);

      expect(subject.costOfOwnership(null), isNull);
    });

    test('does not change perKm — a capital cost is not a running one', () {
      final subject = cost(fuel: 1200, distanceKm: 20000);

      final perKmBefore = subject.perKm;
      subject.costOfOwnership(15000);

      expect(subject.perKm, perKmBefore);
    });
  });

  group('what the figures agree on', () {
    const cost = RunningCost(
      fuel: 100,
      service: 50,
      other: 1.64,
      otherPaid: 600,
      distanceKm: 500,
      months: 6,
    );

    test(
      'ownership adds the price to what was paid, not to what was spread',
      () {
        // The screen prints "since you added it" as paid and the ownership line
        // directly under it; built on the spread figure, the second was smaller
        // than the price plus the first.
        expect(cost.costOfOwnership(5000), 5750);
      },
    );

    test('spending that prorates to nothing is not enough to report', () {
      // A policy whose cover falls entirely before the car was added: the
      // rates would all be zero, and zero rates printed above a €600 total
      // read as a broken card rather than as amortisation.
      const spreadOnly = RunningCost(
        fuel: 0,
        service: 0,
        other: 0,
        otherPaid: 600,
        distanceKm: 500,
        months: 6,
      );

      expect(spreadOnly.hasSpending, isFalse);
    });
  });
}
