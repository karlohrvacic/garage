import 'money_entry.dart';

/// Money entries with nothing attached: what the accountant will ask for
/// and what the console asks the driver for first.
abstract final class MissingReceipts {
  /// The month's entries with no receipt, oldest first: the order a driver
  /// works through them and the order the ledger prints them.
  static List<MoneyEntry> inMonth({
    required Iterable<MoneyEntry> entries,
    required Set<String> entryIdsWithAttachments,
    required DateTime month,
  }) {
    return [
      for (final entry in entries)
        if (entry.date.year == month.year &&
            entry.date.month == month.month &&
            !entryIdsWithAttachments.contains(entry.id))
          entry,
    ]..sort((a, b) => a.date.compareTo(b.date));
  }
}
