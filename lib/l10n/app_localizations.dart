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

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Fuel and maintenance, on record.'**
  String get authTagline;

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

  /// No description provided for @authSetNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get authSetNewPasswordTitle;

  /// No description provided for @authPasswordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated.'**
  String get authPasswordUpdated;

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
  /// **'Create a garage'**
  String get onboardingCreateTitle;

  /// No description provided for @onboardingCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Everyone you invite shares these vehicles'**
  String get onboardingCreateHint;

  /// No description provided for @onboardingHouseholdName.
  ///
  /// In en, this message translates to:
  /// **'Garage name'**
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
  /// **'Ask someone in the garage for their 8-character invite code'**
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

  /// No description provided for @joinTitle.
  ///
  /// In en, this message translates to:
  /// **'Join a garage'**
  String get joinTitle;

  /// No description provided for @joinInvited.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to share a garage. Sign in, or create an account, and you will join with this invite.'**
  String get joinInvited;

  /// No description provided for @joinJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get joinJoining;

  /// No description provided for @joinDone.
  ///
  /// In en, this message translates to:
  /// **'You are in. Everything the garage logs is now yours too.'**
  String get joinDone;

  /// No description provided for @joinOpenGarage.
  ///
  /// In en, this message translates to:
  /// **'Open my garage'**
  String get joinOpenGarage;

  /// No description provided for @householdShareInvite.
  ///
  /// In en, this message translates to:
  /// **'Share invite link'**
  String get householdShareInvite;

  /// No description provided for @householdInviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get householdInviteLinkCopied;

  /// No description provided for @householdTitle.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get householdTitle;

  /// No description provided for @householdMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get householdMembers;

  /// No description provided for @householdInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite someone'**
  String get householdInvite;

  /// No description provided for @householdCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get householdCopyCode;

  /// No description provided for @householdCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get householdCopied;

  /// No description provided for @householdLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave garage'**
  String get householdLeave;

  /// No description provided for @householdLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Leave this garage? You will lose access to its vehicles.'**
  String get householdLeaveConfirm;

  /// No description provided for @householdSpend.
  ///
  /// In en, this message translates to:
  /// **'Shared spend'**
  String get householdSpend;

  /// No description provided for @householdSpendHint.
  ///
  /// In en, this message translates to:
  /// **'Everything logged against this garage’s vehicles, by whoever logged it'**
  String get householdSpendHint;

  /// No description provided for @householdUnattributed.
  ///
  /// In en, this message translates to:
  /// **'From a deleted account: {amount}'**
  String householdUnattributed(String amount);

  /// No description provided for @householdShareEach.
  ///
  /// In en, this message translates to:
  /// **'Even share: {amount}'**
  String householdShareEach(String amount);

  /// No description provided for @householdSettled.
  ///
  /// In en, this message translates to:
  /// **'All square'**
  String get householdSettled;

  /// No description provided for @householdOwes.
  ///
  /// In en, this message translates to:
  /// **'{from} owes {to} {amount}'**
  String householdOwes(String from, String to, String amount);

  /// No description provided for @householdRemoveMember.
  ///
  /// In en, this message translates to:
  /// **'Remove from garage'**
  String get householdRemoveMember;

  /// No description provided for @householdRoleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get householdRoleAdmin;

  /// No description provided for @householdRoleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get householdRoleMember;

  /// No description provided for @settingsUnits.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get settingsUnits;

  /// No description provided for @settingsUnitsHint.
  ///
  /// In en, this message translates to:
  /// **'How distances, volumes and prices are shown'**
  String get settingsUnitsHint;

  /// No description provided for @settingsDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get settingsDistance;

  /// No description provided for @settingsVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get settingsVolume;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @calculatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get calculatorTitle;

  /// No description provided for @calcModeTripCost.
  ///
  /// In en, this message translates to:
  /// **'Trip cost'**
  String get calcModeTripCost;

  /// No description provided for @calcModeDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get calcModeDistance;

  /// No description provided for @calcModeConsumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get calcModeConsumption;

  /// No description provided for @calcModeRequiredFuel.
  ///
  /// In en, this message translates to:
  /// **'Required fuel'**
  String get calcModeRequiredFuel;

  /// No description provided for @calcConsumption.
  ///
  /// In en, this message translates to:
  /// **'Consumption'**
  String get calcConsumption;

  /// No description provided for @calcResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get calcResult;

  /// No description provided for @stationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuel stations'**
  String get stationsTitle;

  /// No description provided for @stationsFuelPetrol.
  ///
  /// In en, this message translates to:
  /// **'Petrol'**
  String get stationsFuelPetrol;

  /// No description provided for @stationsFuelDiesel.
  ///
  /// In en, this message translates to:
  /// **'Diesel'**
  String get stationsFuelDiesel;

  /// No description provided for @stationsFuelLpg.
  ///
  /// In en, this message translates to:
  /// **'LPG'**
  String get stationsFuelLpg;

  /// No description provided for @stationsAttribution.
  ///
  /// In en, this message translates to:
  /// **'Prices: mzoe-gor.hr (Ministry of Economy)'**
  String get stationsAttribution;

  /// No description provided for @stationsOpenMap.
  ///
  /// In en, this message translates to:
  /// **'Open in maps'**
  String get stationsOpenMap;

  /// No description provided for @stationsNoLocation.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable — sorted by price.'**
  String get stationsNoLocation;

  /// No description provided for @stationsFavourite.
  ///
  /// In en, this message translates to:
  /// **'Favourite'**
  String get stationsFavourite;

  /// No description provided for @stationsAvgNearby.
  ///
  /// In en, this message translates to:
  /// **'Average nearby'**
  String get stationsAvgNearby;

  /// No description provided for @stationsNationalAvg.
  ///
  /// In en, this message translates to:
  /// **'National average'**
  String get stationsNationalAvg;

  /// No description provided for @stationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stations found.'**
  String get stationsEmpty;

  /// No description provided for @stationsOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Fuel prices come from the Croatian ministry\'s open data, so this only helps inside Croatia. The nearest station on record is {distance} away.'**
  String stationsOutOfRange(String distance);

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTitle;

  /// No description provided for @timelineEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet.'**
  String get timelineEmpty;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @statsTabFillUps.
  ///
  /// In en, this message translates to:
  /// **'Fill-ups'**
  String get statsTabFillUps;

  /// No description provided for @statsTabCosts.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get statsTabCosts;

  /// No description provided for @statsTabDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get statsTabDistance;

  /// No description provided for @statsAllVehicles.
  ///
  /// In en, this message translates to:
  /// **'All vehicles'**
  String get statsAllVehicles;

  /// No description provided for @commonVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get commonVehicle;

  /// No description provided for @statsThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get statsThisYear;

  /// No description provided for @statsPreviousYear.
  ///
  /// In en, this message translates to:
  /// **'Previous year'**
  String get statsPreviousYear;

  /// No description provided for @statsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get statsThisMonth;

  /// No description provided for @statsPreviousMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get statsPreviousMonth;

  /// No description provided for @statsFillUps.
  ///
  /// In en, this message translates to:
  /// **'Fill-ups'**
  String get statsFillUps;

  /// No description provided for @statsFuelVolume.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get statsFuelVolume;

  /// No description provided for @statsMinFill.
  ///
  /// In en, this message translates to:
  /// **'Smallest fill'**
  String get statsMinFill;

  /// No description provided for @statsMaxFill.
  ///
  /// In en, this message translates to:
  /// **'Largest fill'**
  String get statsMaxFill;

  /// No description provided for @statsAvgEconomy.
  ///
  /// In en, this message translates to:
  /// **'Average consumption'**
  String get statsAvgEconomy;

  /// No description provided for @statsBestEconomy.
  ///
  /// In en, this message translates to:
  /// **'Best consumption'**
  String get statsBestEconomy;

  /// No description provided for @statsWorstEconomy.
  ///
  /// In en, this message translates to:
  /// **'Worst consumption'**
  String get statsWorstEconomy;

  /// No description provided for @statsTotalWithFuel.
  ///
  /// In en, this message translates to:
  /// **'Costs (with fuel)'**
  String get statsTotalWithFuel;

  /// No description provided for @statsTotalWithoutFuel.
  ///
  /// In en, this message translates to:
  /// **'Costs (without fuel)'**
  String get statsTotalWithoutFuel;

  /// No description provided for @statsFuelOnly.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get statsFuelOnly;

  /// No description provided for @statsLowestBill.
  ///
  /// In en, this message translates to:
  /// **'Lowest bill'**
  String get statsLowestBill;

  /// No description provided for @statsHighestBill.
  ///
  /// In en, this message translates to:
  /// **'Highest bill'**
  String get statsHighestBill;

  /// No description provided for @statsBestFuelPrice.
  ///
  /// In en, this message translates to:
  /// **'Best fuel price'**
  String get statsBestFuelPrice;

  /// No description provided for @statsWorstFuelPrice.
  ///
  /// In en, this message translates to:
  /// **'Worst fuel price'**
  String get statsWorstFuelPrice;

  /// No description provided for @statsAvgCost.
  ///
  /// In en, this message translates to:
  /// **'Average cost'**
  String get statsAvgCost;

  /// No description provided for @statsAvgPerDay.
  ///
  /// In en, this message translates to:
  /// **'Average per day'**
  String get statsAvgPerDay;

  /// No description provided for @statsAvgPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Average per month'**
  String get statsAvgPerMonth;

  /// No description provided for @statsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get statsCategories;

  /// No description provided for @statsDistanceTracked.
  ///
  /// In en, this message translates to:
  /// **'Distance tracked'**
  String get statsDistanceTracked;

  /// No description provided for @statsLastOdometer.
  ///
  /// In en, this message translates to:
  /// **'Last odometer'**
  String get statsLastOdometer;

  /// No description provided for @statsCharts.
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get statsCharts;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet.'**
  String get statsEmpty;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get confirmDeleteBody;

  /// No description provided for @settingsImportFuelio.
  ///
  /// In en, this message translates to:
  /// **'Import from Fuelio'**
  String get settingsImportFuelio;

  /// No description provided for @settingsImportFuelioHint.
  ///
  /// In en, this message translates to:
  /// **'Pick the CSV backup exported by Fuelio. Fill-ups, costs, services, and recurring reminders are imported; re-importing skips rows that already exist.'**
  String get settingsImportFuelioHint;

  /// No description provided for @settingsImportVehicle.
  ///
  /// In en, this message translates to:
  /// **'Import into vehicle'**
  String get settingsImportVehicle;

  /// No description provided for @settingsImportRun.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get settingsImportRun;

  /// No description provided for @settingsImportDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {fills} fill-ups, {services} services, {costs} costs, {reminders} reminders.'**
  String settingsImportDone(int fills, int services, int costs, int reminders);

  /// No description provided for @settingsImportSkipped.
  ///
  /// In en, this message translates to:
  /// **'Not recognised, skipped: {titles}'**
  String settingsImportSkipped(String titles);

  /// No description provided for @vehicleCurrentOdometer.
  ///
  /// In en, this message translates to:
  /// **'Current odometer'**
  String get vehicleCurrentOdometer;

  /// No description provided for @dashboardRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get dashboardRecent;

  /// No description provided for @dashboardTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get dashboardTotalSpent;

  /// No description provided for @calendarNothingOn.
  ///
  /// In en, this message translates to:
  /// **'Nothing due on {date}'**
  String calendarNothingOn(String date);

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Create report'**
  String get reportsTitle;

  /// No description provided for @reportSellers.
  ///
  /// In en, this message translates to:
  /// **'Seller\'s report'**
  String get reportSellers;

  /// No description provided for @reportMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance history'**
  String get reportMaintenance;

  /// No description provided for @reportAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual summary'**
  String get reportAnnual;

  /// No description provided for @costsTitle.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get costsTitle;

  /// No description provided for @costAdd.
  ///
  /// In en, this message translates to:
  /// **'Add cost'**
  String get costAdd;

  /// No description provided for @costAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get costAmount;

  /// No description provided for @costCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get costCategory;

  /// No description provided for @costDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get costDate;

  /// No description provided for @costRemindNextYear.
  ///
  /// In en, this message translates to:
  /// **'Remind me when it is due again'**
  String get costRemindNextYear;

  /// No description provided for @costsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No costs logged yet.'**
  String get costsEmpty;

  /// No description provided for @costAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get costAmountRequired;

  /// No description provided for @costCategoryRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get costCategoryRegistration;

  /// No description provided for @costCategoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get costCategoryInsurance;

  /// No description provided for @costCategoryParking.
  ///
  /// In en, this message translates to:
  /// **'Parking'**
  String get costCategoryParking;

  /// No description provided for @costCategoryToll.
  ///
  /// In en, this message translates to:
  /// **'Tolls'**
  String get costCategoryToll;

  /// No description provided for @costCategoryVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get costCategoryVignette;

  /// No description provided for @countryAustria.
  ///
  /// In en, this message translates to:
  /// **'Austria'**
  String get countryAustria;

  /// No description provided for @countryBulgaria.
  ///
  /// In en, this message translates to:
  /// **'Bulgaria'**
  String get countryBulgaria;

  /// No description provided for @countryCzechia.
  ///
  /// In en, this message translates to:
  /// **'Czechia'**
  String get countryCzechia;

  /// No description provided for @countryHungary.
  ///
  /// In en, this message translates to:
  /// **'Hungary'**
  String get countryHungary;

  /// No description provided for @countryRomania.
  ///
  /// In en, this message translates to:
  /// **'Romania'**
  String get countryRomania;

  /// No description provided for @countrySlovakia.
  ///
  /// In en, this message translates to:
  /// **'Slovakia'**
  String get countrySlovakia;

  /// No description provided for @countrySlovenia.
  ///
  /// In en, this message translates to:
  /// **'Slovenia'**
  String get countrySlovenia;

  /// No description provided for @countrySwitzerland.
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get countrySwitzerland;

  /// No description provided for @fuelAtThePump.
  ///
  /// In en, this message translates to:
  /// **'Taken from {station}, {distance} away — change it if you paid a different price'**
  String fuelAtThePump(String station, String distance);

  /// No description provided for @costVignetteCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get costVignetteCountry;

  /// No description provided for @costVignetteValidity.
  ///
  /// In en, this message translates to:
  /// **'Valid for'**
  String get costVignetteValidity;

  /// No description provided for @costVignetteValidityDay1.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get costVignetteValidityDay1;

  /// No description provided for @costVignetteValidityDays7.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get costVignetteValidityDays7;

  /// No description provided for @costVignetteValidityDays10.
  ///
  /// In en, this message translates to:
  /// **'10 days'**
  String get costVignetteValidityDays10;

  /// No description provided for @costVignetteValidityDays30.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get costVignetteValidityDays30;

  /// No description provided for @costVignetteValidityMonths2.
  ///
  /// In en, this message translates to:
  /// **'2 months'**
  String get costVignetteValidityMonths2;

  /// No description provided for @costVignetteValidityDays60.
  ///
  /// In en, this message translates to:
  /// **'60 days'**
  String get costVignetteValidityDays60;

  /// No description provided for @costVignetteValidityYear.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get costVignetteValidityYear;

  /// No description provided for @costVignetteBuy.
  ///
  /// In en, this message translates to:
  /// **'Buy from {operator}'**
  String costVignetteBuy(String operator);

  /// No description provided for @costVignetteExpires.
  ///
  /// In en, this message translates to:
  /// **'Valid through {date}'**
  String costVignetteExpires(String date);

  /// No description provided for @costVignetteRemind.
  ///
  /// In en, this message translates to:
  /// **'Remind me on the last valid day'**
  String get costVignetteRemind;

  /// No description provided for @costCategoryWash.
  ///
  /// In en, this message translates to:
  /// **'Car wash'**
  String get costCategoryWash;

  /// No description provided for @costCategoryFine.
  ///
  /// In en, this message translates to:
  /// **'Fine'**
  String get costCategoryFine;

  /// No description provided for @costCategoryEquipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get costCategoryEquipment;

  /// No description provided for @costCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get costCategoryOther;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsBundling.
  ///
  /// In en, this message translates to:
  /// **'Maintenance bundling'**
  String get settingsBundling;

  /// No description provided for @settingsBundlingWindowDays.
  ///
  /// In en, this message translates to:
  /// **'Group items within (days)'**
  String get settingsBundlingWindowDays;

  /// No description provided for @settingsBundlingWindowKm.
  ///
  /// In en, this message translates to:
  /// **'Group items within (distance)'**
  String get settingsBundlingWindowKm;

  /// No description provided for @settingsBundlingHint.
  ///
  /// In en, this message translates to:
  /// **'Items due close together are suggested as one visit'**
  String get settingsBundlingHint;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsRemindersThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Only this device is notified'**
  String get settingsRemindersThisDevice;

  /// No description provided for @settingsRemindersThisDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'Each phone schedules its own reminders, so somebody who did not set one up will not hear about it.'**
  String get settingsRemindersThisDeviceHint;

  /// No description provided for @settingsRemindersEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone in this garage is notified'**
  String get settingsRemindersEveryone;

  /// No description provided for @settingsRemindersEveryoneHint.
  ///
  /// In en, this message translates to:
  /// **'Reminders are sent from the server, so every member gets them — not only the device that set them up.'**
  String get settingsRemindersEveryoneHint;

  /// No description provided for @settingsRemindersSchedule.
  ///
  /// In en, this message translates to:
  /// **'Sent 30 days and 7 days before, and whenever a reading brings one within 500 km'**
  String get settingsRemindersSchedule;

  /// No description provided for @settingsRemindersScheduleDevice.
  ///
  /// In en, this message translates to:
  /// **'This device sends them at 9:00 in the morning'**
  String get settingsRemindersScheduleDevice;

  /// No description provided for @settingsRemindersScheduleServer.
  ///
  /// In en, this message translates to:
  /// **'The server sends them early each morning'**
  String get settingsRemindersScheduleServer;

  /// No description provided for @settingsCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get settingsCountry;

  /// No description provided for @settingsCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Which registration and inspection items are offered'**
  String get settingsCountryHint;

  /// No description provided for @countryElsewhere.
  ///
  /// In en, this message translates to:
  /// **'Elsewhere'**
  String get countryElsewhere;

  /// No description provided for @settingsTracking.
  ///
  /// In en, this message translates to:
  /// **'Detail level'**
  String get settingsTracking;

  /// No description provided for @settingsTrackingHint.
  ///
  /// In en, this message translates to:
  /// **'How much detail a service entry asks for'**
  String get settingsTrackingHint;

  /// No description provided for @trackingBeginner.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get trackingBeginner;

  /// No description provided for @trackingIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Detailed'**
  String get trackingIntermediate;

  /// No description provided for @trackingAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get trackingAdvanced;

  /// No description provided for @serviceDiy.
  ///
  /// In en, this message translates to:
  /// **'Done at home'**
  String get serviceDiy;

  /// No description provided for @servicePartsCost.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get servicePartsCost;

  /// No description provided for @serviceLaborCost.
  ///
  /// In en, this message translates to:
  /// **'Labour'**
  String get serviceLaborCost;

  /// No description provided for @servicePartsDetail.
  ///
  /// In en, this message translates to:
  /// **'Parts used'**
  String get servicePartsDetail;

  /// No description provided for @serviceWarrantyUntil.
  ///
  /// In en, this message translates to:
  /// **'Warranty until'**
  String get serviceWarrantyUntil;

  /// No description provided for @serviceFaultCodes.
  ///
  /// In en, this message translates to:
  /// **'Fault codes'**
  String get serviceFaultCodes;

  /// No description provided for @serviceFaultCodesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. P0301, P0171'**
  String get serviceFaultCodesHint;

  /// No description provided for @serviceMeasurements.
  ///
  /// In en, this message translates to:
  /// **'Readings'**
  String get serviceMeasurements;

  /// No description provided for @measurementBrakePadFront.
  ///
  /// In en, this message translates to:
  /// **'Front brake pads'**
  String get measurementBrakePadFront;

  /// No description provided for @measurementBrakePadRear.
  ///
  /// In en, this message translates to:
  /// **'Rear brake pads'**
  String get measurementBrakePadRear;

  /// No description provided for @measurementBrakeDiscFront.
  ///
  /// In en, this message translates to:
  /// **'Front discs'**
  String get measurementBrakeDiscFront;

  /// No description provided for @measurementTreadFrontLeft.
  ///
  /// In en, this message translates to:
  /// **'Tread, front left'**
  String get measurementTreadFrontLeft;

  /// No description provided for @measurementTreadFrontRight.
  ///
  /// In en, this message translates to:
  /// **'Tread, front right'**
  String get measurementTreadFrontRight;

  /// No description provided for @measurementTreadRearLeft.
  ///
  /// In en, this message translates to:
  /// **'Tread, rear left'**
  String get measurementTreadRearLeft;

  /// No description provided for @measurementTreadRearRight.
  ///
  /// In en, this message translates to:
  /// **'Tread, rear right'**
  String get measurementTreadRearRight;

  /// No description provided for @measurementBatteryVolts.
  ///
  /// In en, this message translates to:
  /// **'Battery voltage'**
  String get measurementBatteryVolts;

  /// No description provided for @measurementBatteryCca.
  ///
  /// In en, this message translates to:
  /// **'Battery CCA'**
  String get measurementBatteryCca;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsData;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get settingsExport;

  /// No description provided for @settingsExportDone.
  ///
  /// In en, this message translates to:
  /// **'Export ready'**
  String get settingsExportDone;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account. If you are the last member of your garage, its vehicles and all their history are deleted too. This cannot be undone.'**
  String get settingsDeleteConfirmBody;

  /// No description provided for @settingsDeleteConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get settingsDeleteConfirmAction;

  /// No description provided for @apiTitle.
  ///
  /// In en, this message translates to:
  /// **'API access'**
  String get apiTitle;

  /// No description provided for @apiHint.
  ///
  /// In en, this message translates to:
  /// **'A read-only feed of this garage’s data, for your own scripts and dashboards'**
  String get apiHint;

  /// No description provided for @apiNewKey.
  ///
  /// In en, this message translates to:
  /// **'New key'**
  String get apiNewKey;

  /// No description provided for @apiKeyName.
  ///
  /// In en, this message translates to:
  /// **'What is it for?'**
  String get apiKeyName;

  /// No description provided for @apiKeyCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get apiKeyCreate;

  /// No description provided for @apiKeyOnce.
  ///
  /// In en, this message translates to:
  /// **'Copy this key now — it is not shown again'**
  String get apiKeyOnce;

  /// No description provided for @apiKeyRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get apiKeyRevoke;

  /// No description provided for @apiKeyRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get apiKeyRevoked;

  /// No description provided for @apiKeyNeverUsed.
  ///
  /// In en, this message translates to:
  /// **'Never used'**
  String get apiKeyNeverUsed;

  /// No description provided for @apiKeyLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used {date}'**
  String apiKeyLastUsed(String date);

  /// No description provided for @apiWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get apiWebhooks;

  /// No description provided for @apiWebhooksHint.
  ///
  /// In en, this message translates to:
  /// **'Called when something is logged or comes due'**
  String get apiWebhooksHint;

  /// No description provided for @apiWebhookAdd.
  ///
  /// In en, this message translates to:
  /// **'Add webhook'**
  String get apiWebhookAdd;

  /// No description provided for @apiWebhookUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get apiWebhookUrl;

  /// No description provided for @apiWebhookInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an https:// address'**
  String get apiWebhookInvalid;

  /// No description provided for @apiWebhookAddAction.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get apiWebhookAddAction;

  /// No description provided for @apiWebhookFailing.
  ///
  /// In en, this message translates to:
  /// **'Last delivery failed ({status})'**
  String apiWebhookFailing(int status);

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

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

  /// No description provided for @vehicleNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get vehicleNameRequired;

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

  /// No description provided for @vehiclePhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get vehiclePhoto;

  /// No description provided for @vehiclePhotoAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get vehiclePhotoAdd;

  /// No description provided for @vehiclePhotoReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get vehiclePhotoReplace;

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

  /// No description provided for @vehicleDecodeVin.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get vehicleDecodeVin;

  /// No description provided for @vehicleVinNotFound.
  ///
  /// In en, this message translates to:
  /// **'That VIN could not be looked up'**
  String get vehicleVinNotFound;

  /// No description provided for @vehicleVinDecoded.
  ///
  /// In en, this message translates to:
  /// **'Filled in from the VIN registry'**
  String get vehicleVinDecoded;

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

  /// No description provided for @vehicleTankCapacity.
  ///
  /// In en, this message translates to:
  /// **'Tank capacity'**
  String get vehicleTankCapacity;

  /// No description provided for @vehicleTankCapacityHint.
  ///
  /// In en, this message translates to:
  /// **'Optional — flags a fill-up bigger than the tank'**
  String get vehicleTankCapacityHint;

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

  /// No description provided for @recallsTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety recalls'**
  String get recallsTitle;

  /// No description provided for @recallsNone.
  ///
  /// In en, this message translates to:
  /// **'No recalls found for this make, model, and year'**
  String get recallsNone;

  /// No description provided for @recallsCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for recalls'**
  String get recallsCheck;

  /// No description provided for @recallsCaveat.
  ///
  /// In en, this message translates to:
  /// **'From the US NHTSA registry — confirm with a dealer for a European vehicle'**
  String get recallsCaveat;

  /// No description provided for @recallsNeedsDetails.
  ///
  /// In en, this message translates to:
  /// **'Add the make, model, and year to check for recalls'**
  String get recallsNeedsDetails;

  /// No description provided for @tyresTitle.
  ///
  /// In en, this message translates to:
  /// **'Tyre sets'**
  String get tyresTitle;

  /// No description provided for @tyresEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add the sets this vehicle runs on'**
  String get tyresEmpty;

  /// No description provided for @tyresAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a set'**
  String get tyresAdd;

  /// No description provided for @tyresName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tyresName;

  /// No description provided for @tyresSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get tyresSeason;

  /// No description provided for @tyresSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get tyresSize;

  /// No description provided for @tyresStorage.
  ///
  /// In en, this message translates to:
  /// **'Stored at'**
  String get tyresStorage;

  /// No description provided for @tyresFitted.
  ///
  /// In en, this message translates to:
  /// **'On the car'**
  String get tyresFitted;

  /// No description provided for @tyresFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to car'**
  String get tyresFit;

  /// No description provided for @tyresRetire.
  ///
  /// In en, this message translates to:
  /// **'Retire'**
  String get tyresRetire;

  /// No description provided for @tyresRetired.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get tyresRetired;

  /// No description provided for @tyresAddReading.
  ///
  /// In en, this message translates to:
  /// **'Record tread'**
  String get tyresAddReading;

  /// No description provided for @tyresTread.
  ///
  /// In en, this message translates to:
  /// **'Tread'**
  String get tyresTread;

  /// No description provided for @tyresTreadNone.
  ///
  /// In en, this message translates to:
  /// **'No tread recorded'**
  String get tyresTreadNone;

  /// No description provided for @tyresBelowLegal.
  ///
  /// In en, this message translates to:
  /// **'At or below the 1.6 mm legal minimum'**
  String get tyresBelowLegal;

  /// No description provided for @tyresFrontLeft.
  ///
  /// In en, this message translates to:
  /// **'Front left'**
  String get tyresFrontLeft;

  /// No description provided for @tyresFrontRight.
  ///
  /// In en, this message translates to:
  /// **'Front right'**
  String get tyresFrontRight;

  /// No description provided for @tyresRearLeft.
  ///
  /// In en, this message translates to:
  /// **'Rear left'**
  String get tyresRearLeft;

  /// No description provided for @tyresRearRight.
  ///
  /// In en, this message translates to:
  /// **'Rear right'**
  String get tyresRearRight;

  /// No description provided for @tyreSeasonSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer'**
  String get tyreSeasonSummer;

  /// No description provided for @tyreSeasonWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter'**
  String get tyreSeasonWinter;

  /// No description provided for @tyreSeasonAll.
  ///
  /// In en, this message translates to:
  /// **'All-season'**
  String get tyreSeasonAll;

  /// No description provided for @vehicleTabEconomy.
  ///
  /// In en, this message translates to:
  /// **'Economy'**
  String get vehicleTabEconomy;

  /// No description provided for @vehicleTabMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Service'**
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

  /// No description provided for @vehicleTrendNeedsMore.
  ///
  /// In en, this message translates to:
  /// **'Log more full-tank fills to see the trend'**
  String get vehicleTrendNeedsMore;

  /// No description provided for @plannerRestoreExcluded.
  ///
  /// In en, this message translates to:
  /// **'Restore excluded items'**
  String get plannerRestoreExcluded;

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

  /// No description provided for @fuelEnergy.
  ///
  /// In en, this message translates to:
  /// **'Charge (kWh)'**
  String get fuelEnergy;

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

  /// No description provided for @attachmentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachmentsTitle;

  /// No description provided for @attachmentsAdd.
  ///
  /// In en, this message translates to:
  /// **'Attach a receipt or document'**
  String get attachmentsAdd;

  /// No description provided for @attachmentsSaveFirst.
  ///
  /// In en, this message translates to:
  /// **'Save the entry first, then attach files to it'**
  String get attachmentsSaveFirst;

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

  /// No description provided for @fuelOdometerRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the odometer reading'**
  String get fuelOdometerRequired;

  /// No description provided for @fuelOdometerTooLow.
  ///
  /// In en, this message translates to:
  /// **'Lower than the previous reading of {previous}'**
  String fuelOdometerTooLow(String previous);

  /// No description provided for @fuelOdometerTooHigh.
  ///
  /// In en, this message translates to:
  /// **'Higher than the next reading of {next}'**
  String fuelOdometerTooHigh(String next);

  /// No description provided for @fuelOdometerLast.
  ///
  /// In en, this message translates to:
  /// **'Last reading: {previous}'**
  String fuelOdometerLast(String previous);

  /// No description provided for @fuelVolumeOverTank.
  ///
  /// In en, this message translates to:
  /// **'More than the tank holds ({capacity})'**
  String fuelVolumeOverTank(String capacity);

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

  /// No description provided for @maintenanceOneTime.
  ///
  /// In en, this message translates to:
  /// **'One-time reminder'**
  String get maintenanceOneTime;

  /// No description provided for @maintenanceDueDateField.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get maintenanceDueDateField;

  /// No description provided for @maintenanceDueKmField.
  ///
  /// In en, this message translates to:
  /// **'Due at odometer'**
  String get maintenanceDueKmField;

  /// No description provided for @maintenanceOneTimeNeedsTarget.
  ///
  /// In en, this message translates to:
  /// **'Set a due date or odometer.'**
  String get maintenanceOneTimeNeedsTarget;

  /// No description provided for @maintenancePreviously.
  ///
  /// In en, this message translates to:
  /// **'Previously: {details}'**
  String maintenancePreviously(String details);

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

  /// No description provided for @maintenanceRuleServiceType.
  ///
  /// In en, this message translates to:
  /// **'Service type'**
  String get maintenanceRuleServiceType;

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

  /// No description provided for @serviceIssue.
  ///
  /// In en, this message translates to:
  /// **'Fault noted'**
  String get serviceIssue;

  /// No description provided for @serviceDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get serviceDiagnostics;

  /// No description provided for @serviceModification.
  ///
  /// In en, this message translates to:
  /// **'Modification'**
  String get serviceModification;

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

  /// No description provided for @serviceInsuranceComprehensive.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive insurance'**
  String get serviceInsuranceComprehensive;

  /// No description provided for @serviceVignette.
  ///
  /// In en, this message translates to:
  /// **'Vignette expires'**
  String get serviceVignette;

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
  /// **'Dashboard'**
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
  /// **'Anything overdue sits under today, because today is when it needs doing'**
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

  /// No description provided for @notificationDueIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Due in 1 day} other{Due in {count} days}}'**
  String notificationDueIn(int count);

  /// No description provided for @notificationDueInKm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{Due in {count} km}}'**
  String notificationDueInKm(int count);

  /// No description provided for @notificationOverdueByKm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, other{{count} km past due}}'**
  String notificationOverdueByKm(int count);

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

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Every car in the garage in one place: fuel, servicing, costs, and what falls due next.'**
  String get aboutTagline;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String aboutVersion(String version, String build);

  /// No description provided for @aboutPromises.
  ///
  /// In en, this message translates to:
  /// **'What this app promises'**
  String get aboutPromises;

  /// No description provided for @aboutPromiseFree.
  ///
  /// In en, this message translates to:
  /// **'No ads, no subscription, no locked features. What you see is the whole app.'**
  String get aboutPromiseFree;

  /// No description provided for @aboutPromiseData.
  ///
  /// In en, this message translates to:
  /// **'Your records are yours. Export everything as CSV whenever you like — it opens in any spreadsheet.'**
  String get aboutPromiseData;

  /// No description provided for @aboutPromiseLeave.
  ///
  /// In en, this message translates to:
  /// **'Leaving is deliberately easy. Delete your account and every record goes with it.'**
  String get aboutPromiseLeave;

  /// No description provided for @aboutPromisePrivacy.
  ///
  /// In en, this message translates to:
  /// **'No tracking, no analytics, no profiles. What you log stays inside your garage.'**
  String get aboutPromisePrivacy;

  /// No description provided for @aboutPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get aboutPrivacyPolicy;

  /// No description provided for @aboutLicences.
  ///
  /// In en, this message translates to:
  /// **'Open source licences'**
  String get aboutLicences;

  /// No description provided for @aboutLicencesHint.
  ///
  /// In en, this message translates to:
  /// **'The libraries this app is built on'**
  String get aboutLicencesHint;

  /// No description provided for @settingsTrackingBasicHint.
  ///
  /// In en, this message translates to:
  /// **'Date, odometer, what was done, what it cost'**
  String get settingsTrackingBasicHint;

  /// No description provided for @settingsTrackingDetailedHint.
  ///
  /// In en, this message translates to:
  /// **'Adds parts, labour, DIY and warranty'**
  String get settingsTrackingDetailedHint;

  /// No description provided for @settingsTrackingFullHint.
  ///
  /// In en, this message translates to:
  /// **'Adds readings: pad thickness, tread depth, voltage'**
  String get settingsTrackingFullHint;

  /// No description provided for @settingsImportCreates.
  ///
  /// In en, this message translates to:
  /// **'This will add {name} to your garage'**
  String settingsImportCreates(String name);

  /// No description provided for @settingsImportNoVehicle.
  ///
  /// In en, this message translates to:
  /// **'That backup has no vehicle in it. Add a car first, then import into it.'**
  String get settingsImportNoVehicle;

  /// No description provided for @settingsImportFuelType.
  ///
  /// In en, this message translates to:
  /// **'Fuel it runs on'**
  String get settingsImportFuelType;

  /// No description provided for @settingsExportNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export yet — log a fill-up or a service first'**
  String get settingsExportNothing;

  /// No description provided for @householdInvites.
  ///
  /// In en, this message translates to:
  /// **'Invite codes'**
  String get householdInvites;

  /// No description provided for @householdInvitesHint.
  ///
  /// In en, this message translates to:
  /// **'Anyone with a code can join this garage until it is used or expires'**
  String get householdInvitesHint;

  /// No description provided for @householdInviteActive.
  ///
  /// In en, this message translates to:
  /// **'Waiting to be used'**
  String get householdInviteActive;

  /// No description provided for @householdInviteUsed.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get householdInviteUsed;

  /// No description provided for @householdInviteExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get householdInviteExpired;

  /// No description provided for @householdInviteRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get householdInviteRevoke;

  /// No description provided for @householdInviteRevoked.
  ///
  /// In en, this message translates to:
  /// **'Code revoked'**
  String get householdInviteRevoked;

  /// No description provided for @householdInviteNew.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get householdInviteNew;

  /// No description provided for @householdInvitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No codes issued yet'**
  String get householdInvitesEmpty;

  /// No description provided for @economyScale.
  ///
  /// In en, this message translates to:
  /// **'Best {best} · Worst {worst} on this car'**
  String economyScale(String best, String worst);

  /// No description provided for @economyScaleNone.
  ///
  /// In en, this message translates to:
  /// **'Log a few full tanks to compare against'**
  String get economyScaleNone;

  /// No description provided for @maintenanceLastDone.
  ///
  /// In en, this message translates to:
  /// **'Last done (optional)'**
  String get maintenanceLastDone;

  /// No description provided for @maintenanceLastDoneHint.
  ///
  /// In en, this message translates to:
  /// **'If you have already done this, say when: intervals count from there instead of from when the car was added'**
  String get maintenanceLastDoneHint;

  /// No description provided for @maintenanceLastDoneDate.
  ///
  /// In en, this message translates to:
  /// **'Date it was done'**
  String get maintenanceLastDoneDate;

  /// No description provided for @maintenanceLastDoneKm.
  ///
  /// In en, this message translates to:
  /// **'Odometer when done'**
  String get maintenanceLastDoneKm;

  /// No description provided for @runningCostTitle.
  ///
  /// In en, this message translates to:
  /// **'What this car costs'**
  String get runningCostTitle;

  /// No description provided for @runningCostPerKm.
  ///
  /// In en, this message translates to:
  /// **'Per kilometre'**
  String get runningCostPerKm;

  /// No description provided for @runningCostFuelShare.
  ///
  /// In en, this message translates to:
  /// **'Fuel {amount}'**
  String runningCostFuelShare(String amount);

  /// No description provided for @runningCostUpkeepShare.
  ///
  /// In en, this message translates to:
  /// **'Upkeep {amount}'**
  String runningCostUpkeepShare(String amount);

  /// No description provided for @runningCostPerMonth.
  ///
  /// In en, this message translates to:
  /// **'Per month'**
  String get runningCostPerMonth;

  /// No description provided for @runningCostPerYear.
  ///
  /// In en, this message translates to:
  /// **'Per year'**
  String get runningCostPerYear;

  /// No description provided for @runningCostTotal.
  ///
  /// In en, this message translates to:
  /// **'Since you added it'**
  String get runningCostTotal;

  /// No description provided for @runningCostNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Log some fuel and costs to see what this car costs to run'**
  String get runningCostNotEnough;

  /// No description provided for @runningCostBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Where it went'**
  String get runningCostBreakdown;

  /// No description provided for @runningCostFuelTotal.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get runningCostFuelTotal;

  /// No description provided for @runningCostServiceTotal.
  ///
  /// In en, this message translates to:
  /// **'Servicing'**
  String get runningCostServiceTotal;

  /// No description provided for @runningCostOtherTotal.
  ///
  /// In en, this message translates to:
  /// **'Registration, insurance and the rest'**
  String get runningCostOtherTotal;

  /// No description provided for @costCategoryInsuranceComprehensive.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive insurance'**
  String get costCategoryInsuranceComprehensive;

  /// No description provided for @settingsDeleteData.
  ///
  /// In en, this message translates to:
  /// **'Delete all data'**
  String get settingsDeleteData;

  /// No description provided for @settingsDeleteDataHint.
  ///
  /// In en, this message translates to:
  /// **'Start over: removes every vehicle and everything logged against them. Your account and garage stay.'**
  String get settingsDeleteDataHint;

  /// No description provided for @settingsDeleteDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete every vehicle and all their fuel, services, costs and attachments? This cannot be undone.'**
  String get settingsDeleteDataConfirm;

  /// No description provided for @settingsDeleteDataDone.
  ///
  /// In en, this message translates to:
  /// **'All vehicle data deleted'**
  String get settingsDeleteDataDone;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get quickAdd;

  /// No description provided for @quickAddFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel up'**
  String get quickAddFuel;

  /// No description provided for @quickAddService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get quickAddService;

  /// No description provided for @quickAddCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get quickAddCost;

  /// No description provided for @quickAddPickVehicle.
  ///
  /// In en, this message translates to:
  /// **'Which car?'**
  String get quickAddPickVehicle;

  /// No description provided for @settingsPumpAutofill.
  ///
  /// In en, this message translates to:
  /// **'Fill in the station and price for me'**
  String get settingsPumpAutofill;

  /// No description provided for @settingsPumpAutofillHint.
  ///
  /// In en, this message translates to:
  /// **'Uses your location at the pump to find the station you are at and fill in today’s posted price for your fuel. Nothing is sent anywhere — the position is matched against prices already on your phone.'**
  String get settingsPumpAutofillHint;

  /// No description provided for @settingsPumpAutofillOn.
  ///
  /// In en, this message translates to:
  /// **'On — the price fills itself in when you are at a station'**
  String get settingsPumpAutofillOn;

  /// No description provided for @settingsPumpAutofillDenied.
  ///
  /// In en, this message translates to:
  /// **'Location is off for Garage. Turn it on in the system settings to use this.'**
  String get settingsPumpAutofillDenied;

  /// No description provided for @settingsSampleData.
  ///
  /// In en, this message translates to:
  /// **'Load sample data'**
  String get settingsSampleData;

  /// No description provided for @settingsSampleDataHint.
  ///
  /// In en, this message translates to:
  /// **'Adds one car with a year of fill-ups, services and costs, so every screen has something to show. Remove it with Delete all data.'**
  String get settingsSampleDataHint;

  /// No description provided for @settingsSampleDataDone.
  ///
  /// In en, this message translates to:
  /// **'Sample car added'**
  String get settingsSampleDataDone;

  /// No description provided for @gettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get gettingStarted;

  /// No description provided for @gettingStartedVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add your car'**
  String get gettingStartedVehicle;

  /// No description provided for @gettingStartedFuel.
  ///
  /// In en, this message translates to:
  /// **'Log a fill-up'**
  String get gettingStartedFuel;

  /// No description provided for @gettingStartedReminder.
  ///
  /// In en, this message translates to:
  /// **'Set what it needs, and when'**
  String get gettingStartedReminder;

  /// No description provided for @gettingStartedDone.
  ///
  /// In en, this message translates to:
  /// **'That is the whole app. Everything else follows from these three.'**
  String get gettingStartedDone;

  /// No description provided for @gettingStartedSample.
  ///
  /// In en, this message translates to:
  /// **'Or load sample data to look around first'**
  String get gettingStartedSample;

  /// No description provided for @odometerTitle.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get odometerTitle;

  /// No description provided for @odometerAdd.
  ///
  /// In en, this message translates to:
  /// **'Log a reading'**
  String get odometerAdd;

  /// No description provided for @odometerReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get odometerReading;

  /// No description provided for @odometerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No readings logged yet.'**
  String get odometerEmpty;

  /// No description provided for @odometerHint.
  ///
  /// In en, this message translates to:
  /// **'A reading with no money attached, so maintenance still knows how far the car has gone.'**
  String get odometerHint;

  /// No description provided for @quickAddOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get quickAddOdometer;

  /// No description provided for @statsPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get statsPeriod;

  /// No description provided for @statsPeriodAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get statsPeriodAllTime;

  /// No description provided for @statsPeriodLastTwelve.
  ///
  /// In en, this message translates to:
  /// **'Last 12 months'**
  String get statsPeriodLastTwelve;

  /// No description provided for @statsPeriodCustom.
  ///
  /// In en, this message translates to:
  /// **'Pick dates'**
  String get statsPeriodCustom;

  /// No description provided for @statsPeriodRange.
  ///
  /// In en, this message translates to:
  /// **'{from} – {to}'**
  String statsPeriodRange(String from, String to);

  /// No description provided for @statsEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{No entries}=1{1 entry}other{{count} entries}}'**
  String statsEntryCount(int count);

  /// No description provided for @statsPerDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get statsPerDay;

  /// No description provided for @statsPerDistance.
  ///
  /// In en, this message translates to:
  /// **'By distance'**
  String get statsPerDistance;

  /// No description provided for @statsByKind.
  ///
  /// In en, this message translates to:
  /// **'Where the money goes'**
  String get statsByKind;

  /// No description provided for @statsByCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get statsByCategory;

  /// No description provided for @statsByStation.
  ///
  /// In en, this message translates to:
  /// **'By station'**
  String get statsByStation;

  /// No description provided for @statsMonthlySpend.
  ///
  /// In en, this message translates to:
  /// **'Spend per month'**
  String get statsMonthlySpend;

  /// No description provided for @statsOdometerChart.
  ///
  /// In en, this message translates to:
  /// **'Odometer over time'**
  String get statsOdometerChart;

  /// No description provided for @statsOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get statsOthers;

  /// No description provided for @statsUnlabelled.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get statsUnlabelled;

  /// No description provided for @statsRecords.
  ///
  /// In en, this message translates to:
  /// **'Best and worst'**
  String get statsRecords;

  /// No description provided for @statsComparison.
  ///
  /// In en, this message translates to:
  /// **'Year and month'**
  String get statsComparison;

  /// No description provided for @statsSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get statsSummary;

  /// No description provided for @statsCustomise.
  ///
  /// In en, this message translates to:
  /// **'Choose what to show'**
  String get statsCustomise;

  /// No description provided for @statsCustomiseHint.
  ///
  /// In en, this message translates to:
  /// **'Turned off here, kept out of the way. Nothing is deleted.'**
  String get statsCustomiseHint;

  /// No description provided for @statsShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show everything'**
  String get statsShowAll;

  /// No description provided for @statsNothingShown.
  ///
  /// In en, this message translates to:
  /// **'Everything is hidden. Choose what to show from the menu.'**
  String get statsNothingShown;

  /// No description provided for @tripsTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip log'**
  String get tripsTitle;

  /// No description provided for @tripAdd.
  ///
  /// In en, this message translates to:
  /// **'Log a trip'**
  String get tripAdd;

  /// No description provided for @tripsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No trips logged yet.'**
  String get tripsEmpty;

  /// No description provided for @tripTitleField.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tripTitleField;

  /// No description provided for @tripFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get tripFrom;

  /// No description provided for @tripTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get tripTo;

  /// No description provided for @tripDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get tripDistance;

  /// No description provided for @tripDistanceRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a distance, or both odometer readings.'**
  String get tripDistanceRequired;

  /// No description provided for @tripStartOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer at the start'**
  String get tripStartOdometer;

  /// No description provided for @tripEndOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer at the end'**
  String get tripEndOdometer;

  /// No description provided for @tripOdometerOrder.
  ///
  /// In en, this message translates to:
  /// **'The end reading cannot be lower than the start.'**
  String get tripOdometerOrder;

  /// No description provided for @tripMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get tripMinutes;

  /// No description provided for @tripPurpose.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get tripPurpose;

  /// No description provided for @tripPurposePrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get tripPurposePrivate;

  /// No description provided for @tripPurposeBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get tripPurposeBusiness;

  /// No description provided for @tripTotalTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get tripTotalTrips;

  /// No description provided for @tripTotalDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get tripTotalDistance;

  /// No description provided for @tripTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get tripTotalTime;

  /// No description provided for @tripAverageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average speed'**
  String get tripAverageSpeed;

  /// No description provided for @tripHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String tripHoursMinutes(int hours, int minutes);

  /// No description provided for @quickAddTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get quickAddTrip;

  /// No description provided for @incomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get incomeTitle;

  /// No description provided for @incomeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get incomeAdd;

  /// No description provided for @incomeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No income logged yet.'**
  String get incomeEmpty;

  /// No description provided for @incomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get incomeAmount;

  /// No description provided for @incomeCategory.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get incomeCategory;

  /// No description provided for @incomeCategoryRide.
  ///
  /// In en, this message translates to:
  /// **'Lift share'**
  String get incomeCategoryRide;

  /// No description provided for @incomeCategoryTransportApp.
  ///
  /// In en, this message translates to:
  /// **'Ride-hailing'**
  String get incomeCategoryTransportApp;

  /// No description provided for @incomeCategoryFreight.
  ///
  /// In en, this message translates to:
  /// **'Freight'**
  String get incomeCategoryFreight;

  /// No description provided for @incomeCategoryRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get incomeCategoryRefund;

  /// No description provided for @incomeCategoryVehicleSale.
  ///
  /// In en, this message translates to:
  /// **'Sold the car'**
  String get incomeCategoryVehicleSale;

  /// No description provided for @incomeCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get incomeCategoryOther;

  /// No description provided for @quickAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get quickAddIncome;

  /// No description provided for @statsBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get statsBalance;

  /// No description provided for @statsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get statsIncome;

  /// No description provided for @statsTabTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get statsTabTrips;

  /// No description provided for @statsBusinessDistance.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get statsBusinessDistance;

  /// No description provided for @statsPrivateDistance.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get statsPrivateDistance;

  /// No description provided for @statsIncomeByKind.
  ///
  /// In en, this message translates to:
  /// **'Where the money comes from'**
  String get statsIncomeByKind;

  /// No description provided for @joinSecondGarage.
  ///
  /// In en, this message translates to:
  /// **'You are already in {name}. Joining this one adds it — you can switch between them.'**
  String joinSecondGarage(String name);

  /// No description provided for @householdSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch garage'**
  String get householdSwitch;

  /// No description provided for @householdCreateAnother.
  ///
  /// In en, this message translates to:
  /// **'Create another garage'**
  String get householdCreateAnother;

  /// No description provided for @householdYours.
  ///
  /// In en, this message translates to:
  /// **'Your garages'**
  String get householdYours;

  /// No description provided for @householdCurrent.
  ///
  /// In en, this message translates to:
  /// **'Showing now'**
  String get householdCurrent;

  /// No description provided for @transferTitle.
  ///
  /// In en, this message translates to:
  /// **'Transfer this car'**
  String get transferTitle;

  /// No description provided for @transferSell.
  ///
  /// In en, this message translates to:
  /// **'Sold the car?'**
  String get transferSell;

  /// No description provided for @transferSellHint.
  ///
  /// In en, this message translates to:
  /// **'Hand the buyer this code. The car and its whole history move into their garage, and out of yours.'**
  String get transferSellHint;

  /// No description provided for @transferBought.
  ///
  /// In en, this message translates to:
  /// **'Bought a car?'**
  String get transferBought;

  /// No description provided for @transferBoughtHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the code the seller gave you.'**
  String get transferBoughtHint;

  /// No description provided for @transferGenerate.
  ///
  /// In en, this message translates to:
  /// **'Get a transfer code'**
  String get transferGenerate;

  /// No description provided for @transferRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem a code'**
  String get transferRedeem;

  /// No description provided for @transferCode.
  ///
  /// In en, this message translates to:
  /// **'Transfer code'**
  String get transferCode;

  /// No description provided for @transferCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get transferCopied;

  /// No description provided for @transferDone.
  ///
  /// In en, this message translates to:
  /// **'The car is in your garage now.'**
  String get transferDone;

  /// No description provided for @transferWarning.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone from here — only the new owner can send it back.'**
  String get transferWarning;

  /// No description provided for @transferPhotoNote.
  ///
  /// In en, this message translates to:
  /// **'The photo stays with you; everything else goes.'**
  String get transferPhotoNote;

  /// No description provided for @vehicleSecondFuel.
  ///
  /// In en, this message translates to:
  /// **'Second fuel'**
  String get vehicleSecondFuel;

  /// No description provided for @vehicleSecondFuelHint.
  ///
  /// In en, this message translates to:
  /// **'For a car that runs on two — LPG beside petrol. Each fill-up then says which went in.'**
  String get vehicleSecondFuelHint;

  /// No description provided for @vehicleSecondFuelNone.
  ///
  /// In en, this message translates to:
  /// **'Only one fuel'**
  String get vehicleSecondFuelNone;

  /// No description provided for @fuelWhichFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get fuelWhichFuel;

  /// No description provided for @fuelCng.
  ///
  /// In en, this message translates to:
  /// **'CNG'**
  String get fuelCng;

  /// No description provided for @fuelEthanol.
  ///
  /// In en, this message translates to:
  /// **'Ethanol'**
  String get fuelEthanol;

  /// No description provided for @fuelPetrolMidgrade.
  ///
  /// In en, this message translates to:
  /// **'Petrol 95+'**
  String get fuelPetrolMidgrade;

  /// No description provided for @fuelPetrolPremium.
  ///
  /// In en, this message translates to:
  /// **'Petrol 100'**
  String get fuelPetrolPremium;

  /// No description provided for @statsEconomyByFuel.
  ///
  /// In en, this message translates to:
  /// **'Consumption per fuel'**
  String get statsEconomyByFuel;

  /// No description provided for @csvImportTitle.
  ///
  /// In en, this message translates to:
  /// **'Import a CSV'**
  String get csvImportTitle;

  /// No description provided for @csvImportIntro.
  ///
  /// In en, this message translates to:
  /// **'From Drivvo, a spreadsheet, or anything else that exports a table. Pick the file, say which column is which, and check the preview before it is written.'**
  String get csvImportIntro;

  /// No description provided for @csvPickFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get csvPickFile;

  /// No description provided for @csvFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file has no rows this app can read.'**
  String get csvFileEmpty;

  /// No description provided for @csvWhatIsIt.
  ///
  /// In en, this message translates to:
  /// **'What is in this file'**
  String get csvWhatIsIt;

  /// No description provided for @csvKindFuel.
  ///
  /// In en, this message translates to:
  /// **'Fill-ups'**
  String get csvKindFuel;

  /// No description provided for @csvKindCost.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get csvKindCost;

  /// No description provided for @csvKindService.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get csvKindService;

  /// No description provided for @csvKindOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer readings'**
  String get csvKindOdometer;

  /// No description provided for @csvKindTrip.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get csvKindTrip;

  /// No description provided for @csvKindIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get csvKindIncome;

  /// No description provided for @csvWhichVehicle.
  ///
  /// In en, this message translates to:
  /// **'Which car'**
  String get csvWhichVehicle;

  /// No description provided for @csvColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get csvColumns;

  /// No description provided for @csvColumnNone.
  ///
  /// In en, this message translates to:
  /// **'Not in this file'**
  String get csvColumnNone;

  /// No description provided for @csvRequired.
  ///
  /// In en, this message translates to:
  /// **'required'**
  String get csvRequired;

  /// No description provided for @csvDayFirst.
  ///
  /// In en, this message translates to:
  /// **'Dates are day first (31/12)'**
  String get csvDayFirst;

  /// No description provided for @csvMiles.
  ///
  /// In en, this message translates to:
  /// **'Distances are in miles'**
  String get csvMiles;

  /// No description provided for @csvGallons.
  ///
  /// In en, this message translates to:
  /// **'Volumes are in gallons'**
  String get csvGallons;

  /// No description provided for @csvPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get csvPreview;

  /// No description provided for @csvReadyToImport.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =0{Nothing to import}=1{1 row ready}other{{count} rows ready}}'**
  String csvReadyToImport(int count);

  /// No description provided for @csvSkippedRows.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 row will be skipped}other{{count} rows will be skipped}}'**
  String csvSkippedRows(int count);

  /// No description provided for @csvMissingColumn.
  ///
  /// In en, this message translates to:
  /// **'Choose a column for {field}'**
  String csvMissingColumn(String field);

  /// No description provided for @csvRowProblem.
  ///
  /// In en, this message translates to:
  /// **'Line {line}: {field} could not be read'**
  String csvRowProblem(int line, String field);

  /// No description provided for @csvImportAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get csvImportAction;

  /// No description provided for @csvImported.
  ///
  /// In en, this message translates to:
  /// **'{written} imported, {skipped} already there'**
  String csvImported(int written, int skipped);

  /// No description provided for @csvFieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get csvFieldDate;

  /// No description provided for @csvFieldOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get csvFieldOdometer;

  /// No description provided for @csvFieldVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get csvFieldVolume;

  /// No description provided for @csvFieldPricePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Price per unit'**
  String get csvFieldPricePerUnit;

  /// No description provided for @csvFieldTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get csvFieldTotal;

  /// No description provided for @csvFieldFullTank.
  ///
  /// In en, this message translates to:
  /// **'Full tank'**
  String get csvFieldFullTank;

  /// No description provided for @csvFieldStation.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get csvFieldStation;

  /// No description provided for @csvFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get csvFieldNotes;

  /// No description provided for @csvFieldAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get csvFieldAmount;

  /// No description provided for @csvFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get csvFieldCategory;

  /// No description provided for @csvFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get csvFieldType;

  /// No description provided for @csvFieldCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get csvFieldCost;

  /// No description provided for @csvFieldShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get csvFieldShop;

  /// No description provided for @csvFieldDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get csvFieldDistance;

  /// No description provided for @csvFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get csvFieldTitle;

  /// No description provided for @csvFieldFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get csvFieldFrom;

  /// No description provided for @csvFieldTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get csvFieldTo;

  /// No description provided for @csvFieldBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business trip'**
  String get csvFieldBusiness;

  /// No description provided for @csvFieldMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get csvFieldMinutes;

  /// No description provided for @settingsImportCsv.
  ///
  /// In en, this message translates to:
  /// **'Import a CSV (any app)'**
  String get settingsImportCsv;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Back up everything'**
  String get settingsBackup;

  /// No description provided for @settingsBackupHint.
  ///
  /// In en, this message translates to:
  /// **'A file that can be restored, unlike the CSV export'**
  String get settingsBackupHint;

  /// No description provided for @settingsRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get settingsRestore;

  /// No description provided for @settingsRestoreHint.
  ///
  /// In en, this message translates to:
  /// **'Adds what is missing. Nothing is deleted or overwritten.'**
  String get settingsRestoreHint;

  /// No description provided for @settingsBackupDone.
  ///
  /// In en, this message translates to:
  /// **'Backup shared'**
  String get settingsBackupDone;

  /// No description provided for @settingsRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'{vehicles} cars, {written} entries added, {skipped} already there'**
  String settingsRestoreDone(int vehicles, int written, int skipped);

  /// No description provided for @settingsRestoreNotABackup.
  ///
  /// In en, this message translates to:
  /// **'That file is not a Garage backup.'**
  String get settingsRestoreNotABackup;

  /// No description provided for @stationsPickNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get stationsPickNearest;

  /// No description provided for @stationsPickCheapest.
  ///
  /// In en, this message translates to:
  /// **'Cheapest'**
  String get stationsPickCheapest;

  /// No description provided for @stationsPickBestValue.
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get stationsPickBestValue;

  /// No description provided for @stationsBestValueHint.
  ///
  /// In en, this message translates to:
  /// **'Cheapest once the fuel to get there and back is paid for'**
  String get stationsBestValueHint;

  /// No description provided for @stationsGradeAverages.
  ///
  /// In en, this message translates to:
  /// **'Average around here'**
  String get stationsGradeAverages;

  /// No description provided for @stationsGradeStations.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 station}other{{count} stations}}'**
  String stationsGradeStations(int count);
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
