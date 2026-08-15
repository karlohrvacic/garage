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
    this.trackingLevel = 'beginner',
    this.countryCode = 'HR',
  });

  final String id;
  final String name;
  final String currencyCode;
  final String distanceUnit;
  final String volumeUnit;
  final int bundlingWindowDays;
  final int bundlingWindowKm;

  /// How much detail service entries ask for: `beginner`, `intermediate`, or
  /// `advanced`. Stored language-neutral; see `TrackingLevel`.
  final String trackingLevel;

  /// ISO 3166-1 alpha-2. Decides which statutory service types the household
  /// is offered — registration and inspection cycles are national, and the
  /// app only claims the ones it has verified.
  final String countryCode;

  @override
  bool operator ==(Object other) {
    return other is Household &&
        other.id == id &&
        other.name == name &&
        other.currencyCode == currencyCode &&
        other.distanceUnit == distanceUnit &&
        other.volumeUnit == volumeUnit &&
        other.bundlingWindowDays == bundlingWindowDays &&
        other.bundlingWindowKm == bundlingWindowKm &&
        other.trackingLevel == trackingLevel &&
        other.countryCode == countryCode;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    currencyCode,
    distanceUnit,
    volumeUnit,
    bundlingWindowDays,
    bundlingWindowKm,
    trackingLevel,
    countryCode,
  );

  @override
  String toString() {
    return 'Household(id: $id, name: $name, currencyCode: $currencyCode, '
        'distanceUnit: $distanceUnit, volumeUnit: $volumeUnit, '
        'bundlingWindowDays: $bundlingWindowDays, '
        'bundlingWindowKm: $bundlingWindowKm, '
        'trackingLevel: $trackingLevel, countryCode: $countryCode)';
  }
}
