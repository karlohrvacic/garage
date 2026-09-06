# What only you can do

Written 6 September 2026, after a night that shipped named routes with a
commute trend, observations with photos, a mechanic handover sheet, a pre-trip
check, an offline write queue, a startup cache, a mileage trail on the seller's
report, time-limited guest access to a car, and merging two garages — plus twelve
bug fixes and ten new CI guards.

Everything in this repository is done, formatted, analysed and green:

```
flutter analyze                        # clean
flutter test                           # 2870 passing
flutter build web                      # builds
flutter build apk --release            # builds, and was installed and run
dart test test_rls/rls_test.dart       # 189 passing, against a real Postgres
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
nothing else — they are in §9.

What is below is the part that lives in accounts, consoles and physical
devices. It is ordered by what it costs if it is skipped, not by effort.

---

## 1. Ten new migrations will apply themselves — check that they did

`0054_trip_drafts.sql` through `0063_realtime_guest_passes.sql` go out with the
push to `main` through the Supabase GitHub integration. They were applied from
scratch locally (`supabase db reset`) and the RLS suite ran against the result
more than once tonight, so they are known to apply in order.

**Check Dashboard → Database → Migrations lists up to `0063`.** If the
integration missed them, `supabase db push` applies the backlog.

Two of them are quiet if they fail. `0062` and `0063` only add tables to the
realtime publication: without them the app still works, and a note recorded on
one phone simply never reaches another until that screen is reopened. Nothing
errors. `0061` is the loud one — the routes screen fails on open without it.

---

## 2. The `public-api` edge function has changed and must be deployed

It gained an `/observations` resource, and `/trips` now returns `route_id` and
`comparable`. Until it ships, the app is fine and the API answers `404` for a
path the docs and the hosted page both describe.

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

## 5. The Play listing needs an editorial decision, not a paste (~30 minutes)

The full description is **stale by five features** — drives and routes,
observations and the mechanic sheet, the trip check, lending a car, and working
without a signal — and **both languages are within a dozen characters of the
4000 Play allows**. `test/ci/deploy_workflow_test.dart` enforces the cap.

So adding any of them means taking something out, and which features earn a
place in the shop window is your call rather than mine. The note at the top of
[`play-store-listing.md`](play-store-listing.md) says the same thing; the
`README.md` feature list is current and is the best source for wording.

Everything else about the listing is unchanged: screenshots and the feature
graphic are as they were, release notes upload themselves with the tag, and no
new data *type* is collected — a route name and an observation are both "Other
user-generated content", already declared.

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

## 7. Terms of use — an offer, not a task (~an hour, with someone qualified)

The AGPL covers the source; nothing covers the *service*. There is no
acceptable-use statement, no liability disclaimer for the hosted app, and
nothing saying what it is not.

The app disclaims itself where it matters most — the seller's report, the
handover sheet and the trip check each say in the document that they are
compiled from the owner's own records and verify nothing. What is missing is
the ordinary umbrella: provided as-is, figures come from what you typed, a
projected due date is not a legal deadline.

I did not draft one. A terms document is published legal wording and it should
be yours. **If you want it, say so and I will write a first draft for a lawyer
to correct** — that is the cheapest order to do it in.

Checked and fine while I was there: no analytics or crash-reporting dependency,
and no page under `web/` loads anything from a third-party host, so the "no
tracking" claim holds and no cookie banner is owed. Adding analytics would
change both answers at once.

---

## 8. On a real device, what is left (~10 minutes)

Most of the device work is done — see the walk at the top. Three things remain
that no automation here can reach, and all three fail silently:

- **Place the home-screen widget.** Its colours changed tonight (§9) and a
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

## 9. Three things you reported, all fixed — and five the device found

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

- **"I can't find a button to borrow my Clio."** You could not: lending had a
  screen, a table, policies, tests and a line in the release notes, and no way
  in. It is now `Lending` in the vehicle menu, beside Transfer. A test now
  fails the build for any route nothing opens — this was the third time
  (decision 138).

**Found by reading the public pages as instructions rather than as prose:**

- Five menu paths were stale — including the one on the account-deletion page
  Google links to, and one in the privacy policy pointing at a screen that had
  no entry point on More at all. Both are fixed, and a test now holds every
  such path to rows that exist (decisions 136 and 137).

---

## 10. Optional, and worth knowing

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
