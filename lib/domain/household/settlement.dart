/// One payment that would square a household up.
class SettlementTransfer {
  const SettlementTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });

  /// The member who is behind on the shared spend.
  final String from;

  /// The member who is ahead of it.
  final String to;

  final double amount;

  @override
  String toString() => 'SettlementTransfer($from → $to: $amount)';
}

/// Who has paid what into a household's vehicles, and what it would take to
/// even it out.
///
/// Every member carries an equal share of the total — the household owns the
/// vehicles jointly, so the spend is joint too. A member who has paid more
/// than their share is owed the difference by the ones who have paid less.
class Settlement {
  const Settlement._({
    required this.spendByMember,
    required this.total,
    required this.unattributed,
    required this.fairShare,
    required this.transfers,
  });

  /// Cents-level noise: splitting 100 three ways leaves thirds behind, and a
  /// transfer of a third of a cent is not worth showing anyone.
  static const double _tolerance = 0.01;

  /// [spendByMember] holds only people who can still be paid or be owed.
  ///
  /// [unattributed] is spend whose author is gone — an account that has been
  /// deleted. It went into these vehicles, so it is part of what the household
  /// has spent, but it cannot join the split: there is nobody on the other end
  /// of a transfer. Counting it as a participant divided the share by one head
  /// too many and had everyone owing the wrong amount to a nameless row.
  ///
  /// Leaving it out of the split is also the arithmetically honest answer.
  /// Money nobody will be repaid for benefits every remaining member equally,
  /// so it cannot change who owes whom.
  factory Settlement.of({
    required Map<String, double> spendByMember,
    double unattributed = 0,
  }) {
    if (spendByMember.isEmpty) {
      return Settlement._(
        spendByMember: const {},
        total: 0,
        unattributed: unattributed,
        fairShare: 0,
        transfers: const [],
      );
    }

    final total = spendByMember.values.fold<double>(0, (sum, v) => sum + v);
    final fairShare = total / spendByMember.length;

    final creditors = <MapEntry<String, double>>[];
    final debtors = <MapEntry<String, double>>[];
    for (final entry in spendByMember.entries) {
      final balance = entry.value - fairShare;
      if (balance > _tolerance) {
        creditors.add(MapEntry(entry.key, balance));
      } else if (balance < -_tolerance) {
        debtors.add(MapEntry(entry.key, -balance));
      }
    }
    // Largest first on both sides: the fewest payments that clear the board.
    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final transfers = <SettlementTransfer>[];
    var creditorIndex = 0;
    var debtorIndex = 0;
    var owedToCreditor = creditors.isEmpty ? 0.0 : creditors.first.value;
    var owedByDebtor = debtors.isEmpty ? 0.0 : debtors.first.value;

    while (creditorIndex < creditors.length && debtorIndex < debtors.length) {
      final amount = owedToCreditor < owedByDebtor
          ? owedToCreditor
          : owedByDebtor;
      if (amount > _tolerance) {
        transfers.add(
          SettlementTransfer(
            from: debtors[debtorIndex].key,
            to: creditors[creditorIndex].key,
            amount: amount,
          ),
        );
      }
      owedToCreditor -= amount;
      owedByDebtor -= amount;
      if (owedToCreditor <= _tolerance) {
        creditorIndex++;
        if (creditorIndex < creditors.length) {
          owedToCreditor = creditors[creditorIndex].value;
        }
      }
      if (owedByDebtor <= _tolerance) {
        debtorIndex++;
        if (debtorIndex < debtors.length) {
          owedByDebtor = debtors[debtorIndex].value;
        }
      }
    }

    return Settlement._(
      spendByMember: Map.unmodifiable(spendByMember),
      total: total,
      unattributed: unattributed,
      fairShare: fairShare,
      transfers: List.unmodifiable(transfers),
    );
  }

  final Map<String, double> spendByMember;

  /// The spend the split is over: what identifiable people paid.
  final double total;

  /// Spend whose author has deleted their account. Outside the split, and
  /// shown separately so the difference between this and [householdTotal]
  /// never looks like an arithmetic mistake.
  final double unattributed;

  /// Everything that went into the household's vehicles, settled or not.
  double get householdTotal => total + unattributed;
  final double fairShare;
  final List<SettlementTransfer> transfers;

  Iterable<String> get members => spendByMember.keys;

  /// How far ahead (positive) or behind (negative) a member is. A member the
  /// household does not know reads as square rather than throwing.
  double balanceFor(String userId) {
    final spent = spendByMember[userId];
    return spent == null ? 0 : spent - fairShare;
  }

  bool get isSettled => transfers.isEmpty;
}
