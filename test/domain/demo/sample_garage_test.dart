import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/demo/sample_garage.dart';

final today = DateTime.utc(2026, 8, 16);

void main() {
  final sample = SampleGarage.build(today: today);

  group('sample data', () {
    // An empty app cannot show what it is for: every screen is an empty state,
    // and the economy chart, the projections and the running cost all need
    // history before they mean anything. This gives a new arrival something to
    // look at, and Settings' delete-all takes it away again.
    test('is one car, so the point is not lost in a fleet', () {
      expect(sample.vehicle.nickname, isNotEmpty);
    });

    test('has enough full tanks for an economy figure to exist', () {
      // Two full tanks is the minimum the algorithm can measure between.
      final fullTanks = sample.fuel.where((entry) => entry.fullTank).length;

      expect(fullTanks, greaterThan(2));
    });

    test('fill-ups run forwards in time and distance', () {
      for (var i = 1; i < sample.fuel.length; i++) {
        expect(
          sample.fuel[i].odometerKm,
          greaterThan(sample.fuel[i - 1].odometerKm),
        );
        expect(sample.fuel[i].date.isAfter(sample.fuel[i - 1].date), isTrue);
      }
    });

    test('ends in the present, not at some fixed date in the past', () {
      final newest = sample.fuel.last.date;

      expect(today.difference(newest).inDays, lessThan(40));
    });

    test(
      'includes servicing and running costs, so totals are not all fuel',
      () {
        expect(sample.services, isNotEmpty);
        expect(sample.costs, isNotEmpty);
      },
    );

    test('includes a reminder, so the planner has something to plan', () {
      expect(sample.rules, isNotEmpty);
    });

    test('starts the car before its history, or the history predates it', () {
      expect(
        sample.vehicle.baselineOdometerKm,
        lessThanOrEqualTo(sample.fuel.first.odometerKm),
      );
      expect(
        sample.vehicle.baselineDate.isAfter(sample.fuel.first.date),
        isFalse,
      );
    });

    test('is the same every time, so a demo is never surprising', () {
      final again = SampleGarage.build(today: today);

      expect(again.fuel.length, sample.fuel.length);
      expect(again.fuel.first.volumeL, sample.fuel.first.volumeL);
    });
  });
}
