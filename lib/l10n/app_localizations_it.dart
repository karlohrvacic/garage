// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Garage';

  @override
  String get commonShare => 'Condividi';

  @override
  String get commonSave => 'Salva';

  @override
  String get saveStillSaving => 'Salvataggio in corso…';

  @override
  String get saveEntryKept => 'Quello che hai scritto è ancora qui.';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonUndo => 'Annulla';

  @override
  String get discardTitle => 'Vuoi scartare quello che hai scritto?';

  @override
  String get discardKeep => 'Continua a modificare';

  @override
  String get discardConfirm => 'Scarta';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get errorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get errorNoConnection =>
      'Nessuna connessione. Controlla la rete e riprova.';

  @override
  String get errorTimeout =>
      'Il server non ha risposto in tempo. Potrebbe aver salvato lo stesso: controlla l\'elenco prima di riprovare.';

  @override
  String get errorPermission => 'Non hai accesso a questo elemento.';

  @override
  String get errorNotFound => 'Non è stato possibile trovarlo.';

  @override
  String get errorTransferCode =>
      'Quel codice di cessione non è valido oppure è già stato usato.';

  @override
  String get errorTransferHere => 'Quel veicolo è già in questo garage.';

  @override
  String get errorConflict => 'Esiste già.';

  @override
  String get errorInvalid =>
      'Alcuni valori non sono stati accettati. Controllali e riprova.';

  @override
  String get errorExpired => 'Quel codice d\'invito è scaduto.';

  @override
  String get errorAlreadyUsed => 'Quel codice d\'invito è già stato usato.';

  @override
  String get errorAuth => 'Accesso non riuscito. Controlla email e password.';

  @override
  String get errorEmailNotConfirmed =>
      'Conferma prima il tuo indirizzo email. Cerca nella posta in arrivo il link che ti abbiamo inviato alla registrazione.';

  @override
  String get authWhatIsThis => 'Che cosa fa Garage';

  @override
  String get authPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get authTagline => 'Rifornimenti e manutenzione, nero su bianco.';

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authSignUpTitle => 'Crea un account';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authDisplayName => 'Il tuo nome';

  @override
  String get authDisplayNameHint =>
      'Visibile alle persone con cui condividi un garage';

  @override
  String get authSignInAction => 'Accedi';

  @override
  String get authSignUpAction => 'Crea un account';

  @override
  String get authConfirmEmailTitle => 'Controlla la tua email';

  @override
  String authConfirmEmailBody(String email) {
    return 'Abbiamo inviato un link di conferma a $email. Aprilo, poi torna qui e accedi.';
  }

  @override
  String get authConfirmEmailAction => 'Torna all\'accesso';

  @override
  String get authNoAccount => 'Non hai un account? Creane uno';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authResetSent =>
      'Controlla la tua email: ti abbiamo inviato un link per reimpostarla.';

  @override
  String get authLinkFailed =>
      'Quel link è scaduto oppure è già stato usato. Accedi qui sotto, o crea di nuovo l\'account.';

  @override
  String get authContinueWithGoogle => 'Continua con Google';

  @override
  String get authSetNewPasswordTitle => 'Imposta una nuova password';

  @override
  String get authPasswordUpdated => 'Password aggiornata.';

  @override
  String get authInvalidEmail => 'Inserisci un indirizzo email valido';

  @override
  String get authPasswordTooShort => 'Usa almeno 8 caratteri';

  @override
  String get authNameRequired => 'Inserisci il tuo nome';

  @override
  String get onboardingTitle => 'Prepara il tuo garage';

  @override
  String get onboardingCreateTitle => 'Crea un garage';

  @override
  String get onboardingCreateHint => 'Chiunque inviti condivide questi veicoli';

  @override
  String get onboardingHouseholdName => 'Nome del garage';

  @override
  String get onboardingCreateAction => 'Crea';

  @override
  String get onboardingJoinTitle => 'Entra con un codice';

  @override
  String get onboardingJoinHint =>
      'Chiedi a qualcuno del garage il codice d\'invito di 8 caratteri';

  @override
  String get onboardingInviteCode => 'Codice d\'invito';

  @override
  String get onboardingJoinAction => 'Entra';

  @override
  String get onboardingNameRequired => 'Inserisci un nome';

  @override
  String get onboardingSuggestName => 'Suggerisci un nome';

  @override
  String onboardingNameOfPerson(String name) {
    return 'Garage di $name';
  }

  @override
  String get onboardingNameIdea1 => 'Garage di famiglia';

  @override
  String get onboardingNameIdea2 => 'Flotta di casa';

  @override
  String get onboardingNameIdea3 => 'Le nostre auto';

  @override
  String get onboardingNameIdea4 => 'Il cortile';

  @override
  String get onboardingNameIdea5 => 'Parco auto';

  @override
  String get onboardingCodeInvalid => 'Inserisci il codice di 8 caratteri';

  @override
  String get onboardingSignOut => 'Esci';

  @override
  String get joinTitle => 'Entra in un garage';

  @override
  String get joinInvited =>
      'Sei stato invitato a condividere un garage. Accedi, oppure crea un account, ed entrerai con questo invito.';

  @override
  String get joinJoining => 'Ingresso in corso…';

  @override
  String get joinDone =>
      'Ci sei. Tutto quello che il garage registra ora è anche tuo.';

  @override
  String get joinOpenGarage => 'Apri il mio garage';

  @override
  String get householdShareInvite => 'Condividi il link d\'invito';

  @override
  String get householdInviteLinkCopied => 'Messaggio d\'invito copiato';

  @override
  String householdInviteMessageNoExpiry(String code, String link) {
    return 'Entra nel mio garage su Garage: installa l\'app, crea un account, tocca \"Entra con un codice\" e inserisci $code, oppure apri direttamente $link.';
  }

  @override
  String householdInviteMessage(String code, String link, String until) {
    return 'Entra nel mio garage su Garage: installa l\'app, crea un account, tocca \"Entra con un codice\" e inserisci $code, oppure apri direttamente $link. Il codice è valido fino al $until.';
  }

  @override
  String get transferVehicleLocked =>
      'Questo è il veicolo che il codice cederà. Torna indietro per sceglierne un altro.';

  @override
  String householdTransferNamed(String vehicle) {
    return 'Cedi $vehicle a un altro garage';
  }

  @override
  String get householdTransferPick => 'Cedi un veicolo a un altro garage…';

  @override
  String get householdDangerZone => 'Esci o elimina';

  @override
  String get householdManage => 'Gestisci';

  @override
  String get householdTitle => 'Garage';

  @override
  String get householdMembers => 'Membri';

  @override
  String get householdInvite => 'Invita qualcuno';

  @override
  String get householdCopyCode => 'Copia il codice';

  @override
  String get householdCopied => 'Copiato';

  @override
  String get householdLeave => 'Esci dal garage';

  @override
  String get householdLeaveConfirm =>
      'Vuoi uscire da questo garage? Perderai l\'accesso ai suoi veicoli.';

  @override
  String get householdSpend => 'Spesa condivisa';

  @override
  String get householdSpendHint =>
      'Tutto ciò che è registrato sui veicoli di questo garage, da chiunque l\'abbia registrato';

  @override
  String householdUnattributed(String amount) {
    return 'Da un account eliminato: $amount';
  }

  @override
  String householdShareEach(String amount) {
    return 'Quota a testa: $amount';
  }

  @override
  String get householdSettled => 'Conti in pari';

  @override
  String householdOwes(String from, String to, String amount) {
    return '$from deve $amount a $to';
  }

  @override
  String get householdRemoveMember => 'Rimuovi dal garage';

  @override
  String get householdRoleAdmin => 'Amministratore';

  @override
  String get householdRoleMember => 'Membro';

  @override
  String get settingsUnits => 'Unità di misura';

  @override
  String get settingsUnitsHint =>
      'Come vengono mostrati distanze, volumi e prezzi';

  @override
  String get settingsDistance => 'Distanza';

  @override
  String get settingsVolume => 'Volume';

  @override
  String get settingsCurrency => 'Valuta';

  @override
  String get calculatorTitle => 'Calcolatrice';

  @override
  String calculatorFromCar(String vehicle, String economy) {
    return 'Da $vehicle: $economy';
  }

  @override
  String get calcModeTripCost => 'Costo del viaggio';

  @override
  String get calcModeDistance => 'Distanza';

  @override
  String get calcModeConsumption => 'Consumo';

  @override
  String get calcModeRequiredFuel => 'Carburante necessario';

  @override
  String get calcConsumption => 'Consumo';

  @override
  String get calcFuelAvailable => 'Carburante nel serbatoio';

  @override
  String get calcFuelUsed => 'Carburante consumato';

  @override
  String get calcResult => 'Risultato';

  @override
  String get stationsTitle => 'Distributori';

  @override
  String get stationsFuelPetrol => 'Benzina';

  @override
  String get stationsFuelDiesel => 'Diesel';

  @override
  String get stationsFuelLpg => 'GPL';

  @override
  String get stationsAttribution =>
      'Prezzi: mzoe-gor.hr (Ministero dell\'Economia)';

  @override
  String get stationsOpenMap => 'Apri nelle mappe';

  @override
  String get stationsNoLocationTitle => 'I più economici in Croazia';

  @override
  String get stationsNoLocationBody =>
      'Senza la tua posizione questi sono i distributori più economici del Paese, non quelli più vicini. Niente qui è ordinato per distanza.';

  @override
  String get stationsUseLocation => 'Usa la mia posizione';

  @override
  String get stationsGradesNearby => 'Carburanti vicino a te';

  @override
  String get stationsGradesCountry => 'Carburanti in tutto il Paese';

  @override
  String get stationsGradesNote => 'Prima i più venduti';

  @override
  String get stationsFavourite => 'Preferito';

  @override
  String get stationsAvgNearby => 'Media nelle vicinanze';

  @override
  String get stationsNationalAvg => 'Media nazionale';

  @override
  String stationsTrendUp(String amount) {
    return 'In aumento di $amount rispetto alla settimana scorsa';
  }

  @override
  String stationsTrendDown(String amount) {
    return 'In calo di $amount rispetto alla settimana scorsa';
  }

  @override
  String get stationsTrendSteady => 'Stabile rispetto alla settimana scorsa';

  @override
  String get stationsEmpty => 'Nessun distributore trovato.';

  @override
  String stationsOutOfRange(String distance) {
    return 'I prezzi dei carburanti provengono dai dati aperti del ministero croato, quindi sono utili solo in Croazia. Il distributore più vicino tra quelli registrati dista $distance.';
  }

  @override
  String get timelineTitle => 'Cronologia';

  @override
  String get timelineEmpty => 'Non è ancora stato registrato niente.';

  @override
  String get statsTitle => 'Statistiche';

  @override
  String get statsTabFillUps => 'Rifornimenti';

  @override
  String get statsTabCosts => 'Costi';

  @override
  String get statsTabDistance => 'Distanza';

  @override
  String get statsAllVehicles => 'Tutti i veicoli';

  @override
  String get commonVehicle => 'Veicolo';

  @override
  String get statsThisYear => 'Quest\'anno';

  @override
  String get statsPreviousYear => 'Anno precedente';

  @override
  String get statsThisMonth => 'Questo mese';

  @override
  String get statsPreviousMonth => 'Mese precedente';

  @override
  String get statsFillUps => 'Rifornimenti';

  @override
  String get statsFuelVolume => 'Carburante';

  @override
  String get statsMinFill => 'Rifornimento più piccolo';

  @override
  String get statsMaxFill => 'Rifornimento più grande';

  @override
  String get statsAvgEconomy => 'Consumo medio';

  @override
  String get statsBestEconomy => 'Consumo migliore';

  @override
  String get statsWorstEconomy => 'Consumo peggiore';

  @override
  String get statsTotalWithFuel => 'Costi (carburante incluso)';

  @override
  String get statsTotalWithoutFuel => 'Costi (carburante escluso)';

  @override
  String get statsFuelOnly => 'Carburante';

  @override
  String get statsLowestBill => 'Spesa più bassa';

  @override
  String get statsHighestBill => 'Spesa più alta';

  @override
  String get statsBestFuelPrice => 'Miglior prezzo del carburante';

  @override
  String get statsWorstFuelPrice => 'Peggior prezzo del carburante';

  @override
  String get statsAvgPerDay => 'Media al giorno';

  @override
  String get statsAvgPerMonth => 'Media al mese';

  @override
  String get statsAvgPerYear => 'Media all\'anno';

  @override
  String get statsCategories => 'Categorie';

  @override
  String get statsDistanceTracked => 'Distanza registrata';

  @override
  String get statsDistanceNeedsSecond => 'Serve una seconda lettura';

  @override
  String get statsLastOdometer => 'Ultimo contachilometri';

  @override
  String get statsEmpty => 'Non ci sono ancora dati a sufficienza.';

  @override
  String get reminderLogIt => 'Registralo come fatto';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get confirmDeleteTitle => 'Eliminare la voce?';

  @override
  String get confirmDeleteBody => 'Questa operazione non può essere annullata.';

  @override
  String get settingsImportFuelio => 'Importa da Fuelio';

  @override
  String get settingsImportFuelioHint =>
      'Scegli il backup CSV esportato da Fuelio. Vengono importati rifornimenti, costi, interventi e promemoria ricorrenti; una nuova importazione salta le righe già presenti.';

  @override
  String get settingsImportVehicle => 'Importa nel veicolo';

  @override
  String get settingsImportRun => 'Importa';

  @override
  String settingsImportDone(int fills, int services, int costs, int reminders) {
    return 'Rifornimenti: $fills, interventi: $services, costi: $costs, promemoria: $reminders.';
  }

  @override
  String settingsImportSkipped(String titles) {
    return 'Non riconosciuti, saltati: $titles';
  }

  @override
  String get vehicleCurrentOdometer => 'Contachilometri attuale';

  @override
  String get dashboardRecent => 'Attività recente';

  @override
  String get dashboardTotalSpent => 'Spesa totale';

  @override
  String calendarNothingOn(String date) {
    return 'Niente in scadenza il $date';
  }

  @override
  String get calendarTapHint => 'Tocca un giorno per vedere che cosa scade';

  @override
  String get reportsNotSaved => 'Rapporto non salvato';

  @override
  String get reportsTitle => 'Crea un rapporto';

  @override
  String get reportSellers => 'Rapporto per la vendita';

  @override
  String get reportMaintenance => 'Storico della manutenzione';

  @override
  String get reportSchedule => 'Piano di manutenzione';

  @override
  String get reportScheduleHint =>
      'Gli intervalli impostati per questa auto, in un foglio da stampare o da consegnare';

  @override
  String get reportScheduleItem => 'Voce';

  @override
  String get reportScheduleEvery => 'Ogni';

  @override
  String get reportScheduleLastDone => 'Ultima volta';

  @override
  String get reportScheduleNextDue => 'Prossima scadenza';

  @override
  String get reportScheduleNone =>
      'Per questo veicolo non è ancora stato impostato nessun intervallo.';

  @override
  String reportScheduleKm(String km) {
    return '$km km';
  }

  @override
  String reportScheduleMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesi',
      one: '1 mese',
    );
    return '$_temp0';
  }

  @override
  String get reportScheduleOnce => 'Una volta sola';

  @override
  String get reportScheduleNote =>
      'Gli intervalli sono le impostazioni di questo garage, non il piano del costruttore.';

  @override
  String get reportTripLog => 'Registro dei viaggi';

  @override
  String get reportTripLogHint =>
      'Ogni viaggio di un periodo, con la quota di lavoro e una riga da firmare';

  @override
  String get reportTripLogPeriod => 'Periodo';

  @override
  String get reportTripLogDriver => 'Conducente';

  @override
  String get reportTripLogPurpose => 'Dettagli';

  @override
  String get reportTripLogRoute => 'Percorso';

  @override
  String get reportTripLogBusinessTotal => 'Distanza per lavoro';

  @override
  String get reportTripLogPrivateTotal => 'Distanza privata';

  @override
  String get reportTripLogTotal => 'Distanza totale';

  @override
  String get reportTripLogTrips => 'Viaggi';

  @override
  String get reportTripLogSignature => 'Firma';

  @override
  String get reportTripLogDate => 'Data';

  @override
  String get reportTripLogNoTrips =>
      'Nessun viaggio registrato in questo periodo.';

  @override
  String get reportTripLogPickPeriod => 'Quale periodo?';

  @override
  String get reportTripLogThisMonth => 'Questo mese';

  @override
  String get reportTripLogLastMonth => 'Mese scorso';

  @override
  String get reportTripLogThisYear => 'Quest\'anno';

  @override
  String get reportAnnual => 'Riepilogo annuale';

  @override
  String get reportSellersHint =>
      'Quello che chiede un acquirente: storico, chilometraggio e quanto è costato mantenerla';

  @override
  String get reportMaintenanceHint =>
      'Ogni intervento registrato, con date e letture del contachilometri';

  @override
  String get reportAnnualHint =>
      'Un anno di carburante, manutenzione e altri costi';

  @override
  String get costsTitle => 'Costi';

  @override
  String get costAdd => 'Aggiungi un costo';

  @override
  String get costEdit => 'Modifica il costo';

  @override
  String get costAmount => 'Importo';

  @override
  String get costCategory => 'Categoria';

  @override
  String get costDate => 'Data';

  @override
  String get costRemindNextYear => 'Ricordamelo alla prossima scadenza';

  @override
  String get costsEmpty => 'Non è ancora stato registrato nessun costo.';

  @override
  String get costsEmptyBeyondFuel => 'Ancora nessun costo oltre al carburante.';

  @override
  String costsFuelLine(String amount) {
    return 'Carburante $amount, dai rifornimenti';
  }

  @override
  String get costAmountRequired => 'Inserisci un importo.';

  @override
  String get costCategoryRegistration => 'Bollo auto';

  @override
  String get costCategoryInsurance => 'Assicurazione';

  @override
  String get costCategoryParking => 'Parcheggio';

  @override
  String get costCategoryToll => 'Pedaggi';

  @override
  String get costCategoryVignette => 'Vignetta';

  @override
  String get countryAustria => 'Austria';

  @override
  String get countryBulgaria => 'Bulgaria';

  @override
  String get countryCzechia => 'Cechia';

  @override
  String get countryHungary => 'Ungheria';

  @override
  String get countryRomania => 'Romania';

  @override
  String get countrySlovakia => 'Slovacchia';

  @override
  String get countrySlovenia => 'Slovenia';

  @override
  String get countrySwitzerland => 'Svizzera';

  @override
  String fuelAtThePump(String station, String distance) {
    return 'Preso da $station, a $distance. Modificalo se hai pagato un prezzo diverso';
  }

  @override
  String get costVignetteCountry => 'Paese';

  @override
  String get costVignetteValidity => 'Validità';

  @override
  String get costVignetteValidityDay1 => '1 giorno';

  @override
  String get costVignetteValidityDays7 => '7 giorni';

  @override
  String get costVignetteValidityDays10 => '10 giorni';

  @override
  String get costVignetteValidityDays30 => '30 giorni';

  @override
  String get costVignetteValidityMonths2 => '2 mesi';

  @override
  String get costVignetteValidityDays60 => '60 giorni';

  @override
  String get costVignetteValidityYear => '1 anno';

  @override
  String costVignetteBuy(String operator) {
    return 'Acquista da $operator';
  }

  @override
  String costVignetteExpires(String date) {
    return 'Valida fino al $date';
  }

  @override
  String get costVignetteRemind => 'Ricordamelo l\'ultimo giorno di validità';

  @override
  String get costCategoryWash => 'Autolavaggio';

  @override
  String get costCategoryFine => 'Multa';

  @override
  String get costCategoryEquipment => 'Attrezzatura';

  @override
  String get costCategoryOther => 'Altro';

  @override
  String get settingsSignOut => 'Esci';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Come il sistema';

  @override
  String get settingsThemeLight => 'Chiaro';

  @override
  String get settingsThemeDark => 'Scuro';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsLanguageSystem => 'Come il sistema';

  @override
  String get settingsBundling => 'Raggruppamento dei promemoria';

  @override
  String get settingsBundlingWindowDays => 'Raggruppa le voci entro (giorni)';

  @override
  String get settingsBundlingWindowKm => 'Raggruppa le voci entro (distanza)';

  @override
  String get settingsBundlingHint =>
      'Le voci che scadono a poca distanza l\'una dall\'altra vengono proposte come un\'unica visita';

  @override
  String get settingsReminders => 'Promemoria';

  @override
  String get settingsRemindersThisDevice =>
      'Viene avvisato solo questo dispositivo';

  @override
  String get settingsRemindersThisDeviceHint =>
      'Ogni telefono programma i propri promemoria, quindi chi non li ha impostati non ne saprà nulla.';

  @override
  String get settingsRemindersEveryone =>
      'Vengono avvisati tutti in questo garage';

  @override
  String get settingsRemindersEveryoneHint =>
      'I promemoria vengono inviati dal server, quindi li ricevono tutti i membri, non solo il dispositivo che li ha impostati.';

  @override
  String get settingsRemindersSchedule =>
      'Inviati 30 giorni e 7 giorni prima, e ogni volta che una lettura porta una scadenza entro 500 km';

  @override
  String get settingsRemindersScheduleDevice =>
      'Questo dispositivo li invia alle 9:00 del mattino';

  @override
  String get settingsRemindersScheduleServer =>
      'Il server li invia ogni mattina presto';

  @override
  String get settingsCountry => 'Paese';

  @override
  String get settingsCountryHint =>
      'Quali voci di bollo e revisione vengono proposte';

  @override
  String get countryElsewhere => 'Altrove';

  @override
  String get settingsTracking => 'Livello di dettaglio';

  @override
  String get settingsTrackingHint =>
      'Quanti dettagli chiede una voce di manutenzione';

  @override
  String get trackingBeginner => 'Essenziale';

  @override
  String get trackingIntermediate => 'Dettagliato';

  @override
  String get trackingAdvanced => 'Completo';

  @override
  String get serviceDiy => 'Fai da te';

  @override
  String get servicePartsCost => 'Ricambi';

  @override
  String get serviceLaborCost => 'Manodopera';

  @override
  String get servicePartsDetail => 'Ricambi usati';

  @override
  String get serviceWarrantyUntil => 'Garanzia fino al';

  @override
  String get serviceFaultCodes => 'Codici di errore';

  @override
  String get serviceFaultCodesHint => 'ad esempio P0301, P0171';

  @override
  String get serviceMeasurements => 'Misurazioni';

  @override
  String get measurementBrakePadFront => 'Pastiglie freni anteriori';

  @override
  String get measurementBrakePadRear => 'Pastiglie freni posteriori';

  @override
  String get measurementBrakeDiscFront => 'Dischi anteriori';

  @override
  String get measurementTreadFrontLeft => 'Battistrada, anteriore sinistro';

  @override
  String get measurementTreadFrontRight => 'Battistrada, anteriore destro';

  @override
  String get measurementTreadRearLeft => 'Battistrada, posteriore sinistro';

  @override
  String get measurementTreadRearRight => 'Battistrada, posteriore destro';

  @override
  String get measurementBatteryVolts => 'Tensione della batteria';

  @override
  String get measurementBatteryCca => 'CCA della batteria';

  @override
  String get settingsData => 'I tuoi dati';

  @override
  String get settingsExport => 'Esporta come fogli di calcolo';

  @override
  String settingsExportDone(String file) {
    return 'Esportazione pronta: $file';
  }

  @override
  String get settingsDeleteAccount => 'Elimina l\'account';

  @override
  String get settingsDeleteConfirmTitle => 'Vuoi eliminare il tuo account?';

  @override
  String get settingsDeleteConfirmBody =>
      'Questa operazione elimina definitivamente il tuo account. Se sei l\'ultimo membro del tuo garage, vengono eliminati anche i suoi veicoli e tutto il loro storico. Non si può annullare.';

  @override
  String get settingsDeleteConfirmAction => 'Elimina definitivamente';

  @override
  String get settingsDeleteTypeName =>
      'Scrivi il nome del garage per confermare';

  @override
  String get settingsDeleteNameMismatch => 'Questo non è il nome del garage.';

  @override
  String get apiTitle => 'Accesso API';

  @override
  String get apiHint =>
      'Chiavi di sola lettura per i tuoi script, e webhook che inviano i dati di questo garage a un indirizzo scelto da te';

  @override
  String get apiDocs => 'Come si usa';

  @override
  String get apiNewKey => 'Nuova chiave';

  @override
  String get apiKeyName => 'A che cosa serve?';

  @override
  String get apiKeyCreate => 'Crea';

  @override
  String get apiKeyOnce =>
      'Copia questa chiave adesso: non verrà mostrata di nuovo';

  @override
  String get apiKeyRevoke => 'Revoca';

  @override
  String get apiKeyRevoked => 'Revocata';

  @override
  String get apiKeyNeverUsed => 'Mai usata';

  @override
  String apiKeyLastUsed(String date) {
    return 'Ultimo utilizzo $date';
  }

  @override
  String get apiWebhooks => 'Webhook';

  @override
  String get apiWebhooksHint =>
      'Chiamati quando succede qualcosa a un\'auto o al garage';

  @override
  String get apiWebhookAdd => 'Aggiungi un webhook';

  @override
  String get apiWebhookFormat => 'Formato';

  @override
  String get apiWebhookFormatHint =>
      'Ricavato dall\'indirizzo, a meno che il ricevitore non sia tuo';

  @override
  String get apiWebhookEvents => 'Cosa invia';

  @override
  String get apiWebhookEventEntries =>
      'Rifornimenti, interventi, spese, letture, viaggi ed entrate';

  @override
  String get apiWebhookEventChanges => 'Voci modificate o eliminate';

  @override
  String get apiWebhookEventCars =>
      'Veicoli aggiunti, archiviati, prestati o ceduti';

  @override
  String get apiWebhookEventMembers => 'Membri che entrano o escono';

  @override
  String get apiWebhookEventReminders => 'Promemoria in scadenza';

  @override
  String get apiWebhookEventsNone => 'Scegline almeno uno';

  @override
  String get apiWebhookEditEvents => 'Cosa riceve questo webhook';

  @override
  String get apiWebhookFormatAuto => 'Rileva dall\'indirizzo';

  @override
  String get apiWebhookFormatGeneric => 'JSON firmato (Home Assistant, script)';

  @override
  String get apiWebhookUrl => 'URL';

  @override
  String get apiWebhookInvalid => 'Inserisci un indirizzo https://';

  @override
  String get apiWebhookAddAction => 'Aggiungi';

  @override
  String apiWebhookFailing(int status) {
    return 'Ultimo invio non riuscito ($status)';
  }

  @override
  String get apiWebhookName => 'Nome';

  @override
  String get apiWebhookNameHint =>
      'Facoltativo. Mostrato al posto dell\'indirizzo';

  @override
  String get apiWebhookCars => 'Veicoli';

  @override
  String get apiWebhookCarsAll => 'Tutti i veicoli';

  @override
  String apiWebhookCarsSome(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veicoli',
      one: '1 veicolo',
    );
    return '$_temp0';
  }

  @override
  String get apiWebhookCarsNone => 'Scegli almeno un veicolo';

  @override
  String get apiWebhookLanguage => 'Lingua dei messaggi';

  @override
  String get apiWebhookLanguageHint =>
      'Per i servizi di chat. Il JSON firmato non dipende dalla lingua';

  @override
  String get apiWebhookFormatTeams => 'Microsoft Teams';

  @override
  String get apiWebhookFormatText => 'Rocket.Chat, Matrix (testo semplice)';

  @override
  String get apiWebhookFormatPushover => 'Pushover';

  @override
  String get apiWebhookFormatPushbullet => 'Pushbullet';

  @override
  String get apiWebhookNeedsToken =>
      'Incolla l\'URL con il token e la chiave utente';

  @override
  String get apiWebhookCopied => 'Indirizzo copiato';

  @override
  String apiWebhookDelivered(String when) {
    return 'Consegnato $when';
  }

  @override
  String apiWebhookRetrying(int attempt, int most) {
    return 'Nuovo tentativo, $attempt di $most';
  }

  @override
  String apiWebhookGivenUp(int most) {
    return 'Abbandonato dopo $most tentativi';
  }

  @override
  String get apiWebhookQueued => 'In coda';

  @override
  String get apiWebhookPaused => 'In pausa: le ultime consegne sono fallite';

  @override
  String get apiWebhookResume => 'Riprendi';

  @override
  String get apiWebhookSendTest => 'Invia un test';

  @override
  String get apiWebhookTestSent =>
      'Test inviato. Guarda il registro qui sotto.';

  @override
  String get apiWebhookLog => 'Consegne recenti';

  @override
  String get apiWebhookGone => 'Questo webhook non esiste più';

  @override
  String get apiWebhookLogEmpty => 'Ancora nulla inviato';

  @override
  String get apiWebhookNever => 'Ancora nulla inviato';

  @override
  String get commonCopy => 'Copia';

  @override
  String get settingsPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get vehiclesTitle => 'Veicoli';

  @override
  String get vehiclesEmpty =>
      'Aggiungi il tuo primo veicolo per iniziare a registrare';

  @override
  String get vehiclesAdd => 'Aggiungi un veicolo';

  @override
  String vehicleAdded(String name) {
    return 'Aggiunto: $name';
  }

  @override
  String get vehicleNickname => 'Nome';

  @override
  String get vehicleNameRequired => 'Inserisci un nome';

  @override
  String get vehicleMake => 'Marca';

  @override
  String get vehicleModel => 'Modello';

  @override
  String get vehicleYear => 'Anno';

  @override
  String get vehiclePhoto => 'Foto';

  @override
  String get vehiclePhotoAdd => 'Aggiungi una foto';

  @override
  String get vehiclePhotoReplace => 'Sostituisci la foto';

  @override
  String get vehiclePhotoCropTitle => 'Inquadra la foto';

  @override
  String get vehiclePhotoRemove => 'Rimuovi la foto';

  @override
  String get vehiclePhotoNotAPhoto =>
      'Quel file non è una foto. Scegli un\'immagine JPEG, PNG, WebP o HEIC.';

  @override
  String get vehiclePlate => 'Targa';

  @override
  String get sheetVehicleLockedByFile =>
      'Rimuovi l\'allegato per spostare questa voce su un\'altra auto';

  @override
  String get sheetVehicleTapToChange => 'Tocca per cambiare';

  @override
  String get vehicleVin => 'VIN';

  @override
  String get vehicleVinLength => 'Un VIN è lungo da 11 a 17 caratteri';

  @override
  String get vehicleDecodeVin => 'Cerca';

  @override
  String get vehicleVinHint =>
      'Compila marca, modello e anno a partire dal numero';

  @override
  String get vehicleVinNotFound => 'Non è stato possibile cercare quel VIN';

  @override
  String get vehicleVinDecoded => 'Compilato dal registro VIN';

  @override
  String get vehicleFuelType => 'Tipo di carburante';

  @override
  String get vehicleOdometer => 'Contachilometri attuale';

  @override
  String fuelCheaperNearby(String amount, String distance, String station) {
    return '$amount in meno a $distance, da $station';
  }

  @override
  String get fuelCheapestNearby => 'Il più economico nei dintorni quel giorno';

  @override
  String fuelWorseThanUsual(String percent) {
    return '$percent in più rispetto alla media di quest\'auto';
  }

  @override
  String fuelBetterThanUsual(String percent) {
    return '$percent in meno rispetto alla media di quest\'auto';
  }

  @override
  String get vehicleTankCapacity => 'Capacità del serbatoio';

  @override
  String get vehicleTankCapacityHint =>
      'Segnala un rifornimento più grande del serbatoio';

  @override
  String get vehicleCurrentValue => 'Quanto vale adesso';

  @override
  String get vehicleCurrentValueHint =>
      'Una tua stima. Insieme al prezzo d\'acquisto dice quanto costa possedere l\'auto, non solo usarla: il valore che perde è la spesa più grande del tenerla.';

  @override
  String get vehiclePurchasePrice => 'Prezzo d\'acquisto';

  @override
  String get vehiclePurchasePriceHint => 'Quanto hai pagato l\'auto';

  @override
  String get vehicleArchiveTitle => 'Vuoi archiviare questo veicolo?';

  @override
  String get vehicleArchiveBody =>
      'Mantiene il suo storico e resta fuori dagli elenchi e dai totali. Puoi riportarlo indietro dalla sua pagina.';

  @override
  String get vehicleArchivedBanner =>
      'Archiviato: fuori dagli elenchi, storico conservato.';

  @override
  String get vehicleSearch => 'Cerca tra i veicoli';

  @override
  String get recallsTitle => 'Richiami di sicurezza';

  @override
  String get recallsNone =>
      'Nessun richiamo trovato per questa marca, modello e anno';

  @override
  String get recallsCheck => 'Controlla i richiami';

  @override
  String get recallsCaveat =>
      'Dal registro NHTSA statunitense: per un veicolo europeo verifica con un concessionario';

  @override
  String get recallsNeedsDetails =>
      'Aggiungi marca, modello e anno per controllare i richiami';

  @override
  String get tyresTitle => 'Pneumatici';

  @override
  String get vehicleTyresHint =>
      'I treni, il cambio stagionale, il battistrada e l\'età';

  @override
  String get tyresEmpty => 'Aggiungi i treni che monta questo veicolo';

  @override
  String get tyresAdd => 'Aggiungi un treno';

  @override
  String get tyresEdit => 'Modifica il treno';

  @override
  String tyresAgeAgeing(Object years) {
    return '$years anni: vale la pena controllarli ogni anno';
  }

  @override
  String tyresAgeAgeingEstimated(Object years) {
    return 'Circa $years anni, stimati da quando sono stati montati';
  }

  @override
  String tyresAgeExpired(Object years) {
    return '$years anni: da sostituire, qualunque cosa dica il battistrada';
  }

  @override
  String tyresAgeExpiredEstimated(Object years) {
    return 'Circa $years anni, stimati da quando sono stati montati: da sostituire, qualunque cosa dica il battistrada';
  }

  @override
  String get tyresDotCode => 'Codice DOT';

  @override
  String get tyresDotPerCorner => 'I codici sono diversi su ogni pneumatico';

  @override
  String get tyresDotSame => 'Sono tutti uguali';

  @override
  String get tyresDotCodeHint =>
      'Quattro cifre sul fianco, come 3419 per la settimana 34 del 2019';

  @override
  String get tyresDotCodeInvalid =>
      'Quattro cifre: settimana 01-53, poi l\'anno';

  @override
  String get tyresName => 'Nome';

  @override
  String get tyresSeason => 'Stagione';

  @override
  String get tyresSize => 'Misura';

  @override
  String get tyresStorage => 'Custoditi presso';

  @override
  String get tyresFitted => 'Sul veicolo';

  @override
  String get tyresFit => 'Monta sul veicolo';

  @override
  String get tyresRetire => 'Metti fuori uso';

  @override
  String get tyresUnfit => 'Smonta dal veicolo';

  @override
  String get tyresUnretire => 'Rimetti in uso';

  @override
  String get tyresMoreActions => 'Altro per questo treno';

  @override
  String get tyresRetireConfirmTitle => 'Vuoi mettere fuori uso questo treno?';

  @override
  String get tyresRetireConfirmBody =>
      'Resta nell\'elenco con le sue misurazioni e smette di essere proposto per il montaggio.';

  @override
  String get tyresDelete => 'Elimina il treno';

  @override
  String get tyresDeleteConfirmTitle => 'Vuoi eliminare questo treno?';

  @override
  String get tyresDeleteConfirmBody =>
      'Il treno e ogni misurazione del battistrada se ne vanno con lui. Non si può annullare.';

  @override
  String get tyresRetired => 'Fuori uso';

  @override
  String get tyresAddReading => 'Registra il battistrada';

  @override
  String get tyresTread => 'Battistrada';

  @override
  String get tyresTreadNone => 'Nessun battistrada registrato';

  @override
  String get tyresReadingSaved => 'Battistrada registrato';

  @override
  String tyresMeasuredOn(String date) {
    return 'Misurato il $date';
  }

  @override
  String tyresBelowLegalAt(String minimum) {
    return 'Pari o inferiore al minimo legale di $minimum';
  }

  @override
  String tyresWearEstimate(String distance, String date) {
    return 'Restano circa $distance, intorno al $date';
  }

  @override
  String tyresWearEstimateDistanceOnly(Object distance) {
    return 'Restano circa $distance';
  }

  @override
  String get economyByFuelOverlap =>
      'Ogni carburante è misurato sui propri rifornimenti, ma i periodi si sovrappongono: viene conteggiata anche la distanza percorsa con l\'altro carburante. Considerali valori approssimativi, non esatti.';

  @override
  String tyresUneven(String low, String high) {
    return 'Usura irregolare: da $low a $high';
  }

  @override
  String get tyresFront => 'Anteriori';

  @override
  String get tyresRear => 'Posteriori';

  @override
  String get tyresFrontLeft => 'Anteriore sinistro';

  @override
  String get tyresFrontRight => 'Anteriore destro';

  @override
  String get tyresRearLeft => 'Posteriore sinistro';

  @override
  String get tyresRearRight => 'Posteriore destro';

  @override
  String get tyreSeasonSummer => 'Estivi';

  @override
  String get tyreSeasonWinter => 'Invernali';

  @override
  String get tyreSeasonAll => 'Quattro stagioni';

  @override
  String get vehicleTabFuel => 'Consumi';

  @override
  String get vehicleTabUpkeep => 'Interventi';

  @override
  String get vehicleTabCar => 'Auto';

  @override
  String get remindersTitle => 'Promemoria';

  @override
  String get vehicleArchive => 'Archivia';

  @override
  String get vehicleRestore => 'Ripristina';

  @override
  String get vehicleArchived =>
      'Archiviato. Mantiene il suo storico e resta fuori dagli elenchi.';

  @override
  String get vehicleRestored => 'Di nuovo in garage.';

  @override
  String get vehicleDelete => 'Elimina il veicolo';

  @override
  String get vehicleDeleteTitle => 'Vuoi eliminare questo veicolo?';

  @override
  String get vehicleDeleteBody =>
      'Se ne vanno anche tutti i rifornimenti, gli interventi, i costi, le letture e i documenti registrati su di esso, e nulla di tutto ciò è recuperabile. Archivialo, invece, per conservare lo storico.';

  @override
  String get vehiclesArchivedSection => 'Archiviati';

  @override
  String get vehicleEdit => 'Modifica il veicolo';

  @override
  String get vehicleNoEconomyYet => 'Registra due pieni per vedere i consumi';

  @override
  String economyTanksProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieni registrati su 2',
      one: '1 pieno registrato su 2',
    );
    return '$_temp0';
  }

  @override
  String get vehicleTrendNeedsMore =>
      'Registra altri pieni per vedere l\'andamento';

  @override
  String get plannerRestoreExcluded => 'Ripristina le voci escluse';

  @override
  String get vehicleNoHistoryYet => 'Nessun intervento registrato';

  @override
  String get fuelPetrol => 'Benzina';

  @override
  String get fuelDiesel => 'Diesel';

  @override
  String get fuelLpg => 'GPL';

  @override
  String get fuelElectric => 'Elettrico';

  @override
  String get fuelHybrid => 'Ibrido';

  @override
  String get fuelTitle => 'Carburante';

  @override
  String get fuelEmpty =>
      'Registra un rifornimento per iniziare a seguire i consumi';

  @override
  String fuelSaved(String amount) {
    return 'Salvato, $amount.';
  }

  @override
  String fuelSavedFirstFull(String amount) {
    return 'Salvato, $amount. Ancora un pieno e compariranno i consumi.';
  }

  @override
  String get fuelSavedPlain => 'Rifornimento salvato.';

  @override
  String get serviceSaved => 'Intervento registrato.';

  @override
  String get costDuplicateWarning =>
      'Lo stesso importo nella stessa categoria è già registrato in questa data';

  @override
  String get costSaved => 'Costo salvato.';

  @override
  String get fuelAdd => 'Registra un rifornimento';

  @override
  String get fuelLatest => 'Ultimi rifornimenti';

  @override
  String fuelAllFillUps(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tutti i rifornimenti ($count)',
      one: 'Tutti i rifornimenti ($count)',
    );
    return '$_temp0';
  }

  @override
  String get servicesTitle => 'Interventi';

  @override
  String get vehicleSectionDue => 'Scadenze';

  @override
  String get vehicleSectionHistory => 'Storico';

  @override
  String vehicleOnLoanTo(Object date, Object label) {
    return 'In prestito a $label fino al $date';
  }

  @override
  String vehicleOnLoanUntil(Object date) {
    return 'In prestito fino al $date';
  }

  @override
  String get fuelEdit => 'Modifica il rifornimento';

  @override
  String get fuelDate => 'Data';

  @override
  String get fuelOdometer => 'Contachilometri';

  @override
  String get fuelVolume => 'Volume';

  @override
  String get fuelEnergy => 'Ricarica (kWh)';

  @override
  String get fuelPricePerUnit => 'Prezzo unitario';

  @override
  String get fuelTotal => 'Totale';

  @override
  String get fuelFullTank => 'Pieno fatto';

  @override
  String get fuelFullTankHint =>
      'I consumi si calcolano tra un pieno e l\'altro';

  @override
  String get fuelMissedFill =>
      'Ho dimenticato di registrare un rifornimento prima di questo';

  @override
  String get fuelMissedFillHint =>
      'Interrompe la catena di calcolo, così non viene mostrato un dato sbagliato';

  @override
  String get fuelStation => 'Distributore';

  @override
  String get attachmentsTitle => 'Allegati';

  @override
  String get attachmentsAdd => 'Allega una ricevuta o un documento';

  @override
  String get fuelNotes => 'Note';

  @override
  String get fuelAverage => 'Media';

  @override
  String get fuelCostPerDistance => 'Costo del carburante, ultimo rifornimento';

  @override
  String get fuelNeedTwoValues =>
      'Inserisci almeno due valori tra volume, prezzo e totale';

  @override
  String get amountNotANumber => 'Non è un numero';

  @override
  String get fuelOdometerRequired => 'Inserisci la lettura del contachilometri';

  @override
  String fuelOdometerTooLow(String previous) {
    return 'Più bassa della lettura precedente ($previous)';
  }

  @override
  String fuelOdometerTooHigh(String next) {
    return 'Più alta della lettura successiva ($next)';
  }

  @override
  String fuelOdometerLast(String previous) {
    return 'Ultima lettura: $previous';
  }

  @override
  String fuelOdometerEarlierToday(String reading) {
    return 'Già oggi: $reading';
  }

  @override
  String fuelImpliedConsumption(String rate) {
    return 'Ne risulta $rate: controlla il contachilometri e la quantità';
  }

  @override
  String fuelVolumeOverTank(String capacity) {
    return 'Più di quanto contenga il serbatoio ($capacity)';
  }

  @override
  String get maintenanceTitle => 'Manutenzione';

  @override
  String get maintenanceEmpty =>
      'Aggiungi un promemoria per iniziare a seguire le scadenze';

  @override
  String get maintenanceAddRule => 'Aggiungi un promemoria';

  @override
  String maintenanceRuleSaved(String type) {
    return 'Promemoria impostato: $type';
  }

  @override
  String get maintenanceLogService => 'Registra un intervento';

  @override
  String get maintenanceEditService => 'Modifica l\'intervento';

  @override
  String get maintenanceIntervalKm => 'Ogni (distanza)';

  @override
  String get maintenanceIntervalMonths => 'Ogni (mesi)';

  @override
  String intervalNoteMake(String make) {
    return 'Tipico per $make: verifica sul libretto di manutenzione';
  }

  @override
  String get intervalNoteChain =>
      'Questo motore ha una catena di distribuzione, quindi non serve alcun intervallo';

  @override
  String get intervalNoteWetBelt =>
      'Cinghia in bagno d\'olio: la maggior parte dei costruttori ha accorciato questo intervallo';

  @override
  String get intervalNoteSetTimingDrive =>
      'Indica il tipo di distribuzione sul veicolo per un valore predefinito migliore';

  @override
  String get intervalNoteSetTransmission =>
      'Indica il cambio sul veicolo per un valore predefinito migliore';

  @override
  String get intervalNoteSealed =>
      'Un cambio a doppia frizione a secco è sigillato a vita';

  @override
  String get intervalNoteAdvisory =>
      'I costruttori spesso dicono \"a vita\"; le officine indipendenti lo cambiano comunque';

  @override
  String get maintenanceIntervalHint =>
      'Imposta l\'uno, l\'altro o entrambi. Vale il primo che arriva.';

  @override
  String maintenanceDueAt(String odometer) {
    return 'a $odometer';
  }

  @override
  String get maintenanceOneTime => 'Promemoria una tantum';

  @override
  String get maintenanceDueDateField => 'Data di scadenza';

  @override
  String get maintenanceDueKmField => 'Scadenza al contachilometri';

  @override
  String get maintenanceOneTimeNeedsTarget =>
      'Imposta una data o un contachilometri di scadenza.';

  @override
  String maintenanceOtherDeadlineByDate(String date) {
    return 'Per data non prima del $date';
  }

  @override
  String maintenanceOtherDeadlineByDistance(String date) {
    return 'Per distanza non prima del $date';
  }

  @override
  String maintenanceRateMeasured(num days, String rate) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
    );
    return 'Le date qui sotto sono stimate su $rate/giorno rilevati in $_temp0 di letture';
  }

  @override
  String maintenanceRateUnmeasured(String rate) {
    return 'Non c\'è ancora un ritmo di guida: le date qui sotto vengono dall\'intervallo di calendario. Bastano un paio di settimane di letture e compare la stima sulla distanza; fino ad allora una regola con la sola distanza ipotizza $rate/giorno.';
  }

  @override
  String maintenanceCostForItems(String amount, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$amount per $count voci',
      one: '$amount per $count voce',
    );
    return '$_temp0';
  }

  @override
  String maintenancePreviously(String details) {
    return 'In precedenza: $details';
  }

  @override
  String maintenanceDueOn(String date) {
    return 'Scade il $date';
  }

  @override
  String maintenanceExpectedOn(String date) {
    return 'Prevista il $date';
  }

  @override
  String get maintenanceNeedsInterval =>
      'Imposta un intervallo di distanza o di tempo';

  @override
  String get maintenanceServiceDate => 'Data';

  @override
  String get maintenanceServiceCost => 'Costo';

  @override
  String get maintenanceServiceShop => 'Officina';

  @override
  String get serviceDuplicateWarning =>
      'Lo stesso intervento allo stesso contachilometri è già registrato in questa data';

  @override
  String get documentsTitle => 'Documenti';

  @override
  String get documentsSubtitle =>
      'Bollo, revisione, assicurazione e quando scade ciascuno';

  @override
  String get documentsEmpty =>
      'Ancora nessun documento. Registra quando scadono il bollo e la revisione, e l\'app te lo dirà per tempo.';

  @override
  String get documentsSomethingExpired => 'Qualcosa è scaduto';

  @override
  String get documentsSomethingExpiring => 'Qualcosa scade a breve';

  @override
  String get documentAdd => 'Aggiungi un documento';

  @override
  String get documentEdit => 'Modifica il documento';

  @override
  String get documentType => 'Tipo';

  @override
  String get documentLabel => 'Di che cosa si tratta';

  @override
  String get documentLabelHint =>
      'Solo per un documento che questo elenco non prevede';

  @override
  String get documentNumber => 'Numero';

  @override
  String get documentIssuer => 'Rilasciato da';

  @override
  String get documentIssuedOn => 'Rilasciato il';

  @override
  String get documentExpiresOn => 'Valido fino al';

  @override
  String get documentDateNotSet => 'Non impostata';

  @override
  String get documentClearDate => 'Cancella';

  @override
  String get documentNoExpiry => 'Nessuna scadenza registrata';

  @override
  String documentExpiredOn(String date) {
    return 'Scaduto il $date';
  }

  @override
  String get documentExpiresToday => 'Scade oggi';

  @override
  String documentExpiresInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scade tra $count giorni',
      one: 'Scade domani',
    );
    return '$_temp0';
  }

  @override
  String documentValidUntil(String date) {
    return 'Valido fino al $date';
  }

  @override
  String get documentDatesOutOfOrder =>
      'Non può scadere prima di essere stato rilasciato';

  @override
  String get documentLabelRequired => 'Indica che cos\'è questo documento';

  @override
  String get documentSaved => 'Documento salvato.';

  @override
  String get documentReminderNote =>
      'Dalla scadenza viene impostato un promemoria, così comparirà nel pianificatore prima che scada.';

  @override
  String get documentNoReminderNote =>
      'Nessun promemoria: l\'app non ha un nome per questo documento, quindi non può dire che cosa sta per scadere.';

  @override
  String get documentTypeRegistration => 'Bollo auto';

  @override
  String get documentTypeRoadworthiness => 'Revisione';

  @override
  String get documentTypeInsuranceLiability => 'Assicurazione RC auto';

  @override
  String get documentTypeInsuranceComprehensive => 'Polizza kasko';

  @override
  String get documentTypeGreenCard => 'Carta verde';

  @override
  String get documentTypeOther => 'Altro';

  @override
  String get maintenanceServiceItems => 'Che cosa è stato fatto';

  @override
  String get maintenanceRuleServiceType => 'Tipo di intervento';

  @override
  String get serviceTypeChoose => 'Scegli un tipo di intervento';

  @override
  String get serviceTypeSearch => 'Cerca';

  @override
  String get serviceTypeCommon => 'Frequenti';

  @override
  String get serviceTypeOthers => 'Tutto il resto';

  @override
  String get serviceTypeNoMatch => 'Nessun risultato';

  @override
  String get maintenanceCalendar => 'Calendario';

  @override
  String get maintenanceList => 'Elenco';

  @override
  String get serviceOilChange => 'Cambio dell\'olio';

  @override
  String get serviceOilFilter => 'Filtro dell\'olio';

  @override
  String get serviceAirFilter => 'Filtro dell\'aria';

  @override
  String get serviceCabinFilter => 'Filtro abitacolo';

  @override
  String get serviceSparkPlugs => 'Candele';

  @override
  String get serviceBrakeFluid => 'Liquido dei freni';

  @override
  String get serviceBrakePadsFront => 'Pastiglie freni anteriori';

  @override
  String get serviceBrakePadsRear => 'Pastiglie freni posteriori';

  @override
  String get serviceTimingBelt => 'Cinghia di distribuzione';

  @override
  String get serviceCoolant => 'Liquido di raffreddamento';

  @override
  String get serviceTransmissionOil => 'Olio del cambio';

  @override
  String get serviceTireRotation => 'Rotazione degli pneumatici';

  @override
  String get serviceTireSwapSeasonal => 'Cambio stagionale degli pneumatici';

  @override
  String get serviceBattery => 'Batteria';

  @override
  String get serviceWipers => 'Spazzole tergicristallo';

  @override
  String get serviceIssue => 'Guasto segnalato';

  @override
  String get serviceDiagnostics => 'Diagnosi';

  @override
  String get serviceModification => 'Modifica';

  @override
  String get serviceRegistration => 'Bollo auto';

  @override
  String get serviceTechnicalInspection => 'Revisione';

  @override
  String get serviceInsurance => 'Assicurazione';

  @override
  String get serviceInsuranceComprehensive => 'Polizza kasko';

  @override
  String get serviceGreenCard => 'Scadenza della carta verde';

  @override
  String get serviceVignette => 'Scadenza della vignetta';

  @override
  String get maintenanceStateUpcoming => 'In arrivo';

  @override
  String get maintenanceStateDue => 'In scadenza';

  @override
  String get maintenanceStateOverdue => 'Scaduto';

  @override
  String get dashboardTitle => 'Cruscotto';

  @override
  String get plannerTitle => 'Pianificatore';

  @override
  String get plannerRunway => 'Prossime 12 settimane';

  @override
  String get plannerEmpty => 'Niente in scadenza nelle prossime 12 settimane';

  @override
  String get plannerAddReminder => 'Aggiungi un promemoria';

  @override
  String get plannerOverdueNote =>
      'Tutto ciò che è scaduto compare sotto la data di oggi, perché è oggi che va fatto';

  @override
  String get plannerFurtherOut => 'Più avanti';

  @override
  String get plannerFurtherOutNote =>
      'Oltre le dodici settimane, mese per mese.';

  @override
  String plannerWeekOf(String date) {
    return 'Settimana del $date';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get dashboardDueSoonest => 'Scadenze più vicine';

  @override
  String dashboardNextUp(String what, String when) {
    return 'Prossima: $what · $when';
  }

  @override
  String dashboardOverdueNow(String what) {
    return 'Scaduto: $what';
  }

  @override
  String dashboardDueByDistance(String rate) {
    return 'per distanza, circa $rate al giorno';
  }

  @override
  String dashboardDueByDistanceAssumed(String rate) {
    return 'per distanza, ipotizzando $rate al giorno';
  }

  @override
  String get dashboardDueByDateOnly =>
      'per data; bastano un paio di settimane di guida e compare la stima sulla distanza';

  @override
  String dashboardVehicleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veicoli',
      one: '1 veicolo',
    );
    return '$_temp0';
  }

  @override
  String bundleVisitOn(String date) {
    return 'Un\'unica visita il $date';
  }

  @override
  String bundleSpanDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'A $days giorni di distanza',
      one: 'A $days giorno di distanza',
    );
    return '$_temp0';
  }

  @override
  String get bundleLogVisit => 'Registra questa visita';

  @override
  String get bundleExcludeHint =>
      'Togliere una voce cambia solo il suggerimento qui sopra: non viene registrato né annullato niente.';

  @override
  String get bundlePutBack => 'Rimetti';

  @override
  String get bundleOneVehicleOnly =>
      'Registrala veicolo per veicolo: queste voci riguardano più di un veicolo.';

  @override
  String get bundleExclude => 'Questa no';

  @override
  String get bundleExplain =>
      'Queste scadono a poca distanza l\'una dall\'altra: farle in un\'unica visita risparmia un secondo viaggio';

  @override
  String notificationDueTitle(String service) {
    return '$service: è il momento';
  }

  @override
  String notificationBundleTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci in scadenza insieme',
      one: '$count voce in scadenza',
    );
    return '$_temp0';
  }

  @override
  String notificationDueIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scade tra $count giorni',
      one: 'Scade tra 1 giorno',
    );
    return '$_temp0';
  }

  @override
  String notificationDueInKm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scade tra $count km',
    );
    return '$_temp0';
  }

  @override
  String notificationOverdueByKm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Scaduto da $count km',
    );
    return '$_temp0';
  }

  @override
  String bundleSuggestionTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Raggruppa $count voci in un\'unica visita',
      one: 'Raggruppa $count voce in un\'unica visita',
    );
    return '$_temp0';
  }

  @override
  String get aboutTitle => 'Informazioni';

  @override
  String get aboutTagline =>
      'Ogni veicolo del garage in un unico posto: carburante, manutenzione, costi e la prossima scadenza.';

  @override
  String aboutVersion(String version, String build) {
    return 'Versione $version ($build)';
  }

  @override
  String get aboutPromises => 'Che cosa promette questa app';

  @override
  String get aboutPromiseFree =>
      'Niente pubblicità, mai. Gratis per un piccolo garage. Quello che hai già registrato resta sempre accessibile senza pagare.';

  @override
  String get aboutPromiseData =>
      'I tuoi dati sono tuoi. Esporta tutto in CSV quando vuoi: si apre con qualsiasi foglio di calcolo.';

  @override
  String get aboutPromiseLeave =>
      'Andarsene è volutamente facile. Elimina il tuo account e il tuo garage se ne va con lui. Un garage condiviso resta agli altri, con quello che hai registrato ma senza il tuo nome.';

  @override
  String get aboutPromisePrivacy =>
      'Nessun tracciamento, nessuna analisi, nessun profilo. Quello che registri resta nel tuo garage.';

  @override
  String get aboutPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get aboutLicences => 'Licenze open source';

  @override
  String get aboutLicencesHint => 'Le librerie su cui è costruita questa app';

  @override
  String get aboutSourceCode => 'Codice sorgente';

  @override
  String get aboutSourceCodeHint =>
      'L\'app è interamente open source, con licenza AGPL-3.0';

  @override
  String get aboutSendFeedback => 'Invia un commento';

  @override
  String get aboutSendFeedbackHint =>
      'Un errore, un\'idea, o anche solo un saluto';

  @override
  String get aboutFeedbackSubject => 'Commenti su Garage';

  @override
  String get aboutDiagnostics => 'Diagnostica';

  @override
  String get aboutDiagnosticsHint =>
      'Errori recenti, da allegare a una segnalazione';

  @override
  String get diagnosticsTitle => 'Diagnostica';

  @override
  String get diagnosticsEmpty =>
      'Su questo dispositivo non è andato storto niente.';

  @override
  String get diagnosticsExplain =>
      'Conservata solo su questo dispositivo. Non viene inviato niente finché non la condividi tu.';

  @override
  String get diagnosticsShare => 'Condividi';

  @override
  String get diagnosticsClear => 'Cancella';

  @override
  String get diagnosticsCleared => 'Diagnostica cancellata';

  @override
  String get settingsTrackingBasicHint =>
      'Data, contachilometri, che cosa è stato fatto e quanto è costato';

  @override
  String get settingsTrackingDetailedHint =>
      'Aggiunge ricambi, manodopera, fai da te e garanzia';

  @override
  String get settingsTrackingFullHint =>
      'Aggiunge le misurazioni: spessore delle pastiglie, battistrada, tensione';

  @override
  String settingsImportCreates(String name) {
    return 'Questo aggiungerà $name al tuo garage';
  }

  @override
  String get settingsImportNoVehicle =>
      'Quel backup non contiene nessun veicolo. Aggiungi prima un veicolo, poi importa al suo interno.';

  @override
  String get settingsImportStation => 'Distributore';

  @override
  String get settingsImportStationHint =>
      'Facoltativo: questo file non dice dove hai fatto rifornimento';

  @override
  String get settingsImportFuelType => 'Carburante che usa';

  @override
  String get settingsExportNothing =>
      'Non c\'è ancora niente da esportare: registra prima un rifornimento o un intervento';

  @override
  String get householdInvites => 'Codici d\'invito';

  @override
  String get householdInvitesHint =>
      'Chiunque abbia un codice può entrare in questo garage finché non viene usato o non scade';

  @override
  String householdInviteActiveUntil(String until) {
    return 'Pronto da inviare · valido fino al $until';
  }

  @override
  String get householdInviteUsed => 'Usato';

  @override
  String get householdInviteExpired => 'Scaduto';

  @override
  String get householdInviteRevoke => 'Revoca';

  @override
  String get householdInviteRevokeTitle => 'Vuoi revocare questo codice?';

  @override
  String get householdInviteRevokeBody =>
      'Chi lo possiede non potrà più usarlo per entrare. Puoi crearne uno nuovo.';

  @override
  String get householdInviteRevoked => 'Codice revocato';

  @override
  String get householdInviteNew => 'Nuovo codice';

  @override
  String economyScale(String best, String worst) {
    return 'Migliore $best · Peggiore $worst su questo veicolo';
  }

  @override
  String get economyScaleNone =>
      'Registra qualche pieno per avere un termine di paragone';

  @override
  String economyScaleDefault(String best, String worst) {
    return 'L\'anello va da $best a $worst finché quest\'auto non ha una scala tutta sua';
  }

  @override
  String get maintenanceLastDone => 'Ultima volta (facoltativo)';

  @override
  String get maintenanceLastDoneHint =>
      'Se l\'hai già fatto, indica quando: gli intervalli si contano da lì invece che da quando è stato aggiunto il veicolo';

  @override
  String get maintenanceLastDoneDate => 'Data in cui è stato fatto';

  @override
  String get maintenanceLastDoneDatePick => 'Scegli una data';

  @override
  String get maintenanceLastDoneKm => 'Contachilometri di allora';

  @override
  String maintenanceLastDoneFromLog(String date) {
    return 'Preso dall\'intervento registrato il $date';
  }

  @override
  String get runningCostTitle => 'Quanto costa questo veicolo';

  @override
  String runningCostFuelShare(String amount) {
    return 'Carburante $amount';
  }

  @override
  String runningCostUpkeepShare(String amount) {
    return 'Manutenzione $amount';
  }

  @override
  String get runningCostPerMonth => 'Al mese';

  @override
  String get runningCostPerYear => 'All\'anno';

  @override
  String get runningCostTotal => 'Da quando l\'hai aggiunto';

  @override
  String get runningCostSpread =>
      'Le coperture annuali come assicurazione e bollo sono ripartite sul loro anno per i dati mensili e annuali.';

  @override
  String runningCostToOwn(String rate) {
    return '$rate per possederlo, contando il valore che ha perso';
  }

  @override
  String get runningCostValuationStale =>
      'Basato su una stima di oltre un anno fa: aggiornala nella pagina del veicolo.';

  @override
  String get runningCostOwnership => 'Costo di possesso finora';

  @override
  String get runningCostNotEnough =>
      'Registra qualche rifornimento e qualche costo per vedere quanto costa usare questo veicolo';

  @override
  String get runningCostNeedsTank =>
      'Ancora un pieno e comparirà il costo per distanza';

  @override
  String get runningCostBreakdown => 'Dove sono finiti';

  @override
  String get runningCostFuelTotal => 'Carburante';

  @override
  String get runningCostServiceTotal => 'Manutenzione';

  @override
  String get runningCostOtherTotal => 'Bollo, assicurazione e il resto';

  @override
  String get costCategoryInsuranceComprehensive => 'Polizza kasko';

  @override
  String get settingsDeleteData => 'Elimina tutti i dati';

  @override
  String get settingsDeleteDataHint =>
      'Ricomincia da capo: rimuove ogni veicolo e tutto quello che vi è stato registrato. Il tuo account e il garage restano.';

  @override
  String get settingsDeleteDataConfirm =>
      'Vuoi eliminare tutti i veicoli e tutti i loro rifornimenti, interventi, costi e allegati? Non si può annullare.';

  @override
  String get settingsDeleteDataDone =>
      'Tutti i dati dei veicoli sono stati eliminati';

  @override
  String get quickAddFuel => 'Rifornimento';

  @override
  String get quickAddService => 'Intervento';

  @override
  String get quickAddCost => 'Costo';

  @override
  String get quickAddPickVehicle => 'Quale veicolo?';

  @override
  String get settingsPumpAutofill => 'Compila tu distributore e prezzo';

  @override
  String get settingsDataBringIn => 'Porta dentro i dati';

  @override
  String get settingsDataTakeOut => 'Porta fuori i dati';

  @override
  String get settingsForDevelopers => 'Per sviluppatori';

  @override
  String get settingsFillUps => 'Rifornimenti';

  @override
  String get settingsPumpAutofillHint =>
      'Usa la tua posizione al distributore per capire dove sei e inserire il prezzo esposto oggi per il tuo carburante. Non viene inviato niente: la posizione viene confrontata con i prezzi già presenti sul telefono.';

  @override
  String get settingsPumpAutofillOn =>
      'Attivo: il prezzo si compila da solo quando sei a un distributore';

  @override
  String get settingsPumpAutofillDenied =>
      'La posizione è disattivata per Garage. Attivala nelle impostazioni di sistema per usare questa funzione.';

  @override
  String get settingsSampleData => 'Carica dati di esempio';

  @override
  String get settingsSampleDataHint =>
      'Aggiunge un veicolo con un anno di rifornimenti, interventi e costi, così ogni schermata ha qualcosa da mostrare. Si rimuove da Altro → Impostazioni → Elimina tutti i dati.';

  @override
  String get settingsSampleDataConfirmTitle =>
      'Vuoi caricare i dati di esempio?';

  @override
  String settingsSampleDataConfirmBody(String vehicle) {
    return 'Questo aggiunge un\'auto dimostrativa ($vehicle) con un anno di storico a questo garage, accanto a quello che hai già. Puoi eliminarla in seguito.';
  }

  @override
  String get settingsSampleDataDone => 'Veicolo di esempio aggiunto';

  @override
  String get gettingStarted => 'Per cominciare';

  @override
  String get gettingStartedFirstVehicle => 'Aggiungi il tuo primo veicolo';

  @override
  String get gettingStartedImport => 'Importa da un\'altra app';

  @override
  String get gettingStartedTransfer => 'Ricevi un veicolo con un codice';

  @override
  String get gettingStartedNext => 'E adesso';

  @override
  String get gettingStartedFuel => 'Registra un rifornimento';

  @override
  String get gettingStartedReminder =>
      'Imposta un promemoria: che cosa serve e quando';

  @override
  String get gettingStartedSample =>
      'Oppure carica i dati di esempio per dare prima un\'occhiata';

  @override
  String get gettingStartedTour => 'Scopri tutto quello che sa fare Garage';

  @override
  String get gettingStartedHide => 'Nascondi';

  @override
  String get featuresTitle => 'Che cosa sa fare Garage';

  @override
  String get featuresHint =>
      'Una panoramica in una pagina delle cose principali, e di dove si trova ciascuna';

  @override
  String get featureAddVehicle => 'Aggiungi un veicolo';

  @override
  String get featureAddVehicleBlurb =>
      'Un\'auto, una moto o un furgone. Scrivi il VIN e marca, modello e anno si compilano da soli.';

  @override
  String get featureFuel => 'Registro dei rifornimenti';

  @override
  String get featureFuelBlurb =>
      'Registra un rifornimento in pochi secondi dal cruscotto. Consumo, costo al chilometro e quanta strada fai con un pieno vengono da sé.';

  @override
  String get featurePlannerBlurb =>
      'Che cosa serve a ogni veicolo, settimana per settimana, e quali lavori conviene raggruppare in un\'unica visita in officina.';

  @override
  String get featureTimelineBlurb =>
      'Tutto quello che è successo a ogni veicolo, mese per mese, con il totale di ciascun mese.';

  @override
  String get featureStatsBlurb =>
      'Consumi, spese e distanze su qualsiasi periodo, per veicolo o per tutto il garage.';

  @override
  String get featureStationsBlurb =>
      'I prezzi dei carburanti di oggi nelle vicinanze, e se sono saliti o scesi questa settimana.';

  @override
  String get featureTripsBlurb =>
      'Registra i viaggi privati e di lavoro; la distanza arriva dal contachilometri.';

  @override
  String get featureCalculatorBlurb =>
      'Costo del viaggio, autonomia o consumo a partire dai numeri che hai.';

  @override
  String get featureTyres => 'Pneumatici';

  @override
  String get featureTyresBlurb =>
      'I treni di gomme, il cambio stagionale, il battistrada e l\'età, sulla pagina di ogni veicolo.';

  @override
  String get featureDocuments => 'Documenti';

  @override
  String get featureDocumentsBlurb =>
      'Bollo, revisione, assicurazione e carta verde, ciascuno con la sua data di scadenza, e un promemoria prima che arrivi.';

  @override
  String get featureReceipts => 'Ricevute e fatture';

  @override
  String get featureReceiptsBlurb =>
      'Allega alla voce lo scontrino della pompa o la fattura dell\'officina una volta salvata, e ritrovala anni dopo, quando vendi l\'auto.';

  @override
  String get featureShare => 'Condividi il garage';

  @override
  String get featureShareBlurb =>
      'Invita chi usa l\'auto con te. Tutti vedono lo stesso registro e le spese si dividono.';

  @override
  String get featureLend => 'Presta un\'auto';

  @override
  String get featureLendBlurb =>
      'Dai un codice a qualcuno e per qualche giorno potrà registrare rifornimenti e viaggi su una sola auto, senza entrare nel tuo garage né vedere il tuo storico.';

  @override
  String get featureData => 'Importazione, esportazione e backup';

  @override
  String get featureDataBlurb =>
      'Porta qui il tuo storico da Fuelio o da un qualsiasi CSV; esportalo o fanne un backup quando vuoi.';

  @override
  String get featureApiBlurb =>
      'Leggi i tuoi dati da uno script o da un foglio di calcolo con una chiave.';

  @override
  String get odometerTitle => 'Contachilometri';

  @override
  String get odometerAdd => 'Registra una lettura';

  @override
  String get odometerEdit => 'Modifica la lettura';

  @override
  String get odometerReading => 'Lettura';

  @override
  String get odometerHint =>
      'Una lettura senza importi, così la manutenzione sa comunque quanta strada ha fatto il veicolo.';

  @override
  String get quickAddOdometer => 'Contachilometri';

  @override
  String get statsPeriodAllTime => 'Sempre';

  @override
  String get statsPeriodLastTwelve => 'Ultimi 12 mesi';

  @override
  String get statsPeriodCustom => 'Scegli le date';

  @override
  String statsPeriodRange(String from, String to) {
    return '$from / $to';
  }

  @override
  String statsEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci',
      one: '1 voce',
      zero: 'Nessuna voce',
    );
    return '$_temp0';
  }

  @override
  String get statsPerDay => 'Per giorno';

  @override
  String get statsPerDistance => 'Per distanza';

  @override
  String get statsByKind => 'Dove vanno i soldi';

  @override
  String get statsByCategory => 'Per categoria';

  @override
  String get statsByStation => 'Spesa per distributore';

  @override
  String get statsMonthlySpend => 'Spesa mensile';

  @override
  String get statsEconomyByStation => 'Consumi per distributore';

  @override
  String get statsEconomyByStationNote =>
      'Un\'osservazione, non un consiglio: guida, meteo e stagione spostano i consumi molto più del carburante';

  @override
  String statsEconomyTanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pieni',
      one: '1 pieno',
    );
    return '$_temp0';
  }

  @override
  String get statsOdometerChart => 'Contachilometri nel tempo';

  @override
  String get statsFullTankRange => 'Con il pieno';

  @override
  String get statsFullTankTypical => 'Di solito';

  @override
  String get statsFullTankBest => 'Pieno migliore';

  @override
  String get statsFullTankWorst => 'Pieno peggiore';

  @override
  String get statsFullTankSize => 'Serbatoio';

  @override
  String statsFullTankTanks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Da $count pieni, da sempre',
      one: 'Da $count pieno, da sempre',
    );
    return '$_temp0';
  }

  @override
  String get statsOthers => 'Altri';

  @override
  String get statsUnlabelled => 'Non registrato';

  @override
  String get statsRecords => 'Migliori e peggiori';

  @override
  String get statsComparison => 'Anno e mese';

  @override
  String get statsSummary => 'Riepilogo';

  @override
  String get statsCustomise => 'Scegli che cosa mostrare';

  @override
  String get statsCustomiseHint =>
      'Disattivato qui, tolto di mezzo. Non viene eliminato niente.';

  @override
  String get statsShowAll => 'Mostra tutto';

  @override
  String get statsNothingShown =>
      'È tutto nascosto. Scegli dal menu che cosa mostrare.';

  @override
  String get tripsTitle => 'Viaggi';

  @override
  String get tripAdd => 'Registra un viaggio';

  @override
  String get tripEdit => 'Modifica il viaggio';

  @override
  String get tripsEmpty => 'Non è ancora stato registrato nessun viaggio.';

  @override
  String get tripTitleField => 'Nome';

  @override
  String get tripFrom => 'Da';

  @override
  String get tripTo => 'A';

  @override
  String get tripDistance => 'Distanza';

  @override
  String tripImpliedSpeed(String speed) {
    return 'Ne risulta $speed: controlla la distanza e il tempo';
  }

  @override
  String get tripDriver => 'Conducente';

  @override
  String get tripDriverHint =>
      'Chi era al volante: un registro dei viaggi per il fisco lo indica, e non è sempre chi ha scritto la voce.';

  @override
  String get tripDistanceRequired =>
      'Inserisci una distanza, oppure entrambe le letture del contachilometri.';

  @override
  String get tripStartOdometer => 'Contachilometri alla partenza';

  @override
  String get tripEndOdometer => 'Contachilometri all\'arrivo';

  @override
  String get tripOdometerOrder =>
      'La lettura all\'arrivo non può essere più bassa di quella alla partenza.';

  @override
  String get tripMinutes => 'Minuti';

  @override
  String get tripPurpose => 'Motivo';

  @override
  String get tripPurposePrivate => 'Privato';

  @override
  String get tripPurposeBusiness => 'Lavoro';

  @override
  String get tripTotalTrips => 'Viaggi';

  @override
  String get tripTotalDistance => 'Distanza';

  @override
  String get tripTotalTime => 'Tempo';

  @override
  String get tripAverageSpeed => 'Velocità media';

  @override
  String tripHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get tripDriveStart => 'Inizia un viaggio';

  @override
  String get tripDriveInProgress => 'Viaggio in corso';

  @override
  String tripDriveSince(String time) {
    return 'Partenza alle $time';
  }

  @override
  String tripDriveElapsed(String duration) {
    return '$duration finora';
  }

  @override
  String get tripDriveFinish => 'Termina il viaggio';

  @override
  String get tripDriveDiscard => 'Scarta';

  @override
  String get tripDriveDiscardConfirm =>
      'Vuoi scartare questo viaggio? Non verrà registrato niente.';

  @override
  String get tripDriveOdometerNow => 'Contachilometri adesso';

  @override
  String get tripDriveOdometerNowHint =>
      'Quello che segna il cruscotto. Lascialo vuoto se non riesci a vederlo.';

  @override
  String get tripDriveStarted => 'Viaggio iniziato. Chiudilo quando parcheggi.';

  @override
  String tripDriveFinished(String distance) {
    return 'Viaggio registrato: $distance';
  }

  @override
  String get tripDriveAlreadyOpen => 'Quell\'auto è già in viaggio.';

  @override
  String get tripDriveNeedsMeasure =>
      'Inserisci il contachilometri di adesso, oppure una distanza.';

  @override
  String tripDriveStartedBy(String name) {
    return 'Iniziato da $name';
  }

  @override
  String get incomeTitle => 'Entrate';

  @override
  String get incomeAdd => 'Aggiungi un\'entrata';

  @override
  String get incomeEdit => 'Modifica l\'entrata';

  @override
  String get incomeAmount => 'Importo';

  @override
  String get incomeCategory => 'Tipo';

  @override
  String get incomeCategoryRide => 'Passaggi condivisi';

  @override
  String get incomeCategoryTransportApp => 'Trasporto con app';

  @override
  String get incomeCategoryFreight => 'Trasporto merci';

  @override
  String get incomeCategoryRefund => 'Rimborso';

  @override
  String get incomeCategoryVehicleSale => 'Vendita del veicolo';

  @override
  String get incomeCategoryOther => 'Altro';

  @override
  String get quickAddIncome => 'Entrata';

  @override
  String get quickAddMore => 'Altro';

  @override
  String get statsBalance => 'Saldo';

  @override
  String get statsTabTrips => 'Viaggi';

  @override
  String get statsBusinessDistance => 'Lavoro';

  @override
  String get statsPrivateDistance => 'Privato';

  @override
  String get statsIncomeByKind => 'Da dove arrivano i soldi';

  @override
  String joinSecondGarage(String current, String name) {
    return 'Fai già parte di $current. Entrando in $name lo aggiungi: potrai passare dall\'uno all\'altro.';
  }

  @override
  String joinFor(String name) {
    return 'Questo invito è per il garage $name.';
  }

  @override
  String joinAlreadyMember(String name) {
    return 'Fai già parte di $name. Non c\'è nulla a cui unirsi.';
  }

  @override
  String get householdSwitch => 'Cambia garage';

  @override
  String get householdCreateAnother => 'Crea un altro garage';

  @override
  String get householdYours => 'I tuoi garage';

  @override
  String get householdCurrent => 'Visualizzato ora';

  @override
  String get transferTitle => 'Cedi questo veicolo';

  @override
  String get transferCodeCancel => 'Annulla questa cessione';

  @override
  String get transferCodeCancelled =>
      'Cessione annullata. Il codice non funziona più.';

  @override
  String get transferSellHint =>
      'Consegna questo codice all\'acquirente. Il veicolo e tutto il suo storico passano nel suo garage e escono dal tuo.';

  @override
  String get transferBought => 'Hai comprato un veicolo?';

  @override
  String get transferBoughtHint =>
      'Inserisci il codice che ti ha dato il venditore.';

  @override
  String get transferGenerate => 'Ottieni un codice di cessione';

  @override
  String get transferConfirmTitle => 'Vuoi cedere questo veicolo?';

  @override
  String get transferRedeem => 'Riscatta un codice';

  @override
  String get transferCompletedTitle => 'Ceduto';

  @override
  String transferCompletedNamed(String nickname) {
    return '$nickname è ora nel garage del nuovo proprietario, con tutto il suo storico.';
  }

  @override
  String get transferCompleted =>
      'Un veicolo che hai ceduto è ora nel garage del nuovo proprietario.';

  @override
  String get transferCompletedDismiss => 'Ho capito';

  @override
  String get transferSell => 'Hai venduto il veicolo?';

  @override
  String get transferCode => 'Codice di cessione';

  @override
  String get transferCopied => 'Codice copiato';

  @override
  String get transferDone => 'Il veicolo è ora nel tuo garage.';

  @override
  String get transferWarning =>
      'Da qui non si può annullare: solo il nuovo proprietario può restituirlo.';

  @override
  String get transferPhotoNote =>
      'La foto resta a te; tutto il resto se ne va.';

  @override
  String get vehicleSecondFuel => 'Secondo carburante';

  @override
  String get vehicleSecondFuelHint =>
      'Per un veicolo che ne usa due, per esempio GPL accanto alla benzina. Ogni rifornimento dirà allora quale è stato messo.';

  @override
  String get vehicleSecondFuelNone => 'Nessun secondo carburante';

  @override
  String get vehicleKind => 'Tipo di veicolo';

  @override
  String get vehicleSectionEngine => 'Motore e carburante';

  @override
  String get vehicleSectionOptional => 'Dettagli facoltativi';

  @override
  String get vehicleKindCar => 'Auto';

  @override
  String get vehicleKindMotorcycle => 'Moto';

  @override
  String get vehicleKindVan => 'Furgone';

  @override
  String get vehicleFinalDrive => 'Trasmissione finale';

  @override
  String get vehicleFinalDriveNotSet => 'Non impostata';

  @override
  String get finalDriveChain => 'Catena';

  @override
  String get finalDriveBelt => 'Cinghia';

  @override
  String get finalDriveShaft => 'Cardano';

  @override
  String get vehicleTimingDrive => 'Distribuzione a cinghia o a catena';

  @override
  String get vehicleTimingDriveNotSet => 'Non lo so';

  @override
  String get vehicleTimingDriveHint =>
      'Cinghia in bagno d\'olio (PureTech, EcoBoost, 1.0 TCe): la cinghia gira nell\'olio motore';

  @override
  String get timingDriveBelt => 'Cinghia';

  @override
  String get timingDriveChain => 'Catena';

  @override
  String get timingDriveWetBelt => 'Cinghia in bagno d\'olio';

  @override
  String get vehicleTransmission => 'Cambio';

  @override
  String get vehicleTransmissionNotSet => 'Non impostato';

  @override
  String get transmissionManual => 'Manuale';

  @override
  String get transmissionAutomatic => 'Automatico';

  @override
  String get transmissionDctDry => 'Doppia frizione, a secco';

  @override
  String get transmissionDctWet => 'Doppia frizione, in bagno d\'olio';

  @override
  String get transmissionCvt => 'CVT';

  @override
  String get fuelWhichFuel => 'Carburante';

  @override
  String get fuelCng => 'Metano';

  @override
  String get fuelEthanol => 'Etanolo';

  @override
  String get fuelPetrolMidgrade => 'Benzina 95+';

  @override
  String get fuelPetrolPremium => 'Benzina 100';

  @override
  String get statsEconomyByFuel => 'Consumo per carburante';

  @override
  String get csvImportTitle => 'Importa un CSV';

  @override
  String get csvImportIntro =>
      'Da Drivvo, da un foglio di calcolo o da qualsiasi altra cosa esporti una tabella. Scegli il file, indica a che cosa corrisponde ogni colonna e controlla l\'anteprima prima che venga scritto.';

  @override
  String get csvPickFile => 'Scegli un file';

  @override
  String get csvFileEmpty =>
      'Quel file non ha righe che questa app possa leggere.';

  @override
  String get csvWhatIsIt => 'Che cosa contiene questo file';

  @override
  String get csvKindFuel => 'Rifornimenti';

  @override
  String get csvKindCost => 'Costi';

  @override
  String get csvKindService => 'Interventi';

  @override
  String get csvKindOdometer => 'Letture del contachilometri';

  @override
  String get csvKindTrip => 'Viaggi';

  @override
  String get csvKindIncome => 'Entrate';

  @override
  String get csvWhichVehicle => 'Quale veicolo';

  @override
  String get csvColumns => 'Colonne';

  @override
  String get csvColumnNone => 'Non presente in questo file';

  @override
  String get csvRequired => 'obbligatorio';

  @override
  String get csvDayFirst => 'Le date iniziano dal giorno (31/12)';

  @override
  String get csvMiles => 'Le distanze sono in miglia';

  @override
  String get csvGallons => 'I volumi sono in galloni';

  @override
  String get csvPreview => 'Anteprima';

  @override
  String csvReadyToImport(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count righe pronte',
      one: '1 riga pronta',
      zero: 'Niente da importare',
    );
    return '$_temp0';
  }

  @override
  String csvSkippedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count righe verranno saltate',
      one: '1 riga verrà saltata',
    );
    return '$_temp0';
  }

  @override
  String csvMissingColumn(String field) {
    return 'Scegli una colonna per $field';
  }

  @override
  String csvRowProblem(int line, String field) {
    return 'Riga $line: non è stato possibile leggere $field';
  }

  @override
  String get csvImportAction => 'Importa';

  @override
  String csvImported(int written, int skipped) {
    return 'Importate: $written. Già presenti: $skipped.';
  }

  @override
  String get csvFieldDate => 'Data';

  @override
  String get csvFieldOdometer => 'Contachilometri';

  @override
  String get csvFieldVolume => 'Volume';

  @override
  String get csvFieldPricePerUnit => 'Prezzo unitario';

  @override
  String get csvFieldTotal => 'Totale';

  @override
  String get csvFieldFullTank => 'Pieno';

  @override
  String get csvFieldStation => 'Distributore';

  @override
  String get csvFieldNotes => 'Note';

  @override
  String get csvFieldAmount => 'Importo';

  @override
  String get csvFieldCategory => 'Categoria';

  @override
  String get csvFieldType => 'Tipo';

  @override
  String get csvFieldCost => 'Costo';

  @override
  String get csvFieldShop => 'Officina';

  @override
  String get csvFieldDistance => 'Distanza';

  @override
  String get csvFieldTitle => 'Titolo';

  @override
  String get csvFieldFrom => 'Da';

  @override
  String get csvFieldTo => 'A';

  @override
  String get csvFieldBusiness => 'Viaggio di lavoro';

  @override
  String get csvFieldMinutes => 'Minuti';

  @override
  String get settingsImportCsv => 'Importa un CSV (da qualsiasi app)';

  @override
  String get settingsAutoBackup => 'Backup automatico';

  @override
  String get settingsAutoBackupOff =>
      'Disattivato: scegli una cartella in cui salvare un backup al giorno';

  @override
  String settingsAutoBackupOn(String when) {
    return 'Una volta al giorno, ultimo backup $when';
  }

  @override
  String get settingsAutoBackupJustRan => 'Backup eseguito automaticamente';

  @override
  String get settingsAutoBackupNever =>
      'Una volta al giorno, non ancora eseguito';

  @override
  String get settingsAutoBackupStop => 'Interrompi i backup';

  @override
  String get settingsExportHint =>
      'Uno zip di fogli di calcolo, un file per ogni auto e per ogni tipo. Leggibile ovunque; per ripristinare usa un backup.';

  @override
  String get settingsImportCsvHint =>
      'Da Drivvo, da un foglio di calcolo o da qualsiasi altra cosa esporti una tabella. Aggiunge quello che manca; non viene sovrascritto niente.';

  @override
  String get settingsBackup => 'Fai un backup di tutto';

  @override
  String get settingsBackupHint =>
      'Un file che si può ripristinare, a differenza dell\'esportazione CSV';

  @override
  String get settingsRestore => 'Ripristina da un backup';

  @override
  String get settingsRestoreHint =>
      'Aggiunge quello che manca. Non viene eliminato né sovrascritto niente.';

  @override
  String settingsBackupDone(String file) {
    return 'Backup salvato: $file';
  }

  @override
  String settingsRestoreDone(int vehicles, int written, int skipped) {
    return 'Veicoli: $vehicles. Voci aggiunte: $written. Già presenti: $skipped.';
  }

  @override
  String get settingsRestoreNotABackup =>
      'Quel file non è un backup di Garage.';

  @override
  String get stationsPickNearest => 'Più vicino';

  @override
  String get stationsPickCheapest => 'Più economico';

  @override
  String get stationsPickBestValue => 'Miglior compromesso';

  @override
  String get stationsBestValueHint =>
      'Il più conveniente una volta pagato il carburante per andare e tornare';

  @override
  String stationsGradeStations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count distributori',
      one: '1 distributore',
    );
    return '$_temp0';
  }

  @override
  String get commonClose => 'Chiudi';

  @override
  String get householdInviteCopyManually =>
      'Copia questo messaggio e invialo come preferisci.';

  @override
  String get commonClear => 'Cancella';

  @override
  String get commonNext => 'Avanti';

  @override
  String get commonPrevious => 'Indietro';

  @override
  String get commonIncrease => 'Aumenta';

  @override
  String get commonDecrease => 'Diminuisci';

  @override
  String get commonShowPassword => 'Mostra la password';

  @override
  String get commonHidePassword => 'Nascondi la password';

  @override
  String get householdRename => 'Rinomina il garage';

  @override
  String get householdRenamed => 'Garage rinominato';

  @override
  String get householdRenameAdminOnly =>
      'Solo un amministratore può rinominare il garage';

  @override
  String get householdDelete => 'Elimina il garage';

  @override
  String get householdDeleteTitle => 'Vuoi eliminare questo garage?';

  @override
  String get householdDeleteBody =>
      'Questo chiude il garage per tutti i suoi membri, non solo per te. Ogni veicolo, voce e promemoria se ne va con lui.';

  @override
  String get maintenanceLogServiceHint => 'Qualcosa che è stato fatto';

  @override
  String get maintenanceAddRuleHint => 'Qualcosa che tornerà a scadere';

  @override
  String get quickAddInterval => 'Aggiungi un promemoria';

  @override
  String get settingsMore => 'Altro';

  @override
  String get settingsPreferencesHint =>
      'Unità di misura, valuta, tema e lingua';

  @override
  String get settingsDataHint => 'Importazione, esportazione e backup';

  @override
  String get timelineSearch => 'Cerca nello storico';

  @override
  String get timelineNoMatches => 'Nessun risultato.';

  @override
  String get timelineSearchCovers =>
      'La ricerca copre il tipo di voce, l\'auto, chi l\'ha registrata, la data e le note.';

  @override
  String get timelineFilterVehicle => 'Veicolo';

  @override
  String timelineBalanceNet(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimenti, saldo $amount',
      one: '$count movimento, saldo $amount',
    );
    return '$_temp0';
  }

  @override
  String timelineBalanceSpent(String amount, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimenti, spesi $amount',
      one: '$count movimento, spesi $amount',
    );
    return '$_temp0';
  }

  @override
  String timelineBalanceReceived(String amount, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movimenti, incassati $amount',
      one: '$count movimento, incassati $amount',
    );
    return '$_temp0';
  }

  @override
  String get serviceBrakeDiscsFront => 'Dischi freno anteriori';

  @override
  String get serviceBrakeDiscsRear => 'Dischi freno posteriori';

  @override
  String get serviceBrakeDrumsRear => 'Tamburi freno posteriori';

  @override
  String get serviceGlowPlugs => 'Candelette';

  @override
  String get serviceDpf => 'Filtro antiparticolato';

  @override
  String get serviceAdblue => 'Rabbocco di AdBlue';

  @override
  String get serviceFuelFilter => 'Filtro del carburante';

  @override
  String get serviceClutch => 'Frizione';

  @override
  String get serviceDifferentialOil => 'Olio del differenziale';

  @override
  String get serviceSerpentineBelt => 'Cinghia dei servizi';

  @override
  String get serviceWaterPump => 'Pompa dell\'acqua';

  @override
  String get serviceShockAbsorbers => 'Ammortizzatori';

  @override
  String get serviceWheelAlignment => 'Assetto ruote';

  @override
  String get serviceAcService => 'Manutenzione del climatizzatore';

  @override
  String get serviceBulbs => 'Lampadine';

  @override
  String get serviceChainLube => 'Lubrificazione e registrazione della catena';

  @override
  String get serviceChainSprockets => 'Catena, pignone e corona';

  @override
  String get serviceForkOil => 'Olio della forcella';

  @override
  String get serviceValveClearance => 'Gioco valvole';

  @override
  String attachmentTooLarge(String size, String limit) {
    return 'Quel file pesa $size e il limite è $limit. Prova con una foto più piccola, o con un PDF.';
  }

  @override
  String get authConfirmChecking => 'Conferma dell\'email in corso…';

  @override
  String get authConfirmFailedTitle => 'Quel link non ha funzionato';

  @override
  String get authConfirmFailedBody =>
      'I link di conferma si possono usare una sola volta e hanno una scadenza. Chiedine uno nuovo accedendo, oppure registrati di nuovo.';

  @override
  String get authConfirmNoLink => 'Qui non c\'è niente da confermare.';

  @override
  String get authConfirmSignIn => 'Vai all\'accesso';

  @override
  String get timelineHasNote => 'Ha una nota';

  @override
  String get timelineHasAttachment => 'Ha un allegato';

  @override
  String get timelineFilter => 'Filtra per tipo';

  @override
  String get timelineFilterClear => 'Rimuovi i filtri';

  @override
  String get settingsYourName => 'Il tuo nome';

  @override
  String get settingsNameChanged => 'Nome aggiornato';

  @override
  String get settingsSettlement => 'Spese condivise';

  @override
  String get settingsSettlementHint =>
      'Divide in parti uguali tra i membri tutto quello che viene registrato e calcola chi deve quanto a chi. Utile quando condividete un\'auto ma tenete i conti separati.';

  @override
  String get settingsSettlementEnable => 'Calcola chi deve quanto a chi';

  @override
  String tyreWindowFixed(String from, String to) {
    return 'Pneumatici invernali dal $from al $to, qualunque sia il tempo';
  }

  @override
  String tyreWindowWhenWintry(String from, String to) {
    return 'Pneumatici invernali dal $from al $to, quando le strade sono in condizioni invernali';
  }

  @override
  String get tyreWindowSituational =>
      'Nessuna data fissa: pneumatici invernali ogni volta che le strade sono in condizioni invernali';

  @override
  String get notificationSwapToWinter => 'Monta gli pneumatici invernali';

  @override
  String get notificationSwapToSummer => 'Si torna agli pneumatici estivi';

  @override
  String get guestLendTitle => 'Presta quest\'auto';

  @override
  String get guestLendIntro =>
      'Dai un codice a qualcuno e potrà registrare su quest\'auto, e su nient\'altro, finché il codice non scade. Non entra nel tuo garage. Vede sempre i dati dell\'auto, il contachilometri, le scadenze dei documenti, i problemi aperti e le gomme; il resto di quello che hai registrato resta nascosto finché non lo consenti.';

  @override
  String get guestLendLabel => 'Per chi è';

  @override
  String get guestLendLabelHint =>
      'Serve solo a te come riferimento: chi riceve il codice non lo vede.';

  @override
  String get guestLendAllowFuel => 'Registrare rifornimenti';

  @override
  String get guestLendAllowTrips => 'Registrare viaggi';

  @override
  String get guestLendAllowCosts => 'Registrare costi e interventi';

  @override
  String get guestLendAllowHistory =>
      'Vedere lo storico precedente di quest\'auto';

  @override
  String get guestLendAllowHistoryHint =>
      'Disattivato di serie: vede solo quello che ha registrato lui.';

  @override
  String get guestLendAction => 'Crea un codice';

  @override
  String get guestLendCreated => 'Consegna questo codice';

  @override
  String get guestLendCopy => 'Copia il codice';

  @override
  String get guestLendCopied => 'Codice copiato';

  @override
  String get guestPassesTitle => 'Prestiti';

  @override
  String get guestPassesEmpty => 'Quest\'auto non è mai stata prestata.';

  @override
  String get guestPassesLive => 'In uso';

  @override
  String get guestPassesWaiting => 'Non ancora riscattato';

  @override
  String get guestPassesNotStarted => 'Inizia più avanti';

  @override
  String get guestPassesExpired => 'Concluso';

  @override
  String get guestPassesRevoked => 'Ritirato';

  @override
  String guestPassRemaining(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Restano $days giorni',
      one: 'Resta $days giorno',
    );
    return '$_temp0';
  }

  @override
  String get guestPassEndsToday => 'Finisce oggi';

  @override
  String get guestPassRevoke => 'Ritira';

  @override
  String get guestPassRevokeConfirm =>
      'Vuoi ritirare questo codice? L\'accesso si chiude subito. Tutto quello che ha registrato resta.';

  @override
  String get guestRedeemFailed =>
      'Quel codice non funziona. Potrebbe essere scaduto, ritirato oppure già in uso.';

  @override
  String get guestBorrowedBadge => 'Prestata a te';

  @override
  String guestBorrowedUntil(String date) {
    return 'Tua fino al $date';
  }

  @override
  String get guestHistoryHidden =>
      'Vedi solo quello che hai registrato tu. Le voci precedenti del proprietario restano private.';

  @override
  String get householdMakeAdmin => 'Rendi amministratore';

  @override
  String get householdRemoveAdmin => 'Togli i permessi di amministratore';

  @override
  String householdRoleChanged(String name) {
    return '$name è ora amministratore';
  }

  @override
  String householdRoleRemoved(String name) {
    return '$name non è più amministratore';
  }

  @override
  String householdLastAdminKept(String name) {
    return 'Un garage ha sempre un amministratore, quindi il ruolo è passato a $name.';
  }

  @override
  String get householdStepDownTitle =>
      'Vuoi lasciare il ruolo di amministratore?';

  @override
  String householdStepDownBody(String name) {
    return 'Sei l\'unico amministratore, quindi il ruolo passa a $name. Solo un amministratore potrà ridartelo.';
  }

  @override
  String get householdStepDown => 'Lascia il ruolo';

  @override
  String householdLeaveConfirmSuccessor(String name) {
    return 'Vuoi uscire da questo garage? Perderai l\'accesso ai suoi veicoli e $name ne diventerà l\'amministratore.';
  }

  @override
  String get householdMergeTitle => 'Unisci un altro garage a questo';

  @override
  String get householdMergeIntro =>
      'Ogni veicolo, tutto il suo storico e tutte le persone dell\'altro garage si spostano qui. L\'altro garage viene poi eliminato. Non si può annullare.';

  @override
  String get householdMergeNone =>
      'Non sei amministratore di nessun altro garage.';

  @override
  String get householdMergePick => 'Quale garage deve spostarsi qui?';

  @override
  String get householdMergeAction => 'Unisci a questo garage';

  @override
  String householdMergeConfirm(
    String name,
    String survivor,
    String vehicles,
    String people,
  ) {
    return 'Vuoi spostare tutto da $name a $survivor? Arrivano $vehicles e $people, $name viene eliminato e non si può annullare.';
  }

  @override
  String householdMergeVehicleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veicoli',
      one: '1 veicolo',
      zero: 'nessun veicolo',
    );
    return '$_temp0';
  }

  @override
  String householdMergePeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persone',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get householdMergeKeysWarning =>
      'Le chiavi API e i webhook che appartengono all\'altro garage smettono di funzionare.';

  @override
  String householdMergeDone(String vehicles) {
    return 'Unione completata. Veicoli trasferiti: $vehicles.';
  }

  @override
  String householdMergePhotosLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Non è stato possibile spostare $count foto di veicoli.',
      one: 'Non è stato possibile spostare una foto di un veicolo.',
    );
    return '$_temp0';
  }

  @override
  String householdMergeCurrencyClash(String absorbed, String surviving) {
    return 'Questi garage tengono i conti in valute diverse ($absorbed e $surviving). Cambiane una perché coincidano prima di unirli, altrimenti ogni importo cambierebbe significato.';
  }

  @override
  String get syncPendingTitle => 'In attesa di invio';

  @override
  String syncPendingBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci sono in attesa di essere inviate',
      one: '1 voce è in attesa di essere inviata',
    );
    return '$_temp0';
  }

  @override
  String get syncPendingIntro =>
      'Sono state salvate sul telefono quando non c\'era connessione. Verranno inviate da sole alla prossima occasione.';

  @override
  String get syncPendingEmpty => 'È stato inviato tutto.';

  @override
  String syncStaleBanner(String when) {
    return 'Offline. Ecco com\'era $when.';
  }

  @override
  String get syncRetryNow => 'Prova adesso';

  @override
  String get syncEntryQueued =>
      'Salvato sul telefono. Verrà sincronizzato quando avrai segnale.';

  @override
  String syncSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci sincronizzate',
      one: '1 voce sincronizzata',
    );
    return '$_temp0';
  }

  @override
  String get syncStillWaiting =>
      'Ancora nessuna connessione. Non è andato perso niente.';

  @override
  String syncDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci non sono state salvate e sono state rimosse',
      one: '1 voce non è stata salvata ed è stata rimossa',
    );
    return '$_temp0';
  }

  @override
  String get syncKindFuel => 'Rifornimento';

  @override
  String get syncKindOdometer => 'Lettura del contachilometri';

  @override
  String syncQueuedAt(String when) {
    return 'Scritto $when';
  }

  @override
  String get syncPhotoQueued =>
      'Foto salvata sul telefono. Verrà caricata quando avrai segnale.';

  @override
  String get syncKindAttachment => 'Foto';

  @override
  String get syncKindTrip => 'Viaggio';

  @override
  String get syncKindCost => 'Spesa';

  @override
  String get syncKindService => 'Intervento';

  @override
  String get syncKindObservation => 'Annotazione';

  @override
  String get observationsTitle => 'Problemi';

  @override
  String get observationsHint =>
      'Qualcosa che hai notato e non hai ancora sistemato. È un appunto per te e per chi metterà mano all\'auto la prossima volta.';

  @override
  String get observationsEmpty =>
      'Niente da segnalare. Qualsiasi cosa strana (un rumore, una spia accesa, un ticchettio comparso dopo una buca) va qui.';

  @override
  String get observationAdd => 'Segnala un problema';

  @override
  String get observationEdit => 'Modifica';

  @override
  String get observationNote => 'Che cosa hai notato';

  @override
  String get observationNoteHint => 'Rumore davanti a motore freddo';

  @override
  String get observationNoticedOn => 'Quando l\'hai notato';

  @override
  String get observationOdometer => 'Contachilometri';

  @override
  String get observationOpen => 'Non risolto';

  @override
  String get observationStillThere => 'Ancora presente dopo l\'intervento';

  @override
  String get observationResolved => 'Risolto';

  @override
  String observationOpenFor(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: '1 giorno',
      zero: 'notato oggi',
    );
    return '$_temp0';
  }

  @override
  String get observationMarkResolved => 'È passato';

  @override
  String get observationReopen => 'È tornato';

  @override
  String get observationDelete => 'Elimina';

  @override
  String get observationDeleteConfirm =>
      'Vuoi eliminare questo appunto? Se ne va anche la traccia di averlo notato.';

  @override
  String get observationSaved => 'Annotato';

  @override
  String observationResolvedOn(String date) {
    return 'Passato il $date';
  }

  @override
  String get observationAddressedNotResolved =>
      'È stato fatto un intervento e non hai detto che è passato.';

  @override
  String get observationOnTrip => 'Notato durante un viaggio';

  @override
  String get tripDriveNoteSomething => 'Annota qualcosa';

  @override
  String get tripPrepTitle => 'Prima di un viaggio lungo';

  @override
  String get tripPrepIntro =>
      'Che cosa scade durante il viaggio, secondo i dati di questo garage. Non è una revisione e non dice niente su gomme, luci o freni.';

  @override
  String get tripPrepDepart => 'Partenza il';

  @override
  String get tripPrepReturn => 'Ritorno il';

  @override
  String get tripPrepReturnNone => 'Non impostato';

  @override
  String get tripPrepDistance => 'Più o meno quanta strada';

  @override
  String get tripPrepCheck => 'Controlla il viaggio';

  @override
  String get tripPrepDeadlines => 'Scade mentre sei via';

  @override
  String get tripPrepForecast => 'Previsto in scadenza';

  @override
  String get tripPrepForecastNote =>
      'Proiettato dal modo in cui quest\'auto è stata guidata ultimamente, non è una data scritta da qualcuno.';

  @override
  String tripPrepKmAway(String distance) {
    return 'tra circa $distance';
  }

  @override
  String get tripPrepAlreadyPast => 'già scaduto';

  @override
  String get tripPrepNothing =>
      'Nei tuoi dati non c\'è niente che scada durante questo viaggio.';

  @override
  String get tripPrepNoOdometer =>
      'Nessuna lettura recente del contachilometri, quindi non è stato possibile misurare niente sulla distanza. Registrane una e riprova.';

  @override
  String get tripPrepOwnList => 'La tua lista';

  @override
  String get tripPrepOwnListHint =>
      'Le cose che vuoi ricordarti. Restano su questo dispositivo.';

  @override
  String get tripPrepAddItem => 'Aggiungi qualcosa';

  @override
  String tripPrepExpiresOn(String date) {
    return 'scade il $date';
  }

  @override
  String get reportHandover => 'Per il meccanico';

  @override
  String get reportHandoverHint =>
      'Che cosa non va, che cosa sta per scadere e che cosa è stato fatto di recente';

  @override
  String get reportHandoverProblems => 'Che cosa ha notato chi guida';

  @override
  String get reportHandoverStillThere =>
      'È stato fatto un intervento e non è passato';

  @override
  String get reportHandoverComing => 'In arrivo';

  @override
  String get reportHandoverRecent => 'Interventi recenti';

  @override
  String get reportHandoverNoProblems => 'Non è stato segnalato niente.';

  @override
  String reportHandoverNoticedOn(String date) {
    return 'notato il $date';
  }

  @override
  String get reportHandoverFooter =>
      'Compilato dai dati registrati dal proprietario. Non è un\'ispezione e non attesta le condizioni del veicolo.';

  @override
  String get routeLabel => 'Percorso';

  @override
  String get routeNoneOption => 'Nessun percorso';

  @override
  String get routeNewOption => 'Nuovo percorso…';

  @override
  String get routeNameLabel => 'Dai un nome a questo viaggio';

  @override
  String get routeNameHint => 'Casa → Lavoro';

  @override
  String get routeSaveFailed =>
      'Non è stato possibile salvare il percorso, quindi il viaggio non è iniziato.';

  @override
  String get tripNotComparable => 'Non è un viaggio normale';

  @override
  String get tripNotComparableHint =>
      'Una deviazione, una commissione lungo la strada, una strada chiusa. Viene comunque registrato: resta solo fuori dall\'andamento del percorso.';

  @override
  String get routeTrendsTitle => 'Percorsi';

  @override
  String get routeTrendsSubtitle =>
      'Quanto ci vuole davvero per un viaggio che fai spesso';

  @override
  String get routeTrendsEmpty =>
      'Ancora nessun percorso. Dai un nome a uno quando inizi un viaggio, e i viaggi cominceranno a confrontarsi da soli.';

  @override
  String get routeTrendNoTimed =>
      'Su questo percorso non è ancora stato cronometrato niente. Un viaggio iniziato e concluso nell\'app registra i propri minuti.';

  @override
  String routeTrendTypical(String duration) {
    return 'Di solito $duration';
  }

  @override
  String routeTrendSpread(String low, String high) {
    return 'Metà centrale da $low a $high min';
  }

  @override
  String routeTrendSlower(String minutes, String label) {
    return '$minutes min più lento rispetto a $label';
  }

  @override
  String routeTrendFaster(String minutes, String label) {
    return '$minutes min più veloce rispetto a $label';
  }

  @override
  String routeTrendUnchanged(String label) {
    return 'Nessun cambiamento rispetto a $label';
  }

  @override
  String routeTrendSample(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viaggi',
      one: '$count viaggio',
    );
    return '$_temp0';
  }

  @override
  String get routeTrendSparse =>
      'Alcuni periodi si basano su pochissimi viaggi, quindi la differenza potrebbe essere solo rumore.';

  @override
  String get routeTrendCaveat =>
      'Questo riporta che cosa dicono i tuoi dati, non il perché. Un orario di partenza, una strada o un conducente diversi sembrano esattamente traffico.';

  @override
  String get routeTrendGroupMonth => 'Per mese';

  @override
  String get routeTrendGroupQuarter => 'Per trimestre';

  @override
  String get routeTrendWeekdays => 'Solo giorni feriali';

  @override
  String get routeTrendDeparture => 'Partenza';

  @override
  String get routeTrendDepartureAny => 'A qualsiasi ora';

  @override
  String get routeTrendDepartureMorning => 'Mattina';

  @override
  String get routeTrendDepartureMidday => 'Metà giornata';

  @override
  String get routeTrendDepartureEvening => 'Sera';

  @override
  String get routeTrendDriver => 'Conducente';

  @override
  String get routeTrendDriverAnyone => 'Chiunque';

  @override
  String routeTrendExcluded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viaggi esclusi perché non erano viaggi normali',
      one: '$count viaggio escluso perché non era un viaggio normale',
    );
    return '$_temp0';
  }

  @override
  String routeTrendNoStartTime(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count viaggi non hanno un orario di partenza, quindi il filtro sulla partenza non riesce a collocarli',
      one:
          '$count viaggio non ha un orario di partenza, quindi il filtro sulla partenza non riesce a collocarlo',
    );
    return '$_temp0';
  }

  @override
  String get routeRename => 'Rinomina il percorso';

  @override
  String get routeDelete => 'Elimina il percorso';

  @override
  String get routeDeleteConfirm =>
      'Vuoi eliminare questo percorso? I viaggi restano: semplicemente smettono di essere archiviati sotto di esso.';

  @override
  String routeTrendExcludedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e altri $count',
      one: 'e un altro',
    );
    return '$_temp0';
  }

  @override
  String routeTrendExcludedRun(String date, String minutes) {
    return '$date · $minutes min';
  }

  @override
  String get reportMileageTrail => 'Chilometraggio registrato';

  @override
  String get reportMileageYear => 'Anno';

  @override
  String get reportMileageReading => 'Lettura';

  @override
  String get reportMileageDriven => 'Percorrenza';

  @override
  String get reportMileageRecords => 'Registrazioni';

  @override
  String get reportMileagePartialNote =>
      '* Le registrazioni iniziano nel corso di quest\'anno, quindi copre meno di un anno intero.';

  @override
  String get reportMileageGapNote =>
      '† Misurato dall\'ultima lettura precedente a un anno senza registrazioni.';

  @override
  String get reportSellersFooter =>
      'Compilato dai dati registrati dal proprietario in questa app. Non è una dichiarazione ufficiale di chilometraggio e non può mostrare niente che sia avvenuto al di fuori dell\'app.';

  @override
  String get featureRoutes => 'Percorsi';

  @override
  String get featureRoutesBlurb =>
      'Dai un nome a un viaggio che fai spesso e scopri quanto ci vuole di solito, con la variabilità intorno e quanti viaggi stanno dietro a ogni dato.';

  @override
  String get featureObservations => 'Quello che hai notato';

  @override
  String get featureObservationsBlurb =>
      'Un rumore, una spia accesa, una macchia sotto l\'auto, con una foto. Resta aperto finché il problema non passa, e il foglio che consegni al meccanico si apre proprio con questo.';

  @override
  String get featureTripCheck => 'Prima di un viaggio lungo';

  @override
  String get featureTripCheckBlurb =>
      'Che cosa scade durante il viaggio, secondo le date nei tuoi dati. Non è una revisione.';

  @override
  String get featureOffline => 'Funziona senza segnale';

  @override
  String get featureOfflineBlurb =>
      'Un rifornimento scritto alla pompa resta sul telefono e viene inviato quando c\'è connessione. Altro → In attesa di invio elenca quello che aspetta ancora.';

  @override
  String get guestLendFrom => 'Dal';

  @override
  String get guestLendUntil => 'Al';

  @override
  String get guestLendWindowBackwards => 'La fine deve venire dopo l\'inizio.';

  @override
  String get guestLendStartsToday => 'Oggi';

  @override
  String get guestLendAllowPrices => 'Mostra quanto è costato il lavoro';

  @override
  String get guestLendAllowPricesHint =>
      'Disattivato: il meccanico vede che cosa è stato fatto e quando, non quanto hai pagato.';

  @override
  String get guestPassExtend => 'Prolunga';

  @override
  String get guestPassExtendTitle => 'Fino a quando?';

  @override
  String guestPassExtended(String date) {
    return 'Prolungato fino al $date';
  }

  @override
  String guestPassWindow(String from, String to) {
    return 'Dal $from al $to';
  }

  @override
  String get lentHistoryTitle => 'Che cosa è stato fatto';

  @override
  String get lentHistoryEmpty =>
      'Per quest\'auto non è stato registrato niente.';

  @override
  String get lentHistoryPricesHidden =>
      'Il proprietario non ha condiviso quanto è costato il lavoro.';

  @override
  String odometerJumpWarning(String distance, String date) {
    return 'Sono $distance dal $date. Controlla la lettura.';
  }

  @override
  String runningCostOwnSpan(String distance, String date) {
    return 'Misurato sui $distance registrati dal $date, l\'unico periodo per cui l\'app ha letture.';
  }

  @override
  String get partsTitle => 'Che cosa vuole quest\'auto';

  @override
  String get partsHint =>
      'I numeri che cerchi prima di ogni lavoro: viscosità dell\'olio, codice del filtro, lampadina, lunghezza delle spazzole. Scritti una volta, restano per sempre.';

  @override
  String get partsEmpty =>
      'Ancora niente. La prossima volta che ne cerchi uno, scrivilo qui.';

  @override
  String get partsAdd => 'Aggiungi che cosa vuole';

  @override
  String get partsEdit => 'Modifica';

  @override
  String get partsJob => 'Per quale lavoro';

  @override
  String get partsSpec => 'Che cosa vuole';

  @override
  String get partsSpecHint =>
      '5W-30 ACEA C3, W 712/95, H7 55W, 600 mm / 400 mm';

  @override
  String get partsSpecRequired => 'Indica che cosa vuole.';

  @override
  String get partsNotes => 'Note';

  @override
  String get partsDelete => 'Elimina';

  @override
  String get partsDeleteConfirm =>
      'Vuoi eliminare che cosa vuole quest\'auto per quel lavoro?';

  @override
  String partsOnService(String spec) {
    return 'Quest\'auto vuole $spec';
  }

  @override
  String partsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lavori registrati',
      one: '1 lavoro registrato',
    );
    return '$_temp0';
  }

  @override
  String get briefingOdometer => 'Contachilometri';

  @override
  String get briefingPapers => 'Documenti a bordo';

  @override
  String get briefingProblems => 'Da sapere';

  @override
  String get briefingTyres => 'Pneumatici';

  @override
  String briefingNoticedOn(String date) {
    return 'notato il $date';
  }

  @override
  String briefingTyresFitted(String date) {
    return 'montati il $date';
  }

  @override
  String get briefingNothing =>
      'Il proprietario non ha ancora registrato niente su quest\'auto.';

  @override
  String get codeBoxAction => 'Ho un codice';

  @override
  String get codeBoxTitle => 'Inserisci il codice che ti hanno dato';

  @override
  String get codeBoxUnknown =>
      'Nessun codice del genere. Controllalo e riprova.';

  @override
  String get codeBoxSpent => 'Quel codice è già stato usato oppure è scaduto.';

  @override
  String codeBoxLending(String vehicle, String date) {
    return 'Ti prestano $vehicle fino al $date.';
  }

  @override
  String codeBoxTransfer(String vehicle) {
    return '$vehicle diventerebbe tua, con tutto il suo storico. Da qui non si può annullare.';
  }

  @override
  String codeBoxInvite(String subject) {
    return 'Entreresti nel garage $subject e ne condivideresti i veicoli.';
  }

  @override
  String get codeBoxUse => 'Usa il codice';

  @override
  String get passEdit => 'Cambia che cosa permette';

  @override
  String get passEditNote =>
      'Le modifiche valgono subito, sul codice che hanno già.';

  @override
  String passFinished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conclusi',
      one: '1 concluso',
    );
    return '$_temp0';
  }

  @override
  String get guestPassesReturned => 'Restituita';

  @override
  String get guestReturn => 'Restituisci l\'auto';

  @override
  String get guestReturnConfirm =>
      'Vuoi restituire quest\'auto? Il tuo accesso finisce adesso. Tutto quello che hai registrato resta con l\'auto.';

  @override
  String get guestReturned => 'Restituita. Grazie per la guida.';

  @override
  String get csvCarScannerFound => 'Registrazione di Car Scanner';

  @override
  String csvCarScannerDrive(String distance, int minutes, String date) {
    return '$distance in $minutes min, $date';
  }

  @override
  String csvCarScannerDriveMinutes(int minutes) {
    return '$minutes min registrati';
  }

  @override
  String csvCarScannerFuel(String litres, String rate) {
    return 'Consumati $litres, $rate';
  }

  @override
  String get csvCarScannerParked =>
      'Questa registrazione non si è mossa. È lo scanner lasciato acceso in un\'auto ferma, non un viaggio.';

  @override
  String get csvCarScannerNoDistance =>
      'In questa registrazione non c\'è la distanza. Inserisci quanto è stato lungo il viaggio.';

  @override
  String get csvCarScannerNoDate =>
      'Il nome del file non dice quando è avvenuto il viaggio, quindi la data va inserita.';

  @override
  String get csvCarScannerPickDate => 'Scegli una data';

  @override
  String get csvCarScannerImport => 'Importa come viaggio';

  @override
  String get csvCarScannerImported => 'Viaggio importato.';
}
