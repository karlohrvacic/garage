/// One calendar month's worth of items, in the order they were given.
class MonthGroup<T> {
  const MonthGroup({required this.month, required this.items});

  /// UTC, day-of-month 1 — a calendar month with no day of its own, the same
  /// convention [DateTime.utc] with two arguments already gives.
  final DateTime month;
  final List<T> items;
}

/// Buckets [items] into consecutive runs sharing a calendar month, without
/// sorting them first.
///
/// Every caller already has the order it wants — newest first for a log,
/// oldest first nowhere in this app yet, but the point stands — and imposing
/// a sort here would silently override that. A caller whose input is not
/// grouped by month to begin with gets exactly what that implies: two
/// separate groups for two separate visits to the same month, because that is
/// what its own list order says happened.
abstract final class MonthGrouping {
  static List<MonthGroup<T>> of<T>(List<T> items, DateTime Function(T) dateOf) {
    final groups = <MonthGroup<T>>[];
    DateTime? currentMonth;
    List<T>? current;
    for (final item in items) {
      final date = dateOf(item);
      final month = DateTime.utc(date.year, date.month);
      if (currentMonth == null || month != currentMonth) {
        currentMonth = month;
        current = [];
        groups.add(MonthGroup(month: month, items: current));
      }
      current!.add(item);
    }
    return groups;
  }
}
