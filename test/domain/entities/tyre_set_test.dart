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

    test('an axle with one tyre deeper than the other is the signal', () {
      // Front-to-rear difference is ordinary wear — a motorcycle's rear goes
      // first, and so does a front-wheel-drive car's front. Left against
      // right on the same axle is what points at alignment.
      final reading = TyreReading(
        id: 'r1',
        date: DateTime.utc(2026, 5, 1),
        frontLeftMm: 6.5,
        frontRightMm: 3.2,
        rearLeftMm: 7,
        rearRightMm: 7.1,
      );

      expect(reading.axleSpreadMm, closeTo(3.3, 0.001));
    });

    test('front and rear alone say nothing about an axle', () {
      // How a motorcycle's two tyres are stored.
      final reading = TyreReading(
        id: 'r1',
        date: DateTime.utc(2026, 5, 1),
        frontLeftMm: 6.5,
        rearLeftMm: 3.0,
      );

      expect(reading.axleSpreadMm, isNull);
    });

    test('the spread across the set is the difference between corners', () {
      // One corner 3 mm shallower than another is a suspension or alignment
      // problem, and the single worst figure never says so.
      final reading = TyreReading(
        id: 'r1',
        date: DateTime.utc(2026, 5, 1),
        frontLeftMm: 6.5,
        frontRightMm: 3.2,
        rearLeftMm: 7,
        rearRightMm: 7.1,
      );

      expect(reading.deepestMm, 7.1);
      expect(reading.spreadMm, closeTo(3.9, 0.001));
    });

    test('one corner measured has no spread to report', () {
      final reading = TyreReading(
        id: 'r1',
        date: DateTime.utc(2026, 5, 1),
        frontLeftMm: 4.5,
      );

      expect(reading.spreadMm, isNull);
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

    test('a motorcycle is held to 1.0 mm, not to a car\'s 1.6', () {
      // Croatian and EU law: 1.6 mm is the passenger-car figure. Printing it
      // on a bike sends a rider to buy tyres they do not need, and teaches a
      // number no inspection will agree with.
      expect(TyreSet.legalMinimumMmFor('motorcycle'), 1.0);
      expect(TyreSet.legalMinimumMmFor('car'), 1.6);
      expect(TyreSet.legalMinimumMmFor('van'), 1.6);

      final bikeWorn = set(
        readings: [reading(date: DateTime.utc(2026, 10, 1), frontRight: 1.5)],
      );

      expect(bikeWorn.isBelowLegal(1.0), isFalse);
      expect(bikeWorn.isBelowLegal(1.6), isTrue);
    });

    test(
      'a correction written later the same day wins, whatever the order',
      () {
        // The rows come back from an embedded select in no promised order, so
        // list position is not evidence of anything.
        final subject = set(
          readings: [
            TyreReading(
              id: 'later',
              date: DateTime.utc(2026, 10, 1),
              recordedAt: DateTime.utc(2026, 10, 1, 14, 30),
              frontRightMm: 2,
            ),
            TyreReading(
              id: 'earlier',
              date: DateTime.utc(2026, 10, 1),
              recordedAt: DateTime.utc(2026, 10, 1, 14, 5),
              frontRightMm: 4,
            ),
          ],
        );

        expect(subject.latestReading?.id, 'later');
      },
    );

    test('the newest reading wins, and a second one taken today counts', () {
      // Dates are date-only and the sheet stamps today, so two readings on
      // one day tie. The card showed the first one for ever, which is how a
      // corrected measurement disappeared.
      final subject = set(
        readings: [
          reading(date: DateTime.utc(2026, 10, 1), frontRight: 4),
          reading(date: DateTime.utc(2026, 10, 1), frontRight: 2),
        ],
      );

      expect(subject.latestReading?.frontRightMm, 2);
    });
  });

  group('four tyres, four DOT codes', () {
    TyreSet withCorners(Map<TyreCorner, DateTime> made, {DateTime? setWide}) {
      return TyreSet(
        id: 't1',
        vehicleId: 'v1',
        name: 'Winter',
        season: TyreSeason.winter,
        fitted: true,
        createdBy: 'u1',
        manufacturedOn: setWide,
        manufacturedByCorner: made,
      );
    }

    test('the set is judged by its oldest tyre', () {
      // Replacing one tyre does not make the other three younger, and the age
      // warning exists for the one that is past it.
      final set = withCorners({
        TyreCorner.frontLeft: DateTime.utc(2019, 5, 6),
        TyreCorner.frontRight: DateTime.utc(2019, 5, 6),
        TyreCorner.rearLeft: DateTime.utc(2023, 9, 4),
        TyreCorner.rearRight: DateTime.utc(2023, 9, 4),
      });

      expect(set.oldestManufactured, DateTime.utc(2019, 5, 6));
    });

    test(
      'a set recorded before corners existed falls back to its own date',
      () {
        final set = withCorners(const {}, setWide: DateTime.utc(2020, 3, 2));

        expect(set.oldestManufactured, DateTime.utc(2020, 3, 2));
      },
    );

    test('and a set nobody has read has no date at all', () {
      expect(withCorners(const {}).oldestManufactured, isNull);
    });

    test('a corner nobody read is absent rather than guessed', () {
      final set = withCorners({TyreCorner.frontLeft: DateTime.utc(2022, 1, 3)});

      expect(set.manufacturedByCorner[TyreCorner.rearRight], isNull);
      expect(set.oldestManufactured, DateTime.utc(2022, 1, 3));
    });

    test('codes that agree do not count as varying', () {
      final same = withCorners({
        for (final corner in TyreCorner.values)
          corner: DateTime.utc(2022, 1, 3),
      });

      expect(same.manufacturedVaries, isFalse);
    });

    test('and codes that disagree do', () {
      final mixed = withCorners({
        TyreCorner.frontLeft: DateTime.utc(2019, 5, 6),
        TyreCorner.rearLeft: DateTime.utc(2023, 9, 4),
      });

      expect(mixed.manufacturedVaries, isTrue);
    });

    test('two sets with the same corners in another order are equal', () {
      final a = withCorners({
        TyreCorner.frontLeft: DateTime.utc(2022, 1, 3),
        TyreCorner.rearLeft: DateTime.utc(2023, 1, 2),
      });
      final b = withCorners({
        TyreCorner.rearLeft: DateTime.utc(2023, 1, 2),
        TyreCorner.frontLeft: DateTime.utc(2022, 1, 3),
      });

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('and one differing corner makes them different', () {
      final a = withCorners({TyreCorner.frontLeft: DateTime.utc(2022, 1, 3)});
      final b = withCorners({TyreCorner.frontLeft: DateTime.utc(2023, 1, 2)});

      expect(a, isNot(b));
    });
  });
}
