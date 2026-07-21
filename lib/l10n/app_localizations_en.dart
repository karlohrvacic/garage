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
  String get fuelEconomyUnavailable =>
      'Not enough full-tank fills to calculate';

  @override
  String get maintenanceStateUpcoming => 'Upcoming';

  @override
  String get maintenanceStateDue => 'Due';

  @override
  String get maintenanceStateOverdue => 'Overdue';

  @override
  String bundleSuggestionTitle(int count) {
    return 'Bundle $count items into one visit';
  }
}
