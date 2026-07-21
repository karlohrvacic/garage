// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appTitle => 'Garaža';

  @override
  String get commonSave => 'Spremi';

  @override
  String get commonCancel => 'Odustani';

  @override
  String get commonRetry => 'Pokušaj ponovno';

  @override
  String get commonDelete => 'Obriši';

  @override
  String get commonEmpty => 'Ovdje još nema ničega';

  @override
  String get commonLoading => 'Učitavanje…';

  @override
  String get errorGeneric => 'Nešto je pošlo po zlu. Pokušajte ponovno.';

  @override
  String get errorNoConnection =>
      'Nema veze. Provjerite mrežu i pokušajte ponovno.';

  @override
  String get errorPermission => 'Nemate pristup tome.';

  @override
  String get errorNotFound => 'Nije pronađeno.';

  @override
  String get errorConflict => 'To već postoji.';

  @override
  String get errorAuth => 'Prijava nije uspjela. Provjerite e-poštu i lozinku.';

  @override
  String get authSignInTitle => 'Prijava';

  @override
  String get authSignUpTitle => 'Otvori račun';

  @override
  String get authEmail => 'E-pošta';

  @override
  String get authPassword => 'Lozinka';

  @override
  String get authDisplayName => 'Vaše ime';

  @override
  String get authSignInAction => 'Prijavi se';

  @override
  String get authSignUpAction => 'Otvori račun';

  @override
  String get authNoAccount => 'Nemate račun? Otvorite ga';

  @override
  String get authHaveAccount => 'Već imate račun? Prijavite se';

  @override
  String get authForgotPassword => 'Zaboravljena lozinka?';

  @override
  String get authResetSent =>
      'Provjerite e-poštu za poveznicu za ponovno postavljanje.';

  @override
  String get authContinueWithGoogle => 'Nastavi s Googleom';

  @override
  String get authInvalidEmail => 'Unesite ispravnu adresu e-pošte';

  @override
  String get authPasswordTooShort => 'Koristite barem 8 znakova';

  @override
  String get authNameRequired => 'Unesite svoje ime';

  @override
  String get onboardingTitle => 'Postavite svoju garažu';

  @override
  String get onboardingCreateTitle => 'Stvorite kućanstvo';

  @override
  String get onboardingCreateHint => 'Svi koje pozovete dijele ova vozila';

  @override
  String get onboardingHouseholdName => 'Naziv kućanstva';

  @override
  String get onboardingCreateAction => 'Stvori';

  @override
  String get onboardingJoinTitle => 'Pridružite se kodom';

  @override
  String get onboardingJoinHint =>
      'Zatražite od člana njegov osmeroznamenkasti kod';

  @override
  String get onboardingInviteCode => 'Kod pozivnice';

  @override
  String get onboardingJoinAction => 'Pridruži se';

  @override
  String get onboardingNameRequired => 'Unesite naziv';

  @override
  String get onboardingCodeInvalid => 'Unesite osmeroznamenkasti kod';

  @override
  String get onboardingSignOut => 'Odjava';

  @override
  String get fuelEconomyUnavailable =>
      'Nema dovoljno punih tankiranja za izračun';

  @override
  String get maintenanceStateUpcoming => 'Nadolazi';

  @override
  String get maintenanceStateDue => 'Dospijeva';

  @override
  String get maintenanceStateOverdue => 'Kasni';

  @override
  String bundleSuggestionTitle(int count) {
    return 'Objedini $count stavki u jedan posjet';
  }
}
