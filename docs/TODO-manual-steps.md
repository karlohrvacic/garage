# What only you can do

Written 6 September 2026, after a night that shipped named routes with a
commute trend, observations with photos, a mechanic handover sheet, a pre-trip
check, an offline write queue, a startup cache, a mileage trail on the seller's
report, time-limited guest access to a car, and merging two garages — plus twelve
bug fixes and ten new CI guards.

Everything in this repository is done, formatted, analysed and green:

```
flutter analyze                        # clean
flutter test                           # 2885 passing
flutter build web                      # builds
flutter build apk --release            # builds, and was installed and run
dart test test_rls/rls_test.dart       # 201 passing, against a real Postgres
cd supabase/functions && deno test     # 89 passing, plus deno check and lint
```

The **release** build matters separately from the profile one: it is the only
variant R8 shrinks and obfuscates, and a missing keep rule shows up there and
nowhere else. It builds (77.9 MB), installs and starts with nothing in
`logcat`.

The **app bundle** — what Play actually receives — was built too (73.8 MB), and
`keytool -printcert -jarfile` reports `CN=Karlo Hrvacic, O=hrva.cc`, not the
debug key. That is the same check `deploy-play.yml` runs before uploading, so
the local keystore is wired and that step will pass.

> Both were built against `env/local.json`, which points at `127.0.0.1`.
> **Neither artefact is releasable** — they prove the build, not the config.
> The tag workflow supplies the production defines.

The app was also **run**, repeatedly: a profile build on the Pixel 7 emulator
against a local Supabase stack, driven through sign-up → create garage →
sample data → start a drive on a new route → finish it → the trend → generate
the seller's report and read the PDF. Five defects came out of that walk and
nothing else — they are in §10.

What is below is the part that lives in accounts, consoles and physical
devices. It is ordered by what it costs if it is skipped, not by effort.

---

## 1. Twelve new migrations will apply themselves — check that they did

`0054_trip_drafts.sql` through `0065_vehicle_parts.sql` go out with the
push to `main` through the Supabase GitHub integration. They were applied from
scratch locally (`supabase db reset`) and the RLS suite ran against the result
more than once tonight, so they are known to apply in order.

**Check Dashboard → Database → Migrations lists up to `0065`.** If the
integration missed them, `supabase db push` applies the backlog.

> **Updated 17 September 2026: the list now ends at `0076`.**
>
> - `0070` makes the sale of a car end every loan of it (decision 159).
> - `0071` makes a merge carry the absorbed garage's named routes (160).
> - `0072` stops borrowers reading the car's row, which carried its price (164).
>   A borrower on an app build older than this sees no borrowed car until they
>   update.
> - `0073` adds `fuel_entries.station_ref`, the forecourt a fill-up was
>   recognised at (170). Every fill-up the new app saves sends this column, and
>   PostgREST refuses a column it does not know, so **confirm `0073` is applied
>   before tagging an Android build**. The web deploy waits for CI, which is
>   normally longer than the migration takes.
> - `0074` makes minting a pass wait for a sale of the same car (165).
> - `0075` caps both storage buckets at 10 MB and to images and PDFs (166).
> - `0076` gives the daily reminder run a minute to answer and takes back the
>   PUBLIC grant that let anyone with the app's key start it (168).
>
> None moves data, so none can fail halfway. **`0070`, `0072` and `0076` are
> the ones to confirm**: until they are applied, a borrower can keep a sold car
> and read what an owner paid, and anyone can start the reminder run.

Two of them are quiet if they fail. `0062` and `0063` only add tables to the
realtime publication: without them the app still works, and a note recorded on
one phone simply never reaches another until that screen is reopened. Nothing
errors. `0061` is the loud one — the routes screen fails on open without it, and
`0064` is loud in the same way: lending a car calls a function that does not
exist until it lands. `0065` too: the new "what this car takes" screen reads a
table.

---

## 2. The `public-api` edge function has changed and must be deployed

It gained an `/observations` resource, and `/trips` now returns `route_id` and
`comparable`. Until it ships, the app is fine and the API answers `404` for a
path the docs and the hosted page both describe.

> **Updated 17 September 2026: `dispatch-webhooks` and `push-due-reminders`
> have changed too.** Chat messages carry the station, the consumption, the
> category and the note; the JSON body gained three fields; the dispatcher no
> longer believes the row it is handed; and the daily reminder job now posts
> `reminder.due` to webhooks, with or without Firebase. Until both are
> deployed, hooks keep the old behaviour and nothing breaks. The daily job
> only runs once its cron row exists (§3).

Either add the two secrets below once and let it deploy itself from now on, or
deploy it by hand this time:

```bash
supabase functions deploy public-api
```

### Making it automatic (recommended, ~2 minutes)

`.github/workflows/deploy-functions.yml` deploys all four functions on a push
to `main` that touches `supabase/functions/**`. It needs two repository
secrets, in **GitHub → Settings → Secrets and variables → Actions**:

| Secret | Where it comes from |
|---|---|
| `SUPABASE_ACCESS_TOKEN` | supabase.com/dashboard/account/tokens → Generate new token |
| `SUPABASE_PROJECT_REF` | the `<ref>` in `<ref>.supabase.co` |

Without them the job **skips with a notice rather than failing**, which is
deliberate — but it means a skipped deploy looks like a green run. Check the
Actions tab the first time.

---

## 3. Find out whether push actually works (~1 hour, or ten minutes to know)

**This entry has changed since the last one.** It used to say Firebase was not
configured. That was wrong: `Firebase.initializeApp` is called
(`lib/core/notifications/push_receiver.dart:67`), the `FIREBASE_*` dart-defines
come from `env/*.json`, and a profile build starts the messaging service.

What nobody can check from inside the repository is the **server** half:
whether `push-due-reminders` is deployed against the production project with an
FCM service account, and whether the cron row exists. Until somebody looks,
"push is off" and "push is on and untested" are indistinguishable from here —
and they call for opposite work. That look is the ten minutes; the hour is
whatever it finds.

[`RUNBOOK-push.md`](RUNBOOK-push.md) is the whole list.

> **Do not do half of it.** Configuring Firebase makes the app stand down its
> own local scheduling in favour of the server
> (`lib/core/notifications/notification_providers.dart`). A build with the
> dart-defines but no scheduled cron sends nobody anything — strictly worse
> than not starting.

---

## 4. Verify the two link paths against the live project (~15 minutes)

Unchanged by this work, and still open in
[`known-bugs-and-risks.md`](operations/known-bugs-and-risks.md).

**The confirmation email.** In Supabase → Authentication:

- **URL Configuration**: Site URL is `https://garage.hrva.cc`, and
  `https://garage.hrva.cc/` is in the redirect allow-list. Supabase *ignores*
  `emailRedirectTo` unless the URL is allow-listed, and falls back to the Site
  URL silently.
- **Emails**: the templates from the runbook are actually pasted in.

Then register a throwaway address and follow the link. A blank page is the
symptom; the browser console distinguishes an auth error from a Worker problem.

**The invite deep link.** After the next web deploy:

```bash
curl -s https://garage.hrva.cc/.well-known/assetlinks.json | head -c 200
```

**Read the body, not the status.** The Worker serves `index.html` with a `200`
for any missing path, so "not deployed" and "deployed" look identical to
anything that only checks the status code. You want JSON with a
`sha256_cert_fingerprints` array.

---

## 5. Paste the new Play listing, and retake two screenshots (~45 minutes)

**Updated 17 September 2026.** The editorial decision this section used to ask
for has been made (decision 158): all three full descriptions in
[`play-store-listing.md`](play-store-listing.md) were rewritten for the
production launch, carry the five features they were missing, and are under
Play's 4000. What is left is Console work:

- **Main store listing → paste title, short and full description in English,
  Croatian and Italian.** Croatian changed throughout, not only where features
  were added: it now says *ti*, *točenje* and *garaža*, as the app has since
  decision 153, and its short description changed with it.
- **Retake `02-economy.png` and `03-service.png`** before the production
  release. Both show the old vehicle tabs, and `02` shows the "Range left"
  figure that decision 152 removed because it was wrong. The recapture method
  is in the listing file. The other six were compared with the code and not
  with a running build, so look at them while you are there.
- **Production → Countries/regions.** It is production's own list, and a
  release to no countries reaches nobody (`RUNBOOK-update.md` §2).

Release notes upload themselves with the tag. **Before the production tag,
replace the three files in `distribution/whatsnew/` with the launch note
below**: they currently describe the 1.6.17 tester build, and production users
would be told about changes to an app they have never had.

`whatsnew-en-GB`:

```
The first public release. Thank you to the testers whose reports shaped it.
• Real fuel economy, measured between full tanks
• Services due by how the car is actually driven
• What each car costs per kilometre and per month
• One garage, shared live by everyone who drives
• Entries logged with no signal are sent when there is one
• Webhooks say what was logged, and what falls due
• No ads, no tracking, and everything exports
```

`whatsnew-hr`:

```
Prvo javno izdanje. Hvala testerima čije su prijave oblikovale aplikaciju.
• Stvarna potrošnja, mjerena između punih spremnika
• Servisi dospijevaju prema tome koliko se auto stvarno vozi
• Koliko svaki auto stoji po kilometru i po mjesecu
• Jedna garaža koju uživo dijele svi koji voze
• Unosi bez signala šalju se kad ga bude
• Webhookovi javljaju što je upisano i što dospijeva
• Bez oglasa, bez praćenja, a sve možeš izvesti
```

`whatsnew-it`:

```
La prima versione pubblica. Grazie a chi l'ha messa alla prova.
• Consumo reale, misurato tra un pieno e l'altro
• Interventi che scadono in base a quanto guidi davvero
• Quanto costa ogni auto al chilometro e al mese
• Un solo garage, condiviso in tempo reale
• Le voci senza segnale partono appena torna
• I webhook dicono cosa è stato registrato e cosa scade
• Niente pubblicità, niente tracciamento, e tutto si esporta
```

---

## 6. Decide about a Croatian privacy policy (~5 minutes to decide)

The app ships in Croatian, the Play listing has a full Croatian description,
and the release notes are translated. Every page on garage.hrva.cc is English —
including the privacy policy that listing links to.

GDPR Art. 12 asks for information "in a concise, transparent, intelligible and
easily accessible form, using clear and plain language". For an app whose
store listing, interface and support are Croatian, a policy only in English is
the weaker reading of that. **This is not legal advice**, and a policy is the
one document where an approximate translation is worse than none — it is what
a regulator and a user both read as the promise.

The decision is yours: leave it, have `PRIVACY.md` translated properly and
served at `/privacy?hr` with `hreflang` on both, or ask a lawyer as part of a
real EU launch. It is written up in
[`known-bugs-and-risks.md`](operations/known-bugs-and-risks.md) so it does not
get lost.

---

## 7. Terms of use: a draft exists, and it needs a lawyer before it needs a link

**Updated 17 September 2026.** [`TERMS.md`](../TERMS.md) now exists: who sees
what in a shared garage, fair use of the API, what the app's figures are and
are not, the paid-tier promise from decision 155, shutting down, liability, and
Croatian law. Every factual sentence in it was checked against the code and the
migrations. **It is a draft, it says so in a box at its top, and nothing links
to it.** None of this is legal advice, and a terms document is the one place
where confident wording is worth less than an hour of somebody qualified.

**What it commits the operator to, so read these first:** an age of 16, 30
days' notice by email before shutting the service down or changing the terms
for the worse, a written answer to a complaint within 15 days, and a liability
cap of EUR 50 towards business users. Each figure is a placeholder to confirm,
not something anybody has agreed to. The notice is promised by email because
that is the only channel that exists: the app has no way to announce anything
to the people using it.

**Questions for the lawyer:**

1. **Who is the party, and is a name enough?** Both documents now name a
   person and an email address; the draft terms still have a placeholder for a
   postal address. Croatian e-commerce law expects a service provider to be
   identifiable, and GDPR Art. 13(1)(a) asks for a controller's "identity and
   contact details": whether that means an address for a private individual is
   the question.
2. **Is a free app's operator a trader** under the Consumer Protection Act? If
   so, what follows beyond the written-complaint channel the draft already has:
   pre-contract information, and whether the rules for digital services apply
   when the only thing a user "pays" with is data used solely to run the
   service.
3. **What can the liability section actually exclude** towards a consumer, and
   is the EUR 50 cap towards businesses worth having?
4. **Is a stated age of 16 enough** without an age gate, and does it match the
   target audience declared in Play Console?
5. **Changing the terms:** is notice plus the right to leave enough, given that
   silence as acceptance is the classic unfair term?
6. **Jurisdiction wording** for a consumer elsewhere in the EU.
7. **The Digital Services Act.** Garage stores what users type and shows it to
   other users inside a private garage, never publicly. Does that make it a
   hosting service, and do a contact address and the "tell us about illegal
   content" paragraph cover what a one-person service owes?
8. **Other people's data.** A driver's name or a photo of somebody's document
   is typed by the user. Is "you are responsible for having the right to enter
   it" enough?

**To publish it once it is corrected:** delete the status box; mirror it into
`web/terms.html` the way `web/privacy.html` mirrors the policy; give
`test/legal/` a terms twin of `privacy_policy_test.dart` (same headings, same
date, never the word "draft"); add `GarageLinks.terms` beside
`GarageLinks.privacyPolicy` (`lib/core/links/url_opener.dart:24`) and link it
from About, More and the footers under `web/`. Translate it afterwards, not
before: a translation of a draft is two drafts.

**The sign-up screen is the larger gap, and it is about the policy as much as
the terms.** Nothing on the sign-in or sign-up screens links to either
document, and there is no "by continuing you agree" sentence: the privacy
policy is reachable only from About and More, which means only after an account
exists. It is written up in
[`known-bugs-and-risks.md`](operations/known-bugs-and-risks.md) with the other
things the launch review found.

Checked and fine while I was there: no analytics or crash-reporting dependency,
and no page under `web/` loads anything from a third-party host, so the "no
tracking" claim holds and no cookie banner is owed. Adding analytics would
change both answers at once.

---

## 8. iOS: install Xcode, then find out (~1 hour, mostly downloading)

**You said you have a Mac, so the project now exists.** `ios/` is scaffolded and
configured — bundle id matching Android, deployment target 15.0 for Firebase,
the location purpose string, the background mode, the Files-app keys, all three
languages, and the launcher icon generated from the same source art as Android.

**Nothing has compiled it.** This machine has the Command Line Tools, not Xcode.
The `ios` job added to `ci.yml` runs `flutter build ios --no-codesign` on a
macOS runner, and its first run is the first compile this project has ever had —
so expect it to fail, and treat that as the job doing its work.

[RUNBOOK-ios.md](RUNBOOK-ios.md) is the whole list: what needs Xcode (the
build, and a phone for seven days on a free Apple ID) and what needs the paid
account (push, Google sign-in, universal links, TestFlight).

---

## 9. On a real device, what is left (~10 minutes)

Most of the device work is done — see the walk at the top. Three things remain
that no automation here can reach, and all three fail silently:

- **Place the home-screen widget.** Its colours changed earlier (§10) and a
  `RemoteViews` layout that uses an unsupported attribute fails at inflation,
  in the launcher's process, showing "Problem loading widget" and logging
  nowhere the app can see. The compiled resources were checked inside the APK,
  which is not the same as seeing it on a home screen.
- **Long-press the app icon** for the fill-up shortcut (needs API 25+). Its
  icon changed colour too.
- **Lend a car to yourself.** The vehicle menu now has `Lending` — it had no
  button until this morning, so nobody has ever opened that screen from inside
  the app. Create a pass, open the link on a second account, and check the
  borrower sees the one car and cannot reach the others.
- **A cold start into a deep link:**

```bash
adb shell am force-stop cc.hrva.garage
adb shell am start -a android.intent.action.VIEW \
  -d https://garage.hrva.cc/log/fuel cc.hrva.garage/.MainActivity
```

> The emulator on this machine has 2 GB and OOM-kills debug builds — use
> `flutter run --profile`. It is still running, with the **release** build
> installed and signed out: installing it replaced the profile build, which
> Android treats as a different signature, so the account went with it. Sign up
> again or reinstall the profile APK. `supabase stop` frees the rest.

---

## 10. Three things you reported, all fixed — and five the device found

**Reported by you:**

- **Petrol stations read "PM - XXXXX".** That is *prodajno mjesto*, a reference
  in somebody's stock system. A station whose own name carries no word at all
  now shows its brand instead; "BP Zagreb" and the like are untouched, because
  two INA forecourts in one city are exactly what a name tells apart. Fuel
  entries saved under the old code still match for posted prices.
- **The widget's icon was "that blue one".** It was #2F6FEB, a brand blue that
  appears nowhere else in an app whose identity is a dark instrument cluster
  with an amber accent. It is the launcher icon's own near-black with Dash
  Amber now; the launcher shortcut gets Daylight Amber, since launchers draw
  that one on a pale badge.
- **"Loading garage" took too long.** Startup now paints the garage this device
  saw last and refreshes behind it, so a cold start no longer waits on a round
  trip. The cache is keyed by user and cleared on sign-out.

**Found by putting a profile build on the emulator and looking at it** — none
of these was reachable from the test suite:

- Two unhandled exceptions at *every* cold start, from a `WidgetRef` used after
  an `await`, which also meant no reminders were scheduled.
- The route trend's first-run view read `1, 1, 1, 0` down its axis and claimed
  a "middle half" over a single journey.
- The economy chart printed `44,011.364` on top of `43,245`.
- The dashboard asserted "≈0 km left" for a car with a gap in its fuel records.
- The seller's report printed a table header over nothing when a car had no
  services.

**Reported by you the next morning:**

- **Italian.** 1204 strings, reviewed a second time by Codex, which found
  sixteen real defects — wrong agreement, *tagliandi* where the file says
  *interventi*, four counted messages that read "1 rifornimenti". All fixed.
  One objection was kept deliberately: *bollo* for registration (decision 139).
  The dashes are gone from both translations, Croatian included: forty-two
  Croatian messages were rewritten, not search-and-replaced, because half of
  them wanted a full stop where English wanted an aside. A test now fails on a
  dash in any translation. English keeps its own.
- **Lending is a window now**, it can be extended without reissuing the code,
  and the history can be opened *without* the prices. That last one is enforced
  by the database, not by the screen: Postgres cannot mask a column, so a pass
  that hides prices reads no entry rows at all and gets its history from a
  function that nulls the money (decision 140, twelve new RLS tests).

- **"I can't find a button to borrow my Clio."** You could not: lending had a
  screen, a table, policies, tests and a line in the release notes, and no way
  in. It is now `Lending` in the vehicle menu, beside Transfer. A test now
  fails the build for any route nothing opens — this was the third time
  (decision 138).

**Roadmap item 12 is half built, the half that needs no data.** A car now
carries what it takes per job (oil spec, filter number, bulb, wiper lengths),
typed once and printed on the service sheet under the chip the moment that job
is ticked. The curated-dataset half is still a data project with no free
source; what changed is that such data would now have somewhere to land
(decision 144).

**The rest of the roadmap has nothing half-finished left on it.** Its last two open halves
were built tonight (decision 142): an odometer reading that jumps too far to be
driving is now questioned at the moment it is typed, and the cost-to-own rate
says what distance it is measured over, since a car bought before it was logged
makes that rate read high. Everything still open on that page is either waiting
on you (push, the live links, receipt photographs) or is a bet nobody has taken
— EV charging with tariffs, price alerts, consumables, the shared reliability
signal, iOS.

**Found by asking what else shipped half-wired, after lending had no button:**

- Sixteen messages existed in three languages with nothing rendering them.
  Half were features one step short of done — unlabelled route filters, a
  borrowed car that never said when it goes back or why its history looks
  empty, a drive that did not say who started it, an observation hiding which
  journey it came from, a tank range without the date it already knew, a silent
  admin hand-over. All wired up. The other half were leftovers and are gone.
  A test now fails the build on the next one (decision 141).
- Everything else came back clean: no route without a way in, no repository
  method without a caller, no SQL function nothing calls, no orphan column.

**Found by reading the public pages as instructions rather than as prose:**

- Five menu paths were stale — including the one on the account-deletion page
  Google links to, and one in the privacy policy pointing at a screen that had
  no entry point on More at all. Both are fixed, and a test now holds every
  such path to rows that exist (decisions 136 and 137).

---

## 11. Optional, and worth knowing

- **`git status` is deliberately dirty.** Nothing was committed or pushed, as
  asked. `git diff --stat` is the whole change.
- **The dashboard's debug-only `setState during build` assertion** finally has
  the harness it was waiting for
  (`test/features/dashboard/dashboard_live_providers_test.dart`, the real
  provider graph over fake repositories) and still does not reproduce. The
  harness cost seven repository fakes and is the more useful half.
- **Six new CI guards**, each for a failure with no symptom: attachment sweeps
  tied to the entry-kind enum, every backup field written *and* read, every
  table subscribed to realtime or listed as deliberately not with a reason, the
  Dart attachment enum matching the SQL constraint, no provider read inside
  `dispose`, and the startup cache overridden in tests.
- **A new screen convention.** `CLAUDE.md` now asks for a Croatian, 320 px,
  1.5x layout test on any new screen. Croatian runs 20–30% longer than English
  and the ARB tests only check that a translation exists; that check found seven
  overflows in one night, one of them years old.

---

## What was deliberately not built

Recorded so it does not read as an oversight:

- **Receipt OCR** (roadmap item 6, and the proposal's item D). It needs
  photographs of real Croatian receipts — INA, Petrol, Tifon, a service invoice
  — before a line of it is worth writing. An extractor that is wrong a third of
  the time costs more trust than the typing it saves. **This is the one place
  where a few photos from you unblock the highest-value idea on the page.**
- **The twelve-month expense calendar** (item H). Deferred on the proposal's own
  reasoning: it is the idea most likely to produce a confident wrong number.
- **Restoring which route a trip was on.** A backup carries the trip and the
  route names, but a restore mints new ids, so a restored journey comes back
  unfiled. Mapping names to ids needs a pass over the whole file before any
  vehicle is written, and attaching a trip to the *wrong* route is worse than
  leaving it unfiled (decision 131).
- **Retuning the CSV column guesser.** It matches a field to the first header
  *containing* one of its candidates, so the trip field keyed `to` matches
  `route`. Only column order protects our own export today. A minimum candidate
  length would break `km` matching `odometer_km`, which the same pass depends
  on; the reproduction is in known-bugs.
- **Moving the Trips vehicle picker out of the toolbar.** The navigation doc's
  rule is that app-bar actions are icons and variable-width labels belong in the
  body. The picker is capped and guarded instead, which fits; moving it is the
  more faithful answer and worth doing the next time that screen is open.
