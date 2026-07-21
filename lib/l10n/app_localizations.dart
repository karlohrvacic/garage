import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hr'),
  ];

  /// Application name, shown in the app bar and task switcher
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get appTitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get commonEmpty;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNoConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your network and retry.'**
  String get errorNoConnection;

  /// No description provided for @errorPermission.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to that.'**
  String get errorPermission;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'That could not be found.'**
  String get errorNotFound;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'That already exists.'**
  String get errorConflict;

  /// No description provided for @errorExpired.
  ///
  /// In en, this message translates to:
  /// **'That invite code has expired.'**
  String get errorExpired;

  /// No description provided for @errorAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'That invite code has already been used.'**
  String get errorAlreadyUsed;

  /// No description provided for @errorAuth.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check your email and password.'**
  String get errorAuth;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInTitle;

  /// No description provided for @authSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUpTitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authDisplayName;

  /// No description provided for @authSignInAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInAction;

  /// No description provided for @authSignUpAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignUpAction;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account? Create one'**
  String get authNoAccount;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authHaveAccount;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authResetSent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a reset link.'**
  String get authResetSent;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authNameRequired;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your garage'**
  String get onboardingTitle;

  /// No description provided for @onboardingCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a household'**
  String get onboardingCreateTitle;

  /// No description provided for @onboardingCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone you invite shares these vehicles'**
  String get onboardingCreateHint;

  /// No description provided for @onboardingHouseholdName.
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get onboardingHouseholdName;

  /// No description provided for @onboardingCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get onboardingCreateAction;

  /// No description provided for @onboardingJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get onboardingJoinTitle;

  /// No description provided for @onboardingJoinHint.
  ///
  /// In en, this message translates to:
  /// **'Ask a member for their 8-character invite code'**
  String get onboardingJoinHint;

  /// No description provided for @onboardingInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get onboardingInviteCode;

  /// No description provided for @onboardingJoinAction.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get onboardingJoinAction;

  /// No description provided for @onboardingNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get onboardingNameRequired;

  /// No description provided for @onboardingCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-character code'**
  String get onboardingCodeInvalid;

  /// No description provided for @onboardingSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get onboardingSignOut;

  /// No description provided for @vehiclesTitle.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehiclesTitle;

  /// No description provided for @vehiclesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add your first vehicle to start logging'**
  String get vehiclesEmpty;

  /// No description provided for @vehiclesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get vehiclesAdd;

  /// No description provided for @vehicleNickname.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get vehicleNickname;

  /// No description provided for @vehicleMake.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get vehicleMake;

  /// No description provided for @vehicleModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get vehicleModel;

  /// No description provided for @vehicleYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get vehicleYear;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get vehiclePlate;

  /// No description provided for @vehicleVin.
  ///
  /// In en, this message translates to:
  /// **'VIN'**
  String get vehicleVin;

  /// No description provided for @vehicleFuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel type'**
  String get vehicleFuelType;

  /// No description provided for @vehicleOdometer.
  ///
  /// In en, this message translates to:
  /// **'Current odometer'**
  String get vehicleOdometer;

  /// No description provided for @vehicleArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vehicleArchive;

  /// No description provided for @vehicleArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vehicleArchived;

  /// No description provided for @vehicleSearch.
  ///
  /// In en, this message translates to:
  /// **'Search vehicles'**
  String get vehicleSearch;

  /// No description provided for @vehicleTabEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get vehicleTabEconomy;

  /// No description provided for @vehicleTabMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get vehicleTabMaintenance;

  /// No description provided for @vehicleTabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get vehicleTabHistory;

  /// No description provided for @vehicleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get vehicleEdit;

  /// No description provided for @vehicleNoEconomyYet.
  ///
  /// In en, this message translates to:
  /// **'Log two full-tank fills to see economy'**
  String get vehicleNoEconomyYet;

  /// No description provided for @vehicleNoHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No services logged yet'**
  String get vehicleNoHistoryYet;

  /// No description provided for @vehicleLastService.
  ///
  /// In en, this message translates to:
  /// **'Last service {date}'**
  String vehicleLastService(String date);

  /// No description provided for @fuelPetrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get fuelPetrol;

  /// No description provided for @fuelDiesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get fuelDiesel;

  /// No description provided for @fuelLpg.
  ///
  /// In en, this message translates to:
  /// **'LPG'**
  String get fuelLpg;

  /// No description provided for @fuelElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get fuelElectric;

  /// No description provided for @fuelHybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid'**
  String get fuelHybrid;

  /// No description provided for @fuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get fuelTitle;

  /// No description provided for @fuelEmpty.
  ///
  /// In en, this message translates to:
  /// **'Log a fill-up to start tracking economy'**
  String get fuelEmpty;

  /// No description provided for @fuelAdd.
  ///
  /// In en, this message translates to:
  /// **'Add fill-up'**
  String get fuelAdd;

  /// No description provided for @fuelDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fuelDate;

  /// No description provided for @fuelOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get fuelOdometer;

  /// No description provided for @fuelVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get fuelVolume;

  /// No description provided for @fuelPricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Price per unit'**
  String get fuelPricePerUnit;

  /// No description provided for @fuelTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get fuelTotal;

  /// No description provided for @fuelFullTank.
  ///
  /// In en, this message translates to:
  /// **'Filled to full'**
  String get fuelFullTank;

  /// No description provided for @fuelFullTankHint.
  ///
  /// In en, this message translates to:
  /// **'Economy is calculated between full tanks'**
  String get fuelFullTankHint;

  /// No description provided for @fuelMissedFill.
  ///
  /// In en, this message translates to:
  /// **'I missed logging a fill before this one'**
  String get fuelMissedFill;

  /// No description provided for @fuelMissedFillHint.
  ///
  /// In en, this message translates to:
  /// **'Breaks the calculation chain so no wrong figure is shown'**
  String get fuelMissedFillHint;

  /// No description provided for @fuelStation.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get fuelStation;

  /// No description provided for @fuelNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fuelNotes;

  /// No description provided for @fuelAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get fuelAverage;

  /// No description provided for @fuelNeedTwoValues.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two of volume, price, and total'**
  String get fuelNeedTwoValues;

  /// No description provided for @fuelOdometerTooLow.
  ///
  /// In en, this message translates to:
  /// **'Lower than the previous reading of {previous}'**
  String fuelOdometerTooLow(String previous);

  /// No description provided for @fuelEconomyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not enough full-tank fills to calculate'**
  String get fuelEconomyUnavailable;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add an interval to start tracking what is due'**
  String get maintenanceEmpty;

  /// No description provided for @maintenanceAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add interval'**
  String get maintenanceAddRule;

  /// No description provided for @maintenanceLogService.
  ///
  /// In en, this message translates to:
  /// **'Log service'**
  String get maintenanceLogService;

  /// No description provided for @maintenanceIntervalKm.
  ///
  /// In en, this message translates to:
  /// **'Every (distance)'**
  String get maintenanceIntervalKm;

  /// No description provided for @maintenanceIntervalMonths.
  ///
  /// In en, this message translates to:
  /// **'Every (months)'**
  String get maintenanceIntervalMonths;

  /// No description provided for @maintenanceIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'Set either or both. Whichever comes first wins.'**
  String get maintenanceIntervalHint;

  /// No description provided for @maintenanceDueAt.
  ///
  /// In en, this message translates to:
  /// **'Due at {odometer}'**
  String maintenanceDueAt(String odometer);

  /// No description provided for @maintenanceDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String maintenanceDueOn(String date);

  /// No description provided for @maintenanceNeedsInterval.
  ///
  /// In en, this message translates to:
  /// **'Set a distance or a time interval'**
  String get maintenanceNeedsInterval;

  /// No description provided for @maintenanceServiceDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get maintenanceServiceDate;

  /// No description provided for @maintenanceServiceCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get maintenanceServiceCost;

  /// No description provided for @maintenanceServiceShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get maintenanceServiceShop;

  /// No description provided for @maintenanceServiceItems.
  ///
  /// In en, this message translates to:
  /// **'What was done'**
  String get maintenanceServiceItems;

  /// No description provided for @maintenanceCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get maintenanceCalendar;

  /// No description provided for @maintenanceList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get maintenanceList;

  /// No description provided for @serviceOilChange.
  ///
  /// In en, this message translates to:
  /// **'Oil change'**
  String get serviceOilChange;

  /// No description provided for @serviceOilFilter.
  ///
  /// In en, this message translates to:
  /// **'Oil filter'**
  String get serviceOilFilter;

  /// No description provided for @serviceAirFilter.
  ///
  /// In en, this message translates to:
  /// **'Air filter'**
  String get serviceAirFilter;

  /// No description provided for @serviceCabinFilter.
  ///
  /// In en, this message translates to:
  /// **'Cabin filter'**
  String get serviceCabinFilter;

  /// No description provided for @serviceSparkPlugs.
  ///
  /// In en, this message translates to:
  /// **'Spark plugs'**
  String get serviceSparkPlugs;

  /// No description provided for @serviceBrakeFluid.
  ///
  /// In en, this message translates to:
  /// **'Brake fluid'**
  String get serviceBrakeFluid;

  /// No description provided for @serviceBrakePadsFront.
  ///
  /// In en, this message translates to:
  /// **'Front brake pads'**
  String get serviceBrakePadsFront;

  /// No description provided for @serviceBrakePadsRear.
  ///
  /// In en, this message translates to:
  /// **'Rear brake pads'**
  String get serviceBrakePadsRear;

  /// No description provided for @serviceTimingBelt.
  ///
  /// In en, this message translates to:
  /// **'Timing belt'**
  String get serviceTimingBelt;

  /// No description provided for @serviceCoolant.
  ///
  /// In en, this message translates to:
  /// **'Coolant'**
  String get serviceCoolant;

  /// No description provided for @serviceTransmissionOil.
  ///
  /// In en, this message translates to:
  /// **'Transmission oil'**
  String get serviceTransmissionOil;

  /// No description provided for @serviceTireRotation.
  ///
  /// In en, this message translates to:
  /// **'Tire rotation'**
  String get serviceTireRotation;

  /// No description provided for @serviceTireSwapSeasonal.
  ///
  /// In en, this message translates to:
  /// **'Seasonal tire swap'**
  String get serviceTireSwapSeasonal;

  /// No description provided for @serviceBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get serviceBattery;

  /// No description provided for @serviceWipers.
  ///
  /// In en, this message translates to:
  /// **'Wiper blades'**
  String get serviceWipers;

  /// No description provided for @serviceRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get serviceRegistration;

  /// No description provided for @serviceTechnicalInspection.
  ///
  /// In en, this message translates to:
  /// **'Technical inspection'**
  String get serviceTechnicalInspection;

  /// No description provided for @serviceInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get serviceInsurance;

  /// No description provided for @maintenanceStateUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get maintenanceStateUpcoming;

  /// No description provided for @maintenanceStateDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get maintenanceStateDue;

  /// No description provided for @maintenanceStateOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get maintenanceStateOverdue;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get dashboardTitle;

  /// No description provided for @plannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get plannerTitle;

  /// No description provided for @plannerRunway.
  ///
  /// In en, this message translates to:
  /// **'Next 12 weeks'**
  String get plannerRunway;

  /// No description provided for @plannerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing due in the next 12 weeks'**
  String get plannerEmpty;

  /// No description provided for @plannerOverdueNote.
  ///
  /// In en, this message translates to:
  /// **'Overdue items are shown at today, because that is when they need doing'**
  String get plannerOverdueNote;

  /// No description provided for @plannerWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String plannerWeekOf(String date);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @dashboardNoBundles.
  ///
  /// In en, this message translates to:
  /// **'Nothing to bundle right now'**
  String get dashboardNoBundles;

  /// No description provided for @dashboardDueSoonest.
  ///
  /// In en, this message translates to:
  /// **'Due soonest'**
  String get dashboardDueSoonest;

  /// No description provided for @dashboardVehicleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 vehicle} other{{count} vehicles}}'**
  String dashboardVehicleCount(int count);

  /// No description provided for @bundleVisitOn.
  ///
  /// In en, this message translates to:
  /// **'One visit on {date}'**
  String bundleVisitOn(String date);

  /// No description provided for @bundleSpanDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days apart'**
  String bundleSpanDays(int days);

  /// No description provided for @bundleExclude.
  ///
  /// In en, this message translates to:
  /// **'Not this one'**
  String get bundleExclude;

  /// No description provided for @bundleExplain.
  ///
  /// In en, this message translates to:
  /// **'These fall due close together — doing them in one visit saves a second trip'**
  String get bundleExplain;

  /// No description provided for @notificationDueTitle.
  ///
  /// In en, this message translates to:
  /// **'{service} is due'**
  String notificationDueTitle(String service);

  /// No description provided for @notificationBundleTitle.
  ///
  /// In en, this message translates to:
  /// **'{count} items due together'**
  String notificationBundleTitle(int count);

  /// No description provided for @notificationBundleBody.
  ///
  /// In en, this message translates to:
  /// **'Book one visit and save a second trip'**
  String get notificationBundleBody;

  /// Headline of the maintenance bundling suggestion card
  ///
  /// In en, this message translates to:
  /// **'Bundle {count} items into one visit'**
  String bundleSuggestionTitle(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hr':
      return AppLocalizationsHr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
