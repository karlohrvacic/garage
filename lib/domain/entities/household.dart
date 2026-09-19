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
    this.settlementEnabled = false,
    this.plan = 'free',
    this.planUntil,
    this.companyName,
    this.companyOib,
    this.companyAddress,
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

  /// Whether to work out who owes whom.
  ///
  /// Off unless a household asks for it. The settlement divides every logged
  /// expense equally between members, which suits people sharing a car and
  /// keeping separate money — and misreads a couple with joint finances as one
  /// partner owing the other half of everything, on the strength of who
  /// happened to log it.
  final bool settlementEnabled;

  /// `free` or `company`. Written only by the server — the column privilege
  /// (migration 0080) keeps every signed-in user off it — and read here to
  /// decide what the app offers. A company garage that lapses keeps the
  /// word and gets a [planUntil] in the past.
  final String plan;

  /// When the company plan ends, or null for no end.
  final DateTime? planUntil;

  /// What the accountant pack and, later, the travel order print in the
  /// header. Null for a private garage, which has no letterhead.
  final String? companyName;
  final String? companyOib;
  final String? companyAddress;

  /// Whether this garage has the company plan at all, lapsed or not. A
  /// lapsed garage keeps every screen (decision 155); [companyEnabledAt]
  /// is what gates adding a car above the cap, a driver and an assignment.
  bool get isOnCompanyPlan => plan == 'company';

  bool companyEnabledAt(DateTime now) =>
      isOnCompanyPlan && (planUntil == null || planUntil!.isAfter(now));

  /// Whether the garage had the plan and it has ended: what tells "the
  /// plan ended on {date}" apart from the free cap, which a garage that
  /// never had a plan hits without any date to name.
  bool companyLapsedAt(DateTime now) =>
      isOnCompanyPlan && !companyEnabledAt(now);

  /// How many active cars a free garage holds: `free_vehicle_limit()` in
  /// SQL (migration 0080).
  static const freeVehicleLimit = 5;

  /// Whether one more car may become active here, with [activeVehicles]
  /// already so. The same rule as `can_add_vehicle`, which the vehicles
  /// insert policy applies with a bare permission error and which the
  /// unarchive guard, a redeemed sale and a merge refuse by name (P0008):
  /// the app asks first so it can say which sentence applies. Archived cars
  /// do not count, as they do not there.
  bool canAddVehicleAt(DateTime now, {required int activeVehicles}) =>
      companyEnabledAt(now) || activeVehicles < freeVehicleLimit;

  /// Whether every car in [archived] — one flag per car, in the order they
  /// would be created — is admitted with [activeVehicles] already there.
  /// The database asks [canAddVehicleAt] before each insert and only an
  /// active car raises the count, so a restore or an import is checked the
  /// way its inserts would be, before the first one lands: a refusal
  /// halfway through would leave the garage with some of the cars and none
  /// of the entries, which is the state a restore exists to end.
  bool canAddVehiclesAt(
    DateTime now, {
    required int activeVehicles,
    required Iterable<bool> archived,
  }) {
    var active = activeVehicles;
    for (final isArchived in archived) {
      if (!canAddVehicleAt(now, activeVehicles: active)) {
        return false;
      }
      if (!isArchived) {
        active++;
      }
    }
    return true;
  }

  /// One field at a time. A rename that rebuilt the row by hand omitted
  /// `settlementEnabled` and quietly switched shared costs off, which is a
  /// financial setting disappearing on an unrelated action.
  ///
  /// The plan travels unchanged: nothing in the app writes it. The three
  /// letterhead fields take a wrapper so they can be cleared, the way
  /// `CostEntry.copyWith` clears a vignette — a field emptied on the console
  /// has to reach the database as null, since an empty OIB fails its check.
  Household copyWith({
    String? name,
    String? currencyCode,
    String? distanceUnit,
    String? volumeUnit,
    int? bundlingWindowDays,
    int? bundlingWindowKm,
    String? trackingLevel,
    String? countryCode,
    bool? settlementEnabled,
    Object? companyName = _unset,
    Object? companyOib = _unset,
    Object? companyAddress = _unset,
  }) {
    return Household(
      id: id,
      name: name ?? this.name,
      currencyCode: currencyCode ?? this.currencyCode,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      volumeUnit: volumeUnit ?? this.volumeUnit,
      bundlingWindowDays: bundlingWindowDays ?? this.bundlingWindowDays,
      bundlingWindowKm: bundlingWindowKm ?? this.bundlingWindowKm,
      trackingLevel: trackingLevel ?? this.trackingLevel,
      countryCode: countryCode ?? this.countryCode,
      settlementEnabled: settlementEnabled ?? this.settlementEnabled,
      plan: plan,
      planUntil: planUntil,
      companyName: identical(companyName, _unset)
          ? this.companyName
          : companyName as String?,
      companyOib: identical(companyOib, _unset)
          ? this.companyOib
          : companyOib as String?,
      companyAddress: identical(companyAddress, _unset)
          ? this.companyAddress
          : companyAddress as String?,
    );
  }

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
        other.countryCode == countryCode &&
        other.settlementEnabled == settlementEnabled &&
        other.plan == plan &&
        other.planUntil == planUntil &&
        other.companyName == companyName &&
        other.companyOib == companyOib &&
        other.companyAddress == companyAddress;
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
    settlementEnabled,
    plan,
    planUntil,
    companyName,
    companyOib,
    companyAddress,
  );

  @override
  String toString() {
    return 'Household(id: $id, name: $name, currencyCode: $currencyCode, '
        'distanceUnit: $distanceUnit, volumeUnit: $volumeUnit, '
        'bundlingWindowDays: $bundlingWindowDays, '
        'bundlingWindowKm: $bundlingWindowKm, '
        'trackingLevel: $trackingLevel, countryCode: $countryCode, '
        'settlementEnabled: $settlementEnabled, plan: $plan, '
        'planUntil: $planUntil, companyName: $companyName)';
  }
}

/// A private sentinel so `copyWith` can tell "not passed" from "passed null".
const _unset = Object();
