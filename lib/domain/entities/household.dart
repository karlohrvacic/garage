/// The tenancy boundary: vehicles belong to a household, not to a person, so
/// every member is an equal owner of the data rather than a guest on someone
/// else's account.
class Household {
  const Household({
    required this.id,
    required this.name,
    this.currencyCode = 'EUR',
    this.distanceUnit = 'km',
    this.volumeUnit = 'liter',
    this.bundlingWindowDays = 21,
    this.bundlingWindowKm = 500,
  });

  final String id;
  final String name;
  final String currencyCode;
  final String distanceUnit;
  final String volumeUnit;
  final int bundlingWindowDays;
  final int bundlingWindowKm;
}
