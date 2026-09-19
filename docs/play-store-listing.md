# Garage — Play Store listing

Everything needed for the Play Console submission. Copy is pre-trimmed to Play's
character limits (noted inline). Keep the **Data Safety** answers consistent with
`PRIVACY.md` — a mismatch is a common rejection reason.

- **App name:** Garage
- **Package name:** `cc.hrva.garage`
- **Category:** Auto & Vehicles
- **Content rating:** Everyone (no objectionable content)
- **Price:** Free — no ads, no in-app purchases
  _True today, since no billing exists. Decision 155 leaves room for a paid
  tier for bigger garages; when one ships, this line, the Data safety form and
  `PRIVACY.md` change together._
- **Support email:** garage@hrva.cc
- **Privacy policy URL:** https://garage.hrva.cc/privacy

## Store title (max 30 chars)

- **English:** `Garage: Fuel & Maintenance`  _(26)_
- **Hrvatski:** `Garaža: gorivo i servis`  _(23)_
- **Italiano:** `Garage: auto e manutenzione`  _(27)_

## Short description (max 80 chars)

- **English:** `Log fuel, track maintenance, and share your garage with your household.`  _(74)_
- **Hrvatski:** `Bilježi gorivo, prati servise i dijeli garažu s kućanstvom.`  _(59)_
- **Italiano:** `Registra i rifornimenti, segui la manutenzione, condividi il garage di casa.`  _(76)_

## Full description (max 4000 chars)

> **Rewritten 17 September 2026, for the production launch.** All three now
> carry drives and routes, problems and the mechanic's sheet, the trip check,
> lending, and working without a signal, and every sentence was checked against
> the code rather than against the previous listing. Room was made by merging:
> the planner into bundling, make-aware reminders into maintenance, the + button
> into the fuel log, who-paid-what into sharing, receipts into statistics, the
> transfer code into import, and electric, dual-fuel, motorcycles and tyres into
> one section. **Two things were cut outright:** income and belonging to several
> garages. Both are true, and nobody picks a fuel log for either (decision 158).
>
> **Two claims were wrong and are fixed.** Location was "used on the fuel
> stations screen only"; the fill-up sheet reads it too, as `PRIVACY.md` already
> said. And Croatian still addressed the reader as *vi* after the app moved to
> *ti* (decision 153), with *tankiranje*, *kućanstvo* and *nadzorna ploča* where
> the app says *točenje*, *garaža* and *Pregled*.
>
> Room left of Play's 4000: English 56, Croatian 99, Italian 34
> (`test/ci/deploy_workflow_test.dart` enforces the cap). Italian runs longest,
> so a sentence added to all three has to fit there first.

### English

```
Garage keeps your household's vehicles in order — without the spreadsheet.

FUEL LOG
Record every fill-up and see real fuel economy, calculated properly between
full tanks rather than guessed. Missed logging a fill? Mark it, and Garage skips
that stretch instead of showing a wrong figure. Log one from the + button, a
home-screen widget or the app icon.

WHAT THE CAR ACTUALLY COSTS
Per kilometre, per month, and per year, split into fuel and upkeep — with a
breakdown of where the money went. Say what the car is worth today and it also
shows what it costs to own, not only to run.

MAINTENANCE THAT KNOWS WHEN
Set service intervals by distance, by time, or both. Garage projects when each
item is actually due from how much you really drive — so a car that sits all
winter isn't nagged like one doing a daily motorway commute. A new reminder
starts from what your make and engine typically need.

ONE VISIT INSTEAD OF THREE
When several jobs fall due together, Garage suggests one shop visit. A 12-week
runway and a month calendar show what's coming.

PAPERWORK THAT DOES NOT LAPSE
Record when the registration, the roadworthiness test, the insurance and the
green card run out, keep a photo of each, and be told a month before one does —
beside the servicing, in the same planner.

ONE GARAGE, SHARED
Invite the people you share cars with. Everyone sees the same up-to-date
history, in sync across devices. Every entry records who logged it, and the
garage can show what each member has put in — and what would even it up.

WORKS WITHOUT A SIGNAL
A fill-up, a service or a journey typed with no reception is kept on the phone
and sent when there is a connection.

LEND A CAR
Give somebody a code and they can log fuel and drives on one car for the dates
you choose — without joining your garage or seeing the rest of it.

DRIVES AND ROUTES
Start a drive when you set off and finish it when you park. Name a journey you
make often and see what it usually takes, and whether it really is slower now.
No GPS: a drive is a start time and two odometer readings.

PROBLEMS, WRITTEN DOWN
A rattle, a warning light, a puddle under the car, with a photo. It stays open
until the problem actually stops, and the sheet you hand the mechanic leads with
what was already tried. Before a long drive, see what falls due on the way.

TRIP LOG FOR TAX
Record where a journey went, how far, who drove and whether it was private or
business — then print a month as a logbook with the business split and a line
to sign.

FUEL PRICES AT THE PUMP (CROATIA)
Current prices from the Ministry of Economy's open data, nearest first — and
which station is cheapest once the fuel to drive there and back is paid for.

EVERY KIND OF VEHICLE
An electric car logs charges in kWh. A car on petrol and LPG gets a consumption
figure for each. A motorcycle gets chain, sprockets and fork oil instead of a
cabin filter. Tyre sets keep their season, age and tread depth.

RECEIPTS AND STATISTICS
Attach the pump receipt or the shop invoice to its own entry. Pick any period
and see spend by kind, by category and by station, the odometer over time, and
how far a full tank really goes.

BRING YOUR HISTORY, HAND IT ON
Import a Fuelio backup, or a CSV from any app by saying which column is which;
importing twice never doubles it. Selling the car? A seller's report puts its
history in a PDF, and a code moves the car and all of it to the buyer.

YOUR DATA IS YOURS
Export everything as spreadsheets any time, back the whole garage up to a file
you can restore, or read it through the built-in read-only API. Delete your
account from inside the app.

No ads, ever. No trackers. Free for a small garage, and what you have already
logged never goes behind a paywall. Data hosted in the EU. Your location is used
only on your phone, to sort fuel stations by distance and to fill in the station
you are standing at. On Android and in your browser, in English, Croatian and
Italian.
```

### Hrvatski

```
Garaža drži vozila tvog kućanstva u redu, bez Excel tablica.

DNEVNIK TOČENJA
Zabilježi svako točenje i prati stvarnu potrošnju, izračunatu između punih
spremnika, a ne procijenjenu. Jedno točenje nije upisano? Označi to i Garaža
preskače taj dio umjesto da prikaže pogrešan podatak. Točenje bilježiš gumbom +,
widgetom na početnom zaslonu ili dugim pritiskom na ikonu.

KOLIKO AUTO STVARNO STOJI
Po kilometru, mjesečno i godišnje, razdvojeno na gorivo i održavanje, uz pregled
na što je novac otišao. Upiši koliko auto danas vrijedi i vidiš i koliko stoji
imati ga, a ne samo voziti.

ODRŽAVANJE KOJE ZNA KADA
Postavi intervale servisa po kilometrima, po vremenu ili oboje. Garaža procjenjuje
kada što stvarno dospijeva prema tome koliko voziš, pa auto koji zimu provede u
garaži ne opominje kao onaj koji svaki dan ide na autocestu. Novi podsjetnik
kreće od onoga što tvoja marka i motor obično traže.

JEDAN ODLAZAK U SERVIS UMJESTO TRI
Kad više poslova dospijeva zajedno, Garaža predlaže jedan odlazak u servis.
Planer pokazuje sljedećih 12 tjedana, a kalendar cijeli mjesec.

DOKUMENTI KOJI NE ISTEKNU
Zabilježi do kada vrijede registracija, tehnički pregled, osiguranje i zelena
karta, uz svaki spremi fotografiju i dobij podsjetnik mjesec dana ranije, uz
servise, u istom planeru.

JEDNA GARAŽA, ZAJEDNIČKA
Pozovi one s kojima dijeliš aute. Svi vide istu povijest, usklađenu na svim
uređajima. Svaki unos bilježi tko ga je upisao, a garaža može pokazati koliko je
tko uložio i što bi to poravnalo.

RADI I BEZ SIGNALA
Točenje, servis ili putovanje upisano bez signala ostaje na telefonu i šalje se
kad bude veze.

POSUDI AUTO
Daj nekome kod i može bilježiti gorivo i vožnje na jednom autu u danima koje
odabereš, bez ulaska u tvoju garažu i bez uvida u ostalo.

VOŽNJE I RUTE
Započni vožnju kad kreneš i završi je kad parkiraš. Imenuj putovanje koje često
radiš i vidiš koliko obično traje i traje li sada stvarno dulje. Bez GPS-a:
vožnja je vrijeme polaska i dva stanja kilometraže.

PROBLEMI, CRNO NA BIJELO
Zvuk, lampica, lokva ispod auta, uz fotografiju. Ostaje otvoreno dok problem
stvarno ne prestane, a papir koji predaješ serviseru počinje onim što je već
pokušano. Prije duge vožnje vidiš što dolazi na red tijekom puta.

DNEVNIK VOŽNJE ZA POREZ
Zabilježi kamo se išlo, koliko, tko je vozio i je li bilo privatno ili poslovno,
pa ispiši mjesec kao putni nalog, s poslovnim udjelom i mjestom za potpis.

CIJENE GORIVA NA PUMPI (HRVATSKA)
Aktualne cijene iz otvorenih podataka Ministarstva gospodarstva, najbliže prvo,
i koja je postaja najjeftinija kad se uračuna gorivo za put onamo i natrag.

SVAKA VRSTA VOZILA
Električni auto bilježi punjenja u kWh. Auto na benzin i plin dobiva zasebnu
potrošnju za svako gorivo. Motocikl dobiva lanac, lančanike i ulje u vilici
umjesto filtra kabine. Setovi guma pamte sezonu, starost i dubinu profila.

RAČUNI I STATISTIKA
Priloži račun s pumpe ili iz servisa uz sam unos. Odaberi bilo koje razdoblje i
vidiš trošak po vrsti, po kategoriji i po postaji, kilometražu kroz vrijeme i
koliko stvarno prijeđeš s punim spremnikom.

PRENESI POVIJEST, PREDAJ JE DALJE
Uvezi sigurnosnu kopiju iz Fuelija ili CSV iz bilo koje aplikacije tako da kažeš
koji je stupac što; dvostruki uvoz ništa ne udvostručuje. Prodaješ auto?
Izvještaj za prodaju stavlja njegovu povijest u PDF, a kod seli auto i cijelu
povijest kupcu.

TVOJI PODACI SU TVOJI
Izvezi sve kao tablice kad god želiš, napravi sigurnosnu kopiju cijele garaže
koju možeš vratiti ili čitaj podatke kroz ugrađeni API samo za čitanje. Račun
brišeš u samoj aplikaciji.

Oglasa nema i neće ih biti. Bez praćenja. Besplatno za malu garažu, a ono što je
već zabilježeno ostaje dostupno bez plaćanja. Podaci se čuvaju u EU. Lokacija se
koristi samo na tvom telefonu: za sortiranje postaja po udaljenosti i za upis
postaje na kojoj točiš. Na Androidu i u pregledniku, na hrvatskom, engleskom i
talijanskom.
```

### Italiano

```
Garage tiene in ordine i veicoli di casa, senza fogli di calcolo.

REGISTRO DEI RIFORNIMENTI
Registra ogni pieno e segui il consumo reale, calcolato tra un pieno e l'altro e
non stimato. Ne hai saltato uno? Segnalalo e Garage salta quel tratto invece di
mostrare un dato sbagliato. Basta il tasto +, il widget o l'icona dell'app.

QUANTO COSTA DAVVERO L'AUTO
Al chilometro, al mese e all'anno, con carburante e manutenzione separati, e
dove sono finiti i soldi. Scrivi quanto vale oggi e vedrai anche quanto costa
possederla, non solo usarla.

MANUTENZIONE CHE SA QUANDO
Imposta gli intervalli per chilometri, per tempo o entrambi. Garage stima la
scadenza reale in base a quanto guidi davvero, così un'auto ferma tutto l'inverno
non ti assilla come una usata ogni giorno. Un nuovo promemoria parte da quello
che la tua marca e il tuo motore chiedono di solito.

UNA VISITA INVECE DI TRE
Quando più lavori scadono insieme, Garage propone un'unica visita in officina.
Dodici settimane e un calendario mostrano che cosa arriva.

DOCUMENTI CHE NON TI SFUGGONO
Registra fino a quando valgono bollo, revisione, assicurazione e carta verde,
allega la foto e ricevi un avviso un mese prima, nello stesso pianificatore
degli interventi.

UN SOLO GARAGE, CONDIVISO
Invita chi guida le stesse auto. Tutti vedono lo stesso storico, sincronizzato
su ogni dispositivo. Ogni voce registra chi l'ha inserita, e il garage può
mostrare quanto ha messo ciascuno e che cosa pareggerebbe i conti.

FUNZIONA SENZA SEGNALE
Un rifornimento, un intervento o un viaggio scritti senza campo restano sul
telefono e partono appena torna.

PRESTA UN'AUTO
Dai un codice a qualcuno e potrà registrare rifornimenti e viaggi su una sola
auto nei giorni che scegli, senza entrare nel tuo garage né vedere il resto.

VIAGGI E PERCORSI
Inizia un viaggio quando parti e chiudilo quando parcheggi. Dai un nome a un
viaggio che fai spesso e scopri quanto dura di solito, e se adesso dura davvero
di più. Niente GPS: bastano l'ora di partenza e due letture del contachilometri.

PROBLEMI, NERO SU BIANCO
Un rumore, una spia accesa, una macchia sotto l'auto, con una foto. Resta aperto
finché il problema non passa davvero, e il foglio per il meccanico si apre con
quello che è già stato tentato. Prima di un viaggio lungo, vedi che cosa scade
lungo la strada.

REGISTRO DEI VIAGGI
Registra dove, quanto, chi guidava e se era privato o di lavoro. Poi stampa il
mese con la quota di lavoro e una riga da firmare.

PREZZI DEI CARBURANTI (SOLO CROAZIA)
Prezzi dai dati aperti del ministero croato, prima i più vicini, e quale
conviene davvero contando il carburante per andare e tornare.

OGNI TIPO DI VEICOLO
Un'auto elettrica registra le ricariche in kWh. Un'auto a benzina e GPL ha un
consumo per ciascun carburante. Una moto ha catena, corona e olio forcella
invece del filtro abitacolo. I treni di gomme ricordano stagione, età e
battistrada.

RICEVUTE E STATISTICHE
Allega lo scontrino o la fattura dell'officina alla voce stessa. Scegli il
periodo e vedi le spese per tipo, per categoria e per distributore, il
chilometraggio nel tempo e quanta strada fai davvero con un pieno.

PORTA QUI IL TUO STORICO
Importa un backup di Fuelio o un CSV da qualsiasi app indicando quale colonna è
quale; una seconda importazione non raddoppia niente. Vendi l'auto? Il rapporto
per la vendita mette lo storico in un PDF, e un codice lo sposta con l'auto
all'acquirente.

I TUOI DATI SONO TUOI
Esporta tutto come fogli di calcolo, fai un backup dell'intero garage che puoi
ripristinare, o leggilo tramite l'API di sola lettura. L'account si elimina
dall'app stessa.

Niente pubblicità, mai. Niente tracciamento. Gratis per un piccolo garage, e
quello che hai già registrato resta sempre accessibile senza pagare. I dati
restano nell'UE. La posizione serve solo sul tuo telefono, per ordinare i
distributori per distanza e per riconoscere quello in cui ti trovi. Su Android e
nel browser, in italiano, inglese e croato.
```

## Graphic assets

Generated in `assets/store/` from the app art (regenerate: see scratchpad script):

- **App icon (512×512):** `assets/store/play-icon-512.png` — upload as the store icon.
- **Feature graphic (1024×500):** `assets/store/feature-graphic.png` — required.
- **Phone screenshots:** `distribution/screenshots/phone-en/`, eight 1080×1920
  PNGs, **dark theme**, which is the identity the icon and the feature graphic
  are built on — the previous set was light and predated three feature waves.
  Upload in filename order:

  | File | Screen |
  |---|---|
  | `01-garage.png` | Dashboard: the fleet's figures, two jobs bundled into one visit, and what is due soonest |
  | `02-economy.png` | Economy ring against the car's own best and worst, and the latest fill-ups with their economy |
  | `03-service.png` | Reminders: what the car takes, a noted problem, and what is due with its progress |
  | `04-documents.png` | Registration, roadworthiness, insurance and green card, with what runs out when |
  | `05-planner.png` | The next 12 weeks, and two items bundled into one visit |
  | `06-timeline.png` | Everything logged, newest first, each fill-up with its economy |
  | `07-statistics.png` | Fill-ups, fuel and consumption, this year against last |
  | `08-stations.png` | Croatian pump prices with the fortnight's trend |

  Play caps the aspect ratio at 2:1; 1080×1920 is 16:9 and safe, while a
  full-height 1080×2400 shot is 2.22:1 and is rejected.

  **Retaken 18 September 2026: `02`, `03` and `06`.** `02` and `03` showed the
  vehicle tabs as Economy / Reminders / History / Costs (the third has been
  Services since decision 156), `02` a "Range left" figure decision 152
  removed, and `06` predated the economy on each fill-up. The other five were
  compared with the running app that day and still match. One flaw is in the
  app rather than the picture: the stations chart in `08` draws its lowest
  price hard against its first date ("€1.7510/7"), and the current build does
  the same. Retake `08` once the fix ships.

  **`02` and `03` go stale again with the release after 1.6.17.** Decision 173
  re-cut the vehicle tabs to Fuel / Upkeep / Car / Costs, so both show labels
  the app will no longer have, and what `03` shows is now split: what the car
  takes and a noted problem are on Car, what is due on Upkeep. Retake both
  from the build that carries it, `03` as Upkeep with something due and a
  service logged under it.

  **To recapture** (September 2026 method, from the web build — no emulator):

  ```bash
  supabase start && supabase db reset
  flutter build web --release \
    --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
    --dart-define=SUPABASE_ANON_KEY=<anon key from `supabase status`>
  (cd build/web && python3 -m http.server 8899)

  agent-browser set media dark
  agent-browser set viewport 432 768 2.5   # → exactly 1080 × 1920
  agent-browser open http://127.0.0.1:8899
  ```

  Then sign up, create a garage, **Load sample data**, hide the getting-started
  card, and walk the screens. Three things the browser needs told:

  - Flutter draws on a canvas, so there is nothing to click until its
    accessibility tree is on:
    `agent-browser eval "document.querySelector('flt-semantics-placeholder')?.click()"`,
    after every reload.
  - Neither the mouse wheel nor the keyboard scrolls a Flutter list from the
    browser. Set `scrollTop` on the scrollable `flt-semantics` element instead
    (the one whose `overflow-y` is `scroll`), then screenshot.
  - Leave the pointer where it hovers nothing (`agent-browser mouse move 5 760`),
    or a tooltip and a hover highlight end up in the shot.

  `03` also wants something recorded under "What this car takes" and one
  noted problem, or it shows two empty states; insert both with `psql`. The web build is the same Flutter widgets as the
  Android one, so the shots are the app; only the status bar is missing, which
  Play does not require. A device capture is still the higher-fidelity route
  (`adb shell wm size 1080x1920 && adb shell wm density 420`, then
  `adb exec-out screencap -p`, and `adb shell wm size reset` afterwards) — use
  it when the shot has to show system chrome.

  The Documents screen needs documents; the fastest honest way to get a set is
  to add one through the sheet and insert the rest with `psql` against the
  local stack, then add the matching one-time `reminder_rules` rows so the
  planner shows what a real household would see.

## Data Safety form — fill-in

Play → App content → Data safety. Answer exactly this (matches `PRIVACY.md`):

**Does your app collect or share any of the required user data types?** → **Yes**
**Is all user data encrypted in transit?** → **Yes**
**Do you provide a way for users to request that their data is deleted?** → **Yes**
(in-app: More → Settings → Delete account; also via the support email)

Data types to declare — for every row: **Collected = Yes**, **Shared = No**
(Supabase is a processor, not third-party sharing; Google is used only for
optional sign-in), **Processed ephemerally = No**:

> **Guest passes.** A pass holder is not a member of the garage, but what they
> log is visible to its members permanently, and remains after their access
> ends. This is still **Shared = No** for Play's purposes — it is sharing
> *between users of the app*, which the "Data shared with other users" wording
> in the listing description covers, not disclosure to a third party. If Play
> ever queries it, the answer is that a garage's members and its pass holders
> see the entries written against that garage's vehicles, and nobody else does.
> See the "Lending a car" section of `PRIVACY.md`.

| Category → Type | Required/Optional | Purposes |
|---|---|---|
| Personal info → Email address | Required | Account management, App functionality |
| Personal info → Name (display name) | Required | Account management, App functionality |
| App activity → Other user-generated content (vehicles, fuel, service, costs, income, trips, odometer readings, vehicle documents, notes) | Required | App functionality |
| Photos and videos → Photos (vehicle photo, and any photo attached to an entry) | Optional | App functionality |
| Files and docs → Files and docs (receipts or documents attached to an entry) | Optional | App functionality |
| Device or other IDs → Device or other IDs (the FCM registration token) | Optional | App functionality |

**Do NOT declare:** Location, Contacts, Financial info (no payment data — logged
costs are user-entered records, covered under "user-generated content"),
App activity → analytics (there is none).

> **Device or other IDs became declarable when push landed.** Allowing
> notifications makes Firebase issue a registration token, which is stored in
> `device_tokens` against the user and handed to Google to deliver the message.
> That is a device identifier leaving the device, so unlike location it *is*
> collection under Play's definition. Optional, because a user who declines the
> notification permission never generates one. If push is stripped again, this
> row goes with it.

> **Location needs care, because the app does request it.** The Fuel stations
> screen calls `Geolocator.getCurrentPosition()`, the fill-up sheet reads an
> already-granted position to name the station you are standing at, and the app
> holds `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`. It is still not declared, because Play defines
> *collection* as transmitting data off the device, and this position never
> leaves it: `positionProvider` and `grantedPositionProvider` feed nothing but
> the distance arithmetic in
> `nearbyStationsProvider`. If that ever changes — sending coordinates to a
> server, logging them, caching them anywhere off-device — Location becomes a
> declarable type the same day. `PRIVACY.md` discloses the access either way,
> which is what a reviewer asking about the permission will look for.

> Judgment call: fuel/service **costs** are amounts the user types about their own
> spending, not payment instruments or in-app purchases, so they belong under
> "Other user-generated content", not "Financial info". If a reviewer questions
> it, that is the rationale. The same applies to **income** entries: a lift share
> or a sale price is a record the user typed, not a transaction the app made.

> **Trips carry place names, and that is still not Location.** A trip stores the
> text somebody typed for where a journey started and ended. Play's Location type
> is about a position the device measured; a typed place name is user-generated
> content like any other note, and the app never records where the device has
> been. `PRIVACY.md` says so explicitly rather than leaving it to be inferred.

> **A trip's driver can be somebody else's name**, typed by the user, which is
> the one field in the app where a household records a third party rather than
> itself. It stays under "Other user-generated content" — it is text the user
> wrote, visible only inside their garage, deleted with the trip — but
> `PRIVACY.md` calls it out in its own sentence rather than letting it hide in
> a list, because a reviewer asking "whose data is this?" deserves the answer
> without having to ask.

> The **VIN lookup** sends a VIN the user typed to the US NHTSA registry when
> they press "Look up". It is not a Data safety *collection* type (nothing is
> stored, and it is user-initiated), but it is disclosed in `PRIVACY.md` under
> "VIN lookups" as a transfer outside the EU.

> **Document numbers are user-generated content, not "Personal info → Other".**
> A registration certificate number, a policy number and an insurer's name are
> facts about a *vehicle* that the user typed, in the same way a VIN and a
> plate already were, and they are stored and shared exactly like every other
> row: inside the garage, nowhere else. They are not government identifiers of
> a person and the app asks for no such thing — there is deliberately no
> driving licence, because that would be one. `PRIVACY.md` names documents as
> their own bullet rather than folding them into "attachments", which is what
> a reviewer asking about the feature will look for.

> **Webhooks** send what happens in the garage — an entry logged, edited or
> deleted; a vehicle added, archived, restored, lent, returned or handed over,
> by name and without its plate or VIN; a member joining or leaving, by
> display name; and maintenance as it falls due — to a URL that garage chose,
> in the language the garage chose for it, and keep a 30-day log of what was
> sent and whether it arrived.
> That is a user-directed transfer rather than sharing by the app, and it is
> disclosed in `PRIVACY.md`.

## Release checklist (human)

- [ ] Create the production Supabase project in EU (Stockholm); `supabase link`,
      `supabase db push`, then deploy all four edge functions (`delete-account`,
      `push-due-reminders`, `public-api`, `dispatch-webhooks`) — see RELEASE.md §1.
- [ ] Create `env/prod.json` (gitignored) with production URL, anon key, Google
      **web** client ID.
- [ ] Create the Android + Web Google OAuth clients; register the debug SHA-1 now
      and the Play App Signing SHA-1 after first upload; paste the web client ID
      into Supabase → Auth → Google.
- [ ] Generate the upload keystore and `android/key.properties` (both gitignored).
- [ ] `flutter build appbundle --dart-define-from-file=env/prod.json`.
- [ ] Host `PRIVACY.md` at https://garage.hrva.cc/privacy (set the contact email).
- [x] **Invite links: the signing fingerprint is in
      `web/.well-known/assetlinks.json`.** It comes from Play Console →
      *Test and release* → *Setup* → *App signing* → **App signing key
      certificate**. It must be the *App signing* key, not the *Upload* key:
      Play re-signs the app, so the upload fingerprint will not match what is
      installed, and the failure is silent.

- [ ] **After the next web deploy, confirm the file is actually served.**
      This one has a trap. The Worker sets
      `not_found_handling: single-page-application`, so a path that does not
      exist returns **200 with `index.html`** rather than a 404. Checking for a
      200 therefore passes even when the file was never deployed, while Android
      fetches HTML where it expects JSON and refuses to verify without saying
      why. Check the *body*, not the status:

      ```bash
      curl -sS https://garage.hrva.cc/.well-known/assetlinks.json | head -c 60
      # want: [{"relation":["delegate_permission/common.handle_all_urls"], ...
      # wrong: <!DOCTYPE html>   ← the SPA fallback answered; file not deployed
      ```

      If it returns HTML, wrangler did not upload the dot-directory. Modern
      Workers static assets document no such exclusion (that was the legacy
      Workers Sites uploader), so it is expected to work, but this is the step
      that proves it. The remedy if it ever does not: serve that one path from a
      Worker script, since Android's verifier requires a direct 200 and does not
      follow redirects.

- [ ] **Then confirm Android verifies it**, on a device with a build installed
      *from Play* — a local debug or profile build is signed with the debug
      keystore, whose fingerprint is not the one published, so it will never
      verify:

      ```bash
      adb shell pm verify-app-links --re-verify cc.hrva.garage
      adb shell pm get-app-links cc.hrva.garage   # expect "verified"
      ```

      To test the routing before any of that, fire the intent straight at the
      app, which bypasses verification:

      ```bash
      adb shell am start -n cc.hrva.garage/.MainActivity \
        -a android.intent.action.VIEW -d "https://garage.hrva.cc/join/ABC12345"
      ```

      A local debug build can be made to verify too by adding that keystore's
      SHA-256 to the array — it is a list. Weigh it first: the debug keystore
      uses a well-known password, so publishing its fingerprint lets anyone
      holding that file claim these links on a device where their build is
      installed.
- [ ] Device smoke test: sign up → garage → vehicle → two fills → economy →
      two close intervals → bundle card → invite a second device → sync.
- [ ] Upload the AAB to Internal testing, fill listing + Data Safety, upload the
      screenshots from `distribution/screenshots/phone-en/`, then promote to
      Production and submit.
```
