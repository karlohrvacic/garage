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

    test('falls back to the assumed rate when none is measured', () {
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

      // 34,000km at the 30km/day fallback == 1133 days out.
      expect(projection.remainingKm, 34000);
      expect(projection.projectedReplacementDate.isAfter(today), isTrue);
    });
  });
}
