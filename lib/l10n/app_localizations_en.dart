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
  String get saveStillSaving => 'Still saving…';

  @override
  String get saveEntryKept => 'Your entry is still here.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonUndo => 'Undo';

  @override
  String get discardTitle => 'Discard what you typed?';

  @override
  String get discardKeep => 'Keep editing';

  @override
  String get discardConfirm => 'Discard';

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
  String get errorTimeout =>
      'No answer from the server in time. It may still have saved: check the list before trying again.';

  @override
  String get errorPermission => 'You do not have access to that.';

  @override
  String get errorNotFound => 'That could not be found.';

  @override
  String get errorTransferCode =>
      'That transfer code is not valid, or it has already been used.';

  @override
  String get errorTransferHere => 'That vehicle is already in this garage.';

  @override
  String get errorConflict => 'That already exists.';

  @override
  String get errorInvalid =>
      'Some of the values were not accepted. Check them and try again.';

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
  String get authDisplayNameHint =>
      'Shown to the people you share a garage with';

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
  String get onboardingSuggestName => 'Suggest a name';

  @override
  String onboardingNameOfPerson(String name) {
    return '$name\'s garage';
  }

  @override
  String get onboardingNameIdea1 => 'Family garage';

  @override
  String get onboardingNameIdea2 => 'Home fleet';

  @override
  String get onboardingNameIdea3 => 'Our cars';

  @override
  String get onboardingNameIdea4 => 'The driveway';

  @override
  String get onboardingNameIdea5 => 'Motor pool';

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
  String get householdInviteLinkCopied => 'Invite message copied';

  @override
  String householdInviteMessageNoExpiry(String code, String link) {
    return 'Join my garage in Garage: install the app, create an account, tap \"Join with a code\" and enter $code — or just open $link.';
  }

  @override
  String householdInviteMessage(String code, String link, String until) {
    return 'Join my garage in Garage: install the app, create an account, tap \"Join with a code\" and enter $code — or just open $link. The code works until $until.';
  }

  @override
  String get transferVehicleLocked =>
      'This is the vehicle the code will hand over. Go back to pick a different one.';

  @override
  String householdTransferNamed(String vehicle) {
    return 'Hand $vehicle to another garage';
  }

  @override
  String get householdTransferPick => 'Hand a vehicle to another garage…';

  @override
  String get householdTransferVehicle => 'Hand a vehicle to another garage';

  @override
  String get householdDangerZone => 'Leave or delete';

  @override
  String get householdManage => 'Manage';

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
  String calculatorFromCar(String vehicle, String economy) {
    return 'From $vehicle: $economy';
  }

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
  String get stationsNoLocationTitle => 'Cheapest in Croatia';

  @override
  String get stationsNoLocationBody =>
      'Without your location these are the cheapest stations in the country, not the closest ones. Nothing here is sorted by how far it is.';

  @override
  String get stationsUseLocation => 'Use my location';

  @override
  String get stationsGradesNearby => 'Grades near you';

  @override
  String get stationsGradesCountry => 'Grades across the country';

  @override
  String get stationsGradesNote => 'Most widely sold first';

  @override
  String get stationsFavourite => 'Favourite';

  @override
  String get stationsAvgNearby => 'Average nearby';

  @override
  String get stationsNationalAvg => 'National average';

  @override
  String stationsTrendUp(String amount) {
    return 'Up $amount on last week';
  }

  @override
  String stationsTrendDown(String amount) {
    return 'Down $amount on last week';
  }

  @override
  String get stationsTrendSteady => 'Steady on last week';

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
  String get statsDistanceNeedsSecond => 'Needs a second reading';

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
  String get calendarTapHint => 'Tap a day to see what is due';

  @override
  String get reportsNotSaved => 'Report not saved';

  @override
  String get reportsTitle => 'Create report';

  @override
  String get reportSellers => 'Seller\'s report';

  @override
  String get reportMaintenance => 'Maintenance history';

  @override
  String get reportSchedule => 'Service schedule';

  @override
  String get reportScheduleHint =>
      'The intervals set for this car, as a sheet you can print or hand over';

  @override
  String get reportScheduleItem => 'Item';

  @override
  String get reportScheduleEvery => 'Every';

  @override
  String get reportScheduleLastDone => 'Last done';

  @override
  String get reportScheduleNextDue => 'Next due';

  @override
  String get reportScheduleNone => 'No intervals set for this vehicle yet.';

  @override
  String reportScheduleKm(String km) {
    return '$km km';
  }

  @override
  String reportScheduleMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get reportScheduleOnce => 'Once';

  @override
  String get reportScheduleNote =>
      'Intervals are this garage’s own settings, not the manufacturer’s schedule.';

  @override
  String get reportTripLog => 'Mileage logbook';

  @override
  String get reportTripLogHint =>
      'Every journey in a period, with the business split and a line to sign';

  @override
  String get reportTripLogPeriod => 'Period';

  @override
  String get reportTripLogDriver => 'Driver';

  @override
  String get reportTripLogPurpose => 'Details';

  @override
  String get reportTripLogRoute => 'Route';

  @override
  String get reportTripLogBusinessTotal => 'Business distance';

  @override
  String get reportTripLogPrivateTotal => 'Private distance';

  @override
  String get reportTripLogTotal => 'Total distance';

  @override
  String get reportTripLogTrips => 'Journeys';

  @override
  String get reportTripLogSignature => 'Signature';

  @override
  String get reportTripLogDate => 'Date';

  @override
  String get reportTripLogNoTrips => 'No journeys recorded in this period.';

  @override
  String get reportTripLogPickPeriod => 'Which period?';

  @override
  String get reportTripLogThisMonth => 'This month';

  @override
  String get reportTripLogLastMonth => 'Last month';

  @override
  String get reportTripLogThisYear => 'This year';

  @override
  String get reportAnnual => 'Annual summary';

  @override
  String get reportSellersHint =>
      'What a buyer asks for: history, mileage and what it cost to run';

  @override
  String get reportMaintenanceHint =>
      'Every service logged, with dates and odometer readings';

  @override
  String get reportAnnualHint => 'One year of fuel, servicing and other costs';

  @override
  String get costsTitle => 'Costs';

  @override
  String get costAdd => 'Add cost';

  @override
  String get costEdit => 'Edit cost';

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
  String get costsEmptyBeyondFuel => 'No costs beyond fuel yet.';

  @override
  String costsFuelLine(String amount) {
    return 'Fuel $amount, from the fill-ups';
  }

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
  String get settingsExport => 'Export as spreadsheets';

  @override
  String settingsExportDone(String file) {
    return 'Export ready: $file';
  }

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
  String get settingsDeleteTypeName => 'Type the garage name to confirm';

  @override
  String get settingsDeleteNameMismatch => 'That is not the garage name.';

  @override
  String get apiTitle => 'API access';

  @override
  String get apiHint =>
      'Read-only keys for your own scripts, and webhooks that send this garage’s data to a URL you choose';

  @override
  String get apiDocs => 'How to use it';

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
  String get apiWebhookFormat => 'Format';

  @override
  String get apiWebhookFormatHint =>
      'Read from the address unless you run the receiver yourself';

  @override
  String get apiWebhookFormatAuto => 'Detect from the address';

  @override
  String get apiWebhookFormatGeneric => 'Signed JSON (Home Assistant, scripts)';

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
  String vehicleAdded(String name) {
    return '$name added';
  }

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
  String get vehiclePhotoCropTitle => 'Frame the photo';

  @override
  String get vehiclePhotoRemove => 'Remove photo';

  @override
  String get vehiclePlate => 'Plate';

  @override
  String get sheetVehicleLockedByFile =>
      'Remove the attachment to move this to another car';

  @override
  String get sheetVehicleTapToChange => 'Tap to change';

  @override
  String get vehicleVin => 'VIN';

  @override
  String get vehicleVinLength => 'A VIN is 11 to 17 characters long';

  @override
  String get vehicleDecodeVin => 'Look up';

  @override
  String get vehicleVinHint => 'Fills in make, model and year from the number';

  @override
  String get vehicleVinNotFound => 'That VIN could not be looked up';

  @override
  String get vehicleVinDecoded => 'Filled in from the VIN registry';

  @override
  String get vehicleFuelType => 'Fuel type';

  @override
  String get vehicleOdometer => 'Current odometer';

  @override
  String get tankRangeLabel => 'Range left';

  @override
  String fuelCheaperNearby(String amount, String distance, String station) {
    return '$amount cheaper $distance away, at $station';
  }

  @override
  String get fuelCheapestNearby => 'Cheapest nearby that day';

  @override
  String fuelWorseThanUsual(String percent) {
    return '$percent more than this car\'s usual';
  }

  @override
  String fuelBetterThanUsual(String percent) {
    return '$percent less than this car\'s usual';
  }

  @override
  String get tankRangeLeft => 'left';

  @override
  String tankRangeRefuelAround(String date) {
    return 'Fuel up around $date';
  }

  @override
  String get vehicleTankCapacity => 'Tank capacity';

  @override
  String get vehicleTankCapacityHint => 'Flags a fill-up bigger than the tank';

  @override
  String get vehicleCurrentValue => 'What it is worth now';

  @override
  String get vehicleCurrentValueHint =>
      'Your own estimate. With the purchase price it gives what the car costs to own, not only to run — the value it loses is the largest cost of keeping it.';

  @override
  String get vehiclePurchasePrice => 'Purchase price';

  @override
  String get vehiclePurchasePriceHint => 'What you paid for the car';

  @override
  String get vehicleArchiveTitle => 'Archive this vehicle?';

  @override
  String get vehicleArchiveBody =>
      'It keeps its history and stays off the lists and totals. You can bring it back from its own page.';

  @override
  String get vehicleArchivedBanner => 'Archived: off the lists, history kept.';

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
  String get tyresTitle => 'Tyres';

  @override
  String get vehicleTyresHint => 'Sets, the seasonal swap, tread depth and age';

  @override
  String get tyresEmpty => 'Add the sets this vehicle runs on';

  @override
  String get tyresAdd => 'Add a set';

  @override
  String get tyresEdit => 'Edit set';

  @override
  String tyresAgeAgeing(Object years) {
    return '$years years old — worth checking each year';
  }

  @override
  String tyresAgeAgeingEstimated(Object years) {
    return 'About $years years old, estimated from when it was fitted';
  }

  @override
  String tyresAgeExpired(Object years) {
    return '$years years old — replace whatever the tread says';
  }

  @override
  String tyresAgeExpiredEstimated(Object years) {
    return 'About $years years old, estimated from when it was fitted — replace whatever the tread says';
  }

  @override
  String get tyresDotCode => 'DOT code';

  @override
  String get tyresDotPerCorner => 'The codes are different on each tyre';

  @override
  String get tyresDotSame => 'They are all the same';

  @override
  String get tyresDotCodeHint =>
      'Four digits on the sidewall, like 3419 for week 34 of 2019';

  @override
  String get tyresDotCodeInvalid => 'Four digits: week 01-53, then the year';

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
  String get tyresUnfit => 'Take off the vehicle';

  @override
  String get tyresUnretire => 'Bring back into use';

  @override
  String get tyresMoreActions => 'More for this set';

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
  String get tyresReadingSaved => 'Tread recorded';

  @override
  String tyresMeasuredOn(String date) {
    return 'Measured $date';
  }

  @override
  String tyresBelowLegalAt(String minimum) {
    return 'At or below the $minimum legal minimum';
  }

  @override
  String tyresWearEstimate(String distance, String date) {
    return 'About $distance left, around $date';
  }

  @override
  String tyresWearEstimateDistanceOnly(Object distance) {
    return 'About $distance left';
  }

  @override
  String get economyByFuelOverlap =>
      'Each fuel is measured over its own fill-ups, but the spans overlap — distance driven on the other fuel is counted in too. Treat these as close, not exact.';

  @override
  String tyresUneven(String low, String high) {
    return 'Uneven: $low to $high';
  }

  @override
  String get tyresFront => 'Front';

  @override
  String get tyresRear => 'Rear';

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
  String get vehicleTabMaintenance => 'Reminders';

  @override
  String get vehicleTabHistory => 'History';

  @override
  String get vehicleArchive => 'Archive';

  @override
  String get vehicleRestore => 'Restore';

  @override
  String get vehicleArchived =>
      'Archived. It keeps its history and stays off the lists.';

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
  String economyTanksProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count of 2 full tanks logged',
      one: '1 of 2 full tanks logged',
    );
    return '$_temp0';
  }

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
  String fuelSaved(String amount) {
    return 'Saved, $amount.';
  }

  @override
  String fuelSavedFirstFull(String amount) {
    return 'Saved, $amount. One more full tank and consumption appears.';
  }

  @override
  String get fuelSavedPlain => 'Fill-up saved.';

  @override
  String get serviceSaved => 'Service logged.';

  @override
  String get costDuplicateWarning =>
      'The same amount in the same category is already logged on this day';

  @override
  String get costSaved => 'Cost saved.';

  @override
  String get fuelAdd => 'Add fill-up';

  @override
  String get fuelEdit => 'Edit fill-up';

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
  String get fuelNotes => 'Notes';

  @override
  String get fuelAverage => 'Average';

  @override
  String get fuelCostPerDistance => 'Fuel cost, latest fill-up';

  @override
  String get fuelNeedTwoValues =>
      'Enter at least two of volume, price, and total';

  @override
  String get amountNotANumber => 'Not a number';

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
  String fuelOdometerEarlierToday(String reading) {
    return 'Earlier today: $reading';
  }

  @override
  String fuelImpliedConsumption(String rate) {
    return 'That works out at $rate — check the odometer and the amount';
  }

  @override
  String fuelVolumeOverTank(String capacity) {
    return 'More than the tank holds ($capacity)';
  }

  @override
  String get maintenanceTitle => 'Maintenance';

  @override
  String get maintenanceEmpty => 'Add a reminder to start tracking what is due';

  @override
  String get maintenanceAddRule => 'Add reminder';

  @override
  String maintenanceRuleSaved(String type) {
    return 'Reminder set: $type';
  }

  @override
  String get maintenanceLogService => 'Log service';

  @override
  String get maintenanceEditService => 'Edit service';

  @override
  String get maintenanceIntervalKm => 'Every (distance)';

  @override
  String get maintenanceIntervalMonths => 'Every (months)';

  @override
  String intervalNoteMake(String make) {
    return 'Typical for $make — confirm in your service book';
  }

  @override
  String get intervalNoteChain =>
      'This engine has a timing chain, so no interval is needed';

  @override
  String get intervalNoteWetBelt =>
      'A belt that runs in oil — most makers have shortened this interval';

  @override
  String get intervalNoteSetTimingDrive =>
      'Set the timing drive on the vehicle for a better default';

  @override
  String get intervalNoteSetTransmission =>
      'Set the gearbox on the vehicle for a better default';

  @override
  String get intervalNoteSealed =>
      'A dry dual-clutch gearbox is sealed for life';

  @override
  String get intervalNoteAdvisory =>
      'Makers often say \"for life\"; independents change it anyway';

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
  String maintenanceRateMeasured(num days, String rate) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Dates below are estimated from $rate/day over $_temp0 of readings';
  }

  @override
  String maintenanceRateUnmeasured(String rate) {
    return 'No driving rate yet: the dates below come from the calendar interval. A couple of weeks of readings and the distance estimate appears; a rule with only a distance assumes $rate/day until then.';
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
  String get serviceDuplicateWarning =>
      'The same work at the same odometer is already logged on this day';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsSubtitle =>
      'Registration, roadworthiness, insurance — and when each runs out';

  @override
  String get documentsEmpty =>
      'No documents yet. Record when the registration and the roadworthiness certificate run out, and the app will tell you before they do.';

  @override
  String get documentsSomethingExpired => 'Something has run out';

  @override
  String get documentsSomethingExpiring => 'Something runs out soon';

  @override
  String get documentAdd => 'Add document';

  @override
  String get documentEdit => 'Edit document';

  @override
  String get documentType => 'Type';

  @override
  String get documentLabel => 'What it is';

  @override
  String get documentLabelHint => 'Only for a document this list does not name';

  @override
  String get documentNumber => 'Number';

  @override
  String get documentIssuer => 'Issued by';

  @override
  String get documentIssuedOn => 'Issued';

  @override
  String get documentExpiresOn => 'Valid until';

  @override
  String get documentDateNotSet => 'Not set';

  @override
  String get documentClearDate => 'Clear';

  @override
  String get documentNoExpiry => 'No expiry recorded';

  @override
  String documentExpiredOn(String date) {
    return 'Expired $date';
  }

  @override
  String get documentExpiresToday => 'Expires today';

  @override
  String documentExpiresInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Expires in $count days',
      one: 'Expires tomorrow',
    );
    return '$_temp0';
  }

  @override
  String documentValidUntil(String date) {
    return 'Valid until $date';
  }

  @override
  String get documentDatesOutOfOrder => 'Cannot run out before it was issued';

  @override
  String get documentLabelRequired => 'Say what this document is';

  @override
  String get documentSaved => 'Document saved.';

  @override
  String get documentReminderNote =>
      'A reminder is set from the expiry, so this turns up in the planner before it runs out.';

  @override
  String get documentNoReminderNote =>
      'No reminder: the app has no name for this one, so it cannot say what is coming due.';

  @override
  String get documentTypeRegistration => 'Registration';

  @override
  String get documentTypeRoadworthiness => 'Roadworthiness test';

  @override
  String get documentTypeInsuranceLiability => 'Liability insurance';

  @override
  String get documentTypeInsuranceComprehensive => 'Comprehensive insurance';

  @override
  String get documentTypeGreenCard => 'Green card';

  @override
  String get documentTypeOther => 'Other';

  @override
  String get documentAlreadyHeld =>
      'This vehicle already has one. Edit that one instead of adding a second.';

  @override
  String get dashboardDocumentsExpiring => 'Paperwork running out';

  @override
  String get maintenanceServiceItems => 'What was done';

  @override
  String get maintenanceRuleServiceType => 'Service type';

  @override
  String get serviceTypeChoose => 'Choose a service type';

  @override
  String get serviceTypeSearch => 'Search';

  @override
  String get serviceTypeCommon => 'Common';

  @override
  String get serviceTypeOthers => 'Everything else';

  @override
  String get serviceTypeNoMatch => 'Nothing matches';

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
  String get serviceGreenCard => 'Green card expires';

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
  String get plannerAddReminder => 'Add reminder';

  @override
  String get plannerOverdueNote =>
      'Anything overdue sits under today, because today is when it needs doing';

  @override
  String get plannerFurtherOut => 'Further out';

  @override
  String get plannerFurtherOutNote => 'Beyond the twelve weeks, by month.';

  @override
  String plannerWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get dashboardDueSoonest => 'Due soonest';

  @override
  String dashboardNextUp(String what, String when) {
    return 'Next: $what · $when';
  }

  @override
  String dashboardOverdueNow(String what) {
    return 'Overdue: $what';
  }

  @override
  String dashboardDueByDistance(String rate) {
    return 'by distance, about $rate a day';
  }

  @override
  String dashboardDueByDistanceAssumed(String rate) {
    return 'by distance, assuming $rate a day';
  }

  @override
  String get dashboardDueByDateOnly =>
      'by date; a couple of weeks of driving and the distance estimate appears';

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
  String householdInviteActiveUntil(String until) {
    return 'Ready to send · works until $until';
  }

  @override
  String get householdInviteUsed => 'Used';

  @override
  String get householdInviteExpired => 'Expired';

  @override
  String get householdInviteRevoke => 'Revoke';

  @override
  String get householdInviteRevokeTitle => 'Revoke this code?';

  @override
  String get householdInviteRevokeBody =>
      'Whoever has it can no longer join with it. You can make a new one.';

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
  String economyScaleDefault(String best, String worst) {
    return 'The ring runs $best to $worst until this car has a range of its own';
  }

  @override
  String get maintenanceLastDone => 'Last done (optional)';

  @override
  String get maintenanceLastDoneHint =>
      'If you have already done this, say when: intervals count from there instead of from when the vehicle was added';

  @override
  String get maintenanceLastDoneDate => 'Date it was done';

  @override
  String get maintenanceLastDoneDatePick => 'Pick a date';

  @override
  String get maintenanceLastDoneKm => 'Odometer when done';

  @override
  String maintenanceLastDoneFromLog(String date) {
    return 'Taken from the service you logged on $date';
  }

  @override
  String get runningCostTitle => 'What this vehicle costs';

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
  String get runningCostSpread =>
      'Yearly cover such as insurance and registration is spread over its year for the per-month and per-year figures.';

  @override
  String runningCostToOwn(String rate) {
    return '$rate to own, with the value it has lost';
  }

  @override
  String get runningCostValuationStale =>
      'Based on a valuation over a year old — update it on the vehicle\'s page.';

  @override
  String get runningCostOwnership => 'Cost of ownership so far';

  @override
  String get runningCostNotEnough =>
      'Log some fuel and costs to see what this vehicle costs to run';

  @override
  String get runningCostNeedsTank =>
      'One more full tank and the cost per distance appears';

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
  String get settingsDataBringIn => 'Bring data in';

  @override
  String get settingsDataTakeOut => 'Take data out';

  @override
  String get settingsForDevelopers => 'For developers';

  @override
  String get settingsFillUps => 'Fill-ups';

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
      'Adds one vehicle with a year of fill-ups, services and costs, so every screen has something to show. Remove it with Settings → Delete all data.';

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
  String get gettingStartedFirstVehicle => 'Add your first vehicle';

  @override
  String get gettingStartedImport => 'Import from another app';

  @override
  String get gettingStartedTransfer => 'Receive a vehicle with a code';

  @override
  String get gettingStartedNext => 'What next';

  @override
  String get gettingStartedFuel => 'Log a fill-up';

  @override
  String get gettingStartedReminder =>
      'Set a reminder: what it needs, and when';

  @override
  String get gettingStartedSample => 'Or load sample data to look around first';

  @override
  String get gettingStartedTour => 'See everything Garage can do';

  @override
  String get gettingStartedHide => 'Hide';

  @override
  String get featuresTitle => 'What Garage can do';

  @override
  String get featuresHint =>
      'A one-page tour of the main things, and where each one lives';

  @override
  String get featureAddVehicle => 'Add a vehicle';

  @override
  String get featureAddVehicleBlurb =>
      'A car, a motorcycle or a van. Type the VIN and the make, model and year fill themselves in.';

  @override
  String get featureFuel => 'Fuel log';

  @override
  String get featureFuelBlurb =>
      'Log a fill-up in seconds from the dashboard. Consumption, cost per kilometre and how far the tank still goes follow on their own.';

  @override
  String get featurePlannerBlurb =>
      'What each vehicle needs next, week by week, and which jobs are worth bundling into one visit to the shop.';

  @override
  String get featureTimelineBlurb =>
      'Everything that happened to every vehicle, month by month, with what each month came to.';

  @override
  String get featureStatsBlurb =>
      'Consumption, spend and distance over any period, per vehicle or for the whole garage.';

  @override
  String get featureStationsBlurb =>
      'Today\'s fuel prices nearby, and whether they rose or fell this week.';

  @override
  String get featureTripsBlurb =>
      'Log private and business trips; the distance comes from the odometer.';

  @override
  String get featureCalculatorBlurb =>
      'Trip cost, range or consumption from the numbers you have.';

  @override
  String get featureTyres => 'Tyres';

  @override
  String get featureTyresBlurb =>
      'Tyre sets, the seasonal swap, tread depth and age, on each vehicle\'s page.';

  @override
  String get featureDocuments => 'Documents';

  @override
  String get featureDocumentsBlurb =>
      'Registration, roadworthiness, insurance and the green card, each with the date it runs out — and a reminder before it does.';

  @override
  String get featureReceipts => 'Receipts and invoices';

  @override
  String get featureReceiptsBlurb =>
      'Attach the pump receipt or the shop invoice to its entry once it is saved, and find it years later when you sell the car.';

  @override
  String get featureShare => 'Share the garage';

  @override
  String get featureShareBlurb =>
      'Invite whoever shares the car. Everyone sees the same log, and the costs are split.';

  @override
  String get featureLend => 'Lend a car';

  @override
  String get featureLendBlurb =>
      'Give somebody a code and they can log fuel and drives on one car for a few days, without joining your garage or seeing your history.';

  @override
  String get featureData => 'Import, export and backup';

  @override
  String get featureDataBlurb =>
      'Bring your history from Fuelio or any CSV; export it or back it all up any time.';

  @override
  String get featureApiBlurb =>
      'Read your own data from a script or a spreadsheet with a key.';

  @override
  String get odometerTitle => 'Odometer';

  @override
  String get odometerAdd => 'Log a reading';

  @override
  String get odometerEdit => 'Edit reading';

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
  String get tripsTitle => 'Trips';

  @override
  String get tripAdd => 'Log a trip';

  @override
  String get tripEdit => 'Edit trip';

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
  String tripImpliedSpeed(String speed) {
    return 'That works out at $speed — check the distance and the time';
  }

  @override
  String get tripDriver => 'Driver';

  @override
  String get tripDriverHint =>
      'Who was at the wheel — a mileage logbook for tax names them, and it is not always whoever typed the entry.';

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
  String get tripDriveStart => 'Start a drive';

  @override
  String get tripDriveInProgress => 'Drive in progress';

  @override
  String tripDriveSince(String time) {
    return 'Set off at $time';
  }

  @override
  String tripDriveElapsed(String duration) {
    return '$duration so far';
  }

  @override
  String get tripDriveFinish => 'Finish drive';

  @override
  String get tripDriveDiscard => 'Discard';

  @override
  String get tripDriveDiscardConfirm =>
      'Discard this drive? Nothing will be logged for it.';

  @override
  String get tripDriveOdometerNow => 'Odometer now';

  @override
  String get tripDriveOdometerNowHint =>
      'What the dashboard reads. Leave it blank if you cannot see it.';

  @override
  String get tripDriveStarted => 'Drive started. Finish it when you park.';

  @override
  String tripDriveFinished(String distance) {
    return 'Drive logged: $distance';
  }

  @override
  String get tripDriveAlreadyOpen => 'That car is already out on a drive.';

  @override
  String get tripDriveNeedsMeasure => 'Enter the odometer now, or a distance.';

  @override
  String tripDriveStartedBy(String name) {
    return 'Started by $name';
  }

  @override
  String get quickAddTrip => 'Trip';

  @override
  String get incomeTitle => 'Income';

  @override
  String get incomeAdd => 'Add income';

  @override
  String get incomeEdit => 'Edit income';

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
  String get quickAddMore => 'More';

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
  String get transferCodeCancel => 'Cancel this transfer';

  @override
  String get transferCodeCancelled =>
      'Transfer cancelled. The code no longer works.';

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
  String get transferSell => 'Sold the vehicle?';

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
  String get vehicleSecondFuelNone => 'No second fuel';

  @override
  String get vehicleKind => 'Vehicle type';

  @override
  String get vehicleSectionEngine => 'Engine and fuel';

  @override
  String get vehicleSectionOptional => 'Optional details';

  @override
  String get vehicleKindCar => 'Car';

  @override
  String get vehicleKindMotorcycle => 'Motorcycle';

  @override
  String get vehicleKindVan => 'Van';

  @override
  String get vehicleFinalDrive => 'Final drive';

  @override
  String get vehicleFinalDriveNotSet => 'Not set';

  @override
  String get finalDriveChain => 'Chain';

  @override
  String get finalDriveBelt => 'Belt';

  @override
  String get finalDriveShaft => 'Shaft';

  @override
  String get vehicleTimingDrive => 'Timing belt or chain';

  @override
  String get vehicleTimingDriveNotSet => 'Don\'t know';

  @override
  String get vehicleTimingDriveHint =>
      'Belt-in-oil: PureTech, EcoBoost, 1.0 TCe — the belt runs in the engine oil';

  @override
  String get timingDriveBelt => 'Belt';

  @override
  String get timingDriveChain => 'Chain';

  @override
  String get timingDriveWetBelt => 'Belt-in-oil';

  @override
  String get vehicleTransmission => 'Gearbox';

  @override
  String get vehicleTransmissionNotSet => 'Not set';

  @override
  String get transmissionManual => 'Manual';

  @override
  String get transmissionAutomatic => 'Automatic';

  @override
  String get transmissionDctDry => 'Dual-clutch, dry';

  @override
  String get transmissionDctWet => 'Dual-clutch, wet';

  @override
  String get transmissionCvt => 'CVT';

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
  String get settingsExportHint =>
      'A zip of spreadsheets, one file per car and per kind. Readable anywhere; use a backup to restore.';

  @override
  String get settingsImportCsvHint =>
      'From Drivvo, a spreadsheet, or anything else that exports a table. Adds what is missing; nothing is overwritten.';

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
  String settingsBackupDone(String file) {
    return 'Backup saved: $file';
  }

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
  String get commonClose => 'Close';

  @override
  String get householdInviteCopyManually =>
      'Copy this message and send it however you like.';

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
  String get quickAddInterval => 'Add reminder';

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
  String get timelineSearchCovers =>
      'Search covers the kind of entry, the car, who logged it, the date and the notes.';

  @override
  String get timelineFilterVehicle => 'Vehicle';

  @override
  String timelineBalanceNet(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions, balance $amount',
      one: '$count transaction, balance $amount',
    );
    return '$_temp0';
  }

  @override
  String timelineBalanceSpent(String amount, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions, spent $amount',
      one: '$count transaction, spent $amount',
    );
    return '$_temp0';
  }

  @override
  String timelineBalanceReceived(String amount, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions, received $amount',
      one: '$count transaction, received $amount',
    );
    return '$_temp0';
  }

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
  String get serviceChainLube => 'Chain lubrication and adjustment';

  @override
  String get serviceChainSprockets => 'Chain and sprockets';

  @override
  String get serviceForkOil => 'Fork oil';

  @override
  String get serviceValveClearance => 'Valve clearance';

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

  @override
  String get guestLendTitle => 'Lend this car';

  @override
  String get guestLendIntro =>
      'Give somebody a code and they can log against this car — and nothing else — until it runs out. They do not join your garage and cannot see anything you logged.';

  @override
  String get guestLendDays => 'For how many days';

  @override
  String get guestLendLabel => 'Who is it for';

  @override
  String get guestLendLabelHint =>
      'Just for your own reference — they never see it.';

  @override
  String get guestLendAllowFuel => 'Log fill-ups';

  @override
  String get guestLendAllowTrips => 'Log drives';

  @override
  String get guestLendAllowCosts => 'Log costs and services';

  @override
  String get guestLendAllowHistory => 'See this car\'s earlier history';

  @override
  String get guestLendAllowHistoryHint =>
      'Off by default: they see only what they logged themselves.';

  @override
  String get guestLendAction => 'Create a code';

  @override
  String get guestLendCreated => 'Hand over this code';

  @override
  String get guestLendCopy => 'Copy code';

  @override
  String get guestLendCopied => 'Code copied';

  @override
  String get guestPassesTitle => 'Lending';

  @override
  String get guestPassesEmpty => 'This car has never been lent out.';

  @override
  String get guestPassesLive => 'In use';

  @override
  String get guestPassesWaiting => 'Not claimed yet';

  @override
  String get guestPassesNotStarted => 'Starts later';

  @override
  String get guestPassesExpired => 'Finished';

  @override
  String get guestPassesRevoked => 'Withdrawn';

  @override
  String guestPassRemaining(int days) {
    return '$days days left';
  }

  @override
  String get guestPassEndsToday => 'Ends today';

  @override
  String get guestPassRevoke => 'Withdraw';

  @override
  String get guestPassRevokeConfirm =>
      'Withdraw this code? They lose access immediately. Everything they logged stays.';

  @override
  String get guestRedeemTitle => 'Use a car someone lent you';

  @override
  String get guestRedeemIntro =>
      'Enter the code they gave you. You will be able to log against their car until it runs out.';

  @override
  String get guestRedeemAction => 'Use the code';

  @override
  String get guestRedeemDone => 'You can now log against that car.';

  @override
  String get guestRedeemFailed =>
      'That code does not work. It may have expired, been withdrawn, or already be in use.';

  @override
  String get guestBorrowedBadge => 'Lent to you';

  @override
  String guestBorrowedUntil(String date) {
    return 'Yours until $date';
  }

  @override
  String get guestHistoryHidden =>
      'You are seeing only what you logged. The owner\'s earlier entries stay private.';

  @override
  String get householdMakeAdmin => 'Make admin';

  @override
  String get householdRemoveAdmin => 'Remove admin';

  @override
  String householdRoleChanged(String name) {
    return '$name is now an admin';
  }

  @override
  String householdRoleRemoved(String name) {
    return '$name is no longer an admin';
  }

  @override
  String get householdLastAdminKept =>
      'A garage always keeps an admin, so the role passed to the next longest-standing member.';

  @override
  String get householdMergeTitle => 'Merge another garage into this one';

  @override
  String get householdMergeIntro =>
      'Every vehicle, its whole history and everyone in the other garage move here. The other garage is then deleted. This cannot be undone.';

  @override
  String get householdMergeNone => 'You are not an admin of any other garage.';

  @override
  String get householdMergePick => 'Which garage should move here?';

  @override
  String get householdMergeAction => 'Merge into this garage';

  @override
  String householdMergeConfirm(
    String name,
    String survivor,
    String vehicles,
    String people,
  ) {
    return 'Move everything from $name into $survivor? $vehicles and $people come across, $name is deleted, and this cannot be undone.';
  }

  @override
  String householdMergeVehicleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vehicles',
      one: '1 vehicle',
      zero: 'no vehicles',
    );
    return '$_temp0';
  }

  @override
  String householdMergePeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get householdMergeKeysWarning =>
      'Any API keys and webhooks belonging to the other garage stop working.';

  @override
  String householdMergeDone(String vehicles) {
    return 'Merged. $vehicles moved across.';
  }

  @override
  String householdMergePhotosLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vehicle photos could not be moved.',
      one: 'One vehicle photo could not be moved.',
    );
    return '$_temp0';
  }

  @override
  String householdMergeCurrencyClash(String absorbed, String surviving) {
    return 'These garages keep their money in different currencies ($absorbed and $surviving). Change one to match before merging, or every amount would change meaning.';
  }

  @override
  String get syncPendingTitle => 'Waiting to sync';

  @override
  String syncPendingBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries are waiting to sync',
      one: '1 entry is waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get syncPendingIntro =>
      'These were saved on your phone when there was no connection. They will be sent on their own the next time there is one.';

  @override
  String get syncPendingEmpty => 'Everything has been sent.';

  @override
  String get syncRetryNow => 'Try now';

  @override
  String get syncEntryQueued =>
      'Saved on your phone. It will sync when you have a signal.';

  @override
  String syncSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries synced',
      one: '1 entry synced',
    );
    return '$_temp0';
  }

  @override
  String get syncStillWaiting => 'Still no connection. Nothing was lost.';

  @override
  String syncDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries could not be saved and were removed',
      one: '1 entry could not be saved and was removed',
    );
    return '$_temp0';
  }

  @override
  String get syncKindFuel => 'Fill-up';

  @override
  String get syncKindOdometer => 'Odometer reading';

  @override
  String syncQueuedAt(String when) {
    return 'Typed $when';
  }

  @override
  String get syncPhotoQueued =>
      'Photo saved on your phone. It will upload when you have a signal.';

  @override
  String get syncKindAttachment => 'Photo';
}
