import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/fuel/energy_type.dart';
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

    test('English short date omits the year within it', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(
        format.formatShortDate(date, today: DateTime(2026, 8, 16)),
        'Mar 14',
      );
    });

    test('Croatian long date', () {
      final format = UnitFormat(locale: 'hr', preferences: metric);

      expect(format.formatDate(date), '14. ožu 2026.');
    });

    test('Croatian short date omits the year within it', () {
      final format = UnitFormat(locale: 'hr', preferences: metric);

      expect(
        format.formatShortDate(date, today: DateTime(2026, 8, 16)),
        '14. ožu',
      );
    });

    // A service list runs newest first, so a car's history crossing New Year
    // read "Apr 16" above "Oct 16": correct, and indistinguishable from a
    // list in the wrong order. The year is what tells them apart, and it is
    // only worth the width when it is not this year.
    test('an earlier year is named, so a list cannot read out of order', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(
        format.formatShortDate(date, today: DateTime(2027, 1, 5)),
        'Mar 14, 2026',
      );
    });

    test('a later year is named too, for something scheduled ahead', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(
        format.formatShortDate(
          DateTime(2027, 3, 14),
          today: DateTime(2026, 8, 16),
        ),
        'Mar 14, 2027',
      );
    });

    test('Croatian names the year the same way', () {
      final format = UnitFormat(locale: 'hr', preferences: metric);

      expect(
        format.formatShortDate(date, today: DateTime(2027, 1, 5)),
        '14. ožu 2026.',
      );
    });
  });

  test('money uses the household currency code', () {
    final format = UnitFormat(locale: 'en', preferences: metric);

    expect(format.formatMoney(1234.5), '€1,234.50');
  });

  group('electric vehicles', () {
    test('energy is shown in kWh, whatever the volume preference', () {
      final metricFormat = UnitFormat(locale: 'en', preferences: metric);
      final imperialFormat = UnitFormat(locale: 'en', preferences: imperial);

      expect(metricFormat.formatEnergy(42.5, EnergyType.electric), '42.50 kWh');
      expect(
        imperialFormat.formatEnergy(42.5, EnergyType.electric),
        '42.50 kWh',
      );
    });

    test('liquid energy still follows the volume preference', () {
      final format = UnitFormat(locale: 'en', preferences: imperial);

      expect(format.formatEnergy(10, EnergyType.liquid), '2.64 gal');
    });

    test('electric economy reads as kWh per 100 km', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatEconomy(18.4, EnergyType.electric), '18.4 kWh/100km');
    });

    test('an imperial household reads it per 100 miles', () {
      final format = UnitFormat(locale: 'en', preferences: imperial);

      // 18.4 kWh/100km is 29.6 kWh per 100 miles.
      expect(format.formatEconomy(18.4, EnergyType.electric), '29.6 kWh/100mi');
    });

    test('an unknown electric economy is still an em dash', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatEconomy(null, EnergyType.electric), '—');
    });

    test('liquid economy is unchanged by the new argument', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatEconomy(7.35), '7.3 l/100km');
      expect(format.formatEconomy(7.35, EnergyType.liquid), '7.3 l/100km');
    });
  });

  group('editableNumber', () {
    test('drops the trailing zeros a fixed format would add', () {
      expect(UnitFormat.editableNumber(1.75), '1.75');
      expect(UnitFormat.editableNumber(1.5, decimals: 1), '1.5');
    });

    test('drops the decimal point when nothing follows it', () {
      expect(UnitFormat.editableNumber(55), '55');
      expect(UnitFormat.editableNumber(55, decimals: 0), '55');
    });

    test('keeps the digits that matter at the given precision', () {
      expect(UnitFormat.editableNumber(1.5551), '1.555');
      expect(UnitFormat.editableNumber(1.5551, decimals: 1), '1.6');
    });

    test(
      'stays locale-independent, since entry fields parse either separator',
      () {
        expect(UnitFormat.editableNumber(1234.5, decimals: 1), '1234.5');
      },
    );

    test('handles zero', () {
      expect(UnitFormat.editableNumber(0), '0');
    });
  });

  group('money at a finer precision', () {
    // A cost per kilometre is a fraction of a currency unit. Two decimals
    // rounds 0.104 and 0.096 to the same "0.10", which is the whole figure
    // the driver is looking at.
    test('shows the digits a per-kilometre figure needs', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatMoney(0.104, decimals: 3), contains('0.104'));
    });

    test('still defaults to ordinary currency precision', () {
      final format = UnitFormat(locale: 'en', preferences: metric);

      expect(format.formatMoney(12.5), contains('12.50'));
    });
  });
}
