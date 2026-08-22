/// When a country's winter-tyre period runs, and on what terms.
///
/// The dates are national and statutory, so they are the same kind of fact as
/// the registration and inspection cycles in `service_types` — and they carry
/// the same rule: **only the countries that have actually been checked get a
/// window.** A plausible-looking date for a country nobody verified is worse
/// than no date, because the app looks authoritative while being wrong.
///
/// Verified against national sources in August 2026:
///
/// | Country | Window | How it binds | Source |
/// |---|---|---|---|
/// | HR | 15 Nov – 15 Apr | Regardless of weather, on winter road sections | MUP; NN 121/2020 |
/// | SI | 15 Nov – 15 Mar | Fixed, and any time conditions are wintry | europe-consommateurs.eu |
/// | BA | 1 Nov – 1 Apr | "bez obzira na vremenske uslove" | BIHAMK |
/// | RS | 1 Nov – 1 Apr | Within the window, only when there is snow or ice | Serbian Monitor |
/// | AT | 1 Nov – 15 Apr | Within the window, only in wintry conditions | bmimi.gv.at |
/// | DE | none | Whenever the road is wintry (§2(3a) StVO) | ADAC |
///
/// Italy is left out on purpose: its obligation is set per road by ordinance
/// rather than nationally, so there is no single window to name. Great Britain
/// and the United States have no national requirement at all — several US
/// states have their own, which is a per-state table this does not attempt.
library;

/// How a country's winter-tyre requirement binds.
enum WinterTyreRule {
  /// Fixed dates, and the weather does not matter.
  dated,

  /// Fixed dates, but within them the requirement bites only when the road is
  /// actually wintry. Worth a reminder anyway: the dates are when a driver has
  /// to be *ready*, which is the thing a reminder can help with.
  datedWhenWintry,

  /// No dates. The requirement follows the road's condition, so nothing can be
  /// scheduled — but saying so is still better than silence.
  whenWintryOnly,

  /// Nothing verified for this country.
  none,
}

/// A day in the year, with no year attached — which is what a statutory window
/// actually is.
class MonthDay {
  const MonthDay(this.month, this.day);

  final int month;
  final int day;

  DateTime inYear(int year) => DateTime.utc(year, month, day);

  @override
  bool operator ==(Object other) =>
      other is MonthDay && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(month, day);

  @override
  String toString() => 'MonthDay($month, $day)';
}

/// One country's rule.
class WinterTyrePeriod {
  const WinterTyrePeriod({required this.rule, this.start, this.end});

  final WinterTyreRule rule;

  /// The day winter tyres have to be on by, and the day they stop being
  /// needed. Both null unless [rule] is one of the dated ones.
  final MonthDay? start;
  final MonthDay? end;

  bool get hasDates => start != null && end != null;
}

/// Which way a swap goes, so a reminder can say *fit winter tyres* rather than
/// the useless *swap your tyres*.
enum SwapDirection { toWinter, toSummer }

/// A dated swap: when, and which way.
class SeasonalSwap {
  const SeasonalSwap({required this.date, required this.direction});

  /// UTC, date-only, like every domain [DateTime].
  final DateTime date;
  final SwapDirection direction;

  @override
  bool operator ==(Object other) =>
      other is SeasonalSwap &&
      other.date == date &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(date, direction);

  @override
  String toString() => 'SeasonalSwap($date, ${direction.name})';
}

const _periods = <String, WinterTyrePeriod>{
  'HR': WinterTyrePeriod(
    rule: WinterTyreRule.dated,
    start: MonthDay(11, 15),
    end: MonthDay(4, 15),
  ),
  'SI': WinterTyrePeriod(
    rule: WinterTyreRule.dated,
    start: MonthDay(11, 15),
    end: MonthDay(3, 15),
  ),
  'BA': WinterTyrePeriod(
    rule: WinterTyreRule.dated,
    start: MonthDay(11, 1),
    end: MonthDay(4, 1),
  ),
  'RS': WinterTyrePeriod(
    rule: WinterTyreRule.datedWhenWintry,
    start: MonthDay(11, 1),
    end: MonthDay(4, 1),
  ),
  'AT': WinterTyrePeriod(
    rule: WinterTyreRule.datedWhenWintry,
    start: MonthDay(11, 1),
    end: MonthDay(4, 15),
  ),
  'DE': WinterTyrePeriod(rule: WinterTyreRule.whenWintryOnly),
};

const _unverified = WinterTyrePeriod(rule: WinterTyreRule.none);

/// What [countryCode] requires. Never null: a country nobody checked gets
/// [WinterTyreRule.none], which claims nothing.
WinterTyrePeriod winterTyrePeriodFor(String countryCode) =>
    _periods[countryCode.toUpperCase()] ?? _unverified;

/// The next swap [countryCode] puts on the calendar, or null where there is no
/// dated window to pin one to.
///
/// A swap falling *on* [today] is the next one, not a missed one: the tyres
/// have to be on by the first day of the window, so on that day the job is due
/// rather than six months away.
SeasonalSwap? nextSeasonalSwap({
  required String countryCode,
  required DateTime today,
}) {
  final period = winterTyrePeriodFor(countryCode);
  if (!period.hasDates) {
    return null;
  }

  final from = DateTime.utc(today.year, today.month, today.day);
  // This year's two dates and next year's, so a date already past in January
  // still finds its successor without special-casing the year end.
  final candidates = <SeasonalSwap>[
    for (final year in [from.year, from.year + 1]) ...[
      SeasonalSwap(
        date: period.start!.inYear(year),
        direction: SwapDirection.toWinter,
      ),
      SeasonalSwap(
        date: period.end!.inYear(year),
        direction: SwapDirection.toSummer,
      ),
    ],
  ]..sort((a, b) => a.date.compareTo(b.date));

  for (final candidate in candidates) {
    if (!candidate.date.isBefore(from)) {
      return candidate;
    }
  }
  return null;
}
