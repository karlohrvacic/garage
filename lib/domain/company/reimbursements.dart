import '../entities/vehicle_assignment.dart';
import 'assignment_resolution.dart';
import 'money_entry.dart';

/// What one driver is owed for one month.
class ReimbursementLine {
  const ReimbursementLine({
    required this.driverId,
    required this.month,
    required this.entries,
  });

  /// Null for entries on days nobody had the car: named on the screen as
  /// such, never folded into somebody's total.
  final String? driverId;

  /// UTC, day-of-month 1.
  final DateTime month;
  final List<MoneyEntry> entries;

  double get total => entries.fold(0, (sum, entry) => sum + entry.amount);
}

/// The inverse of the household settlement, which a fleet switches off:
/// drivers do not owe the company, the company owes whoever paid out of
/// their own pocket.
abstract final class Reimbursements {
  /// Own-money entries not yet paid back, per driver per month, the driver
  /// resolved from the assignment on the entry's date. Newest month first.
  static List<ReimbursementLine> outstanding({
    required Iterable<MoneyEntry> entries,
    required Iterable<VehicleAssignment> assignments,
  }) {
    final grouped = <(String?, DateTime), List<MoneyEntry>>{};
    for (final entry in entries) {
      if (!entry.isOwnMoney || entry.isReimbursed) {
        continue;
      }
      final driver = AssignmentResolution.driverOn(
        assignments,
        vehicleId: entry.vehicleId,
        on: entry.date,
      );
      final month = DateTime.utc(entry.date.year, entry.date.month);
      grouped.putIfAbsent((driver, month), () => []).add(entry);
    }
    return [
      for (final MapEntry(key: (driver, month), value: lines)
          in grouped.entries)
        ReimbursementLine(
          driverId: driver,
          month: month,
          entries: lines..sort((a, b) => a.date.compareTo(b.date)),
        ),
    ]..sort((a, b) {
      final byMonth = b.month.compareTo(a.month);
      return byMonth != 0
          ? byMonth
          : (a.driverId ?? '').compareTo(b.driverId ?? '');
    });
  }
}
