# What only you can do

Written 4 September 2026, after a change that added documents with expiry
dates, a printable mileage logbook, cost of ownership, three more entry-time
sanity checks, and two CI guards.

Everything in this repository is done, formatted, analysed and green:

```
flutter analyze                        # clean
flutter test                           # 2497 passing
flutter build web                      # builds
dart test test_rls/rls_test.dart       # 110 passing, against a real Postgres
cd supabase/functions && deno test     # 89 passing
```

The app was also **run**: built against a local Supabase stack and driven
through sign-up → create garage → sample data → add a registration document
with an expiry → planner. The reminder the document raises appears in the
planner as "Renault Clio · Registration", which is the one path across the
new table and the existing reminder machinery that no unit test reaches.

What is below is the part that lives in accounts, consoles and physical
devices. It is ordered by what it costs if it is skipped, not by effort.

---

## 1. Five new migrations will apply themselves — check that they did

`0049_vehicle_documents.sql` through `0053_tyre_dot_per_corner.sql` go out with the
push to `main` through the Supabase GitHub integration. They were applied from
scratch locally (`supabase db reset`) and the RLS suite ran against the result,
so they are known to apply in order.

**Check Dashboard → Database → Migrations lists up to `0053`.** If the
integration missed them, `supabase db push` applies the backlog. A missing
`0049` is not subtle — the Documents screen will report a failure on every
open — but a missing `0052` or `0053` is: a trip, or a tyre set, will simply
refuse to save, and only the error message says why.

---

## 2. The `public-api` edge function has changed and must be deployed

It gained a `/documents` resource. Until it ships, the app is fine and the API
answers `404` for a path the docs and the hosted page both now describe.

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

## 3. Turn push on — still the single highest-value thing (~1 hour)

Unchanged by this work and still the largest gap between what the app says and
what it does: a reminder created by one member of a shared garage is heard by
nobody else. Everything is written; nothing is configured.

[`RUNBOOK-push.md`](RUNBOOK-push.md) is the whole list. In short:

1. A Firebase project with an Android app, giving four values
   (`FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
   `FIREBASE_PROJECT_ID`) as GitHub secrets and in `env/local.json`.
2. A service-account JSON as a Supabase secret:
   `supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"`.
3. `supabase functions deploy push-due-reminders` — or step 2 above makes this
   automatic.
4. The daily `cron.schedule` in the runbook.

> **Do not do half of it.** Configuring Firebase makes the app stand down its
> own local scheduling in favour of the server
> (`lib/core/notifications/notification_providers.dart:51`). A build with the
> dart-defines but no scheduled cron sends nobody anything — strictly worse
> than not starting.

Documents ride on this for free: a document's expiry writes an ordinary
one-time reminder rule, so the push sender already covers it with no further
work.

---

## 4. Verify the two link paths against the live project (~15 minutes)

Both are recorded as open in
[`known-bugs-and-risks.md`](operations/known-bugs-and-risks.md) and neither can
be proven from here.

**The confirmation email.** In Supabase → Authentication:

- **URL Configuration**: Site URL is `https://garage.hrva.cc`, and
  `https://garage.hrva.cc/` is in the redirect allow-list. Supabase *ignores*
  `emailRedirectTo` unless the URL is allow-listed, and falls back to the Site
  URL silently.
- **Emails**: the templates from the runbook are actually pasted in.

Then register a throwaway address and follow the link. A blank page is the
symptom to look for; the browser console distinguishes an auth error from a
Worker problem.

**The invite deep link.** After the next web deploy:

```bash
curl -s https://garage.hrva.cc/.well-known/assetlinks.json | head -c 200
```

**Read the body, not the status.** The Worker serves `index.html` with a `200`
for any missing path, so "not deployed" and "deployed" look identical to
anything that only checks the status code. You want JSON with a
`sha256_cert_fingerprints` array.

---

## 5. Play Store copy needs pasting (~10 minutes, at the next release)

The repository holds the text; Play does not read it from here.

- **Screenshots**: `distribution/screenshots/phone-en/` has **eight** new
  1080×1920 shots, dark theme, replacing seven stale light-theme ones. Upload
  in filename order; the listing doc names each.
- **Feature graphic**: `assets/store/feature-graphic.png` is new (its HTML
  source is beside it in `assets/store/sources/`).
- **Full description**, both languages, from
  [`play-store-listing.md`](play-store-listing.md). Both were rewritten to
  make room for the documents and logbook sections and both now sit just under
  the 4000-character cap (3985 and 3999). `test/ci/deploy_workflow_test.dart`
  enforces the cap, so the next feature worth a sentence means trimming one.
- **Release notes** in `distribution/whatsnew/` are uploaded automatically by
  the tag workflow. Nothing to do.
- **Data safety**: no new *type* to declare. Documents and the trip driver are
  both "Other user-generated content", which is already declared. Two
  explanatory notes were added to the listing doc for a reviewer who asks —
  worth reading once so the answer is yours rather than mine.

---

## 6. On a real device, once (~10 minutes)

Nothing in this repository can run these, and all three fail silently.

```bash
# Cold start into a deep link
adb shell am force-stop cc.hrva.garage
adb shell am start -a android.intent.action.VIEW \
  -d https://garage.hrva.cc/log/fuel cc.hrva.garage/.MainActivity
```

- Long-press the app icon: the shortcut should be there (needs API 25+).
- Place the home-screen widget: a `RemoteViews` layout that uses an
  unsupported attribute fails at inflation, in the launcher's process, showing
  "Problem loading widget" and logging nowhere the app can see.
- The documents → planner path was already exercised on web against a local
  Supabase (see above), so what is left on a device is the Android half:
  the same walk, plus checking the notification actually arrives once push is
  on.

> The emulator on this machine has 2 GB and OOM-kills debug builds — use
> `flutter run --profile`.

---

## 7. Four things you reported, all fixed

Listed so you can check them rather than take my word:

- **"Hand a vehicle to another garage" — which vehicle?** The transfer screen
  now names the car at the top, and the button names it too when the garage
  has one (an ellipsis when a picker follows).
- **One DOT code for four tyres.** A tyre set now records a date per corner.
  The sheet asks once and unfolds to four when you say the codes differ; the
  set's age is judged by its oldest tyre.
- **The quick-add offered an archived car.** It reads the active list now, so
  a garage with one car and one sold one does not ask at all.
- **A printable service schedule.** Vehicle → ⋯ → Create report → **Service
  schedule**: what this car gets done, how often, when it last was and when it
  is next due, with a footnote saying the intervals are yours and not the
  manufacturer's.

## 8. Optional, and worth knowing

- **The dashboard's debug-only `setState during build` assertion** was
  investigated again and not reproduced; the reason is written up in
  known-bugs. It needs a screen harness driven by fake *repositories* rather
  than by overridden providers, which no test in this repository has yet. That
  harness is worth more than the bug.
- **`git status` is deliberately dirty.** Nothing was committed or pushed, as
  asked. `git diff --stat` is the whole change.

---

## What was deliberately not built

Recorded so it does not read as an oversight:

- **A driving licence document.** It belongs to a person, not a car, and both
  the table and the attachments bucket are scoped by vehicle (decision 94).
- **Receipt OCR** (roadmap item 6). It needs an ML Kit plugin whose web
  fallback and device behaviour cannot be verified from here, and a wrong
  reading saved silently is worse than typing.
- **The offline write queue** (roadmap item 2). It touches every repository
  and needs its own suite; a half-working queue at a petrol station is worse
  than an honest failure. It is the largest thing left that is entirely within
  the code.
- **A scraped valuation source.** A listing price the app invented would sit
  on the same card as numbers the household typed, carrying an authority it
  has not earned (decision 96).
