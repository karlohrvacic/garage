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
  String get commonShare => 'Share';

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
  String get errorEmailNotConfirmed =>
      'Confirm your email address first. Check your inbox for the link we sent when you signed up.';

  @override
  String get authWhatIsThis => 'What Garage does';

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
  String get authConfirmEmailTitle => 'Check your email';

  @override
  String authConfirmEmailBody(String email) {
    return 'We sent a confirmation link to $email. Open it, then come back and sign in.';
  }

  @override
  String get authConfirmEmailAction => 'Back to sign in';

  @override
  String get authNoAccount => 'No account? Create one';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authResetSent => 'Check your email for a reset link.';

  @override
  String get authLinkFailed =>
      'That link has expired or was already used. Sign in below, or create the account again.';

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
  String get onboardingCreateTitle => 'Create a garage';

  @override
  String get onboardingCreateHint =>
      'Everyone you invite shares these vehicles';

  @override
  String get onboardingHouseholdName => 'Garage name';

  @override
  String get onboardingCreateAction => 'Create';

  @override
  String get onboardingJoinTitle => 'Join with a code';

  @override
  String get onboardingJoinHint =>
      'Ask someone in the garage for their 8-character invite code';

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
  String get joinTitle => 'Join a garage';

  @override
  String get joinInvited =>
      'You have been invited to share a garage. Sign in, or create an account, and you will join with this invite.';

  @override
  String get joinJoining => 'Joining…';

  @override
  String get joinDone =>
      'You are in. Everything the garage logs is now yours too.';

  @override
  String get joinOpenGarage => 'Open my garage';

  @override
  String get householdShareInvite => 'Share invite link';

  @override
  String get householdInviteLinkCopied => 'Invite link copied';

  @override
  String get householdTitle => 'Garage';

  @override
  String get householdMembers => 'Members';

  @override
  String get householdInvite => 'Invite someone';

  @override
  String get householdCopyCode => 'Copy code';

  @override
  String get householdCopied => 'Copied';

  @override
  String get householdLeave => 'Leave garage';

  @override
  String get householdLeaveConfirm =>
      'Leave this garage? You will lose access to its vehicles.';

  @override
  String get householdSpend => 'Shared spend';

  @override
  String get householdSpendHint =>
      'Everything logged against this garage’s vehicles, by whoever logged it';

  @override
  String householdUnattributed(String amount) {
    return 'From a deleted account: $amount';
  }

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
  String get householdRemoveMember => 'Remove from garage';

  @override
  String get householdRoleAdmin => 'Admin';

  @override
  String get householdRoleMember => 'Member';

  @override
  String get settingsUnits => 'Units';

  @override
  String get settingsUnitsHint => 'How distances, volumes and prices are shown';

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
  String get calcFuelAvailable => 'Fuel in the tank';

  @override
  String get calcFuelUsed => 'Fuel used';

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
  String stationsOutOfRange(String distance) {
    return 'Fuel prices come from the Croatian ministry\'s open data, so this only helps inside Croatia. The nearest station on record is $distance away.';
  }

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
  String get commonVehicle => 'Vehicle';

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
  String get statsEmpty => 'Not enough data yet.';

  @override
  String get reminderLogIt => 'Log it as done';

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
  String get dashboardRecent => 'Recent activity';

  @override
  String get dashboardTotalSpent => 'Total spent';

  @override
  String calendarNothingOn(String date) {
    return 'Nothing due on $date';
  }

  @override
  String get reportsNotSaved => 'Report not saved';

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
  String get costCategoryVignette => 'Vignette';

  @override
  String get countryAustria => 'Austria';

  @override
  String get countryBulgaria => 'Bulgaria';

  @override
  String get countryCzechia => 'Czechia';

  @override
  String get countryHungary => 'Hungary';

  @override
  String get countryRomania => 'Romania';

  @override
  String get countrySlovakia => 'Slovakia';

  @override
  String get countrySlovenia => 'Slovenia';

  @override
  String get countrySwitzerland => 'Switzerland';

  @override
  String fuelAtThePump(String station, String distance) {
    return 'Taken from $station, $distance away — change it if you paid a different price';
  }

  @override
  String get costVignetteCountry => 'Country';

  @override
  String get costVignetteValidity => 'Valid for';

  @override
  String get costVignetteValidityDay1 => '1 day';

  @override
  String get costVignetteValidityDays7 => '7 days';

  @override
  String get costVignetteValidityDays10 => '10 days';

  @override
  String get costVignetteValidityDays30 => '30 days';

  @override
  String get costVignetteValidityMonths2 => '2 months';

  @override
  String get costVignetteValidityDays60 => '60 days';

  @override
  String get costVignetteValidityYear => '1 year';

  @override
  String costVignetteBuy(String operator) {
    return 'Buy from $operator';
  }

  @override
  String costVignetteExpires(String date) {
    return 'Valid through $date';
  }

  @override
  String get costVignetteRemind => 'Remind me on the last valid day';

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
      'Items due close together are suggested as one visit';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsRemindersThisDevice => 'Only this device is notified';

  @override
  String get settingsRemindersThisDeviceHint =>
      'Each phone schedules its own reminders, so somebody who did not set one up will not hear about it.';

  @override
  String get settingsRemindersEveryone => 'Everyone in this garage is notified';

  @override
  String get settingsRemindersEveryoneHint =>
      'Reminders are sent from the server, so every member gets them — not only the device that set them up.';

  @override
  String get settingsRemindersSchedule =>
      'Sent 30 days and 7 days before, and whenever a reading brings one within 500 km';

  @override
  String get settingsRemindersScheduleDevice =>
      'This device sends them at 9:00 in the morning';

  @override
  String get settingsRemindersScheduleServer =>
      'The server sends them early each morning';

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
  String get settingsTrackingHint => 'How much detail a service entry asks for';

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
      'This permanently deletes your account. If you are the last member of your garage, its vehicles and all their history are deleted too. This cannot be undone.';

  @override
  String get settingsDeleteConfirmAction => 'Delete permanently';

  @override
  String get apiTitle => 'API access';

  @override
  String get apiHint =>
      'A read-only feed of this garage’s data, for your own scripts and dashboards';

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
  String get vehicleArchived =>
      'Archived. It keeps its history and stays off the lists.';

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
  String get tyresFitted => 'On the vehicle';

  @override
  String get tyresFit => 'Fit to vehicle';

  @override
  String get tyresRetire => 'Retire';

  @override
  String get tyresRetireConfirmTitle => 'Retire this set?';

  @override
  String get tyresRetireConfirmBody =>
      'It stays on the list with its readings, and stops being offered to fit.';

  @override
  String get tyresDelete => 'Delete set';

  @override
  String get tyresDeleteConfirmTitle => 'Delete this set?';

  @override
  String get tyresDeleteConfirmBody =>
      'The set and every tread reading on it go with it. This cannot be undone.';

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
  String get vehicleTabMaintenance => 'Service';

  @override
  String get vehicleTabHistory => 'History';

  @override
  String get vehicleRestore => 'Restore';

  @override
  String get vehicleRestored => 'Back in the garage.';

  @override
  String get vehicleDelete => 'Delete vehicle';

  @override
  String get vehicleDeleteTitle => 'Delete this vehicle?';

  @override
  String get vehicleDeleteBody =>
      'Every fill-up, service, cost, reading and document logged against it goes too, and none of it can be recovered. Archive it instead to keep the history.';

  @override
  String get vehiclesArchivedSection => 'Archived';

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
  String get fuelCostPerDistance => 'Fuel cost';

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
    return 'at $odometer';
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
  String maintenanceOtherDeadlineByDate(String date) {
    return 'By date not until $date';
  }

  @override
  String maintenanceOtherDeadlineByDistance(String date) {
    return 'By distance not until $date';
  }

  @override
  String maintenanceRateMeasured(String rate) {
    return 'Estimated from $rate/day over the last 3 months';
  }

  @override
  String maintenanceRateAssumed(String rate) {
    return 'Assuming $rate/day — no odometer history to measure';
  }

  @override
  String maintenanceCostForItems(String amount, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount for $count items',
      one: '$amount for $count item',
    );
    return '$_temp0';
  }

  @override
  String maintenancePreviously(String details) {
    return 'Previously: $details';
  }

  @override
  String maintenanceDueOn(String date) {
    return 'Due $date';
  }

  @override
  String maintenanceExpectedOn(String date) {
    return 'Expected $date';
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
  String get serviceInsuranceComprehensive => 'Comprehensive insurance';

  @override
  String get serviceVignette => 'Vignette expires';

  @override
  String get maintenanceStateUpcoming => 'Upcoming';

  @override
  String get maintenanceStateDue => 'Due';

  @override
  String get maintenanceStateOverdue => 'Overdue';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get plannerTitle => 'Planner';

  @override
  String get plannerRunway => 'Next 12 weeks';

  @override
  String get plannerEmpty => 'Nothing due in the next 12 weeks';

  @override
  String get plannerOverdueNote =>
      'Anything overdue sits under today, because today is when it needs doing';

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
  String get bundleLogVisit => 'Log this visit';

  @override
  String get bundleExcludeHint =>
      'Trimming an item only changes the suggestion above — nothing is logged or cancelled.';

  @override
  String get bundlePutBack => 'Put back';

  @override
  String get bundleOneVehicleOnly =>
      'Log it per vehicle: these are on more than one.';

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
  String notificationDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Due in $count days',
      one: 'Due in 1 day',
    );
    return '$_temp0';
  }

  @override
  String notificationDueInKm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Due in $count km',
    );
    return '$_temp0';
  }

  @override
  String notificationOverdueByKm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count km past due',
    );
    return '$_temp0';
  }

  @override
  String bundleSuggestionTitle(int count) {
    return 'Bundle $count items into one visit';
  }

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline =>
      'Every vehicle in the garage in one place: fuel, servicing, costs, and what falls due next.';

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
      'No tracking, no analytics, no profiles. What you log stays inside your garage.';

  @override
  String get aboutPrivacyPolicy => 'Privacy policy';

  @override
  String get aboutLicences => 'Open source licences';

  @override
  String get aboutLicencesHint => 'The libraries this app is built on';

  @override
  String get aboutSourceCode => 'Source code';

  @override
  String get aboutSourceCodeHint =>
      'The whole app is open source, under AGPL-3.0';

  @override
  String get aboutSendFeedback => 'Send feedback';

  @override
  String get aboutSendFeedbackHint => 'A bug, an idea, or just to say hello';

  @override
  String get aboutFeedbackSubject => 'Garage feedback';

  @override
  String get aboutDiagnostics => 'Diagnostics';

  @override
  String get aboutDiagnosticsHint => 'Recent errors, to send with a bug report';

  @override
  String get diagnosticsTitle => 'Diagnostics';

  @override
  String get diagnosticsEmpty => 'Nothing has gone wrong on this device.';

  @override
  String get diagnosticsExplain =>
      'Kept only on this device. Nothing is sent anywhere until you share it.';

  @override
  String get diagnosticsShare => 'Share';

  @override
  String get diagnosticsClear => 'Clear';

  @override
  String get diagnosticsCleared => 'Diagnostics cleared';

  @override
  String get settingsTrackingBasicHint =>
      'Date, odometer, what was done, what it cost';

  @override
  String get settingsTrackingDetailedHint =>
      'Adds parts, labour, DIY and warranty';

  @override
  String get settingsTrackingFullHint =>
      'Adds readings: pad thickness, tread depth, voltage';

  @override
  String settingsImportCreates(String name) {
    return 'This will add $name to your garage';
  }

  @override
  String get settingsImportNoVehicle =>
      'That backup has no vehicle in it. Add a vehicle first, then import into it.';

  @override
  String get settingsImportStation => 'Fuel station';

  @override
  String get settingsImportStationHint =>
      'Optional — this file does not say where you filled up';

  @override
  String get settingsImportFuelType => 'Fuel it runs on';

  @override
  String get settingsExportNothing =>
      'Nothing to export yet — log a fill-up or a service first';

  @override
  String get householdInvites => 'Invite codes';

  @override
  String get householdInvitesHint =>
      'Anyone with a code can join this garage until it is used or expires';

  @override
  String get householdInviteActive => 'Waiting to be used';

  @override
  String get householdInviteUsed => 'Used';

  @override
  String get householdInviteExpired => 'Expired';

  @override
  String get householdInviteRevoke => 'Revoke';

  @override
  String get householdInviteRevoked => 'Code revoked';

  @override
  String get householdInviteNew => 'New code';

  @override
  String economyScale(String best, String worst) {
    return 'Best $best · Worst $worst on this vehicle';
  }

  @override
  String get economyScaleNone => 'Log a few full tanks to compare against';

  @override
  String get maintenanceLastDone => 'Last done (optional)';

  @override
  String get maintenanceLastDoneHint =>
      'If you have already done this, say when: intervals count from there instead of from when the vehicle was added';

  @override
  String get maintenanceLastDoneDate => 'Date it was done';

  @override
  String get maintenanceLastDoneKm => 'Odometer when done';

  @override
  String get runningCostTitle => 'What this vehicle costs';

  @override
  String get runningCostPerKm => 'Per kilometre';

  @override
  String runningCostFuelShare(String amount) {
    return 'Fuel $amount';
  }

  @override
  String runningCostUpkeepShare(String amount) {
    return 'Upkeep $amount';
  }

  @override
  String get runningCostPerMonth => 'Per month';

  @override
  String get runningCostPerYear => 'Per year';

  @override
  String get runningCostTotal => 'Since you added it';

  @override
  String get runningCostNotEnough =>
      'Log some fuel and costs to see what this vehicle costs to run';

  @override
  String get runningCostBreakdown => 'Where it went';

  @override
  String get runningCostFuelTotal => 'Fuel';

  @override
  String get runningCostServiceTotal => 'Servicing';

  @override
  String get runningCostOtherTotal => 'Registration, insurance and the rest';

  @override
  String get costCategoryInsuranceComprehensive => 'Comprehensive insurance';

  @override
  String get settingsDeleteData => 'Delete all data';

  @override
  String get settingsDeleteDataHint =>
      'Start over: removes every vehicle and everything logged against them. Your account and garage stay.';

  @override
  String get settingsDeleteDataConfirm =>
      'Delete every vehicle and all their fuel, services, costs and attachments? This cannot be undone.';

  @override
  String get settingsDeleteDataDone => 'All vehicle data deleted';

  @override
  String get quickAddFuel => 'Fuel up';

  @override
  String get quickAddService => 'Service';

  @override
  String get quickAddCost => 'Cost';

  @override
  String get quickAddPickVehicle => 'Which vehicle?';

  @override
  String get settingsPumpAutofill => 'Fill in the station and price for me';

  @override
  String get settingsPumpAutofillHint =>
      'Uses your location at the pump to find the station you are at and fill in today’s posted price for your fuel. Nothing is sent anywhere — the position is matched against prices already on your phone.';

  @override
  String get settingsPumpAutofillOn =>
      'On — the price fills itself in when you are at a station';

  @override
  String get settingsPumpAutofillDenied =>
      'Location is off for Garage. Turn it on in the system settings to use this.';

  @override
  String get settingsSampleData => 'Load sample data';

  @override
  String get settingsSampleDataHint =>
      'Adds one vehicle with a year of fill-ups, services and costs, so every screen has something to show. Remove it with Delete all data.';

  @override
  String get settingsSampleDataConfirmTitle => 'Load sample data?';

  @override
  String settingsSampleDataConfirmBody(String vehicle) {
    return 'This adds a demo car ($vehicle) with a year of history to this garage, alongside what you already have. You can delete it afterwards.';
  }

  @override
  String get settingsSampleDataDone => 'Sample vehicle added';

  @override
  String get gettingStarted => 'Getting started';

  @override
  String get gettingStartedVehicle => 'Add a vehicle yourself';

  @override
  String get gettingStartedTransfer => 'Receive a vehicle with a code';

  @override
  String get gettingStartedNext => 'What next';

  @override
  String get gettingStartedFuel => 'Log a fill-up';

  @override
  String get gettingStartedReminder => 'Set what it needs, and when';

  @override
  String get gettingStartedSample => 'Or load sample data to look around first';

  @override
  String get odometerTitle => 'Odometer';

  @override
  String get odometerAdd => 'Log a reading';

  @override
  String get odometerReading => 'Reading';

  @override
  String get odometerHint =>
      'A reading with no money attached, so maintenance still knows how far the vehicle has gone.';

  @override
  String get quickAddOdometer => 'Odometer';

  @override
  String get statsPeriodAllTime => 'All time';

  @override
  String get statsPeriodLastTwelve => 'Last 12 months';

  @override
  String get statsPeriodCustom => 'Pick dates';

  @override
  String statsPeriodRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'No entries',
    );
    return '$_temp0';
  }

  @override
  String get statsPerDay => 'By day';

  @override
  String get statsPerDistance => 'By distance';

  @override
  String get statsByKind => 'Where the money goes';

  @override
  String get statsByCategory => 'By category';

  @override
  String get statsByStation => 'By station';

  @override
  String get statsMonthlySpend => 'Spend per month';

  @override
  String get statsEconomyByStation => 'Economy by station';

  @override
  String get statsEconomyByStationNote =>
      'An observation, not advice — driving, weather and season move economy far more than fuel does';

  @override
  String statsEconomyTanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tanks',
      one: '1 tank',
    );
    return '$_temp0';
  }

  @override
  String get statsOdometerChart => 'Odometer over time';

  @override
  String get statsOthers => 'Others';

  @override
  String get statsUnlabelled => 'Not recorded';

  @override
  String get statsRecords => 'Best and worst';

  @override
  String get statsComparison => 'Year and month';

  @override
  String get statsSummary => 'Summary';

  @override
  String get statsCustomise => 'Choose what to show';

  @override
  String get statsCustomiseHint =>
      'Turned off here, kept out of the way. Nothing is deleted.';

  @override
  String get statsShowAll => 'Show everything';

  @override
  String get statsNothingShown =>
      'Everything is hidden. Choose what to show from the menu.';

  @override
  String get tripsTitle => 'Trip log';

  @override
  String get tripAdd => 'Log a trip';

  @override
  String get tripsEmpty => 'No trips logged yet.';

  @override
  String get tripTitleField => 'Name';

  @override
  String get tripFrom => 'From';

  @override
  String get tripTo => 'To';

  @override
  String get tripDistance => 'Distance';

  @override
  String get tripDistanceRequired =>
      'Enter a distance, or both odometer readings.';

  @override
  String get tripStartOdometer => 'Odometer at the start';

  @override
  String get tripEndOdometer => 'Odometer at the end';

  @override
  String get tripOdometerOrder =>
      'The end reading cannot be lower than the start.';

  @override
  String get tripMinutes => 'Minutes';

  @override
  String get tripPurpose => 'Purpose';

  @override
  String get tripPurposePrivate => 'Private';

  @override
  String get tripPurposeBusiness => 'Business';

  @override
  String get tripTotalTrips => 'Trips';

  @override
  String get tripTotalDistance => 'Distance';

  @override
  String get tripTotalTime => 'Time';

  @override
  String get tripAverageSpeed => 'Average speed';

  @override
  String tripHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get quickAddTrip => 'Trip';

  @override
  String get incomeTitle => 'Income';

  @override
  String get incomeAdd => 'Add income';

  @override
  String get incomeAmount => 'Amount';

  @override
  String get incomeCategory => 'Kind';

  @override
  String get incomeCategoryRide => 'Lift share';

  @override
  String get incomeCategoryTransportApp => 'Ride-hailing';

  @override
  String get incomeCategoryFreight => 'Freight';

  @override
  String get incomeCategoryRefund => 'Refund';

  @override
  String get incomeCategoryVehicleSale => 'Sold the vehicle';

  @override
  String get incomeCategoryOther => 'Other';

  @override
  String get quickAddIncome => 'Income';

  @override
  String get statsBalance => 'Balance';

  @override
  String get statsTabTrips => 'Trips';

  @override
  String get statsBusinessDistance => 'Business';

  @override
  String get statsPrivateDistance => 'Private';

  @override
  String get statsIncomeByKind => 'Where the money comes from';

  @override
  String joinSecondGarage(String name) {
    return 'You are already in $name. Joining this one adds it — you can switch between them.';
  }

  @override
  String get householdSwitch => 'Switch garage';

  @override
  String get householdCreateAnother => 'Create another garage';

  @override
  String get householdYours => 'Your garages';

  @override
  String get householdCurrent => 'Showing now';

  @override
  String get transferTitle => 'Transfer this vehicle';

  @override
  String get transferSell => 'Sold the vehicle?';

  @override
  String get transferSellHint =>
      'Hand the buyer this code. The vehicle and its whole history move into their garage, and out of yours.';

  @override
  String get transferBought => 'Bought a vehicle?';

  @override
  String get transferBoughtHint => 'Enter the code the seller gave you.';

  @override
  String get transferGenerate => 'Get a transfer code';

  @override
  String get transferConfirmTitle => 'Hand this vehicle over?';

  @override
  String get transferRedeem => 'Redeem a code';

  @override
  String get transferCompletedTitle => 'Handed over';

  @override
  String transferCompletedNamed(String nickname) {
    return '$nickname is now in its new owner’s garage, with all its history.';
  }

  @override
  String get transferCompleted =>
      'A vehicle you transferred is now in its new owner’s garage.';

  @override
  String get transferCompletedDismiss => 'Got it';

  @override
  String get transferCode => 'Transfer code';

  @override
  String get transferCopied => 'Code copied';

  @override
  String get transferDone => 'The vehicle is in your garage now.';

  @override
  String get transferWarning =>
      'This cannot be undone from here — only the new owner can send it back.';

  @override
  String get transferPhotoNote =>
      'The photo stays with you; everything else goes.';

  @override
  String get vehicleSecondFuel => 'Second fuel';

  @override
  String get vehicleSecondFuelHint =>
      'For a vehicle that runs on two — LPG beside petrol. Each fill-up then says which went in.';

  @override
  String get vehicleSecondFuelNone => 'Only one fuel';

  @override
  String get fuelWhichFuel => 'Fuel';

  @override
  String get fuelCng => 'CNG';

  @override
  String get fuelEthanol => 'Ethanol';

  @override
  String get fuelPetrolMidgrade => 'Petrol 95+';

  @override
  String get fuelPetrolPremium => 'Petrol 100';

  @override
  String get statsEconomyByFuel => 'Consumption per fuel';

  @override
  String get csvImportTitle => 'Import a CSV';

  @override
  String get csvImportIntro =>
      'From Drivvo, a spreadsheet, or anything else that exports a table. Pick the file, say which column is which, and check the preview before it is written.';

  @override
  String get csvPickFile => 'Choose a file';

  @override
  String get csvFileEmpty => 'That file has no rows this app can read.';

  @override
  String get csvWhatIsIt => 'What is in this file';

  @override
  String get csvKindFuel => 'Fill-ups';

  @override
  String get csvKindCost => 'Costs';

  @override
  String get csvKindService => 'Services';

  @override
  String get csvKindOdometer => 'Odometer readings';

  @override
  String get csvKindTrip => 'Trips';

  @override
  String get csvKindIncome => 'Income';

  @override
  String get csvWhichVehicle => 'Which vehicle';

  @override
  String get csvColumns => 'Columns';

  @override
  String get csvColumnNone => 'Not in this file';

  @override
  String get csvRequired => 'required';

  @override
  String get csvDayFirst => 'Dates are day first (31/12)';

  @override
  String get csvMiles => 'Distances are in miles';

  @override
  String get csvGallons => 'Volumes are in gallons';

  @override
  String get csvPreview => 'Preview';

  @override
  String csvReadyToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows ready',
      one: '1 row ready',
      zero: 'Nothing to import',
    );
    return '$_temp0';
  }

  @override
  String csvSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows will be skipped',
      one: '1 row will be skipped',
    );
    return '$_temp0';
  }

  @override
  String csvMissingColumn(String field) {
    return 'Choose a column for $field';
  }

  @override
  String csvRowProblem(int line, String field) {
    return 'Line $line: $field could not be read';
  }

  @override
  String get csvImportAction => 'Import';

  @override
  String csvImported(int written, int skipped) {
    return '$written imported, $skipped already there';
  }

  @override
  String get csvFieldDate => 'Date';

  @override
  String get csvFieldOdometer => 'Odometer';

  @override
  String get csvFieldVolume => 'Volume';

  @override
  String get csvFieldPricePerUnit => 'Price per unit';

  @override
  String get csvFieldTotal => 'Total';

  @override
  String get csvFieldFullTank => 'Full tank';

  @override
  String get csvFieldStation => 'Station';

  @override
  String get csvFieldNotes => 'Notes';

  @override
  String get csvFieldAmount => 'Amount';

  @override
  String get csvFieldCategory => 'Category';

  @override
  String get csvFieldType => 'Type';

  @override
  String get csvFieldCost => 'Cost';

  @override
  String get csvFieldShop => 'Shop';

  @override
  String get csvFieldDistance => 'Distance';

  @override
  String get csvFieldTitle => 'Title';

  @override
  String get csvFieldFrom => 'From';

  @override
  String get csvFieldTo => 'To';

  @override
  String get csvFieldBusiness => 'Business trip';

  @override
  String get csvFieldMinutes => 'Minutes';

  @override
  String get settingsImportCsv => 'Import a CSV (any app)';

  @override
  String get settingsAutoBackup => 'Automatic backup';

  @override
  String get settingsAutoBackupOff =>
      'Off — pick a folder to back up into once a day';

  @override
  String settingsAutoBackupOn(String when) {
    return 'Once a day, last backed up $when';
  }

  @override
  String get settingsAutoBackupJustRan => 'Backed up automatically';

  @override
  String get settingsAutoBackupNever => 'Once a day, not run yet';

  @override
  String get settingsAutoBackupStop => 'Stop backing up';

  @override
  String get settingsBackup => 'Back up everything';

  @override
  String get settingsBackupHint =>
      'A file that can be restored, unlike the CSV export';

  @override
  String get settingsRestore => 'Restore from a backup';

  @override
  String get settingsRestoreHint =>
      'Adds what is missing. Nothing is deleted or overwritten.';

  @override
  String get settingsBackupDone => 'Backup saved';

  @override
  String settingsRestoreDone(int vehicles, int written, int skipped) {
    return '$vehicles vehicles, $written entries added, $skipped already there';
  }

  @override
  String get settingsRestoreNotABackup => 'That file is not a Garage backup.';

  @override
  String get stationsPickNearest => 'Nearest';

  @override
  String get stationsPickCheapest => 'Cheapest';

  @override
  String get stationsPickBestValue => 'Best value';

  @override
  String get stationsBestValueHint =>
      'Cheapest once the fuel to get there and back is paid for';

  @override
  String get stationsGradeAverages => 'Average around here';

  @override
  String stationsGradeStations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stations',
      one: '1 station',
    );
    return '$_temp0';
  }

  @override
  String get commonClear => 'Clear';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonIncrease => 'Increase';

  @override
  String get commonDecrease => 'Decrease';

  @override
  String get commonShowPassword => 'Show password';

  @override
  String get commonHidePassword => 'Hide password';

  @override
  String get householdRename => 'Rename garage';

  @override
  String get householdRenamed => 'Garage renamed';

  @override
  String get householdRenameAdminOnly => 'Only an admin can rename the garage';

  @override
  String get householdDelete => 'Delete garage';

  @override
  String get householdDeleteTitle => 'Delete this garage?';

  @override
  String get householdDeleteBody =>
      'This ends the garage for everyone in it, not just for you. Every vehicle, entry and reminder goes with it.';

  @override
  String get maintenanceLogServiceHint => 'Something that has been done';

  @override
  String get maintenanceAddRuleHint => 'Something that should come round again';

  @override
  String get quickAddInterval => 'Set an interval';

  @override
  String get settingsMore => 'More';

  @override
  String get settingsPreferencesHint => 'Units, currency, theme and language';

  @override
  String get settingsDataHint => 'Import, export and backups';

  @override
  String get timelineSearch => 'Search history';

  @override
  String get timelineNoMatches => 'Nothing matches that.';

  @override
  String get serviceBrakeDiscsFront => 'Front brake discs';

  @override
  String get serviceBrakeDiscsRear => 'Rear brake discs';

  @override
  String get serviceBrakeDrumsRear => 'Rear brake drums';

  @override
  String get serviceGlowPlugs => 'Glow plugs';

  @override
  String get serviceDpf => 'Diesel particulate filter';

  @override
  String get serviceAdblue => 'AdBlue top-up';

  @override
  String get serviceFuelFilter => 'Fuel filter';

  @override
  String get serviceClutch => 'Clutch';

  @override
  String get serviceDifferentialOil => 'Differential oil';

  @override
  String get serviceSerpentineBelt => 'Serpentine belt';

  @override
  String get serviceWaterPump => 'Water pump';

  @override
  String get serviceShockAbsorbers => 'Shock absorbers';

  @override
  String get serviceWheelAlignment => 'Wheel alignment';

  @override
  String get serviceAcService => 'Air conditioning service';

  @override
  String get serviceBulbs => 'Bulbs';

  @override
  String attachmentTooLarge(String size, String limit) {
    return 'That file is $size — the limit is $limit. Try a smaller photo, or a PDF.';
  }

  @override
  String get authConfirmChecking => 'Confirming your email…';

  @override
  String get authConfirmFailedTitle => 'That link did not work';

  @override
  String get authConfirmFailedBody =>
      'Confirmation links work once and expire. Ask for a new one by signing in, or register again.';

  @override
  String get authConfirmNoLink => 'There is nothing to confirm here.';

  @override
  String get authConfirmSignIn => 'Go to sign-in';

  @override
  String get timelineHasNote => 'Has a note';

  @override
  String get timelineHasAttachment => 'Has an attachment';

  @override
  String get timelineFilter => 'Filter by kind';

  @override
  String get timelineFilterClear => 'Clear filters';

  @override
  String get settingsYourName => 'Your name';

  @override
  String get settingsNameChanged => 'Name updated';

  @override
  String get settingsSettlement => 'Shared costs';

  @override
  String get settingsSettlementHint =>
      'Splits everything logged equally between members and works out who owes whom. Useful when you share a car but keep separate money.';

  @override
  String get settingsSettlementEnable => 'Work out who owes whom';

  @override
  String tyreWindowFixed(String from, String to) {
    return 'Winter tyres $from – $to, whatever the weather';
  }

  @override
  String tyreWindowWhenWintry(String from, String to) {
    return 'Winter tyres $from – $to, when roads are wintry';
  }

  @override
  String get tyreWindowSituational =>
      'No fixed dates — winter tyres whenever roads are wintry';

  @override
  String get notificationSwapToWinter => 'Fit winter tyres';

  @override
  String get notificationSwapToSummer => 'Back to summer tyres';
}
