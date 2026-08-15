import '../entities/cost_entry.dart';

/// When a recurring expense comes round again, and what to call it.
class RecurringCostDue {
  const RecurringCostDue({required this.serviceTypeKey, required this.dueDate});

  final String serviceTypeKey;

  /// UTC date-only, like every domain [DateTime].
  final DateTime dueDate;
}

/// Which costs are obligations that return on a cycle rather than one-off
/// spending.
///
/// Registration and insurance are the two every household pays yearly and
/// nobody wants to be caught out by; parking, washes, and fines are simply
/// spent. The interval is the calendar year the payment covers — a household
/// that pays half-yearly can still edit the reminder it creates.
abstract final class RecurringCosts {
  static const _yearly = {
    CostCategories.registration: 'service_registration',
    CostCategories.insurance: 'service_insurance',
  };

  static RecurringCostDue? nextDue({
    required String category,
    required DateTime paidOn,
  }) {
    final serviceTypeKey = _yearly[category];
    if (serviceTypeKey == null) {
      return null;
    }
    return RecurringCostDue(
      serviceTypeKey: serviceTypeKey,
      dueDate: _oneYearOn(paidOn),
    );
  }

  /// A year later on the calendar. February 29th has no anniversary, so it
  /// falls back to the 28th rather than rolling into March.
  static DateTime _oneYearOn(DateTime date) {
    final year = date.year + 1;
    final isLeapDay = date.month == 2 && date.day == 29;
    return DateTime.utc(year, date.month, isLeapDay ? 28 : date.day);
  }
}
