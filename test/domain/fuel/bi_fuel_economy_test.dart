import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/fuel_economy.dart';

FuelEntry fill(
  String id,
  int odometerKm,
  double volumeL, {
  bool fullTank = true,
  String? fuelTypeKey,
  int day = 1,
}) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: DateTime.utc(2026, 1, day),
    odometerKm: odometerKm,
    volumeL: volumeL,
    fullTank: fullTank,
    missedFill: false,
    fuelTypeKey: fuelTypeKey,
    createdBy: 'u1',
  );
}

void main() {
  group('a car running two fuels', () {
    // Petrol at 1000 and 1500; LPG at 1200 and 1700. Averaged together these
    // interleave into nonsense; kept apart, each chain measures its own fuel.
    final entries = [
      fill('p1', 1000, 40, fuelTypeKey: 'fuel_petrol', day: 1),
      fill('l1', 1200, 50, fuelTypeKey: 'fuel_lpg', day: 5),
      fill('p2', 1500, 25, fuelTypeKey: 'fuel_petrol', day: 9),
      fill('l2', 1700, 45, fuelTypeKey: 'fuel_lpg', day: 13),
    ];

    test('measures each fuel against its own chain of full tanks', () {
      final points = FuelEconomy.compute(entries);

      expect(points.map((p) => p.entryId), ['p2', 'l2']);
    });

    test('a span never counts the other fuel that went in between', () {
      final points = FuelEconomy.compute(entries);
      final petrol = points.firstWhere((p) => p.entryId == 'p2');

      // 25 litres of petrol over 500 km, not 75 litres of two fuels.
      expect(petrol.volumeL, 25);
      expect(petrol.distanceKm, 500);
      expect(petrol.litersPer100Km, 5);
    });

    test('each point says which fuel it is about', () {
      final points = FuelEconomy.compute(entries);

      expect(
        points.firstWhere((p) => p.entryId == 'p2').fuelTypeKey,
        'fuel_petrol',
      );
      expect(
        points.firstWhere((p) => p.entryId == 'l2').fuelTypeKey,
        'fuel_lpg',
      );
    });

    test('a partial fill only counts towards its own fuel', () {
      final points = FuelEconomy.compute([
        fill('p1', 1000, 40, fuelTypeKey: 'fuel_petrol'),
        fill('l1', 1100, 50, fuelTypeKey: 'fuel_lpg'),
        fill('p2', 1200, 10, fullTank: false, fuelTypeKey: 'fuel_petrol'),
        fill('p3', 1500, 20, fuelTypeKey: 'fuel_petrol'),
      ]);
      final petrol = points.firstWhere((p) => p.entryId == 'p3');

      expect(petrol.volumeL, 30);
    });
  });

  group('a car running one fuel', () {
    test('is unchanged when no entry names a fuel', () {
      // Every existing log is this: the column is new, so every row it did not
      // write is null, and null must keep meaning "the one fuel this car uses".
      final points = FuelEconomy.compute([
        fill('f1', 1000, 40),
        fill('f2', 1500, 25),
      ]);

      expect(points.single.volumeL, 25);
      expect(points.single.distanceKm, 500);
      expect(points.single.fuelTypeKey, isNull);
    });

    test(
      'an unnamed fill joins the chain of the fuel the car mainly takes',
      () {
        // A household that turns on the second tank part-way through has older
        // rows with no fuel on them. Told what the car mainly runs on, those
        // rows belong to that chain rather than to one of their own.
        final points = FuelEconomy.compute([
          fill('f1', 1000, 40),
          fill('f2', 1500, 25, fuelTypeKey: 'fuel_petrol'),
        ], primaryFuelKey: 'fuel_petrol');

        expect(points, hasLength(1));
        expect(points.single.distanceKm, 500);
        expect(points.single.fuelTypeKey, 'fuel_petrol');
      },
    );

    test(
      'unnamed fills stay one chain when nothing says what the car takes',
      () {
        final points = FuelEconomy.compute([
          fill('f1', 1000, 40),
          fill('f2', 1500, 25),
        ]);

        expect(points, hasLength(1));
      },
    );
  });
}
