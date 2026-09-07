import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter/foundation.dart';

/// The latest date a record of something that has already happened may carry.
///
/// Today, not 2100: a fill-up or a service dated next week is a typo, and the
/// picker is where it is cheapest to catch. [current] widens the bound when
/// the entry is already dated ahead — imported data has carried such dates,
/// and a picker that will not open on one leaves it uncorrectable.
DateTime lastLoggableDate(DateTime current, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final endOfToday = DateTime(today.year, today.month, today.day);
  return current.isAfter(endOfToday) ? current : endOfToday;
}

/// The earliest date a record may carry: the year 2000, or the entry's own
/// date when it is older still.
///
/// The same argument as [lastLoggableDate] in the other direction — a picker
/// whose bounds exclude the date it is opening on trips the framework's own
/// assertion, and a classic car's service history predates the floor.
DateTime firstLoggableDate(DateTime current) {
  final floor = DateTime(2000);
  return current.isBefore(floor) ? current : floor;
}

/// The app's date picker: Material's, with the week starting on Monday in
/// English as it does on the planner calendar.
///
/// Only the first weekday changes. Asking for British English would have
/// done that too, and also switched the picker's typed dates to day-first
/// while the rest of the English interface is month-first, so "09/04/2026"
/// typed the way the app shows dates would have saved 9 April.
Future<DateTime?> showGarageDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,

  /// Replaces Material's "Select date" when the question is a particular one
  /// — extending a loan asks "until when?", and the default says nothing.
  String? helpText,
}) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    builder: english
        ? (context, child) => Localizations.override(
            context: context,
            delegates: const [_MondayFirstEnglishDelegate()],
            child: child!,
          )
        : null,
  );
}

class _MondayFirstEnglishDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _MondayFirstEnglishDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    const name = 'en';
    // Synchronous, like the framework's own delegate: an async load gives
    // the dialog a blank first frame.
    return SynchronousFuture(
      _MondayFirstEnglish(
        fullYearFormat: intl.DateFormat.y(name),
        compactDateFormat: intl.DateFormat.yMd(name),
        shortDateFormat: intl.DateFormat.yMMMd(name),
        mediumDateFormat: intl.DateFormat.MMMEd(name),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(name),
        yearMonthFormat: intl.DateFormat.yMMMM(name),
        shortMonthDayFormat: intl.DateFormat.MMMd(name),
        decimalFormat: intl.NumberFormat.decimalPattern(name),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),
      ),
    );
  }

  @override
  bool shouldReload(_MondayFirstEnglishDelegate old) => false;
}

/// American English in every string and format, Monday first in the grid.
class _MondayFirstEnglish extends MaterialLocalizationEn {
  const _MondayFirstEnglish({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  @override
  int get firstDayOfWeekIndex => 1;
}
