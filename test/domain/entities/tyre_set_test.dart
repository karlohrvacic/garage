import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/tyre_set.dart';

TyreSet set({
  String id = 't1',
  String name = 'Winter — studded',
  TyreSeason season = TyreSeason.winter,
  bool fitted = true,
  DateTime? retiredAt,
  List<TyreReading> readings = const [],
}) {
  return TyreSet(
    id: id,
    vehicleId: 'v1',
    name: name,
    season: season,
    size: '205/55 R16',
    storageLocation: 'Cellar',
    fitted: fitted,
    fittedAt: DateTime.utc(2026, 11, 1),
    retiredAt: retiredAt,
    createdBy: 'u1',
    readings: readings,
  );
}

TyreReading reading({
  required DateTime date,
  double? frontLeft = 6.5,
  double? frontRight = 6.4,
  double? rearLeft = 7.0,
  double? rearRight = 7.1,
}) {
  return TyreReading(
    id: 'r-${date.millisecondsSinceEpoch}',
    date: date,
    odometerKm: 51000,
    frontLeftMm: frontLeft,
    frontRightMm: frontRight,
    rearLeftMm: rearLeft,
    rearRightMm: rearRight,
  );
}

void main() {
  group('a set', () {
    test('field-identical instances are equal', () {
      expect(set(), set());
      expect(set().hashCode, set().hashCode);
    });

    test('a differing name breaks equality', () {
      expect(set(name: 'Summer'), isNot(set()));
    });

    test('one that has been retired is no longer in use', () {
      expect(set().isRetired, isFalse);
      expect(set(retiredAt: DateTime.utc(2027, 3, 1)).isRetired, isTrue);
    });

    test('seasons map to the keys the table stores', () {
      expect(TyreSeason.summer.key, 'summer');
      expect(TyreSeason.winter.key, 'winter');
      expect(TyreSeason.allSeason.key, 'all_season');
      expect(TyreSeason.fromKey('winter'), TyreSeason.winter);
    });

    test('an unknown season reads as all-season rather than throwing', () {
      expect(TyreSeason.fromKey('monsoon'), TyreSeason.allSeason);
    });
  });

  group('tread', () {
    test('the shallowest corner is what decides the set', () {
      // Tyres are replaced as a set, and the law reads the worst corner.
      final reading = TyreReading(
        id: 'r1',
        date: DateTime.utc(2026, 5, 1),
        frontLeftMm: 6.5,
        frontRightMm: 3.2,
        rearLeftMm: 7,
        rearRightMm: 7.1,
      );

      expect(reading.shallowestMm, 3.2);
    });

    test('a reading of one corner still reports that corner', () {
      final reading = TyreReading(
        id: 'r1',
        date: DateTime.utc(2026, 5, 1),
        frontLeftMm: 4.5,
      );

      expect(reading.shallowestMm, 4.5);
    });

    test('a reading of nothing reports nothing', () {
      final reading = TyreReading(id: 'r1', date: DateTime.utc(2026, 5, 1));

      expect(reading.shallowestMm, isNull);
    });

    test('a set reports its latest reading', () {
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 3, 1), frontLeft: 7.5),
          reading(date: DateTime.utc(2026, 10, 1), frontLeft: 5.5),
        ],
      );

      expect(subject.latestReading?.date, DateTime.utc(2026, 10, 1));
      expect(subject.latestReading?.frontLeftMm, 5.5);
    });

    test('a set with no readings reports none', () {
      expect(set().latestReading, isNull);
    });

    test('a set at or below the legal minimum is flagged', () {
      // 1.6 mm is the EU minimum for summer tyres.
      final worn = set(
        readings: [reading(date: DateTime.utc(2026, 10, 1), frontRight: 1.5)],
      );
      final fine = set(
        readings: [reading(date: DateTime.utc(2026, 10, 1), frontRight: 3.0)],
      );

      expect(worn.isBelowLegalTread, isTrue);
      expect(fine.isBelowLegalTread, isFalse);
    });

    test('a set nobody has measured is not flagged as worn', () {
      expect(set().isBelowLegalTread, isFalse);
    });
  });
}
