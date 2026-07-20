import 'package:intl/intl.dart';

enum DistanceUnit { km, mi }

enum VolumeUnit { liter, usGallon, ukGallon }

const double _kmPerMile = 1.609344;
const double _litersPerUsGallon = 3.785411784;
const double _litersPerUkGallon = 4.54609;

/// Divide by l/100km to get miles per US gallon.
const double _mpgUsConstant = 235.214583;

/// Divide by l/100km to get miles per UK gallon.
const double _mpgUkConstant = 282.480936;

/// A household's display preferences. Values are always stored in kilometres
/// and litres; these convert only at the presentation boundary.
class UnitPreferences {
  const UnitPreferences({
    required this.distance,
    required this.volume,
    required this.currencyCode,
  });

  final DistanceUnit distance;
  final VolumeUnit volume;
  final String currencyCode;

  double kmToDisplay(double km) =>
      distance == DistanceUnit.km ? km : km / _kmPerMile;

  double displayToKm(double value) =>
      distance == DistanceUnit.km ? value : value * _kmPerMile;

  double litersToDisplay(double liters) => switch (volume) {
        VolumeUnit.liter => liters,
        VolumeUnit.usGallon => liters / _litersPerUsGallon,
        VolumeUnit.ukGallon => liters / _litersPerUkGallon,
      };

  double displayToLiters(double value) => switch (volume) {
        VolumeUnit.liter => value,
        VolumeUnit.usGallon => value * _litersPerUsGallon,
        VolumeUnit.ukGallon => value * _litersPerUkGallon,
      };
}

/// Locale-aware formatting of canonical (km / litre / currency) values.
class UnitFormat {
  UnitFormat({required this.locale, required this.preferences});

  final String locale;
  final UnitPreferences preferences;

  static const String emptyValue = '—';

  String formatDistance(double km, {int decimals = 1}) {
    final value = preferences.kmToDisplay(km);
    final suffix = preferences.distance == DistanceUnit.km ? 'km' : 'mi';
    return '${_decimal(decimals).format(value)} $suffix';
  }

  String formatVolume(double liters, {int decimals = 2}) {
    final value = preferences.litersToDisplay(liters);
    final suffix = switch (preferences.volume) {
      VolumeUnit.liter => 'l',
      VolumeUnit.usGallon || VolumeUnit.ukGallon => 'gal',
    };
    return '${_decimal(decimals).format(value)} $suffix';
  }

  String formatMoney(double? amount) {
    if (amount == null) {
      return emptyValue;
    }
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: preferences.currencyCode,
    ).format(amount);
  }

  /// [litersPer100Km] is the canonical economy figure. Imperial preferences
  /// invert it to miles per gallon, which is how those users read economy.
  String formatEconomy(double? litersPer100Km) {
    if (litersPer100Km == null || litersPer100Km <= 0) {
      return emptyValue;
    }
    if (preferences.distance == DistanceUnit.km &&
        preferences.volume == VolumeUnit.liter) {
      return '${_decimal(1).format(litersPer100Km)} l/100km';
    }
    final constant = preferences.volume == VolumeUnit.ukGallon
        ? _mpgUkConstant
        : _mpgUsConstant;
    return '${_decimal(1).format(constant / litersPer100Km)} mpg';
  }

  /// Requires `intl` date symbol data for [locale] to be initialized, or this
  /// throws `LocaleDataException`. Inside a `MaterialApp` with the localization
  /// delegates installed that happens automatically; tests and other isolated
  /// use must call `initializeDateFormatting()` first.
  String formatDate(DateTime date) => DateFormat.yMMMd(locale).format(date);

  /// Requires `intl` date symbol data for [locale] to be initialized, or this
  /// throws `LocaleDataException`. Inside a `MaterialApp` with the localization
  /// delegates installed that happens automatically; tests and other isolated
  /// use must call `initializeDateFormatting()` first.
  String formatShortDate(DateTime date) => DateFormat.MMMd(locale).format(date);

  NumberFormat _decimal(int decimals) {
    return NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
  }
}
