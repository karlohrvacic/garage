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
  String get authTagline => 'Fuel and maintenance, on record.';

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
  String get authSetNewPasswordTitle => 'Set a new password';

  @override
  String get authPasswordUpdated => 'Password updated.';

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
  String get householdTitle => 'Household';

  @override
  String get householdMembers => 'Members';

  @override
  String get householdInvite => 'Invite someone';

  @override
  String householdInviteCreated(String code) {
    return 'Share this code: $code';
  }

  @override
  String get householdInviteExpires => 'Expires in 14 days';

  @override
  String get householdCopyCode => 'Copy code';

  @override
  String get householdCopied => 'Copied';

  @override
  String get householdLeave => 'Leave household';

  @override
  String get householdLeaveConfirm =>
      'Leave this household? You will lose access to its vehicles.';

  @override
  String get householdSpend => 'Shared spend';

  @override
  String get householdSpendHint =>
      'Everything logged against this household’s vehicles, by who logged it';

  @override
  String householdShareEach(String amount) {
    return 'Even share: $amount';
  }

  @override
  String get householdSettled => 'All square';

  @override
  String householdOwes(String from, String to, String amount) {
    return '$from owes $to $amount';
  }

  @override
  String get householdRemoveMember => 'Remove from household';

  @override
  String get householdRoleAdmin => 'Admin';

  @override
  String get householdRoleMember => 'Member';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsDistance => 'Distance';

  @override
  String get settingsVolume => 'Volume';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get calculatorTitle => 'Calculator';

  @override
  String get calcModeTripCost => 'Trip cost';

  @override
  String get calcModeDistance => 'Distance';

  @override
  String get calcModeConsumption => 'Consumption';

  @override
  String get calcModeRequiredFuel => 'Required fuel';

  @override
  String get calcConsumption => 'Consumption';

  @override
  String get calcResult => 'Result';

  @override
  String get stationsTitle => 'Fuel stations';

  @override
  String get stationsFuelPetrol => 'Petrol';

  @override
  String get stationsFuelDiesel => 'Diesel';

  @override
  String get stationsFuelLpg => 'LPG';

  @override
  String get stationsAttribution => 'Prices: mzoe-gor.hr (Ministry of Economy)';

  @override
  String get stationsOpenMap => 'Open in maps';

  @override
  String get stationsNoLocation => 'Location unavailable — sorted by price.';

  @override
  String get stationsFavourite => 'Favourite';

  @override
  String get stationsAvgNearby => 'Average nearby';

  @override
  String get stationsNationalAvg => 'National average';

  @override
  String get stationsEmpty => 'No stations found.';

  @override
  String get timelineTitle => 'Timeline';

  @override
  String get timelineEmpty => 'Nothing logged yet.';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsTabFillUps => 'Fill-ups';

  @override
  String get statsTabCosts => 'Costs';

  @override
  String get statsTabDistance => 'Distance';

  @override
  String get statsAllVehicles => 'All vehicles';

  @override
  String get statsThisYear => 'This year';

  @override
  String get statsPreviousYear => 'Previous year';

  @override
  String get statsThisMonth => 'This month';

  @override
  String get statsPreviousMonth => 'Previous month';

  @override
  String get statsFillUps => 'Fill-ups';

  @override
  String get statsFuelVolume => 'Fuel';

  @override
  String get statsMinFill => 'Smallest fill';

  @override
  String get statsMaxFill => 'Largest fill';

  @override
  String get statsAvgEconomy => 'Average consumption';

  @override
  String get statsBestEconomy => 'Best consumption';

  @override
  String get statsWorstEconomy => 'Worst consumption';

  @override
  String get statsTotalWithFuel => 'Costs (with fuel)';

  @override
  String get statsTotalWithoutFuel => 'Costs (without fuel)';

  @override
  String get statsFuelOnly => 'Fuel';

  @override
  String get statsLowestBill => 'Lowest bill';

  @override
  String get statsHighestBill => 'Highest bill';

  @override
  String get statsBestFuelPrice => 'Best fuel price';

  @override
  String get statsWorstFuelPrice => 'Worst fuel price';

  @override
  String get statsAvgCost => 'Average cost';

  @override
  String get statsAvgPerDay => 'Average per day';

  @override
  String get statsAvgPerMonth => 'Average per month';

  @override
  String get statsCategories => 'Categories';

  @override
  String get statsDistanceTracked => 'Distance tracked';

  @override
  String get statsLastOdometer => 'Last odometer';

  @override
  String get statsCharts => 'Charts';

  @override
  String get statsEmpty => 'Not enough data yet.';

  @override
  String get commonEdit => 'Edit';

  @override
  String get confirmDeleteTitle => 'Delete entry?';

  @override
  String get confirmDeleteBody => 'This cannot be undone.';

  @override
  String get settingsImportFuelio => 'Import from Fuelio';

  @override
  String get settingsImportFuelioHint =>
      'Pick the CSV backup exported by Fuelio. Fill-ups, costs, services, and recurring reminders are imported; re-importing skips rows that already exist.';

  @override
  String get settingsImportVehicle => 'Import into vehicle';

  @override
  String get settingsImportRun => 'Import';

  @override
  String settingsImportDone(int fills, int services, int costs, int reminders) {
    return 'Imported $fills fill-ups, $services services, $costs costs, $reminders reminders.';
  }

  @override
  String settingsImportSkipped(String titles) {
    return 'Not recognised, skipped: $titles';
  }

  @override
  String get vehicleCurrentOdometer => 'Current odometer';

  @override
  String get vehicleUpdateOdometer => 'Update odometer';

  @override
  String get dashboardRecent => 'Recent activity';

  @override
  String get reportsTitle => 'Create report';

  @override
  String get reportSellers => 'Seller\'s report';

  @override
  String get reportMaintenance => 'Maintenance history';

  @override
  String get reportAnnual => 'Annual summary';

  @override
  String get costsTitle => 'Costs';

  @override
  String get costAdd => 'Add cost';

  @override
  String get costAmount => 'Amount';

  @override
  String get costCategory => 'Category';

  @override
  String get costDate => 'Date';

  @override
  String get costRemindNextYear => 'Remind me when it is due again';

  @override
  String get costsEmpty => 'No costs logged yet.';

  @override
  String get costAmountRequired => 'Enter an amount.';

  @override
  String get costCategoryRegistration => 'Registration';

  @override
  String get costCategoryInsurance => 'Insurance';

  @override
  String get costCategoryParking => 'Parking';

  @override
  String get costCategoryToll => 'Tolls';

  @override
  String get costCategoryWash => 'Car wash';

  @override
  String get costCategoryFine => 'Fine';

  @override
  String get costCategoryEquipment => 'Equipment';

  @override
  String get costCategoryOther => 'Other';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsBundling => 'Maintenance bundling';

  @override
  String get settingsBundlingWindowDays => 'Group items within (days)';

  @override
  String get settingsBundlingWindowKm => 'Group items within (distance)';

  @override
  String get settingsBundlingHint =>
      'Wider settings suggest more combined visits';

  @override
  String get settingsCountry => 'Country';

  @override
  String get settingsCountryHint =>
      'Which registration and inspection items are offered';

  @override
  String get countryElsewhere => 'Elsewhere';

  @override
  String get settingsTracking => 'Detail level';

  @override
  String get settingsTrackingHint => 'How much a service entry asks for';

  @override
  String get trackingBeginner => 'Basic';

  @override
  String get trackingIntermediate => 'Detailed';

  @override
  String get trackingAdvanced => 'Full';

  @override
  String get serviceDiy => 'Done at home';

  @override
  String get servicePartsCost => 'Parts';

  @override
  String get serviceLaborCost => 'Labour';

  @override
  String get servicePartsDetail => 'Parts used';

  @override
  String get serviceWarrantyUntil => 'Warranty until';

  @override
  String get serviceFaultCodes => 'Fault codes';

  @override
  String get serviceFaultCodesHint => 'e.g. P0301, P0171';

  @override
  String get serviceMeasurements => 'Readings';

  @override
  String get measurementBrakePadFront => 'Front brake pads';

  @override
  String get measurementBrakePadRear => 'Rear brake pads';

  @override
  String get measurementBrakeDiscFront => 'Front discs';

  @override
  String get measurementTreadFrontLeft => 'Tread, front left';

  @override
  String get measurementTreadFrontRight => 'Tread, front right';

  @override
  String get measurementTreadRearLeft => 'Tread, rear left';

  @override
  String get measurementTreadRearRight => 'Tread, rear right';

  @override
  String get measurementBatteryVolts => 'Battery voltage';

  @override
  String get measurementBatteryCca => 'Battery CCA';

  @override
  String get settingsData => 'Your data';

  @override
  String get settingsExport => 'Export as CSV';

  @override
  String get settingsExportDone => 'Export ready';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteConfirmTitle => 'Delete your account?';

  @override
  String get settingsDeleteConfirmBody =>
      'This permanently deletes your account. If you are the last member of your household, its vehicles and all their history are deleted too. This cannot be undone.';

  @override
  String get settingsDeleteConfirmAction => 'Delete permanently';

  @override
  String get apiTitle => 'API access';

  @override
  String get apiHint =>
      'A read-only feed of this household’s data, for your own scripts and dashboards';

  @override
  String get apiNewKey => 'New key';

  @override
  String get apiKeyName => 'What is it for?';

  @override
  String get apiKeyCreate => 'Create';

  @override
  String get apiKeyOnce => 'Copy this key now — it is not shown again';

  @override
  String get apiKeyRevoke => 'Revoke';

  @override
  String get apiKeyRevoked => 'Revoked';

  @override
  String get apiKeyNeverUsed => 'Never used';

  @override
  String apiKeyLastUsed(String date) {
    return 'Last used $date';
  }

  @override
  String get apiWebhooks => 'Webhooks';

  @override
  String get apiWebhooksHint => 'Called when something is logged or comes due';

  @override
  String get apiWebhookAdd => 'Add webhook';

  @override
  String get apiWebhookUrl => 'URL';

  @override
  String get apiWebhookInvalid => 'Enter an https:// address';

  @override
  String get apiWebhookAddAction => 'Add';

  @override
  String apiWebhookFailing(int status) {
    return 'Last delivery failed ($status)';
  }

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get vehiclesTitle => 'Vehicles';

  @override
  String get vehiclesEmpty => 'Add your first vehicle to start logging';

  @override
  String get vehiclesAdd => 'Add vehicle';

  @override
  String get vehicleNickname => 'Name';

  @override
  String get vehicleNameRequired => 'Enter a name';

  @override
  String get vehicleMake => 'Make';

  @override
  String get vehicleModel => 'Model';

  @override
  String get vehicleYear => 'Year';

  @override
  String get vehiclePhoto => 'Photo';

  @override
  String get vehiclePhotoAdd => 'Add a photo';

  @override
  String get vehiclePhotoReplace => 'Replace photo';

  @override
  String get vehiclePlate => 'Plate';

  @override
  String get vehicleVin => 'VIN';

  @override
  String get vehicleDecodeVin => 'Look up';

  @override
  String get vehicleVinNotFound => 'That VIN could not be looked up';

  @override
  String get vehicleVinDecoded => 'Filled in from the VIN registry';

  @override
  String get vehicleFuelType => 'Fuel type';

  @override
  String get vehicleOdometer => 'Current odometer';

  @override
  String get vehicleTankCapacity => 'Tank capacity';

  @override
  String get vehicleTankCapacityHint =>
      'Optional — flags a fill-up bigger than the tank';

  @override
  String get vehicleArchive => 'Archive';

  @override
  String get vehicleArchived => 'Archived';

  @override
  String get vehicleSearch => 'Search vehicles';

  @override
  String get recallsTitle => 'Safety recalls';

  @override
  String get recallsNone => 'No recalls found for this make, model, and year';

  @override
  String get recallsCheck => 'Check for recalls';

  @override
  String get recallsCaveat =>
      'From the US NHTSA registry — confirm with a dealer for a European vehicle';

  @override
  String get recallsNeedsDetails =>
      'Add the make, model, and year to check for recalls';

  @override
  String get tyresTitle => 'Tyre sets';

  @override
  String get tyresEmpty => 'Add the sets this vehicle runs on';

  @override
  String get tyresAdd => 'Add a set';

  @override
  String get tyresName => 'Name';

  @override
  String get tyresSeason => 'Season';

  @override
  String get tyresSize => 'Size';

  @override
  String get tyresStorage => 'Stored at';

  @override
  String get tyresFitted => 'On the car';

  @override
  String get tyresFit => 'Fit to car';

  @override
  String get tyresRetire => 'Retire';

  @override
  String get tyresRetired => 'Retired';

  @override
  String get tyresAddReading => 'Record tread';

  @override
  String get tyresTread => 'Tread';

  @override
  String get tyresTreadNone => 'No tread recorded';

  @override
  String get tyresBelowLegal => 'At or below the 1.6 mm legal minimum';

  @override
  String get tyresFrontLeft => 'Front left';

  @override
  String get tyresFrontRight => 'Front right';

  @override
  String get tyresRearLeft => 'Rear left';

  @override
  String get tyresRearRight => 'Rear right';

  @override
  String get tyreSeasonSummer => 'Summer';

  @override
  String get tyreSeasonWinter => 'Winter';

  @override
  String get tyreSeasonAll => 'All-season';

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
  String get vehicleTrendNeedsMore =>
      'Log more full-tank fills to see the trend';

  @override
  String get plannerRestoreExcluded => 'Restore excluded items';

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
  String get fuelEnergy => 'Charge (kWh)';

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
  String get attachmentsTitle => 'Attachments';

  @override
  String get attachmentsAdd => 'Attach a receipt or document';

  @override
  String get attachmentsSaveFirst =>
      'Save the entry first, then attach files to it';

  @override
  String get fuelNotes => 'Notes';

  @override
  String get fuelAverage => 'Average';

  @override
  String get fuelNeedTwoValues =>
      'Enter at least two of volume, price, and total';

  @override
  String get fuelOdometerRequired => 'Enter the odometer reading';

  @override
  String fuelOdometerTooLow(String previous) {
    return 'Lower than the previous reading of $previous';
  }

  @override
  String fuelOdometerTooHigh(String next) {
    return 'Higher than the next reading of $next';
  }

  @override
  String fuelOdometerLast(String previous) {
    return 'Last reading: $previous';
  }

  @override
  String fuelVolumeOverTank(String capacity) {
    return 'More than the tank holds ($capacity)';
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
  String get maintenanceOneTime => 'One-time reminder';

  @override
  String get maintenanceDueDateField => 'Due date';

  @override
  String get maintenanceDueKmField => 'Due at odometer';

  @override
  String get maintenanceOneTimeNeedsTarget => 'Set a due date or odometer.';

  @override
  String maintenancePreviously(String details) {
    return 'Previously: $details';
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
  String get maintenanceRuleServiceType => 'Service type';

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
  String get serviceIssue => 'Fault noted';

  @override
  String get serviceDiagnostics => 'Diagnostics';

  @override
  String get serviceModification => 'Modification';

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
  String notificationDueTitle(String service) {
    return '$service is due';
  }

  @override
  String notificationBundleTitle(int count) {
    return '$count items due together';
  }

  @override
  String get notificationBundleBody => 'Book one visit and save a second trip';

  @override
  String bundleSuggestionTitle(int count) {
    return 'Bundle $count items into one visit';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline =>
      'Every car in the household in one place: fuel, servicing, costs, and what falls due next.';

  @override
  String aboutVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get aboutPromises => 'What this app promises';

  @override
  String get aboutPromiseFree =>
      'No ads, no subscription, no locked features. What you see is the whole app.';

  @override
  String get aboutPromiseData =>
      'Your records are yours. Export everything as CSV whenever you like — it opens in any spreadsheet.';

  @override
  String get aboutPromiseLeave =>
      'Leaving is deliberately easy. Delete your account and every record goes with it.';

  @override
  String get aboutPromisePrivacy =>
      'No tracking, no analytics, no profiles. What you log stays inside your household.';

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutLicences => 'Open source licences';

  @override
  String get aboutLicencesHint => 'The libraries this app is built on';
}
