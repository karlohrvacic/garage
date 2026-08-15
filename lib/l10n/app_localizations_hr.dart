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
  String get errorAuth => 'Prijava nije uspjela. Provjerite e-mail i lozinku.';

  @override
  String get authTagline => 'Gorivo i održavanje, zabilježeno.';

  @override
  String get authSignInTitle => 'Prijava';

  @override
  String get authSignUpTitle => 'Otvori račun';

  @override
  String get authEmail => 'E-mail';

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
  String get authResetSent => 'Poslali smo vam poveznicu za promjenu lozinke.';

  @override
  String get authContinueWithGoogle => 'Nastavi s Googleom';

  @override
  String get authSetNewPasswordTitle => 'Postavite novu lozinku';

  @override
  String get authPasswordUpdated => 'Lozinka je promijenjena.';

  @override
  String get authInvalidEmail => 'Unesite ispravnu e-mail adresu';

  @override
  String get authPasswordTooShort => 'Koristite barem 8 znakova';

  @override
  String get authNameRequired => 'Unesite svoje ime';

  @override
  String get onboardingTitle => 'Postavite svoju garažu';

  @override
  String get onboardingCreateTitle => 'Napravite kućanstvo';

  @override
  String get onboardingCreateHint => 'Svi koje pozovete dijele ova vozila';

  @override
  String get onboardingHouseholdName => 'Naziv kućanstva';

  @override
  String get onboardingCreateAction => 'Napravi';

  @override
  String get onboardingJoinTitle => 'Pridružite se kodom';

  @override
  String get onboardingJoinHint =>
      'Zatražite kod od člana kućanstva — ima osam znakova';

  @override
  String get onboardingInviteCode => 'Kod pozivnice';

  @override
  String get onboardingJoinAction => 'Pridruži se';

  @override
  String get onboardingNameRequired => 'Unesite naziv';

  @override
  String get onboardingCodeInvalid => 'Unesite kod od osam znakova';

  @override
  String get onboardingSignOut => 'Odjava';

  @override
  String get householdTitle => 'Kućanstvo';

  @override
  String get householdMembers => 'Članovi';

  @override
  String get householdInvite => 'Pozovi nekoga';

  @override
  String householdInviteCreated(String code) {
    return 'Podijelite ovaj kod: $code';
  }

  @override
  String get householdInviteExpires => 'Istječe za 14 dana';

  @override
  String get householdCopyCode => 'Kopiraj kod';

  @override
  String get householdCopied => 'Kopirano';

  @override
  String get householdLeave => 'Napusti kućanstvo';

  @override
  String get householdLeaveConfirm =>
      'Napustiti ovo kućanstvo? Izgubit ćete pristup njegovim vozilima.';

  @override
  String get householdSpend => 'Zajednički troškovi';

  @override
  String get householdSpendHint =>
      'Sve zabilježeno na vozilima ovog kućanstva, po tome tko je unio';

  @override
  String householdShareEach(String amount) {
    return 'Jednak udio: $amount';
  }

  @override
  String get householdSettled => 'Sve je poravnato';

  @override
  String householdOwes(String from, String to, String amount) {
    return '$from duguje $to $amount';
  }

  @override
  String get householdRemoveMember => 'Ukloni iz kućanstva';

  @override
  String get householdRoleAdmin => 'Administrator';

  @override
  String get householdRoleMember => 'Član';

  @override
  String get settingsUnits => 'Mjerne jedinice';

  @override
  String get settingsDistance => 'Udaljenost';

  @override
  String get settingsVolume => 'Volumen';

  @override
  String get settingsCurrency => 'Valuta';

  @override
  String get calculatorTitle => 'Kalkulator';

  @override
  String get calcModeTripCost => 'Trošak putovanja';

  @override
  String get calcModeDistance => 'Udaljenost';

  @override
  String get calcModeConsumption => 'Potrošnja';

  @override
  String get calcModeRequiredFuel => 'Potrebno gorivo';

  @override
  String get calcConsumption => 'Potrošnja';

  @override
  String get calcResult => 'Rezultat';

  @override
  String get stationsTitle => 'Benzinske postaje';

  @override
  String get stationsFuelPetrol => 'Benzin';

  @override
  String get stationsFuelDiesel => 'Dizel';

  @override
  String get stationsFuelLpg => 'Autoplin';

  @override
  String get stationsAttribution =>
      'Cijene: mzoe-gor.hr (Ministarstvo gospodarstva)';

  @override
  String get stationsOpenMap => 'Otvori kartu';

  @override
  String get stationsNoLocation => 'Lokacija nedostupna — poredano po cijeni.';

  @override
  String get stationsFavourite => 'Omiljena';

  @override
  String get stationsAvgNearby => 'Prosjek u blizini';

  @override
  String get stationsNationalAvg => 'Nacionalni prosjek';

  @override
  String get stationsEmpty => 'Nema pronađenih postaja.';

  @override
  String get timelineTitle => 'Povijest';

  @override
  String get timelineEmpty => 'Još ništa nije zabilježeno.';

  @override
  String get statsTitle => 'Statistika';

  @override
  String get statsTabFillUps => 'Točenja';

  @override
  String get statsTabCosts => 'Troškovi';

  @override
  String get statsTabDistance => 'Udaljenost';

  @override
  String get statsAllVehicles => 'Sva vozila';

  @override
  String get statsThisYear => 'Ova godina';

  @override
  String get statsPreviousYear => 'Prošla godina';

  @override
  String get statsThisMonth => 'Ovaj mjesec';

  @override
  String get statsPreviousMonth => 'Prošli mjesec';

  @override
  String get statsFillUps => 'Točenja';

  @override
  String get statsFuelVolume => 'Gorivo';

  @override
  String get statsMinFill => 'Najmanje točenje';

  @override
  String get statsMaxFill => 'Najveće točenje';

  @override
  String get statsAvgEconomy => 'Prosječna potrošnja';

  @override
  String get statsBestEconomy => 'Najbolja potrošnja';

  @override
  String get statsWorstEconomy => 'Najgora potrošnja';

  @override
  String get statsTotalWithFuel => 'Troškovi (s gorivom)';

  @override
  String get statsTotalWithoutFuel => 'Troškovi (bez goriva)';

  @override
  String get statsFuelOnly => 'Gorivo';

  @override
  String get statsLowestBill => 'Najniži račun';

  @override
  String get statsHighestBill => 'Najviši račun';

  @override
  String get statsBestFuelPrice => 'Najbolja cijena goriva';

  @override
  String get statsWorstFuelPrice => 'Najgora cijena goriva';

  @override
  String get statsAvgCost => 'Prosječni trošak';

  @override
  String get statsAvgPerDay => 'Prosjek po danu';

  @override
  String get statsAvgPerMonth => 'Prosjek po mjesecu';

  @override
  String get statsCategories => 'Kategorije';

  @override
  String get statsDistanceTracked => 'Prijeđena udaljenost';

  @override
  String get statsLastOdometer => 'Zadnje stanje brojila';

  @override
  String get statsCharts => 'Grafikoni';

  @override
  String get statsEmpty => 'Još nema dovoljno podataka.';

  @override
  String get commonEdit => 'Uredi';

  @override
  String get confirmDeleteTitle => 'Obrisati unos?';

  @override
  String get confirmDeleteBody => 'Ovo se ne može poništiti.';

  @override
  String get settingsImportFuelio => 'Uvoz iz Fuelija';

  @override
  String get settingsImportFuelioHint =>
      'Odaberite CSV sigurnosnu kopiju iz Fuelija. Uvoze se točenja, troškovi, servisi i ponavljajući podsjetnici; ponovni uvoz preskače već postojeće retke.';

  @override
  String get settingsImportVehicle => 'Uvezi u vozilo';

  @override
  String get settingsImportRun => 'Uvezi';

  @override
  String settingsImportDone(int fills, int services, int costs, int reminders) {
    return 'Uvezeno: $fills točenja, $services servisa, $costs troškova, $reminders podsjetnika.';
  }

  @override
  String settingsImportSkipped(String titles) {
    return 'Nije prepoznato, preskočeno: $titles';
  }

  @override
  String get vehicleCurrentOdometer => 'Trenutna kilometraža';

  @override
  String get vehicleUpdateOdometer => 'Ažuriraj kilometražu';

  @override
  String get dashboardRecent => 'Nedavna aktivnost';

  @override
  String get reportsTitle => 'Izradi izvještaj';

  @override
  String get reportSellers => 'Izvještaj za prodaju';

  @override
  String get reportMaintenance => 'Povijest održavanja';

  @override
  String get reportAnnual => 'Godišnji sažetak';

  @override
  String get costsTitle => 'Troškovi';

  @override
  String get costAdd => 'Dodaj trošak';

  @override
  String get costAmount => 'Iznos';

  @override
  String get costCategory => 'Kategorija';

  @override
  String get costDate => 'Datum';

  @override
  String get costRemindNextYear => 'Podsjeti me kad ponovno dospije';

  @override
  String get costsEmpty => 'Još nema unesenih troškova.';

  @override
  String get costAmountRequired => 'Unesite iznos.';

  @override
  String get costCategoryRegistration => 'Registracija';

  @override
  String get costCategoryInsurance => 'Osiguranje';

  @override
  String get costCategoryParking => 'Parking';

  @override
  String get costCategoryToll => 'Cestarina';

  @override
  String get costCategoryWash => 'Pranje auta';

  @override
  String get costCategoryFine => 'Kazna';

  @override
  String get costCategoryEquipment => 'Oprema';

  @override
  String get costCategoryOther => 'Ostalo';

  @override
  String get settingsSignOut => 'Odjava';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Prema sustavu';

  @override
  String get settingsThemeLight => 'Svijetla';

  @override
  String get settingsThemeDark => 'Tamna';

  @override
  String get settingsLanguage => 'Jezik';

  @override
  String get settingsLanguageSystem => 'Prema sustavu';

  @override
  String get settingsBundling => 'Objedinjavanje održavanja';

  @override
  String get settingsBundlingWindowDays => 'Grupiraj stavke unutar (dana)';

  @override
  String get settingsBundlingWindowKm => 'Grupiraj stavke unutar (kilometara)';

  @override
  String get settingsBundlingHint =>
      'Veći raspon znači više objedinjenih posjeta';

  @override
  String get settingsCountry => 'Država';

  @override
  String get settingsCountryHint =>
      'Koje se stavke registracije i pregleda nude';

  @override
  String get countryElsewhere => 'Drugdje';

  @override
  String get settingsTracking => 'Razina detalja';

  @override
  String get settingsTrackingHint => 'Koliko podataka traži unos servisa';

  @override
  String get trackingBeginner => 'Osnovno';

  @override
  String get trackingIntermediate => 'Detaljno';

  @override
  String get trackingAdvanced => 'Potpuno';

  @override
  String get serviceDiy => 'Odrađeno samostalno';

  @override
  String get servicePartsCost => 'Dijelovi';

  @override
  String get serviceLaborCost => 'Rad';

  @override
  String get servicePartsDetail => 'Ugrađeni dijelovi';

  @override
  String get serviceWarrantyUntil => 'Jamstvo do';

  @override
  String get serviceFaultCodes => 'Kodovi grešaka';

  @override
  String get serviceFaultCodesHint => 'npr. P0301, P0171';

  @override
  String get serviceMeasurements => 'Očitanja';

  @override
  String get measurementBrakePadFront => 'Prednje pločice';

  @override
  String get measurementBrakePadRear => 'Stražnje pločice';

  @override
  String get measurementBrakeDiscFront => 'Prednji diskovi';

  @override
  String get measurementTreadFrontLeft => 'Šara, prednja lijeva';

  @override
  String get measurementTreadFrontRight => 'Šara, prednja desna';

  @override
  String get measurementTreadRearLeft => 'Šara, stražnja lijeva';

  @override
  String get measurementTreadRearRight => 'Šara, stražnja desna';

  @override
  String get measurementBatteryVolts => 'Napon akumulatora';

  @override
  String get measurementBatteryCca => 'CCA akumulatora';

  @override
  String get settingsData => 'Vaši podaci';

  @override
  String get settingsExport => 'Izvezi kao CSV';

  @override
  String get settingsExportDone => 'Izvoz je spreman';

  @override
  String get settingsDeleteAccount => 'Obriši račun';

  @override
  String get settingsDeleteConfirmTitle => 'Obrisati vaš račun?';

  @override
  String get settingsDeleteConfirmBody =>
      'Ovo trajno briše vaš račun. Ako ste posljednji član kućanstva, brišu se i njegova vozila te sva povijest. Ovo se ne može poništiti.';

  @override
  String get settingsDeleteConfirmAction => 'Trajno obriši';

  @override
  String get apiTitle => 'API pristup';

  @override
  String get apiHint =>
      'Pristup podacima ovog kućanstva samo za čitanje, za vlastite skripte i nadzorne ploče';

  @override
  String get apiNewKey => 'Novi ključ';

  @override
  String get apiKeyName => 'Čemu služi?';

  @override
  String get apiKeyCreate => 'Napravi';

  @override
  String get apiKeyOnce => 'Kopirajte ključ sada — više se neće prikazati';

  @override
  String get apiKeyRevoke => 'Opozovi';

  @override
  String get apiKeyRevoked => 'Opozvan';

  @override
  String get apiKeyNeverUsed => 'Nije korišten';

  @override
  String apiKeyLastUsed(String date) {
    return 'Zadnje korišten $date';
  }

  @override
  String get apiWebhooks => 'Webhookovi';

  @override
  String get apiWebhooksHint =>
      'Pozivaju se kad se nešto zabilježi ili dospije';

  @override
  String get apiWebhookAdd => 'Dodaj webhook';

  @override
  String get apiWebhookUrl => 'Adresa';

  @override
  String get apiWebhookInvalid => 'Unesite https:// adresu';

  @override
  String get apiWebhookAddAction => 'Dodaj';

  @override
  String apiWebhookFailing(int status) {
    return 'Zadnja isporuka nije uspjela ($status)';
  }

  @override
  String get settingsPrivacyPolicy => 'Pravila privatnosti';

  @override
  String get vehiclesTitle => 'Vozila';

  @override
  String get vehiclesEmpty => 'Dodajte prvo vozilo i počnite voditi evidenciju';

  @override
  String get vehiclesAdd => 'Dodaj vozilo';

  @override
  String get vehicleNickname => 'Naziv';

  @override
  String get vehicleNameRequired => 'Unesite naziv';

  @override
  String get vehicleMake => 'Marka';

  @override
  String get vehicleModel => 'Model';

  @override
  String get vehicleYear => 'Godina';

  @override
  String get vehiclePhoto => 'Fotografija';

  @override
  String get vehiclePhotoAdd => 'Dodaj fotografiju';

  @override
  String get vehiclePhotoReplace => 'Zamijeni fotografiju';

  @override
  String get vehiclePlate => 'Registracija';

  @override
  String get vehicleVin => 'Broj šasije';

  @override
  String get vehicleDecodeVin => 'Dohvati';

  @override
  String get vehicleVinNotFound => 'Broj šasije nije moguće dohvatiti';

  @override
  String get vehicleVinDecoded => 'Popunjeno iz registra';

  @override
  String get vehicleFuelType => 'Vrsta goriva';

  @override
  String get vehicleOdometer => 'Trenutna kilometraža';

  @override
  String get vehicleTankCapacity => 'Zapremina spremnika';

  @override
  String get vehicleTankCapacityHint =>
      'Neobavezno — upozorava na točenje veće od spremnika';

  @override
  String get vehicleArchive => 'Arhiviraj';

  @override
  String get vehicleArchived => 'Arhivirano';

  @override
  String get vehicleSearch => 'Pretraži vozila';

  @override
  String get recallsTitle => 'Sigurnosni opozivi';

  @override
  String get recallsNone => 'Nema opoziva za ovu marku, model i godinu';

  @override
  String get recallsCheck => 'Provjeri opozive';

  @override
  String get recallsCaveat =>
      'Iz američkog NHTSA registra — za europsko vozilo potvrdite kod ovlaštenog servisa';

  @override
  String get recallsNeedsDetails =>
      'Dodajte marku, model i godinu za provjeru opoziva';

  @override
  String get tyresTitle => 'Garniture guma';

  @override
  String get tyresEmpty => 'Dodajte garniture koje ovo vozilo koristi';

  @override
  String get tyresAdd => 'Dodaj garnituru';

  @override
  String get tyresName => 'Naziv';

  @override
  String get tyresSeason => 'Sezona';

  @override
  String get tyresSize => 'Dimenzija';

  @override
  String get tyresStorage => 'Spremljeno u';

  @override
  String get tyresFitted => 'Na vozilu';

  @override
  String get tyresFit => 'Postavi na vozilo';

  @override
  String get tyresRetire => 'Umirovi';

  @override
  String get tyresRetired => 'Umirovljeno';

  @override
  String get tyresAddReading => 'Zabilježi šaru';

  @override
  String get tyresTread => 'Šara';

  @override
  String get tyresTreadNone => 'Šara nije zabilježena';

  @override
  String get tyresBelowLegal => 'Na zakonskom minimumu od 1,6 mm ili ispod';

  @override
  String get tyresFrontLeft => 'Prednja lijeva';

  @override
  String get tyresFrontRight => 'Prednja desna';

  @override
  String get tyresRearLeft => 'Stražnja lijeva';

  @override
  String get tyresRearRight => 'Stražnja desna';

  @override
  String get tyreSeasonSummer => 'Ljetne';

  @override
  String get tyreSeasonWinter => 'Zimske';

  @override
  String get tyreSeasonAll => 'Cjelogodišnje';

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
      'Unesite dva puna točenja za prikaz potrošnje';

  @override
  String get vehicleTrendNeedsMore =>
      'Zabilježite još punih točenja za prikaz trenda';

  @override
  String get plannerRestoreExcluded => 'Vrati isključene stavke';

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
  String get fuelEmpty => 'Zabilježite točenje za praćenje potrošnje';

  @override
  String get fuelAdd => 'Dodaj točenje';

  @override
  String get fuelDate => 'Datum';

  @override
  String get fuelOdometer => 'Kilometraža';

  @override
  String get fuelVolume => 'Količina';

  @override
  String get fuelEnergy => 'Punjenje (kWh)';

  @override
  String get fuelPricePerUnit => 'Cijena po jedinici';

  @override
  String get fuelTotal => 'Ukupno';

  @override
  String get fuelFullTank => 'Pun spremnik';

  @override
  String get fuelFullTankHint =>
      'Potrošnja se računa od jednog punog spremnika do drugog';

  @override
  String get fuelMissedFill => 'Prethodno točenje nije zabilježeno';

  @override
  String get fuelMissedFillHint =>
      'Prekida lanac izračuna kako se ne bi prikazao pogrešan podatak';

  @override
  String get fuelStation => 'Postaja';

  @override
  String get attachmentsTitle => 'Privici';

  @override
  String get attachmentsAdd => 'Dodaj račun ili dokument';

  @override
  String get attachmentsSaveFirst =>
      'Prvo spremite unos, zatim mu dodajte datoteke';

  @override
  String get fuelNotes => 'Bilješke';

  @override
  String get fuelAverage => 'Prosjek';

  @override
  String get fuelNeedTwoValues =>
      'Unesite barem dvije vrijednosti: količinu, cijenu ili ukupno';

  @override
  String get fuelOdometerRequired => 'Unesite očitanje kilometraže';

  @override
  String fuelOdometerTooLow(String previous) {
    return 'Manje od prethodnog očitanja ($previous)';
  }

  @override
  String fuelOdometerTooHigh(String next) {
    return 'Više od sljedećeg očitanja ($next)';
  }

  @override
  String fuelOdometerLast(String previous) {
    return 'Zadnje očitanje: $previous';
  }

  @override
  String fuelVolumeOverTank(String capacity) {
    return 'Više nego što spremnik prima ($capacity)';
  }

  @override
  String get fuelEconomyUnavailable => 'Nema dovoljno punih točenja za izračun';

  @override
  String get maintenanceTitle => 'Održavanje';

  @override
  String get maintenanceEmpty => 'Dodajte interval i pratite što dospijeva';

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
      'Postavite jedno ili oboje. Vrijedi ono što prije nastupi.';

  @override
  String maintenanceDueAt(String odometer) {
    return 'Dospijeva pri $odometer';
  }

  @override
  String get maintenanceOneTime => 'Jednokratni podsjetnik';

  @override
  String get maintenanceDueDateField => 'Rok (datum)';

  @override
  String get maintenanceDueKmField => 'Rok (kilometraža)';

  @override
  String get maintenanceOneTimeNeedsTarget =>
      'Postavite rok po datumu ili kilometraži.';

  @override
  String maintenancePreviously(String details) {
    return 'Prethodno: $details';
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
  String get maintenanceServiceShop => 'Radionica';

  @override
  String get maintenanceServiceItems => 'Što je obavljeno';

  @override
  String get maintenanceRuleServiceType => 'Vrsta servisa';

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
  String get serviceIssue => 'Zabilježen kvar';

  @override
  String get serviceDiagnostics => 'Dijagnostika';

  @override
  String get serviceModification => 'Preinaka';

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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dana razmaka',
      few: '$days dana razmaka',
      one: '$days dan razmaka',
    );
    return '$_temp0';
  }

  @override
  String get bundleExclude => 'Preskoči';

  @override
  String get bundleExplain =>
      'Ove stavke dospijevaju blizu jedna drugoj — obavite ih u jednom posjetu i izbjegnite još jedan odlazak';

  @override
  String notificationDueTitle(String service) {
    return '$service dospijeva';
  }

  @override
  String notificationBundleTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stavki dospijeva zajedno',
      few: '$count stavke dospijevaju zajedno',
      one: '$count stavka dospijeva',
    );
    return '$_temp0';
  }

  @override
  String get notificationBundleBody =>
      'Dogovorite jedan posjet i izbjegnite još jedan odlazak';

  @override
  String bundleSuggestionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Objedini $count stavki u jedan posjet',
      few: 'Objedini $count stavke u jedan posjet',
      one: 'Objedini $count stavku u jedan posjet',
    );
    return '$_temp0';
  }

  @override
  String get aboutTitle => 'O aplikaciji';

  @override
  String get aboutTagline =>
      'Svi automobili u kućanstvu na jednom mjestu: gorivo, servisi, troškovi i što sljedeće dolazi na red.';

  @override
  String aboutVersion(String version, String build) {
    return 'Verzija $version ($build)';
  }

  @override
  String get aboutPromises => 'Što aplikacija obećava';

  @override
  String get aboutPromiseFree =>
      'Bez oglasa, bez pretplate i bez zaključanih funkcija. Ovo što vidite je cijela aplikacija.';

  @override
  String get aboutPromiseData =>
      'Vaši su zapisi vaši. Sve možete izvesti u CSV kad god želite — otvara se u bilo kojem programu za tablice.';

  @override
  String get aboutPromiseLeave =>
      'Odlazak je namjerno jednostavan. Obrišete račun i svi zapisi nestaju s njim.';

  @override
  String get aboutPromisePrivacy =>
      'Bez praćenja, bez analitike i bez profiliranja. Ono što upišete ostaje u vašem kućanstvu.';

  @override
  String get aboutPrivacyPolicy => 'Pravila privatnosti';

  @override
  String get aboutLicences => 'Licencije otvorenog koda';

  @override
  String get aboutLicencesHint => 'Biblioteke na kojima aplikacija počiva';
}
