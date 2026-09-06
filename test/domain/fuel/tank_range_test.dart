import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/fuel/tank_range.dart';

FuelEntry fill({
  required int odometerKm,
  required double volumeL,
  bool fullTank = true,
  bool missedFill = false,
  DateTime? date,
}) {
  return FuelEntry(
    id: 'f$odometerKm',
    vehicleId: 'v1',
    date: date ?? DateTime.utc(2026, 8, 1),
    odometerKm: odometerKm,
    volumeL: volumeL,
    fullTank: fullTank,
    missedFill: missedFill,
    createdBy: 'u1',
  );
}

final today = DateTime.utc(2026, 8, 31);

TankRange estimate({
  double? tankCapacityL = 50,
  double? litersPer100Km = 5,
  double? kmPerDay = 40,
  int currentOdometerKm = 50100,
  List<FuelEntry> entries = const [],
}) {
  return estimateTankRange(
    tankCapacityL: tankCapacityL,
    litersPer100Km: litersPer100Km,
    kmPerDay: kmPerDay,
    currentOdometerKm: currentOdometerKm,
    entries: entries,
    today: today,
  );
}

void main() {
  group('what is left in the tank', () {
    test('a full tank driven 100 km at 5 l/100km has 45 litres left', () {
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 50100,
      );

      expect(range.isKnown, isTrue);
      expect(range.litersLeft, closeTo(45, 1e-9));
      expect(range.kmLeft, closeTo(900, 1e-9));
    });

    test('the tank is full the moment it is filled', () {
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 50000,
      );

      expect(range.litersLeft, 50);
    });

    test('it does not go below empty, however far the car was driven', () {
      // The clamp itself. Driven *well* past empty the estimate stops being
      // an estimate at all — see "driven further than a tankful" below — so
      // this is the last reading that is still one.
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 51010,
      );

      expect(range.litersLeft, 0);
      expect(range.kmLeft, 0);
    });

    test(
      'an odometer that went backwards burns nothing rather than filling',
      () {
        final range = estimate(
          entries: [fill(odometerKm: 50000, volumeL: 40)],
          currentOdometerKm: 49900,
        );

        expect(range.litersLeft, 50);
      },
    );
  });

  group('a partial fill in between', () {
    test('puts its litres back in', () {
      // Full at 50000, 200 km later (10 l burned) a 5 l splash, then 100 km
      // more (5 l burned): 50 − 10 + 5 − 5 = 40.
      final range = estimate(
        entries: [
          fill(odometerKm: 50000, volumeL: 40),
          fill(odometerKm: 50200, volumeL: 5, fullTank: false),
        ],
        currentOdometerKm: 50300,
      );

      expect(range.litersLeft, closeTo(40, 1e-9));
    });

    test('cannot overfill the tank it went into', () {
      final range = estimate(
        entries: [
          fill(odometerKm: 50000, volumeL: 40),
          fill(odometerKm: 50020, volumeL: 30, fullTank: false),
        ],
        currentOdometerKm: 50020,
      );

      expect(
        range.litersLeft,
        50,
        reason: 'a 30 litre splash into a nearly full 50 litre tank is not 79',
      );
    });

    test('a later full tank is what counts, not the earlier one', () {
      final range = estimate(
        entries: [
          fill(odometerKm: 50000, volumeL: 40),
          fill(odometerKm: 50400, volumeL: 20),
        ],
        currentOdometerKm: 50500,
      );

      expect(range.litersLeft, closeTo(45, 1e-9));
    });
  });

  group('when it refuses to answer', () {
    test('no tank capacity, which most cars in the app do not have', () {
      final range = estimate(
        tankCapacityL: null,
        entries: [fill(odometerKm: 50000, volumeL: 40)],
      );

      expect(range.isKnown, isFalse);
      expect(range.reason, TankRangeUnknown.noTankCapacity);
    });

    test('a tank capacity of zero is not a tank', () {
      final range = estimate(
        tankCapacityL: 0,
        entries: [fill(odometerKm: 50000, volumeL: 40)],
      );

      expect(range.reason, TankRangeUnknown.noTankCapacity);
    });

    test('no measured economy yet', () {
      final range = estimate(
        litersPer100Km: null,
        entries: [fill(odometerKm: 50000, volumeL: 40)],
      );

      expect(range.reason, TankRangeUnknown.noEconomy);
    });

    test('no full tank ever recorded, so there is no starting point', () {
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 20, fullTank: false)],
      );

      expect(range.reason, TankRangeUnknown.noFullTank);
    });

    test('no fill-ups at all', () {
      final range = estimate(entries: const []);

      expect(range.reason, TankRangeUnknown.noFullTank);
    });

    // The one that matters: an unlogged fill means the arithmetic is wrong,
    // and a confident wrong number is worse than a blank.
    test('a fill-up known to be missing since the last full tank', () {
      final range = estimate(
        entries: [
          fill(odometerKm: 50000, volumeL: 40),
          fill(
            odometerKm: 50200,
            volumeL: 20,
            fullTank: false,
            missedFill: true,
          ),
        ],
        currentOdometerKm: 50300,
      );

      expect(range.reason, TankRangeUnknown.missedFill);
    });

    test('a missed fill before the last full tank does not matter', () {
      final range = estimate(
        entries: [
          fill(odometerKm: 49000, volumeL: 30, missedFill: true),
          fill(odometerKm: 50000, volumeL: 40),
        ],
        currentOdometerKm: 50100,
      );

      expect(range.isKnown, isTrue);
      expect(range.litersLeft, closeTo(45, 1e-9));
    });
  });

  group('when the tank runs dry', () {
    test('is projected from how far the car is actually driven', () {
      // 45 litres at 5 l/100km is 900 km; at 40 km a day that is 22.5 days.
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 50100,
        kmPerDay: 40,
      );

      expect(range.emptyOn, DateTime.utc(2026, 9, 23));
    });

    test('is not guessed when the driving rate is unknown', () {
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        kmPerDay: null,
      );

      expect(range.isKnown, isTrue);
      expect(range.kmLeft, closeTo(900, 1e-9));
      expect(
        range.emptyOn,
        isNull,
        reason: 'a date is a promise; km left is only arithmetic',
      );
    });

    test('a car that is not driven at all gets no date either', () {
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        kmPerDay: 0,
      );

      expect(range.emptyOn, isNull);
    });

    test('an empty tank is empty today, not in the past', () {
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 51000,
      );

      expect(range.emptyOn, today);
    });
  });

  group('driven further than a tankful since the last full one', () {
    test('says it cannot tell, rather than that the tank is empty', () {
      // Seen on a device: "142,322 km · ≈0 km left" on a car whose last full
      // tank was 92,000 km ago. The arithmetic is right and the claim is
      // wrong — fuel plainly went in that nobody logged, and a confident "0"
      // reads as an empty tank rather than as a gap in the records.
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 51500,
      );

      expect(range.isKnown, isFalse);
      expect(range.reason, TankRangeUnknown.unrecordedFill);
    });

    test('a tank run genuinely low is still a number', () {
      // 50 litres at 5 l/100km is 1,000 km. At 990 there are 10 km left and
      // that is worth saying.
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 50990,
      );

      expect(range.isKnown, isTrue);
      expect(range.kmLeft, closeTo(10, 0.001));
    });

    test('reaching exactly empty is not treated as a gap', () {
      // The boundary itself: a litre of tolerance, so rounding at the bottom
      // of the tank does not flip a real reading into a shrug.
      final range = estimate(
        entries: [fill(odometerKm: 50000, volumeL: 40)],
        currentOdometerKm: 51000,
      );

      expect(range.isKnown, isTrue);
      expect(range.kmLeft, closeTo(0, 0.001));
    });
  });
}
