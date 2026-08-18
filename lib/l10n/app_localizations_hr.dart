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
  String get errorEmailNotConfirmed =>
      'Najprije potvrdite svoju e-mail adresu. Poveznicu smo poslali kad ste otvorili račun.';

  @override
  String get authWhatIsThis => 'Što Garaža nudi';

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
  String get authConfirmEmailTitle => 'Provjerite e-poštu';

  @override
  String authConfirmEmailBody(String email) {
    return 'Poslali smo poveznicu za potvrdu na $email. Otvorite je, pa se vratite i prijavite.';
  }

  @override
  String get authConfirmEmailAction => 'Natrag na prijavu';

  @override
  String get authNoAccount => 'Nemate račun? Otvorite ga';

  @override
  String get authForgotPassword => 'Zaboravljena lozinka?';

  @override
  String get authResetSent => 'Poslali smo vam poveznicu za promjenu lozinke.';

  @override
  String get authLinkFailed =>
      'Poveznica je istekla ili je već iskorištena. Prijavite se ispod ili ponovno otvorite račun.';

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
  String get onboardingCreateTitle => 'Napravite garažu';

  @override
  String get onboardingCreateHint => 'Svi koje pozovete dijele ova vozila';

  @override
  String get onboardingHouseholdName => 'Naziv garaže';

  @override
  String get onboardingCreateAction => 'Napravi';

  @override
  String get onboardingJoinTitle => 'Pridružite se kodom';

  @override
  String get onboardingJoinHint =>
      'Zatražite kod od nekoga iz garaže — ima osam znakova';

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
  String get joinTitle => 'Pridruži se garaži';

  @override
  String get joinInvited =>
      'Netko vas je pozvao u svoju garažu. Prijavite se ili otvorite račun i pozivnica će vas odmah pridružiti.';

  @override
  String get joinJoining => 'Pridruživanje…';

  @override
  String get joinDone =>
      'Ušli ste. Sve što se u garaži bilježi sada je i vaše.';

  @override
  String get joinOpenGarage => 'Otvori moju garažu';

  @override
  String get householdShareInvite => 'Podijeli poveznicu';

  @override
  String get householdInviteLinkCopied => 'Poveznica kopirana';

  @override
  String get householdTitle => 'Garaža';

  @override
  String get householdMembers => 'Članovi';

  @override
  String get householdInvite => 'Pozovi nekoga';

  @override
  String get householdCopyCode => 'Kopiraj kod';

  @override
  String get householdCopied => 'Kopirano';

  @override
  String get householdLeave => 'Napusti garažu';

  @override
  String get householdLeaveConfirm =>
      'Napustiti ovu garažu? Izgubit ćete pristup njezinim vozilima.';

  @override
  String get householdSpend => 'Zajednički troškovi';

  @override
  String get householdSpendHint =>
      'Sve zabilježeno na vozilima ove garaže, po tome tko je što unio';

  @override
  String householdUnattributed(String amount) {
    return 'S izbrisanog računa: $amount';
  }

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
  String get householdRemoveMember => 'Ukloni iz garaže';

  @override
  String get householdRoleAdmin => 'Administrator';

  @override
  String get householdRoleMember => 'Član';

  @override
  String get settingsUnits => 'Mjerne jedinice';

  @override
  String get settingsUnitsHint =>
      'Kako se prikazuju udaljenosti, količine i cijene';

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
  String get calcFuelAvailable => 'Gorivo u spremniku';

  @override
  String get calcFuelUsed => 'Potrošeno gorivo';

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
  String stationsOutOfRange(String distance) {
    return 'Cijene goriva dolaze iz otvorenih podataka hrvatskog ministarstva, pa su korisne samo unutar Hrvatske. Najbliža zabilježena postaja udaljena je $distance.';
  }

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
  String get commonVehicle => 'Vozilo';

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
  String get statsEmpty => 'Još nema dovoljno podataka.';

  @override
  String get reminderLogIt => 'Zabilježi da je obavljeno';

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
  String get dashboardRecent => 'Nedavna aktivnost';

  @override
  String get dashboardTotalSpent => 'Ukupno potrošeno';

  @override
  String calendarNothingOn(String date) {
    return 'Ništa ne dospijeva $date';
  }

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
  String get costCategoryVignette => 'Vinjeta';

  @override
  String get countryAustria => 'Austrija';

  @override
  String get countryBulgaria => 'Bugarska';

  @override
  String get countryCzechia => 'Češka';

  @override
  String get countryHungary => 'Mađarska';

  @override
  String get countryRomania => 'Rumunjska';

  @override
  String get countrySlovakia => 'Slovačka';

  @override
  String get countrySlovenia => 'Slovenija';

  @override
  String get countrySwitzerland => 'Švicarska';

  @override
  String fuelAtThePump(String station, String distance) {
    return 'Preuzeto s postaje $station, $distance od vas — promijenite ako ste platili drugu cijenu';
  }

  @override
  String get costVignetteCountry => 'Država';

  @override
  String get costVignetteValidity => 'Vrijedi';

  @override
  String get costVignetteValidityDay1 => '1 dan';

  @override
  String get costVignetteValidityDays7 => '7 dana';

  @override
  String get costVignetteValidityDays10 => '10 dana';

  @override
  String get costVignetteValidityDays30 => '30 dana';

  @override
  String get costVignetteValidityMonths2 => '2 mjeseca';

  @override
  String get costVignetteValidityDays60 => '60 dana';

  @override
  String get costVignetteValidityYear => '1 godina';

  @override
  String costVignetteBuy(String operator) {
    return 'Kupi kod $operator';
  }

  @override
  String costVignetteExpires(String date) {
    return 'Vrijedi do $date';
  }

  @override
  String get costVignetteRemind => 'Podsjeti me zadnji dan valjanosti';

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
      'Stavke koje dolaze na red u kratkom razmaku predlažu se kao jedan odlazak';

  @override
  String get settingsReminders => 'Podsjetnici';

  @override
  String get settingsRemindersThisDevice =>
      'Obavijest stiže samo na ovaj uređaj';

  @override
  String get settingsRemindersThisDeviceHint =>
      'Svaki telefon sam raspoređuje svoje podsjetnike, pa onaj tko ga nije postavio neće ništa čuti.';

  @override
  String get settingsRemindersEveryone => 'Obavijest stiže svima u ovoj garaži';

  @override
  String get settingsRemindersEveryoneHint =>
      'Podsjetnike šalje poslužitelj, pa ih dobiva svaki član, a ne samo uređaj koji ih je postavio.';

  @override
  String get settingsRemindersSchedule =>
      'Stižu 30 i 7 dana prije roka, i čim stanje brojača pokaže da je ostalo manje od 500 km';

  @override
  String get settingsRemindersScheduleDevice =>
      'Ovaj ih uređaj šalje u 9:00 ujutro';

  @override
  String get settingsRemindersScheduleServer =>
      'Poslužitelj ih šalje rano ujutro';

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
  String get settingsTrackingHint => 'Koliko detalja traži unos servisa';

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
      'Ovo trajno briše vaš račun. Ako ste posljednji član garaže, brišu se i njezina vozila te sva povijest. Ovo se ne može poništiti.';

  @override
  String get settingsDeleteConfirmAction => 'Trajno obriši';

  @override
  String get apiTitle => 'API pristup';

  @override
  String get apiHint =>
      'Pristup podacima ove garaže samo za čitanje, za vlastite skripte i nadzorne ploče';

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
  String get vehicleVinDecoded => 'Popunjeno prema broju šasije';

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
  String get vehicleArchived =>
      'Arhivirano. Povijest ostaje, a vozilo nestaje s popisa.';

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
  String get tyresRetireConfirmTitle => 'Umiroviti ovaj komplet?';

  @override
  String get tyresRetireConfirmBody =>
      'Ostaje na popisu sa svojim mjerenjima i više se ne nudi za montažu.';

  @override
  String get tyresDelete => 'Izbriši komplet';

  @override
  String get tyresDeleteConfirmTitle => 'Izbrisati ovaj komplet?';

  @override
  String get tyresDeleteConfirmBody =>
      'Nestaju i komplet i sva mjerenja dubine na njemu. To se ne može poništiti.';

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
  String get vehicleTabMaintenance => 'Servis';

  @override
  String get vehicleTabHistory => 'Povijest';

  @override
  String get vehicleRestore => 'Vrati iz arhive';

  @override
  String get vehicleRestored => 'Vozilo je opet u garaži.';

  @override
  String get vehicleDelete => 'Obriši vozilo';

  @override
  String get vehicleDeleteTitle => 'Obrisati ovo vozilo?';

  @override
  String get vehicleDeleteBody =>
      'Sva točenja, servisi, troškovi, očitanja i dokumenti nestaju s njim i ništa se ne može vratiti. Arhivirajte ga ako želite zadržati povijest.';

  @override
  String get vehiclesArchivedSection => 'Arhivirano';

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
  String get serviceInsuranceComprehensive => 'Kasko osiguranje';

  @override
  String get serviceVignette => 'Vinjeta istječe';

  @override
  String get maintenanceStateUpcoming => 'Nadolazi';

  @override
  String get maintenanceStateDue => 'Dospijeva';

  @override
  String get maintenanceStateOverdue => 'Kasni';

  @override
  String get dashboardTitle => 'Pregled';

  @override
  String get plannerTitle => 'Planer';

  @override
  String get plannerRunway => 'Sljedećih 12 tjedana';

  @override
  String get plannerEmpty => 'Ništa ne dospijeva u sljedećih 12 tjedana';

  @override
  String get plannerOverdueNote =>
      'Sve što kasni prikazano je pod današnjim danom jer to treba obaviti sada';

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
  String get bundleLogVisit => 'Zabilježi ovaj posjet';

  @override
  String get bundleExcludeHint =>
      'Izbacivanje stavke mijenja samo prijedlog iznad — ništa se ne bilježi ni ne otkazuje.';

  @override
  String get bundlePutBack => 'Vrati';

  @override
  String get bundleOneVehicleOnly =>
      'Bilježite po vozilu: ove su stavke na više njih.';

  @override
  String get bundleExclude => 'Preskoči';

  @override
  String get bundleExplain =>
      'Ove stavke dolaze na red otprilike u isto vrijeme — obavite ih u jednom posjetu i uštedite još jedan odlazak';

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
  String notificationDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Za $count dana',
      few: 'Za $count dana',
      one: 'Za $count dan',
    );
    return '$_temp0';
  }

  @override
  String notificationDueInKm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Još $count km',
      few: 'Još $count km',
      one: 'Još $count km',
    );
    return '$_temp0';
  }

  @override
  String notificationOverdueByKm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count km preko roka',
      few: '$count km preko roka',
      one: '$count km preko roka',
    );
    return '$_temp0';
  }

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
      'Sva vozila u garaži na jednom mjestu: gorivo, servisi, troškovi i što sljedeće dolazi na red.';

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
      'Bez praćenja, bez analitike i bez profiliranja. Ono što upišete ostaje u vašoj garaži.';

  @override
  String get aboutPrivacyPolicy => 'Pravila privatnosti';

  @override
  String get aboutLicences => 'Licencije otvorenog koda';

  @override
  String get aboutLicencesHint => 'Biblioteke na kojima aplikacija počiva';

  @override
  String get aboutSourceCode => 'Izvorni kôd';

  @override
  String get aboutSourceCodeHint =>
      'Cijela je aplikacija otvorenog koda, pod licencijom AGPL-3.0';

  @override
  String get aboutDiagnostics => 'Dijagnostika';

  @override
  String get aboutDiagnosticsHint =>
      'Nedavne pogreške, za slanje uz prijavu problema';

  @override
  String get diagnosticsTitle => 'Dijagnostika';

  @override
  String get diagnosticsEmpty => 'Na ovom uređaju ništa nije pošlo po zlu.';

  @override
  String get diagnosticsExplain =>
      'Čuva se samo na ovom uređaju. Ništa se nikamo ne šalje dok to sami ne podijelite.';

  @override
  String get diagnosticsShare => 'Podijeli';

  @override
  String get diagnosticsClear => 'Obriši';

  @override
  String get diagnosticsCleared => 'Dijagnostika obrisana';

  @override
  String get settingsTrackingBasicHint =>
      'Datum, kilometraža, što je napravljeno i koliko je stajalo';

  @override
  String get settingsTrackingDetailedHint =>
      'Dodaje dijelove, rad, samostalni popravak i jamstvo';

  @override
  String get settingsTrackingFullHint =>
      'Dodaje mjerenja: debljinu pločica, dubinu profila, napon';

  @override
  String settingsImportCreates(String name) {
    return 'Ovo će dodati $name u vašu garažu';
  }

  @override
  String get settingsImportNoVehicle =>
      'Ta sigurnosna kopija ne sadrži vozilo. Prvo dodajte vozilo, pa uvezite u njega.';

  @override
  String get settingsImportFuelType => 'Gorivo koje koristi';

  @override
  String get settingsExportNothing =>
      'Još nema ničega za izvoz — prvo zabilježite točenje ili servis';

  @override
  String get householdInvites => 'Kodovi pozivnice';

  @override
  String get householdInvitesHint =>
      'Svatko s kodom može se pridružiti ovoj garaži dok se kod ne iskoristi ili ne istekne';

  @override
  String get householdInviteActive => 'Čeka na korištenje';

  @override
  String get householdInviteUsed => 'Iskorišten';

  @override
  String get householdInviteExpired => 'Istekao';

  @override
  String get householdInviteRevoke => 'Povuci';

  @override
  String get householdInviteRevoked => 'Kod je povučen';

  @override
  String get householdInviteNew => 'Novi kod';

  @override
  String economyScale(String best, String worst) {
    return 'Najbolje $best · Najgore $worst na ovom vozilu';
  }

  @override
  String get economyScaleNone =>
      'Zabilježite nekoliko punih spremnika za usporedbu';

  @override
  String get maintenanceLastDone => 'Zadnji put obavljeno (nije obavezno)';

  @override
  String get maintenanceLastDoneHint =>
      'Ako ste ovo već obavili, upišite kada: interval se tada računa od toga, a ne od dodavanja vozila';

  @override
  String get maintenanceLastDoneDate => 'Datum obavljanja';

  @override
  String get maintenanceLastDoneKm => 'Kilometraža pri obavljanju';

  @override
  String get runningCostTitle => 'Koliko ovo vozilo košta';

  @override
  String get runningCostPerKm => 'Po kilometru';

  @override
  String runningCostFuelShare(String amount) {
    return 'Gorivo $amount';
  }

  @override
  String runningCostUpkeepShare(String amount) {
    return 'Održavanje $amount';
  }

  @override
  String get runningCostPerMonth => 'Mjesečno';

  @override
  String get runningCostPerYear => 'Godišnje';

  @override
  String get runningCostTotal => 'Otkad ste ga dodali';

  @override
  String get runningCostNotEnough =>
      'Zabilježite gorivo i troškove da vidite koliko vas vozilo stoji';

  @override
  String get runningCostBreakdown => 'Na što je otišlo';

  @override
  String get runningCostFuelTotal => 'Gorivo';

  @override
  String get runningCostServiceTotal => 'Servisi';

  @override
  String get runningCostOtherTotal => 'Registracija, osiguranje i ostalo';

  @override
  String get costCategoryInsuranceComprehensive => 'Kasko osiguranje';

  @override
  String get settingsDeleteData => 'Obriši sve podatke';

  @override
  String get settingsDeleteDataHint =>
      'Kreni ispočetka: briše sva vozila i sve zabilježeno uz njih. Račun i garaža ostaju.';

  @override
  String get settingsDeleteDataConfirm =>
      'Obrisati sva vozila i sva njihova točenja, servise, troškove i priloge? Ovo se ne može poništiti.';

  @override
  String get settingsDeleteDataDone => 'Svi podaci o vozilima su obrisani';

  @override
  String get quickAddFuel => 'Točenje';

  @override
  String get quickAddService => 'Servis';

  @override
  String get quickAddCost => 'Trošak';

  @override
  String get quickAddPickVehicle => 'Koje vozilo?';

  @override
  String get settingsPumpAutofill => 'Popuni postaju i cijenu umjesto mene';

  @override
  String get settingsPumpAutofillHint =>
      'Prema vašoj lokaciji na pumpi prepozna postaju na kojoj ste i popuni današnju objavljenu cijenu vašeg goriva. Ništa se ne šalje — lokacija se uspoređuje s cijenama koje su već na telefonu.';

  @override
  String get settingsPumpAutofillOn =>
      'Uključeno — cijena se sama popuni kad ste na pumpi';

  @override
  String get settingsPumpAutofillDenied =>
      'Lokacija je isključena za Garažu. Uključite je u postavkama sustava.';

  @override
  String get settingsSampleData => 'Učitaj primjer podataka';

  @override
  String get settingsSampleDataHint =>
      'Dodaje jedno vozilo s godinom točenja, servisa i troškova, da svaki ekran ima što pokazati. Uklanja se preko „Obriši sve podatke”.';

  @override
  String get settingsSampleDataDone => 'Primjer vozila je dodan';

  @override
  String get gettingStarted => 'Za početak';

  @override
  String get gettingStartedVehicle => 'Dodajte vozilo ručno';

  @override
  String get gettingStartedTransfer => 'Preuzmite vozilo kodom';

  @override
  String get gettingStartedNext => 'Što dalje';

  @override
  String get gettingStartedFuel => 'Zabilježite točenje';

  @override
  String get gettingStartedReminder => 'Odredite što vozilo treba i kada';

  @override
  String get gettingStartedSample =>
      'Ili učitajte primjer podataka da prvo razgledate';

  @override
  String get odometerTitle => 'Kilometraža';

  @override
  String get odometerAdd => 'Zabilježi stanje';

  @override
  String get odometerReading => 'Stanje brojača';

  @override
  String get odometerHint =>
      'Stanje brojača bez troška, da održavanje zna koliko je vozilo prešlo.';

  @override
  String get quickAddOdometer => 'Kilometraža';

  @override
  String get statsPeriodAllTime => 'Sve';

  @override
  String get statsPeriodLastTwelve => 'Zadnjih 12 mjeseci';

  @override
  String get statsPeriodCustom => 'Odaberi datume';

  @override
  String statsPeriodRange(String from, String to) {
    return '$from – $to';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unosa',
      few: '$count unosa',
      one: '$count unos',
      zero: 'Nema unosa',
    );
    return '$_temp0';
  }

  @override
  String get statsPerDay => 'Po danu';

  @override
  String get statsPerDistance => 'Po udaljenosti';

  @override
  String get statsByKind => 'Kamo novac ide';

  @override
  String get statsByCategory => 'Po kategoriji';

  @override
  String get statsByStation => 'Po benzinskoj';

  @override
  String get statsMonthlySpend => 'Potrošnja po mjesecu';

  @override
  String get statsOdometerChart => 'Kilometraža kroz vrijeme';

  @override
  String get statsOthers => 'Ostalo';

  @override
  String get statsUnlabelled => 'Nije zabilježeno';

  @override
  String get statsRecords => 'Najbolje i najgore';

  @override
  String get statsComparison => 'Godina i mjesec';

  @override
  String get statsSummary => 'Sažetak';

  @override
  String get statsCustomise => 'Odaberi što se prikazuje';

  @override
  String get statsCustomiseHint =>
      'Isključeno ovdje, maknuto s puta. Ništa se ne briše.';

  @override
  String get statsShowAll => 'Prikaži sve';

  @override
  String get statsNothingShown =>
      'Sve je skriveno. Odaberite što prikazati iz izbornika.';

  @override
  String get tripsTitle => 'Dnevnik vožnje';

  @override
  String get tripAdd => 'Zabilježi putovanje';

  @override
  String get tripsEmpty => 'Još nema zabilježenih putovanja.';

  @override
  String get tripTitleField => 'Naziv';

  @override
  String get tripFrom => 'Od';

  @override
  String get tripTo => 'Do';

  @override
  String get tripDistance => 'Udaljenost';

  @override
  String get tripDistanceRequired =>
      'Unesite udaljenost ili oba stanja brojača.';

  @override
  String get tripStartOdometer => 'Brojač na početku';

  @override
  String get tripEndOdometer => 'Brojač na kraju';

  @override
  String get tripOdometerOrder =>
      'Stanje na kraju ne može biti manje od početnog.';

  @override
  String get tripMinutes => 'Minuta';

  @override
  String get tripPurpose => 'Svrha';

  @override
  String get tripPurposePrivate => 'Privatno';

  @override
  String get tripPurposeBusiness => 'Poslovno';

  @override
  String get tripTotalTrips => 'Putovanja';

  @override
  String get tripTotalDistance => 'Udaljenost';

  @override
  String get tripTotalTime => 'Vrijeme';

  @override
  String get tripAverageSpeed => 'Prosječna brzina';

  @override
  String tripHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get quickAddTrip => 'Putovanje';

  @override
  String get incomeTitle => 'Prihod';

  @override
  String get incomeAdd => 'Dodaj prihod';

  @override
  String get incomeAmount => 'Iznos';

  @override
  String get incomeCategory => 'Vrsta';

  @override
  String get incomeCategoryRide => 'Doprinos za vožnju';

  @override
  String get incomeCategoryTransportApp => 'Prijevoz putem aplikacije';

  @override
  String get incomeCategoryFreight => 'Prijevoz robe';

  @override
  String get incomeCategoryRefund => 'Povrat';

  @override
  String get incomeCategoryVehicleSale => 'Prodaja vozila';

  @override
  String get incomeCategoryOther => 'Ostalo';

  @override
  String get quickAddIncome => 'Prihod';

  @override
  String get statsBalance => 'Saldo';

  @override
  String get statsTabTrips => 'Putovanja';

  @override
  String get statsBusinessDistance => 'Poslovno';

  @override
  String get statsPrivateDistance => 'Privatno';

  @override
  String get statsIncomeByKind => 'Odakle novac dolazi';

  @override
  String joinSecondGarage(String name) {
    return 'Već ste u garaži $name. Ovim je dodajete — možete se prebacivati između njih.';
  }

  @override
  String get householdSwitch => 'Promijeni garažu';

  @override
  String get householdCreateAnother => 'Napravi još jednu garažu';

  @override
  String get householdYours => 'Vaše garaže';

  @override
  String get householdCurrent => 'Trenutno prikazano';

  @override
  String get transferTitle => 'Prijenos vozila';

  @override
  String get transferSell => 'Prodali ste vozilo?';

  @override
  String get transferSellHint =>
      'Dajte kupcu ovaj kod. Vozilo i cijela povijest prelaze u njegovu garažu, a iz vaše više nisu.';

  @override
  String get transferBought => 'Kupili ste vozilo?';

  @override
  String get transferBoughtHint => 'Unesite kod koji vam je dao prodavatelj.';

  @override
  String get transferGenerate => 'Dohvati kod za prijenos';

  @override
  String get transferConfirmTitle => 'Predati ovo vozilo?';

  @override
  String get transferRedeem => 'Iskoristi kod';

  @override
  String get transferCompletedTitle => 'Predano';

  @override
  String transferCompletedNamed(String nickname) {
    return '$nickname je sada u garaži novog vlasnika, zajedno s cijelom poviješću.';
  }

  @override
  String get transferCompleted =>
      'Vozilo koje ste prenijeli sada je u garaži novog vlasnika.';

  @override
  String get transferCompletedDismiss => 'U redu';

  @override
  String get transferCode => 'Kod za prijenos';

  @override
  String get transferCopied => 'Kod kopiran';

  @override
  String get transferDone => 'Vozilo je sada u vašoj garaži.';

  @override
  String get transferWarning =>
      'Ovo se odavde ne može poništiti — samo novi vlasnik može vratiti vozilo.';

  @override
  String get transferPhotoNote => 'Fotografija ostaje kod vas; sve ostalo ide.';

  @override
  String get vehicleSecondFuel => 'Drugo gorivo';

  @override
  String get vehicleSecondFuelHint =>
      'Za vozilo koje vozi na dva goriva — plin uz benzin. Svako točenje tada kaže koje je gorivo.';

  @override
  String get vehicleSecondFuelNone => 'Samo jedno gorivo';

  @override
  String get fuelWhichFuel => 'Gorivo';

  @override
  String get fuelCng => 'SPP';

  @override
  String get fuelEthanol => 'Etanol';

  @override
  String get fuelPetrolMidgrade => 'Benzin 95+';

  @override
  String get fuelPetrolPremium => 'Benzin 100';

  @override
  String get statsEconomyByFuel => 'Potrošnja po gorivu';

  @override
  String get csvImportTitle => 'Uvoz CSV datoteke';

  @override
  String get csvImportIntro =>
      'Iz Drivva, tablice ili bilo čega drugog što izvozi tablicu. Odaberite datoteku, recite koji je stupac što, i provjerite pregled prije upisa.';

  @override
  String get csvPickFile => 'Odaberi datoteku';

  @override
  String get csvFileEmpty =>
      'Ta datoteka nema redaka koje aplikacija može pročitati.';

  @override
  String get csvWhatIsIt => 'Što je u datoteci';

  @override
  String get csvKindFuel => 'Točenja goriva';

  @override
  String get csvKindCost => 'Troškovi';

  @override
  String get csvKindService => 'Servisi';

  @override
  String get csvKindOdometer => 'Stanja brojača';

  @override
  String get csvKindTrip => 'Putovanja';

  @override
  String get csvKindIncome => 'Prihodi';

  @override
  String get csvWhichVehicle => 'Koje vozilo';

  @override
  String get csvColumns => 'Stupci';

  @override
  String get csvColumnNone => 'Nije u datoteci';

  @override
  String get csvRequired => 'obavezno';

  @override
  String get csvDayFirst => 'Datumi počinju danom (31.12.)';

  @override
  String get csvMiles => 'Udaljenosti su u miljama';

  @override
  String get csvGallons => 'Količine su u galonima';

  @override
  String get csvPreview => 'Pregled';

  @override
  String csvReadyToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redaka spremno',
      few: '$count retka spremna',
      one: '$count redak spreman',
      zero: 'Nema što uvesti',
    );
    return '$_temp0';
  }

  @override
  String csvSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count redaka bit će preskočeno',
      few: '$count retka bit će preskočena',
      one: '$count redak bit će preskočen',
    );
    return '$_temp0';
  }

  @override
  String csvMissingColumn(String field) {
    return 'Odaberite stupac za $field';
  }

  @override
  String csvRowProblem(int line, String field) {
    return 'Redak $line: $field se ne može pročitati';
  }

  @override
  String get csvImportAction => 'Uvezi';

  @override
  String csvImported(int written, int skipped) {
    return 'Uvezeno: $written, već postojalo: $skipped';
  }

  @override
  String get csvFieldDate => 'Datum';

  @override
  String get csvFieldOdometer => 'Brojač';

  @override
  String get csvFieldVolume => 'Količina';

  @override
  String get csvFieldPricePerUnit => 'Cijena po jedinici';

  @override
  String get csvFieldTotal => 'Ukupno';

  @override
  String get csvFieldFullTank => 'Puni spremnik';

  @override
  String get csvFieldStation => 'Benzinska';

  @override
  String get csvFieldNotes => 'Bilješke';

  @override
  String get csvFieldAmount => 'Iznos';

  @override
  String get csvFieldCategory => 'Kategorija';

  @override
  String get csvFieldType => 'Vrsta';

  @override
  String get csvFieldCost => 'Trošak';

  @override
  String get csvFieldShop => 'Servis';

  @override
  String get csvFieldDistance => 'Udaljenost';

  @override
  String get csvFieldTitle => 'Naziv';

  @override
  String get csvFieldFrom => 'Od';

  @override
  String get csvFieldTo => 'Do';

  @override
  String get csvFieldBusiness => 'Poslovno putovanje';

  @override
  String get csvFieldMinutes => 'Minuta';

  @override
  String get settingsImportCsv => 'Uvezi CSV (bilo koja aplikacija)';

  @override
  String get settingsBackup => 'Sigurnosna kopija svega';

  @override
  String get settingsBackupHint =>
      'Datoteka koja se može vratiti, za razliku od CSV izvoza';

  @override
  String get settingsRestore => 'Vrati iz sigurnosne kopije';

  @override
  String get settingsRestoreHint =>
      'Dodaje ono što nedostaje. Ništa se ne briše niti prepisuje.';

  @override
  String get settingsBackupDone => 'Kopija podijeljena';

  @override
  String settingsRestoreDone(int vehicles, int written, int skipped) {
    return 'Vozila: $vehicles, dodano unosa: $written, već postojalo: $skipped';
  }

  @override
  String get settingsRestoreNotABackup =>
      'Ta datoteka nije Garage sigurnosna kopija.';

  @override
  String get stationsPickNearest => 'Najbliža';

  @override
  String get stationsPickCheapest => 'Najjeftinija';

  @override
  String get stationsPickBestValue => 'Najisplativija';

  @override
  String get stationsBestValueHint =>
      'Najjeftinija kad se uračuna gorivo za put onamo i natrag';

  @override
  String get stationsGradeAverages => 'Prosjek u okolici';

  @override
  String stationsGradeStations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count postaja',
      few: '$count postaje',
      one: '$count postaja',
    );
    return '$_temp0';
  }

  @override
  String get commonClear => 'Očisti';

  @override
  String get commonNext => 'Sljedeće';

  @override
  String get commonPrevious => 'Prethodno';

  @override
  String get commonIncrease => 'Povećaj';

  @override
  String get commonDecrease => 'Smanji';

  @override
  String get commonShowPassword => 'Prikaži lozinku';

  @override
  String get commonHidePassword => 'Sakrij lozinku';

  @override
  String get householdRename => 'Preimenuj garažu';

  @override
  String get householdRenamed => 'Garaža je preimenovana';

  @override
  String get householdRenameAdminOnly =>
      'Garažu može preimenovati samo administrator';

  @override
  String get householdDelete => 'Izbriši garažu';

  @override
  String get householdDeleteTitle => 'Izbrisati ovu garažu?';

  @override
  String get householdDeleteBody =>
      'Ovime garaža nestaje za sve u njoj, ne samo za vas. S njom odlaze sva vozila, svi unosi i svi podsjetnici.';

  @override
  String get maintenanceLogServiceHint => 'Nešto što je obavljeno';

  @override
  String get maintenanceAddRuleHint => 'Nešto što se ponavlja';

  @override
  String get quickAddInterval => 'Postavi interval';

  @override
  String get settingsMore => 'Više';

  @override
  String get settingsPreferencesHint => 'Jedinice, valuta, tema i jezik';

  @override
  String get settingsDataHint => 'Uvoz, izvoz i sigurnosne kopije';

  @override
  String get timelineSearch => 'Pretraži povijest';

  @override
  String get timelineNoMatches => 'Ništa ne odgovara tome.';

  @override
  String get serviceBrakeDiscsFront => 'Prednji diskovi';

  @override
  String get serviceBrakeDiscsRear => 'Stražnji diskovi';

  @override
  String get serviceBrakeDrumsRear => 'Stražnji bubnjevi';

  @override
  String get serviceGlowPlugs => 'Grijači';

  @override
  String get serviceDpf => 'DPF filtar';

  @override
  String get serviceAdblue => 'Dopuna AdBluea';

  @override
  String get serviceFuelFilter => 'Filtar goriva';

  @override
  String get serviceClutch => 'Kvačilo';

  @override
  String get serviceDifferentialOil => 'Ulje diferencijala';

  @override
  String get serviceSerpentineBelt => 'Klinasti remen';

  @override
  String get serviceWaterPump => 'Vodena pumpa';

  @override
  String get serviceShockAbsorbers => 'Amortizeri';

  @override
  String get serviceWheelAlignment => 'Geometrija kotača';

  @override
  String get serviceAcService => 'Servis klime';

  @override
  String get serviceBulbs => 'Žarulje';

  @override
  String attachmentTooLarge(String size, String limit) {
    return 'Datoteka ima $size, a ograničenje je $limit. Pokušajte s manjom slikom ili PDF-om.';
  }

  @override
  String get authConfirmChecking => 'Potvrđujemo vašu e-mail adresu…';

  @override
  String get authConfirmFailedTitle => 'Poveznica nije uspjela';

  @override
  String get authConfirmFailedBody =>
      'Poveznice za potvrdu vrijede jednom i istječu. Zatražite novu prijavom ili se registrirajte ponovno.';

  @override
  String get authConfirmNoLink => 'Ovdje nema ničega za potvrditi.';

  @override
  String get authConfirmSignIn => 'Idi na prijavu';

  @override
  String get timelineHasNote => 'Ima bilješku';

  @override
  String get timelineHasAttachment => 'Ima prilog';

  @override
  String get timelineFilter => 'Filtriraj po vrsti';

  @override
  String get timelineFilterClear => 'Očisti filtre';

  @override
  String get settingsYourName => 'Vaše ime';

  @override
  String get settingsNameChanged => 'Ime je promijenjeno';

  @override
  String get settingsSettlement => 'Zajednički troškovi';

  @override
  String get settingsSettlementHint =>
      'Dijeli sve zabilježeno ravnomjerno među članovima i računa tko kome duguje. Korisno kad dijelite auto, a novac vam je odvojen.';

  @override
  String get settingsSettlementEnable => 'Računaj tko kome duguje';
}
