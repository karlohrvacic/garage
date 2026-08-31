/// One thing that happened, reduced to whether it moved money and which way.
///
/// A record rather than an entry type: the timeline's own `TimelineItem` lives
/// in the feature layer, and the balance of a month is arithmetic that has no
/// business knowing what a fill-up is.
typedef LedgerEntry = ({double? amount, bool isIncome});

/// What a set of entries came to, and how many of them were about money.
class EntryBalance {
  const EntryBalance({required this.net, required this.transactions});

  /// Income minus spending. Negative is the ordinary case: a car costs money.
  final double net;

  /// Only the entries that carried an amount. An odometer reading and a trip
  /// are rows in the timeline but not transactions, and a fill-up whose total
  /// was never typed in is not one either.
  final int transactions;

  bool get isEmpty => transactions == 0;

  /// Whether to say "spent" rather than "received".
  ///
  /// Breaking even exactly says spent: "received 0" claims money arrived when
  /// none did.
  bool get spent => net <= 0;

  /// The figure to print beside the word, which carries the direction instead.
  double get magnitude => net.abs();
}

EntryBalance balanceOf(Iterable<LedgerEntry> entries) {
  var net = 0.0;
  var transactions = 0;
  for (final entry in entries) {
    final amount = entry.amount;
    if (amount == null) {
      continue;
    }
    transactions++;
    net += entry.isIncome ? amount : -amount;
  }
  return EntryBalance(net: net, transactions: transactions);
}
