import '../entities/cost_entry.dart';
import '../entities/fuel_entry.dart';
import '../entities/service_entry.dart';
import 'payment_method.dart';

/// The three tables money leaves through, as one shape.
enum MoneyEntryKind {
  fuel('fuel', 'fuel_entries'),
  service('service', 'service_entries'),
  cost('cost', 'cost_entries');

  const MoneyEntryKind(this.key, this.table);

  /// The attachment kind and the receipt reminder's word for it.
  final String key;

  /// The table a "paid back" stamp is written to.
  final String table;
}

/// A fill-up, a service or a cost, reduced to what the reimbursements and
/// the receipts check ask: when, on which car, how much, how it was paid.
class MoneyEntry {
  const MoneyEntry({
    required this.kind,
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.amount,
    this.paidWith,
    this.reimbursedAt,
  });

  final MoneyEntryKind kind;
  final String id;
  final String vehicleId;

  /// UTC date-only.
  final DateTime date;
  final double amount;
  final PaymentMethod? paidWith;
  final DateTime? reimbursedAt;

  bool get isOwnMoney => paidWith == PaymentMethod.ownMoney;

  bool get isReimbursed => reimbursedAt != null;
}

abstract final class MoneyEntries {
  /// Every entry with money on it. A fill-up with no total and a service
  /// with no cost are left out: there is nothing to pay back and nothing a
  /// receipt could be for.
  static List<MoneyEntry> of({
    required Iterable<FuelEntry> fuel,
    required Iterable<ServiceEntry> services,
    required Iterable<CostEntry> costs,
  }) {
    return [
      for (final entry in fuel)
        if (entry.total case final total?)
          MoneyEntry(
            kind: MoneyEntryKind.fuel,
            id: entry.id,
            vehicleId: entry.vehicleId,
            date: entry.date,
            amount: total,
            paidWith: entry.paidWith,
            reimbursedAt: entry.reimbursedAt,
          ),
      for (final entry in services)
        if (entry.cost case final cost?)
          MoneyEntry(
            kind: MoneyEntryKind.service,
            id: entry.id,
            vehicleId: entry.vehicleId,
            date: entry.date,
            amount: cost,
            paidWith: entry.paidWith,
            reimbursedAt: entry.reimbursedAt,
          ),
      for (final entry in costs)
        MoneyEntry(
          kind: MoneyEntryKind.cost,
          id: entry.id,
          vehicleId: entry.vehicleId,
          date: entry.date,
          amount: entry.amount,
          paidWith: entry.paidWith,
          reimbursedAt: entry.reimbursedAt,
        ),
    ];
  }
}
