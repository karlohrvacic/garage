# Known bugs and risks

What is broken, thin, or sharp enough to bite. Read this before trusting anything
in production.

Severity means:

| | Meaning |
|---|---|
| **Critical** | Data loss, or one household's data reachable by another |
| **High** | A feature is broken or unavailable for a whole class of users |
| **Medium** | Works, but wrong or confusing in a way people will hit |
| **Low** | Annoyance, or a trap for the next developer rather than a user |

Last reviewed: 17 August 2026.

---

## Open

### 1. Invite-link verification is unproven until the next web deploy
**Medium.** `web/.well-known/assetlinks.json` now carries the real Play App
Signing fingerprint, but nothing has served it yet. Two things make this fail
quietly rather than loudly:

The Worker sets `not_found_handling: single-page-application`, so a missing path
returns **200 with `index.html`**. Today `curl https://garage.hrva.cc/.well-known/assetlinks.json`
returns HTML with a 200, which is what "not deployed" looks like — and it is
indistinguishable from success to any check that only reads the status code.
Android fetches HTML where it expects JSON and declines to verify without
reporting anything to the app. Check the body, not the status.

The fingerprint published is the *App signing* key. A locally built debug or
profile APK is signed with the debug keystore, so it will never verify on this
machine; that is expected, not a regression. Fire the intent directly at the
package to exercise the routing.

Neither blocks a release: an unverified link opens the web app, which is the
intended fallback for someone without the app. The verification steps are in the
[listing doc](../play-store-listing.md).

`test/ci/invite_links_test.dart` keeps the link, the intent filter and the
assetlinks file agreeing on host and path, and asserts the fingerprint is 32
upper-case hex bytes rather than a placeholder, since a rename or a bad paste in
one of the three is otherwise invisible until someone follows a link.

### 2. Push is finished in code and switched off in the world
**Medium.** Every piece is now written: the token registers, the function sends,
the device displays what arrives, and settings say which mode is in force. What
is missing is account work nobody can do from the repo — a Firebase project,
five values, `supabase functions deploy push-due-reminders`, and the cron row.
Until then `PushConfig.isConfigured` is false, the receiver is a no-op, and
reminders stay per device. [RUNBOOK-push.md](../RUNBOOK-push.md) is the whole
list.

**Do not do half of it.** Configuring Firebase makes the app stand its local
scheduling down in favour of the server
(`lib/core/notifications/notification_providers.dart:51`), so a build with the
dart-defines but no scheduled cron sends nobody anything — worse than not
starting. The runbook does both in one sitting for that reason.

### 3. Reminders are per device until push is switched on
**Medium.** A household member who did not create a reminder never hears about
it, which undercuts the shared-household premise. This is decision 5 in the
[decision log](../decisions/decision-log.md), recorded here because from a
user's point of view it is indistinguishable from a bug.

What changed: the app now **says so** rather than leaving people to guess —
Settings → Reminders reads "Only this device is notified", and flips to
"Everyone in this garage is notified" the moment push is real. The silence was
the worse half of this, and it is closed. The limitation itself ends with
item 2.

### 4. Nothing on screen distinguishes a measured rate from an assumed one
**Low.** A vehicle with fewer than two odometer sightings, or none that moved,
has no rate to measure and falls back to 30 km/day
(`lib/domain/maintenance/reminder_projection.dart:74`). The projection then
reads exactly like a measured one. The coupling to *fuel* logging is gone —
see "Maintenance accuracy was coupled to fuel logging" below — but the silent
fallback is not.

### 5. Two fuels still share one distance
**Low.** Each fuel now gets its own chain of full tanks, so a petrol figure is
computed from petrol volumes alone. What no app can fix from this data is that
the chains overlap: an LPG span from 1000 to 1500 km includes whatever was
driven on petrol in between. Each figure is an approximation of that fuel's
consumption over a period rather than a measurement of it, and nothing on
screen says so.

### 6. The failure log is memory-only and unreachable
**Medium.** `reportFailure` keeps the last 20 failures
(`lib/core/errors/failure_log.dart:7`) and logs them to `dart:developer`, which is
readable over `adb logcat -s garage.failure` on a wired device. A tester in the
field cannot get at it, so "it said something went wrong" is still where most
reports will stop. Surfacing it behind the About screen is the obvious next step
and is not built.

### 7. Realtime covers the entry tables, not the schema
**Low.** The publication now carries vehicles, all six entry kinds, reminder
rules, attachments and tyre sets. Still outside it: **invites, api keys,
webhooks, and vehicle transfers** — so a code revoked on a laptop still looks
live on a phone until that screen is revisited. Fine today, surprising if you
assume everything streams.

Worth knowing for the next entry kind: **three places have to be told about it**
— the realtime publication, the webhook trigger, and the `entryKinds` map in
`dispatch-webhooks`. Missing the last two is silent, and it happened between
migrations `0028` and `0032`.

### 8. `lib/domain/` purity has no automated guard
**Low.** Nothing fails if someone imports Flutter into the domain layer. The rule
is stated in [`CLAUDE.md`](../../CLAUDE.md) and holds by convention. A one-line
test over the directory would close it.

### 9. Release notes and store copy sit outside the tested strings
**Low.** `distribution/whatsnew/` and [play-store-listing.md](../play-store-listing.md)
duplicate feature names that also exist in the ARB files, and no test relates
them. A rename reaches users inconsistently.

---

## Recently fixed, worth remembering

### CI failed twice on things nobody had written
**Was Low** each time, and both were the same shape: the checks that decide
whether code may ship were configured less carefully than the deploy they gate.

**A floating SDK.** The three CI jobs asked for `channel: stable` with no
version while both deploy workflows pinned `3.44.6`, so CI ran on whatever
Flutter was newest that morning. A formatter change in a later SDK reported
`test/core/theme/page_transitions_test.dart` as unformatted on a tree that
formats clean locally — a red build with no commit behind it. All three jobs
now pin the same version the release builds with
(`.github/workflows/ci.yml:45`), and a test fails if any Flutter setup step
anywhere loses its pin.

**A key the suite needs and the job never passed.** The account-deletion cases
in `test_rls/rls_test.dart:50` need `SUPABASE_SERVICE_ROLE_KEY`, because they do
what the `delete-account` function does. The job exported only the anon key, so
`setUpAll` threw and the run reported `0 tests passed, 2 failed` — which names
neither the key nor the reason. The job now reads `SERVICE_ROLE_KEY` out of
`supabase status -o env` alongside the other two, and a test derives the
required names from the suite itself and fails if the workflow does not pass
one of them.

Verified locally the way CI runs it: `supabase db reset` from scratch, then the
suite with all three variables — 57 passing.

### The push sender rejected the only caller it has
**Was High** the moment push was switched on, and invisible until then: every
scheduled run would have been refused.

The function gated itself on `authHeader.includes(SUPABASE_SERVICE_ROLE_KEY)`,
matching the injected env value as a string. On a project with the newer secret
keys that value is an `sb_secret_…` string, while the platform's own
`verify_jwt` lets only a JWT reach the function at all — so no caller could
satisfy both. Proven against production: the legacy service-role JWT passed the
gateway and failed the comparison (403), the secret key failed the gateway
(401).

It now checks the **role** carried by the token
(`supabase/functions/push-due-reminders/index.ts:59`), which the platform has
already verified the signature of, and still refuses an anon token — the one
every copy of the app holds. Verified by calling
`select public.run_due_reminders_push()` and reading `net._http_response`:
`200 {"pushed":0}`, where it had been `403 Forbidden`.

**How it hid:** nothing calls this function except a cron job whose wrapper is
silent by design when unconfigured, so the first real evidence would have been
a household never being notified.

### A car going away while you were looking at it crashed the screen
**Was Medium**, and it shipped: the vehicle picker on Statistics and on the
calculator has been there for releases. The screen keeps the chosen id in its
own state, and a `DropdownButton` whose `value` is not among its `items`
asserts rather than degrading. So when a car left the fleet while a screen held
it selected — another member transfers or deletes it, realtime refreshes the
list — the screen threw instead of falling back.

Fixed with one guard, `chosenVehicleId`
(`lib/features/vehicles/vehicle_choice.dart:10`), used by Statistics, the trip
log and the calculator: a car that is gone reads as "all vehicles", which is
what the screen showed before anything was picked. Proven by reverting the
guard — the test fails on the framework assertion, not on a missing widget.

It is not in the release notes. Every line there is a feature this release
gives everyone, the file is at 487 of its 500 characters, and this needs a
household to delete a car while a second device sits on the statistics screen.
Worth adding if that turns out to be less rare than it sounds.

### A CSV in gallons imported a price per litre it never said
**Was High for anyone importing an imperial file**, and silent. `CsvUnits`
converted the volume of a fill-up and left `pricePerUnit` alone, so ten gallons
at 4.20 per gallon were stored as 37.85 litres at "4.20 per litre" against a
total of 42 — an entry contradicting itself, and every price-per-litre figure
out by nearly four times.

Worse, "gallons" meant the US one whatever the household reads. A UK household
importing UK gallons had every volume understated by a fifth, which nothing
downstream could detect.

Both fixed in `lib/features/settings/data/csv_import_action.dart:26`:
`pricePerVolume` divides where `volumeL` multiplies, and the factor comes from
the household's own volume unit (`litresPerGallon`,
`lib/core/format/unit_format.dart:23`) rather than a constant. A household
reading litres that ticks the box still gets the US gallon, which is what an
unqualified "gallons" means in most exports.

### The backup called itself everything and left two things out
**Was Medium.** `buildBackup` carried the six entry kinds and the vehicles, but
not the reminder rules or the tyre sets — under a button labelled "Back up
everything". Losing reminders is the silent kind of loss: the log comes back
after a restore and the notifications simply never do. Tread readings are worse
still, being the one thing nobody can measure again afterwards.

Both are now in the file and in the restore, additively as everything else is
(`lib/features/settings/data/backup_action.dart:78`). Tyres restore in two
steps because a set has no id until it is created; a set already there is left
alone and only gains readings it lacks.

**Still out:** photo attachments, which are files in storage rather than rows,
and which a JSON file cannot carry without becoming something else.

### Distance-based reminders would have pushed off a stale odometer
**Was Low only because the function is not deployed.**
`push-due-reminders` read the current odometer from the newest **fuel** entry,
which is exactly the coupling the app itself was fixed to remove: a household
recording readings without buying fuel — an EV, or anyone who stopped logging
fill-ups — would have had every distance-based reminder projected from a number
that stopped moving.

It now takes the highest reading across all six tables that record one
(`supabase/functions/push-due-reminders/index.ts:140`), mirroring
`OdometerHistory`. The highest rather than the newest, because an odometer only
goes up and a lower later number is a typo. `test/ci/entry_kinds_wired_test.dart`
fails if a kind is left out of it.

**Deployment:** edge functions do not deploy themselves. This one is dormant
until somebody runs `supabase functions deploy push-due-reminders`, and the fix
is dormant with it.

### Opening a sidebar link slid the whole browser window
**Was Low**, and only on a desktop-width window. Household, Statistics, Fuel
stations and the calculator are pushed routes with no custom page, so they took
the platform's push transition — which on the web in a Mac browser is the
Cupertino slide, since Flutter reports `TargetPlatform.macOS` there. The sidebar
is drawn inside each page, so the whole window slid in from the right while the
page underneath, sidebar and all, parallaxed out to the left: one sidebar left
and an identical one arrived. The five tab routes were immune only because
`_tabPage` gives them a fading page of their own.

Fixed in the theme rather than route by route
(`lib/core/theme/garage_theme.dart:203`), because the same slide was on all ten
pushed screens that draw a sidebar, not only the four in the sidebar itself.
Phone-width windows keep the platform transition and its back gesture.

**Still true underneath:** the sidebar is part of every page rather than a shell
around them. The cross-fade hides it — two identical sidebars fading into each
other look static — but a `ShellRoute` is what would make it actually so, and
anything that animates a page will keep having to work around this.

### Bi-fuel vehicles produced mixed economy figures
**Was Medium.** `FuelEconomy.compute` treated every fill as the same fuel, so a
car alternating petrol and LPG produced spans that averaged the two into a
figure that was neither.

A vehicle may now name a second fuel it takes
(`supabase/migrations/0031_bi_fuel.sql:12`), a fill-up may name which went in,
and the algorithm computes one chain per fuel
(`lib/domain/fuel/fuel_economy.dart:54`). Both columns are nullable and null
still means what it always did: one fuel, no question to ask, existing history
untouched.

The subtlety worth remembering is what `primaryFuelKey` is for. A household that
turns on the second tank part-way through has older rows with no fuel on them,
and those belong to the chain of the fuel the car mainly runs on rather than to
a chain of their own. The economy provider passes the vehicle's own fuel — but
only when the car is bi-fuel, so a single-fuel car's points stay unlabelled.

### Deleting an account failed for anyone who shared a household
**Was High**, and a Play compliance problem: in-app deletion has to work.

Seventeen `created_by` and `redeemed_by` columns referenced `auth.users` with
the default `no action`, so Postgres refused to delete a user while any row
pointed at them. A **solo** household worked only by accident —
`household_members` cascades, the cleanup trigger drops the empty household, and
that cascades through vehicles to every entry before those references are
checked — which is why it was never noticed. Sharing the household exposed it:
`delete-account` returned "Database error deleting user".

Fixed in `supabase/migrations/0033_account_deletion_unblocked.sql` with
`on delete set null` rather than `cascade`. The entries belong to the
**household**, not to whoever typed them; cascading would mean one member
leaving takes half a shared log with them.

**Two traps found while fixing it, both on a live Postgres and both worse than
the original bug:**

1. **`pin_created_by` silently defeated the fix.** That trigger (migration
   `0008`) reverts any update of `created_by` to stop a crafted client forging
   authorship — and `on delete set null` *is* an update. The delete then reported
   success and left a **dangling foreign-key reference** behind. The trigger now
   permits exactly one thing it did not: nulling `created_by` when the user it
   pointed at no longer exists, which is true for the referential action (fired
   after the parent row is gone) and false for any client.
2. **The rewritten trigger broke every edit.** It reads `auth.users`, which
   `authenticated` cannot select from, so editing a fill-up failed with
   "permission denied for table users" until the function was made
   `security definer`. Caught by the regression test, not by inspection.

Four tests in `test_rls/rls_test.dart` now cover it: the delete completes, the
entries survive, nothing is left dangling, and a *live* member still cannot
erase their own authorship. They need `SUPABASE_SERVICE_ROLE_KEY` as well as the
anon key, because they exercise what the edge function does.

**A follow-on bug this caused, now fixed.** The eight repositories read
`created_by` as nullable and map it to the empty string, which this codebase
already uses for "no author". That empty key reached
`householdSpendByMemberProvider` and became a *participant* in the settlement:
the fair share was divided by one head too many, and the household could be told
it owed money to a blank name. Spend with no author is now kept in
`Settlement.unattributed`
(`lib/domain/household/settlement.dart:134`) — outside the split, because there
is nobody to pay or be paid, and shown on its own line in the settlement card so
the difference from `householdTotal` does not look like an arithmetic mistake.
Leaving it out cannot change who owes whom: money nobody will be repaid for
benefits every remaining member equally.

Spend from someone who has *left* the household but still exists stays in the
split, deliberately — they can still be settled with.

### A member could not join a second household
**Was Low.** The schema always permitted belonging to several — `household_members`
is keyed on the pair — but every screen read `myHouseholds().first`, so a second
membership was invisible and the join screen refused rather than appearing to
work. Two people who had each already made a garage could only merge by one of
them leaving.

`selectedHouseholdIdProvider`
(`lib/features/household/providers/current_household.dart:15`) now holds which
garage this device is showing, and `chooseHousehold`
(`current_household.dart:56`) falls back to the first when the stored choice is
not among the user's — which is what leaving, or being removed, looks like from
here. A switcher appears in the sidebar header and on the household screen, and
only when there is more than one garage to switch between.

**The race this had to close:** the stored choice is read asynchronously while
the app is already usable, so a switch made in that window was being undone by a
value that was stale before it arrived. The notifier tracks whether this session
has chosen and ignores the load if so.

### Vehicles can now change hands
Not a bug — a gap. `vehicle_transfers`
(`supabase/migrations/0030_vehicle_transfer.sql:15`) moves a car and its whole
history to another garage by changing one `household_id`; everything else hangs
off `vehicle_id` and follows. Worth knowing: the vehicle **photo does not
follow**, because objects in the `vehicle-photos` bucket are keyed
`<household_id>/<vehicle_id>` and SQL cannot move a storage object. The path is
cleared on transfer.

### Maintenance accuracy was coupled to fuel logging
**Was Medium.** The daily driving rate, and the vehicle's current odometer, were
read from fill-ups alone. A household that services its car but pays cash at the
pump had nothing to measure from, so every distance-based projection used the
30 km/day fallback however much the car was actually driven.

Two changes closed it. `OdometerHistory`
(`lib/domain/fuel/odometer_history.dart:33`) merges every source that records a
reading — fill-up, service, cost entry, standalone reading — into one series,
and both the rate and the current reading are taken from that. And
`odometer_entries` is a new entry kind with no money attached, so somebody who
never buys anything the app tracks can still say how far the car has gone.

The series is deliberately opinionated: one reading per day (the highest), and
nothing that goes backwards. Several entries on one day are normal — a fill-up
and the service that prompted it — and two points zero days apart would drag any
rate towards nothing. A reading below one already recorded means one of the two
is a typo, and which is unknowable.

### The push sender skipped every dated reminder
**Was High**, and unnoticed because nothing had ever pushed. `push-due-reminders`
selected only `interval_km` and `interval_months` and projected a due date from
the last matching service. A one-off carries neither: it has `one_time` and its
own `due_date`. Both branches were skipped, `dueDate` stayed null, and the loop
`continue`d — so a vignette running out, and registration, insurance and casco
falling due, were exactly the reminders that would never have been pushed.

Fixed by reading `one_time, due_date` and using the date on the rule. Verified
against the schema and the writer in `cost_entry_sheet.dart`, **not** end to end:
sending needs the `FCM_SERVICE_ACCOUNT` secret, which does not exist yet.

### Vignette expiry was a day late
**Was Medium.** A period covers its own first day — ASFINAG sells the 10-day
vignette as "the 1st day of validity plus 9 additional calendar days", and DARS
sells seven consecutive days — but `nextDue` added the full period to the
purchase date. Every vignette therefore claimed one more day of validity than it
had, which is the direction that ends in a fine. The date is now the last day it
is still valid, and the sheet says "Valid through" rather than "Runs out".

Times of day are still not modelled: Romania sells in 24-hour periods from
purchase, and an Austrian vignette bought at midday does not lapse at midnight.
Landing the reminder on the morning of the last certainly-valid day is the safe
side of that.

### Loading the sample data looked like nothing happened
**Was Medium.** The load writes about twenty rows one at a time, which is
seconds against a real backend, and the screen did not change while it ran. The
first person to try it tapped five times and got five sample cars. There is a
spinner in both places that offer it now, and `sampleDataLoadingProvider` makes
the action itself refuse to start twice, so the guard does not depend on a
screen remembering to disable its button.

### The RLS suite ran on the honour system
**Was High.** `test_rls/rls_test.dart` is the only thing that proves one household
cannot read another's data, and because it needs a live Postgres it sat outside
CI and was run by hand. It had already caught real decay once: the suite used Bob
as its "stranger" while a test halfway down made him a household member, so a run
of isolation assertions was quietly measuring a member and proving nothing.

`.github/workflows/ci.yml` now has an `rls` job that runs `supabase start` and the
38 tests against it. Because `deploy-web.yml` calls this workflow and waits on it,
the site can no longer go out over a tenancy regression. Standing the stack up
from scratch also proves every migration still applies to an empty database.

### Sample data made the app look broken
**Was Medium.** Every litre figure in `SampleGarage` was its distance times a flat
0.06, so all twelve spans came out at exactly 6.0 l/100km. The economy chart was
a flat line, the car's summary read "Best 6.0 · Worst 6.0", and the ring showed a
scale of nothing. This was the first screen anyone loading the demo saw.

Underneath it was a real defect: `EconomyRange.of` rejected a degenerate range
with `best == worst`, an exact comparison on numbers that come out of
floating-point division. Twelve "identical" tanks differed by 9e-16, which passed
as a range, and the ring then scaled a rounding error and read full. It now needs
a spread of at least 0.05 l/100km, which is what the screen can print.

### The scale on the economy chart repeated itself
**Was Medium.** Y-axis ticks were rounded to whole numbers, but a car's whole
range fits inside one or two l/100km, so several ticks printed the same label: a
scale reading 7, 7, 6, 6, 5 down the side. One decimal now, matching every other
economy figure in the app.

### The floating button covered the end of every list
**Was Medium.** None of the four screens with a floating action button left room
for it, so the last row sat underneath and any control on that row could not be
tapped at all: on the dashboard, the last vehicle's fuel and maintenance buttons.
`GarageTokens.fabClearance` is now the bottom padding on all four.

### Entry forms opened under the status bar
**Was Low.** `showAdaptiveEntrySheet` opened a scroll-controlled sheet, which is
laid out over the whole screen, and the route strips the top inset from the
MediaQuery it passes down, so the `SafeArea` inside each form could not see it.
"Add fill-up" came to rest against the clock. Fixed with `useSafeArea: true`.

### A list of dates could read as though it were out of order
**Was Low.** `formatShortDate` always omitted the year, so a car serviced in
October and again the following April listed "Apr 16" above "Oct 16": correct,
newest first, and indistinguishable from a list sorted backwards. The year is
named now whenever the date is not in the current one.

### Fuel prices claimed to be nearby from anywhere on earth
**Was Medium.** The dataset is the Croatian ministry's, but nothing said so on
screen. Opened from outside the country it listed the whole of Croatia, nearest
first, with "average nearby" over the top: a station 9,671 km away offered as
somewhere to fill up. Beyond 300 km the screen now says which country the prices
cover, and the nearby average is computed only inside that radius. The national
average, which is true from anywhere, stays.

This entry replaces an older one claiming the screen was "simply empty" outside
Croatia. It never was, which is the more useful half of the lesson.

### The calculator labelled a field with its own default answer
**Was Low.** The vehicle picker's label was the string "All vehicles", the name of
the option already selected inside it, while every field below named what it was
for.

### Fuelio import stopped halfway and reported nothing useful
**Was High.** `upsertRule` asked Postgres for `on conflict (vehicle_id,
service_type_key)`, but migration `0024` had replaced that constraint with a
*partial* unique index (`where not one_time`) so two dated tyre swaps could
coexist. A partial index only satisfies ON CONFLICT when the statement repeats
its predicate, which PostgREST cannot express, so every recurring rule failed
with 42P10. An import wrote its fill-ups, services and costs, then died on the
first reminder. Replaced with update-then-insert, covered by three RLS tests.

### One item showed two different percentages
**Was Medium.** The dashboard measured *time remaining over 90 days* while the
maintenance list measured *interval consumed*, so the same tyre swap read as
100% in one place and 26% in the other. Worse, the gauge's danger colour was at
the empty end, so a freshly serviced item glowed red. One meaning now
(`ReminderProjection.dueness`): zero is freshly done, one is due.

### The economy ring was a proportion of nothing
**Was Low.** It scaled against a hardcoded 4 to 12 l/100km, which flattered a
small diesel, pinned a thirsty car at empty, and was meaningless for an
electric one. It now scales against the car's own best and worst, and prints
that range underneath.

### Google sign-in never worked in a shipped build
**Was Critical.** "Continue with Google" failed on every release build with a
generic error. The cause was `authorizationForScopes([])`: an empty authorization
request, which the platform rejects *after* the account picker has already
succeeded. Every plausible-looking culprit (signing certificate, OAuth client,
Supabase authorized client IDs) was correct all along.

Two things made it expensive. The exception matched no branch in `AppFailure.from`
and so rendered as a generic sentence, and `debugMessage` was recorded nowhere, so
the app knew exactly what went wrong and discarded it. Both are now fixed
([09](../architecture/09-errors-and-diagnostics.md)); the second is the more
valuable fix.

### Editing an older fill-up was impossible
**Was High.** The odometer guard compared against the newest reading in the log, so
editing any historical entry was rejected for being "before the last fill-up", as
was backdating one. Replaced with a date-bracketed window
(`lib/domain/fuel/odometer_bounds.dart:10`).

### Importing from Fuelio did nothing
**Was High.** The importer returned early when the household had no vehicles, so a
new user arriving from Fuelio, the exact person it is for, tapped it and saw
nothing at all. It now reads the backup's `## Vehicle` section and creates the car.

### Dialogs stretched to full height
**Was Medium.** `LabeledField` used a `Column` with the default `MainAxisSize.max`,
so inside an `AlertDialog` one label and one text field measured 856 logical
pixels tall. It affected every dialog using it, not just the one reported.

### The privacy policy named the wrong hosting region
**Was Medium.** `PRIVACY.md` and the hosted page said Frankfurt; the project runs
in `eu-north-1`, Stockholm. Both are in the EU so residency was never affected,
but the statement was false on a page the Play listing links to.

---

## Non-issues (checked, turned out fine)

- **The 67.5 MB app bundle.** Alarming until inspected: 96.9 MB uncompressed of it
  is `BUNDLE-METADATA`, debug symbols and the ProGuard map, which Play strips.
  Devices download one ABI. Keeping it is what makes crash reports show Dart
  frames.
- **Location permission versus the Data safety form.** The app requests precise
  location for the Stations screen, which looked like an undeclared data type. It
  is not collected under Play's definition: the position never leaves the device,
  feeding only the distance arithmetic in `nearbyStationsProvider`. Documented with
  the condition that would flip it in [play-store-listing.md](../play-store-listing.md).
- **Webhook delivery is single-attempt.** Looks like missing retry logic; it is a
  decision recorded at `supabase/functions/dispatch-webhooks/index.ts:9`. A
  receiver that missed one can read the same data from the API.
- **Supabase's built-in email limit.** Two messages per hour project-wide looked
  like a blocker for onboarding testers. Resolved by configuring custom SMTP and
  raising the limit; worth knowing that the limit is only raisable *with* custom
  SMTP.
