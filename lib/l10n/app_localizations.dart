import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hr.dart';
import 'app_localizations_it.dart';

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
    Locale('it'),
  ];

  /// Application name, shown in the app bar and task switcher
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get appTitle;

  /// Tooltip on the share button beside an export row. Saving is the row's own action; sharing sits next to it.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @saveStillSaving.
  ///
  /// In en, this message translates to:
  /// **'Still saving…'**
  String get saveStillSaving;

  /// No description provided for @saveEntryKept.
  ///
  /// In en, this message translates to:
  /// **'Your entry is still here.'**
  String get saveEntryKept;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @discardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard what you typed?'**
  String get discardTitle;

  /// No description provided for @discardKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get discardKeep;

  /// No description provided for @discardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardConfirm;

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

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'No answer from the server in time. It may still have saved: check the list before trying again.'**
  String get errorTimeout;

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

  /// No description provided for @errorTransferCode.
  ///
  /// In en, this message translates to:
  /// **'That transfer code is not valid, or it has already been used.'**
  String get errorTransferCode;

  /// No description provided for @errorTransferHere.
  ///
  /// In en, this message translates to:
  /// **'That vehicle is already in this garage.'**
  String get errorTransferHere;

  /// No description provided for @errorConflict.
  ///
  /// In en, this message translates to:
  /// **'That already exists.'**
  String get errorConflict;

  /// No description provided for @errorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Some of the values were not accepted. Check them and try again.'**
  String get errorInvalid;

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

  /// No description provided for @errorEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirm your email address first. Check your inbox for the link we sent when you signed up.'**
  String get errorEmailNotConfirmed;

  /// No description provided for @authWhatIsThis.
  ///
  /// In en, this message translates to:
  /// **'What Garage does'**
  String get authWhatIsThis;

  /// Link under the sign-in and the sign-up form that opens the hosted privacy policy. Both forms ask for an email address, and the policy was otherwise reachable only from About and More, which sit behind the sign-in. Deliberately a plain link and not a consent sentence: it says nothing about agreeing, and there is no checkbox beside it.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get authPrivacyPolicy;

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

  /// No description provided for @authDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown to the people you share a garage with'**
  String get authDisplayNameHint;

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

  /// No description provided for @authConfirmEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authConfirmEmailTitle;

  /// No description provided for @authConfirmEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Open it, then come back and sign in.'**
  String authConfirmEmailBody(String email);

  /// No description provided for @authConfirmEmailAction.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authConfirmEmailAction;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'No account? Create one'**
  String get authNoAccount;

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

  /// No description provided for @authLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'That link has expired or was already used. Sign in below, or create the account again.'**
  String get authLinkFailed;

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

  /// No description provided for @onboardingSuggestName.
  ///
  /// In en, this message translates to:
  /// **'Suggest a name'**
  String get onboardingSuggestName;

  /// No description provided for @onboardingNameOfPerson.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s garage'**
  String onboardingNameOfPerson(String name);

  /// No description provided for @onboardingNameIdea1.
  ///
  /// In en, this message translates to:
  /// **'Family garage'**
  String get onboardingNameIdea1;

  /// No description provided for @onboardingNameIdea2.
  ///
  /// In en, this message translates to:
  /// **'Home fleet'**
  String get onboardingNameIdea2;

  /// No description provided for @onboardingNameIdea3.
  ///
  /// In en, this message translates to:
  /// **'Our cars'**
  String get onboardingNameIdea3;

  /// No description provided for @onboardingNameIdea4.
  ///
  /// In en, this message translates to:
  /// **'The driveway'**
  String get onboardingNameIdea4;

  /// No description provided for @onboardingNameIdea5.
  ///
  /// In en, this message translates to:
  /// **'Motor pool'**
  String get onboardingNameIdea5;

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
  /// **'Invite message copied'**
  String get householdInviteLinkCopied;

  /// No description provided for @householdInviteMessageNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'Join my garage in Garage: install the app, create an account, tap \"Join with a code\" and enter {code} — or just open {link}.'**
  String householdInviteMessageNoExpiry(String code, String link);

  /// No description provided for @householdInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Join my garage in Garage: install the app, create an account, tap \"Join with a code\" and enter {code} — or just open {link}. The code works until {until}.'**
  String householdInviteMessage(String code, String link, String until);

  /// No description provided for @transferVehicleLocked.
  ///
  /// In en, this message translates to:
  /// **'This is the vehicle the code will hand over. Go back to pick a different one.'**
  String get transferVehicleLocked;

  /// No description provided for @householdTransferNamed.
  ///
  /// In en, this message translates to:
  /// **'Hand {vehicle} to another garage'**
  String householdTransferNamed(String vehicle);

  /// No description provided for @householdTransferPick.
  ///
  /// In en, this message translates to:
  /// **'Hand a vehicle to another garage…'**
  String get householdTransferPick;

  /// No description provided for @householdDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Leave or delete'**
  String get householdDangerZone;

  /// No description provided for @householdManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get householdManage;

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

  /// No description provided for @calculatorFromCar.
  ///
  /// In en, this message translates to:
  /// **'From {vehicle}: {economy}'**
  String calculatorFromCar(String vehicle, String economy);

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

  /// No description provided for @calcFuelAvailable.
  ///
  /// In en, this message translates to:
  /// **'Fuel in the tank'**
  String get calcFuelAvailable;

  /// No description provided for @calcFuelUsed.
  ///
  /// In en, this message translates to:
  /// **'Fuel used'**
  String get calcFuelUsed;

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

  /// No description provided for @stationsNoLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cheapest in Croatia'**
  String get stationsNoLocationTitle;

  /// No description provided for @stationsNoLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Without your location these are the cheapest stations in the country, not the closest ones. Nothing here is sorted by how far it is.'**
  String get stationsNoLocationBody;

  /// No description provided for @stationsUseLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get stationsUseLocation;

  /// No description provided for @stationsGradesNearby.
  ///
  /// In en, this message translates to:
  /// **'Grades near you'**
  String get stationsGradesNearby;

  /// No description provided for @stationsGradesCountry.
  ///
  /// In en, this message translates to:
  /// **'Grades across the country'**
  String get stationsGradesCountry;

  /// No description provided for @stationsGradesNote.
  ///
  /// In en, this message translates to:
  /// **'Most widely sold first'**
  String get stationsGradesNote;

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

  /// The national average compared week against week, smoothed. Not a comparison of two individual days — daily figures in this feed move more than the market does.
  ///
  /// In en, this message translates to:
  /// **'Up {amount} on last week'**
  String stationsTrendUp(String amount);

  /// No description provided for @stationsTrendDown.
  ///
  /// In en, this message translates to:
  /// **'Down {amount} on last week'**
  String stationsTrendDown(String amount);

  /// No description provided for @stationsTrendSteady.
  ///
  /// In en, this message translates to:
  /// **'Steady on last week'**
  String get stationsTrendSteady;

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

  /// No description provided for @statsDistanceNeedsSecond.
  ///
  /// In en, this message translates to:
  /// **'Needs a second reading'**
  String get statsDistanceNeedsSecond;

  /// No description provided for @statsLastOdometer.
  ///
  /// In en, this message translates to:
  /// **'Last odometer'**
  String get statsLastOdometer;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not enough data yet.'**
  String get statsEmpty;

  /// No description provided for @reminderLogIt.
  ///
  /// In en, this message translates to:
  /// **'Log it as done'**
  String get reminderLogIt;

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

  /// No description provided for @calendarTapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a day to see what is due'**
  String get calendarTapHint;

  /// Shown when the user backs out of the save dialog for a vehicle report. Says what happened without implying anything went wrong.
  ///
  /// In en, this message translates to:
  /// **'Report not saved'**
  String get reportsNotSaved;

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

  /// No description provided for @reportSchedule.
  ///
  /// In en, this message translates to:
  /// **'Service schedule'**
  String get reportSchedule;

  /// No description provided for @reportScheduleHint.
  ///
  /// In en, this message translates to:
  /// **'The intervals set for this car, as a sheet you can print or hand over'**
  String get reportScheduleHint;

  /// No description provided for @reportScheduleItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get reportScheduleItem;

  /// No description provided for @reportScheduleEvery.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get reportScheduleEvery;

  /// No description provided for @reportScheduleLastDone.
  ///
  /// In en, this message translates to:
  /// **'Last done'**
  String get reportScheduleLastDone;

  /// No description provided for @reportScheduleNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get reportScheduleNextDue;

  /// No description provided for @reportScheduleNone.
  ///
  /// In en, this message translates to:
  /// **'No intervals set for this vehicle yet.'**
  String get reportScheduleNone;

  /// No description provided for @reportScheduleKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String reportScheduleKm(String km);

  /// No description provided for @reportScheduleMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String reportScheduleMonths(int count);

  /// No description provided for @reportScheduleOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get reportScheduleOnce;

  /// No description provided for @reportScheduleNote.
  ///
  /// In en, this message translates to:
  /// **'Intervals are this garage’s own settings, not the manufacturer’s schedule.'**
  String get reportScheduleNote;

  /// No description provided for @reportTripLog.
  ///
  /// In en, this message translates to:
  /// **'Mileage logbook'**
  String get reportTripLog;

  /// No description provided for @reportTripLogHint.
  ///
  /// In en, this message translates to:
  /// **'Every journey in a period, with the business split and a line to sign'**
  String get reportTripLogHint;

  /// No description provided for @reportTripLogPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportTripLogPeriod;

  /// No description provided for @reportTripLogDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get reportTripLogDriver;

  /// No description provided for @reportTripLogPurpose.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reportTripLogPurpose;

  /// No description provided for @reportTripLogRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get reportTripLogRoute;

  /// No description provided for @reportTripLogBusinessTotal.
  ///
  /// In en, this message translates to:
  /// **'Business distance'**
  String get reportTripLogBusinessTotal;

  /// No description provided for @reportTripLogPrivateTotal.
  ///
  /// In en, this message translates to:
  /// **'Private distance'**
  String get reportTripLogPrivateTotal;

  /// No description provided for @reportTripLogTotal.
  ///
  /// In en, this message translates to:
  /// **'Total distance'**
  String get reportTripLogTotal;

  /// No description provided for @reportTripLogTrips.
  ///
  /// In en, this message translates to:
  /// **'Journeys'**
  String get reportTripLogTrips;

  /// No description provided for @reportTripLogSignature.
  ///
  /// In en, this message translates to:
  /// **'Signature'**
  String get reportTripLogSignature;

  /// No description provided for @reportTripLogDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get reportTripLogDate;

  /// No description provided for @reportTripLogNoTrips.
  ///
  /// In en, this message translates to:
  /// **'No journeys recorded in this period.'**
  String get reportTripLogNoTrips;

  /// No description provided for @reportTripLogPickPeriod.
  ///
  /// In en, this message translates to:
  /// **'Which period?'**
  String get reportTripLogPickPeriod;

  /// No description provided for @reportTripLogThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportTripLogThisMonth;

  /// No description provided for @reportTripLogLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get reportTripLogLastMonth;

  /// No description provided for @reportTripLogThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get reportTripLogThisYear;

  /// No description provided for @reportAnnual.
  ///
  /// In en, this message translates to:
  /// **'Annual summary'**
  String get reportAnnual;

  /// No description provided for @reportSellersHint.
  ///
  /// In en, this message translates to:
  /// **'What a buyer asks for: history, mileage and what it cost to run'**
  String get reportSellersHint;

  /// No description provided for @reportMaintenanceHint.
  ///
  /// In en, this message translates to:
  /// **'Every service logged, with dates and odometer readings'**
  String get reportMaintenanceHint;

  /// No description provided for @reportAnnualHint.
  ///
  /// In en, this message translates to:
  /// **'One year of fuel, servicing and other costs'**
  String get reportAnnualHint;

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

  /// No description provided for @costEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit cost'**
  String get costEdit;

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

  /// No description provided for @costsEmptyBeyondFuel.
  ///
  /// In en, this message translates to:
  /// **'No costs beyond fuel yet.'**
  String get costsEmptyBeyondFuel;

  /// No description provided for @costsFuelLine.
  ///
  /// In en, this message translates to:
  /// **'Fuel {amount}, from the fill-ups'**
  String costsFuelLine(String amount);

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
  /// **'Bundling reminders'**
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
  /// **'Export as spreadsheets'**
  String get settingsExport;

  /// No description provided for @settingsExportDone.
  ///
  /// In en, this message translates to:
  /// **'Export ready: {file}'**
  String settingsExportDone(String file);

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

  /// No description provided for @settingsDeleteTypeName.
  ///
  /// In en, this message translates to:
  /// **'Type the garage name to confirm'**
  String get settingsDeleteTypeName;

  /// No description provided for @settingsDeleteNameMismatch.
  ///
  /// In en, this message translates to:
  /// **'That is not the garage name.'**
  String get settingsDeleteNameMismatch;

  /// No description provided for @apiTitle.
  ///
  /// In en, this message translates to:
  /// **'API access'**
  String get apiTitle;

  /// No description provided for @apiHint.
  ///
  /// In en, this message translates to:
  /// **'Read-only keys for your own scripts, and webhooks that send this garage’s data to a URL you choose'**
  String get apiHint;

  /// Opens the hosted API reference. Without it a key is issued with nothing explaining what to do with it — the repository is private and the app says nothing more.
  ///
  /// In en, this message translates to:
  /// **'How to use it'**
  String get apiDocs;

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

  /// No description provided for @apiWebhookFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get apiWebhookFormat;

  /// No description provided for @apiWebhookFormatHint.
  ///
  /// In en, this message translates to:
  /// **'Read from the address unless you run the receiver yourself'**
  String get apiWebhookFormatHint;

  /// No description provided for @apiWebhookFormatAuto.
  ///
  /// In en, this message translates to:
  /// **'Detect from the address'**
  String get apiWebhookFormatAuto;

  /// No description provided for @apiWebhookFormatGeneric.
  ///
  /// In en, this message translates to:
  /// **'Signed JSON (Home Assistant, scripts)'**
  String get apiWebhookFormatGeneric;

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

  /// No description provided for @vehicleAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String vehicleAdded(String name);

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

  /// No description provided for @vehiclePhotoCropTitle.
  ///
  /// In en, this message translates to:
  /// **'Frame the photo'**
  String get vehiclePhotoCropTitle;

  /// No description provided for @vehiclePhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get vehiclePhotoRemove;

  /// Shown when the file picked as a vehicle photo is not an image the app can store, such as a PDF.
  ///
  /// In en, this message translates to:
  /// **'That file is not a photo. Choose a JPEG, PNG, WebP or HEIC image.'**
  String get vehiclePhotoNotAPhoto;

  /// No description provided for @vehiclePlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get vehiclePlate;

  /// No description provided for @sheetVehicleLockedByFile.
  ///
  /// In en, this message translates to:
  /// **'Remove the attachment to move this to another car'**
  String get sheetVehicleLockedByFile;

  /// No description provided for @sheetVehicleTapToChange.
  ///
  /// In en, this message translates to:
  /// **'Tap to change'**
  String get sheetVehicleTapToChange;

  /// No description provided for @vehicleVin.
  ///
  /// In en, this message translates to:
  /// **'VIN'**
  String get vehicleVin;

  /// No description provided for @vehicleVinLength.
  ///
  /// In en, this message translates to:
  /// **'A VIN is 11 to 17 characters long'**
  String get vehicleVinLength;

  /// No description provided for @vehicleDecodeVin.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get vehicleDecodeVin;

  /// No description provided for @vehicleVinHint.
  ///
  /// In en, this message translates to:
  /// **'Fills in make, model and year from the number'**
  String get vehicleVinHint;

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

  /// Shown under a fill-up when a station within reach posted a lower price that day. Past tense in effect — it describes the market as it stood, not as it is now.
  ///
  /// In en, this message translates to:
  /// **'{amount} cheaper {distance} away, at {station}'**
  String fuelCheaperNearby(String amount, String distance, String station);

  /// Shown under a fill-up made at the cheapest station in reach.
  ///
  /// In en, this message translates to:
  /// **'Cheapest nearby that day'**
  String get fuelCheapestNearby;

  /// Explains the colour already on the economy figure. Not a warning — one cold winter tank is enough to earn it, and there is nothing to be done about a fill-up already made.
  ///
  /// In en, this message translates to:
  /// **'{percent} more than this car\'s usual'**
  String fuelWorseThanUsual(String percent);

  /// No description provided for @fuelBetterThanUsual.
  ///
  /// In en, this message translates to:
  /// **'{percent} less than this car\'s usual'**
  String fuelBetterThanUsual(String percent);

  /// No description provided for @vehicleTankCapacity.
  ///
  /// In en, this message translates to:
  /// **'Tank capacity'**
  String get vehicleTankCapacity;

  /// No description provided for @vehicleTankCapacityHint.
  ///
  /// In en, this message translates to:
  /// **'Flags a fill-up bigger than the tank'**
  String get vehicleTankCapacityHint;

  /// No description provided for @vehicleCurrentValue.
  ///
  /// In en, this message translates to:
  /// **'What it is worth now'**
  String get vehicleCurrentValue;

  /// No description provided for @vehicleCurrentValueHint.
  ///
  /// In en, this message translates to:
  /// **'Your own estimate. With the purchase price it gives what the car costs to own, not only to run — the value it loses is the largest cost of keeping it.'**
  String get vehicleCurrentValueHint;

  /// No description provided for @vehiclePurchasePrice.
  ///
  /// In en, this message translates to:
  /// **'Purchase price'**
  String get vehiclePurchasePrice;

  /// No description provided for @vehiclePurchasePriceHint.
  ///
  /// In en, this message translates to:
  /// **'What you paid for the car'**
  String get vehiclePurchasePriceHint;

  /// No description provided for @vehicleArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive this vehicle?'**
  String get vehicleArchiveTitle;

  /// No description provided for @vehicleArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'It keeps its history and stays off the lists and totals. You can bring it back from its own page.'**
  String get vehicleArchiveBody;

  /// No description provided for @vehicleArchivedBanner.
  ///
  /// In en, this message translates to:
  /// **'Archived: off the lists, history kept.'**
  String get vehicleArchivedBanner;

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
  /// **'Tyres'**
  String get tyresTitle;

  /// No description provided for @vehicleTyresHint.
  ///
  /// In en, this message translates to:
  /// **'Sets, the seasonal swap, tread depth and age'**
  String get vehicleTyresHint;

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

  /// No description provided for @tyresEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit set'**
  String get tyresEdit;

  /// No description provided for @tyresAgeAgeing.
  ///
  /// In en, this message translates to:
  /// **'{years} years old — worth checking each year'**
  String tyresAgeAgeing(Object years);

  /// No description provided for @tyresAgeAgeingEstimated.
  ///
  /// In en, this message translates to:
  /// **'About {years} years old, estimated from when it was fitted'**
  String tyresAgeAgeingEstimated(Object years);

  /// No description provided for @tyresAgeExpired.
  ///
  /// In en, this message translates to:
  /// **'{years} years old — replace whatever the tread says'**
  String tyresAgeExpired(Object years);

  /// No description provided for @tyresAgeExpiredEstimated.
  ///
  /// In en, this message translates to:
  /// **'About {years} years old, estimated from when it was fitted — replace whatever the tread says'**
  String tyresAgeExpiredEstimated(Object years);

  /// No description provided for @tyresDotCode.
  ///
  /// In en, this message translates to:
  /// **'DOT code'**
  String get tyresDotCode;

  /// No description provided for @tyresDotPerCorner.
  ///
  /// In en, this message translates to:
  /// **'The codes are different on each tyre'**
  String get tyresDotPerCorner;

  /// No description provided for @tyresDotSame.
  ///
  /// In en, this message translates to:
  /// **'They are all the same'**
  String get tyresDotSame;

  /// No description provided for @tyresDotCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Four digits on the sidewall, like 3419 for week 34 of 2019'**
  String get tyresDotCodeHint;

  /// No description provided for @tyresDotCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Four digits: week 01-53, then the year'**
  String get tyresDotCodeInvalid;

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
  /// **'On the vehicle'**
  String get tyresFitted;

  /// No description provided for @tyresFit.
  ///
  /// In en, this message translates to:
  /// **'Fit to vehicle'**
  String get tyresFit;

  /// No description provided for @tyresRetire.
  ///
  /// In en, this message translates to:
  /// **'Retire'**
  String get tyresRetire;

  /// No description provided for @tyresUnfit.
  ///
  /// In en, this message translates to:
  /// **'Take off the vehicle'**
  String get tyresUnfit;

  /// No description provided for @tyresUnretire.
  ///
  /// In en, this message translates to:
  /// **'Bring back into use'**
  String get tyresUnretire;

  /// No description provided for @tyresMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More for this set'**
  String get tyresMoreActions;

  /// No description provided for @tyresRetireConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Retire this set?'**
  String get tyresRetireConfirmTitle;

  /// No description provided for @tyresRetireConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'It stays on the list with its readings, and stops being offered to fit.'**
  String get tyresRetireConfirmBody;

  /// No description provided for @tyresDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete set'**
  String get tyresDelete;

  /// No description provided for @tyresDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this set?'**
  String get tyresDeleteConfirmTitle;

  /// No description provided for @tyresDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The set and every tread reading on it go with it. This cannot be undone.'**
  String get tyresDeleteConfirmBody;

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

  /// No description provided for @tyresReadingSaved.
  ///
  /// In en, this message translates to:
  /// **'Tread recorded'**
  String get tyresReadingSaved;

  /// No description provided for @tyresMeasuredOn.
  ///
  /// In en, this message translates to:
  /// **'Measured {date}'**
  String tyresMeasuredOn(String date);

  /// No description provided for @tyresBelowLegalAt.
  ///
  /// In en, this message translates to:
  /// **'At or below the {minimum} legal minimum'**
  String tyresBelowLegalAt(String minimum);

  /// No description provided for @tyresWearEstimate.
  ///
  /// In en, this message translates to:
  /// **'About {distance} left, around {date}'**
  String tyresWearEstimate(String distance, String date);

  /// No description provided for @tyresWearEstimateDistanceOnly.
  ///
  /// In en, this message translates to:
  /// **'About {distance} left'**
  String tyresWearEstimateDistanceOnly(Object distance);

  /// No description provided for @economyByFuelOverlap.
  ///
  /// In en, this message translates to:
  /// **'Each fuel is measured over its own fill-ups, but the spans overlap — distance driven on the other fuel is counted in too. Treat these as close, not exact.'**
  String get economyByFuelOverlap;

  /// No description provided for @tyresUneven.
  ///
  /// In en, this message translates to:
  /// **'Uneven: {low} to {high}'**
  String tyresUneven(String low, String high);

  /// No description provided for @tyresFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get tyresFront;

  /// No description provided for @tyresRear.
  ///
  /// In en, this message translates to:
  /// **'Rear'**
  String get tyresRear;

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
  /// **'Reminders'**
  String get vehicleTabMaintenance;

  /// No description provided for @vehicleTabHistory.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get vehicleTabHistory;

  /// No description provided for @vehicleArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get vehicleArchive;

  /// No description provided for @vehicleRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get vehicleRestore;

  /// No description provided for @vehicleArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived. It keeps its history and stays off the lists.'**
  String get vehicleArchived;

  /// No description provided for @vehicleRestored.
  ///
  /// In en, this message translates to:
  /// **'Back in the garage.'**
  String get vehicleRestored;

  /// No description provided for @vehicleDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete vehicle'**
  String get vehicleDelete;

  /// No description provided for @vehicleDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this vehicle?'**
  String get vehicleDeleteTitle;

  /// No description provided for @vehicleDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Every fill-up, service, cost, reading and document logged against it goes too, and none of it can be recovered. Archive it instead to keep the history.'**
  String get vehicleDeleteBody;

  /// No description provided for @vehiclesArchivedSection.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get vehiclesArchivedSection;

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

  /// No description provided for @economyTanksProgress.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 of 2 full tanks logged} other{{count} of 2 full tanks logged}}'**
  String economyTanksProgress(int count);

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

  /// No description provided for @fuelSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved, {amount}.'**
  String fuelSaved(String amount);

  /// No description provided for @fuelSavedFirstFull.
  ///
  /// In en, this message translates to:
  /// **'Saved, {amount}. One more full tank and consumption appears.'**
  String fuelSavedFirstFull(String amount);

  /// No description provided for @fuelSavedPlain.
  ///
  /// In en, this message translates to:
  /// **'Fill-up saved.'**
  String get fuelSavedPlain;

  /// No description provided for @serviceSaved.
  ///
  /// In en, this message translates to:
  /// **'Service logged.'**
  String get serviceSaved;

  /// No description provided for @costDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'The same amount in the same category is already logged on this day'**
  String get costDuplicateWarning;

  /// No description provided for @costSaved.
  ///
  /// In en, this message translates to:
  /// **'Cost saved.'**
  String get costSaved;

  /// No description provided for @fuelAdd.
  ///
  /// In en, this message translates to:
  /// **'Log a fill-up'**
  String get fuelAdd;

  /// No description provided for @fuelLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest fill-ups'**
  String get fuelLatest;

  /// No description provided for @fuelAllFillUps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{All fill-ups (1)} other{All fill-ups ({count})}}'**
  String fuelAllFillUps(num count);

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @vehicleSectionThisCar.
  ///
  /// In en, this message translates to:
  /// **'This car'**
  String get vehicleSectionThisCar;

  /// No description provided for @vehicleOnLoanTo.
  ///
  /// In en, this message translates to:
  /// **'On loan to {label} until {date}'**
  String vehicleOnLoanTo(Object date, Object label);

  /// No description provided for @vehicleOnLoanUntil.
  ///
  /// In en, this message translates to:
  /// **'On loan until {date}'**
  String vehicleOnLoanUntil(Object date);

  /// No description provided for @fuelEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit fill-up'**
  String get fuelEdit;

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

  /// No description provided for @fuelCostPerDistance.
  ///
  /// In en, this message translates to:
  /// **'Fuel cost, latest fill-up'**
  String get fuelCostPerDistance;

  /// No description provided for @fuelNeedTwoValues.
  ///
  /// In en, this message translates to:
  /// **'Enter at least two of volume, price, and total'**
  String get fuelNeedTwoValues;

  /// No description provided for @amountNotANumber.
  ///
  /// In en, this message translates to:
  /// **'Not a number'**
  String get amountNotANumber;

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

  /// No description provided for @fuelOdometerEarlierToday.
  ///
  /// In en, this message translates to:
  /// **'Earlier today: {reading}'**
  String fuelOdometerEarlierToday(String reading);

  /// No description provided for @fuelImpliedConsumption.
  ///
  /// In en, this message translates to:
  /// **'That works out at {rate} — check the odometer and the amount'**
  String fuelImpliedConsumption(String rate);

  /// No description provided for @fuelVolumeOverTank.
  ///
  /// In en, this message translates to:
  /// **'More than the tank holds ({capacity})'**
  String fuelVolumeOverTank(String capacity);

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add a reminder to start tracking what is due'**
  String get maintenanceEmpty;

  /// No description provided for @maintenanceAddRule.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get maintenanceAddRule;

  /// No description provided for @maintenanceRuleSaved.
  ///
  /// In en, this message translates to:
  /// **'Reminder set: {type}'**
  String maintenanceRuleSaved(String type);

  /// No description provided for @maintenanceLogService.
  ///
  /// In en, this message translates to:
  /// **'Log a service'**
  String get maintenanceLogService;

  /// No description provided for @maintenanceEditService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get maintenanceEditService;

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

  /// No description provided for @intervalNoteMake.
  ///
  /// In en, this message translates to:
  /// **'Typical for {make} — confirm in your service book'**
  String intervalNoteMake(String make);

  /// No description provided for @intervalNoteChain.
  ///
  /// In en, this message translates to:
  /// **'This engine has a timing chain, so no interval is needed'**
  String get intervalNoteChain;

  /// No description provided for @intervalNoteWetBelt.
  ///
  /// In en, this message translates to:
  /// **'A belt that runs in oil — most makers have shortened this interval'**
  String get intervalNoteWetBelt;

  /// No description provided for @intervalNoteSetTimingDrive.
  ///
  /// In en, this message translates to:
  /// **'Set the timing drive on the vehicle for a better default'**
  String get intervalNoteSetTimingDrive;

  /// No description provided for @intervalNoteSetTransmission.
  ///
  /// In en, this message translates to:
  /// **'Set the gearbox on the vehicle for a better default'**
  String get intervalNoteSetTransmission;

  /// No description provided for @intervalNoteSealed.
  ///
  /// In en, this message translates to:
  /// **'A dry dual-clutch gearbox is sealed for life'**
  String get intervalNoteSealed;

  /// No description provided for @intervalNoteAdvisory.
  ///
  /// In en, this message translates to:
  /// **'Makers often say \"for life\"; independents change it anyway'**
  String get intervalNoteAdvisory;

  /// No description provided for @maintenanceIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'Set either or both. Whichever comes first wins.'**
  String get maintenanceIntervalHint;

  /// The odometer half of a due line, appended after maintenanceDueOn: "Due 4 Sep 2026 · at 60,000 km". It carries no verb of its own because the date half already did, and joining two whole sentences said "Due" twice.
  ///
  /// In en, this message translates to:
  /// **'at {odometer}'**
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

  /// Shown under a due line whose odometer deadline binds first, naming the later calendar one. A rule with two intervals has two deadlines and which one binds is what a driver plans around.
  ///
  /// In en, this message translates to:
  /// **'By date not until {date}'**
  String maintenanceOtherDeadlineByDate(String date);

  /// The mirror of maintenanceOtherDeadlineByDate: shown when the calendar binds first, naming when this vehicle is expected to reach the odometer target at its current rate.
  ///
  /// In en, this message translates to:
  /// **'By distance not until {date}'**
  String maintenanceOtherDeadlineByDistance(String date);

  /// No description provided for @maintenanceRateMeasured.
  ///
  /// In en, this message translates to:
  /// **'Dates below are estimated from {rate}/day over {days, plural, =1{1 day} other{{days} days}} of readings'**
  String maintenanceRateMeasured(num days, String rate);

  /// No description provided for @maintenanceRateUnmeasured.
  ///
  /// In en, this message translates to:
  /// **'No driving rate yet: the dates below come from the calendar interval. A couple of weeks of readings and the distance estimate appears; a rule with only a distance assumes {rate}/day until then.'**
  String maintenanceRateUnmeasured(String rate);

  /// The cost of a service visit that covered several items. Shown instead of the bare amount so one 200 EUR visit across four items does not read as four 200 EUR visits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{amount} for {count} item} other{{amount} for {count} items}}'**
  String maintenanceCostForItems(String amount, num count);

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

  /// The due line for an item whose date was extrapolated from how fast the car is being driven, rather than fixed by a calendar interval or a one-off's own date. Deliberately a different verb from maintenanceDueOn: the distance date moves every time a reading is logged, and stating it as "Due" presented a forecast as a fact.
  ///
  /// In en, this message translates to:
  /// **'Expected {date}'**
  String maintenanceExpectedOn(String date);

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

  /// No description provided for @serviceDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'The same work at the same odometer is already logged on this day'**
  String get serviceDuplicateWarning;

  /// No description provided for @documentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documentsTitle;

  /// No description provided for @documentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Registration, roadworthiness, insurance — and when each runs out'**
  String get documentsSubtitle;

  /// No description provided for @documentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents yet. Record when the registration and the roadworthiness certificate run out, and the app will tell you before they do.'**
  String get documentsEmpty;

  /// No description provided for @documentsSomethingExpired.
  ///
  /// In en, this message translates to:
  /// **'Something has run out'**
  String get documentsSomethingExpired;

  /// No description provided for @documentsSomethingExpiring.
  ///
  /// In en, this message translates to:
  /// **'Something runs out soon'**
  String get documentsSomethingExpiring;

  /// No description provided for @documentAdd.
  ///
  /// In en, this message translates to:
  /// **'Add document'**
  String get documentAdd;

  /// No description provided for @documentEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit document'**
  String get documentEdit;

  /// No description provided for @documentType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get documentType;

  /// No description provided for @documentLabel.
  ///
  /// In en, this message translates to:
  /// **'What it is'**
  String get documentLabel;

  /// No description provided for @documentLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Only for a document this list does not name'**
  String get documentLabelHint;

  /// No description provided for @documentNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get documentNumber;

  /// No description provided for @documentIssuer.
  ///
  /// In en, this message translates to:
  /// **'Issued by'**
  String get documentIssuer;

  /// No description provided for @documentIssuedOn.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get documentIssuedOn;

  /// No description provided for @documentExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get documentExpiresOn;

  /// No description provided for @documentDateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get documentDateNotSet;

  /// No description provided for @documentClearDate.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get documentClearDate;

  /// No description provided for @documentNoExpiry.
  ///
  /// In en, this message translates to:
  /// **'No expiry recorded'**
  String get documentNoExpiry;

  /// No description provided for @documentExpiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String documentExpiredOn(String date);

  /// No description provided for @documentExpiresToday.
  ///
  /// In en, this message translates to:
  /// **'Expires today'**
  String get documentExpiresToday;

  /// No description provided for @documentExpiresInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Expires tomorrow} other{Expires in {count} days}}'**
  String documentExpiresInDays(int count);

  /// No description provided for @documentValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String documentValidUntil(String date);

  /// No description provided for @documentDatesOutOfOrder.
  ///
  /// In en, this message translates to:
  /// **'Cannot run out before it was issued'**
  String get documentDatesOutOfOrder;

  /// No description provided for @documentLabelRequired.
  ///
  /// In en, this message translates to:
  /// **'Say what this document is'**
  String get documentLabelRequired;

  /// No description provided for @documentSaved.
  ///
  /// In en, this message translates to:
  /// **'Document saved.'**
  String get documentSaved;

  /// No description provided for @documentReminderNote.
  ///
  /// In en, this message translates to:
  /// **'A reminder is set from the expiry, so this turns up in the planner before it runs out.'**
  String get documentReminderNote;

  /// No description provided for @documentNoReminderNote.
  ///
  /// In en, this message translates to:
  /// **'No reminder: the app has no name for this one, so it cannot say what is coming due.'**
  String get documentNoReminderNote;

  /// No description provided for @documentTypeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get documentTypeRegistration;

  /// No description provided for @documentTypeRoadworthiness.
  ///
  /// In en, this message translates to:
  /// **'Roadworthiness test'**
  String get documentTypeRoadworthiness;

  /// No description provided for @documentTypeInsuranceLiability.
  ///
  /// In en, this message translates to:
  /// **'Liability insurance'**
  String get documentTypeInsuranceLiability;

  /// No description provided for @documentTypeInsuranceComprehensive.
  ///
  /// In en, this message translates to:
  /// **'Comprehensive insurance'**
  String get documentTypeInsuranceComprehensive;

  /// No description provided for @documentTypeGreenCard.
  ///
  /// In en, this message translates to:
  /// **'Green card'**
  String get documentTypeGreenCard;

  /// No description provided for @documentTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get documentTypeOther;

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

  /// No description provided for @serviceTypeChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a service type'**
  String get serviceTypeChoose;

  /// No description provided for @serviceTypeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get serviceTypeSearch;

  /// No description provided for @serviceTypeCommon.
  ///
  /// In en, this message translates to:
  /// **'Common'**
  String get serviceTypeCommon;

  /// No description provided for @serviceTypeOthers.
  ///
  /// In en, this message translates to:
  /// **'Everything else'**
  String get serviceTypeOthers;

  /// No description provided for @serviceTypeNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches'**
  String get serviceTypeNoMatch;

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

  /// No description provided for @serviceGreenCard.
  ///
  /// In en, this message translates to:
  /// **'Green card expires'**
  String get serviceGreenCard;

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

  /// No description provided for @plannerAddReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get plannerAddReminder;

  /// No description provided for @plannerOverdueNote.
  ///
  /// In en, this message translates to:
  /// **'Anything overdue sits under today, because today is when it needs doing'**
  String get plannerOverdueNote;

  /// No description provided for @plannerFurtherOut.
  ///
  /// In en, this message translates to:
  /// **'Further out'**
  String get plannerFurtherOut;

  /// No description provided for @plannerFurtherOutNote.
  ///
  /// In en, this message translates to:
  /// **'Beyond the twelve weeks, by month.'**
  String get plannerFurtherOutNote;

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

  /// No description provided for @dashboardDueSoonest.
  ///
  /// In en, this message translates to:
  /// **'Due soonest'**
  String get dashboardDueSoonest;

  /// No description provided for @dashboardNextUp.
  ///
  /// In en, this message translates to:
  /// **'Next: {what} · {when}'**
  String dashboardNextUp(String what, String when);

  /// No description provided for @dashboardOverdueNow.
  ///
  /// In en, this message translates to:
  /// **'Overdue: {what}'**
  String dashboardOverdueNow(String what);

  /// No description provided for @dashboardDueByDistance.
  ///
  /// In en, this message translates to:
  /// **'by distance, about {rate} a day'**
  String dashboardDueByDistance(String rate);

  /// No description provided for @dashboardDueByDistanceAssumed.
  ///
  /// In en, this message translates to:
  /// **'by distance, assuming {rate} a day'**
  String dashboardDueByDistanceAssumed(String rate);

  /// No description provided for @dashboardDueByDateOnly.
  ///
  /// In en, this message translates to:
  /// **'by date; a couple of weeks of driving and the distance estimate appears'**
  String get dashboardDueByDateOnly;

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

  /// No description provided for @bundleLogVisit.
  ///
  /// In en, this message translates to:
  /// **'Log this visit'**
  String get bundleLogVisit;

  /// No description provided for @bundleExcludeHint.
  ///
  /// In en, this message translates to:
  /// **'Trimming an item only changes the suggestion above — nothing is logged or cancelled.'**
  String get bundleExcludeHint;

  /// No description provided for @bundlePutBack.
  ///
  /// In en, this message translates to:
  /// **'Put back'**
  String get bundlePutBack;

  /// No description provided for @bundleOneVehicleOnly.
  ///
  /// In en, this message translates to:
  /// **'Log it per vehicle: these are on more than one.'**
  String get bundleOneVehicleOnly;

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
  /// **'Every vehicle in the garage in one place: fuel, servicing, costs, and what falls due next.'**
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
  /// **'No ads, ever. Free for a small garage. What you have already logged never goes behind a paywall.'**
  String get aboutPromiseFree;

  /// No description provided for @aboutPromiseData.
  ///
  /// In en, this message translates to:
  /// **'Your records are yours. Export everything as CSV whenever you like — it opens in any spreadsheet.'**
  String get aboutPromiseData;

  /// No description provided for @aboutPromiseLeave.
  ///
  /// In en, this message translates to:
  /// **'Leaving is deliberately easy. Delete your account and your garage goes with it. A garage you share stays with the others, and keeps what you logged without your name on it.'**
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

  /// No description provided for @aboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get aboutSourceCode;

  /// No description provided for @aboutSourceCodeHint.
  ///
  /// In en, this message translates to:
  /// **'The whole app is open source, under AGPL-3.0'**
  String get aboutSourceCodeHint;

  /// Row that opens an email to the app's support address for a bug report or suggestion.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get aboutSendFeedback;

  /// Subtitle under aboutSendFeedback.
  ///
  /// In en, this message translates to:
  /// **'A bug, an idea, or just to say hello'**
  String get aboutSendFeedbackHint;

  /// Subject line of the feedback email.
  ///
  /// In en, this message translates to:
  /// **'Garage feedback'**
  String get aboutFeedbackSubject;

  /// No description provided for @aboutDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get aboutDiagnostics;

  /// No description provided for @aboutDiagnosticsHint.
  ///
  /// In en, this message translates to:
  /// **'Recent errors, to send with a bug report'**
  String get aboutDiagnosticsHint;

  /// No description provided for @diagnosticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnosticsTitle;

  /// No description provided for @diagnosticsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has gone wrong on this device.'**
  String get diagnosticsEmpty;

  /// No description provided for @diagnosticsExplain.
  ///
  /// In en, this message translates to:
  /// **'Kept only on this device. Nothing is sent anywhere until you share it.'**
  String get diagnosticsExplain;

  /// No description provided for @diagnosticsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get diagnosticsShare;

  /// No description provided for @diagnosticsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get diagnosticsClear;

  /// No description provided for @diagnosticsCleared.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics cleared'**
  String get diagnosticsCleared;

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
  /// **'That backup has no vehicle in it. Add a vehicle first, then import into it.'**
  String get settingsImportNoVehicle;

  /// Label on the optional field in the Fuelio import dialog that sets one station on every imported fill-up. Shown only when the file names no station on any row, which is what a real Fuelio export does — its City and StationID columns are both empty.
  ///
  /// In en, this message translates to:
  /// **'Fuel station'**
  String get settingsImportStation;

  /// Hint under settingsImportStation, explaining why the app is asking rather than importing the value.
  ///
  /// In en, this message translates to:
  /// **'Optional — this file does not say where you filled up'**
  String get settingsImportStationHint;

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

  /// No description provided for @householdInviteActiveUntil.
  ///
  /// In en, this message translates to:
  /// **'Ready to send · works until {until}'**
  String householdInviteActiveUntil(String until);

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

  /// No description provided for @householdInviteRevokeTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke this code?'**
  String get householdInviteRevokeTitle;

  /// No description provided for @householdInviteRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'Whoever has it can no longer join with it. You can make a new one.'**
  String get householdInviteRevokeBody;

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

  /// No description provided for @economyScale.
  ///
  /// In en, this message translates to:
  /// **'Best {best} · Worst {worst} on this vehicle'**
  String economyScale(String best, String worst);

  /// No description provided for @economyScaleNone.
  ///
  /// In en, this message translates to:
  /// **'Log a few full tanks to compare against'**
  String get economyScaleNone;

  /// No description provided for @economyScaleDefault.
  ///
  /// In en, this message translates to:
  /// **'The ring runs {best} to {worst} until this car has a range of its own'**
  String economyScaleDefault(String best, String worst);

  /// No description provided for @maintenanceLastDone.
  ///
  /// In en, this message translates to:
  /// **'Last done (optional)'**
  String get maintenanceLastDone;

  /// No description provided for @maintenanceLastDoneHint.
  ///
  /// In en, this message translates to:
  /// **'If you have already done this, say when: intervals count from there instead of from when the vehicle was added'**
  String get maintenanceLastDoneHint;

  /// No description provided for @maintenanceLastDoneDate.
  ///
  /// In en, this message translates to:
  /// **'Date it was done'**
  String get maintenanceLastDoneDate;

  /// No description provided for @maintenanceLastDoneDatePick.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get maintenanceLastDoneDatePick;

  /// No description provided for @maintenanceLastDoneKm.
  ///
  /// In en, this message translates to:
  /// **'Odometer when done'**
  String get maintenanceLastDoneKm;

  /// No description provided for @maintenanceLastDoneFromLog.
  ///
  /// In en, this message translates to:
  /// **'Taken from the service you logged on {date}'**
  String maintenanceLastDoneFromLog(String date);

  /// No description provided for @runningCostTitle.
  ///
  /// In en, this message translates to:
  /// **'What this vehicle costs'**
  String get runningCostTitle;

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

  /// No description provided for @runningCostSpread.
  ///
  /// In en, this message translates to:
  /// **'Yearly cover such as insurance and registration is spread over its year for the per-month and per-year figures.'**
  String get runningCostSpread;

  /// No description provided for @runningCostToOwn.
  ///
  /// In en, this message translates to:
  /// **'{rate} to own, with the value it has lost'**
  String runningCostToOwn(String rate);

  /// No description provided for @runningCostValuationStale.
  ///
  /// In en, this message translates to:
  /// **'Based on a valuation over a year old — update it on the vehicle\'s page.'**
  String get runningCostValuationStale;

  /// No description provided for @runningCostOwnership.
  ///
  /// In en, this message translates to:
  /// **'Cost of ownership so far'**
  String get runningCostOwnership;

  /// No description provided for @runningCostNotEnough.
  ///
  /// In en, this message translates to:
  /// **'Log some fuel and costs to see what this vehicle costs to run'**
  String get runningCostNotEnough;

  /// No description provided for @runningCostNeedsTank.
  ///
  /// In en, this message translates to:
  /// **'One more full tank and the cost per distance appears'**
  String get runningCostNeedsTank;

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

  /// No description provided for @quickAddFuel.
  ///
  /// In en, this message translates to:
  /// **'Fill-up'**
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
  /// **'Which vehicle?'**
  String get quickAddPickVehicle;

  /// No description provided for @settingsPumpAutofill.
  ///
  /// In en, this message translates to:
  /// **'Fill in the station and price for me'**
  String get settingsPumpAutofill;

  /// No description provided for @settingsDataBringIn.
  ///
  /// In en, this message translates to:
  /// **'Bring data in'**
  String get settingsDataBringIn;

  /// No description provided for @settingsDataTakeOut.
  ///
  /// In en, this message translates to:
  /// **'Take data out'**
  String get settingsDataTakeOut;

  /// No description provided for @settingsForDevelopers.
  ///
  /// In en, this message translates to:
  /// **'For developers'**
  String get settingsForDevelopers;

  /// No description provided for @settingsFillUps.
  ///
  /// In en, this message translates to:
  /// **'Fill-ups'**
  String get settingsFillUps;

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
  /// **'Adds one vehicle with a year of fill-ups, services and costs, so every screen has something to show. Remove it with More → Settings → Delete all data.'**
  String get settingsSampleDataHint;

  /// Title of the confirmation shown before the demo garage is written into a real one.
  ///
  /// In en, this message translates to:
  /// **'Load sample data?'**
  String get settingsSampleDataConfirmTitle;

  /// Body of the sample-data confirmation. Names the car because the demo vehicle is a Renault Clio and anyone who owns one otherwise ends up with two identically named cars and no way to tell which is theirs.
  ///
  /// In en, this message translates to:
  /// **'This adds a demo car ({vehicle}) with a year of history to this garage, alongside what you already have. You can delete it afterwards.'**
  String settingsSampleDataConfirmBody(String vehicle);

  /// No description provided for @settingsSampleDataDone.
  ///
  /// In en, this message translates to:
  /// **'Sample vehicle added'**
  String get settingsSampleDataDone;

  /// No description provided for @gettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting started'**
  String get gettingStarted;

  /// No description provided for @gettingStartedFirstVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add your first vehicle'**
  String get gettingStartedFirstVehicle;

  /// No description provided for @gettingStartedImport.
  ///
  /// In en, this message translates to:
  /// **'Import from another app'**
  String get gettingStartedImport;

  /// No description provided for @gettingStartedTransfer.
  ///
  /// In en, this message translates to:
  /// **'Receive a vehicle with a code'**
  String get gettingStartedTransfer;

  /// No description provided for @gettingStartedNext.
  ///
  /// In en, this message translates to:
  /// **'What next'**
  String get gettingStartedNext;

  /// No description provided for @gettingStartedFuel.
  ///
  /// In en, this message translates to:
  /// **'Log a fill-up'**
  String get gettingStartedFuel;

  /// No description provided for @gettingStartedReminder.
  ///
  /// In en, this message translates to:
  /// **'Set a reminder: what it needs, and when'**
  String get gettingStartedReminder;

  /// No description provided for @gettingStartedSample.
  ///
  /// In en, this message translates to:
  /// **'Or load sample data to look around first'**
  String get gettingStartedSample;

  /// No description provided for @gettingStartedTour.
  ///
  /// In en, this message translates to:
  /// **'See everything Garage can do'**
  String get gettingStartedTour;

  /// No description provided for @gettingStartedHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get gettingStartedHide;

  /// No description provided for @featuresTitle.
  ///
  /// In en, this message translates to:
  /// **'What Garage can do'**
  String get featuresTitle;

  /// No description provided for @featuresHint.
  ///
  /// In en, this message translates to:
  /// **'A one-page tour of the main things, and where each one lives'**
  String get featuresHint;

  /// No description provided for @featureAddVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add a vehicle'**
  String get featureAddVehicle;

  /// No description provided for @featureAddVehicleBlurb.
  ///
  /// In en, this message translates to:
  /// **'A car, a motorcycle or a van. Type the VIN and the make, model and year fill themselves in.'**
  String get featureAddVehicleBlurb;

  /// No description provided for @featureFuel.
  ///
  /// In en, this message translates to:
  /// **'Fuel log'**
  String get featureFuel;

  /// No description provided for @featureFuelBlurb.
  ///
  /// In en, this message translates to:
  /// **'Log a fill-up in seconds from the dashboard. Consumption, cost per kilometre and how far a full tank goes follow on their own.'**
  String get featureFuelBlurb;

  /// No description provided for @featurePlannerBlurb.
  ///
  /// In en, this message translates to:
  /// **'What each vehicle needs next, week by week, and which jobs are worth bundling into one visit to the shop.'**
  String get featurePlannerBlurb;

  /// No description provided for @featureTimelineBlurb.
  ///
  /// In en, this message translates to:
  /// **'Everything that happened to every vehicle, month by month, with what each month came to.'**
  String get featureTimelineBlurb;

  /// No description provided for @featureStatsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Consumption, spend and distance over any period, per vehicle or for the whole garage.'**
  String get featureStatsBlurb;

  /// No description provided for @featureStationsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Today\'s fuel prices nearby, and whether they rose or fell this week.'**
  String get featureStationsBlurb;

  /// No description provided for @featureTripsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Log private and business trips; the distance comes from the odometer.'**
  String get featureTripsBlurb;

  /// No description provided for @featureCalculatorBlurb.
  ///
  /// In en, this message translates to:
  /// **'Trip cost, range or consumption from the numbers you have.'**
  String get featureCalculatorBlurb;

  /// No description provided for @featureTyres.
  ///
  /// In en, this message translates to:
  /// **'Tyres'**
  String get featureTyres;

  /// No description provided for @featureTyresBlurb.
  ///
  /// In en, this message translates to:
  /// **'Tyre sets, the seasonal swap, tread depth and age, on each vehicle\'s page.'**
  String get featureTyresBlurb;

  /// No description provided for @featureDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get featureDocuments;

  /// No description provided for @featureDocumentsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Registration, roadworthiness, insurance and the green card, each with the date it runs out — and a reminder before it does.'**
  String get featureDocumentsBlurb;

  /// No description provided for @featureReceipts.
  ///
  /// In en, this message translates to:
  /// **'Receipts and invoices'**
  String get featureReceipts;

  /// No description provided for @featureReceiptsBlurb.
  ///
  /// In en, this message translates to:
  /// **'Attach the pump receipt or the shop invoice to its entry once it is saved, and find it years later when you sell the car.'**
  String get featureReceiptsBlurb;

  /// No description provided for @featureShare.
  ///
  /// In en, this message translates to:
  /// **'Share the garage'**
  String get featureShare;

  /// No description provided for @featureShareBlurb.
  ///
  /// In en, this message translates to:
  /// **'Invite whoever shares the car. Everyone sees the same log, and the costs are split.'**
  String get featureShareBlurb;

  /// No description provided for @featureLend.
  ///
  /// In en, this message translates to:
  /// **'Lend a car'**
  String get featureLend;

  /// No description provided for @featureLendBlurb.
  ///
  /// In en, this message translates to:
  /// **'Give somebody a code and they can log fuel and drives on one car for a few days, without joining your garage or seeing your history.'**
  String get featureLendBlurb;

  /// No description provided for @featureData.
  ///
  /// In en, this message translates to:
  /// **'Import, export and backup'**
  String get featureData;

  /// No description provided for @featureDataBlurb.
  ///
  /// In en, this message translates to:
  /// **'Bring your history from Fuelio or any CSV; export it or back it all up any time.'**
  String get featureDataBlurb;

  /// No description provided for @featureApiBlurb.
  ///
  /// In en, this message translates to:
  /// **'Read your own data from a script or a spreadsheet with a key.'**
  String get featureApiBlurb;

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

  /// No description provided for @odometerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit reading'**
  String get odometerEdit;

  /// No description provided for @odometerReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get odometerReading;

  /// No description provided for @odometerHint.
  ///
  /// In en, this message translates to:
  /// **'A reading with no money attached, so maintenance still knows how far the vehicle has gone.'**
  String get odometerHint;

  /// No description provided for @quickAddOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get quickAddOdometer;

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

  /// Title of the stats section comparing fuel economy between filling stations.
  ///
  /// In en, this message translates to:
  /// **'Economy by station'**
  String get statsEconomyByStation;

  /// Caveat under the economy-by-station section. Fuel brand is a small effect next to how and where the car was driven, and the section must not read as a recommendation to change where you buy fuel.
  ///
  /// In en, this message translates to:
  /// **'An observation, not advice — driving, weather and season move economy far more than fuel does'**
  String get statsEconomyByStationNote;

  /// How many full-tank spans a station's figure rests on. Shown so the reader can weigh four tanks differently from forty.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 tank} other{{count} tanks}}'**
  String statsEconomyTanks(int count);

  /// No description provided for @statsOdometerChart.
  ///
  /// In en, this message translates to:
  /// **'Odometer over time'**
  String get statsOdometerChart;

  /// No description provided for @statsFullTankRange.
  ///
  /// In en, this message translates to:
  /// **'On a full tank'**
  String get statsFullTankRange;

  /// No description provided for @statsFullTankTypical.
  ///
  /// In en, this message translates to:
  /// **'Typical'**
  String get statsFullTankTypical;

  /// No description provided for @statsFullTankBest.
  ///
  /// In en, this message translates to:
  /// **'Best tank'**
  String get statsFullTankBest;

  /// No description provided for @statsFullTankWorst.
  ///
  /// In en, this message translates to:
  /// **'Worst tank'**
  String get statsFullTankWorst;

  /// No description provided for @statsFullTankSize.
  ///
  /// In en, this message translates to:
  /// **'Tank'**
  String get statsFullTankSize;

  /// No description provided for @statsFullTankTanks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{From {count} full tank, all time} other{From {count} full tanks, all time}}'**
  String statsFullTankTanks(int count);

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
  /// **'Trips'**
  String get tripsTitle;

  /// No description provided for @tripAdd.
  ///
  /// In en, this message translates to:
  /// **'Log a trip'**
  String get tripAdd;

  /// No description provided for @tripEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get tripEdit;

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

  /// No description provided for @tripImpliedSpeed.
  ///
  /// In en, this message translates to:
  /// **'That works out at {speed} — check the distance and the time'**
  String tripImpliedSpeed(String speed);

  /// No description provided for @tripDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get tripDriver;

  /// No description provided for @tripDriverHint.
  ///
  /// In en, this message translates to:
  /// **'Who was at the wheel — a mileage logbook for tax names them, and it is not always whoever typed the entry.'**
  String get tripDriverHint;

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

  /// No description provided for @tripDriveStart.
  ///
  /// In en, this message translates to:
  /// **'Start a drive'**
  String get tripDriveStart;

  /// No description provided for @tripDriveInProgress.
  ///
  /// In en, this message translates to:
  /// **'Drive in progress'**
  String get tripDriveInProgress;

  /// No description provided for @tripDriveSince.
  ///
  /// In en, this message translates to:
  /// **'Set off at {time}'**
  String tripDriveSince(String time);

  /// No description provided for @tripDriveElapsed.
  ///
  /// In en, this message translates to:
  /// **'{duration} so far'**
  String tripDriveElapsed(String duration);

  /// No description provided for @tripDriveFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish drive'**
  String get tripDriveFinish;

  /// No description provided for @tripDriveDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get tripDriveDiscard;

  /// No description provided for @tripDriveDiscardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard this drive? Nothing will be logged for it.'**
  String get tripDriveDiscardConfirm;

  /// No description provided for @tripDriveOdometerNow.
  ///
  /// In en, this message translates to:
  /// **'Odometer now'**
  String get tripDriveOdometerNow;

  /// No description provided for @tripDriveOdometerNowHint.
  ///
  /// In en, this message translates to:
  /// **'What the dashboard reads. Leave it blank if you cannot see it.'**
  String get tripDriveOdometerNowHint;

  /// No description provided for @tripDriveStarted.
  ///
  /// In en, this message translates to:
  /// **'Drive started. Finish it when you park.'**
  String get tripDriveStarted;

  /// No description provided for @tripDriveFinished.
  ///
  /// In en, this message translates to:
  /// **'Drive logged: {distance}'**
  String tripDriveFinished(String distance);

  /// No description provided for @tripDriveAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'That car is already out on a drive.'**
  String get tripDriveAlreadyOpen;

  /// No description provided for @tripDriveNeedsMeasure.
  ///
  /// In en, this message translates to:
  /// **'Enter the odometer now, or a distance.'**
  String get tripDriveNeedsMeasure;

  /// No description provided for @tripDriveStartedBy.
  ///
  /// In en, this message translates to:
  /// **'Started by {name}'**
  String tripDriveStartedBy(String name);

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

  /// No description provided for @incomeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit income'**
  String get incomeEdit;

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
  /// **'Sold the vehicle'**
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

  /// No description provided for @quickAddMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get quickAddMore;

  /// No description provided for @statsBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get statsBalance;

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
  /// **'You are already in {current}. Joining {name} adds it — you can switch between them.'**
  String joinSecondGarage(String current, String name);

  /// No description provided for @joinFor.
  ///
  /// In en, this message translates to:
  /// **'This invite is for the garage {name}.'**
  String joinFor(String name);

  /// No description provided for @joinAlreadyMember.
  ///
  /// In en, this message translates to:
  /// **'You are already in {name}. There is nothing to join.'**
  String joinAlreadyMember(String name);

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
  /// **'Transfer this vehicle'**
  String get transferTitle;

  /// No description provided for @transferCodeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel this transfer'**
  String get transferCodeCancel;

  /// No description provided for @transferCodeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Transfer cancelled. The code no longer works.'**
  String get transferCodeCancelled;

  /// No description provided for @transferSellHint.
  ///
  /// In en, this message translates to:
  /// **'Hand the buyer this code. The vehicle and its whole history move into their garage, and out of yours.'**
  String get transferSellHint;

  /// No description provided for @transferBought.
  ///
  /// In en, this message translates to:
  /// **'Bought a vehicle?'**
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

  /// No description provided for @transferConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Hand this vehicle over?'**
  String get transferConfirmTitle;

  /// No description provided for @transferRedeem.
  ///
  /// In en, this message translates to:
  /// **'Redeem a code'**
  String get transferRedeem;

  /// No description provided for @transferCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get transferCompletedTitle;

  /// No description provided for @transferCompletedNamed.
  ///
  /// In en, this message translates to:
  /// **'{nickname} is now in its new owner’s garage, with all its history.'**
  String transferCompletedNamed(String nickname);

  /// No description provided for @transferCompleted.
  ///
  /// In en, this message translates to:
  /// **'A vehicle you transferred is now in its new owner’s garage.'**
  String get transferCompleted;

  /// No description provided for @transferCompletedDismiss.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get transferCompletedDismiss;

  /// No description provided for @transferSell.
  ///
  /// In en, this message translates to:
  /// **'Sold the vehicle?'**
  String get transferSell;

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
  /// **'The vehicle is in your garage now.'**
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
  /// **'For a vehicle that runs on two — LPG beside petrol. Each fill-up then says which went in.'**
  String get vehicleSecondFuelHint;

  /// No description provided for @vehicleSecondFuelNone.
  ///
  /// In en, this message translates to:
  /// **'No second fuel'**
  String get vehicleSecondFuelNone;

  /// No description provided for @vehicleKind.
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get vehicleKind;

  /// No description provided for @vehicleSectionEngine.
  ///
  /// In en, this message translates to:
  /// **'Engine and fuel'**
  String get vehicleSectionEngine;

  /// No description provided for @vehicleSectionOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get vehicleSectionOptional;

  /// No description provided for @vehicleKindCar.
  ///
  /// In en, this message translates to:
  /// **'Car'**
  String get vehicleKindCar;

  /// No description provided for @vehicleKindMotorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get vehicleKindMotorcycle;

  /// No description provided for @vehicleKindVan.
  ///
  /// In en, this message translates to:
  /// **'Van'**
  String get vehicleKindVan;

  /// No description provided for @vehicleFinalDrive.
  ///
  /// In en, this message translates to:
  /// **'Final drive'**
  String get vehicleFinalDrive;

  /// No description provided for @vehicleFinalDriveNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get vehicleFinalDriveNotSet;

  /// No description provided for @finalDriveChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get finalDriveChain;

  /// No description provided for @finalDriveBelt.
  ///
  /// In en, this message translates to:
  /// **'Belt'**
  String get finalDriveBelt;

  /// No description provided for @finalDriveShaft.
  ///
  /// In en, this message translates to:
  /// **'Shaft'**
  String get finalDriveShaft;

  /// No description provided for @vehicleTimingDrive.
  ///
  /// In en, this message translates to:
  /// **'Timing belt or chain'**
  String get vehicleTimingDrive;

  /// No description provided for @vehicleTimingDriveNotSet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t know'**
  String get vehicleTimingDriveNotSet;

  /// No description provided for @vehicleTimingDriveHint.
  ///
  /// In en, this message translates to:
  /// **'Belt-in-oil: PureTech, EcoBoost, 1.0 TCe — the belt runs in the engine oil'**
  String get vehicleTimingDriveHint;

  /// No description provided for @timingDriveBelt.
  ///
  /// In en, this message translates to:
  /// **'Belt'**
  String get timingDriveBelt;

  /// No description provided for @timingDriveChain.
  ///
  /// In en, this message translates to:
  /// **'Chain'**
  String get timingDriveChain;

  /// No description provided for @timingDriveWetBelt.
  ///
  /// In en, this message translates to:
  /// **'Belt-in-oil'**
  String get timingDriveWetBelt;

  /// No description provided for @vehicleTransmission.
  ///
  /// In en, this message translates to:
  /// **'Gearbox'**
  String get vehicleTransmission;

  /// No description provided for @vehicleTransmissionNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get vehicleTransmissionNotSet;

  /// No description provided for @transmissionManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get transmissionManual;

  /// No description provided for @transmissionAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get transmissionAutomatic;

  /// No description provided for @transmissionDctDry.
  ///
  /// In en, this message translates to:
  /// **'Dual-clutch, dry'**
  String get transmissionDctDry;

  /// No description provided for @transmissionDctWet.
  ///
  /// In en, this message translates to:
  /// **'Dual-clutch, wet'**
  String get transmissionDctWet;

  /// No description provided for @transmissionCvt.
  ///
  /// In en, this message translates to:
  /// **'CVT'**
  String get transmissionCvt;

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
  /// **'Which vehicle'**
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

  /// Row that turns on writing a daily backup into a folder the user picks.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get settingsAutoBackup;

  /// Subtitle when no backup folder has been chosen. Says what choosing one will do.
  ///
  /// In en, this message translates to:
  /// **'Off — pick a folder to back up into once a day'**
  String get settingsAutoBackupOff;

  /// Subtitle when automatic backup is on, naming when it last ran.
  ///
  /// In en, this message translates to:
  /// **'Once a day, last backed up {when}'**
  String settingsAutoBackupOn(String when);

  /// Toast shown the moment an automatic backup actually writes a file, so a feature running silently in the background is not invisible the one time a household might want to know it worked.
  ///
  /// In en, this message translates to:
  /// **'Backed up automatically'**
  String get settingsAutoBackupJustRan;

  /// Subtitle when a folder is chosen but no backup has been written yet.
  ///
  /// In en, this message translates to:
  /// **'Once a day, not run yet'**
  String get settingsAutoBackupNever;

  /// Action that forgets the chosen backup folder.
  ///
  /// In en, this message translates to:
  /// **'Stop backing up'**
  String get settingsAutoBackupStop;

  /// No description provided for @settingsExportHint.
  ///
  /// In en, this message translates to:
  /// **'A zip of spreadsheets, one file per car and per kind. Readable anywhere; use a backup to restore.'**
  String get settingsExportHint;

  /// No description provided for @settingsImportCsvHint.
  ///
  /// In en, this message translates to:
  /// **'From Drivvo, a spreadsheet, or anything else that exports a table. Adds what is missing; nothing is overwritten.'**
  String get settingsImportCsvHint;

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
  /// **'Backup saved: {file}'**
  String settingsBackupDone(String file);

  /// No description provided for @settingsRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'{vehicles} vehicles, {written} entries added, {skipped} already there'**
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

  /// No description provided for @stationsGradeStations.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{1 station}other{{count} stations}}'**
  String stationsGradeStations(int count);

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @householdInviteCopyManually.
  ///
  /// In en, this message translates to:
  /// **'Copy this message and send it however you like.'**
  String get householdInviteCopyManually;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get commonPrevious;

  /// No description provided for @commonIncrease.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get commonIncrease;

  /// No description provided for @commonDecrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get commonDecrease;

  /// No description provided for @commonShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get commonShowPassword;

  /// No description provided for @commonHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get commonHidePassword;

  /// No description provided for @householdRename.
  ///
  /// In en, this message translates to:
  /// **'Rename garage'**
  String get householdRename;

  /// No description provided for @householdRenamed.
  ///
  /// In en, this message translates to:
  /// **'Garage renamed'**
  String get householdRenamed;

  /// No description provided for @householdRenameAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can rename the garage'**
  String get householdRenameAdminOnly;

  /// No description provided for @householdDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete garage'**
  String get householdDelete;

  /// No description provided for @householdDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this garage?'**
  String get householdDeleteTitle;

  /// No description provided for @householdDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This ends the garage for everyone in it, not just for you. Every vehicle, entry and reminder goes with it.'**
  String get householdDeleteBody;

  /// No description provided for @maintenanceLogServiceHint.
  ///
  /// In en, this message translates to:
  /// **'Something that has been done'**
  String get maintenanceLogServiceHint;

  /// No description provided for @maintenanceAddRuleHint.
  ///
  /// In en, this message translates to:
  /// **'Something that should come round again'**
  String get maintenanceAddRuleHint;

  /// No description provided for @quickAddInterval.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get quickAddInterval;

  /// No description provided for @settingsMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get settingsMore;

  /// No description provided for @settingsPreferencesHint.
  ///
  /// In en, this message translates to:
  /// **'Units, currency, theme and language'**
  String get settingsPreferencesHint;

  /// No description provided for @settingsDataHint.
  ///
  /// In en, this message translates to:
  /// **'Import, export and backups'**
  String get settingsDataHint;

  /// No description provided for @timelineSearch.
  ///
  /// In en, this message translates to:
  /// **'Search history'**
  String get timelineSearch;

  /// No description provided for @timelineNoMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches that.'**
  String get timelineNoMatches;

  /// No description provided for @timelineSearchCovers.
  ///
  /// In en, this message translates to:
  /// **'Search covers the kind of entry, the car, who logged it, the date and the notes.'**
  String get timelineSearchCovers;

  /// No description provided for @timelineFilterVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get timelineFilterVehicle;

  /// No description provided for @timelineBalanceNet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction, balance {amount}} other{{count} transactions, balance {amount}}}'**
  String timelineBalanceNet(int count, String amount);

  /// Closes the timeline: how many entries moved money and what they came to, when more went out than came in. The count excludes odometer readings and trips, which are rows without an amount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction, spent {amount}} other{{count} transactions, spent {amount}}}'**
  String timelineBalanceSpent(String amount, num count);

  /// The same line for a period whose income beat its costs — a car earning its keep as a taxi.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction, received {amount}} other{{count} transactions, received {amount}}}'**
  String timelineBalanceReceived(String amount, num count);

  /// No description provided for @serviceBrakeDiscsFront.
  ///
  /// In en, this message translates to:
  /// **'Front brake discs'**
  String get serviceBrakeDiscsFront;

  /// No description provided for @serviceBrakeDiscsRear.
  ///
  /// In en, this message translates to:
  /// **'Rear brake discs'**
  String get serviceBrakeDiscsRear;

  /// No description provided for @serviceBrakeDrumsRear.
  ///
  /// In en, this message translates to:
  /// **'Rear brake drums'**
  String get serviceBrakeDrumsRear;

  /// No description provided for @serviceGlowPlugs.
  ///
  /// In en, this message translates to:
  /// **'Glow plugs'**
  String get serviceGlowPlugs;

  /// No description provided for @serviceDpf.
  ///
  /// In en, this message translates to:
  /// **'Diesel particulate filter'**
  String get serviceDpf;

  /// No description provided for @serviceAdblue.
  ///
  /// In en, this message translates to:
  /// **'AdBlue top-up'**
  String get serviceAdblue;

  /// No description provided for @serviceFuelFilter.
  ///
  /// In en, this message translates to:
  /// **'Fuel filter'**
  String get serviceFuelFilter;

  /// No description provided for @serviceClutch.
  ///
  /// In en, this message translates to:
  /// **'Clutch'**
  String get serviceClutch;

  /// No description provided for @serviceDifferentialOil.
  ///
  /// In en, this message translates to:
  /// **'Differential oil'**
  String get serviceDifferentialOil;

  /// No description provided for @serviceSerpentineBelt.
  ///
  /// In en, this message translates to:
  /// **'Serpentine belt'**
  String get serviceSerpentineBelt;

  /// No description provided for @serviceWaterPump.
  ///
  /// In en, this message translates to:
  /// **'Water pump'**
  String get serviceWaterPump;

  /// No description provided for @serviceShockAbsorbers.
  ///
  /// In en, this message translates to:
  /// **'Shock absorbers'**
  String get serviceShockAbsorbers;

  /// No description provided for @serviceWheelAlignment.
  ///
  /// In en, this message translates to:
  /// **'Wheel alignment'**
  String get serviceWheelAlignment;

  /// No description provided for @serviceAcService.
  ///
  /// In en, this message translates to:
  /// **'Air conditioning service'**
  String get serviceAcService;

  /// No description provided for @serviceBulbs.
  ///
  /// In en, this message translates to:
  /// **'Bulbs'**
  String get serviceBulbs;

  /// No description provided for @serviceChainLube.
  ///
  /// In en, this message translates to:
  /// **'Chain lubrication and adjustment'**
  String get serviceChainLube;

  /// No description provided for @serviceChainSprockets.
  ///
  /// In en, this message translates to:
  /// **'Chain and sprockets'**
  String get serviceChainSprockets;

  /// No description provided for @serviceForkOil.
  ///
  /// In en, this message translates to:
  /// **'Fork oil'**
  String get serviceForkOil;

  /// No description provided for @serviceValveClearance.
  ///
  /// In en, this message translates to:
  /// **'Valve clearance'**
  String get serviceValveClearance;

  /// No description provided for @attachmentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That file is {size} — the limit is {limit}. Try a smaller photo, or a PDF.'**
  String attachmentTooLarge(String size, String limit);

  /// No description provided for @authConfirmChecking.
  ///
  /// In en, this message translates to:
  /// **'Confirming your email…'**
  String get authConfirmChecking;

  /// No description provided for @authConfirmFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'That link did not work'**
  String get authConfirmFailedTitle;

  /// No description provided for @authConfirmFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Confirmation links work once and expire. Ask for a new one by signing in, or register again.'**
  String get authConfirmFailedBody;

  /// No description provided for @authConfirmNoLink.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to confirm here.'**
  String get authConfirmNoLink;

  /// No description provided for @authConfirmSignIn.
  ///
  /// In en, this message translates to:
  /// **'Go to sign-in'**
  String get authConfirmSignIn;

  /// No description provided for @timelineHasNote.
  ///
  /// In en, this message translates to:
  /// **'Has a note'**
  String get timelineHasNote;

  /// No description provided for @timelineHasAttachment.
  ///
  /// In en, this message translates to:
  /// **'Has an attachment'**
  String get timelineHasAttachment;

  /// No description provided for @timelineFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter by kind'**
  String get timelineFilter;

  /// No description provided for @timelineFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get timelineFilterClear;

  /// No description provided for @settingsYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get settingsYourName;

  /// No description provided for @settingsNameChanged.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get settingsNameChanged;

  /// No description provided for @settingsSettlement.
  ///
  /// In en, this message translates to:
  /// **'Shared costs'**
  String get settingsSettlement;

  /// No description provided for @settingsSettlementHint.
  ///
  /// In en, this message translates to:
  /// **'Splits everything logged equally between members and works out who owes whom. Useful when you share a car but keep separate money.'**
  String get settingsSettlementHint;

  /// No description provided for @settingsSettlementEnable.
  ///
  /// In en, this message translates to:
  /// **'Work out who owes whom'**
  String get settingsSettlementEnable;

  /// Shown under a seasonal tyre swap, naming the country's statutory winter-tyre window. This wording is for a country where the requirement binds regardless of weather (Croatia, Slovenia, Bosnia). from and to are already-formatted day-and-month strings. Deliberately does not claim legality: Croatia's rule binds on winter road sections, not every road.
  ///
  /// In en, this message translates to:
  /// **'Winter tyres {from} – {to}, whatever the weather'**
  String tyreWindowFixed(String from, String to);

  /// The same note for a country whose window is dated but only binds when the road is actually wintry (Austria, Serbia). The dates are still when a driver has to be ready.
  ///
  /// In en, this message translates to:
  /// **'Winter tyres {from} – {to}, when roads are wintry'**
  String tyreWindowWhenWintry(String from, String to);

  /// The note for a country with no dates at all, where winter tyres are required by road conditions alone (Germany). Shown so an interval-derived date does not read as authoritative.
  ///
  /// In en, this message translates to:
  /// **'No fixed dates — winter tyres whenever roads are wintry'**
  String get tyreWindowSituational;

  /// Notification title for the swap onto winter tyres, replacing the generic service name so the nudge says which way the swap goes.
  ///
  /// In en, this message translates to:
  /// **'Fit winter tyres'**
  String get notificationSwapToWinter;

  /// Notification title for the swap back onto summer tyres.
  ///
  /// In en, this message translates to:
  /// **'Back to summer tyres'**
  String get notificationSwapToSummer;

  /// No description provided for @guestLendTitle.
  ///
  /// In en, this message translates to:
  /// **'Lend this car'**
  String get guestLendTitle;

  /// No description provided for @guestLendIntro.
  ///
  /// In en, this message translates to:
  /// **'Give somebody a code and they can log against this car — and nothing else — until it runs out. They do not join your garage. They always see the car\'s own details, the odometer, when the papers run out, any open problems and the tyres; the rest of what you logged stays hidden unless you allow it.'**
  String get guestLendIntro;

  /// No description provided for @guestLendLabel.
  ///
  /// In en, this message translates to:
  /// **'Who is it for'**
  String get guestLendLabel;

  /// No description provided for @guestLendLabelHint.
  ///
  /// In en, this message translates to:
  /// **'Just for your own reference — they never see it.'**
  String get guestLendLabelHint;

  /// No description provided for @guestLendAllowFuel.
  ///
  /// In en, this message translates to:
  /// **'Log fill-ups'**
  String get guestLendAllowFuel;

  /// No description provided for @guestLendAllowTrips.
  ///
  /// In en, this message translates to:
  /// **'Log drives'**
  String get guestLendAllowTrips;

  /// No description provided for @guestLendAllowCosts.
  ///
  /// In en, this message translates to:
  /// **'Log costs and services'**
  String get guestLendAllowCosts;

  /// No description provided for @guestLendAllowHistory.
  ///
  /// In en, this message translates to:
  /// **'See this car\'s earlier history'**
  String get guestLendAllowHistory;

  /// No description provided for @guestLendAllowHistoryHint.
  ///
  /// In en, this message translates to:
  /// **'Off by default: they see only what they logged themselves.'**
  String get guestLendAllowHistoryHint;

  /// No description provided for @guestLendAction.
  ///
  /// In en, this message translates to:
  /// **'Create a code'**
  String get guestLendAction;

  /// No description provided for @guestLendCreated.
  ///
  /// In en, this message translates to:
  /// **'Hand over this code'**
  String get guestLendCreated;

  /// No description provided for @guestLendCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get guestLendCopy;

  /// No description provided for @guestLendCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get guestLendCopied;

  /// No description provided for @guestPassesTitle.
  ///
  /// In en, this message translates to:
  /// **'Lending'**
  String get guestPassesTitle;

  /// No description provided for @guestPassesEmpty.
  ///
  /// In en, this message translates to:
  /// **'This car has never been lent out.'**
  String get guestPassesEmpty;

  /// No description provided for @guestPassesLive.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get guestPassesLive;

  /// No description provided for @guestPassesWaiting.
  ///
  /// In en, this message translates to:
  /// **'Not claimed yet'**
  String get guestPassesWaiting;

  /// No description provided for @guestPassesNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Starts later'**
  String get guestPassesNotStarted;

  /// No description provided for @guestPassesExpired.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get guestPassesExpired;

  /// No description provided for @guestPassesRevoked.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get guestPassesRevoked;

  /// No description provided for @guestPassRemaining.
  ///
  /// In en, this message translates to:
  /// **'{days} days left'**
  String guestPassRemaining(int days);

  /// No description provided for @guestPassEndsToday.
  ///
  /// In en, this message translates to:
  /// **'Ends today'**
  String get guestPassEndsToday;

  /// No description provided for @guestPassRevoke.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get guestPassRevoke;

  /// No description provided for @guestPassRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Withdraw this code? They lose access immediately. Everything they logged stays.'**
  String get guestPassRevokeConfirm;

  /// No description provided for @guestRedeemFailed.
  ///
  /// In en, this message translates to:
  /// **'That code does not work. It may have expired, been withdrawn, or already be in use.'**
  String get guestRedeemFailed;

  /// No description provided for @guestBorrowedBadge.
  ///
  /// In en, this message translates to:
  /// **'Lent to you'**
  String get guestBorrowedBadge;

  /// No description provided for @guestBorrowedUntil.
  ///
  /// In en, this message translates to:
  /// **'Yours until {date}'**
  String guestBorrowedUntil(String date);

  /// No description provided for @guestHistoryHidden.
  ///
  /// In en, this message translates to:
  /// **'You are seeing only what you logged. The owner\'s earlier entries stay private.'**
  String get guestHistoryHidden;

  /// No description provided for @householdMakeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make admin'**
  String get householdMakeAdmin;

  /// No description provided for @householdRemoveAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove admin'**
  String get householdRemoveAdmin;

  /// No description provided for @householdRoleChanged.
  ///
  /// In en, this message translates to:
  /// **'{name} is now an admin'**
  String householdRoleChanged(String name);

  /// No description provided for @householdRoleRemoved.
  ///
  /// In en, this message translates to:
  /// **'{name} is no longer an admin'**
  String householdRoleRemoved(String name);

  /// No description provided for @householdLastAdminKept.
  ///
  /// In en, this message translates to:
  /// **'A garage always keeps an admin, so the role passed to the next longest-standing member.'**
  String get householdLastAdminKept;

  /// No description provided for @householdMergeTitle.
  ///
  /// In en, this message translates to:
  /// **'Merge another garage into this one'**
  String get householdMergeTitle;

  /// No description provided for @householdMergeIntro.
  ///
  /// In en, this message translates to:
  /// **'Every vehicle, its whole history and everyone in the other garage move here. The other garage is then deleted. This cannot be undone.'**
  String get householdMergeIntro;

  /// No description provided for @householdMergeNone.
  ///
  /// In en, this message translates to:
  /// **'You are not an admin of any other garage.'**
  String get householdMergeNone;

  /// No description provided for @householdMergePick.
  ///
  /// In en, this message translates to:
  /// **'Which garage should move here?'**
  String get householdMergePick;

  /// No description provided for @householdMergeAction.
  ///
  /// In en, this message translates to:
  /// **'Merge into this garage'**
  String get householdMergeAction;

  /// No description provided for @householdMergeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Move everything from {name} into {survivor}? {vehicles} and {people} come across, {name} is deleted, and this cannot be undone.'**
  String householdMergeConfirm(
    String name,
    String survivor,
    String vehicles,
    String people,
  );

  /// No description provided for @householdMergeVehicleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{no vehicles} =1{1 vehicle} other{{count} vehicles}}'**
  String householdMergeVehicleCount(int count);

  /// No description provided for @householdMergePeopleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 person} other{{count} people}}'**
  String householdMergePeopleCount(int count);

  /// No description provided for @householdMergeKeysWarning.
  ///
  /// In en, this message translates to:
  /// **'Any API keys and webhooks belonging to the other garage stop working.'**
  String get householdMergeKeysWarning;

  /// No description provided for @householdMergeDone.
  ///
  /// In en, this message translates to:
  /// **'Merged. {vehicles} moved across.'**
  String householdMergeDone(String vehicles);

  /// No description provided for @householdMergePhotosLost.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One vehicle photo could not be moved.} other{{count} vehicle photos could not be moved.}}'**
  String householdMergePhotosLost(int count);

  /// No description provided for @householdMergeCurrencyClash.
  ///
  /// In en, this message translates to:
  /// **'These garages keep their money in different currencies ({absorbed} and {surviving}). Change one to match before merging, or every amount would change meaning.'**
  String householdMergeCurrencyClash(String absorbed, String surviving);

  /// No description provided for @syncPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync'**
  String get syncPendingTitle;

  /// No description provided for @syncPendingBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry is waiting to sync} other{{count} entries are waiting to sync}}'**
  String syncPendingBanner(int count);

  /// No description provided for @syncPendingIntro.
  ///
  /// In en, this message translates to:
  /// **'These were saved on your phone when there was no connection. They will be sent on their own the next time there is one.'**
  String get syncPendingIntro;

  /// No description provided for @syncPendingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Everything has been sent.'**
  String get syncPendingEmpty;

  /// No description provided for @syncRetryNow.
  ///
  /// In en, this message translates to:
  /// **'Try now'**
  String get syncRetryNow;

  /// No description provided for @syncEntryQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on your phone. It will sync when you have a signal.'**
  String get syncEntryQueued;

  /// No description provided for @syncSent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry synced} other{{count} entries synced}}'**
  String syncSent(int count);

  /// No description provided for @syncStillWaiting.
  ///
  /// In en, this message translates to:
  /// **'Still no connection. Nothing was lost.'**
  String get syncStillWaiting;

  /// No description provided for @syncDiscarded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry could not be saved and was removed} other{{count} entries could not be saved and were removed}}'**
  String syncDiscarded(int count);

  /// No description provided for @syncKindFuel.
  ///
  /// In en, this message translates to:
  /// **'Fill-up'**
  String get syncKindFuel;

  /// No description provided for @syncKindOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer reading'**
  String get syncKindOdometer;

  /// No description provided for @syncQueuedAt.
  ///
  /// In en, this message translates to:
  /// **'Typed {when}'**
  String syncQueuedAt(String when);

  /// No description provided for @syncPhotoQueued.
  ///
  /// In en, this message translates to:
  /// **'Photo saved on your phone. It will upload when you have a signal.'**
  String get syncPhotoQueued;

  /// No description provided for @syncKindAttachment.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get syncKindAttachment;

  /// No description provided for @syncKindTrip.
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get syncKindTrip;

  /// No description provided for @syncKindCost.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get syncKindCost;

  /// No description provided for @syncKindService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get syncKindService;

  /// No description provided for @syncKindObservation.
  ///
  /// In en, this message translates to:
  /// **'Something noticed'**
  String get syncKindObservation;

  /// No description provided for @observationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Problems'**
  String get observationsTitle;

  /// No description provided for @observationsHint.
  ///
  /// In en, this message translates to:
  /// **'Something you noticed and have not sorted out. It is a note to yourself, and to whoever next works on the car.'**
  String get observationsHint;

  /// No description provided for @observationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing noted. Anything odd — a rattle, a warning light, a noise since a pothole — goes here.'**
  String get observationsEmpty;

  /// No description provided for @observationAdd.
  ///
  /// In en, this message translates to:
  /// **'Note a problem'**
  String get observationAdd;

  /// No description provided for @observationEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get observationEdit;

  /// No description provided for @observationNote.
  ///
  /// In en, this message translates to:
  /// **'What did you notice'**
  String get observationNote;

  /// No description provided for @observationNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Rattling at the front when the engine is cold'**
  String get observationNoteHint;

  /// No description provided for @observationNoticedOn.
  ///
  /// In en, this message translates to:
  /// **'When you noticed it'**
  String get observationNoticedOn;

  /// No description provided for @observationOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get observationOdometer;

  /// No description provided for @observationOpen.
  ///
  /// In en, this message translates to:
  /// **'Not sorted'**
  String get observationOpen;

  /// No description provided for @observationStillThere.
  ///
  /// In en, this message translates to:
  /// **'Still there after work'**
  String get observationStillThere;

  /// No description provided for @observationResolved.
  ///
  /// In en, this message translates to:
  /// **'Sorted'**
  String get observationResolved;

  /// No description provided for @observationOpenFor.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{noticed today} =1{1 day} other{{days} days}}'**
  String observationOpenFor(int days);

  /// No description provided for @observationMarkResolved.
  ///
  /// In en, this message translates to:
  /// **'It has stopped'**
  String get observationMarkResolved;

  /// No description provided for @observationReopen.
  ///
  /// In en, this message translates to:
  /// **'It is back'**
  String get observationReopen;

  /// No description provided for @observationDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get observationDelete;

  /// No description provided for @observationDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this note? The record of noticing it goes with it.'**
  String get observationDeleteConfirm;

  /// No description provided for @observationSaved.
  ///
  /// In en, this message translates to:
  /// **'Noted'**
  String get observationSaved;

  /// No description provided for @observationResolvedOn.
  ///
  /// In en, this message translates to:
  /// **'Stopped {date}'**
  String observationResolvedOn(String date);

  /// No description provided for @observationAddressedNotResolved.
  ///
  /// In en, this message translates to:
  /// **'Work was done and you have not said it stopped.'**
  String get observationAddressedNotResolved;

  /// No description provided for @observationOnTrip.
  ///
  /// In en, this message translates to:
  /// **'Noticed on a drive'**
  String get observationOnTrip;

  /// No description provided for @tripDriveNoteSomething.
  ///
  /// In en, this message translates to:
  /// **'Note something'**
  String get tripDriveNoteSomething;

  /// No description provided for @tripPrepTitle.
  ///
  /// In en, this message translates to:
  /// **'Before a long drive'**
  String get tripPrepTitle;

  /// No description provided for @tripPrepIntro.
  ///
  /// In en, this message translates to:
  /// **'What this garage\'s own records say falls due over the journey. It is not a roadworthiness check and says nothing about the tyres, lights or brakes.'**
  String get tripPrepIntro;

  /// No description provided for @tripPrepDepart.
  ///
  /// In en, this message translates to:
  /// **'Leaving on'**
  String get tripPrepDepart;

  /// No description provided for @tripPrepReturn.
  ///
  /// In en, this message translates to:
  /// **'Back on'**
  String get tripPrepReturn;

  /// No description provided for @tripPrepReturnNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get tripPrepReturnNone;

  /// No description provided for @tripPrepDistance.
  ///
  /// In en, this message translates to:
  /// **'Roughly how far'**
  String get tripPrepDistance;

  /// No description provided for @tripPrepCheck.
  ///
  /// In en, this message translates to:
  /// **'Check the journey'**
  String get tripPrepCheck;

  /// No description provided for @tripPrepDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Runs out while you are away'**
  String get tripPrepDeadlines;

  /// No description provided for @tripPrepForecast.
  ///
  /// In en, this message translates to:
  /// **'Expected to come due'**
  String get tripPrepForecast;

  /// No description provided for @tripPrepForecastNote.
  ///
  /// In en, this message translates to:
  /// **'Projected from how this car has lately been driven, not a date anybody wrote down.'**
  String get tripPrepForecastNote;

  /// No description provided for @tripPrepKmAway.
  ///
  /// In en, this message translates to:
  /// **'in about {distance}'**
  String tripPrepKmAway(String distance);

  /// No description provided for @tripPrepAlreadyPast.
  ///
  /// In en, this message translates to:
  /// **'already past due'**
  String get tripPrepAlreadyPast;

  /// No description provided for @tripPrepNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing in your records falls due over this journey.'**
  String get tripPrepNothing;

  /// No description provided for @tripPrepNoOdometer.
  ///
  /// In en, this message translates to:
  /// **'No recent odometer reading, so nothing could be measured against the distance. Log one and check again.'**
  String get tripPrepNoOdometer;

  /// No description provided for @tripPrepOwnList.
  ///
  /// In en, this message translates to:
  /// **'Your own list'**
  String get tripPrepOwnList;

  /// No description provided for @tripPrepOwnListHint.
  ///
  /// In en, this message translates to:
  /// **'Things you want to remember. Kept on this device.'**
  String get tripPrepOwnListHint;

  /// No description provided for @tripPrepAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add something'**
  String get tripPrepAddItem;

  /// No description provided for @tripPrepExpiresOn.
  ///
  /// In en, this message translates to:
  /// **'runs out {date}'**
  String tripPrepExpiresOn(String date);

  /// No description provided for @reportHandover.
  ///
  /// In en, this message translates to:
  /// **'For the mechanic'**
  String get reportHandover;

  /// No description provided for @reportHandoverHint.
  ///
  /// In en, this message translates to:
  /// **'What is wrong, what is coming due, and what was done recently'**
  String get reportHandoverHint;

  /// No description provided for @reportHandoverProblems.
  ///
  /// In en, this message translates to:
  /// **'What the driver has noticed'**
  String get reportHandoverProblems;

  /// No description provided for @reportHandoverStillThere.
  ///
  /// In en, this message translates to:
  /// **'Work was done and it did not stop'**
  String get reportHandoverStillThere;

  /// No description provided for @reportHandoverComing.
  ///
  /// In en, this message translates to:
  /// **'Coming due'**
  String get reportHandoverComing;

  /// No description provided for @reportHandoverRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent work'**
  String get reportHandoverRecent;

  /// No description provided for @reportHandoverNoProblems.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been noted.'**
  String get reportHandoverNoProblems;

  /// No description provided for @reportHandoverNoticedOn.
  ///
  /// In en, this message translates to:
  /// **'noticed {date}'**
  String reportHandoverNoticedOn(String date);

  /// No description provided for @reportHandoverFooter.
  ///
  /// In en, this message translates to:
  /// **'Compiled from the owner\'s own records. It is not an inspection and does not verify the condition of the vehicle.'**
  String get reportHandoverFooter;

  /// No description provided for @routeLabel.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get routeLabel;

  /// No description provided for @routeNoneOption.
  ///
  /// In en, this message translates to:
  /// **'No route'**
  String get routeNoneOption;

  /// No description provided for @routeNewOption.
  ///
  /// In en, this message translates to:
  /// **'New route…'**
  String get routeNewOption;

  /// No description provided for @routeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name this journey'**
  String get routeNameLabel;

  /// No description provided for @routeNameHint.
  ///
  /// In en, this message translates to:
  /// **'Home → Work'**
  String get routeNameHint;

  /// No description provided for @routeSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The route could not be saved, so the drive was not started.'**
  String get routeSaveFailed;

  /// No description provided for @tripNotComparable.
  ///
  /// In en, this message translates to:
  /// **'Not a normal run'**
  String get tripNotComparable;

  /// No description provided for @tripNotComparableHint.
  ///
  /// In en, this message translates to:
  /// **'A detour, an errand on the way, a road that was shut. It is still logged; it just stays out of the route\'s trend.'**
  String get tripNotComparableHint;

  /// No description provided for @routeTrendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get routeTrendsTitle;

  /// No description provided for @routeTrendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How long a journey you make often actually takes'**
  String get routeTrendsSubtitle;

  /// No description provided for @routeTrendsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No routes yet. Name one when you start a drive, and the journeys will start comparing themselves.'**
  String get routeTrendsEmpty;

  /// No description provided for @routeTrendNoTimed.
  ///
  /// In en, this message translates to:
  /// **'Nothing timed on this route yet. A drive you start and finish in the app records its own minutes.'**
  String get routeTrendNoTimed;

  /// No description provided for @routeTrendTypical.
  ///
  /// In en, this message translates to:
  /// **'Usually {duration}'**
  String routeTrendTypical(String duration);

  /// No description provided for @routeTrendSpread.
  ///
  /// In en, this message translates to:
  /// **'Middle half {low}–{high} min'**
  String routeTrendSpread(String low, String high);

  /// No description provided for @routeTrendSlower.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min slower than {label}'**
  String routeTrendSlower(String minutes, String label);

  /// No description provided for @routeTrendFaster.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min faster than {label}'**
  String routeTrendFaster(String minutes, String label);

  /// No description provided for @routeTrendUnchanged.
  ///
  /// In en, this message translates to:
  /// **'No change since {label}'**
  String routeTrendUnchanged(String label);

  /// No description provided for @routeTrendSample.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} journey} other{{count} journeys}}'**
  String routeTrendSample(int count);

  /// No description provided for @routeTrendSparse.
  ///
  /// In en, this message translates to:
  /// **'Some periods rest on very few journeys, so the change may be noise.'**
  String get routeTrendSparse;

  /// No description provided for @routeTrendCaveat.
  ///
  /// In en, this message translates to:
  /// **'This reports what your records say, not why. A different departure time, road or driver looks exactly like traffic.'**
  String get routeTrendCaveat;

  /// No description provided for @routeTrendGroupMonth.
  ///
  /// In en, this message translates to:
  /// **'By month'**
  String get routeTrendGroupMonth;

  /// No description provided for @routeTrendGroupQuarter.
  ///
  /// In en, this message translates to:
  /// **'By quarter'**
  String get routeTrendGroupQuarter;

  /// No description provided for @routeTrendWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays only'**
  String get routeTrendWeekdays;

  /// No description provided for @routeTrendDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get routeTrendDeparture;

  /// No description provided for @routeTrendDepartureAny.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get routeTrendDepartureAny;

  /// No description provided for @routeTrendDepartureMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get routeTrendDepartureMorning;

  /// No description provided for @routeTrendDepartureMidday.
  ///
  /// In en, this message translates to:
  /// **'Midday'**
  String get routeTrendDepartureMidday;

  /// No description provided for @routeTrendDepartureEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get routeTrendDepartureEvening;

  /// No description provided for @routeTrendDriver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get routeTrendDriver;

  /// No description provided for @routeTrendDriverAnyone.
  ///
  /// In en, this message translates to:
  /// **'Anyone'**
  String get routeTrendDriverAnyone;

  /// No description provided for @routeTrendExcluded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} journey left out as not a normal run} other{{count} journeys left out as not normal runs}}'**
  String routeTrendExcluded(int count);

  /// No description provided for @routeTrendNoStartTime.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} journey has no start time, so the departure filter cannot place it} other{{count} journeys have no start time, so the departure filter cannot place them}}'**
  String routeTrendNoStartTime(int count);

  /// No description provided for @routeRename.
  ///
  /// In en, this message translates to:
  /// **'Rename route'**
  String get routeRename;

  /// No description provided for @routeDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete route'**
  String get routeDelete;

  /// No description provided for @routeDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this route? The journeys stay; they simply stop being filed under it.'**
  String get routeDeleteConfirm;

  /// No description provided for @routeTrendExcludedMore.
  ///
  /// In en, this message translates to:
  /// **'and {count} more'**
  String routeTrendExcludedMore(int count);

  /// No description provided for @routeTrendExcludedRun.
  ///
  /// In en, this message translates to:
  /// **'{date} · {minutes} min'**
  String routeTrendExcludedRun(String date, String minutes);

  /// No description provided for @reportMileageTrail.
  ///
  /// In en, this message translates to:
  /// **'Recorded mileage'**
  String get reportMileageTrail;

  /// No description provided for @reportMileageYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get reportMileageYear;

  /// No description provided for @reportMileageReading.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reportMileageReading;

  /// No description provided for @reportMileageDriven.
  ///
  /// In en, this message translates to:
  /// **'Driven'**
  String get reportMileageDriven;

  /// No description provided for @reportMileageRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get reportMileageRecords;

  /// No description provided for @reportMileagePartialNote.
  ///
  /// In en, this message translates to:
  /// **'* Records begin during this year, so it covers less than a full year.'**
  String get reportMileagePartialNote;

  /// No description provided for @reportMileageGapNote.
  ///
  /// In en, this message translates to:
  /// **'† Measured from the last reading before a year with none recorded.'**
  String get reportMileageGapNote;

  /// No description provided for @reportSellersFooter.
  ///
  /// In en, this message translates to:
  /// **'Compiled from the owner\'s own records in this app. It is not an official mileage statement, and it cannot show anything that happened outside it.'**
  String get reportSellersFooter;

  /// No description provided for @featureRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get featureRoutes;

  /// No description provided for @featureRoutesBlurb.
  ///
  /// In en, this message translates to:
  /// **'Name a journey you make often and see what it usually takes, with the spread around it and how many journeys each figure rests on.'**
  String get featureRoutesBlurb;

  /// No description provided for @featureObservations.
  ///
  /// In en, this message translates to:
  /// **'What you have noticed'**
  String get featureObservations;

  /// No description provided for @featureObservationsBlurb.
  ///
  /// In en, this message translates to:
  /// **'A rattle, a warning light, a puddle under the car — with a photo. It stays open until the noise stops, and the sheet you hand a mechanic leads with it.'**
  String get featureObservationsBlurb;

  /// No description provided for @featureTripCheck.
  ///
  /// In en, this message translates to:
  /// **'Before a long drive'**
  String get featureTripCheck;

  /// No description provided for @featureTripCheckBlurb.
  ///
  /// In en, this message translates to:
  /// **'What falls due over the journey, from the dates in your own records. Not a roadworthiness check.'**
  String get featureTripCheckBlurb;

  /// No description provided for @featureOffline.
  ///
  /// In en, this message translates to:
  /// **'Works without a signal'**
  String get featureOffline;

  /// No description provided for @featureOfflineBlurb.
  ///
  /// In en, this message translates to:
  /// **'A fill-up typed at a pump is kept on the phone and sent when there is a connection. More → Waiting to sync lists what is still waiting.'**
  String get featureOfflineBlurb;

  /// No description provided for @guestLendFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get guestLendFrom;

  /// No description provided for @guestLendUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get guestLendUntil;

  /// No description provided for @guestLendWindowBackwards.
  ///
  /// In en, this message translates to:
  /// **'The end has to come after the start.'**
  String get guestLendWindowBackwards;

  /// No description provided for @guestLendStartsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get guestLendStartsToday;

  /// No description provided for @guestLendAllowPrices.
  ///
  /// In en, this message translates to:
  /// **'Show what the work cost'**
  String get guestLendAllowPrices;

  /// No description provided for @guestLendAllowPricesHint.
  ///
  /// In en, this message translates to:
  /// **'Off: a mechanic sees what was done and when, not what you paid for it.'**
  String get guestLendAllowPricesHint;

  /// No description provided for @guestPassExtend.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get guestPassExtend;

  /// No description provided for @guestPassExtendTitle.
  ///
  /// In en, this message translates to:
  /// **'Until when?'**
  String get guestPassExtendTitle;

  /// No description provided for @guestPassExtended.
  ///
  /// In en, this message translates to:
  /// **'Extended to {date}'**
  String guestPassExtended(String date);

  /// No description provided for @guestPassWindow.
  ///
  /// In en, this message translates to:
  /// **'{from} to {to}'**
  String guestPassWindow(String from, String to);

  /// No description provided for @lentHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'What was done'**
  String get lentHistoryTitle;

  /// No description provided for @lentHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing has been logged for this car.'**
  String get lentHistoryEmpty;

  /// No description provided for @lentHistoryPricesHidden.
  ///
  /// In en, this message translates to:
  /// **'The owner has not shared what the work cost.'**
  String get lentHistoryPricesHidden;

  /// No description provided for @odometerJumpWarning.
  ///
  /// In en, this message translates to:
  /// **'That is {distance} since {date}. Check the reading.'**
  String odometerJumpWarning(String distance, String date);

  /// No description provided for @runningCostOwnSpan.
  ///
  /// In en, this message translates to:
  /// **'Measured over the {distance} logged since {date}, which is all this app has readings for.'**
  String runningCostOwnSpan(String distance, String date);

  /// No description provided for @partsTitle.
  ///
  /// In en, this message translates to:
  /// **'What this car takes'**
  String get partsTitle;

  /// No description provided for @partsHint.
  ///
  /// In en, this message translates to:
  /// **'The numbers you look up before a job: oil viscosity, a filter part number, a bulb, wiper lengths. Typed once, kept for good.'**
  String get partsHint;

  /// No description provided for @partsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet. The next time you look one up, put it here.'**
  String get partsEmpty;

  /// No description provided for @partsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add what it takes'**
  String get partsAdd;

  /// No description provided for @partsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get partsEdit;

  /// No description provided for @partsJob.
  ///
  /// In en, this message translates to:
  /// **'For which job'**
  String get partsJob;

  /// No description provided for @partsSpec.
  ///
  /// In en, this message translates to:
  /// **'What it takes'**
  String get partsSpec;

  /// No description provided for @partsSpecHint.
  ///
  /// In en, this message translates to:
  /// **'5W-30 ACEA C3, W 712/95, H7 55W, 600 mm / 400 mm'**
  String get partsSpecHint;

  /// No description provided for @partsSpecRequired.
  ///
  /// In en, this message translates to:
  /// **'Say what it takes.'**
  String get partsSpecRequired;

  /// No description provided for @partsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get partsNotes;

  /// No description provided for @partsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get partsDelete;

  /// No description provided for @partsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete what this car takes for that job?'**
  String get partsDeleteConfirm;

  /// No description provided for @partsOnService.
  ///
  /// In en, this message translates to:
  /// **'This car takes {spec}'**
  String partsOnService(String spec);

  /// No description provided for @partsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 job recorded} other{{count} jobs recorded}}'**
  String partsCount(int count);

  /// No description provided for @briefingOdometer.
  ///
  /// In en, this message translates to:
  /// **'Odometer'**
  String get briefingOdometer;

  /// No description provided for @briefingPapers.
  ///
  /// In en, this message translates to:
  /// **'Papers on board'**
  String get briefingPapers;

  /// No description provided for @briefingProblems.
  ///
  /// In en, this message translates to:
  /// **'Worth knowing'**
  String get briefingProblems;

  /// No description provided for @briefingTyres.
  ///
  /// In en, this message translates to:
  /// **'Tyres'**
  String get briefingTyres;

  /// No description provided for @briefingNoticedOn.
  ///
  /// In en, this message translates to:
  /// **'noticed {date}'**
  String briefingNoticedOn(String date);

  /// No description provided for @briefingTyresFitted.
  ///
  /// In en, this message translates to:
  /// **'fitted {date}'**
  String briefingTyresFitted(String date);

  /// No description provided for @briefingNothing.
  ///
  /// In en, this message translates to:
  /// **'The owner has recorded nothing about this car yet.'**
  String get briefingNothing;

  /// No description provided for @codeBoxAction.
  ///
  /// In en, this message translates to:
  /// **'I have a code'**
  String get codeBoxAction;

  /// No description provided for @codeBoxTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code you were given'**
  String get codeBoxTitle;

  /// No description provided for @codeBoxUnknown.
  ///
  /// In en, this message translates to:
  /// **'No code like that. Check it and try again.'**
  String get codeBoxUnknown;

  /// No description provided for @codeBoxSpent.
  ///
  /// In en, this message translates to:
  /// **'That code has already been used, or it has run out.'**
  String get codeBoxSpent;

  /// No description provided for @codeBoxLending.
  ///
  /// In en, this message translates to:
  /// **'You are being lent {vehicle} until {date}.'**
  String codeBoxLending(String vehicle, String date);

  /// No description provided for @codeBoxTransfer.
  ///
  /// In en, this message translates to:
  /// **'{vehicle} would become yours, with all its history. This cannot be undone from here.'**
  String codeBoxTransfer(String vehicle);

  /// No description provided for @codeBoxInvite.
  ///
  /// In en, this message translates to:
  /// **'You would join the garage {subject} and share its vehicles.'**
  String codeBoxInvite(String subject);

  /// No description provided for @codeBoxUse.
  ///
  /// In en, this message translates to:
  /// **'Use the code'**
  String get codeBoxUse;

  /// No description provided for @passEdit.
  ///
  /// In en, this message translates to:
  /// **'Change what it allows'**
  String get passEdit;

  /// No description provided for @passEditNote.
  ///
  /// In en, this message translates to:
  /// **'Changes take effect at once, on the code they already have.'**
  String get passEditNote;

  /// No description provided for @passFinished.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 finished} other{{count} finished}}'**
  String passFinished(int count);

  /// No description provided for @guestPassesReturned.
  ///
  /// In en, this message translates to:
  /// **'Given back'**
  String get guestPassesReturned;

  /// No description provided for @guestReturn.
  ///
  /// In en, this message translates to:
  /// **'Give the car back'**
  String get guestReturn;

  /// No description provided for @guestReturnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Give this car back? Your access ends now. Everything you logged stays with the car.'**
  String get guestReturnConfirm;

  /// No description provided for @guestReturned.
  ///
  /// In en, this message translates to:
  /// **'Given back. Thanks for driving.'**
  String get guestReturned;

  /// No description provided for @csvCarScannerFound.
  ///
  /// In en, this message translates to:
  /// **'Car Scanner recording'**
  String get csvCarScannerFound;

  /// No description provided for @csvCarScannerDrive.
  ///
  /// In en, this message translates to:
  /// **'{distance} in {minutes} min, {date}'**
  String csvCarScannerDrive(String distance, int minutes, String date);

  /// No description provided for @csvCarScannerDriveMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min recorded'**
  String csvCarScannerDriveMinutes(int minutes);

  /// No description provided for @csvCarScannerFuel.
  ///
  /// In en, this message translates to:
  /// **'{litres} used, {rate}'**
  String csvCarScannerFuel(String litres, String rate);

  /// No description provided for @csvCarScannerParked.
  ///
  /// In en, this message translates to:
  /// **'This recording never went anywhere. It is the scanner left running in a parked car, not a journey.'**
  String get csvCarScannerParked;

  /// No description provided for @csvCarScannerNoDistance.
  ///
  /// In en, this message translates to:
  /// **'This recording has no distance in it. Enter how far the drive went.'**
  String get csvCarScannerNoDistance;

  /// No description provided for @csvCarScannerNoDate.
  ///
  /// In en, this message translates to:
  /// **'The file name does not say when this drive was, so the date has to be entered.'**
  String get csvCarScannerNoDate;

  /// No description provided for @csvCarScannerPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get csvCarScannerPickDate;

  /// No description provided for @csvCarScannerImport.
  ///
  /// In en, this message translates to:
  /// **'Import as a trip'**
  String get csvCarScannerImport;

  /// No description provided for @csvCarScannerImported.
  ///
  /// In en, this message translates to:
  /// **'Trip imported.'**
  String get csvCarScannerImported;
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
      <String>['en', 'hr', 'it'].contains(locale.languageCode);

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
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
