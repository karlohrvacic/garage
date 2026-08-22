import 'package:intl/intl.dart';

import '../../domain/fuel/energy_type.dart';

enum DistanceUnit { km, mi }

enum VolumeUnit { liter, usGallon, ukGallon }

const double _kmPerMile = 1.609344;
const double _litersPerUsGallon = 3.785411784;
const double _litersPerUkGallon = 4.54609;

/// Divide by l/100km to get miles per US gallon.
const double _mpgUsConstant = 235.214583;

/// Divide by l/100km to get miles per UK gallon.
const double _mpgUkConstant = 282.480936;

/// Litres in one gallon of the given flavour.
///
/// A household reading litres has no gallon of its own, so it gets the US one:
/// that is what an unqualified "gallons" means in a file from most apps.
double litresPerGallon(VolumeUnit unit) =>
    unit == VolumeUnit.ukGallon ? _litersPerUkGallon : _litersPerUsGallon;

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

  /// A plain number for a text field the user is about to edit. Fixed decimals
  /// would put "1.750" where the receipt says "1.75", and entry fields parse
  /// either decimal separator themselves, so no locale grouping is applied.
  static String editableNumber(double value, {int decimals = 3}) {
    final text = value.toStringAsFixed(decimals);
    if (!text.contains('.')) {
      return text;
    }
    final trimmed = text.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

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

  /// [decimals] overrides the currency's usual precision. A cost per kilometre
  /// is a fraction of a unit, and two decimals rounds 0.104 and 0.096 to the
  /// same figure, which is the one being looked at.
  String formatMoney(double? amount, {int? decimals}) {
    if (amount == null) {
      return emptyValue;
    }
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: preferences.currencyCode,
      decimalDigits: decimals,
    ).format(amount);
  }

  /// What a kilometre of driving costs, in the distance unit the household
  /// reads.
  ///
  /// The figure carries its own unit because the label above it cannot: a
  /// household reading miles was shown a per-kilometre number under a heading
  /// that said km, and neither of them was right.
  String formatCostPerDistance(double? costPerKm) {
    if (costPerKm == null) {
      return emptyValue;
    }
    if (preferences.distance == DistanceUnit.km) {
      return '${formatMoney(costPerKm)}/km';
    }
    // A mile is longer than a kilometre, so it costs more to cover: multiply.
    return '${formatMoney(costPerKm * _kmPerMile)}/mi';
  }

  /// How far this vehicle is driven in a day, in the household's distance
  /// unit — "68 km" or "42 mi", without the "per day" part.
  ///
  /// The caller supplies the "per day", because Croatian inflects it and a
  /// slash-joined suffix here could not be translated.
  String formatDailyDistance(double km) => formatDistance(km, decimals: 0);

  /// How much went in, in the unit that energy is measured in.
  ///
  /// Electricity is kilowatt-hours the world over: a household that reads
  /// distance in miles and fuel in gallons still charges in kWh.
  String formatEnergy(double quantity, EnergyType energy, {int decimals = 2}) {
    if (energy.isElectric) {
      return '${_decimal(decimals).format(quantity)} kWh';
    }
    return formatVolume(quantity, decimals: decimals);
  }

  /// The canonical economy figure — litres per 100 km, or kilowatt-hours per
  /// 100 km for an electric vehicle.
  ///
  /// Imperial preferences invert a liquid figure to miles per gallon, which is
  /// how those users read economy. There is no equivalent inversion for
  /// electricity, so it stays "per 100", converted to miles.
  String formatEconomy(
    double? perHundredKm, [
    EnergyType energy = EnergyType.liquid,
  ]) {
    if (perHundredKm == null || perHundredKm <= 0) {
      return emptyValue;
    }
    if (energy.isElectric) {
      if (preferences.distance == DistanceUnit.km) {
        return '${_decimal(1).format(perHundredKm)} kWh/100km';
      }
      final perHundredMiles = perHundredKm * _kmPerMile;
      return '${_decimal(1).format(perHundredMiles)} kWh/100mi';
    }
    if (preferences.distance == DistanceUnit.km &&
        preferences.volume == VolumeUnit.liter) {
      return '${_decimal(1).format(perHundredKm)} l/100km';
    }
    final constant = preferences.volume == VolumeUnit.ukGallon
        ? _mpgUkConstant
        : _mpgUsConstant;
    return '${_decimal(1).format(constant / perHundredKm)} mpg';
  }

  /// Requires `intl` date symbol data for [locale] to be initialized, or this
  /// throws `LocaleDataException`. Inside a `MaterialApp` with the localization
  /// delegates installed that happens automatically; tests and other isolated
  /// use must call `initializeDateFormatting()` first.
  String formatDate(DateTime date) => DateFormat.yMMMd(locale).format(date);

  /// Day and month, plus the year whenever [date] falls outside the year
  /// containing [today].
  ///
  /// A vehicle's history runs newest first, so a car serviced in October and
  /// again the following April listed "Apr 16" above "Oct 16": correct, and
  /// indistinguishable from a list sorted the wrong way. Naming the year only
  /// when it differs keeps the common case short and the ambiguous case clear.
  ///
  /// Requires `intl` date symbol data for [locale] to be initialized, or this
  /// throws `LocaleDataException`. Inside a `MaterialApp` with the localization
  /// delegates installed that happens automatically; tests and other isolated
  /// use must call `initializeDateFormatting()` first.
  String formatShortDate(DateTime date, {DateTime? today}) {
    final now = today ?? DateTime.now();
    return date.year == now.year
        ? DateFormat.MMMd(locale).format(date)
        : formatDate(date);
  }

  /// A day in the year with no year on it — `15 Nov`, `15. stu`.
  ///
  /// For a statutory window, which is a month and a day and genuinely has no
  /// year: writing one would suggest the rule belongs to that year.
  ///
  /// Requires `intl` date symbol data for [locale] to be initialized, or this
  /// throws `LocaleDataException`. Inside a `MaterialApp` with the localization
  /// delegates installed that happens automatically; tests and other isolated
  /// use must call `initializeDateFormatting()` first.
  String formatMonthDay(DateTime date) => DateFormat.MMMd(locale).format(date);

  NumberFormat _decimal(int decimals) {
    return NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
  }
}
