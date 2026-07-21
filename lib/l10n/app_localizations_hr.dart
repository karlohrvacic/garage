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
  String get errorExpired => 'Kod pozivnice je istekao.';

  @override
  String get errorAlreadyUsed => 'Kod pozivnice je već iskorišten.';

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
  String get vehiclesTitle => 'Vozila';

  @override
  String get vehiclesEmpty =>
      'Dodajte prvo vozilo za početak vođenja evidencije';

  @override
  String get vehiclesAdd => 'Dodaj vozilo';

  @override
  String get vehicleNickname => 'Naziv';

  @override
  String get vehicleMake => 'Marka';

  @override
  String get vehicleModel => 'Model';

  @override
  String get vehicleYear => 'Godina';

  @override
  String get vehiclePlate => 'Registracija';

  @override
  String get vehicleVin => 'Broj šasije';

  @override
  String get vehicleFuelType => 'Vrsta goriva';

  @override
  String get vehicleOdometer => 'Trenutna kilometraža';

  @override
  String get vehicleArchive => 'Arhiviraj';

  @override
  String get vehicleArchived => 'Arhivirano';

  @override
  String get vehicleSearch => 'Pretraži vozila';

  @override
  String get vehicleTabEconomy => 'Potrošnja';

  @override
  String get vehicleTabMaintenance => 'Održavanje';

  @override
  String get vehicleTabHistory => 'Povijest';

  @override
  String get vehicleEdit => 'Uredi vozilo';

  @override
  String get vehicleNoEconomyYet =>
      'Unesite dva puna tankiranja za prikaz potrošnje';

  @override
  String get vehicleNoHistoryYet => 'Još nema zabilježenih servisa';

  @override
  String vehicleLastService(String date) {
    return 'Zadnji servis $date';
  }

  @override
  String get fuelPetrol => 'Benzin';

  @override
  String get fuelDiesel => 'Dizel';

  @override
  String get fuelLpg => 'Plin';

  @override
  String get fuelElectric => 'Struja';

  @override
  String get fuelHybrid => 'Hibrid';

  @override
  String get fuelTitle => 'Gorivo';

  @override
  String get fuelEmpty => 'Unesite tankiranje za praćenje potrošnje';

  @override
  String get fuelAdd => 'Dodaj tankiranje';

  @override
  String get fuelDate => 'Datum';

  @override
  String get fuelOdometer => 'Kilometraža';

  @override
  String get fuelVolume => 'Količina';

  @override
  String get fuelPricePerUnit => 'Cijena po jedinici';

  @override
  String get fuelTotal => 'Ukupno';

  @override
  String get fuelFullTank => 'Napunjen do vrha';

  @override
  String get fuelFullTankHint => 'Potrošnja se računa između punih spremnika';

  @override
  String get fuelMissedFill => 'Propustio sam unijeti prethodno tankiranje';

  @override
  String get fuelMissedFillHint =>
      'Prekida lanac izračuna kako se ne bi prikazao pogrešan podatak';

  @override
  String get fuelStation => 'Postaja';

  @override
  String get fuelNotes => 'Bilješke';

  @override
  String get fuelAverage => 'Prosjek';

  @override
  String get fuelNeedTwoValues =>
      'Unesite barem dvije od: količina, cijena, ukupno';

  @override
  String fuelOdometerTooLow(String previous) {
    return 'Manje od prethodnog očitanja od $previous';
  }

  @override
  String get fuelEconomyUnavailable =>
      'Nema dovoljno punih tankiranja za izračun';

  @override
  String get maintenanceTitle => 'Održavanje';

  @override
  String get maintenanceEmpty => 'Dodajte interval za praćenje dospijeća';

  @override
  String get maintenanceAddRule => 'Dodaj interval';

  @override
  String get maintenanceLogService => 'Zabilježi servis';

  @override
  String get maintenanceIntervalKm => 'Svakih (kilometara)';

  @override
  String get maintenanceIntervalMonths => 'Svakih (mjeseci)';

  @override
  String get maintenanceIntervalHint =>
      'Postavite jedno ili oboje. Vrijedi ono što prije dođe.';

  @override
  String maintenanceDueAt(String odometer) {
    return 'Dospijeva na $odometer';
  }

  @override
  String maintenanceDueOn(String date) {
    return 'Dospijeva $date';
  }

  @override
  String get maintenanceNeedsInterval =>
      'Postavite interval po kilometraži ili vremenu';

  @override
  String get maintenanceServiceDate => 'Datum';

  @override
  String get maintenanceServiceCost => 'Trošak';

  @override
  String get maintenanceServiceShop => 'Servis';

  @override
  String get maintenanceServiceItems => 'Što je obavljeno';

  @override
  String get maintenanceCalendar => 'Kalendar';

  @override
  String get maintenanceList => 'Popis';

  @override
  String get serviceOilChange => 'Zamjena ulja';

  @override
  String get serviceOilFilter => 'Filtar ulja';

  @override
  String get serviceAirFilter => 'Filtar zraka';

  @override
  String get serviceCabinFilter => 'Filtar kabine';

  @override
  String get serviceSparkPlugs => 'Svjećice';

  @override
  String get serviceBrakeFluid => 'Kočiona tekućina';

  @override
  String get serviceBrakePadsFront => 'Prednje pločice';

  @override
  String get serviceBrakePadsRear => 'Stražnje pločice';

  @override
  String get serviceTimingBelt => 'Zupčasti remen';

  @override
  String get serviceCoolant => 'Rashladna tekućina';

  @override
  String get serviceTransmissionOil => 'Ulje mjenjača';

  @override
  String get serviceTireRotation => 'Rotacija guma';

  @override
  String get serviceTireSwapSeasonal => 'Sezonska zamjena guma';

  @override
  String get serviceBattery => 'Akumulator';

  @override
  String get serviceWipers => 'Metlice brisača';

  @override
  String get serviceRegistration => 'Registracija';

  @override
  String get serviceTechnicalInspection => 'Tehnički pregled';

  @override
  String get serviceInsurance => 'Osiguranje';

  @override
  String get maintenanceStateUpcoming => 'Nadolazi';

  @override
  String get maintenanceStateDue => 'Dospijeva';

  @override
  String get maintenanceStateOverdue => 'Kasni';

  @override
  String get dashboardTitle => 'Garaža';

  @override
  String get plannerTitle => 'Planer';

  @override
  String get plannerRunway => 'Sljedećih 12 tjedana';

  @override
  String get plannerEmpty => 'Ništa ne dospijeva u sljedećih 12 tjedana';

  @override
  String get plannerOverdueNote =>
      'Zakašnjele stavke prikazane su na današnji dan jer ih tada treba obaviti';

  @override
  String plannerWeekOf(String date) {
    return 'Tjedan od $date';
  }

  @override
  String get settingsTitle => 'Postavke';

  @override
  String get dashboardNoBundles => 'Trenutno nema ništa za objediniti';

  @override
  String get dashboardDueSoonest => 'Najbliže dospijeće';

  @override
  String dashboardVehicleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vozila',
      few: '$count vozila',
      one: '$count vozilo',
    );
    return '$_temp0';
  }

  @override
  String bundleVisitOn(String date) {
    return 'Jedan posjet $date';
  }

  @override
  String bundleSpanDays(int days) {
    return '$days dana razmaka';
  }

  @override
  String get bundleExclude => 'Ne ovo';

  @override
  String get bundleExplain =>
      'Ove stavke dospijevaju blizu jedna drugoj — obavite ih u jednom posjetu i uštedite drugi odlazak';

  @override
  String notificationDueTitle(String service) {
    return '$service dospijeva';
  }

  @override
  String notificationBundleTitle(int count) {
    return '$count stavki dospijeva zajedno';
  }

  @override
  String get notificationBundleBody =>
      'Dogovorite jedan posjet i uštedite drugi odlazak';

  @override
  String bundleSuggestionTitle(int count) {
    return 'Objedini $count stavki u jedan posjet';
  }
}
