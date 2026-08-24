import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/tyre_set.dart';
import 'package:garage/domain/maintenance/tyre_wear_projection.dart';

final today = DateTime.utc(2026, 7, 20);

TyreReading reading({required DateTime date, int? odometerKm, double? mm}) {
  return TyreReading(
    id: 'r-${date.toIso8601String()}',
    date: date,
    odometerKm: odometerKm,
    frontLeftMm: mm,
    frontRightMm: mm,
    rearLeftMm: mm,
    rearRightMm: mm,
  );
}

TyreSet set({List<TyreReading> readings = const []}) {
  return TyreSet(
    id: 't1',
    vehicleId: 'v1',
    name: 'Winter set',
    season: TyreSeason.winter,
    fitted: true,
    createdBy: 'u1',
    readings: readings,
  );
}

void main() {
  group('a set with fewer than two measured readings', () {
    test('has no wear rate to project from', () {
      expect(
        TyreWearProjector.project(set: set(), today: today, kmPerDay: 40),
        isNull,
      );
    });

    test('one reading alone is not enough', () {
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 6),
        ],
      );

      expect(
        TyreWearProjector.project(set: subject, today: today, kmPerDay: 40),
        isNull,
      );
    });
  });

  group('a set measured twice', () {
    test('projects remaining life from the measured wear rate', () {
      // 6.0mm at 40,000km, 5.0mm at 50,000km: 1mm per 10,000km. Legal floor
      // is 1.6mm, so 3.4mm remain: 34,000km to go.
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 6.0),
          reading(date: DateTime.utc(2026, 6, 1), odometerKm: 50000, mm: 5.0),
        ],
      );

      final projection = TyreWearProjector.project(
        set: subject,
        today: today,
        kmPerDay: 100,
      )!;

      expect(projection.wearRatePerKm, closeTo(0.0001, 0.00001));
      expect(projection.remainingKm, 34000);
      // 34,000km at 100km/day == 340 days out.
      expect(projection.projectedReplacementDate, DateTime(2027, 6, 25));
    });

    test('reads readings out of date order correctly', () {
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 6, 1), odometerKm: 50000, mm: 5.0),
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 6.0),
        ],
      );

      final projection = TyreWearProjector.project(
        set: subject,
        today: today,
        kmPerDay: 100,
      )!;

      expect(projection.remainingKm, 34000);
    });

    test('a set already at or under the legal floor has nothing left', () {
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 3.0),
          reading(date: DateTime.utc(2026, 6, 1), odometerKm: 50000, mm: 1.5),
        ],
      );

      final projection = TyreWearProjector.project(
        set: subject,
        today: today,
        kmPerDay: 100,
      )!;

      expect(projection.remainingKm, 0);
    });

    test('readings with no measurable wear project nothing', () {
      // Identical tread twice — no wear rate to divide by.
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 6.0),
          reading(date: DateTime.utc(2026, 6, 1), odometerKm: 50000, mm: 6.0),
        ],
      );

      expect(
        TyreWearProjector.project(set: subject, today: today, kmPerDay: 100),
        isNull,
      );
    });

    test('a reading missing an odometer is not counted as measured', () {
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 6.0),
          reading(date: DateTime.utc(2026, 6, 1), mm: 5.0),
        ],
      );

      expect(
        TyreWearProjector.project(set: subject, today: today, kmPerDay: 100),
        isNull,
      );
    });

    // This used to substitute the assumed 30 km/day and hand back a date.
    // The distance is a measurement and the date would not have been one, and
    // the sentence they were rendered into could not tell them apart.
    test('keeps the measured distance and names no date', () {
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 6.0),
          reading(date: DateTime.utc(2026, 6, 1), odometerKm: 50000, mm: 5.0),
        ],
      );

      final projection = TyreWearProjector.project(
        set: subject,
        today: today,
        kmPerDay: 0,
      )!;

      expect(projection.remainingKm, 34000);
      expect(projection.projectedReplacementDate, isNull);
    });
  });

  // The distance left is measured — tread lost over kilometres actually
  // driven. The *date* is that distance divided by a driving rate, and when
  // the vehicle has none to measure the projector was quietly substituting
  // the assumed 30 km/day, so a guess and a measurement were rendered as one
  // sentence with nothing to tell them apart.
  group('a vehicle with no measurable driving rate', () {
    TyreSet worn() => set(
      readings: [
        reading(date: DateTime.utc(2026, 1, 1), odometerKm: 40000, mm: 8),
        reading(date: DateTime.utc(2026, 6, 1), odometerKm: 50000, mm: 6),
      ],
    );

    test('still measures the distance left', () {
      final projection = TyreWearProjector.project(
        set: worn(),
        today: today,
        kmPerDay: 0,
      );

      // 2mm lost over 10000 km, and 4.4mm left above the 1.6mm minimum.
      expect(projection, isNotNull);
      expect(projection!.remainingKm, 22000);
    });

    test('but names no date for it', () {
      final projection = TyreWearProjector.project(
        set: worn(),
        today: today,
        kmPerDay: 0,
      );

      expect(
        projection!.projectedReplacementDate,
        isNull,
        reason: 'a date from an assumed rate reads exactly like a measured one',
      );
    });

    test('and does name one once there is a rate', () {
      final projection = TyreWearProjector.project(
        set: worn(),
        today: today,
        kmPerDay: 50,
      );

      // 22000 km at 50 a day is 440 days out.
      expect(projection!.projectedReplacementDate, DateTime(2026, 7, 20 + 440));
    });
  });
}
