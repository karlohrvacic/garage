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
}
