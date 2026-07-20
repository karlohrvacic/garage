import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // formatDate and formatShortDate need intl's date symbol data. The app gets
  // it from main(); tests must ask for it explicitly.
  setUpAll(initializeDateFormatting);

  const metric = UnitPreferences(
    distance: DistanceUnit.km,
    volume: VolumeUnit.liter,
    currencyCode: 'EUR',
  );
  const imperial = UnitPreferences(
    distance: DistanceUnit.mi,
    volume: VolumeUnit.usGallon,
    currencyCode: 'USD',
  );
  const ukImperial = UnitPreferences(
    distance: DistanceUnit.mi,
    volume: VolumeUnit.ukGallon,
    currencyCode: 'GBP',
  );

  group('conversion is lossless in both directions', () {
    test('kilometres to miles and back', () {
      expect(imperial.kmToDisplay(100), closeTo(62.1371, 0.0001));
      expect(imperial.displayToKm(62.1371), closeTo(100, 0.001));
    });

    test('litres to US gallons and back', () {
      expect(imperial.litersToDisplay(10), closeTo(2.64172, 0.0001));
      expect(imperial.displayToLiters(2.64172), closeTo(10, 0.001));
    });

    test('litres to UK gallons and back', () {
      expect(ukImperial.litersToDisplay(10), closeTo(2.19969, 0.0001));
      expect(ukImperial.displayToLiters(2.19969), closeTo(10, 0.001));
    });

    test('metric preferences pass values through untouched', () {
      expect(metric.kmToDisplay(100), 100);
      expect(metric.litersToDisplay(10), 10);
    });
  });

  group('volume', () {
    test('litres format with the litre suffix', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatVolume(45.5), '45.50 l');
    });

    test('US gallon preferences convert before formatting', () {
      final format = UnitFormat(locale: 'en', preferences: imperial);

      expect(format.formatVolume(10), '2.64 gal');
    });

    test('UK gallon preferences convert before formatting', () {
      final format = UnitFormat(locale: 'en', preferences: ukImperial);

      expect(format.formatVolume(10), '2.20 gal');
    });
  });

  group('formatting is locale aware', () {
    test('Croatian uses a comma decimal separator', () {
      final format = UnitFormat(locale: 'hr', preferences: metric);

      expect(format.formatDistance(1234.5), '1.234,5 km');
    });

    test('English uses a period decimal separator', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatDistance(1234.5), '1,234.5 km');
    });

    test('imperial preferences convert before formatting', () {
      final format = UnitFormat(locale: 'en', preferences: imperial);

      expect(format.formatDistance(100), '62.1 mi');
    });
  });

  group('economy', () {
    test('metric economy reads as litres per 100 km', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      // 7.35 as an IEEE double is 7.34999999999999964, just below the
      // midpoint, so one-decimal rounding lands on 7.3 rather than 7.4.
      expect(format.formatEconomy(7.35), '7.3 l/100km');
    });

    test('imperial economy inverts to miles per gallon', () {
      final format = UnitFormat(locale: 'en', preferences: imperial);

      // 7.35 l/100km == 235.215 / 7.35 == 32.0 US mpg
      expect(format.formatEconomy(7.35), '32.0 mpg');
    });

    test('UK gallon preferences invert to UK miles per gallon', () {
      final format = UnitFormat(locale: 'en', preferences: ukImperial);

      // 7.35 l/100km == 282.481 / 7.35 == 38.4 UK mpg, higher than the 32.0
      // US mpg above because a UK gallon is the larger of the two.
      expect(format.formatEconomy(7.35), '38.4 mpg');
    });

    test('a null economy renders as an em dash', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatEconomy(null), '—');
    });
  });

  // Regression tests for the missing intl date symbol data: before
  // initializeDateFormatting() was wired into main(), these threw
  // LocaleDataException for every locale, including 'en'.
  group('dates are locale aware', () {
    final date = DateTime(2026, 3, 14);

    test('English long date', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatDate(date), 'Mar 14, 2026');
    });

    test('English short date omits the year', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatShortDate(date), 'Mar 14');
    });

    test('Croatian long date', () {
      final format = UnitFormat(locale: 'hr', preferences: metric);

      expect(format.formatDate(date), '14. ožu 2026.');
    });

    test('Croatian short date omits the year', () {
      final format = UnitFormat(locale: 'hr', preferences: metric);

      expect(format.formatShortDate(date), '14. ožu');
    });
  });

  test('money uses the household currency code', () {
    final format = UnitFormat(locale: 'en', preferences: metric);

    expect(format.formatMoney(1234.5), '€1,234.50');
  });
}
