# Garage — Play Store listing

Everything needed for the Play Console submission. Copy is pre-trimmed to Play's
character limits (noted inline). Keep the **Data Safety** answers consistent with
`PRIVACY.md` — a mismatch is a common rejection reason.

- **App name:** Garage
- **Package name:** `cc.hrva.garage`
- **Category:** Auto & Vehicles
- **Content rating:** Everyone (no objectionable content)
- **Price:** Free — no ads, no in-app purchases
- **Support email:** privacy@hrva.cc
- **Privacy policy URL:** https://garage.hrva.cc/privacy

## Store title (max 30 chars)

- **English:** `Garage: Fuel & Maintenance`  _(26)_
- **Hrvatski:** `Garaža: gorivo i servis`  _(23)_

## Short description (max 80 chars)

- **English:** `Log fuel, track maintenance, and share your garage with your household.`  _(70)_
- **Hrvatski:** `Bilježite gorivo, pratite servise i dijelite garažu s kućanstvom.`  _(64)_

## Full description (max 4000 chars)

### English

```
Garage keeps your household's vehicles in order — without the spreadsheet.

FUEL LOG
Record every fill-up and see real fuel economy, calculated properly between
full tanks rather than guessed. Missed logging a fill? Mark it, and Garage skips
that stretch instead of showing a wrong figure.

MAINTENANCE THAT KNOWS WHEN
Set service intervals by distance, by time, or both. Garage projects when each
item is actually due from how much you really drive — so a car that sits all
winter isn't nagged like one doing a daily motorway commute.

SMART BUNDLING
When several jobs fall due around the same time, Garage suggests doing them in a
single shop visit — and re-plans instantly if you wave one off. One trip instead
of three.

SHARED HOUSEHOLD
Invite the people you share cars with. Everyone sees the same up-to-date history,
in sync across devices, with no manual refresh.

PLANNER & CALENDAR
A 12-week runway and a month calendar show what's coming, so nothing sneaks up
on you.

YOUR DATA IS YOURS
Export everything as CSV any time. Delete your account — and its data — in one tap.

No ads. No trackers. No location. Data hosted in the EU.
```

### Hrvatski

```
Garaža održava vozila vašeg kućanstva u redu — bez tablica.

EVIDENCIJA GORIVA
Zabilježite svako tankiranje i pratite stvarnu potrošnju, točno izračunatu između
punih spremnika, a ne procijenjenu. Propustili ste unijeti tankiranje? Označite
to i Garaža preskače taj dio umjesto da prikaže pogrešan podatak.

ODRŽAVANJE KOJE ZNA KADA
Postavite intervale servisa po kilometraži, po vremenu ili oboje. Garaža
procjenjuje stvarno dospijeće prema tome koliko doista vozite — pa auto koji zimu
provede u garaži ne opominje kao onaj u svakodnevnoj vožnji.

PAMETNO OBJEDINJAVANJE
Kad više stavki dospijeva u sličnom razdoblju, Garaža predlaže da ih obavite u
jednom posjetu servisu — i odmah ponovno planira ako neku izostavite. Jedan
odlazak umjesto tri.

ZAJEDNIČKO KUĆANSTVO
Pozovite one s kojima dijelite automobile. Svi vide istu, ažurnu povijest,
usklađenu na svim uređajima, bez ručnog osvježavanja.

PLANER I KALENDAR
Pregled od 12 tjedana i mjesečni kalendar pokazuju što slijedi, da vas ništa ne
iznenadi.

VAŠI PODACI SU VAŠI
Izvezite sve u CSV bilo kada. Obrišite račun — i njegove podatke — jednim dodirom.

Bez oglasa. Bez pratitelja. Bez lokacije. Podaci se čuvaju u EU.
```

## Graphic assets

Generated in `assets/store/` from the app art (regenerate: see scratchpad script):

- **App icon (512×512):** `assets/store/play-icon-512.png` — upload as the store icon.
- **Feature graphic (1024×500):** `assets/store/feature-graphic.png` — required.
- **Phone screenshots (still to capture, 2–8, min 320px side):** run the app and
  capture, in this order:
  1. Dashboard with the bundling card
  2. Fuel log with the economy header
  3. Vehicle detail — the economy gauge
  4. Maintenance calendar
  5. 12-week planner
  6. Onboarding (create / join a household)

## Data Safety form — fill-in

Play → App content → Data safety. Answer exactly this (matches `PRIVACY.md`):

**Does your app collect or share any of the required user data types?** → **Yes**
**Is all user data encrypted in transit?** → **Yes**
**Do you provide a way for users to request that their data is deleted?** → **Yes**
(in-app: Settings → Delete account; also via the support email)

Data types to declare — for every row: **Collected = Yes**, **Shared = No**
(Supabase is a processor, not third-party sharing; Google is used only for
optional sign-in), **Processed ephemerally = No**:

| Category → Type | Required/Optional | Purposes |
|---|---|---|
| Personal info → Email address | Required | Account management, App functionality |
| Personal info → Name (display name) | Required | Account management, App functionality |
| App activity → Other user-generated content (vehicles, fuel, service, notes) | Required | App functionality |
| Photos and videos → Photos (optional vehicle photo) | Optional | App functionality |

**Do NOT declare:** Location, Contacts, Financial info (no payment data — logged
costs are user-entered records, covered under "user-generated content"), Device
or other IDs, App activity → analytics (there is none).

> Judgment call: fuel/service **costs** are amounts the user types about their own
> spending, not payment instruments or in-app purchases, so they belong under
> "Other user-generated content", not "Financial info". If a reviewer questions
> it, that is the rationale.

## Release checklist (human)

- [ ] Create the production Supabase project in EU (Frankfurt); `supabase link`,
      `supabase db push`, `supabase functions deploy delete-account`.
- [ ] Create `env/prod.json` (gitignored) with production URL, anon key, Google
      **web** client ID.
- [ ] Create the Android + Web Google OAuth clients; register the debug SHA-1 now
      and the Play App Signing SHA-1 after first upload; paste the web client ID
      into Supabase → Auth → Google.
- [ ] Generate the upload keystore and `android/key.properties` (both gitignored).
- [ ] `flutter build appbundle --dart-define-from-file=env/prod.json`.
- [ ] Host `PRIVACY.md` at https://garage.hrva.cc/privacy (set the contact email).
- [ ] Device smoke test: sign up → household → vehicle → two fills → economy →
      two close intervals → bundle card → invite a second device → sync.
- [ ] Upload the AAB to Internal testing, fill listing + Data Safety, capture
      screenshots, then promote to Production and submit.
```
