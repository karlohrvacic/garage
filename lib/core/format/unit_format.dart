import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

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

  /// What a fill-up holds, as stored → as the household reads it. A volume
  /// is litres and converts; a charge is kilowatt-hours and never does.
  ///
  /// Every fill-up quantity crosses here rather than through
  /// [litersToDisplay], because which of the two it is belongs to the entry:
  /// see `EnergyType.forEntry`.
  double quantityToDisplay(double stored, EnergyType energy) =>
      energy.isElectric ? stored : litersToDisplay(stored);

  /// The inverse of [quantityToDisplay]: what was typed → what is stored.
  double displayToQuantity(double shown, EnergyType energy) =>
      energy.isElectric ? shown : displayToLiters(shown);

  /// A price per stored unit → a price per the unit the household reads.
  ///
  /// A gallon is more litres, so it costs more: the price converts the
  /// opposite way to the volume. A price per kilowatt-hour is left alone.
  double unitPriceToDisplay(double perStoredUnit, EnergyType energy) =>
      energy.isElectric ? perStoredUnit : perStoredUnit * displayToLiters(1);

  /// Whether economy reads as litres per 100 km (the canonical figure) or as
  /// miles per gallon, which is the inverse and needs its own arithmetic.
  bool get _economyIsPerHundredKm =>
      distance == DistanceUnit.km && volume == VolumeUnit.liter;

  double get _mpgConstant =>
      volume == VolumeUnit.ukGallon ? _mpgUkConstant : _mpgUsConstant;

  /// l/100km → the household's economy figure. Zero stays zero: the inverse
  /// of nothing is not infinity, it is a box with nothing useful in it.
  double economyToDisplay(double perHundredKm) {
    if (_economyIsPerHundredKm || perHundredKm <= 0) {
      return perHundredKm;
    }
    return _mpgConstant / perHundredKm;
  }

  /// The household's economy figure → l/100km. The mpg inversion is its own
  /// inverse, so the same constant serves both directions.
  double displayToEconomy(double value) {
    if (_economyIsPerHundredKm || value <= 0) {
      return value;
    }
    return _mpgConstant / value;
  }
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

  /// The unit to show beside a number, on a form field as well as in prose.
  ///
  /// A box labelled "Volume" with nothing beside the number was read as
  /// "litres, probably". These exist so every field can say what it takes,
  /// from one place, in the household's own units.
  String get distanceSuffix =>
      preferences.distance == DistanceUnit.km ? 'km' : 'mi';

  String get volumeSuffix => switch (preferences.volume) {
    VolumeUnit.liter => 'l',
    VolumeUnit.usGallon || VolumeUnit.ukGallon => 'gal',
  };

  /// Electricity is kilowatt-hours the world over; anything else is the
  /// household's volume unit.
  String energySuffix(EnergyType energy) =>
      energy.isElectric ? 'kWh' : volumeSuffix;

  /// The currency's symbol, or its code when `intl` knows no symbol for it —
  /// "XYZ" beside a number is still better than nothing.
  String get currencySymbol =>
      currencyFormatter(locale, preferences.currencyCode, null).currencySymbol;

  /// What a price per unit is a price per: "€/l", "\$/gal", "€/kWh".
  String pricePerUnitSuffix([EnergyType energy = EnergyType.liquid]) =>
      '$currencySymbol/${energySuffix(energy)}';

  /// The unit [formatEconomy] writes a liquid figure in.
  String get economySuffix =>
      preferences.distance == DistanceUnit.km &&
          preferences.volume == VolumeUnit.liter
      ? 'l/100km'
      : 'mpg';

  String formatDistance(double km, {int decimals = 1}) {
    final value = preferences.kmToDisplay(km);
    return '${_decimal(decimals).format(value)} $distanceSuffix';
  }

  String formatVolume(double liters, {int decimals = 2}) {
    final value = preferences.litersToDisplay(liters);
    return '${_decimal(decimals).format(value)} $volumeSuffix';
  }

  /// [decimals] overrides the currency's usual precision. A cost per kilometre
  /// is a fraction of a unit, and two decimals rounds 0.104 and 0.096 to the
  /// same figure, which is the one being looked at.
  String formatMoney(double? amount, {int? decimals}) {
    if (amount == null) {
      return emptyValue;
    }
    return currencyFormatter(
      locale,
      preferences.currencyCode,
      decimals,
    ).format(amount);
  }

  /// What a kilometre of driving costs, in the distance unit the household
  /// reads.
  ///
  /// The figure carries its own unit because the label above it cannot: a
  /// household reading miles was shown a per-kilometre number under a heading
  /// that said km, and neither of them was right.
  /// [decimals] is for the running-cost card, where the figure is the
  /// headline rather than a footnote: at two decimals a cost per kilometre
  /// rounds to a couple of significant digits and two quite different cars
  /// read the same.
  String formatCostPerDistance(double? costPerKm, {int? decimals}) {
    if (costPerKm == null) {
      return emptyValue;
    }
    if (preferences.distance == DistanceUnit.km) {
      return '${formatMoney(costPerKm, decimals: decimals)}/km';
    }
    // A mile is longer than a kilometre, so it costs more to cover: multiply.
    return '${formatMoney(costPerKm * _kmPerMile, decimals: decimals)}/mi';
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
  String formatDate(DateTime date) =>
      dateFormatter(locale, withYear: true).format(date);

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
        ? dateFormatter(locale, withYear: false).format(date)
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
  String formatMonthDay(DateTime date) =>
      dateFormatter(locale, withYear: false).format(date);

  /// A tread depth in millimetres, in the reader's own number format. The
  /// tyre card printed "2.4 mm" with a full stop two lines above a legal
  /// minimum written "1,6 mm", on the same card, in Croatian.
  String formatMillimetres(double mm, {int decimals = 1}) =>
      '${_decimal(decimals).format(mm)} mm';

  NumberFormat _decimal(int decimals) => decimalFormatter(locale, decimals);

  /// The `intl` formatters, built once per shape and shared from here on.
  ///
  /// Building one parses the locale's pattern, which measured **7.5x** the
  /// cost of reusing it — 2.18 ms against 0.29 ms per frame over 200 rows.
  /// Every formatter used to be constructed per call, on screens that format
  /// thirty-odd values in a single build, so the cost sat under everything.
  ///
  /// Not evicted, because there is nothing to evict: the keys are the app's
  /// three locales, a handful of decimal counts, and the one currency a
  /// household has set. Each map stays a few entries for the life of the
  /// process.
  ///
  /// The only way a cache like this can be wrong is by keying on too little
  /// and handing back somebody else's formatter — dollars shown as euros,
  /// with nothing thrown. Every part of the shape is therefore in the key,
  /// including `formatMoney`'s nullable precision override, and
  /// `test/core/format/unit_format_test.dart` holds one test per way they
  /// could collide.
  static final Map<(String, int), NumberFormat> _decimals = {};
  static final Map<(String, String, int?), NumberFormat> _currencies = {};
  static final Map<(String, bool), DateFormat> _dates = {};

  @visibleForTesting
  static NumberFormat decimalFormatter(String locale, int decimals) =>
      _decimals.putIfAbsent(
        (locale, decimals),
        () => NumberFormat.decimalPatternDigits(
          locale: locale,
          decimalDigits: decimals,
        ),
      );

  @visibleForTesting
  static NumberFormat currencyFormatter(
    String locale,
    String currencyCode,
    int? decimals,
  ) => _currencies.putIfAbsent(
    (locale, currencyCode, decimals),
    () => NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
      decimalDigits: decimals,
    ),
  );

  /// `yMMMd` when [withYear], `MMMd` otherwise. Two shapes, one key each: a
  /// date that names its year and one that must not are not interchangeable.
  @visibleForTesting
  static DateFormat dateFormatter(String locale, {required bool withYear}) =>
      _dates.putIfAbsent((
        locale,
        withYear,
      ), () => withYear ? DateFormat.yMMMd(locale) : DateFormat.MMMd(locale));
}
