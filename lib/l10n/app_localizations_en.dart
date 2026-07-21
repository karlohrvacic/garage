// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Garage';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEmpty => 'Nothing here yet';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNoConnection =>
      'No connection. Check your network and retry.';

  @override
  String get errorPermission => 'You do not have access to that.';

  @override
  String get errorNotFound => 'That could not be found.';

  @override
  String get errorConflict => 'That already exists.';

  @override
  String get errorExpired => 'That invite code has expired.';

  @override
  String get errorAlreadyUsed => 'That invite code has already been used.';

  @override
  String get errorAuth => 'Sign-in failed. Check your email and password.';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authSignUpTitle => 'Create account';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authDisplayName => 'Your name';

  @override
  String get authSignInAction => 'Sign in';

  @override
  String get authSignUpAction => 'Create account';

  @override
  String get authNoAccount => 'No account? Create one';

  @override
  String get authHaveAccount => 'Already have an account? Sign in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetSent => 'Check your email for a reset link.';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authInvalidEmail => 'Enter a valid email address';

  @override
  String get authPasswordTooShort => 'Use at least 8 characters';

  @override
  String get authNameRequired => 'Enter your name';

  @override
  String get onboardingTitle => 'Set up your garage';

  @override
  String get onboardingCreateTitle => 'Create a household';

  @override
  String get onboardingCreateHint =>
      'Everyone you invite shares these vehicles';

  @override
  String get onboardingHouseholdName => 'Household name';

  @override
  String get onboardingCreateAction => 'Create';

  @override
  String get onboardingJoinTitle => 'Join with a code';

  @override
  String get onboardingJoinHint =>
      'Ask a member for their 8-character invite code';

  @override
  String get onboardingInviteCode => 'Invite code';

  @override
  String get onboardingJoinAction => 'Join';

  @override
  String get onboardingNameRequired => 'Enter a name';

  @override
  String get onboardingCodeInvalid => 'Enter the 8-character code';

  @override
  String get onboardingSignOut => 'Sign out';

  @override
  String get vehiclesTitle => 'Vehicles';

  @override
  String get vehiclesEmpty => 'Add your first vehicle to start logging';

  @override
  String get vehiclesAdd => 'Add vehicle';

  @override
  String get vehicleNickname => 'Name';

  @override
  String get vehicleMake => 'Make';

  @override
  String get vehicleModel => 'Model';

  @override
  String get vehicleYear => 'Year';

  @override
  String get vehiclePlate => 'Plate';

  @override
  String get vehicleVin => 'VIN';

  @override
  String get vehicleFuelType => 'Fuel type';

  @override
  String get vehicleOdometer => 'Current odometer';

  @override
  String get vehicleArchive => 'Archive';

  @override
  String get vehicleArchived => 'Archived';

  @override
  String get vehicleSearch => 'Search vehicles';

  @override
  String get vehicleTabEconomy => 'Economy';

  @override
  String get vehicleTabMaintenance => 'Maintenance';

  @override
  String get vehicleTabHistory => 'History';

  @override
  String get vehicleEdit => 'Edit vehicle';

  @override
  String get vehicleNoEconomyYet => 'Log two full-tank fills to see economy';

  @override
  String get vehicleNoHistoryYet => 'No services logged yet';

  @override
  String vehicleLastService(String date) {
    return 'Last service $date';
  }

  @override
  String get fuelPetrol => 'Petrol';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelLpg => 'LPG';

  @override
  String get fuelElectric => 'Electric';

  @override
  String get fuelHybrid => 'Hybrid';

  @override
  String get fuelTitle => 'Fuel';

  @override
  String get fuelEmpty => 'Log a fill-up to start tracking economy';

  @override
  String get fuelAdd => 'Add fill-up';

  @override
  String get fuelDate => 'Date';

  @override
  String get fuelOdometer => 'Odometer';

  @override
  String get fuelVolume => 'Volume';

  @override
  String get fuelPricePerUnit => 'Price per unit';

  @override
  String get fuelTotal => 'Total';

  @override
  String get fuelFullTank => 'Filled to full';

  @override
  String get fuelFullTankHint => 'Economy is calculated between full tanks';

  @override
  String get fuelMissedFill => 'I missed logging a fill before this one';

  @override
  String get fuelMissedFillHint =>
      'Breaks the calculation chain so no wrong figure is shown';

  @override
  String get fuelStation => 'Station';

  @override
  String get fuelNotes => 'Notes';

  @override
  String get fuelAverage => 'Average';

  @override
  String get fuelNeedTwoValues =>
      'Enter at least two of volume, price, and total';

  @override
  String fuelOdometerTooLow(String previous) {
    return 'Lower than the previous reading of $previous';
  }

  @override
  String get fuelEconomyUnavailable =>
      'Not enough full-tank fills to calculate';

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get maintenanceEmpty =>
      'Add an interval to start tracking what is due';

  @override
  String get maintenanceAddRule => 'Add interval';

  @override
  String get maintenanceLogService => 'Log service';

  @override
  String get maintenanceIntervalKm => 'Every (distance)';

  @override
  String get maintenanceIntervalMonths => 'Every (months)';

  @override
  String get maintenanceIntervalHint =>
      'Set either or both. Whichever comes first wins.';

  @override
  String maintenanceDueAt(String odometer) {
    return 'Due at $odometer';
  }

  @override
  String maintenanceDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get maintenanceNeedsInterval => 'Set a distance or a time interval';

  @override
  String get maintenanceServiceDate => 'Date';

  @override
  String get maintenanceServiceCost => 'Cost';

  @override
  String get maintenanceServiceShop => 'Shop';

  @override
  String get maintenanceServiceItems => 'What was done';

  @override
  String get maintenanceCalendar => 'Calendar';

  @override
  String get maintenanceList => 'List';

  @override
  String get serviceOilChange => 'Oil change';

  @override
  String get serviceOilFilter => 'Oil filter';

  @override
  String get serviceAirFilter => 'Air filter';

  @override
  String get serviceCabinFilter => 'Cabin filter';

  @override
  String get serviceSparkPlugs => 'Spark plugs';

  @override
  String get serviceBrakeFluid => 'Brake fluid';

  @override
  String get serviceBrakePadsFront => 'Front brake pads';

  @override
  String get serviceBrakePadsRear => 'Rear brake pads';

  @override
  String get serviceTimingBelt => 'Timing belt';

  @override
  String get serviceCoolant => 'Coolant';

  @override
  String get serviceTransmissionOil => 'Transmission oil';

  @override
  String get serviceTireRotation => 'Tire rotation';

  @override
  String get serviceTireSwapSeasonal => 'Seasonal tire swap';

  @override
  String get serviceBattery => 'Battery';

  @override
  String get serviceWipers => 'Wiper blades';

  @override
  String get serviceRegistration => 'Registration';

  @override
  String get serviceTechnicalInspection => 'Technical inspection';

  @override
  String get serviceInsurance => 'Insurance';

  @override
  String get maintenanceStateUpcoming => 'Upcoming';

  @override
  String get maintenanceStateDue => 'Due';

  @override
  String get maintenanceStateOverdue => 'Overdue';

  @override
  String get dashboardTitle => 'Garage';

  @override
  String get plannerTitle => 'Planner';

  @override
  String get plannerRunway => 'Next 12 weeks';

  @override
  String get plannerEmpty => 'Nothing due in the next 12 weeks';

  @override
  String get plannerOverdueNote =>
      'Overdue items are shown at today, because that is when they need doing';

  @override
  String plannerWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get dashboardNoBundles => 'Nothing to bundle right now';

  @override
  String get dashboardDueSoonest => 'Due soonest';

  @override
  String dashboardVehicleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vehicles',
      one: '1 vehicle',
    );
    return '$_temp0';
  }

  @override
  String bundleVisitOn(String date) {
    return 'One visit on $date';
  }

  @override
  String bundleSpanDays(int days) {
    return '$days days apart';
  }

  @override
  String get bundleExclude => 'Not this one';

  @override
  String get bundleExplain =>
      'These fall due close together — doing them in one visit saves a second trip';

  @override
  String bundleSuggestionTitle(int count) {
    return 'Bundle $count items into one visit';
  }
}
