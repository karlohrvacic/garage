/// A Postgres `date` column carries no time and no zone. The domain treats
/// every [DateTime] as UTC — the `isUtc` flag is load-bearing for entity
/// equality — so a date-only value is read as UTC midnight of that calendar
/// day rather than through `DateTime.parse`, whose local midnight would flip
/// the flag and silently break equality on round-trip.
library;

/// The calendar day [date] falls on, as the `YYYY-MM-DD` a date column wants.
///
/// A local value is taken at its own calendar day rather than converted: for a
/// user west of UTC, converting first moves a late-evening entry onto the next
/// day, filing a fill-up under a date the driver never saw.
String dateToColumn(DateTime date) {
  final day = date.isUtc ? date : DateTime.utc(date.year, date.month, date.day);
  return day.toIso8601String().split('T').first;
}

DateTime dateFromColumn(String value) => DateTime.parse('${value}T00:00:00Z');
