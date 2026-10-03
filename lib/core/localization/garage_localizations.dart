import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;

/// The app's delegates: its own strings, and Material's and Cupertino's for
/// the three languages it ships in.
///
/// The generated `localizationsDelegates` on `AppLocalizations` hands over
/// Flutter's global delegates, which pick among every language Flutter
/// translates at run time, so none of them can be left out of a build: they
/// were 345 KB of the JavaScript (decision 189). Naming the three here is what
/// lets the rest go.
const List<LocalizationsDelegate<Object?>> garageLocalizationsDelegates = [
  AppLocalizations.delegate,
  _MaterialDelegate(),
  _CupertinoDelegate(),
  GlobalWidgetsLocalizations.delegate,
];

bool _speaks(Locale locale) =>
    const {'en', 'hr', 'it'}.contains(locale.languageCode);

/// The date symbols intl carries for every locale. Synchronous for the local
/// data, whatever the signature says: an asynchronous load would give every
/// screen a blank first frame.
void _loadDateSymbols() => unawaited(initializeDateFormatting());

class _MaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialDelegate();

  @override
  bool isSupported(Locale locale) => _speaks(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    _loadDateSymbols();
    final name = locale.languageCode;
    final fullYear = intl.DateFormat.y(name);
    final compact = intl.DateFormat.yMd(name);
    final short = intl.DateFormat.yMMMd(name);
    final medium = intl.DateFormat.MMMEd(name);
    final long = intl.DateFormat.yMMMMEEEEd(name);
    final yearMonth = intl.DateFormat.yMMMM(name);
    final shortMonthDay = intl.DateFormat.MMMd(name);
    final decimal = intl.NumberFormat.decimalPattern(name);
    final twoDigits = intl.NumberFormat('00', name);
    return SynchronousFuture(switch (name) {
      'hr' => MaterialLocalizationHr(
        fullYearFormat: fullYear,
        compactDateFormat: compact,
        shortDateFormat: short,
        mediumDateFormat: medium,
        longDateFormat: long,
        yearMonthFormat: yearMonth,
        shortMonthDayFormat: shortMonthDay,
        decimalFormat: decimal,
        twoDigitZeroPaddedFormat: twoDigits,
      ),
      'it' => MaterialLocalizationIt(
        fullYearFormat: fullYear,
        compactDateFormat: compact,
        shortDateFormat: short,
        mediumDateFormat: medium,
        longDateFormat: long,
        yearMonthFormat: yearMonth,
        shortMonthDayFormat: shortMonthDay,
        decimalFormat: decimal,
        twoDigitZeroPaddedFormat: twoDigits,
      ),
      _ => MaterialLocalizationEn(
        fullYearFormat: fullYear,
        compactDateFormat: compact,
        shortDateFormat: short,
        mediumDateFormat: medium,
        longDateFormat: long,
        yearMonthFormat: yearMonth,
        shortMonthDayFormat: shortMonthDay,
        decimalFormat: decimal,
        twoDigitZeroPaddedFormat: twoDigits,
      ),
    });
  }

  @override
  bool shouldReload(_MaterialDelegate old) => false;
}

/// Cupertino's words, which a text field's selection menu uses in Safari on
/// an iPhone.
class _CupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoDelegate();

  @override
  bool isSupported(Locale locale) => _speaks(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    _loadDateSymbols();
    final name = locale.languageCode;
    final fullYear = intl.DateFormat.y(name);
    final day = intl.DateFormat.d(name);
    final weekday = intl.DateFormat.E(name);
    final medium = intl.DateFormat.MMMEd(name);
    final hour = intl.DateFormat('HH', name);
    final minute = intl.DateFormat.m(name);
    final twoDigitMinute = intl.DateFormat('mm', name);
    final second = intl.DateFormat.s(name);
    final decimal = intl.NumberFormat.decimalPattern(name);
    return SynchronousFuture(switch (name) {
      'hr' => CupertinoLocalizationHr(
        fullYearFormat: fullYear,
        dayFormat: day,
        weekdayFormat: weekday,
        mediumDateFormat: medium,
        singleDigitHourFormat: hour,
        singleDigitMinuteFormat: minute,
        doubleDigitMinuteFormat: twoDigitMinute,
        singleDigitSecondFormat: second,
        decimalFormat: decimal,
      ),
      'it' => CupertinoLocalizationIt(
        fullYearFormat: fullYear,
        dayFormat: day,
        weekdayFormat: weekday,
        mediumDateFormat: medium,
        singleDigitHourFormat: hour,
        singleDigitMinuteFormat: minute,
        doubleDigitMinuteFormat: twoDigitMinute,
        singleDigitSecondFormat: second,
        decimalFormat: decimal,
      ),
      _ => CupertinoLocalizationEn(
        fullYearFormat: fullYear,
        dayFormat: day,
        weekdayFormat: weekday,
        mediumDateFormat: medium,
        singleDigitHourFormat: hour,
        singleDigitMinuteFormat: minute,
        doubleDigitMinuteFormat: twoDigitMinute,
        singleDigitSecondFormat: second,
        decimalFormat: decimal,
      ),
    });
  }

  @override
  bool shouldReload(_CupertinoDelegate old) => false;
}
