import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/tyre_age.dart';

final today = DateTime.utc(2026, 6, 1);

void main() {
  group('reading a DOT code', () {
    test('gives the Monday of that week', () {
      // Week 34 of 2019 began on Monday 19 August.
      expect(TyreDotCode.parse('3419'), DateTime.utc(2019, 8, 19));
    });

    test('accepts week one and week fifty-three', () {
      expect(TyreDotCode.parse('0120'), isNotNull);
      expect(TyreDotCode.parse('5320'), isNotNull);
    });

    test('refuses a week that does not exist', () {
      expect(TyreDotCode.parse('0019'), isNull);
      expect(TyreDotCode.parse('5419'), isNull);
    });

    test('refuses anything that is not four digits', () {
      for (final bad in ['', '341', '34199', 'ab19', '34/19']) {
        expect(TyreDotCode.parse(bad), isNull, reason: bad);
      }
    });

    // A tyre is dated by a two-digit year, so the century has to be inferred.
    // The most recent past year is the only sane reading: 2099 has not
    // happened, and a tyre from 1999 is a museum piece but a real answer.
    test('reads the two-digit year as the most recent past one', () {
      // Mid-year weeks, so the Monday lands in the year the digits name and
      // the assertion is about the century rather than the ISO boundary below.
      expect(TyreDotCode.parse('2626', today: today)!.year, 2026);
      expect(TyreDotCode.parse('2699', today: today)!.year, 1999);
      expect(TyreDotCode.parse('2627', today: today)!.year, 1927);
    });

    // ISO week 1 is the week containing 4 January, so its Monday can fall in
    // the previous December. That is correct and worth pinning, because it
    // looks like an off-by-one every time somebody reads it.
    test('week one can begin in the previous year', () {
      expect(
        TyreDotCode.parse('0126', today: today),
        DateTime.utc(2025, 12, 29),
      );
    });

    test('tolerates surrounding whitespace', () {
      expect(TyreDotCode.parse('  3419  '), DateTime.utc(2019, 8, 19));
    });
  });

  // Shown back as the code on the sidewall rather than the date it parsed to,
  // so somebody can check it against the tyre.
  group('writing a DOT code back out', () {
    test('round-trips every week of a year', () {
      for (var week = 1; week <= 52; week++) {
        final code = '${week.toString().padLeft(2, '0')}19';
        expect(
          TyreDotCode.format(TyreDotCode.parse(code, today: today)),
          code,
          reason: 'week $week',
        );
      }
    });

    test('and the week-one boundary that begins in December', () {
      expect(TyreDotCode.format(DateTime.utc(2025, 12, 29)), '0126');
    });

    test('is empty for a set nobody has read', () {
      expect(TyreDotCode.format(null), '');
    });
  });

  group('how old a set is', () {
    test('is unknown when nothing dates it', () {
      expect(TyreAge.assess(today: today), isNull);
    });

    test('is measured from the manufacture date when there is one', () {
      final age = TyreAge.assess(
        manufacturedOn: DateTime.utc(2019, 8, 19),
        today: today,
      )!;

      expect(age.years, 6);
      expect(age.estimated, isFalse);
    });

    // The fallback errs low — a set fitted in 2020 may have been made in 2016 —
    // so it is marked, the same way an assumed driving rate is.
    test('falls back to the fitted date, and says it is an estimate', () {
      final age = TyreAge.assess(
        fittedAt: DateTime.utc(2019, 8, 19),
        today: today,
      )!;

      expect(age.years, 6);
      expect(age.estimated, isTrue);
    });

    test('prefers the manufacture date when both are known', () {
      final age = TyreAge.assess(
        manufacturedOn: DateTime.utc(2014, 1, 1),
        fittedAt: DateTime.utc(2022, 1, 1),
        today: today,
      )!;

      expect(age.years, 12);
      expect(age.estimated, isFalse);
    });
  });

  group('what an age means', () {
    TyreAge at(int year) =>
        TyreAge.assess(manufacturedOn: DateTime.utc(year, 6, 1), today: today)!;

    test('under six years is nothing to say', () {
      expect(at(2021).standing, TyreAgeStanding.fresh);
    });

    // Both boundaries pinned: an off-by-one here is a warning that arrives a
    // year late, which is the direction that matters.
    test('six years is worth a look', () {
      expect(at(2020).standing, TyreAgeStanding.ageing);
      expect(at(2021).standing, TyreAgeStanding.fresh);
    });

    test('ten years is past it whatever the tread says', () {
      expect(at(2016).standing, TyreAgeStanding.expired);
      expect(at(2017).standing, TyreAgeStanding.ageing);
    });
  });
}
