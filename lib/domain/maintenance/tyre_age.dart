import 'date_math.dart';

/// How a set's age reads against the guidance, independent of its tread.
///
/// Wear and age are separate reasons to replace a tyre, which is why this is a
/// sibling of the wear projector rather than part of it: a set can be legal on
/// tread and long past it on age, and a set can be nearly new and worn out.
enum TyreAgeStanding {
  /// Under [TyreAge.ageingYears]. Nothing worth saying.
  fresh,

  /// Old enough that the usual advice is to have it looked at each year.
  ageing,

  /// Past the point most manufacturers say to replace regardless of tread.
  expired,
}

/// A set's age, and how much the figure is worth.
class TyreAge {
  const TyreAge({
    required this.years,
    required this.estimated,
    required this.standing,
  });

  /// Whole years. Deliberately not months: the thresholds are annual and a
  /// figure to the month would imply a precision a DOT week does not carry.
  final int years;

  /// True when the age came from the fitted date rather than the sidewall.
  ///
  /// The fallback errs low — a set fitted in 2020 may have been made in 2016,
  /// which is four years of shelf life the app cannot see — so it is marked,
  /// the same way an assumed driving rate is on the maintenance screen.
  final bool estimated;

  final TyreAgeStanding standing;

  /// Worth a look. Most manufacturers suggest an annual inspection from about
  /// here, and several European winter-tyre recommendations treat six as the
  /// practical limit.
  static const int ageingYears = 6;

  /// Replace regardless of tread. The figure manufacturers converge on, and
  /// the one this check exists for.
  static const int expiredYears = 10;

  /// Null when nothing dates the set at all — neither a DOT code nor a fitted
  /// date. Silence is the honest answer there; a set with no dates is not
  /// young, it is unknown.
  static TyreAge? assess({
    DateTime? manufacturedOn,
    DateTime? fittedAt,
    required DateTime today,
  }) {
    final from = manufacturedOn ?? fittedAt;
    if (from == null) {
      return null;
    }

    final years = _wholeYearsBetween(from, today);
    return TyreAge(
      years: years,
      estimated: manufacturedOn == null,
      standing: switch (years) {
        >= expiredYears => TyreAgeStanding.expired,
        >= ageingYears => TyreAgeStanding.ageing,
        _ => TyreAgeStanding.fresh,
      },
    );
  }

  /// Whole years elapsed, counting a birthday only once it has passed.
  static int _wholeYearsBetween(DateTime from, DateTime to) {
    final start = DateMath.dateOnly(from);
    final end = DateMath.dateOnly(to);
    var years = end.year - start.year;
    final hadBirthday =
        end.month > start.month ||
        (end.month == start.month && end.day >= start.day);
    if (!hadBirthday) {
      years -= 1;
    }
    return years < 0 ? 0 : years;
  }
}

/// The four digits moulded into a tyre's sidewall: week, then two-digit year.
abstract final class TyreDotCode {
  /// The Monday of the week [code] names, or null for anything unreadable.
  ///
  /// Null rather than a guess, the rule every stored-key parser in this app
  /// follows: a wrong manufacture date is worse than none, because it drives a
  /// warning that either never comes or comes for the wrong set.
  static DateTime? parse(String code, {DateTime? today}) {
    final digits = code.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(digits)) {
      return null;
    }
    final week = int.parse(digits.substring(0, 2));
    if (week < 1 || week > 53) {
      return null;
    }

    final now = today ?? DateTime.now();
    final twoDigitYear = int.parse(digits.substring(2));
    // The most recent past year the digits can name. A tyre cannot have been
    // made in the future, and a two-digit year is otherwise ambiguous by a
    // century.
    var year = now.year - now.year % 100 + twoDigitYear;
    if (year > now.year) {
      year -= 100;
    }

    // ISO weeks start on Monday, and week 1 is the one containing 4 January.
    final fourthOfJanuary = DateTime.utc(year, 1, 4);
    final firstMonday = fourthOfJanuary.subtract(
      Duration(days: fourthOfJanuary.weekday - DateTime.monday),
    );
    return firstMonday.add(Duration(days: (week - 1) * 7));
  }

  /// The inverse, for showing a stored date back as the code on the sidewall.
  /// Empty for null, so it drops straight into a text field.
  static String format(DateTime? manufacturedOn) {
    if (manufacturedOn == null) {
      return '';
    }
    // Both halves come from the week, not from the date. Week 1 of 2019 began
    // on 31 December 2018, so reading the year off the date itself prints the
    // previous one and the code stops matching the sidewall.
    final (week, year) = _isoWeekOf(manufacturedOn);
    return '${week.toString().padLeft(2, '0')}'
        '${(year % 100).toString().padLeft(2, '0')}';
  }

  /// The ISO week a date falls in, and the year that week belongs to.
  ///
  /// Week 1 is the one containing 4 January, so a date in late December can
  /// belong to week 1 of the next year. The week's own year is the year of its
  /// Thursday, which is what makes that come out right.
  static (int, int) _isoWeekOf(DateTime date) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final firstOfYear = DateTime.utc(thursday.year, 1, 1);
    final week = 1 + thursday.difference(firstOfYear).inDays ~/ 7;
    return (week, thursday.year);
  }
}
