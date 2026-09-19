/// How a fill-up, a service or a cost was paid. Null on the entry is the
/// household default, and stays null for a private garage, which is never
/// asked.
enum PaymentMethod {
  companyCard('company_card'),
  companyCash('company_cash'),

  /// Out of the driver's own pocket: what the reimbursements add up.
  ownMoney('own_money');

  const PaymentMethod(this.key);

  final String key;

  /// Null for anything unrecognised rather than a guess, the rule every
  /// stored-key enum in this app follows.
  static PaymentMethod? fromKey(String? key) {
    for (final method in values) {
      if (method.key == key) {
        return method;
      }
    }
    return null;
  }
}
