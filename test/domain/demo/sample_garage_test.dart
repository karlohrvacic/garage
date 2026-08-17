import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/domain/demo/sample_garage.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';

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

    // Every litre figure was its distance times 0.06, so all twelve spans came
    // out at exactly 6.0 l/100km. The economy chart was a flat line, the ring
    // had a degenerate scale, and the car's own summary read "Best 6.0 ·
    // Worst 6.0" on the first screen a new arrival sees.
    test('economy varies between fill-ups, as a real car does', () {
      final figures = FuelEconomy.compute(
        sample.fuel,
      ).map((point) => point.litersPer100Km).toList();

      expect(figures.length, greaterThan(3));
      expect(
        figures.reduce(math.max) - figures.reduce(math.min),
        greaterThan(0.5),
        reason:
            'a flat series makes the ring, the chart and best/worst '
            'all meaningless',
      );
    });

    test('stays plausible for a small diesel while it varies', () {
      for (final point in FuelEconomy.compute(sample.fuel)) {
        expect(point.litersPer100Km, inInclusiveRange(4, 9));
      }
    });

    // "Petrol" is a real fuel brand, but on the Add fill-up form it landed in
    // the field labelled Station, directly under one labelled Price per unit,
    // where it reads as a fuel type entered in the wrong box.
    test('names stations so they cannot be read as a fuel type', () {
      const fuelWords = ['petrol', 'diesel', 'lpg', 'gas'];
      for (final entry in sample.fuel) {
        expect(fuelWords, isNot(contains(entry.station?.toLowerCase())));
      }
    });

    test('is the same every time, so a demo is never surprising', () {
      final again = SampleGarage.build(today: today);

      expect(again.fuel.length, sample.fuel.length);
      expect(again.fuel.first.volumeL, sample.fuel.first.volumeL);
    });
  });

  group('the kinds added in August', () {
    test('includes trips, so the trip log is not an empty state', () {
      expect(sample.trips, isNotEmpty);
    });

    test('splits the trips business and private, which is their point', () {
      expect(sample.trips.map((t) => t.purpose).toSet(), {
        TripPurpose.business,
        TripPurpose.private,
      });
    });

    test('includes income, so the balance figure is not just cost negated', () {
      expect(sample.income, isNotEmpty);
    });

    test('includes a standalone reading, so its row on the chart appears', () {
      expect(sample.readings, isNotEmpty);
    });

    test('keeps every reading inside the year the car has history for', () {
      // A reading dated outside the log would put a lone point at one end of
      // the odometer chart and make the rest of it flat.
      final first = sample.fuel.first.date;
      final last = sample.fuel.last.date;
      for (final reading in sample.readings) {
        expect(reading.date.isBefore(first), isFalse);
        expect(reading.date.isAfter(last), isFalse);
      }
    });

    test('never reads the odometer backwards against the fill-ups', () {
      // The merged series drops a reading that goes backwards, so a badly
      // placed sample reading would silently vanish from the demo.
      for (final reading in sample.readings) {
        final before = sample.fuel
            .where((f) => !f.date.isAfter(reading.date))
            .map((f) => f.odometerKm);
        final after = sample.fuel
            .where((f) => !f.date.isBefore(reading.date))
            .map((f) => f.odometerKm);
        if (before.isNotEmpty) {
          expect(
            reading.odometerKm,
            greaterThanOrEqualTo(before.reduce(math.max)),
          );
        }
        if (after.isNotEmpty) {
          expect(reading.odometerKm, lessThanOrEqualTo(after.reduce(math.min)));
        }
      }
    });
  });
}
